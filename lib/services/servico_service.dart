// ============================================================
// servico_service.dart
// Servico CRUD de servicos com Firestore + cache SQLite.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/servico.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'connectivity_service.dart';
import 'firebase_context_service.dart';

class ServicoService {
  final DatabaseHelper _db = DatabaseHelper();
  final FirebaseContextService _context = FirebaseContextService();
  final ConnectivityService _connectivity = ConnectivityService();
  final Uuid _uuid = const Uuid();

  bool get _firebaseDisponivel => Firebase.apps.isNotEmpty;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<bool> _isFirebaseOnline() async {
    if (!_firebaseDisponivel) return false;
    return _connectivity.isOnline();
  }

  Future<List<Servico>> getAll({bool apenasAtivos = true}) async {
    await _syncFromFirestoreIfOnline();

    final maps = await _db.queryAll(
      AppConstants.tableServicos,
      where: apenasAtivos ? 'ativo = 1' : null,
      orderBy: 'nome ASC',
    );
    return maps.map((m) => Servico.fromMap(m)).toList(growable: false);
  }

  Future<Servico?> getById(int id) async {
    SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do servico',
      min: 1,
      max: 1 << 30,
    );
    await _syncFromFirestoreIfOnline();

    final maps = await _db.queryAll(
      AppConstants.tableServicos,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Servico.fromMap(maps.first);
  }

  Future<int> insert(Servico servico) async {
    final safeServico = _sanitizarServico(servico);

    if (await _isFirebaseOnline()) {
      final shopId = await _context.getBarbeariaIdAtual();
      final uid = _auth.currentUser?.uid;
      if (shopId != null && uid != null) {
        final firebaseId = _uuid.v4();

        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableServicos)
            .doc(firebaseId)
            .set({
          'nome': safeServico.nome,
          'preco': safeServico.preco,
          'duracao_minutos': safeServico.duracaoMinutos,
          'comissao_percentual': safeServico.comissaoPercentual,
          'ativo': safeServico.ativo,
          'barbearia_id': shopId,
          'created_by': uid,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        return _db.insert(AppConstants.tableServicos, {
          ...safeServico.toMap(),
          'firebase_id': firebaseId,
          'barbearia_id': shopId,
          'created_by': uid,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }

    return _db.insert(AppConstants.tableServicos, safeServico.toMap());
  }

  Future<void> update(Servico servico) async {
    SecurityUtils.ensure(servico.id != null, 'ID do servico invalido.');
    final safeServico = _sanitizarServico(servico);

    if (await _isFirebaseOnline()) {
      final row = await _db.queryAll(
        AppConstants.tableServicos,
        where: 'id = ?',
        whereArgs: [safeServico.id],
        limit: 1,
      );
      final firebaseId = row.isEmpty ? null : row.first['firebase_id'] as String?;
      final shopId = await _context.getBarbeariaIdAtual();
      final uid = _auth.currentUser?.uid;
      if (firebaseId != null && shopId != null && uid != null) {
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableServicos)
            .doc(firebaseId)
            .set({
          'nome': safeServico.nome,
          'preco': safeServico.preco,
          'duracao_minutos': safeServico.duracaoMinutos,
          'comissao_percentual': safeServico.comissaoPercentual,
          'ativo': safeServico.ativo,
          'barbearia_id': shopId,
          'created_by': uid,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await _db.update(
      AppConstants.tableServicos,
      {
        ...safeServico.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      'id = ?',
      [safeServico.id],
    );
  }

  Future<void> delete(int id) async {
    SecurityUtils.sanitizeIntRange(
      id,
      fieldName: 'ID do servico',
      min: 1,
      max: 1 << 30,
    );

    if (await _isFirebaseOnline()) {
      final row = await _db.queryAll(
        AppConstants.tableServicos,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final firebaseId = row.isEmpty ? null : row.first['firebase_id'] as String?;
      final shopId = await _context.getBarbeariaIdAtual();
      if (firebaseId != null && shopId != null) {
        await _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableServicos)
            .doc(firebaseId)
            .set({
          'ativo': false,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await _db.update(
      AppConstants.tableServicos,
      {'ativo': 0, 'updated_at': DateTime.now().toIso8601String()},
      'id = ?',
      [id],
    );
  }

  Future<List<Map<String, dynamic>>> getMaisRealizados({int limit = 5}) async {
    final safeLimit = SecurityUtils.sanitizeIntRange(
      limit,
      fieldName: 'Limite',
      min: 1,
      max: 100,
    );

    return _db.rawQuery('''
      SELECT
        ai.nome,
        SUM(ai.quantidade) as total_vendas,
        SUM(ai.quantidade * ai.preco_unitario) as faturamento_total
      FROM ${AppConstants.tableAtendimentoItens} ai
      WHERE ai.tipo = 'servico'
      GROUP BY ai.nome
      ORDER BY total_vendas DESC
      LIMIT ?
    ''', [safeLimit]);
  }

  Future<void> _syncFromFirestoreIfOnline() async {
    if (!await _isFirebaseOnline()) return;
    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null || shopId.trim().isEmpty) return;

    final snap = await _context
        .collection(barbeariaId: shopId, nome: AppConstants.tableServicos)
        .orderBy('nome')
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final existing = await _db.queryAll(
        AppConstants.tableServicos,
        where: 'firebase_id = ?',
        whereArgs: [doc.id],
        limit: 1,
      );
      final map = <String, dynamic>{
        'firebase_id': doc.id,
        'barbearia_id': (data['barbearia_id'] as String?) ?? shopId,
        'created_by': data['created_by'] as String?,
        'nome': (data['nome'] ?? '') as String,
        'preco': (data['preco'] as num?)?.toDouble() ?? 0.0,
        'duracao_minutos': (data['duracao_minutos'] as num?)?.toInt() ?? 30,
        'comissao_percentual':
            (data['comissao_percentual'] as num?)?.toDouble() ?? 0.5,
        'ativo': ((data['ativo'] as bool?) ?? true) ? 1 : 0,
        'created_at': data['created_at'] is Timestamp
            ? (data['created_at'] as Timestamp).toDate().toIso8601String()
            : DateTime.now().toIso8601String(),
        'updated_at': data['updated_at'] is Timestamp
            ? (data['updated_at'] as Timestamp).toDate().toIso8601String()
            : DateTime.now().toIso8601String(),
      };

      if (existing.isEmpty) {
        await _db.insert(AppConstants.tableServicos, map);
      } else {
        await _db.update(
          AppConstants.tableServicos,
          map,
          'id = ?',
          [existing.first['id']],
        );
      }
    }
  }

  Servico _sanitizarServico(Servico servico) {
    final safeNome =
        SecurityUtils.sanitizeName(servico.nome, fieldName: 'Nome do servico');
    final safePreco = SecurityUtils.sanitizeDoubleRange(
      servico.preco,
      fieldName: 'Preco',
      min: 0.01,
      max: 99999,
    );
    final safeDuracao = SecurityUtils.sanitizeIntRange(
      servico.duracaoMinutos,
      fieldName: 'Duracao',
      min: 5,
      max: 720,
    );
    final safeComissao = SecurityUtils.sanitizeDoubleRange(
      servico.comissaoPercentual,
      fieldName: 'Comissao',
      min: 0,
      max: 1,
    );

    return servico.copyWith(
      nome: safeNome,
      preco: safePreco,
      duracaoMinutos: safeDuracao,
      comissaoPercentual: safeComissao,
    );
  }
}
