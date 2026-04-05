// ============================================================
// financeiro_service.dart
// Serviço financeiro com Firestore como fonte principal
// e SQLite como cache offline.
// ============================================================

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/caixa.dart';
import '../models/despesa.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'comanda_service.dart';
import 'connectivity_service.dart';
import 'firebase_context_service.dart';
import 'service_exceptions.dart';

class FinanceiroService {
  final DatabaseHelper _db = DatabaseHelper();
  final ComandaService _comandaService = ComandaService();
  final FirebaseContextService _context = FirebaseContextService();
  final ConnectivityService _connectivity = ConnectivityService();
  final Uuid _uuid = const Uuid();

  static final Set<String> _categoriasAceitas = {
    ...AppConstants.categoriasDespesa,
    'Luz',
  };

  bool get _firebaseDisponivel => Firebase.apps.isNotEmpty;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<bool> _isFirebaseOnline() async {
    if (!_firebaseDisponivel) return false;
    return _connectivity.isOnline();
  }

  Future<List<Despesa>> getDespesas({DateTime? inicio, DateTime? fim}) async {
    await _syncDespesasFromFirestoreIfOnline();

    String? where;
    List<dynamic>? whereArgs;

    if (inicio != null && fim != null) {
      SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
      where = 'data BETWEEN ? AND ?';
      whereArgs = [inicio.toIso8601String(), fim.toIso8601String()];
    }

    final maps = await _db.queryAll(
      AppConstants.tableDespesas,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'data DESC',
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
          'created_by': uid,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        localMap['firebase_id'] = firebaseId;
        localMap['barbearia_id'] = shopId;
        localMap['created_by'] = uid;
      }
    }

