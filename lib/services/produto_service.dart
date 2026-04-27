import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/fornecedor.dart';
import '../models/movimento_estoque.dart';
import '../models/produto.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'connectivity_service.dart';
import 'firebase_context_service.dart';
import 'service_exceptions.dart';

class ProdutoService {
  static const String _estoqueCollection = 'estoque';

  ProdutoService({
    DatabaseHelper? db,
    FirebaseContextService? context,
    ConnectivityService? connectivity,
    Uuid? uuid,
  })  : _db = db ?? DatabaseHelper(),
        _context = context ?? FirebaseContextService(),
        _connectivity = connectivity ?? ConnectivityService(),
        _uuid = uuid ?? const Uuid();

  final DatabaseHelper _db;
  final FirebaseContextService _context;
  final ConnectivityService _connectivity;
  final Uuid _uuid;

  bool get _firebaseDisponivel => _context.firebaseDisponivel;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<bool> _isFirebaseOnline() async {
    if (!_firebaseDisponivel) return false;
    return _connectivity.isOnline();
  }

  Future<List<Produto>> getAll({bool apenasAtivos = true}) async {
    await _syncFromFirestoreIfOnline();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final whereParts = <String>[];
    final args = <dynamic>[];
    if (apenasAtivos) {
      whereParts.add('p.ativo = 1');
    }
    if (shopIdFiltro != null) {
      whereParts.add('p.barbearia_id = ?');
      args.add(shopIdFiltro);
    }

    final maps = await _db.rawQuery('''
      SELECT p.*, f.nome as fornecedor_nome
      FROM ${AppConstants.tableProdutos} p
      LEFT JOIN ${AppConstants.tableFornecedores} f ON p.fornecedor_id = f.id
      ${whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}'}
      ORDER BY p.nome ASC
    ''', args);
    return maps.map((m) => Produto.fromMap(m)).toList();
  }

  Future<Produto?> getById(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do produto',
      min: 1,
      max: 1 << 30,
    );
    await _syncFromFirestoreIfOnline();
    final shopIdFiltro = await _barbeariaIdParaFiltro();

