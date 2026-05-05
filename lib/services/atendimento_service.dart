// ============================================================
// atendimento_service.dart
// Atendimento com Firestore como fonte online e SQLite como cache.
// ============================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/atendimento.dart';
import '../utils/constants.dart';
import '../utils/firebase_error_handler.dart';
import '../utils/security_utils.dart';
import 'cliente_service.dart';
import 'connectivity_service.dart';
import 'firebase_context_service.dart';
import 'produto_service.dart';
import 'service_exceptions.dart';

class AtendimentoService {
  AtendimentoService({
    DatabaseHelper? db,
    FirebaseContextService? context,
    ConnectivityService? connectivity,
    ClienteService? clienteService,
    ProdutoService? produtoService,
    Uuid? uuid,
  })  : _db = db ?? DatabaseHelper(),
        _context = context ?? FirebaseContextService(),
        _connectivity = connectivity ?? ConnectivityService(),
        _clienteService = clienteService ?? ClienteService(),
        _produtoService = produtoService ?? ProdutoService(),
        _uuid = uuid ?? const Uuid();

  final DatabaseHelper _db;
  final FirebaseContextService _context;
  final ConnectivityService _connectivity;
  final ClienteService _clienteService;
  final ProdutoService _produtoService;
  final Uuid _uuid;

  bool get _firebaseDisponivel => _context.firebaseDisponivel;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<bool> _isFirebaseOnline() async {
    if (!_firebaseDisponivel) return false;
    return _connectivity.isOnline();
  }

  void _syncEmBackground() {
    unawaited(_syncFromFirestoreIfOnline().catchError((_) {}));
  }

