// ============================================================
// financeiro_service.dart
// ServiÃ§o financeiro com Firestore como fonte principal
// e SQLite como cache offline.
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/caixa.dart';
import '../models/despesa.dart';
import '../utils/constants.dart';
import '../utils/firebase_error_handler.dart';
import '../utils/security_utils.dart';
import 'comanda_service.dart';
import 'connectivity_service.dart';
import 'firebase_context_service.dart';
import 'service_exceptions.dart';

class FinanceiroService {
  FinanceiroService({
    DatabaseHelper? db,
    ComandaService? comandaService,
    FirebaseContextService? context,
    ConnectivityService? connectivity,
    Uuid? uuid,
  })  : _db = db ?? DatabaseHelper(),
        _comandaService = comandaService ?? ComandaService(),
        _context = context ?? FirebaseContextService(),
        _connectivity = connectivity ?? ConnectivityService(),
        _uuid = uuid ?? const Uuid();

  final DatabaseHelper _db;
  final ComandaService _comandaService;
  final FirebaseContextService _context;
  final ConnectivityService _connectivity;
  final Uuid _uuid;

  static final Set<String> _categoriasAceitas = {
    ...AppConstants.categoriasDespesa,
  };

  bool get _firebaseDisponivel => _context.firebaseDisponivel;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<bool> _isFirebaseOnline() async {
    if (!_firebaseDisponivel) return false;
    return _connectivity.isOnline();
  }

  Future<List<Despesa>> getDespesas({
    DateTime? inicio,
    DateTime? fim,
    int? limit,
    int? offset,
  }) async {
    _syncDespesasEmBackground();

    final whereParts = <String>[];
    final whereArgs = <dynamic>[];
    final shopIdFiltro = await _barbeariaIdParaFiltro();

    if (inicio != null && fim != null) {
      SecurityUtils.ensure(!fim.isBefore(inicio), 'PerÃ­odo invÃ¡lido.');
      whereParts.add('data BETWEEN ? AND ?');
      whereArgs.addAll([inicio.toIso8601String(), fim.toIso8601String()]);
    }
    if (shopIdFiltro != null) {
      whereParts.add('barbearia_id = ?');
      whereArgs.add(shopIdFiltro);
    }

    final maps = await _db.queryAll(
      AppConstants.tableDespesas,
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'data DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Despesa.fromMap(m)).toList(growable: false);
  }

  Future<int> insertDespesa(Despesa despesa) async {
    final safeDespesa = _sanitizarDespesa(despesa);
    final nowIso = DateTime.now().toIso8601String();
    final localMap = <String, dynamic>{
      ...safeDespesa.toMap(),
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    if (await _isFirebaseOnline()) {
      final shopId = await _context.getBarbeariaIdAtual();
      final uid = _auth.currentUser?.uid;
      if (shopId != null && uid != null) {
        final firebaseId = _uuid.v4();
        await FirebaseErrorHandler.wrap(() => _context
                .collection(
                    barbeariaId: shopId, nome: AppConstants.tableDespesas)
                .doc(firebaseId)
                .set({
              'descricao': safeDespesa.descricao,
              'categoria': safeDespesa.categoria,
              'valor': safeDespesa.valor,
              'data': Timestamp.fromDate(safeDespesa.data),
              'observacoes': safeDespesa.observacoes,
              'barbearia_id': shopId,
              'created_by': uid,
              'created_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
            }));

        localMap['firebase_id'] = firebaseId;
        localMap['barbearia_id'] = shopId;
        localMap['created_by'] = uid;
      }
    }

    return _db.insert(AppConstants.tableDespesas, localMap);
  }

  Future<void> updateDespesa(Despesa despesa) async {
    SecurityUtils.ensure(despesa.id != null, 'ID da despesa invÃ¡lido.');
    final safeDespesa = _sanitizarDespesa(despesa);

    if (await _isFirebaseOnline()) {
      await _syncDespesaByLocalIdIfOnline(safeDespesa.id!);

      final row = await _db.queryAll(
        AppConstants.tableDespesas,
        where: 'id = ?',
        whereArgs: [safeDespesa.id],
        limit: 1,
      );
      final firebaseId =
          row.isEmpty ? null : row.first['firebase_id'] as String?;
      final shopId = await _context.getBarbeariaIdAtual();
      final uid = _auth.currentUser?.uid;
      if (firebaseId != null && shopId != null && uid != null) {
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableDespesas)
            .doc(firebaseId)
            .set({
          'descricao': safeDespesa.descricao,
          'categoria': safeDespesa.categoria,
          'valor': safeDespesa.valor,
          'data': Timestamp.fromDate(safeDespesa.data),
          'observacoes': safeDespesa.observacoes,
          'barbearia_id': shopId,
          'created_by': row.first['created_by'] ?? uid,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await _db.update(
      AppConstants.tableDespesas,
      {
        ...safeDespesa.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      'id = ?',
      [safeDespesa.id],
    );
  }

  Future<void> deleteDespesa(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID da despesa',
      min: 1,
      max: 1 << 30,
    );

    if (await _isFirebaseOnline()) {
      final row = await _db.queryAll(
        AppConstants.tableDespesas,
        where: 'id = ?',
        whereArgs: [safeId],
        limit: 1,
      );
      final firebaseId =
          row.isEmpty ? null : row.first['firebase_id'] as String?;
      final shopId = await _context.getBarbeariaIdAtual();
      if (firebaseId != null && shopId != null) {
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableDespesas)
            .doc(firebaseId)
            .delete();
      }
    }

    await _db.delete(AppConstants.tableDespesas, 'id = ?', [safeId]);
  }

  Future<double> getTotalDespesas(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'PerÃ­odo invÃ¡lido.');
    _syncDespesasEmBackground();

    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[inicio.toIso8601String(), fim.toIso8601String()];
    if (shopIdFiltro != null) {
      args.add(shopIdFiltro);
    }

    final result = await _db.rawQuery('''
      SELECT SUM(valor) as total
      FROM ${AppConstants.tableDespesas}
      WHERE data BETWEEN ? AND ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
    ''', args);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getDespesasPorCategoria(
    DateTime inicio,
    DateTime fim,
  ) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'PerÃ­odo invÃ¡lido.');
    _syncDespesasEmBackground();

    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[inicio.toIso8601String(), fim.toIso8601String()];
    if (shopIdFiltro != null) {
      args.add(shopIdFiltro);
    }

    return _db.rawQuery('''
      SELECT categoria, SUM(valor) as total
      FROM ${AppConstants.tableDespesas}
      WHERE data BETWEEN ? AND ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
      GROUP BY categoria
      ORDER BY total DESC
    ''', args);
  }

  Future<Map<String, double>> getResumo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'PerÃ­odo invÃ¡lido.');

    // Faturamento via comandas (fluxo atual)
    final faturamentoComandas =
        await _comandaService.getFaturamentoPeriodo(inicio, fim);

    // Faturamento via atendimentos legados (prÃ©-comanda)
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final legadoArgs = <dynamic>[
      inicio.toIso8601String(),
      fim.toIso8601String(),
    ];
    if (shopIdFiltro != null) {
      legadoArgs.add(shopIdFiltro);
    }
    final legadoResult = await _db.rawQuery('''
      SELECT SUM(total) AS total
      FROM ${AppConstants.tableAtendimentos}
      WHERE data BETWEEN ? AND ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
    ''', legadoArgs);
    final faturamentoLegado =
        (legadoResult.first['total'] as num?)?.toDouble() ?? 0.0;

    final faturamento = faturamentoComandas + faturamentoLegado;
    final despesas = await getTotalDespesas(inicio, fim);
    final lucro = faturamento - despesas;

    return {
      'faturamento': faturamento,
      'despesas': despesas,
      'lucro': lucro,
    };
  }