    final maps = await _db.rawQuery('''
      SELECT p.*, f.nome as fornecedor_nome
      FROM ${AppConstants.tableProdutos} p
      LEFT JOIN ${AppConstants.tableFornecedores} f ON p.fornecedor_id = f.id
      WHERE p.id = ?
        ${shopIdFiltro == null ? '' : 'AND p.barbearia_id = ?'}
      LIMIT 1
    ''', shopIdFiltro == null ? [safeId] : [safeId, shopIdFiltro]);
    if (maps.isEmpty) return null;
    return Produto.fromMap(maps.first);
  }

  Future<int> insert(Produto produto) async {
    final safeProduto = _sanitizarProduto(produto);
    if (await _isFirebaseOnline()) {
      final shopId = await _context.getBarbeariaIdAtual();
      final uid = _auth.currentUser?.uid;
      if (shopId != null && uid != null) {
        final firebaseId = _uuid.v4();
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableProdutos)
            .doc(firebaseId)
            .set({
          'nome': safeProduto.nome,
          'preco_venda': safeProduto.precoVenda,
          'preco_custo': safeProduto.precoCusto,
          'quantidade': safeProduto.quantidade,
          'estoque_minimo': safeProduto.estoqueMinimo,
          'comissao_percentual': safeProduto.comissaoPercentual,
          'fornecedor_id': safeProduto.fornecedorId,
          'ativo': safeProduto.ativo,
          'barbearia_id': shopId,
          'created_by': uid,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        return _db.insert(AppConstants.tableProdutos, {
          ...safeProduto.toMap(),
          'firebase_id': firebaseId,
          'barbearia_id': shopId,
          'created_by': uid,
        });
      }
    }
    return _db.insert(AppConstants.tableProdutos, safeProduto.toMap());
  }

  Future<void> update(Produto produto) async {
    SecurityUtils.ensure(produto.id != null, 'ID do produto inválido.');
    final safeProduto = _sanitizarProduto(
      produto.copyWith(updatedAt: DateTime.now()),
    );
    if (await _isFirebaseOnline()) {
      final row = await _db.queryAll(
        AppConstants.tableProdutos,
        where: 'id = ?',
        whereArgs: [safeProduto.id],
        limit: 1,
      );
      final firebaseId =
          row.isEmpty ? null : row.first['firebase_id'] as String?;
      final shopId = await _context.getBarbeariaIdAtual();
      final uid = _auth.currentUser?.uid;
      if (firebaseId != null && shopId != null && uid != null) {
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableProdutos)
            .doc(firebaseId)
            .set({
          'nome': safeProduto.nome,
          'preco_venda': safeProduto.precoVenda,
          'preco_custo': safeProduto.precoCusto,
          'quantidade': safeProduto.quantidade,
          'estoque_minimo': safeProduto.estoqueMinimo,
          'comissao_percentual': safeProduto.comissaoPercentual,
          'fornecedor_id': safeProduto.fornecedorId,
          'ativo': safeProduto.ativo,
          'barbearia_id': shopId,
          'created_by': uid,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await _db.update(
      AppConstants.tableProdutos,
      safeProduto.toMap(),
      'id = ?',
      [safeProduto.id],
    );

    await _syncProdutoAndLastMovimentoIfOnline(safeProduto.id!);
  }

  Future<void> delete(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do produto',
      min: 1,
      max: 1 << 30,
    );
    if (await _isFirebaseOnline()) {
      final row = await _db.queryAll(
        AppConstants.tableProdutos,
        where: 'id = ?',
        whereArgs: [safeId],
        limit: 1,
      );
      final firebaseId =
          row.isEmpty ? null : row.first['firebase_id'] as String?;
      final shopId = await _context.getBarbeariaIdAtual();
      if (firebaseId != null && shopId != null) {
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableProdutos)
            .doc(firebaseId)
            .set({
          'ativo': false,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await _db.update(
      AppConstants.tableProdutos,
      {'ativo': 0},
      'id = ?',
      [safeId],
    );
  }

  Future<List<Produto>> getProdutosEstoqueBaixo() async {
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[];
    if (shopIdFiltro != null) {
      args.add(shopIdFiltro);
    }
    final maps = await _db.rawQuery('''
      SELECT p.*, f.nome as fornecedor_nome
      FROM ${AppConstants.tableProdutos} p
      LEFT JOIN ${AppConstants.tableFornecedores} f ON p.fornecedor_id = f.id
      WHERE p.ativo = 1 AND p.quantidade <= p.estoque_minimo
        ${shopIdFiltro == null ? '' : 'AND p.barbearia_id = ?'}
      ORDER BY p.quantidade ASC
    ''', args);
    return maps.map((m) => Produto.fromMap(m)).toList();
  }

  Future<void> entradaEstoque({
    required int produtoId,
    required int quantidade,
    required double valorUnitario,
    String? observacao,
  }) async {
    await _db.transaction((txn) async {
      await _registrarMovimentoEstoque(
        executor: txn,
        produtoId: produtoId,
        quantidade: quantidade,
        valorUnitario: valorUnitario,
        tipo: AppConstants.estoqueEntrada,
        observacaoPadrao: 'Compra de produto',
        observacao: observacao,
      );
    });
    await _syncProdutoAndLastMovimentoIfOnline(produtoId);
  }

  Future<void> baixarEstoque({
    required int produtoId,
    required int quantidade,
    required double valorUnitario,
    String? observacao,
  }) async {
    await _db.transaction((txn) async {
      await baixarEstoqueComExecutor(
        executor: txn,
        produtoId: produtoId,
        quantidade: quantidade,
        valorUnitario: valorUnitario,
        observacao: observacao,
      );
    });
    await _syncProdutoAndLastMovimentoIfOnline(produtoId);
  }

  Future<void> baixarEstoqueComExecutor({
    required DatabaseExecutor executor,
    required int produtoId,
    required int quantidade,
    required double valorUnitario,
    String? observacao,
  }) async {
    await _registrarMovimentoEstoque(
      executor: executor,
      produtoId: produtoId,
      quantidade: quantidade,
      valorUnitario: valorUnitario,
      tipo: AppConstants.estoqueSaida,
      observacaoPadrao: 'Venda em atendimento',
      observacao: observacao,
    );
  }

  Future<void> syncProdutoByIdIfOnline(int produtoId) async {
    final safeProdutoId = SecurityUtils.sanitizeIntRange(
      produtoId,
      fieldName: 'ID do produto',
      min: 1,
      max: 1 << 30,
    );
    await _syncProdutoAndLastMovimentoIfOnline(safeProdutoId);
  }

  Future<void> _registrarMovimentoEstoque({
    required DatabaseExecutor executor,
    required int produtoId,
    required int quantidade,
    required double valorUnitario,
    required String tipo,
    required String observacaoPadrao,
    String? observacao,
  }) async {
    final safeProdutoId = SecurityUtils.sanitizeIntRange(
      produtoId,
      fieldName: 'ID do produto',
      min: 1,
      max: 1 << 30,
    );
    final safeQuantidade = SecurityUtils.sanitizeIntRange(
      quantidade,
      fieldName: 'Quantidade',
      min: 1,
      max: 1000000,
    );
    final safeValorUnitario = SecurityUtils.sanitizeDoubleRange(
      valorUnitario,
      fieldName: 'Valor unitario',
      min: 0,
      max: 999999,
    );
    final safeTipo = SecurityUtils.sanitizeEnumValue(
      tipo,
      fieldName: 'Tipo do movimento',
      allowedValues: const [
        AppConstants.estoqueEntrada,
        AppConstants.estoqueSaida,
      ],
    );
    final safeObservacao = SecurityUtils.sanitizeOptionalText(
      observacao,
      maxLength: 300,
      allowNewLines: true,
    );

    final produtoRows = await executor.query(
      AppConstants.tableProdutos,
      columns: ['id', 'nome', 'quantidade', 'preco_custo', 'ativo'],
      where: 'id = ?',
      whereArgs: [safeProdutoId],
      limit: 1,
    );
    if (produtoRows.isEmpty) {
      throw const NotFoundException('Produto não encontrado para estoque.');
    }

    final produtoRow = produtoRows.first;
    final ativo = (produtoRow['ativo'] as num?)?.toInt() ?? 0;
    if (ativo != 1) {
      throw const ConflictException('Produto inativo não permite movimento.');
    }

    final nomeProduto = produtoRow['nome'] as String;
    final quantidadeAtual = (produtoRow['quantidade'] as num?)?.toInt() ?? 0;
    final precoCustoAtual =
        (produtoRow['preco_custo'] as num?)?.toDouble() ?? 0.0;
    final nowIso = DateTime.now().toIso8601String();

    if (safeTipo == AppConstants.estoqueEntrada) {
      final novaQuantidade = quantidadeAtual + safeQuantidade;
      final custoMedio = (quantidadeAtual * precoCustoAtual +
              safeQuantidade * safeValorUnitario) /
          novaQuantidade;

      await executor.update(
        AppConstants.tableProdutos,
        {
          'quantidade': novaQuantidade,
          'preco_custo': custoMedio,
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [safeProdutoId],
      );
    } else {
      if (quantidadeAtual < safeQuantidade) {
        throw ConflictException(
          'Estoque insuficiente para $nomeProduto: disponivel '
          '$quantidadeAtual, solicitado $safeQuantidade.',
        );
      }

      await executor.update(
        AppConstants.tableProdutos,
        {
          'quantidade': quantidadeAtual - safeQuantidade,
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [safeProdutoId],
      );
    }

    await executor.insert(
      AppConstants.tableMovimentosEstoque,
      MovimentoEstoque(
        produtoId: safeProdutoId,
        produtoNome: nomeProduto,
        tipo: safeTipo,
        quantidade: safeQuantidade,
        valorUnitario: safeValorUnitario,
        data: DateTime.now(),
        observacao: safeObservacao ?? observacaoPadrao,
      ).toMap(),
    );
  }

  Future<List<MovimentoEstoque>> getMovimentos({int? produtoId}) async {
    if (produtoId != null) {
      SecurityUtils.sanitizeIntRange(
        produtoId,
        fieldName: 'ID do produto',
        min: 1,
        max: 1 << 30,
      );
    }
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final whereParts = <String>[];
    final whereArgs = <dynamic>[];
    if (produtoId != null) {
      whereParts.add('produto_id = ?');
      whereArgs.add(produtoId);
    }
    if (shopIdFiltro != null) {
      whereParts.add('barbearia_id = ?');
      whereArgs.add(shopIdFiltro);
    }
    final maps = await _db.queryAll(
      AppConstants.tableMovimentosEstoque,
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'data DESC',
    );
    return maps.map((m) => MovimentoEstoque.fromMap(m)).toList();
  }

  Future<List<Fornecedor>> getFornecedores() async {
    final maps = await _db.queryAll(
      AppConstants.tableFornecedores,
      orderBy: 'nome ASC',
    );
    return maps.map((m) => Fornecedor.fromMap(m)).toList();
  }

  Future<int> insertFornecedor(Fornecedor f) async {
    final safeFornecedor = _sanitizarFornecedor(f);
    return _db.insert(AppConstants.tableFornecedores, safeFornecedor.toMap());
  }

  Future<void> updateFornecedor(Fornecedor f) async {
    SecurityUtils.ensure(f.id != null, 'ID do fornecedor inválido.');
    final safeFornecedor = _sanitizarFornecedor(f);
    await _db.update(
      AppConstants.tableFornecedores,
      safeFornecedor.toMap(),
      'id = ?',
      [safeFornecedor.id],
    );
  }

  Future<void> deleteFornecedor(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do fornecedor',
      min: 1,
      max: 1 << 30,
    );
    await _db.delete(AppConstants.tableFornecedores, 'id = ?', [safeId]);
  }

  Future<List<Map<String, dynamic>>> getMaisVendidos({int limit = 5}) async {
    final safeLimit = SecurityUtils.sanitizeIntRange(
      limit,
      fieldName: 'Limite',
      min: 1,
      max: 100,
    );
    // Unifica vendas de atendimentos legados E de comandas (fluxo principal)
    return _db.rawQuery('''
      SELECT
        vendas.item_id,
        vendas.nome,
        SUM(vendas.total_vendas)     AS total_vendas,
        SUM(vendas.faturamento)      AS faturamento_total,
        p.preco_custo,
        (SUM(vendas.faturamento) / NULLIF(SUM(vendas.total_vendas), 0)
          - p.preco_custo)           AS margem_unitaria,
        SUM(vendas.total_vendas) *
          (SUM(vendas.faturamento) / NULLIF(SUM(vendas.total_vendas), 0)
            - p.preco_custo)         AS lucro_total
      FROM (
        -- Vendas via atendimentos (fluxo legado)
        SELECT
          item_id,
          nome,
          SUM(quantidade)                      AS total_vendas,
          SUM(quantidade * preco_unitario)     AS faturamento
        FROM ${AppConstants.tableAtendimentoItens}
        WHERE tipo = 'produto'
        GROUP BY item_id

        UNION ALL

        -- Vendas via comandas (fluxo principal atual)
        SELECT
          item_id,
          nome,
          SUM(quantidade)                      AS total_vendas,
          SUM(quantidade * preco_unitario)     AS faturamento
        FROM ${AppConstants.tableComandasItens}
        WHERE tipo = 'produto'
        GROUP BY item_id
      ) AS vendas
      JOIN ${AppConstants.tableProdutos} p ON p.id = vendas.item_id
      GROUP BY vendas.item_id
      ORDER BY total_vendas DESC
      LIMIT ?
    ''', [safeLimit]);
  }

  Future<List<Produto>> getProdutosParados() async {
    final limite =
        DateTime.now().subtract(const Duration(days: 60)).toIso8601String();
    final maps = await _db.rawQuery('''
      SELECT p.*, f.nome as fornecedor_nome
      FROM ${AppConstants.tableProdutos} p
      LEFT JOIN ${AppConstants.tableFornecedores} f ON p.fornecedor_id = f.id
      WHERE p.ativo = 1 AND p.quantidade > 0
        AND p.id NOT IN (
          SELECT DISTINCT produto_id FROM ${AppConstants.tableMovimentosEstoque}
          WHERE tipo = 'saida' AND data >= ?
        )
      ORDER BY p.nome ASC
    ''', [limite]);
    return maps.map((m) => Produto.fromMap(m)).toList();
  }

  Future<double> getValorTotalEstoque() async {
    final result = await _db.rawQuery('''
      SELECT SUM(quantidade * preco_custo) as total
      FROM ${AppConstants.tableProdutos}
      WHERE ativo = 1
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getSugestoesReposicao() async {
    final maps = await _db.rawQuery('''
      SELECT 
        p.id,
        p.nome,
        p.quantidade as estoque_atual,
        p.estoque_minimo,
        COALESCE(SUM(CASE WHEN m.tipo = 'saida' THEN m.quantidade ELSE 0 END), 0) as saidas_30dias
      FROM ${AppConstants.tableProdutos} p
      LEFT JOIN ${AppConstants.tableMovimentosEstoque} m 
        ON p.id = m.produto_id 
        AND m.data >= date('now', '-30 days')
        AND m.tipo = 'saida'
      WHERE p.ativo = 1
      GROUP BY p.id
      HAVING p.quantidade <= p.estoque_minimo 
          OR (saidas_30dias > 0 AND p.quantidade < (saidas_30dias * 1.5))
      ORDER BY (p.quantidade - p.estoque_minimo) ASC
    ''');

    return maps.map((m) {
      final saidas = (m['saidas_30dias'] as num?)?.toInt() ?? 0;
      final estoqueAtual = (m['estoque_atual'] as num?)?.toInt() ?? 0;
      final estoqueMinimo = (m['estoque_minimo'] as num?)?.toInt() ?? 3;
      final sugestao = saidas > 0
          ? (saidas * 1.5).ceil() - estoqueAtual
          : estoqueMinimo - estoqueAtual + 2;
      return {
        ...m,
        'quantidade_sugerida': sugestao < 1 ? 1 : sugestao,
      };
    }).toList();
  }

  Future<void> _syncFromFirestoreIfOnline() async {
    if (!await _isFirebaseOnline()) return;
    await _syncPendingLocalProdutosIfOnline();

    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return;

    final snap = await _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableProdutos)
        .orderBy('nome')
        .get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final existing = await _db.queryAll(
        AppConstants.tableProdutos,
        where: 'firebase_id = ?',
        whereArgs: [doc.id],
        limit: 1,
      );

      final map = <String, dynamic>{
        'firebase_id': doc.id,
        'barbearia_id': (data['barbearia_id'] as String?) ?? shopId,
        'created_by': data['created_by'] as String?,
        'nome': (data['nome'] ?? '') as String,
        'preco_venda': (data['preco_venda'] as num?)?.toDouble() ?? 0.0,
        'preco_custo': (data['preco_custo'] as num?)?.toDouble() ?? 0.0,
        'quantidade': (data['quantidade'] as num?)?.toInt() ?? 0,
        'estoque_minimo': (data['estoque_minimo'] as num?)?.toInt() ?? 3,
        'comissao_percentual':
            (data['comissao_percentual'] as num?)?.toDouble() ?? 0.20,
        'fornecedor_id': (data['fornecedor_id'] as num?)?.toInt(),
        'ativo': ((data['ativo'] as bool?) ?? true) ? 1 : 0,
        'created_at': data['created_at'] is Timestamp
            ? (data['created_at'] as Timestamp).toDate().toIso8601String()
            : DateTime.now().toIso8601String(),
        'updated_at': data['updated_at'] is Timestamp
            ? (data['updated_at'] as Timestamp).toDate().toIso8601String()
            : DateTime.now().toIso8601String(),
      };

      if (existing.isEmpty) {
        await _db.insert(
          AppConstants.tableProdutos,
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await _db.update(
          AppConstants.tableProdutos,
          map,
          'id = ?',
          [existing.first['id']],
        );
      }
    }
  }

  Future<void> _syncPendingLocalProdutosIfOnline() async {
    if (!await _isFirebaseOnline()) return;
    final rows = await _db.queryAll(
      AppConstants.tableProdutos,
      orderBy: 'updated_at DESC',
    );
    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      if (id == null) continue;
      await _syncProdutoAndLastMovimentoIfOnline(id);
    }
  }

  Future<void> _syncProdutoAndLastMovimentoIfOnline(int produtoId) async {
    if (!await _isFirebaseOnline()) return;

    final shopId = await _context.getBarbeariaIdAtual();
    final uid = _auth.currentUser?.uid;
    if (shopId == null || uid == null) return;

    final produtoRows = await _db.queryAll(
      AppConstants.tableProdutos,
      where: 'id = ?',
      whereArgs: [produtoId],
      limit: 1,
    );
    if (produtoRows.isEmpty) return;
    final produto = produtoRows.first;
    String? firebaseId = produto['firebase_id'] as String?;
    if (firebaseId == null || firebaseId.trim().isEmpty) {
      firebaseId = _uuid.v4();
      await _db.update(
        AppConstants.tableProdutos,
        {
          'firebase_id': firebaseId,
          'barbearia_id': shopId,
          'created_by': uid,
        },
        'id = ?',
        [produtoId],
      );
    }

    await _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableProdutos)
        .doc(firebaseId)
        .set({
      'nome': produto['nome'],
      'preco_venda': (produto['preco_venda'] as num?)?.toDouble() ?? 0.0,
      'preco_custo': (produto['preco_custo'] as num?)?.toDouble() ?? 0.0,
      'quantidade': (produto['quantidade'] as num?)?.toInt() ?? 0,
      'estoque_minimo': (produto['estoque_minimo'] as num?)?.toInt() ?? 3,
      'comissao_percentual':
          (produto['comissao_percentual'] as num?)?.toDouble() ?? 0.0,
      'fornecedor_id': (produto['fornecedor_id'] as num?)?.toInt(),
      'ativo': ((produto['ativo'] as num?)?.toInt() ?? 1) == 1,
      'barbearia_id': shopId,
      'created_by': uid,
      'updated_at': FieldValue.serverTimestamp(),
      if (produto['created_at'] == null)
        'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final movimentos = await _db.queryAll(
      AppConstants.tableMovimentosEstoque,
      where: 'produto_id = ?',
      whereArgs: [produtoId],
      orderBy: 'data DESC',
      limit: 1,
    );
    if (movimentos.isEmpty) return;
    final mov = movimentos.first;
    final movFirebaseId =
        (mov['firebase_id'] as String?)?.trim().isNotEmpty == true
            ? mov['firebase_id'] as String
            : _uuid.v4();

    await _context
        .collection(
          barbeariaId: shopId,
          nome: _estoqueCollection,
        )
        .doc(movFirebaseId)
        .set({
      'produto_id': produtoId,
      'produto_nome': mov['produto_nome'],
      'tipo': mov['tipo'],
      'quantidade': (mov['quantidade'] as num?)?.toInt() ?? 0,
      'valor_unitario': (mov['valor_unitario'] as num?)?.toDouble() ?? 0.0,
      'data': mov['data'],
      'observacao': mov['observacao'],
      'barbearia_id': shopId,
      'created_by': uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.update(
      AppConstants.tableMovimentosEstoque,
      {'firebase_id': movFirebaseId, 'barbearia_id': shopId, 'created_by': uid},
      'id = ?',
      [mov['id']],
    );
  }

  Future<String?> _barbeariaIdParaFiltro() async {
    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return null;
    if (shopId == AppConstants.localBarbeariaId) return null;
    return shopId;
  }

  Produto _sanitizarProduto(Produto produto) {
    final safeNome =
        SecurityUtils.sanitizeName(produto.nome, fieldName: 'Nome do produto');
    final safePrecoVenda = SecurityUtils.sanitizeDoubleRange(
      produto.precoVenda,
      fieldName: 'Preco de venda',
      min: 0.01,
      max: 999999,
    );
    final safePrecoCusto = SecurityUtils.sanitizeDoubleRange(
      produto.precoCusto,
      fieldName: 'Preco de custo',
      min: 0,
      max: 999999,
    );
    final safeQuantidade = SecurityUtils.sanitizeIntRange(
      produto.quantidade,
      fieldName: 'Quantidade em estoque',
      min: 0,
      max: 1000000,
    );
    final safeEstoqueMinimo = SecurityUtils.sanitizeIntRange(
      produto.estoqueMinimo,
      fieldName: 'Estoque minimo',
      min: 0,
      max: 1000000,
    );
    final comissaoNormalizada = produto.comissaoPercentual > 1
        ? produto.comissaoPercentual / 100
        : produto.comissaoPercentual;
    final safeComissao = SecurityUtils.sanitizeDoubleRange(
      comissaoNormalizada,
      fieldName: 'Comissao',
      min: 0,
      max: 1,
    );

    return produto.copyWith(
      nome: safeNome,
      precoVenda: safePrecoVenda,
      precoCusto: safePrecoCusto,
      quantidade: safeQuantidade,
      estoqueMinimo: safeEstoqueMinimo,
      comissaoPercentual: safeComissao,
    );
  }

  Fornecedor _sanitizarFornecedor(Fornecedor fornecedor) {
    final safeNome = SecurityUtils.sanitizeName(
      fornecedor.nome,
      fieldName: 'Nome do fornecedor',
    );
    final safeTelefone = fornecedor.telefone == null
        ? null
        : SecurityUtils.sanitizePhone(fornecedor.telefone!);
    final safeEmail = SecurityUtils.sanitizeOptionalText(
      fornecedor.email,
      maxLength: 120,
      allowNewLines: false,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      fornecedor.observacoes,
      maxLength: 500,
      allowNewLines: true,
    );

    return fornecedor.copyWith(
      nome: safeNome,
      telefone: safeTelefone,
      email: safeEmail,
      observacoes: safeObs,
    );
  }
}
