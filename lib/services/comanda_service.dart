import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/comanda.dart';
import '../models/item_comanda.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'cliente_service.dart';
import 'connectivity_service.dart';
import 'firebase_context_service.dart';
import 'produto_service.dart';
import 'service_exceptions.dart';

class ComandaService {
  static const String _comandaItensSubcollection = 'itens';
  static const String _legacyComandaItensSubcollection =
      AppConstants.tableComandasItens;

  final DatabaseHelper _db = DatabaseHelper();
  final ProdutoService _produtoService = ProdutoService();
  final ClienteService _clienteService = ClienteService();
  final FirebaseContextService _context = FirebaseContextService();
  final ConnectivityService _connectivity = ConnectivityService();
  final Uuid _uuid = const Uuid();

  bool get _firebaseDisponivel => _context.firebaseDisponivel;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<bool> _isFirebaseOnline() async {
    if (!_firebaseDisponivel) return false;
    return _connectivity.isOnline();
  }

  Future<List<Comanda>> getAll({String? barbeiroId, String? status}) async {
    await _syncFromFirestoreIfOnline();

    final safeBarbeiroId = barbeiroId == null
        ? null
        : SecurityUtils.sanitizeIdentifier(
            barbeiroId,
            fieldName: 'ID do barbeiro',
            minLength: 1,
          );
    final safeStatus = status == null
        ? null
        : SecurityUtils.sanitizeEnumValue(
            status,
            fieldName: 'Status da comanda',
            allowedValues: const [
              AppConstants.comandaAberta,
              AppConstants.comandaFechada,
              AppConstants.comandaCancelada,
            ],
          );

    String? where;
    List<dynamic>? whereArgs;
    if (safeBarbeiroId != null && safeStatus != null) {
      where = 'barbeiro_id = ? AND status = ?';
      whereArgs = [safeBarbeiroId, safeStatus];
    } else if (safeBarbeiroId != null) {
      where = 'barbeiro_id = ?';
      whereArgs = [safeBarbeiroId];
    } else if (safeStatus != null) {
      where = 'status = ?';
      whereArgs = [safeStatus];
    }

    final maps = await _db.queryAll(
      AppConstants.tableComandas,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'data_abertura DESC',
    );
    final comandas = maps.map((m) => Comanda.fromMap(m)).toList();
    return _anexarItens(comandas);
  }

  Future<Comanda?> getById(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID da comanda',
      min: 1,
      max: 1 << 30,
    );
    await _syncFromFirestoreIfOnline();