  Future<Map<String, double>> getFaturamentoPorPagamento(
    DateTime inicio,
    DateTime fim,
  ) {
    return _comandaService.getFaturamentoPorPagamento(inicio, fim);
  }

  Future<Caixa?> getCaixaAberto() async {
    _syncCaixasEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();

    final maps = await _db.queryAll(
      AppConstants.tableCaixas,
      where: shopIdFiltro == null
          ? "status = 'aberto'"
          : "status = 'aberto' AND barbearia_id = ?",
      whereArgs: shopIdFiltro == null ? null : [shopIdFiltro],
      orderBy: 'data_abertura DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Caixa.fromMap(maps.first);
  }

  Future<Caixa?> getUltimoCaixa() async {
    _syncCaixasEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();

    final maps = await _db.queryAll(
      AppConstants.tableCaixas,
      where: shopIdFiltro == null ? null : 'barbearia_id = ?',
      whereArgs: shopIdFiltro == null ? null : [shopIdFiltro],
      orderBy: 'data_abertura DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Caixa.fromMap(maps.first);
  }

  Future<List<Caixa>> getCaixas({int? limit = 30, int? offset}) async {
    final safeLimit = SecurityUtils.sanitizeIntRange(
      limit ?? 30,
      fieldName: 'Limite',
      min: 1,
      max: 365,
    );

    _syncCaixasEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();

    final maps = await _db.queryAll(
      AppConstants.tableCaixas,
      where: shopIdFiltro == null ? null : 'barbearia_id = ?',
      whereArgs: shopIdFiltro == null ? null : [shopIdFiltro],
      orderBy: 'data_abertura DESC',
      limit: safeLimit,
      offset: offset,
    );
    return maps.map((m) => Caixa.fromMap(m)).toList(growable: false);
  }

  Future<int> abrirCaixa({double valorInicial = 0.0}) async {
    final safeValorInicial = SecurityUtils.sanitizeDoubleRange(
      valorInicial,
      fieldName: 'Valor inicial',
      min: 0,
      max: 999999,
    );

    final session = await _firebaseSession();
    final firebaseCaixaId = session == null
        ? null
        : await _abrirCaixaFirebase(
            barbeariaId: session.barbeariaId,
            userId: session.userId,
            valorInicial: safeValorInicial,
          );

    if (firebaseCaixaId == null) {
      final caixaAberto = await getCaixaAberto();
      if (caixaAberto != null) {
        throw const ConflictException(
          'Ja existe um caixa aberto. Feche o caixa atual antes de abrir outro.',
        );
      }
    }

    final agora = DateTime.now().toUtc();
    final novoCaixa = Caixa(
      dataAbertura: agora,
      valorInicial: safeValorInicial,
      status: AppConstants.caixaAberto,
    );

    final nowIso = agora.toIso8601String();
    final localMap = <String, dynamic>{
      ...novoCaixa.toMap(),
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    if (session != null && firebaseCaixaId != null) {
      localMap['firebase_id'] = firebaseCaixaId;
      localMap['barbearia_id'] = session.barbeariaId;
      localMap['created_by'] = session.userId;
    }

    return _db.insert(AppConstants.tableCaixas, localMap);
  }

  Future<void> fecharCaixa(int caixaId, {String? operationId}) async {
    final safeCaixaId = SecurityUtils.sanitizeIntRange(
      caixaId,
      fieldName: 'ID do caixa',
      min: 1,
      max: 1 << 30,
    );

    final agora = DateTime.now().toUtc();
    final caixa = await getCaixaAberto();
    if (caixa == null) {
      throw const NotFoundException('Nao existe caixa aberto para fechamento.');
    }
    if (caixa.id != safeCaixaId) {
      throw const ConflictException(
        'Caixa informado nÃ£o corresponde ao caixa aberto atual.',
      );
    }

    final session = await _firebaseSession();
    final firebaseCaixaId =
        session == null ? null : await _firebaseCaixaIdFromLocalId(safeCaixaId);
    final firebaseResumo = session != null && firebaseCaixaId != null
        ? await _fecharCaixaFirebase(
            barbeariaId: session.barbeariaId,
            userId: session.userId,
            caixaId: firebaseCaixaId,
            operationId: operationId ?? 'fechamento_$firebaseCaixaId',
          )
        : null;

    // Soma comandas (fluxo atual)
    final pagamentos = Map<String, double>.from(
      await _comandaService.getFaturamentoPorPagamento(
          caixa.dataAbertura, agora),
    );

    // Soma atendimentos legados (fluxo prÃ©-comanda)
    final pagamentosLegados =
        await _getFaturamentoPorPagamentoLegado(caixa.dataAbertura, agora);
    for (final entry in pagamentosLegados.entries) {
      pagamentos[entry.key] = (pagamentos[entry.key] ?? 0.0) + entry.value;
    }

    final valorFinal = firebaseResumo?.valorFinal ??
        caixa.valorInicial + pagamentos.values.fold(0.0, (a, b) => a + b);

    await _db.update(
      AppConstants.tableCaixas,
      {
        'data_fechamento': agora.toIso8601String(),
        'valor_final': valorFinal,
        'status': AppConstants.caixaFechado,
        'resumo_pagamentos': jsonEncode(pagamentos),
        'updated_at': agora.toIso8601String(),
      },
      'id = ?',
      [safeCaixaId],
    );

    if (firebaseResumo == null) {
      await _syncCaixaByLocalIdIfOnline(safeCaixaId);
    }
  }

  /// Retorna faturamento agrupado por forma de pagamento da tabela legada
  /// [atendimentos] â€” usada antes da migraÃ§Ã£o para o fluxo de comandas.
  Future<Map<String, double>> _getFaturamentoPorPagamentoLegado(
    DateTime inicio,
    DateTime fim,
  ) async {
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[inicio.toIso8601String(), fim.toIso8601String()];
    if (shopIdFiltro != null) {
      args.add(shopIdFiltro);
    }
    final result = await _db.rawQuery('''
      SELECT forma_pagamento, SUM(total) AS total
      FROM ${AppConstants.tableAtendimentos}
      WHERE data BETWEEN ? AND ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
      GROUP BY forma_pagamento
    ''', args);

    return {
      for (final row in result)
        (row['forma_pagamento'] as String?) ?? AppConstants.pgDinheiro:
            (row['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Sangria: retirada de dinheiro do caixa durante o expediente.
  Future<void> sangria({
    required int caixaId,
    required double valor,
    String? observacao,
    String? operationId,
  }) async {
    final safeCaixaId = SecurityUtils.sanitizeIntRange(
      caixaId,
      fieldName: 'ID do caixa',
      min: 1,
      max: 1 << 30,
    );
    final safeValor = SecurityUtils.sanitizeDoubleRange(
      valor,
      fieldName: 'Valor da sangria',
      min: 0.01,
      max: 999999,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      observacao,
      maxLength: 300,
      allowNewLines: false,
    );

    final caixa = await getCaixaAberto();
    if (caixa == null || caixa.id != safeCaixaId) {
      throw const NotFoundException('Caixa aberto nao encontrado.');
    }

    final session = await _firebaseSession();
    final firebaseCaixaId =
        session == null ? null : await _firebaseCaixaIdFromLocalId(safeCaixaId);
    if (session != null && firebaseCaixaId != null) {
      await _registrarOperacaoCaixaFirebase(
        barbeariaId: session.barbeariaId,
        userId: session.userId,
        caixaId: firebaseCaixaId,
        operationId: operationId ?? _uuid.v4(),
        tipo: 'sangria',
        valor: safeValor,
      );
    }

    await _db.transaction((txn) async {
      final saldo = await _saldoDinheiroDisponivelCaixaComExecutor(caixa, txn);
      if (safeValor > saldo) {
        throw BusinessException(
          'Sangria excede o saldo disponível no caixa. '
          'Saldo atual: R\$ ${_formatarMoedaSimples(saldo)}',
        );
      }

      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      await txn.insert(
        AppConstants.tableDespesas,
        {
          ...Despesa(
            descricao: safeObs ?? 'Sangria de caixa',
            categoria: 'Outros',
            valor: safeValor,
            data: now,
            observacoes: 'Sangria — Caixa #$safeCaixaId',
          ).toMap(),
          'created_at': nowIso,
          'updated_at': nowIso,
        },
      );
    });
  }

  Future<double> _saldoDinheiroDisponivelCaixaComExecutor(
    Caixa caixa,
    DatabaseExecutor executor,
  ) async {
    final caixaId = caixa.id;
    if (caixaId == null) return 0;
    final inicio = caixa.dataAbertura.toIso8601String();
    final fim = DateTime.now().toIso8601String();
    final shopIdFiltro = await _barbeariaIdParaFiltro();

    final comandasArgs = <dynamic>[
      AppConstants.comandaFechada,
      AppConstants.pgDinheiro,
      inicio,
      fim,
    ];
    if (shopIdFiltro != null) {
      comandasArgs.add(shopIdFiltro);
    }
    final comandasResult = await executor.rawQuery('''
      SELECT COALESCE(SUM(total), 0) AS total
      FROM ${AppConstants.tableComandas}
      WHERE status = ?
        AND forma_pagamento = ?
        AND COALESCE(data_fechamento, data_abertura) BETWEEN ? AND ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
    ''', comandasArgs);

    final sangriasArgs = <dynamic>[
      inicio,
      fim,
      '%Caixa #$caixaId%',
    ];
    if (shopIdFiltro != null) {
      sangriasArgs.add(shopIdFiltro);
    }
    final sangriasResult = await executor.rawQuery('''
      SELECT COALESCE(SUM(valor), 0) AS total
      FROM ${AppConstants.tableDespesas}
      WHERE data BETWEEN ? AND ?
        AND observacoes LIKE ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
    ''', sangriasArgs);

    final comandasDinheiro =
        (comandasResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final sangrias = (sangriasResult.first['total'] as num?)?.toDouble() ?? 0.0;
    return caixa.valorInicial + comandasDinheiro - sangrias;
  }

  String _formatarMoedaSimples(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  /// ReforÃ§o: adiÃ§Ã£o de dinheiro ao caixa durante o expediente.
  Future<void> reforco({
    required int caixaId,
    required double valor,
    String? observacao,
    String? operationId,
  }) async {
    final safeCaixaId = SecurityUtils.sanitizeIntRange(
      caixaId,
      fieldName: 'ID do caixa',
      min: 1,
      max: 1 << 30,
    );
    final safeValor = SecurityUtils.sanitizeDoubleRange(
      valor,
      fieldName: 'Valor do reforÃ§o',
      min: 0.01,
      max: 999999,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      observacao,
      maxLength: 300,
      allowNewLines: false,
    );

    final caixa = await getCaixaAberto();
    if (caixa == null || caixa.id != safeCaixaId) {
      throw const NotFoundException('Caixa aberto nao encontrado.');
    }

    final session = await _firebaseSession();
    final firebaseCaixaId =
        session == null ? null : await _firebaseCaixaIdFromLocalId(safeCaixaId);
    if (session != null && firebaseCaixaId != null) {
      await _registrarOperacaoCaixaFirebase(
        barbeariaId: session.barbeariaId,
        userId: session.userId,
        caixaId: firebaseCaixaId,
        operationId: operationId ?? _uuid.v4(),
        tipo: 'reforco',
        valor: safeValor,
      );
    }

    final agora = DateTime.now();
    final agoraIso = agora.toIso8601String();
    String? shopId;
    String? uid;
    if (await _isFirebaseOnline()) {
      shopId = await _context.getBarbeariaIdAtual();
      uid = _auth.currentUser?.uid;
    }

    await _db.transaction((txn) async {
      await txn.insert(AppConstants.tableDespesas, {
        ...Despesa(
          descricao: safeObs ?? 'Reforço de caixa',
          categoria: 'Reforço',
          valor: -safeValor,
          data: agora,
          observacoes: 'Reforço - Caixa #$safeCaixaId',
        ).toMap(),
        'barbearia_id': shopId,
        'created_by': uid,
        'created_at': agoraIso,
        'updated_at': agoraIso,
      });
    });
    await _syncDespesasFromFirestoreIfOnline();
  }

  Map<String, double> simularMudancaPreco({
    required double precoAtual,
    required double novoPreco,
    required int mediaAtendimentosMes,
  }) {
    final safePrecoAtual = SecurityUtils.sanitizeDoubleRange(
      precoAtual,
      fieldName: 'Preco atual',
      min: 0,
      max: 999999,
    );
    final safeNovoPreco = SecurityUtils.sanitizeDoubleRange(
      novoPreco,
      fieldName: 'Novo preco',
      min: 0,
      max: 999999,
    );
    final safeMediaAtendimentos = SecurityUtils.sanitizeIntRange(
      mediaAtendimentosMes,
      fieldName: 'Media de atendimentos',
      min: 0,
      max: 1000000,
    );

    final faturamentoAtual = safePrecoAtual * safeMediaAtendimentos;
    final faturamentoNovo = safeNovoPreco * safeMediaAtendimentos;
    final diferenca = faturamentoNovo - faturamentoAtual;
    final percentual =
        faturamentoAtual > 0 ? (diferenca / faturamentoAtual) : 0.0;

    return {
      'faturamentoAtual': faturamentoAtual,
      'faturamentoNovo': faturamentoNovo,
      'diferenca': diferenca,
      'percentual': percentual,
    };
  }

  Future<_FirebaseSession?> _firebaseSession() async {
    if (!await _isFirebaseOnline()) return null;
    final shopId = await _context.getBarbeariaIdAtual();
    final uid = _auth.currentUser?.uid;
    if (shopId == null ||
        shopId.trim().isEmpty ||
        uid == null ||
        uid.trim().isEmpty) {
      return null;
    }
    return _FirebaseSession(barbeariaId: shopId, userId: uid);
  }

  Future<String?> _abrirCaixaFirebase({
    required String barbeariaId,
    required String userId,
    required double valorInicial,
  }) async {
    final caixaId = _uuid.v4();
    final agora = DateTime.now().toUtc();
    final caixaRef = _caixaDoc(barbeariaId, caixaId);
    final activeRef = _caixaAtualDoc(barbeariaId);

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final activeSnap = await txn.get(activeRef);
      final activeCaixaId = activeSnap.data()?['caixa_aberto_id'] as String?;
      if (activeCaixaId != null && activeCaixaId.trim().isNotEmpty) {
        final activeCaixa =
            await txn.get(_caixaDoc(barbeariaId, activeCaixaId));
        if (activeCaixa.exists &&
            activeCaixa.data()?['status'] == AppConstants.caixaAberto) {
          throw const ConflictException(
            'Ja existe um caixa aberto. Feche o caixa atual antes de abrir outro.',
          );
        }
      }

      txn.set(caixaRef, {
        'id': caixaId,
        'firebase_id': caixaId,
        'barbearia_id': barbeariaId,
        'created_by': userId,
        'data_abertura': Timestamp.fromDate(agora),
        'data_fechamento': null,
        'valor_inicial': valorInicial,
        'valor_final': null,
        'status': AppConstants.caixaAberto,
        'operation_ids': <String>[],
        'created_at': Timestamp.fromDate(agora),
        'updated_at': Timestamp.fromDate(agora),
      });
      txn.set(
          activeRef,
          {
            'caixa_aberto_id': caixaId,
            'barbearia_id': barbeariaId,
            'updated_at': Timestamp.fromDate(agora),
          },
          SetOptions(merge: true));
    });

    return caixaId;
  }

  Future<void> _registrarOperacaoCaixaFirebase({
    required String barbeariaId,
    required String userId,
    required String caixaId,
    required String operationId,
    required String tipo,
    required double valor,
  }) {
    final caixaRef = _caixaDoc(barbeariaId, caixaId);
    final opRef = _caixaOperacaoDoc(barbeariaId, caixaId, operationId);

    return FirebaseFirestore.instance.runTransaction((txn) async {
      final existingOp = await txn.get(opRef);
      if (existingOp.exists) return;

      final caixaSnap = await txn.get(caixaRef);
      if (!caixaSnap.exists) {
        throw const NotFoundException('Caixa aberto nao encontrado.');
      }
      final caixaData = caixaSnap.data()!;
      if (caixaData['status'] != AppConstants.caixaAberto) {
        throw const ConflictException('Caixa informado nao esta aberto.');
      }

      final operationIds = _operationIds(caixaData);
      final operationDocs = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final id in operationIds) {
        operationDocs.add(await txn.get(_caixaOperacaoDoc(
          barbeariaId,
          caixaId,
          id,
        )));
      }

      if (tipo == 'sangria') {
        final saldo = _saldoCaixaLedger(caixaData, operationDocs);
        if (valor > saldo) {
          throw BusinessException(
            'Sangria excede o saldo disponível no caixa. '
            'Saldo atual: R\$ ${_formatarMoedaSimples(saldo)}',
          );
        }
      }

      final agora = DateTime.now().toUtc();
      txn.set(opRef, {
        'tipo': tipo,
        'valor': valor,
        'timestamp': Timestamp.fromDate(agora),
        'userId': userId,
        'operationId': operationId,
        'barbearia_id': barbeariaId,
      });
      txn.update(caixaRef, {
        'operation_ids': [...operationIds, operationId],
        'updated_at': Timestamp.fromDate(agora),
      });
    });
  }

  Future<_CaixaFechamentoResumo?> _fecharCaixaFirebase({
    required String barbeariaId,
    required String userId,
    required String caixaId,
    required String operationId,
  }) {
    final caixaRef = _caixaDoc(barbeariaId, caixaId);
    final opRef = _caixaOperacaoDoc(barbeariaId, caixaId, operationId);
    final activeRef = _caixaAtualDoc(barbeariaId);

    return FirebaseFirestore.instance
        .runTransaction<_CaixaFechamentoResumo?>((txn) async {
      final caixaSnap = await txn.get(caixaRef);
      if (!caixaSnap.exists) {
        throw const NotFoundException('Caixa aberto nao encontrado.');
      }
      final caixaData = caixaSnap.data()!;

      final existingOp = await txn.get(opRef);
      if (existingOp.exists) {
        final valor = (existingOp.data()?['valor'] as num?)?.toDouble() ??
            (caixaData['valor_final'] as num?)?.toDouble();
        return valor == null ? null : _CaixaFechamentoResumo(valor);
      }

      if (caixaData['status'] != AppConstants.caixaAberto) {
        throw const ConflictException('Caixa informado nao esta aberto.');
      }

      final operationIds = _operationIds(caixaData);
      final operationDocs = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final id in operationIds) {
        operationDocs.add(await txn.get(_caixaOperacaoDoc(
          barbeariaId,
          caixaId,
          id,
        )));
      }

      final valorFinal = _saldoCaixaLedger(caixaData, operationDocs);
      final agora = DateTime.now().toUtc();
      txn.set(opRef, {
        'tipo': 'fechamento',
        'valor': valorFinal,
        'timestamp': Timestamp.fromDate(agora),
        'userId': userId,
        'operationId': operationId,
        'barbearia_id': barbeariaId,
      });
      txn.update(caixaRef, {
        'status': AppConstants.caixaFechado,
        'data_fechamento': Timestamp.fromDate(agora),
        'valor_final': valorFinal,
        'operation_ids': [...operationIds, operationId],
        'updated_at': Timestamp.fromDate(agora),
      });
      txn.set(
          activeRef,
          {
            'caixa_aberto_id': null,
            'barbearia_id': barbeariaId,
            'updated_at': Timestamp.fromDate(agora),
          },
          SetOptions(merge: true));
      return _CaixaFechamentoResumo(valorFinal);
    });
  }

  double _saldoCaixaLedger(
    Map<String, dynamic> caixaData,
    List<DocumentSnapshot<Map<String, dynamic>>> operationDocs,
  ) {
    var saldo = (caixaData['valor_inicial'] as num?)?.toDouble() ?? 0.0;
    for (final doc in operationDocs) {
      final data = doc.data();
      if (data == null) continue;
      final tipo = data['tipo'] as String?;
      final valor = (data['valor'] as num?)?.toDouble() ?? 0.0;
      if (tipo == 'entrada' || tipo == 'reforco') {
        saldo += valor;
      } else if (tipo == 'sangria') {
        saldo -= valor;
      }
    }
    return saldo;
  }

  List<String> _operationIds(Map<String, dynamic> caixaData) {
    final raw = caixaData['operation_ids'];
    if (raw is Iterable) {
      return raw.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  DocumentReference<Map<String, dynamic>> _caixaDoc(
    String barbeariaId,
    String caixaId,
  ) {
    return _context
        .collection(barbeariaId: barbeariaId, nome: AppConstants.tableCaixas)
        .doc(caixaId);
  }

  DocumentReference<Map<String, dynamic>> _caixaOperacaoDoc(
    String barbeariaId,
    String caixaId,
    String operationId,
  ) {
    return _caixaDoc(barbeariaId, caixaId)
        .collection('operacoes')
        .doc(operationId);
  }

  DocumentReference<Map<String, dynamic>> _caixaAtualDoc(String barbeariaId) {
    return _context
        .barbeariaDoc(barbeariaId)
        .collection('metadata')
        .doc('caixa_atual');
  }

  Future<String?> _firebaseCaixaIdFromLocalId(int caixaId) async {
    final rows = await _db.queryAll(
      AppConstants.tableCaixas,
      where: 'id = ?',
      whereArgs: [caixaId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final firebaseId = rows.first['firebase_id'] as String?;
    if (firebaseId == null || firebaseId.trim().isEmpty) return null;
    return firebaseId;
  }

  Future<void> _syncDespesasFromFirestoreIfOnline() async {
    if (!await _isFirebaseOnline()) return;

    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return;

    // Falha silenciosa: SQLite permanece como fonte se Firebase nÃ£o estiver acessÃ­vel.
    await FirebaseErrorHandler.wrapSilent(
      () => _syncPendingLocalDespesasIfOnline(shopId),
    );

    await FirebaseErrorHandler.wrapSilent(() async {
      final snap = await _context
          .collection(barbeariaId: shopId, nome: AppConstants.tableDespesas)
          .orderBy('data', descending: true)
          .limit(AppConstants.kSyncBatchSize)
          .get();

      for (final doc in snap.docs) {
        await _upsertDespesaLocalFromFirestore(doc.id, doc.data(), shopId);
      }
    });
  }

  void _syncDespesasEmBackground() {
    unawaited(_syncDespesasFromFirestoreIfOnline().catchError((_) {}));
  }

  void _syncCaixasEmBackground() {
    unawaited(_syncCaixasFromFirestoreIfOnline().catchError((_) {}));
  }

  Future<void> _syncPendingLocalDespesasIfOnline(String shopId) async {
    // Step 1: never-synced records
    final semFirebaseId = await _db.queryAll(
      AppConstants.tableDespesas,
      where: "firebase_id IS NULL OR trim(firebase_id) = ''",
      orderBy: 'updated_at DESC',
      limit: AppConstants.kSyncBatchSize,
    );
    for (final row in semFirebaseId) {
      final id = (row['id'] as num?)?.toInt();
      if (id == null) continue;
      await _syncDespesaByLocalIdIfOnline(id, shopId: shopId);
    }

    // Step 2: recently-modified records
    final threshold =
        DateTime.now().subtract(const Duration(hours: 48)).toIso8601String();
    final recentes = await _db.queryAll(
      AppConstants.tableDespesas,
      where:
          "firebase_id IS NOT NULL AND trim(firebase_id) != '' AND updated_at >= ?",
      whereArgs: [threshold],
      orderBy: 'updated_at DESC',
      limit: AppConstants.kSyncBatchSize,
    );
    for (final row in recentes) {
      final id = (row['id'] as num?)?.toInt();
      if (id == null) continue;
      await _syncDespesaByLocalIdIfOnline(id, shopId: shopId);
    }
  }

  Future<void> _syncDespesaByLocalIdIfOnline(
    int id, {
    String? shopId,
  }) async {
    if (!await _isFirebaseOnline()) return;

    final resolvedShopId = shopId ?? await _context.getBarbeariaIdAtual();
    final uid = _auth.currentUser?.uid;
    if (resolvedShopId == null || uid == null) return;

    final rows = await _db.queryAll(
      AppConstants.tableDespesas,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    String? firebaseId = row['firebase_id'] as String?;
    if (firebaseId == null || firebaseId.trim().isEmpty) {
      firebaseId = _uuid.v4();
      await _db.update(
        AppConstants.tableDespesas,
        {
          'firebase_id': firebaseId,
          'barbearia_id': resolvedShopId,
          'created_by': uid,
        },
        'id = ?',
        [id],
      );
    }

    final data = DateTime.tryParse((row['data'] as String?) ?? '');
    if (data == null) return;

    await _context
        .collection(
            barbeariaId: resolvedShopId, nome: AppConstants.tableDespesas)
        .doc(firebaseId)
        .set({
      'descricao': row['descricao'],
      'categoria': row['categoria'],
      'valor': (row['valor'] as num?)?.toDouble() ?? 0.0,
      'data': Timestamp.fromDate(data),
      'observacoes': row['observacoes'],
      'barbearia_id': resolvedShopId,
      'created_by': row['created_by'] ?? uid,
      'updated_at': FieldValue.serverTimestamp(),
      if (row['created_at'] == null) 'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _upsertDespesaLocalFromFirestore(
    String firebaseId,
    Map<String, dynamic> data,
    String shopId,
  ) async {
    final createdAt = _parseFirestoreDate(
      data['created_at'],
      fallback: DateTime.now(),
    );
    final updatedAt = _parseFirestoreDate(
      data['updated_at'],
      fallback: createdAt,
    );
    final dataDespesa = _parseFirestoreDate(
      data['data'],
      fallback: createdAt,
    );

    final localMap = <String, dynamic>{
      'firebase_id': firebaseId,
      'barbearia_id': (data['barbearia_id'] as String?) ?? shopId,
      'created_by': data['created_by'] as String?,
      'descricao': (data['descricao'] ?? '') as String,
      'categoria': (data['categoria'] ?? 'Outros') as String,
      'valor': (data['valor'] as num?)?.toDouble() ?? 0.0,
      'data': dataDespesa.toIso8601String(),
      'observacoes': data['observacoes'] as String?,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

    final existing = await _db.queryAll(
      AppConstants.tableDespesas,
      where: 'firebase_id = ?',
      whereArgs: [firebaseId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      if (_localMaisNovoQueRemoto(existing.first, updatedAt)) return;
      await _db.update(
        AppConstants.tableDespesas,
        localMap,
        'id = ?',
        [existing.first['id']],
      );
    } else {
      await _db.insert(
        AppConstants.tableDespesas,
        localMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _syncCaixasFromFirestoreIfOnline() async {
    if (!await _isFirebaseOnline()) return;

    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return;

    await FirebaseErrorHandler.wrapSilent(
      () => _syncPendingLocalCaixasIfOnline(shopId),
    );

    await FirebaseErrorHandler.wrapSilent(() async {
      final snap = await _context
          .collection(barbeariaId: shopId, nome: AppConstants.tableCaixas)
          .orderBy('data_abertura', descending: true)
          .limit(AppConstants.kSyncBatchSize)
          .get();

      for (final doc in snap.docs) {
        await _upsertCaixaLocalFromFirestore(doc.id, doc.data(), shopId);
      }
    });
  }

  Future<void> _syncPendingLocalCaixasIfOnline(String shopId) async {
    final rows = await _db.queryAll(
      AppConstants.tableCaixas,
      orderBy: 'updated_at DESC',
    );
    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      if (id == null) continue;
      await _syncCaixaByLocalIdIfOnline(id, shopId: shopId);
    }
  }

  Future<void> _syncCaixaByLocalIdIfOnline(
    int caixaId, {
    String? shopId,
  }) async {
    if (!await _isFirebaseOnline()) return;

    final resolvedShopId = shopId ?? await _context.getBarbeariaIdAtual();
    final uid = _auth.currentUser?.uid;
    if (resolvedShopId == null || uid == null) return;

    final rows = await _db.queryAll(
      AppConstants.tableCaixas,
      where: 'id = ?',
      whereArgs: [caixaId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    String? firebaseId = row['firebase_id'] as String?;
    if (firebaseId == null || firebaseId.trim().isEmpty) {
      firebaseId = _uuid.v4();
      await _db.update(
        AppConstants.tableCaixas,
        {
          'firebase_id': firebaseId,
          'barbearia_id': resolvedShopId,
          'created_by': uid,
        },
        'id = ?',
        [caixaId],
      );
    }

    final dataAbertura =
        DateTime.tryParse((row['data_abertura'] as String?) ?? '');
    if (dataAbertura == null) return;

    final dataFechamentoRaw = row['data_fechamento'] as String?;
    final dataFechamento =
        dataFechamentoRaw == null ? null : DateTime.tryParse(dataFechamentoRaw);

    await _context
        .collection(barbeariaId: resolvedShopId, nome: AppConstants.tableCaixas)
        .doc(firebaseId)
        .set({
      'data_abertura': Timestamp.fromDate(dataAbertura),
      'data_fechamento':
          dataFechamento == null ? null : Timestamp.fromDate(dataFechamento),
      'valor_inicial': (row['valor_inicial'] as num?)?.toDouble() ?? 0.0,
      'valor_final': (row['valor_final'] as num?)?.toDouble(),
      'status': row['status'],
      'resumo_pagamentos': row['resumo_pagamentos'],
      'observacoes': row['observacoes'],
      'barbearia_id': resolvedShopId,
      'created_by': row['created_by'] ?? uid,
      'updated_at': FieldValue.serverTimestamp(),
      if (row['created_at'] == null) 'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _upsertCaixaLocalFromFirestore(
    String firebaseId,
    Map<String, dynamic> data,
    String shopId,
  ) async {
    final createdAt = _parseFirestoreDate(
      data['created_at'],
      fallback: DateTime.now(),
    );
    final updatedAt = _parseFirestoreDate(
      data['updated_at'],
      fallback: createdAt,
    );
    final dataAbertura = _parseFirestoreDate(
      data['data_abertura'],
      fallback: createdAt,
    );
    final dataFechamento = _parseOptionalFirestoreDate(data['data_fechamento']);

    final localMap = <String, dynamic>{
      'firebase_id': firebaseId,
      'barbearia_id': (data['barbearia_id'] as String?) ?? shopId,
      'created_by': data['created_by'] as String?,
      'data_abertura': dataAbertura.toIso8601String(),
      'data_fechamento': dataFechamento?.toIso8601String(),
      'valor_inicial': (data['valor_inicial'] as num?)?.toDouble() ?? 0.0,
      'valor_final': (data['valor_final'] as num?)?.toDouble(),
      'status': (data['status'] ?? AppConstants.caixaAberto) as String,
      'resumo_pagamentos': data['resumo_pagamentos'] as String?,
      'observacoes': data['observacoes'] as String?,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

    final existing = await _db.queryAll(
      AppConstants.tableCaixas,
      where: 'firebase_id = ?',
      whereArgs: [firebaseId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      if (_localMaisNovoQueRemoto(existing.first, updatedAt)) return;
      await _db.update(
        AppConstants.tableCaixas,
        localMap,
        'id = ?',
        [existing.first['id']],
      );
    } else {
      await _db.insert(
        AppConstants.tableCaixas,
        localMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  DateTime _parseFirestoreDate(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value) ?? (fallback ?? DateTime.now());
    }
    return fallback ?? DateTime.now();
  }

  DateTime? _parseOptionalFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  bool _localMaisNovoQueRemoto(
    Map<String, dynamic> local,
    DateTime remotoUpdatedAt,
  ) {
    final localUpdatedAt =
        DateTime.tryParse((local['updated_at'] as String?) ?? '');
    return localUpdatedAt != null && localUpdatedAt.isAfter(remotoUpdatedAt);
  }

  Future<String?> _barbeariaIdParaFiltro() async {
    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return null;
    if (shopId == AppConstants.localBarbeariaId) return null;
    return shopId;
  }

  Despesa _sanitizarDespesa(Despesa despesa) {
    final safeDescricao = SecurityUtils.sanitizePlainText(
      despesa.descricao,
      fieldName: 'Descricao',
      minLength: 2,
      maxLength: 150,
      allowNewLines: false,
    );
    final safeCategoria = SecurityUtils.sanitizePlainText(
      despesa.categoria,
      fieldName: 'Categoria',
      minLength: 2,
      maxLength: 50,
      allowNewLines: false,
    );
    SecurityUtils.ensure(
      _categoriasAceitas.contains(safeCategoria),
      'Categoria de despesa invalida.',
    );
    final safeValor = SecurityUtils.sanitizeDoubleRange(
      despesa.valor,
      fieldName: 'Valor',
      min: 0.01,
      max: 999999999,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      despesa.observacoes,
      maxLength: 500,
      allowNewLines: true,
    );

    return despesa.copyWith(
      descricao: safeDescricao,
      categoria: safeCategoria,
      valor: safeValor,
      observacoes: safeObs,
    );
  }
}

class _FirebaseSession {
  const _FirebaseSession({
    required this.barbeariaId,
    required this.userId,
  });

  final String barbeariaId;
  final String userId;
}

class _CaixaFechamentoResumo {
  const _CaixaFechamentoResumo(this.valorFinal);

  final double valorFinal;
}
