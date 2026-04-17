// ============================================================
// agenda_service.dart
// Serviço de agendamentos com Firestore (fonte principal)
// e SQLite como cache offline.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/agendamento.dart';
import '../models/item_comanda.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'comanda_service.dart';
import 'connectivity_service.dart';
import 'firebase_context_service.dart';
import 'service_exceptions.dart';
import 'servico_service.dart';

class AgendaService {
  AgendaService({
    DatabaseHelper? db,
    FirebaseContextService? context,
    ConnectivityService? connectivity,
    Uuid? uuid,
    ComandaService? comandaService,
    ServicoService? servicoService,
  })  : _db = db ?? DatabaseHelper(),
        _context = context ?? FirebaseContextService(),
        _connectivity = connectivity ?? ConnectivityService(),
        _uuid = uuid ?? const Uuid(),
        _comandaService = comandaService ?? ComandaService(),
        _servicoService = servicoService ?? ServicoService();

  final DatabaseHelper _db;
  final FirebaseContextService _context;
  final ConnectivityService _connectivity;
  final Uuid _uuid;
  final ComandaService _comandaService;
  final ServicoService _servicoService;

  bool get _firebaseDisponivel => _context.firebaseDisponivel;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<bool> _isFirebaseOnline() async {
    if (!_firebaseDisponivel) return false;
    return _connectivity.isOnline();
  }

  Future<List<Agendamento>> getAll() async {
    await _syncFromFirestoreIfOnline();

    final barbeiroFiltro = await _barbeiroFiltroAtual();
    final maps = await _db.queryAll(
      AppConstants.tableAgendamentos,
      where: barbeiroFiltro == null ? null : 'barbeiro_id = ?',
      whereArgs: barbeiroFiltro == null ? null : [barbeiroFiltro],
      orderBy: 'data_hora ASC',
    );
    return maps.map((m) => Agendamento.fromMap(m)).toList(growable: false);
  }

  Future<List<Agendamento>> getDodia(DateTime data) async {
    await _syncFromFirestoreIfOnline();

    final inicio = DateTime(data.year, data.month, data.day).toIso8601String();
    final fim =
        DateTime(data.year, data.month, data.day, 23, 59, 59).toIso8601String();
    final barbeiroFiltro = await _barbeiroFiltroAtual();

    var where = 'data_hora BETWEEN ? AND ?';
    final whereArgs = <dynamic>[inicio, fim];
    if (barbeiroFiltro != null) {
      where += ' AND barbeiro_id = ?';
      whereArgs.add(barbeiroFiltro);
    }

    final maps = await _db.queryAll(
      AppConstants.tableAgendamentos,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'data_hora ASC',
    );
    return maps.map((m) => Agendamento.fromMap(m)).toList(growable: false);
  }

  Future<List<Agendamento>> getMes(int ano, int mes) async {
    SecurityUtils.sanitizeIntRange(
      ano,
      fieldName: 'Ano',
      min: 2000,
      max: 2100,
    );
    SecurityUtils.sanitizeIntRange(
      mes,
      fieldName: 'Mes',
      min: 1,
      max: 12,
    );

    await _syncFromFirestoreIfOnline();

    final inicio = DateTime(ano, mes, 1).toIso8601String();
    final fim = DateTime(ano, mes + 1, 0, 23, 59, 59).toIso8601String();
    final barbeiroFiltro = await _barbeiroFiltroAtual();

    var where = 'data_hora BETWEEN ? AND ?';
    final whereArgs = <dynamic>[inicio, fim];
    if (barbeiroFiltro != null) {
      where += ' AND barbeiro_id = ?';
      whereArgs.add(barbeiroFiltro);
    }

    final maps = await _db.queryAll(
      AppConstants.tableAgendamentos,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'data_hora ASC',
    );
    return maps.map((m) => Agendamento.fromMap(m)).toList(growable: false);
  }