    final maps = await _db.queryAll(
      AppConstants.tableComandas,
      where: 'id = ?',
      whereArgs: [safeId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final comanda = Comanda.fromMap(maps.first);
    final itens = await _getItensByComandas([safeId]);
    return comanda.copyWith(itens: itens[safeId] ?? const []);
  }

  Future<Comanda?> getComandaAberta({String? barbeiroId}) async {
    await _syncFromFirestoreIfOnline();

    final safeBarbeiroId = barbeiroId == null
        ? null
        : SecurityUtils.sanitizeIdentifier(
            barbeiroId,
            fieldName: 'ID do barbeiro',
            minLength: 1,
          );

    final where = safeBarbeiroId != null
        ? 'status = ? AND barbeiro_id = ?'
        : 'status = ?';
    final whereArgs = safeBarbeiroId != null
        ? [AppConstants.comandaAberta, safeBarbeiroId]
        : [AppConstants.comandaAberta];

    final maps = await _db.queryAll(
      AppConstants.tableComandas,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'data_abertura DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final comanda = Comanda.fromMap(maps.first);
    final itens = await _getItensByComandas([comanda.id!]);
    return comanda.copyWith(itens: itens[comanda.id!] ?? const []);
  }

  Future<List<Comanda>> getComandasHoje({String? barbeiroId}) async {
    await _syncFromFirestoreIfOnline();

    final hoje = DateTime.now();
    final inicio = DateTime(hoje.year, hoje.month, hoje.day).toIso8601String();
    final fim =
        DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59).toIso8601String();

    var where = 'data_abertura BETWEEN ? AND ?';
    final whereArgs = <dynamic>[inicio, fim];

    if (barbeiroId != null) {
      final safeBarbeiroId = SecurityUtils.sanitizeIdentifier(
        barbeiroId,
        fieldName: 'ID do barbeiro',
        minLength: 1,
      );
      where += ' AND barbeiro_id = ?';
      whereArgs.add(safeBarbeiroId);
    }

    final maps = await _db.queryAll(
      AppConstants.tableComandas,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'data_abertura DESC',
    );
    return maps.map((m) => Comanda.fromMap(m)).toList();
  }

  Future<Comanda> abrirComanda({
    int? clienteId,
    required String clienteNome,
    String? barbeiroId,
    String? barbeiroNome,
    String? observacoes,
  }) async {
    if (clienteId != null) {
      SecurityUtils.sanitizeIntRange(
        clienteId,
        fieldName: 'ID do cliente',
        min: 1,
        max: 1 << 30,
      );
    }
    final safeClienteNome = SecurityUtils.sanitizeName(
      clienteNome,
      fieldName: 'Nome do cliente',
    );
    final safeBarbeiroId = barbeiroId == null
        ? null
        : SecurityUtils.sanitizeIdentifier(
            barbeiroId,
            fieldName: 'ID do barbeiro',
            minLength: 1,
          );
    final safeBarbeiroNome = barbeiroNome == null
        ? null
        : SecurityUtils.sanitizeName(
            barbeiroNome,
            fieldName: 'Nome do barbeiro',
          );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      observacoes,
      maxLength: 500,
      allowNewLines: true,
    );

    final comanda = Comanda(
      clienteId: clienteId,
      clienteNome: safeClienteNome,
      barbeiroId: safeBarbeiroId,
      barbeiroNome: safeBarbeiroNome,
      status: AppConstants.comandaAberta,
      dataAbertura: DateTime.now(),
      observacoes: safeObs,
    );

    final localMap = <String, dynamic>{
      ...comanda.toMap(),
      'barbeiro_uid': safeBarbeiroId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (await _isFirebaseOnline()) {
      final shopId = await _context.getBarbeariaIdAtual();
      final uid = _auth.currentUser?.uid;
      if (shopId != null && uid != null) {
        final firebaseId = _uuid.v4();
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableComandas)
            .doc(firebaseId)
            .set({
          'cliente_id': clienteId,
          'cliente_nome': safeClienteNome,
          'barbeiro_id': safeBarbeiroId,
          'barbeiro_nome': safeBarbeiroNome,
          'barbeiro_uid': safeBarbeiroId,
          'status': AppConstants.comandaAberta,
          'total': 0.0,
          'comissao_total': 0.0,
          'forma_pagamento': null,
          'data_abertura': comanda.dataAbertura.toIso8601String(),
          'data_fechamento': null,
          'observacoes': safeObs,
          'barbearia_id': shopId,
          'created_by': uid,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        localMap['firebase_id'] = firebaseId;
        localMap['barbearia_id'] = shopId;
        localMap['created_by'] = uid;
      }
    }

    final id = await _db.insert(AppConstants.tableComandas, localMap);
    return comanda.copyWith(id: id);
  }

  Future<void> adicionarItem(int comandaId, ItemComanda item) async {
    final safeComandaId = SecurityUtils.sanitizeIntRange(
      comandaId,
      fieldName: 'ID da comanda',
      min: 1,
      max: 1 << 30,
    );
    final safeItem = _sanitizarItem(item);

    await _db.transaction((txn) async {
      final comandaRows = await txn.query(
        AppConstants.tableComandas,
        columns: ['id', 'status', 'barbeiro_id'],
        where: 'id = ?',
        whereArgs: [safeComandaId],
        limit: 1,
      );
      if (comandaRows.isEmpty) {
        throw const NotFoundException('Comanda não encontrada.');
      }
      final status = comandaRows.first['status'] as String? ?? '';
      if (status != AppConstants.comandaAberta) {
        throw const ConflictException(
          'Nao e possivel adicionar itens em comanda fechada/cancelada.',
        );
      }
      final barbeiroId = comandaRows.first['barbeiro_id'] as String?;
      final comissaoFinal = await _resolverComissaoPercentual(
        txn,
        barbeiroId: barbeiroId,
        fallback: safeItem.comissaoPercentual,
      );

      await txn.insert(
        AppConstants.tableComandasItens,
        {
          ...safeItem
              .copyWith(
                comandaId: safeComandaId,
                comissaoPercentual: comissaoFinal,
              )
              .toMap(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      final totais = await _calcularTotaisComanda(txn, safeComandaId);
      await txn.update(
        AppConstants.tableComandas,
        {
          'total': totais.total,
          'comissao_total': totais.comissaoTotal,
        },
        where: 'id = ?',
        whereArgs: [safeComandaId],
      );
    });
    await _syncComandaByLocalIdIfOnline(safeComandaId);
  }

  Future<void> removerItem(int comandaId, int itemId) async {
    final safeComandaId = SecurityUtils.sanitizeIntRange(
      comandaId,
      fieldName: 'ID da comanda',
      min: 1,
      max: 1 << 30,
    );
    final safeItemId = SecurityUtils.sanitizeIntRange(
      itemId,
      fieldName: 'ID do item',
      min: 1,
      max: 1 << 30,
    );

    await _db.transaction((txn) async {
      final comandaRows = await txn.query(
        AppConstants.tableComandas,
        columns: ['id', 'status'],
        where: 'id = ?',
        whereArgs: [safeComandaId],
        limit: 1,
      );
      if (comandaRows.isEmpty) {
        throw const NotFoundException('Comanda não encontrada.');
      }
      final status = comandaRows.first['status'] as String? ?? '';
      if (status != AppConstants.comandaAberta) {
        throw const ConflictException(
          'Nao e possivel remover itens em comanda fechada/cancelada.',
        );
      }

      await txn.delete(
        AppConstants.tableComandasItens,
        where: 'id = ? AND comanda_id = ?',
        whereArgs: [safeItemId, safeComandaId],
      );

      final totais = await _calcularTotaisComanda(txn, safeComandaId);
      await txn.update(
        AppConstants.tableComandas,
        {
          'total': totais.total,
          'comissao_total': totais.comissaoTotal,
        },
        where: 'id = ?',
        whereArgs: [safeComandaId],
      );
    });
    await _syncComandaByLocalIdIfOnline(safeComandaId);
  }

  Future<void> fecharComanda({
    required int comandaId,
    required String formaPagamento,
    String? observacoes,
  }) async {
    final safeComandaId = SecurityUtils.sanitizeIntRange(
      comandaId,
      fieldName: 'ID da comanda',
      min: 1,
      max: 1 << 30,
    );
    final safeFormaPagamento = SecurityUtils.sanitizeEnumValue(
      formaPagamento,
      fieldName: 'Forma de pagamento',
      allowedValues: AppConstants.formasPagamento,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      observacoes,
      maxLength: 500,
      allowNewLines: true,
    );

    final agora = DateTime.now();
    final produtosAbaixados = <int>{};
    await _db.transaction((txn) async {
      final comandaRows = await txn.query(
        AppConstants.tableComandas,
        where: 'id = ?',
        whereArgs: [safeComandaId],
        limit: 1,
      );
      if (comandaRows.isEmpty) {
        throw const NotFoundException('Comanda não encontrada.');
      }

      final comanda = Comanda.fromMap(comandaRows.first);
      if (comanda.status != AppConstants.comandaAberta) {
        throw const ConflictException(
            'Comanda não está aberta para fechamento.');
      }

      final itensRows = await txn.query(
        AppConstants.tableComandasItens,
        where: 'comanda_id = ?',
        whereArgs: [safeComandaId],
        orderBy: 'id ASC',
      );
      final itens = itensRows.map((m) => ItemComanda.fromMap(m)).toList();
      if (itens.isEmpty) {
        throw const ValidationException(
          'Comanda sem itens não pode ser fechada.',
        );
      }

      final total = itens.fold<double>(0, (s, i) => s + i.subtotal);
      final comissao = itens.fold<double>(0, (s, i) => s + i.comissaoValor);

      for (final item in itens) {
        if (item.tipo != 'produto') continue;
        produtosAbaixados.add(item.itemId);
        await _produtoService.baixarEstoqueComExecutor(
          executor: txn,
          produtoId: item.itemId,
          quantidade: item.quantidade,
          valorUnitario: item.precoUnitario,
          observacao: 'Comanda #$safeComandaId',
        );
      }

      if (comanda.clienteId != null) {
        await _clienteService.atualizarAposAtendimento(
          comanda.clienteId!,
          total,
          executor: txn,
        );
      }

      final updatedRows = await txn.update(
        AppConstants.tableComandas,
        {
          'status': AppConstants.comandaFechada,
          'total': total,
          'comissao_total': comissao,
          'forma_pagamento': safeFormaPagamento,
          'data_fechamento': agora.toIso8601String(),
          'updated_at': agora.toIso8601String(),
          if (safeObs != null) 'observacoes': safeObs,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [safeComandaId, AppConstants.comandaAberta],
      );
      if (updatedRows == 0) {
        throw const ConflictException(
          'Comanda foi alterada por outro processo.',
        );
      }

      if (comanda.barbeiroId != null && comissao > 0) {
        final comandaRow = comandaRows.first;
        await txn.insert(AppConstants.tableComissoes, {
          'firebase_id': _uuid.v4(),
          'barbearia_id': comandaRow['barbearia_id'],
          'created_by': comandaRow['created_by'],
          'barbeiro_id': comanda.barbeiroId,
          'barbeiro_nome': comanda.barbeiroNome ?? 'Barbeiro',
          'comanda_id': safeComandaId,
          'valor': comissao,
          'data': agora.toIso8601String(),
          'status': 'pendente',
        });
      }
    });
    await _syncComandaByLocalIdIfOnline(safeComandaId);
    for (final produtoId in produtosAbaixados) {
      await _produtoService.syncProdutoByIdIfOnline(produtoId);
    }
  }

  Future<void> cancelarComanda(int comandaId) async {
    final safeComandaId = SecurityUtils.sanitizeIntRange(
      comandaId,
      fieldName: 'ID da comanda',
      min: 1,
      max: 1 << 30,
    );
    final updated = await _db.update(
      AppConstants.tableComandas,
      {
        'status': AppConstants.comandaCancelada,
        'data_fechamento': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      'id = ? AND status = ?',
      [safeComandaId, AppConstants.comandaAberta],
    );
    if (updated == 0) {
      throw const ConflictException(
        'Somente comanda aberta pode ser cancelada.',
      );
    }
    await _syncComandaByLocalIdIfOnline(safeComandaId);
  }

  Future<double> getFaturamentoBarbeiro(
    String barbeiroId,
    DateTime inicio,
    DateTime fim,
  ) async {
    final safeBarbeiroId = SecurityUtils.sanitizeIdentifier(
      barbeiroId,
      fieldName: 'ID do barbeiro',
      minLength: 1,
    );
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    await _syncFromFirestoreIfOnline();

    final result = await _db.rawQuery('''
      SELECT SUM(total) as total
      FROM ${AppConstants.tableComandas}
      WHERE barbeiro_id = ?
        AND status = 'fechada'
        AND COALESCE(data_fechamento, data_abertura) BETWEEN ? AND ?
    ''', [safeBarbeiroId, inicio.toIso8601String(), fim.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getComissaoBarbeiro(
    String barbeiroId,
    DateTime inicio,
    DateTime fim,
  ) async {
    final safeBarbeiroId = SecurityUtils.sanitizeIdentifier(
      barbeiroId,
      fieldName: 'ID do barbeiro',
      minLength: 1,
    );
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    await _syncFromFirestoreIfOnline();

    final result = await _db.rawQuery('''
      SELECT SUM(comissao_total) as total
      FROM ${AppConstants.tableComandas}
      WHERE barbeiro_id = ?
        AND status = 'fechada'
        AND COALESCE(data_fechamento, data_abertura) BETWEEN ? AND ?
    ''', [safeBarbeiroId, inicio.toIso8601String(), fim.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getRankingBarbeiros(
    DateTime inicio,
    DateTime fim,
  ) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    await _syncFromFirestoreIfOnline();
    return _db.rawQuery('''
      SELECT
        c.barbeiro_id,
        c.barbeiro_nome,
        COUNT(*) as total_comandas,
        SUM(c.total) as faturamento,
        SUM(c.comissao_total) as comissao,
        MAX(u.comissao_percentual) as comissao_percentual
      FROM ${AppConstants.tableComandas} c
      LEFT JOIN ${AppConstants.tableUsuarios} u
        ON u.id = c.barbeiro_id
      WHERE c.status = 'fechada'
        AND COALESCE(c.data_fechamento, c.data_abertura) BETWEEN ? AND ?
        AND c.barbeiro_id IS NOT NULL
      GROUP BY c.barbeiro_id
      ORDER BY faturamento DESC
    ''', [inicio.toIso8601String(), fim.toIso8601String()]);
  }

  Future<int> getCountComandasAbertas() async {
    await _syncFromFirestoreIfOnline();
    final result = await _db.rawQuery('''
      SELECT COUNT(*) as total FROM ${AppConstants.tableComandas}
      WHERE status = 'aberta'
    ''');
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<double> getFaturamentoPeriodo(
    DateTime inicio,
    DateTime fim, {
    String? barbeiroId,
  }) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    final safeBarbeiroId = barbeiroId == null
        ? null
        : SecurityUtils.sanitizeIdentifier(
            barbeiroId,
            fieldName: 'ID do barbeiro',
            minLength: 1,
          );
    await _syncFromFirestoreIfOnline();

    final whereArgs = <dynamic>[
      inicio.toIso8601String(),
      fim.toIso8601String()
    ];
    final whereBarbeiro = safeBarbeiroId == null ? '' : ' AND barbeiro_id = ?';
    if (safeBarbeiroId != null) {
      whereArgs.add(safeBarbeiroId);
    }

    final result = await _db.rawQuery('''
      SELECT SUM(total) as total
      FROM ${AppConstants.tableComandas}
      WHERE status = 'fechada'
        AND COALESCE(data_fechamento, data_abertura) BETWEEN ? AND ?
        $whereBarbeiro
    ''', whereArgs);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getCountComandasFechadasPeriodo(
    DateTime inicio,
    DateTime fim, {
    String? barbeiroId,
  }) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    final safeBarbeiroId = barbeiroId == null
        ? null
        : SecurityUtils.sanitizeIdentifier(
            barbeiroId,
            fieldName: 'ID do barbeiro',
            minLength: 1,
          );
    await _syncFromFirestoreIfOnline();

    final whereArgs = <dynamic>[
      inicio.toIso8601String(),
      fim.toIso8601String()
    ];
    final whereBarbeiro = safeBarbeiroId == null ? '' : ' AND barbeiro_id = ?';
    if (safeBarbeiroId != null) {
      whereArgs.add(safeBarbeiroId);
    }

    final result = await _db.rawQuery('''
      SELECT COUNT(*) as total
      FROM ${AppConstants.tableComandas}
      WHERE status = 'fechada'
        AND COALESCE(data_fechamento, data_abertura) BETWEEN ? AND ?
        $whereBarbeiro
    ''', whereArgs);
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getFaturamentoPorDia(
    int dias, {
    String? barbeiroId,
  }) async {
    final safeDias = SecurityUtils.sanitizeIntRange(
      dias,
      fieldName: 'Quantidade de dias',
      min: 1,
      max: 3650,
    );
    final safeBarbeiroId = barbeiroId == null
        ? null
        : SecurityUtils.sanitizeIdentifier(
            barbeiroId,
            fieldName: 'ID do barbeiro',
            minLength: 1,
          );
    await _syncFromFirestoreIfOnline();

    final inicio =
        DateTime.now().subtract(Duration(days: safeDias)).toIso8601String();
    final whereArgs = <dynamic>[inicio];
    final whereBarbeiro = safeBarbeiroId == null ? '' : ' AND barbeiro_id = ?';
    if (safeBarbeiroId != null) {
      whereArgs.add(safeBarbeiroId);
    }

    return _db.rawQuery('''
      SELECT 
        DATE(COALESCE(data_fechamento, data_abertura)) as dia,
        SUM(total) as total,
        COUNT(*) as quantidade
      FROM ${AppConstants.tableComandas}
      WHERE status = 'fechada'
        AND COALESCE(data_fechamento, data_abertura) >= ?
        $whereBarbeiro
      GROUP BY DATE(COALESCE(data_fechamento, data_abertura))
      ORDER BY dia ASC
    ''', whereArgs);
  }

  Future<Map<String, double>> getFaturamentoPorPagamento(
    DateTime inicio,
    DateTime fim, {
    String? barbeiroId,
  }) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    final safeBarbeiroId = barbeiroId == null
        ? null
        : SecurityUtils.sanitizeIdentifier(
            barbeiroId,
            fieldName: 'ID do barbeiro',
            minLength: 1,
          );
    await _syncFromFirestoreIfOnline();

    final whereArgs = <dynamic>[
      inicio.toIso8601String(),
      fim.toIso8601String()
    ];
    final whereBarbeiro = safeBarbeiroId == null ? '' : ' AND barbeiro_id = ?';
    if (safeBarbeiroId != null) {
      whereArgs.add(safeBarbeiroId);
    }

    final result = await _db.rawQuery('''
      SELECT forma_pagamento, SUM(total) as total
      FROM ${AppConstants.tableComandas}
      WHERE status = 'fechada'
        AND COALESCE(data_fechamento, data_abertura) BETWEEN ? AND ?
        $whereBarbeiro
      GROUP BY forma_pagamento
    ''', whereArgs);

    return {
      for (final row in result)
        (row['forma_pagamento'] as String?) ?? AppConstants.pgDinheiro:
            (row['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<List<Comanda>> _anexarItens(List<Comanda> comandas) async {
    if (comandas.isEmpty) return comandas;
    final ids = comandas.map((c) => c.id).whereType<int>().toList();
    final itensPorComanda = await _getItensByComandas(ids);

    return comandas
        .map((c) => c.copyWith(itens: itensPorComanda[c.id] ?? const []))
        .toList(growable: false);
  }

  Future<Map<int, List<ItemComanda>>> _getItensByComandas(
    List<int> comandaIds,
  ) async {
    if (comandaIds.isEmpty) return <int, List<ItemComanda>>{};

    final placeholders = List.filled(comandaIds.length, '?').join(', ');
    final rows = await _db.rawQuery('''
      SELECT *
      FROM ${AppConstants.tableComandasItens}
      WHERE comanda_id IN ($placeholders)
      ORDER BY id ASC
    ''', comandaIds);

    final result = <int, List<ItemComanda>>{};
    for (final row in rows) {
      final item = ItemComanda.fromMap(row);
      final comandaId = item.comandaId;
      if (comandaId == null) continue;
      (result[comandaId] ??= <ItemComanda>[]).add(item);
    }
    return result;
  }

  Future<void> _syncFromFirestoreIfOnline() async {
    if (!await _isFirebaseOnline()) return;
    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return;
    await _syncPendingLocalComandasIfOnline();

    final comandasSnap = await _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableComandas)
        .orderBy('data_abertura', descending: true)
        .get();

    for (final doc in comandasSnap.docs) {
      final data = doc.data();
      final existing = await _db.queryAll(
        AppConstants.tableComandas,
        where: 'firebase_id = ?',
        whereArgs: [doc.id],
        limit: 1,
      );

      final map = <String, dynamic>{
        'firebase_id': doc.id,
        'barbearia_id': (data['barbearia_id'] as String?) ?? shopId,
        'created_by': data['created_by'] as String?,
        'cliente_id': (data['cliente_id'] as num?)?.toInt(),
        'cliente_nome': (data['cliente_nome'] ?? '') as String,
        'barbeiro_id': data['barbeiro_id'] as String?,
        'barbeiro_nome': data['barbeiro_nome'] as String?,
        'barbeiro_uid': data['barbeiro_uid'] as String?,
        'status': (data['status'] ?? AppConstants.comandaAberta) as String,
        'total': (data['total'] as num?)?.toDouble() ?? 0.0,
        'comissao_total': (data['comissao_total'] as num?)?.toDouble() ?? 0.0,
        'forma_pagamento': data['forma_pagamento'] as String?,
        'data_abertura': _normalizeDate(data['data_abertura']),
        'data_fechamento': _normalizeOptionalDate(data['data_fechamento']),
        'observacoes': data['observacoes'] as String?,
        'updated_at': _normalizeDate(data['updated_at']),
      };

      int localComandaId;
      if (existing.isEmpty) {
        localComandaId = await _db.insert(AppConstants.tableComandas, map);
      } else {
        localComandaId = (existing.first['id'] as num).toInt();
        await _db.update(
          AppConstants.tableComandas,
          map,
          'id = ?',
          [localComandaId],
        );
      }

      final comandaRef = _context
          .collection(barbeariaId: shopId, nome: AppConstants.tableComandas)
          .doc(doc.id);
      final itensSnap = await _getItensSnapshot(comandaRef);
      for (final itemDoc in itensSnap.docs) {
        final itemData = itemDoc.data();
        final existingItem = await _db.queryAll(
          AppConstants.tableComandasItens,
          where: 'firebase_id = ?',
          whereArgs: [itemDoc.id],
          limit: 1,
        );
        final itemMap = <String, dynamic>{
          'firebase_id': itemDoc.id,
          'barbearia_id': (itemData['barbearia_id'] as String?) ?? shopId,
          'created_by': itemData['created_by'] as String?,
          'comanda_id': localComandaId,
          'tipo': (itemData['tipo'] ?? 'servico') as String,
          'item_id': (itemData['item_id'] as num?)?.toInt() ?? 0,
          'nome': (itemData['nome'] ?? '') as String,
          'quantidade': (itemData['quantidade'] as num?)?.toInt() ?? 1,
          'preco_unitario':
              (itemData['preco_unitario'] as num?)?.toDouble() ?? 0.0,
          'comissao_percentual':
              (itemData['comissao_percentual'] as num?)?.toDouble() ?? 0.0,
          'comissao_valor':
              (itemData['comissao_valor'] as num?)?.toDouble() ?? 0.0,
          'updated_at': _normalizeDate(itemData['updated_at']),
        };
        if (existingItem.isEmpty) {
          await _db.insert(AppConstants.tableComandasItens, itemMap);
        } else {
          await _db.update(
            AppConstants.tableComandasItens,
            itemMap,
            'id = ?',
            [existingItem.first['id']],
          );
        }
      }
    }
  }

  Future<void> _syncComandaByLocalIdIfOnline(int comandaId) async {
    if (!await _isFirebaseOnline()) return;

    final shopId = await _context.getBarbeariaIdAtual();
    final uid = _auth.currentUser?.uid;
    if (shopId == null || uid == null) return;

    final rows = await _db.queryAll(
      AppConstants.tableComandas,
      where: 'id = ?',
      whereArgs: [comandaId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final row = rows.first;

    String? firebaseId = row['firebase_id'] as String?;
    if (firebaseId == null || firebaseId.trim().isEmpty) {
      firebaseId = _uuid.v4();
      await _db.update(
        AppConstants.tableComandas,
        {'firebase_id': firebaseId, 'barbearia_id': shopId, 'created_by': uid},
        'id = ?',
        [comandaId],
      );
    }

    final comandaRef = _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableComandas)
        .doc(firebaseId);
    final createdBy = (row['created_by'] as String?)?.trim().isNotEmpty == true
        ? row['created_by'] as String
        : uid;

    await comandaRef.set({
      'cliente_id': row['cliente_id'],
      'cliente_nome': row['cliente_nome'],
      'barbeiro_id': row['barbeiro_id'],
      'barbeiro_nome': row['barbeiro_nome'],
      'barbeiro_uid': row['barbeiro_uid'] ?? row['barbeiro_id'],
      'status': row['status'],
      'total': (row['total'] as num?)?.toDouble() ?? 0.0,
      'comissao_total': (row['comissao_total'] as num?)?.toDouble() ?? 0.0,
      'forma_pagamento': row['forma_pagamento'],
      'data_abertura': row['data_abertura'],
      'data_fechamento': row['data_fechamento'],
      'observacoes': row['observacoes'],
      'barbearia_id': shopId,
      'created_by': createdBy,
      'updated_at': FieldValue.serverTimestamp(),
      if (row['created_at'] == null) 'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final itemRows = await _db.queryAll(
      AppConstants.tableComandasItens,
      where: 'comanda_id = ?',
      whereArgs: [comandaId],
      orderBy: 'id ASC',
    );

    final localFirebaseIds = <String>{};
    for (final item in itemRows) {
      String? itemFirebaseId = item['firebase_id'] as String?;
      if (itemFirebaseId == null || itemFirebaseId.trim().isEmpty) {
        itemFirebaseId = _uuid.v4();
        await _db.update(
          AppConstants.tableComandasItens,
          {
            'firebase_id': itemFirebaseId,
            'barbearia_id': shopId,
            'created_by': uid,
          },
          'id = ?',
          [item['id']],
        );
      }
      localFirebaseIds.add(itemFirebaseId);

      await comandaRef
          .collection(_comandaItensSubcollection)
          .doc(itemFirebaseId)
          .set({
        'tipo': item['tipo'],
        'item_id': item['item_id'],
        'nome': item['nome'],
        'quantidade': item['quantidade'],
        'preco_unitario': item['preco_unitario'],
        'comissao_percentual': item['comissao_percentual'],
        'comissao_valor': item['comissao_valor'],
        'barbearia_id': shopId,
        'created_by': uid,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final cloudItems =
        await comandaRef.collection(_comandaItensSubcollection).get();
    for (final cloudDoc in cloudItems.docs) {
      if (!localFirebaseIds.contains(cloudDoc.id)) {
        await cloudDoc.reference.delete();
      }
    }
  }

  Future<void> _syncPendingLocalComandasIfOnline() async {
    if (!await _isFirebaseOnline()) return;
    final rows = await _db.queryAll(
      AppConstants.tableComandas,
      orderBy: 'updated_at DESC',
    );
    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      if (id == null) continue;
      await _syncComandaByLocalIdIfOnline(id);
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getItensSnapshot(
    DocumentReference<Map<String, dynamic>> comandaRef,
  ) async {
    final itens = await comandaRef.collection(_comandaItensSubcollection).get();
    if (itens.docs.isNotEmpty) {
      return itens;
    }
    return comandaRef.collection(_legacyComandaItensSubcollection).get();
  }

  String _normalizeDate(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is String && value.trim().isNotEmpty) return value;
    return DateTime.now().toIso8601String();
  }

  String? _normalizeOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  Future<double> _resolverComissaoPercentual(
    DatabaseExecutor executor, {
    required String? barbeiroId,
    required double fallback,
  }) async {
    final fallbackSanitizado = fallback.clamp(0.0, 1.0).toDouble();
    if (barbeiroId == null || barbeiroId.trim().isEmpty) {
      return fallbackSanitizado;
    }

    final rows = await executor.query(
      AppConstants.tableUsuarios,
      columns: ['comissao_percentual'],
      where: 'id = ?',
      whereArgs: [barbeiroId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return fallbackSanitizado;
    }

    final valorRaw = (rows.first['comissao_percentual'] as num?)?.toDouble();
    if (valorRaw == null) {
      return fallbackSanitizado;
    }
    final escalaDecimal = valorRaw > 1 ? valorRaw / 100 : valorRaw;
    return escalaDecimal.clamp(0.0, 1.0).toDouble();
  }

  Future<_TotaisComanda> _calcularTotaisComanda(
    DatabaseExecutor txn,
    int comandaId,
  ) async {
    final rows = await txn.rawQuery('''
      SELECT 
        COALESCE(SUM(quantidade * preco_unitario), 0) as total,
        COALESCE(SUM(comissao_valor), 0) as comissao_total
      FROM ${AppConstants.tableComandasItens}
      WHERE comanda_id = ?
    ''', [comandaId]);

    final row = rows.first;
    return _TotaisComanda(
      total: (row['total'] as num?)?.toDouble() ?? 0.0,
      comissaoTotal: (row['comissao_total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ItemComanda _sanitizarItem(ItemComanda item) {
    final safeTipo = SecurityUtils.sanitizeEnumValue(
      item.tipo,
      fieldName: 'Tipo do item',
      allowedValues: const ['servico', 'produto'],
    );
    final safeItemId = SecurityUtils.sanitizeIntRange(
      item.itemId,
      fieldName: 'ID do item',
      min: 1,
      max: 1 << 30,
    );
    final safeNome = SecurityUtils.sanitizeName(
      item.nome,
      fieldName: 'Nome do item',
      maxLength: 120,
    );
    final safeQuantidade = SecurityUtils.sanitizeIntRange(
      item.quantidade,
      fieldName: 'Quantidade',
      min: 1,
      max: 1000,
    );
    final safePrecoUnitario = SecurityUtils.sanitizeDoubleRange(
      item.precoUnitario,
      fieldName: 'Preco unitario',
      min: 0.01,
      max: 999999,
    );
    final safeComissao = SecurityUtils.sanitizeDoubleRange(
      item.comissaoPercentual,
      fieldName: 'Comissao',
      min: 0,
      max: 1,
    );

    return ItemComanda(
      id: item.id,
      comandaId: item.comandaId,
      tipo: safeTipo,
      itemId: safeItemId,
      nome: safeNome,
      quantidade: safeQuantidade,
      precoUnitario: safePrecoUnitario,
      comissaoPercentual: safeComissao,
    );
  }
}

class _TotaisComanda {
  final double total;
  final double comissaoTotal;
  const _TotaisComanda({
    required this.total,
    required this.comissaoTotal,
  });
}
