import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/atendimento.dart';
import '../models/cliente.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'connectivity_service.dart';
import 'firebase_context_service.dart';
import 'service_exceptions.dart';

class ClienteService {
  final DatabaseHelper _db = DatabaseHelper();
  final FirebaseContextService _context = FirebaseContextService();
  final ConnectivityService _connectivity = ConnectivityService();
  final Uuid _uuid = const Uuid();

  bool get _firebaseDisponivel => _context.firebaseDisponivel;

  Future<bool> _isFirebaseOnline() async {
    if (!_firebaseDisponivel) return false;
    return _connectivity.isOnline();
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<List<Cliente>> getAll() async {
    await _syncFromFirestoreIfOnline();

    final maps = await _db.queryAll(
      AppConstants.tableClientes,
      orderBy: 'nome ASC',
    );
    return maps.map((m) => Cliente.fromMap(m)).toList();
  }

  Stream<List<Cliente>> streamClientes() async* {
    if (!await _isFirebaseOnline()) {
      yield await getAll();
      return;
    }

    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) {
      yield await getAll();
      return;
    }

    final query = _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableClientes)
        .orderBy('nome');

    yield* query.snapshots().asyncMap((snap) async {
      for (final doc in snap.docs) {
        await _upsertLocalFromFirestoreDoc(doc.id, doc.data(), shopId);
      }
      return snap.docs
          .map((doc) => _fromFirestore(doc.data(), doc.id, shopId))
          .toList(growable: false);
    });
  }

  Future<Cliente?> getById(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do cliente',
      min: 1,
      max: 1 << 30,
    );
    await _syncFromFirestoreIfOnline();

    final maps = await _db.queryAll(
      AppConstants.tableClientes,
      where: 'id = ?',
      whereArgs: [safeId],
    );
    if (maps.isEmpty) return null;
    return Cliente.fromMap(maps.first);
  }

  Future<List<Cliente>> search(String query) async {
    final normalized = SecurityUtils.normalizeUtf8(
      query,
      maxLength: 80,
      allowNewLines: false,
    );
    if (normalized.length < 2) return <Cliente>[];

    final maps = await _db.queryAll(
      AppConstants.tableClientes,
      where: 'nome LIKE ?',
      whereArgs: ['%$normalized%'],
      orderBy: 'nome ASC',
    );
    return maps.map((m) => Cliente.fromMap(m)).toList();
  }

  Future<int> insert(Cliente cliente) async {
    final safeCliente = _sanitizarCliente(cliente);

    if (await _isFirebaseOnline()) {
      final shopId = await _context.getBarbeariaIdAtual();
      final uid = _auth.currentUser?.uid;
      if (shopId != null && uid != null) {
        final firebaseId = _uuid.v4();
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableClientes)
            .doc(firebaseId)
            .set(
              _toFirestoreMap(
                safeCliente,
                barbeariaId: shopId,
                createdBy: uid,
                includeCreatedAt: true,
              ),
            );

        final localMap = {
          ...safeCliente.toMap(),
          'firebase_id': firebaseId,
          'barbearia_id': shopId,
          'created_by': uid,
        };
        return _db.insert(AppConstants.tableClientes, localMap);
      }
    }

    return _db.insert(AppConstants.tableClientes, safeCliente.toMap());
  }

  Future<void> update(Cliente cliente) async {
    SecurityUtils.ensure(cliente.id != null, 'ID do cliente invalido.');
    final safeCliente = _sanitizarCliente(
      cliente.copyWith(updatedAt: DateTime.now()),
    );

    if (await _isFirebaseOnline()) {
      final firebaseId = await _getFirebaseIdByLocalId(safeCliente.id!);
      final shopId = await _context.getBarbeariaIdAtual();
      final uid = _auth.currentUser?.uid;
      if (firebaseId != null && shopId != null && uid != null) {
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableClientes)
            .doc(firebaseId)
            .set(
              _toFirestoreMap(
                safeCliente,
                barbeariaId: shopId,
                createdBy: uid,
              ),
              SetOptions(merge: true),
            );
      }
    }

    await _db.update(
      AppConstants.tableClientes,
      safeCliente.toMap(),
      'id = ?',
      [safeCliente.id],
    );
  }

  Future<void> delete(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do cliente',
      min: 1,
      max: 1 << 30,
    );

    if (await _isFirebaseOnline()) {
      final firebaseId = await _getFirebaseIdByLocalId(safeId);
      final shopId = await _context.getBarbeariaIdAtual();
      if (firebaseId != null && shopId != null) {
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableClientes)
            .doc(firebaseId)
            .delete();
      }
    }

    await _db.delete(AppConstants.tableClientes, 'id = ?', [safeId]);
  }

  Future<List<Atendimento>> getHistorico(int clienteId) async {
    final safeClienteId = SecurityUtils.sanitizeIntRange(
      clienteId,
      fieldName: 'ID do cliente',
      min: 1,
      max: 1 << 30,
    );
    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: 'cliente_id = ?',
      whereArgs: [safeClienteId],
      orderBy: 'data DESC',
    );
    return maps.map((m) => Atendimento.fromMap(m)).toList();
  }

  Future<void> atualizarAposAtendimento(
    int clienteId,
    double valor, {
    DatabaseExecutor? executor,
  }) async {
    final safeClienteId = SecurityUtils.sanitizeIntRange(
      clienteId,
      fieldName: 'ID do cliente',
      min: 1,
      max: 1 << 30,
    );
    final safeValor = SecurityUtils.sanitizeDoubleRange(
      valor,
      fieldName: 'Valor do atendimento',
      min: 0,
      max: 999999,
    );

    if (executor != null) {
      await _atualizarAposAtendimento(executor, safeClienteId, safeValor);
      return;
    }

    await _db.transaction((txn) async {
      await _atualizarAposAtendimento(txn, safeClienteId, safeValor);
    });

    await _syncClienteByLocalIdIfOnline(safeClienteId);
  }

  Future<void> _atualizarAposAtendimento(
    DatabaseExecutor executor,
    int clienteId,
    double valor,
  ) async {
    final rows = await executor.query(
      AppConstants.tableClientes,
      columns: ['total_gasto', 'total_atendimentos', 'pontos_fidelidade'],
      where: 'id = ?',
      whereArgs: [clienteId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const NotFoundException('Cliente não encontrado para atualização.');
    }

    final row = rows.first;
    final totalGastoAtual = (row['total_gasto'] as num?)?.toDouble() ?? 0.0;
    final totalAtendimentosAtual =
        (row['total_atendimentos'] as num?)?.toInt() ?? 0;
    final pontosAtual = (row['pontos_fidelidade'] as num?)?.toInt() ?? 0;
    final now = DateTime.now().toIso8601String();
    await executor.update(
      AppConstants.tableClientes,
      {
        'total_gasto': totalGastoAtual + valor,
        'ultima_visita': now,
        'total_atendimentos': totalAtendimentosAtual + 1,
        'pontos_fidelidade': pontosAtual + 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [clienteId],
    );
  }

  Future<void> resgatarFidelidade(int clienteId) async {
    final safeClienteId = SecurityUtils.sanitizeIntRange(
      clienteId,
      fieldName: 'ID do cliente',
      min: 1,
      max: 1 << 30,
    );

    final cliente = await getById(safeClienteId);
    if (cliente == null) {
      throw const NotFoundException('Cliente não encontrado.');
    }

    final novoPontos = cliente.pontosFidelidade - 10;
    final atualizado = cliente.copyWith(
      pontosFidelidade: novoPontos < 0 ? 0 : novoPontos,
      updatedAt: DateTime.now(),
    );
    await update(atualizado);
  }

  Future<List<Map<String, dynamic>>> getClientesSumidos() async {
    final clientes = await getAll();
    final sumidos = <Map<String, dynamic>>[];

    for (final cliente in clientes) {
      if (cliente.totalAtendimentos < 2 || cliente.ultimaVisita == null) {
        continue;
      }

      final atendimentos = await getHistorico(cliente.id!);
      if (atendimentos.length < 2) continue;

      var somaIntervalos = 0;
      for (var i = 0; i < atendimentos.length - 1; i++) {
        final diff = atendimentos[i]
            .data
            .difference(atendimentos[i + 1].data)
            .inDays
            .abs();
        somaIntervalos += diff;
      }
      final mediaIntervaloDias = somaIntervalos / (atendimentos.length - 1);
      final diasSemVir =
          DateTime.now().difference(cliente.ultimaVisita!).inDays;
      final limite = mediaIntervaloDias + AppConstants.diasToleranciaCliente;

      if (diasSemVir > limite) {
        sumidos.add({
          'cliente': cliente,
          'diasSemVir': diasSemVir,
          'mediaIntervalo': mediaIntervaloDias.round(),
        });
      }
    }

    sumidos.sort(
      (a, b) => (b['diasSemVir'] as int).compareTo(a['diasSemVir'] as int),
    );
    return sumidos;
  }

  Future<List<Cliente>> getRanking({int limit = 10}) async {
    final safeLimit = SecurityUtils.sanitizeIntRange(
      limit,
      fieldName: 'Limite',
      min: 1,
      max: 100,
    );

    await _syncFromFirestoreIfOnline();

    final maps = await _db.queryAll(
      AppConstants.tableClientes,
      orderBy: 'total_gasto DESC',
      limit: safeLimit,
    );
    return maps.map((m) => Cliente.fromMap(m)).toList();
  }

  Future<List<Cliente>> aniversariantesHoje({DateTime? referencia}) async {
    final base = referencia ?? DateTime.now();
    final mes = base.month.toString().padLeft(2, '0');
    final dia = base.day.toString().padLeft(2, '0');
    final md = '$mes-$dia';

    await _syncFromFirestoreIfOnline();

    final rows = await _db.rawQuery('''
      SELECT *
      FROM ${AppConstants.tableClientes}
      WHERE data_nascimento IS NOT NULL
        AND data_nascimento != ''
        AND strftime('%m-%d', data_nascimento) = ?
      ORDER BY nome ASC
    ''', [md]);
    return rows.map((m) => Cliente.fromMap(m)).toList(growable: false);
  }

  Future<void> _syncFromFirestoreIfOnline() async {
    if (!await _isFirebaseOnline()) return;

    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return;

    final snap = await _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableClientes)
        .orderBy('nome')
        .get();

    for (final doc in snap.docs) {
      await _upsertLocalFromFirestoreDoc(doc.id, doc.data(), shopId);
    }
  }

  Future<void> _upsertLocalFromFirestoreDoc(
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

    final localMap = <String, dynamic>{
      'firebase_id': firebaseId,
      'barbearia_id': (data['barbearia_id'] as String?) ?? shopId,
      'created_by': data['created_by'] as String?,
      'nome': (data['nome'] ?? '') as String,
      'telefone': (data['telefone'] ?? '') as String,
      'observacoes': data['observacoes'] as String?,
      'data_nascimento': data['data_nascimento'] as String?,
      'total_gasto': (data['total_gasto'] as num?)?.toDouble() ?? 0.0,
      'ultima_visita':
          _parseOptionalFirestoreDate(data['ultima_visita'])?.toIso8601String(),
      'pontos_fidelidade': (data['pontos_fidelidade'] as num?)?.toInt() ?? 0,
      'total_atendimentos': (data['total_atendimentos'] as num?)?.toInt() ?? 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

    final existing = await _db.queryAll(
      AppConstants.tableClientes,
      where: 'firebase_id = ?',
      whereArgs: [firebaseId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await _db.update(
        AppConstants.tableClientes,
        localMap,
        'id = ?',
        [existing.first['id']],
      );
    } else {
      await _db.insert(AppConstants.tableClientes, localMap);
    }
  }

  Cliente _fromFirestore(
    Map<String, dynamic> data,
    String firebaseId,
    String shopId,
  ) {
    return Cliente.fromMap({
      'id': null,
      'firebase_id': firebaseId,
      'barbearia_id': (data['barbearia_id'] as String?) ?? shopId,
      'created_by': data['created_by'] as String?,
      'nome': (data['nome'] ?? '') as String,
      'telefone': (data['telefone'] ?? '') as String,
      'observacoes': data['observacoes'] as String?,
      'data_nascimento': data['data_nascimento'] as String?,
      'total_gasto': (data['total_gasto'] as num?)?.toDouble() ?? 0.0,
      'ultima_visita':
          _parseOptionalFirestoreDate(data['ultima_visita'])?.toIso8601String(),
      'pontos_fidelidade': (data['pontos_fidelidade'] as num?)?.toInt() ?? 0,
      'total_atendimentos': (data['total_atendimentos'] as num?)?.toInt() ?? 0,
      'created_at': _parseFirestoreDate(
        data['created_at'],
        fallback: DateTime.now(),
      ).toIso8601String(),
      'updated_at': _parseFirestoreDate(
        data['updated_at'],
        fallback: DateTime.now(),
      ).toIso8601String(),
    });
  }

  Map<String, dynamic> _toFirestoreMap(
    Cliente cliente, {
    required String barbeariaId,
    required String createdBy,
    bool includeCreatedAt = false,
  }) {
    return {
      'nome': cliente.nome,
      'telefone': cliente.telefone,
      'observacoes': cliente.observacoes,
      'data_nascimento': cliente.dataNascimento == null
          ? null
          : DateTime(
              cliente.dataNascimento!.year,
              cliente.dataNascimento!.month,
              cliente.dataNascimento!.day,
            ).toIso8601String().split('T').first,
      'total_gasto': cliente.totalGasto,
      'ultima_visita': cliente.ultimaVisita?.toIso8601String(),
      'pontos_fidelidade': cliente.pontosFidelidade,
      'total_atendimentos': cliente.totalAtendimentos,
      'barbearia_id': barbeariaId,
      'created_by': createdBy,
      if (includeCreatedAt) 'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  DateTime _parseFirestoreDate(dynamic value, {DateTime? fallback}) {
    if (value == null) {
      return fallback ?? DateTime.now();
    }
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
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

  Future<String?> _getFirebaseIdByLocalId(int localId) async {
    final rows = await _db.queryAll(
      AppConstants.tableClientes,
      where: 'id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['firebase_id'] as String?;
  }

  Future<void> _syncClienteByLocalIdIfOnline(int localId) async {
    if (!await _isFirebaseOnline()) return;

    final rows = await _db.queryAll(
      AppConstants.tableClientes,
      where: 'id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final firebaseId = rows.first['firebase_id'] as String?;
    if (firebaseId == null || firebaseId.trim().isEmpty) return;

    final shopId = await _context.getBarbeariaIdAtual();
    final uid = _auth.currentUser?.uid;
    if (shopId == null || uid == null) return;

    final cliente = Cliente.fromMap(rows.first);
    await _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableClientes)
        .doc(firebaseId)
        .set(
          _toFirestoreMap(cliente, barbeariaId: shopId, createdBy: uid),
          SetOptions(merge: true),
        );
  }

  Cliente _sanitizarCliente(Cliente cliente) {
    final safeNome =
        SecurityUtils.sanitizeName(cliente.nome, fieldName: 'Nome do cliente');
    final safeTelefone = SecurityUtils.sanitizePhone(cliente.telefone);
    final safeObs = SecurityUtils.sanitizeOptionalText(
      cliente.observacoes,
      maxLength: 500,
      allowNewLines: true,
    );
    final safeTotalGasto = SecurityUtils.sanitizeDoubleRange(
      cliente.totalGasto,
      fieldName: 'Total gasto',
      min: 0,
      max: 999999999,
    );
    final safePontos = SecurityUtils.sanitizeIntRange(
      cliente.pontosFidelidade,
      fieldName: 'Pontos de fidelidade',
      min: 0,
      max: 100000,
    );
    final safeTotalAtendimentos = SecurityUtils.sanitizeIntRange(
      cliente.totalAtendimentos,
      fieldName: 'Total de atendimentos',
      min: 0,
      max: 1000000,
    );
    DateTime? safeDataNascimento;
    if (cliente.dataNascimento != null) {
      final normalizada = DateTime(
        cliente.dataNascimento!.year,
        cliente.dataNascimento!.month,
        cliente.dataNascimento!.day,
      );
      final limiteInferior = DateTime(1900, 1, 1);
      final hoje = DateTime.now();
      SecurityUtils.ensure(
        !normalizada.isBefore(limiteInferior),
        'Data de nascimento invalida.',
      );
      SecurityUtils.ensure(
        !normalizada.isAfter(DateTime(hoje.year, hoje.month, hoje.day)),
        'Data de nascimento não pode ser futura.',
      );
      safeDataNascimento = normalizada;
    }

    return cliente.copyWith(
      nome: safeNome,
      telefone: safeTelefone,
      observacoes: safeObs,
      dataNascimento: safeDataNascimento,
      totalGasto: safeTotalGasto,
      pontosFidelidade: safePontos,
      totalAtendimentos: safeTotalAtendimentos,
    );
  }
}
