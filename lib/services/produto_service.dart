import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/database_helper.dart';
import '../models/fornecedor.dart';
import '../models/movimento_estoque.dart';
import '../models/produto.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'service_exceptions.dart';

class ProdutoService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<Produto>> getAll({bool apenasAtivos = true}) async {
    final maps = await _db.rawQuery('''
      SELECT p.*, f.nome as fornecedor_nome
      FROM ${AppConstants.tableProdutos} p
      LEFT JOIN ${AppConstants.tableFornecedores} f ON p.fornecedor_id = f.id
      ${apenasAtivos ? "WHERE p.ativo = 1" : ""}
      ORDER BY p.nome ASC
    ''');
    return maps.map((m) => Produto.fromMap(m)).toList();
  }

  Future<Produto?> getById(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do produto',
      min: 1,
      max: 1 << 30,
    );
    final maps = await _db.rawQuery('''
      SELECT p.*, f.nome as fornecedor_nome
      FROM ${AppConstants.tableProdutos} p
      LEFT JOIN ${AppConstants.tableFornecedores} f ON p.fornecedor_id = f.id
      WHERE p.id = ?
      LIMIT 1
    ''', [safeId]);
    if (maps.isEmpty) return null;
    return Produto.fromMap(maps.first);
  }

  Future<int> insert(Produto produto) async {
    final safeProduto = _sanitizarProduto(produto);
    return _db.insert(AppConstants.tableProdutos, safeProduto.toMap());
  }

  Future<void> update(Produto produto) async {
    SecurityUtils.ensure(produto.id != null, 'ID do produto invalido.');
    final safeProduto = _sanitizarProduto(
      produto.copyWith(updatedAt: DateTime.now()),
    );
    await _db.update(
      AppConstants.tableProdutos,
      safeProduto.toMap(),
      'id = ?',
      [safeProduto.id],
    );
  }

  Future<void> delete(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do produto',
      min: 1,
      max: 1 << 30,
    );
    await _db.update(
      AppConstants.tableProdutos,
      {'ativo': 0},
      'id = ?',
      [safeId],
    );
  }

  Future<List<Produto>> getProdutosEstoqueBaixo() async {
    final maps = await _db.rawQuery('''
      SELECT p.*, f.nome as fornecedor_nome
      FROM ${AppConstants.tableProdutos} p
      LEFT JOIN ${AppConstants.tableFornecedores} f ON p.fornecedor_id = f.id
      WHERE p.ativo = 1 AND p.quantidade <= p.estoque_minimo
      ORDER BY p.quantidade ASC
    ''');
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
      throw const NotFoundException('Produto nao encontrado para estoque.');
    }

    final produtoRow = produtoRows.first;
    final ativo = (produtoRow['ativo'] as num?)?.toInt() ?? 0;
    if (ativo != 1) {
      throw const ConflictException('Produto inativo nao permite movimento.');
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
    final maps = await _db.queryAll(
      AppConstants.tableMovimentosEstoque,
      where: produtoId != null ? 'produto_id = ?' : null,
      whereArgs: produtoId != null ? [produtoId] : null,
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
    SecurityUtils.ensure(f.id != null, 'ID do fornecedor invalido.');
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
    return _db.rawQuery('''
      SELECT 
        ai.item_id,
        ai.nome,
        SUM(ai.quantidade) as total_vendas,
        SUM(ai.quantidade * ai.preco_unitario) as faturamento_total,
        p.preco_custo,
        (AVG(ai.preco_unitario) - p.preco_custo) as margem_unitaria,
        SUM(ai.quantidade) * (AVG(ai.preco_unitario) - p.preco_custo) as lucro_total
      FROM ${AppConstants.tableAtendimentoItens} ai
      JOIN ${AppConstants.tableProdutos} p ON ai.item_id = p.id
      WHERE ai.tipo = 'produto'
      GROUP BY ai.item_id, ai.nome
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
    final safeComissao = SecurityUtils.sanitizeDoubleRange(
      produto.comissaoPercentual,
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
    final safeEmail = fornecedor.email == null
        ? null
        : SecurityUtils.sanitizeEmail(fornecedor.email!);
    final safeObs = SecurityUtils.sanitizeOptionalText(
      fornecedor.observacoes,
      maxLength: 400,
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