  Future<List<Atendimento>> getAll({int? limit}) async {
    if (limit != null) {
      SecurityUtils.sanitizeIntRange(
        limit,
        fieldName: 'Limite',
        min: 1,
        max: 1000,
      );
    }

    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: shopIdFiltro == null ? null : 'barbearia_id = ?',
      whereArgs: shopIdFiltro == null ? null : [shopIdFiltro],
      orderBy: 'data DESC',
      limit: limit,
    );
    final atendimentos = maps.map((m) => Atendimento.fromMap(m)).toList();
    return _anexarItens(atendimentos);
  }

  Future<Atendimento?> getById(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do atendimento',
      min: 1,
      max: 1 << 30,
    );
    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: shopIdFiltro == null ? 'id = ?' : 'id = ? AND barbearia_id = ?',
      whereArgs: shopIdFiltro == null ? [safeId] : [safeId, shopIdFiltro],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final atendimento = Atendimento.fromMap(maps.first);
    final itens = await _getItensByAtendimentos([safeId]);
    return atendimento.copyWith(itens: itens[safeId] ?? const []);
  }

  Future<List<Atendimento>> getDodia() async {
    _syncEmBackground();
    final agora = DateTime.now().toUtc();
    final inicio =
        DateTime.utc(agora.year, agora.month, agora.day).toIso8601String();
    final fim = DateTime.utc(
      agora.year,
      agora.month,
      agora.day,
      23,
      59,
      59,
    ).toIso8601String();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: shopIdFiltro == null
          ? 'data BETWEEN ? AND ?'
          : 'data BETWEEN ? AND ? AND barbearia_id = ?',
      whereArgs:
          shopIdFiltro == null ? [inicio, fim] : [inicio, fim, shopIdFiltro],
      orderBy: 'data DESC',
    );
    final atendimentos = maps.map((m) => Atendimento.fromMap(m)).toList();
    return _anexarItens(atendimentos);
  }

  Future<List<Atendimento>> getPorPeriodo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final inicioUtc = inicio.toUtc().toIso8601String();
    final fimUtc = fim.toUtc().toIso8601String();
    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: shopIdFiltro == null
          ? 'data BETWEEN ? AND ?'
          : 'data BETWEEN ? AND ? AND barbearia_id = ?',
      whereArgs: shopIdFiltro == null
          ? [inicioUtc, fimUtc]
          : [inicioUtc, fimUtc, shopIdFiltro],
      orderBy: 'data DESC',
    );
    final atendimentos = maps.map((m) => Atendimento.fromMap(m)).toList();
    return _anexarItens(atendimentos);
  }

  Future<int> registrar(Atendimento atendimento) async {
    final safeAtendimento = _sanitizarAtendimento(atendimento);
    _validarTotal(safeAtendimento);

    final agora = DateTime.now().toUtc();
    final agoraIso = agora.toIso8601String();
    final firebaseId = _uuid.v4();

    String? shopId;
    String? uid;
    if (await _isFirebaseOnline()) {
      shopId = await _context.getBarbeariaIdAtual();
      uid = _auth.currentUser?.uid;
    }

    if (shopId != null && uid != null) {
      await FirebaseErrorHandler.wrap(() async {
        final atRef = _context
            .collection(
              barbeariaId: shopId!,
              nome: AppConstants.tableAtendimentos,
            )
            .doc(firebaseId);

        final batch = FirebaseFirestore.instance.batch();
        batch.set(
            atRef,
            _toFirestoreMap(
              safeAtendimento,
              firebaseId: firebaseId,
              shopId: shopId,
              uid: uid!,
              data: agora,
            ));

        for (final item in safeAtendimento.itens) {
          batch.set(atRef.collection('itens').doc(_uuid.v4()), {
            'tipo': item.tipo,
            'item_id': item.itemId,
            'nome': item.nome,
            'quantidade': item.quantidade,
            'preco_unitario': item.precoUnitario,
            'subtotal': item.subtotal,
            'barbearia_id': shopId,
            'created_by': uid,
            'updated_at': Timestamp.fromDate(agora),
          });
        }
        await batch.commit();
      });
    }

    final db = await _db.database;
    return db.transaction((txn) async {
      final localMap = <String, dynamic>{
        ...safeAtendimento.toMap(),
        'data': safeAtendimento.data.toUtc().toIso8601String(),
        'created_at': agoraIso,
        'updated_at': agoraIso,
        if (shopId != null) 'firebase_id': firebaseId,
        if (shopId != null) 'barbearia_id': shopId,
        if (uid != null) 'created_by': uid,
      };

      final atendimentoId = await txn.insert(
        AppConstants.tableAtendimentos,
        localMap,
      );

      for (final item in safeAtendimento.itens) {
        await txn.insert(
          AppConstants.tableAtendimentoItens,
          _itemComAtendimento(item, atendimentoId).toMap(),
        );
      }

      for (final item in safeAtendimento.itens) {
        if (item.tipo != 'produto') continue;
        await _produtoService.baixarEstoqueComExecutor(
          executor: txn,
          produtoId: item.itemId,
          quantidade: item.quantidade,
          valorUnitario: item.precoUnitario,
          observacao: 'Atendimento #$atendimentoId',
        );
      }

      if (safeAtendimento.clienteId != null) {
        await _clienteService.atualizarAposAtendimento(
          safeAtendimento.clienteId!,
          safeAtendimento.total,
          executor: txn,
        );
      }

      return atendimentoId;
    });
  }

  Future<void> processar(Atendimento _, int atendimentoId) async {
    SecurityUtils.sanitizeIntRange(
      atendimentoId,
      fieldName: 'ID do atendimento',
      min: 1,
      max: 1 << 30,
    );
    final existente = await getById(atendimentoId);
    if (existente == null) {
      throw const NotFoundException('Atendimento nao encontrado.');
    }
  }

  Future<void> delete(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do atendimento',
      min: 1,
      max: 1 << 30,
    );

    if (await _isFirebaseOnline()) {
      final row = await _db.queryAll(
        AppConstants.tableAtendimentos,
        where: 'id = ?',
        whereArgs: [safeId],
        limit: 1,
      );
      final firebaseId =
          row.isEmpty ? null : row.first['firebase_id'] as String?;
      final shopId = await _context.getBarbeariaIdAtual();
      if (firebaseId != null && shopId != null) {
        await FirebaseErrorHandler.wrap(() async {
          final ref = _context
              .collection(
                  barbeariaId: shopId, nome: AppConstants.tableAtendimentos)
              .doc(firebaseId);
          final itens = await ref.collection('itens').get();
          final batch = FirebaseFirestore.instance.batch();
          for (final item in itens.docs) {
            batch.delete(item.reference);
          }
          batch.delete(ref);
          await batch.commit();
        });
      }
    }

    await _db.delete(AppConstants.tableAtendimentos, 'id = ?', [safeId]);
  }

  Future<void> _syncFromFirestoreIfOnline() async {
    if (!await _isFirebaseOnline()) return;
    final shopId = await _context.getBarbeariaIdAtual();
    final uid = _auth.currentUser?.uid;
    if (shopId == null || uid == null) return;

    await FirebaseErrorHandler.wrapSilent(
      () => _syncPendingLocalAtendimentosIfOnline(shopId, uid),
    );

    await FirebaseErrorHandler.wrapSilent(() async {
      final snapshot = await _context
          .collection(barbeariaId: shopId, nome: AppConstants.tableAtendimentos)
          .orderBy('updated_at', descending: true)
          .limit(AppConstants.kSyncBatchSize)
          .get();

      for (final doc in snapshot.docs) {
        final applied =
            await _upsertAtendimentoLocal(doc.id, doc.data(), shopId);
        if (applied) {
          await _upsertItensLocalFromFirestore(doc.reference, doc.id);
        }
      }
    });
  }

  Future<void> _syncPendingLocalAtendimentosIfOnline(
    String shopId,
    String uid,
  ) async {
    final rows = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: "firebase_id IS NULL OR trim(firebase_id) = ''",
      orderBy: 'updated_at DESC',
      limit: AppConstants.kSyncBatchSize,
    );
    for (final row in rows) {
      final localId = (row['id'] as num?)?.toInt();
      if (localId == null) continue;
      await _syncAtendimentoByLocalId(localId, shopId: shopId, uid: uid);
    }
  }

  Future<void> _syncAtendimentoByLocalId(
    int atendimentoId, {
    required String shopId,
    required String uid,
  }) async {
    final rows = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: 'id = ?',
      whereArgs: [atendimentoId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    var firebaseId = row['firebase_id'] as String?;
    if (firebaseId == null || firebaseId.trim().isEmpty) {
      firebaseId = _uuid.v4();
      await _db.update(
        AppConstants.tableAtendimentos,
        {
          'firebase_id': firebaseId,
          'barbearia_id': shopId,
          'created_by': uid,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        'id = ?',
        [atendimentoId],
      );
    }

    final data = DateTime.tryParse((row['data'] as String?) ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    final ref = _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableAtendimentos)
        .doc(firebaseId);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(
        ref,
        {
          'firebase_id': firebaseId,
          'barbearia_id': shopId,
          'created_by': row['created_by'] ?? uid,
          'cliente_id': row['cliente_id'],
          'cliente_nome': row['cliente_nome'],
          'forma_pagamento': row['forma_pagamento'],
          'total': (row['total'] as num?)?.toDouble() ?? 0.0,
          'observacoes': row['observacoes'],
          'data': Timestamp.fromDate(data),
          'updated_at': FieldValue.serverTimestamp(),
          if (row['created_at'] == null)
            'created_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));

    final itemRows = await _db.queryAll(
      AppConstants.tableAtendimentoItens,
      where: 'atendimento_id = ?',
      whereArgs: [atendimentoId],
      orderBy: 'id ASC',
    );
    for (final item in itemRows) {
      batch.set(
          ref.collection('itens').doc('item_${item['id']}'),
          {
            'tipo': item['tipo'],
            'item_id': item['item_id'],
            'nome': item['nome'],
            'quantidade': item['quantidade'],
            'preco_unitario': item['preco_unitario'],
            'subtotal': ((item['quantidade'] as num?)?.toInt() ?? 1) *
                ((item['preco_unitario'] as num?)?.toDouble() ?? 0.0),
            'barbearia_id': shopId,
            'created_by': uid,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<bool> _upsertAtendimentoLocal(
    String firebaseId,
    Map<String, dynamic> data,
    String shopId,
  ) async {
    final existing = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: 'firebase_id = ?',
      whereArgs: [firebaseId],
      limit: 1,
    );

    final remoteUpdatedAt = _parseTimestamp(data['updated_at']);
    final now = DateTime.now().toUtc().toIso8601String();
    final localMap = <String, dynamic>{
      'firebase_id': firebaseId,
      'barbearia_id': shopId,
      'cliente_id': _parseInt(data['cliente_id']),
      'cliente_nome': (data['cliente_nome'] ?? '') as String,
      'forma_pagamento': data['forma_pagamento'] ?? AppConstants.pgDinheiro,
      'total': (data['total'] as num?)?.toDouble() ?? 0.0,
      'observacoes': data['observacoes'],
      'data': _normalizeTimestamp(data['data']) ?? now,
      'created_at': _normalizeTimestamp(data['created_at']) ?? now,
      'updated_at': remoteUpdatedAt?.toIso8601String() ?? now,
      'created_by': data['created_by'],
    };

    if (existing.isNotEmpty) {
      final localUpdatedAt = DateTime.tryParse(
        (existing.first['updated_at'] as String?) ?? '',
      );
      if (localUpdatedAt != null &&
          remoteUpdatedAt != null &&
          localUpdatedAt.isAfter(remoteUpdatedAt)) {
        return false;
      }
      await _db.update(
        AppConstants.tableAtendimentos,
        localMap,
        'id = ?',
        [existing.first['id']],
      );
      return true;
    }

    await _db.insert(
      AppConstants.tableAtendimentos,
      localMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  Future<void> _upsertItensLocalFromFirestore(
    DocumentReference<Map<String, dynamic>> atendimentoRef,
    String atendimentoFirebaseId,
  ) async {
    final atendimentos = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: 'firebase_id = ?',
      whereArgs: [atendimentoFirebaseId],
      limit: 1,
    );
    if (atendimentos.isEmpty) return;
    final atendimentoId = (atendimentos.first['id'] as num?)?.toInt();
    if (atendimentoId == null) return;

    final itens = await atendimentoRef.collection('itens').get();
    if (itens.docs.isEmpty) return;

    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        AppConstants.tableAtendimentoItens,
        where: 'atendimento_id = ?',
        whereArgs: [atendimentoId],
      );
      for (final itemDoc in itens.docs) {
        final data = itemDoc.data();
        await txn.insert(AppConstants.tableAtendimentoItens, {
          'atendimento_id': atendimentoId,
          'tipo': (data['tipo'] ?? 'servico') as String,
          'item_id': _parseInt(data['item_id']) ?? 0,
          'nome': (data['nome'] ?? '') as String,
          'quantidade': (data['quantidade'] as num?)?.toInt() ?? 1,
          'preco_unitario': (data['preco_unitario'] as num?)?.toDouble() ?? 0.0,
        });
      }
    });
  }

  Future<double> getFaturamentoPeriodo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[
      inicio.toUtc().toIso8601String(),
      fim.toUtc().toIso8601String(),
    ];
    if (shopIdFiltro != null) args.add(shopIdFiltro);
    final result = await _db.rawQuery('''
      SELECT SUM(total) as total FROM ${AppConstants.tableAtendimentos}
      WHERE data BETWEEN ? AND ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
    ''', args);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getFaturamentoPorDia(int dias) async {
    final safeDias = SecurityUtils.sanitizeIntRange(
      dias,
      fieldName: 'Quantidade de dias',
      min: 1,
      max: 3650,
    );
    _syncEmBackground();
    final inicio = DateTime.now()
        .toUtc()
        .subtract(Duration(days: safeDias))
        .toIso8601String();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[inicio];
    if (shopIdFiltro != null) args.add(shopIdFiltro);

    return _db.rawQuery('''
      SELECT DATE(data) as dia, SUM(total) as total, COUNT(*) as quantidade
      FROM ${AppConstants.tableAtendimentos}
      WHERE data >= ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
      GROUP BY DATE(data)
      ORDER BY dia ASC
    ''', args);
  }

  Future<Map<String, double>> getFaturamentoPorPagamento(
    DateTime inicio,
    DateTime fim,
  ) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[
      inicio.toUtc().toIso8601String(),
      fim.toUtc().toIso8601String(),
    ];
    if (shopIdFiltro != null) args.add(shopIdFiltro);
    final result = await _db.rawQuery('''
      SELECT forma_pagamento, SUM(total) as total
      FROM ${AppConstants.tableAtendimentos}
      WHERE data BETWEEN ? AND ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
      GROUP BY forma_pagamento
    ''', args);

    return {
      for (final row in result)
        row['forma_pagamento'] as String:
            (row['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<int> getCountPeriodo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Periodo invalido.');
    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[
      inicio.toUtc().toIso8601String(),
      fim.toUtc().toIso8601String(),
    ];
    if (shopIdFiltro != null) args.add(shopIdFiltro);
    final result = await _db.rawQuery('''
      SELECT COUNT(*) as total FROM ${AppConstants.tableAtendimentos}
      WHERE data BETWEEN ? AND ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
    ''', args);
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getHorariosMaisLucrativos() async {
    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[];
    if (shopIdFiltro != null) args.add(shopIdFiltro);
    return _db.rawQuery('''
      SELECT CAST(strftime('%H', data) AS INTEGER) as hora,
             COUNT(*) as quantidade,
             SUM(total) as faturamento
      FROM ${AppConstants.tableAtendimentos}
      ${shopIdFiltro == null ? '' : 'WHERE barbearia_id = ?'}
      GROUP BY hora
      ORDER BY faturamento DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getMapaHorarios() async {
    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[];
    if (shopIdFiltro != null) args.add(shopIdFiltro);
    return _db.rawQuery('''
      SELECT CAST(strftime('%H', data) AS INTEGER) as hora,
             COUNT(*) as total_atendimentos,
             SUM(total) as total_faturamento
      FROM ${AppConstants.tableAtendimentos}
      ${shopIdFiltro == null ? '' : 'WHERE barbearia_id = ?'}
      GROUP BY hora
      ORDER BY hora ASC
    ''', args);
  }

  Future<String?> _barbeariaIdParaFiltro() async {
    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return null;
    if (shopId == AppConstants.localBarbeariaId) return null;
    return shopId;
  }

  Future<List<Atendimento>> _anexarItens(List<Atendimento> atendimentos) async {
    if (atendimentos.isEmpty) return atendimentos;
    final ids =
        atendimentos.map((a) => a.id).whereType<int>().toList(growable: false);
    final itensPorAtendimento = await _getItensByAtendimentos(ids);
    return atendimentos
        .map((a) => a.copyWith(itens: itensPorAtendimento[a.id] ?? const []))
        .toList(growable: false);
  }

  Future<Map<int, List<AtendimentoItem>>> _getItensByAtendimentos(
    List<int> atendimentoIds,
  ) async {
    if (atendimentoIds.isEmpty) return <int, List<AtendimentoItem>>{};
    final placeholders = List.filled(atendimentoIds.length, '?').join(', ');
    final rows = await _db.rawQuery('''
      SELECT *
      FROM ${AppConstants.tableAtendimentoItens}
      WHERE atendimento_id IN ($placeholders)
      ORDER BY id ASC
    ''', atendimentoIds);
    final result = <int, List<AtendimentoItem>>{};
    for (final row in rows) {
      final item = AtendimentoItem.fromMap(row);
      final atendimentoId = item.atendimentoId;
      if (atendimentoId == null) continue;
      (result[atendimentoId] ??= <AtendimentoItem>[]).add(item);
    }
    return result;
  }

  AtendimentoItem _itemComAtendimento(AtendimentoItem item, int atendimentoId) {
    return AtendimentoItem(
      id: item.id,
      atendimentoId: atendimentoId,
      tipo: item.tipo,
      itemId: item.itemId,
      nome: item.nome,
      quantidade: item.quantidade,
      precoUnitario: item.precoUnitario,
    );
  }

  Map<String, dynamic> _toFirestoreMap(
    Atendimento atendimento, {
    required String firebaseId,
    required String shopId,
    required String uid,
    required DateTime data,
  }) {
    return {
      'firebase_id': firebaseId,
      'barbearia_id': shopId,
      'created_by': uid,
      'cliente_id': atendimento.clienteId,
      'cliente_nome': atendimento.clienteNome,
      'forma_pagamento': atendimento.formaPagamento,
      'total': atendimento.total,
      'observacoes': atendimento.observacoes,
      'data': Timestamp.fromDate(data.toUtc()),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  String? _normalizeTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc().toIso8601String();
    }
    return null;
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _validarTotal(Atendimento atendimento) {
    if (atendimento.itens.isEmpty) {
      throw const ValidationException(
        'Atendimento deve conter ao menos um item.',
      );
    }
    final totalCalculado =
        atendimento.itens.fold<double>(0, (soma, item) => soma + item.subtotal);
    if ((totalCalculado - atendimento.total).abs() > 0.01) {
      throw const ValidationException(
        'Total do atendimento nao confere com os itens selecionados.',
      );
    }
  }

  Atendimento _sanitizarAtendimento(Atendimento atendimento) {
    final safeClienteNome = SecurityUtils.sanitizeName(
      atendimento.clienteNome,
      fieldName: 'Nome do cliente',
    );
    final safeFormaPagamento = SecurityUtils.sanitizeEnumValue(
      atendimento.formaPagamento,
      fieldName: 'Forma de pagamento',
      allowedValues: AppConstants.formasPagamento,
    );
    final safeTotal = SecurityUtils.sanitizeDoubleRange(
      atendimento.total,
      fieldName: 'Total',
      min: 0.01,
      max: 999999,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      atendimento.observacoes,
      maxLength: 600,
      allowNewLines: true,
    );
    final safeItens = atendimento.itens.map(_sanitizarItem).toList();
    return atendimento.copyWith(
      clienteNome: safeClienteNome,
      formaPagamento: safeFormaPagamento,
      total: safeTotal,
      data: atendimento.data.toUtc(),
      observacoes: safeObs,
      itens: safeItens,
    );
  }

  AtendimentoItem _sanitizarItem(AtendimentoItem item) {
    return AtendimentoItem(
      id: item.id,
      atendimentoId: item.atendimentoId,
      tipo: SecurityUtils.sanitizeEnumValue(
        item.tipo,
        fieldName: 'Tipo do item',
        allowedValues: const ['servico', 'produto'],
      ),
      itemId: SecurityUtils.sanitizeIntRange(
        item.itemId,
        fieldName: 'ID do item',
        min: 1,
        max: 1 << 30,
      ),
      nome: SecurityUtils.sanitizeName(
        item.nome,
        fieldName: 'Nome do item',
        maxLength: 120,
      ),
      quantidade: SecurityUtils.sanitizeIntRange(
        item.quantidade,
        fieldName: 'Quantidade do item',
        min: 1,
        max: 1000,
      ),
      precoUnitario: SecurityUtils.sanitizeDoubleRange(
        item.precoUnitario,
        fieldName: 'Preco unitario',
        min: 0.01,
        max: 999999,
      ),
    );
  }
}