    return _db.insert(AppConstants.tableDespesas, localMap);
  }

  Future<void> updateDespesa(Despesa despesa) async {
    SecurityUtils.ensure(despesa.id != null, 'ID da despesa invalido.');
    final safeDespesa = _sanitizarDespesa(despesa);

    if (await _isFirebaseOnline()) {
      await _syncDespesaByLocalIdIfOnline(safeDespesa.id!);

      final row = await _db.queryAll(
        AppConstants.tableDespesas,
        where: 'id = ?',
        whereArgs: [safeDespesa.id],
        limit: 1,
      );
      final firebaseId = row.isEmpty ? null : row.first['firebase_id'] as String?;
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
      final firebaseId = row.isEmpty ? null : row.first['firebase_id'] as String?;
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
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    await _syncDespesasFromFirestoreIfOnline();

    final result = await _db.rawQuery('''
      SELECT SUM(valor) as total
      FROM ${AppConstants.tableDespesas}
      WHERE data BETWEEN ? AND ?
    ''', [inicio.toIso8601String(), fim.toIso8601String()]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getDespesasPorCategoria(
    DateTime inicio,
    DateTime fim,
  ) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    await _syncDespesasFromFirestoreIfOnline();

    return _db.rawQuery('''
      SELECT categoria, SUM(valor) as total
      FROM ${AppConstants.tableDespesas}
      WHERE data BETWEEN ? AND ?
      GROUP BY categoria
      ORDER BY total DESC
    ''', [inicio.toIso8601String(), fim.toIso8601String()]);
  }

  Future<Map<String, double>> getResumo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    final faturamento = await _comandaService.getFaturamentoPeriodo(inicio, fim);
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
    await _syncCaixasFromFirestoreIfOnline();

    final maps = await _db.queryAll(
      AppConstants.tableCaixas,
      where: "status = 'aberto'",
      orderBy: 'data_abertura DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Caixa.fromMap(maps.first);
  }

  Future<Caixa?> getUltimoCaixa() async {
    await _syncCaixasFromFirestoreIfOnline();

    final maps = await _db.queryAll(
      AppConstants.tableCaixas,
      orderBy: 'data_abertura DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Caixa.fromMap(maps.first);
  }

  Future<List<Caixa>> getCaixas({int limit = 30}) async {
    final safeLimit = SecurityUtils.sanitizeIntRange(
      limit,
      fieldName: 'Limite',
      min: 1,
      max: 365,
    );

    await _syncCaixasFromFirestoreIfOnline();

    final maps = await _db.queryAll(
      AppConstants.tableCaixas,
      orderBy: 'data_abertura DESC',
      limit: safeLimit,
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

    final caixaAberto = await getCaixaAberto();
    if (caixaAberto != null) {
      throw const ConflictException(
        'Ja existe um caixa aberto. Feche o caixa atual antes de abrir outro.',
      );
    }

    final novoCaixa = Caixa(
      dataAbertura: DateTime.now(),
      valorInicial: safeValorInicial,
      status: AppConstants.caixaAberto,
    );

    final nowIso = DateTime.now().toIso8601String();
    final localMap = <String, dynamic>{
      ...novoCaixa.toMap(),
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    if (await _isFirebaseOnline()) {
      final shopId = await _context.getBarbeariaIdAtual();
      final uid = _auth.currentUser?.uid;
      if (shopId != null && uid != null) {
        final firebaseId = _uuid.v4();
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableCaixas)
            .doc(firebaseId)
            .set({
          'data_abertura': Timestamp.fromDate(novoCaixa.dataAbertura),
          'data_fechamento': null,
          'valor_inicial': novoCaixa.valorInicial,
          'valor_final': null,
          'status': novoCaixa.status,
          'resumo_pagamentos': null,
          'observacoes': novoCaixa.observacoes,
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

    return _db.insert(AppConstants.tableCaixas, localMap);
  }

  Future<void> fecharCaixa(int caixaId) async {
    final safeCaixaId = SecurityUtils.sanitizeIntRange(
      caixaId,
      fieldName: 'ID do caixa',
      min: 1,
      max: 1 << 30,
    );

    final agora = DateTime.now();
    final caixa = await getCaixaAberto();
    if (caixa == null) {
      throw const NotFoundException('Nao existe caixa aberto para fechamento.');
    }
    if (caixa.id != safeCaixaId) {
      throw const ConflictException(
        'Caixa informado nao corresponde ao caixa aberto atual.',
      );
    }

    final pagamentos =
        await _comandaService.getFaturamentoPorPagamento(caixa.dataAbertura, agora);

    final valorFinal =
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

    await _syncCaixaByLocalIdIfOnline(safeCaixaId);
  }

  /// Sangria: retirada de dinheiro do caixa durante o expediente.
  Future<void> sangria({
    required int caixaId,
    required double valor,
    String? observacao,
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

    // Registra a sangria como uma despesa interna.
    await insertDespesa(Despesa(
      descricao: safeObs ?? 'Sangria de caixa',
      categoria: 'Outros',
      valor: safeValor,
      data: DateTime.now(),
      observacoes: 'Sangria — Caixa #$safeCaixaId',
    ));
  }

  /// Reforço: adição de dinheiro ao caixa durante o expediente.
  Future<void> reforco({
    required int caixaId,
    required double valor,
    String? observacao,
  }) async {
    final safeCaixaId = SecurityUtils.sanitizeIntRange(
      caixaId,
      fieldName: 'ID do caixa',
      min: 1,
      max: 1 << 30,
    );
    final safeValor = SecurityUtils.sanitizeDoubleRange(
      valor,
      fieldName: 'Valor do reforço',
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

    // Atualiza o valor inicial do caixa para refletir o reforço.
    await _db.update(
      AppConstants.tableCaixas,
      {
        'valor_inicial': caixa.valorInicial + safeValor,
        'observacoes': safeObs != null
            ? 'Reforço: $safeObs'
            : 'Reforço de caixa — R\$ ${safeValor.toStringAsFixed(2)}',
        'updated_at': DateTime.now().toIso8601String(),
      },
      'id = ?',
      [safeCaixaId],
    );
    await _syncCaixaByLocalIdIfOnline(safeCaixaId);
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

  Future<void> _syncDespesasFromFirestoreIfOnline() async {
    if (!await _isFirebaseOnline()) return;

    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return;

    await _syncPendingLocalDespesasIfOnline(shopId);

    final snap = await _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableDespesas)
        .orderBy('data', descending: true)
        .get();

    for (final doc in snap.docs) {
      await _upsertDespesaLocalFromFirestore(doc.id, doc.data(), shopId);
    }
  }

  Future<void> _syncPendingLocalDespesasIfOnline(String shopId) async {
    final rows = await _db.queryAll(
      AppConstants.tableDespesas,
      orderBy: 'updated_at DESC',
    );
    for (final row in rows) {
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
        .collection(barbeariaId: resolvedShopId, nome: AppConstants.tableDespesas)
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
      await _db.update(
        AppConstants.tableDespesas,
        localMap,
        'id = ?',
        [existing.first['id']],
      );
    } else {
      await _db.insert(AppConstants.tableDespesas, localMap);
    }
  }

  Future<void> _syncCaixasFromFirestoreIfOnline() async {
    if (!await _isFirebaseOnline()) return;

    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return;

    await _syncPendingLocalCaixasIfOnline(shopId);

    final snap = await _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableCaixas)
        .orderBy('data_abertura', descending: true)
        .get();

    for (final doc in snap.docs) {
      await _upsertCaixaLocalFromFirestore(doc.id, doc.data(), shopId);
    }
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

    final dataAbertura = DateTime.tryParse((row['data_abertura'] as String?) ?? '');
    if (dataAbertura == null) return;

    final dataFechamentoRaw = row['data_fechamento'] as String?;
    final dataFechamento = dataFechamentoRaw == null
        ? null
        : DateTime.tryParse(dataFechamentoRaw);

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
      await _db.update(
        AppConstants.tableCaixas,
        localMap,
        'id = ?',
        [existing.first['id']],
      );
    } else {
      await _db.insert(AppConstants.tableCaixas, localMap);
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