  Future<int> insert(Agendamento agendamento) async {
    final safeAgendamento = _sanitizarAgendamento(agendamento);
    final nowIso = DateTime.now().toIso8601String();
    final usuario = await _usuarioAtual();
    final barbeiroId = safeAgendamento.barbeiroId ?? usuario.uid;
    final barbeiroNome = safeAgendamento.barbeiroNome ?? usuario.nome;

    final localMap = <String, dynamic>{
      ...safeAgendamento.toMap(),
      'created_at': nowIso,
      'updated_at': nowIso,
      'barbeiro_id': barbeiroId,
      'barbeiro_nome': barbeiroNome,
      'faturamento_registrado': safeAgendamento.faturamentoRegistrado ? 1 : 0,
    };

    if (await _isFirebaseOnline()) {
      final shopId = await _context.getBarbeariaIdAtual();
      if (shopId != null && usuario.uid != null) {
        final firebaseId = _uuid.v4();
        await _context
            .collection(
                barbeariaId: shopId, nome: AppConstants.tableAgendamentos)
            .doc(firebaseId)
            .set({
          'cliente_id': safeAgendamento.clienteId,
          'cliente_nome': safeAgendamento.clienteNome,
          'servico_id': safeAgendamento.servicoId,
          'servico_nome': safeAgendamento.servicoNome,
          'barbeiro_id': barbeiroId,
          'barbeiro_nome': barbeiroNome,
          'data_hora': Timestamp.fromDate(safeAgendamento.dataHora),
          'status': safeAgendamento.status,
          'faturamento_registrado': safeAgendamento.faturamentoRegistrado,
          'observacoes': safeAgendamento.observacoes,
          'barbearia_id': shopId,
          'created_by': usuario.uid,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        localMap['firebase_id'] = firebaseId;
        localMap['barbearia_id'] = shopId;
        localMap['created_by'] = usuario.uid;
      }
    }

    return _db.insert(AppConstants.tableAgendamentos, localMap);
  }

  Future<void> update(Agendamento agendamento) async {
    SecurityUtils.ensure(agendamento.id != null, 'ID do agendamento invalido.');
    final safeAgendamento = _sanitizarAgendamento(agendamento);
    final usuario = await _usuarioAtual();

    if (await _isFirebaseOnline()) {
      await _syncLocalByIdIfOnline(safeAgendamento.id!);

      final row = await _db.queryAll(
        AppConstants.tableAgendamentos,
        where: 'id = ?',
        whereArgs: [safeAgendamento.id],
        limit: 1,
      );
      final firebaseId =
          row.isEmpty ? null : row.first['firebase_id'] as String?;
      final shopId = await _context.getBarbeariaIdAtual();
      if (firebaseId != null && shopId != null && usuario.uid != null) {
        await _context
            .collection(
                barbeariaId: shopId, nome: AppConstants.tableAgendamentos)
            .doc(firebaseId)
            .set({
          'cliente_id': safeAgendamento.clienteId,
          'cliente_nome': safeAgendamento.clienteNome,
          'servico_id': safeAgendamento.servicoId,
          'servico_nome': safeAgendamento.servicoNome,
          'barbeiro_id': safeAgendamento.barbeiroId ??
              row.first['barbeiro_id'] ??
              usuario.uid,
          'barbeiro_nome': safeAgendamento.barbeiroNome ??
              row.first['barbeiro_nome'] ??
              usuario.nome,
          'data_hora': Timestamp.fromDate(safeAgendamento.dataHora),
          'status': safeAgendamento.status,
          'faturamento_registrado': safeAgendamento.faturamentoRegistrado,
          'observacoes': safeAgendamento.observacoes,
          'barbearia_id': shopId,
          'created_by': row.first['created_by'] ?? usuario.uid,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await _db.update(
      AppConstants.tableAgendamentos,
      {
        ...safeAgendamento.toMap(),
        'faturamento_registrado': safeAgendamento.faturamentoRegistrado ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      'id = ?',
      [safeAgendamento.id],
    );
  }

  Future<void> updateStatus(int id, String status) async {
    SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do agendamento',
      min: 1,
      max: 1 << 30,
    );
    final safeStatus = SecurityUtils.sanitizeEnumValue(
      status,
      fieldName: 'Status',
      allowedValues: AppConstants.statusAgendamento,
    );

    final row = await _db.queryAll(
      AppConstants.tableAgendamentos,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (row.isEmpty) {
      throw const NotFoundException('Agendamento nao encontrado.');
    }

    final registroAtual = row.first;
    final statusAtual =
        (registroAtual['status'] as String?) ?? AppConstants.statusPendente;
    var faturamentoRegistrado =
        ((registroAtual['faturamento_registrado'] as num?)?.toInt() ?? 0) == 1;

    if (statusAtual == safeStatus) return;

    if (safeStatus == AppConstants.statusConcluido && !faturamentoRegistrado) {
      await _registrarFaturamentoAgendamento(id, registroAtual);
      faturamentoRegistrado = true;
    }

    if (await _isFirebaseOnline()) {
      final firebaseId = registroAtual['firebase_id'] as String?;
      final shopId = await _context.getBarbeariaIdAtual();
      if (firebaseId != null && shopId != null) {
        await _context
            .collection(
                barbeariaId: shopId, nome: AppConstants.tableAgendamentos)
            .doc(firebaseId)
            .update({
          'status': safeStatus,
          'faturamento_registrado': faturamentoRegistrado,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }

    await _db.update(
      AppConstants.tableAgendamentos,
      {
        'status': safeStatus,
        'faturamento_registrado': faturamentoRegistrado ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      'id = ?',
      [id],
    );
  }

  Future<void> _registrarFaturamentoAgendamento(
    int agendamentoId,
    Map<String, dynamic> agendamentoRow,
  ) async {
    final clienteId = (agendamentoRow['cliente_id'] as num?)?.toInt();
    final clienteNomeRaw = (agendamentoRow['cliente_nome'] as String?)?.trim();
    final clienteNome = (clienteNomeRaw == null || clienteNomeRaw.isEmpty)
        ? 'Cliente'
        : clienteNomeRaw;

    final servicoId = (agendamentoRow['servico_id'] as num?)?.toInt();
    if (servicoId == null) {
      throw const ValidationException(
        'Nao e possivel concluir sem servico vinculado.',
      );
    }

    final servico = await _servicoService.getById(servicoId);
    if (servico == null) {
      throw const NotFoundException('Servico do agendamento nao encontrado.');
    }

    final comanda = await _comandaService.abrirComanda(
      clienteId: clienteId,
      clienteNome: clienteNome,
      barbeiroId: agendamentoRow['barbeiro_id'] as String?,
      barbeiroNome: agendamentoRow['barbeiro_nome'] as String?,
      observacoes: 'Agendamento #$agendamentoId',
    );

    await _comandaService.adicionarItem(
      comanda.id!,
      ItemComanda(
        tipo: 'servico',
        itemId: servico.id!,
        nome: servico.nome,
        quantidade: 1,
        precoUnitario: servico.preco,
        comissaoPercentual: servico.comissaoPercentual,
      ),
    );

    await _comandaService.fecharComanda(
      comandaId: comanda.id!,
      formaPagamento: AppConstants.pgDinheiro,
      observacoes: 'Fechamento automatico do agendamento #$agendamentoId',
    );
  }

  Future<void> delete(int id) async {
    SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do agendamento',
      min: 1,
      max: 1 << 30,
    );

    if (await _isFirebaseOnline()) {
      final row = await _db.queryAll(
        AppConstants.tableAgendamentos,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final firebaseId =
          row.isEmpty ? null : row.first['firebase_id'] as String?;
      final shopId = await _context.getBarbeariaIdAtual();
      if (firebaseId != null && shopId != null) {
        await _context
            .collection(
                barbeariaId: shopId, nome: AppConstants.tableAgendamentos)
            .doc(firebaseId)
            .delete();
      }
    }

    await _db.delete(AppConstants.tableAgendamentos, 'id = ?', [id]);
  }

  Future<List<Agendamento>> getProximos({int limit = 5}) async {
    final safeLimit = SecurityUtils.sanitizeIntRange(
      limit,
      fieldName: 'Limite',
      min: 1,
      max: 100,
    );

    await _syncFromFirestoreIfOnline();

    final agora = DateTime.now().toIso8601String();
    final barbeiroFiltro = await _barbeiroFiltroAtual();

    var where = 'data_hora >= ? AND status NOT IN (?, ?)';
    final whereArgs = <dynamic>[
      agora,
      AppConstants.statusCancelado,
      AppConstants.statusConcluido,
    ];
    if (barbeiroFiltro != null) {
      where += ' AND barbeiro_id = ?';
      whereArgs.add(barbeiroFiltro);
    }

    final maps = await _db.queryAll(
      AppConstants.tableAgendamentos,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'data_hora ASC',
      limit: safeLimit,
    );
    return maps.map((m) => Agendamento.fromMap(m)).toList(growable: false);
  }

  Future<void> _syncFromFirestoreIfOnline() async {
    if (!await _isFirebaseOnline()) return;

    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return;

    await _syncPendingLocalToFirestore(shopId);

    final query = _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableAgendamentos)
        .orderBy('data_hora');

    final snap = await query.get();
    for (final doc in snap.docs) {
      await _upsertLocalFromFirestoreDoc(doc.id, doc.data(), shopId);
    }
  }

  Future<void> _syncPendingLocalToFirestore(String shopId) async {
    final usuario = await _usuarioAtual();
    if (usuario.uid == null) return;

    final rows = await _db.queryAll(
      AppConstants.tableAgendamentos,
      orderBy: 'updated_at DESC',
    );
    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      if (id == null) continue;
      await _syncLocalByIdIfOnline(id, shopId: shopId, fallbackUser: usuario);
    }
  }

  Future<void> _syncLocalByIdIfOnline(
    int id, {
    String? shopId,
    _UsuarioAtual? fallbackUser,
  }) async {
    if (!await _isFirebaseOnline()) return;

    final resolvedShopId = shopId ?? await _context.getBarbeariaIdAtual();
    if (resolvedShopId == null || resolvedShopId.trim().isEmpty) return;

    final usuario = fallbackUser ?? await _usuarioAtual();
    if (usuario.uid == null) return;

    final rows = await _db.queryAll(
      AppConstants.tableAgendamentos,
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
        AppConstants.tableAgendamentos,
        {
          'firebase_id': firebaseId,
          'barbearia_id': resolvedShopId,
          'created_by': usuario.uid,
        },
        'id = ?',
        [id],
      );
    }

    final dataHora = DateTime.tryParse((row['data_hora'] as String?) ?? '');
    if (dataHora == null) return;

    await _context
        .collection(
            barbeariaId: resolvedShopId, nome: AppConstants.tableAgendamentos)
        .doc(firebaseId)
        .set({
      'cliente_id': row['cliente_id'],
      'cliente_nome': row['cliente_nome'],
      'servico_id': row['servico_id'],
      'servico_nome': row['servico_nome'],
      'barbeiro_id': row['barbeiro_id'] ?? usuario.uid,
      'barbeiro_nome': row['barbeiro_nome'] ?? usuario.nome,
      'data_hora': Timestamp.fromDate(dataHora),
      'status': row['status'],
      'faturamento_registrado':
          ((row['faturamento_registrado'] as num?)?.toInt() ?? 0) == 1,
      'observacoes': row['observacoes'],
      'barbearia_id': resolvedShopId,
      'created_by': row['created_by'] ?? usuario.uid,
      'updated_at': FieldValue.serverTimestamp(),
      if (row['created_at'] == null) 'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final dataHora = _parseFirestoreDate(
      data['data_hora'],
      fallback: createdAt,
    );
    final faturamentoRaw = data['faturamento_registrado'];
    final faturamentoRegistrado = faturamentoRaw is bool
        ? faturamentoRaw
        : ((faturamentoRaw as num?)?.toInt() ?? 0) == 1;

    final localMap = <String, dynamic>{
      'firebase_id': firebaseId,
      'barbearia_id': (data['barbearia_id'] as String?) ?? shopId,
      'created_by': data['created_by'] as String?,
      'cliente_id': (data['cliente_id'] as num?)?.toInt(),
      'cliente_nome': (data['cliente_nome'] ?? '') as String,
      'servico_id': (data['servico_id'] as num?)?.toInt(),
      'servico_nome': (data['servico_nome'] ?? '') as String,
      'barbeiro_id': data['barbeiro_id'] as String?,
      'barbeiro_nome': data['barbeiro_nome'] as String?,
      'data_hora': dataHora.toIso8601String(),
      'status': (data['status'] ?? AppConstants.statusPendente) as String,
      'faturamento_registrado': faturamentoRegistrado ? 1 : 0,
      'observacoes': data['observacoes'] as String?,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };

    final existing = await _db.queryAll(
      AppConstants.tableAgendamentos,
      where: 'firebase_id = ?',
      whereArgs: [firebaseId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await _db.update(
        AppConstants.tableAgendamentos,
        localMap,
        'id = ?',
        [existing.first['id']],
      );
      return;
    }

    await _db.insert(AppConstants.tableAgendamentos, localMap);
  }

  Future<String?> _barbeiroFiltroAtual() async {
    final usuario = await _usuarioAtual();
    if (usuario.role == AppConstants.roleBarbeiro) {
      return usuario.uid;
    }
    return null;
  }

  Future<_UsuarioAtual> _usuarioAtual() async {
    if (!_firebaseDisponivel) {
      return const _UsuarioAtual(uid: null, role: null, nome: null);
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      return const _UsuarioAtual(uid: null, role: null, nome: null);
    }

    final rows = await _db.queryAll(
      AppConstants.tableUsuarios,
      where: 'id = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) {
      return _UsuarioAtual(uid: uid, role: null, nome: null);
    }

    final row = rows.first;
    return _UsuarioAtual(
      uid: uid,
      role: row['role'] as String?,
      nome: row['nome'] as String?,
    );
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

  Agendamento _sanitizarAgendamento(Agendamento agendamento) {
    final safeClienteNome = SecurityUtils.sanitizeName(
      agendamento.clienteNome,
      fieldName: 'Nome do cliente',
    );
    final safeServicoNome = SecurityUtils.sanitizeName(
      agendamento.servicoNome,
      fieldName: 'Nome do servico',
    );
    final safeStatus = SecurityUtils.sanitizeEnumValue(
      agendamento.status,
      fieldName: 'Status',
      allowedValues: AppConstants.statusAgendamento,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      agendamento.observacoes,
      maxLength: 500,
      allowNewLines: true,
    );
    final safeBarbeiroId = SecurityUtils.sanitizeOptionalText(
      agendamento.barbeiroId,
      maxLength: 200,
      allowNewLines: false,
    );
    final safeBarbeiroNome = agendamento.barbeiroNome == null
        ? null
        : SecurityUtils.sanitizeName(
            agendamento.barbeiroNome!,
            fieldName: 'Nome do barbeiro',
          );

    return agendamento.copyWith(
      clienteNome: safeClienteNome,
      servicoNome: safeServicoNome,
      barbeiroId: safeBarbeiroId,
      barbeiroNome: safeBarbeiroNome,
      status: safeStatus,
      observacoes: safeObs,
    );
  }
}

class _UsuarioAtual {
  final String? uid;
  final String? role;
  final String? nome;

  const _UsuarioAtual({
    required this.uid,
    required this.role,
    required this.nome,
  });
}
