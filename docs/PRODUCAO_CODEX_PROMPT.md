# Severus Barber Pro — Codex Prompt: Produção
# Gerado em 2026-05-04 após auditoria completa do estado atual do código

## CONTEXTO DO PROJETO

App Flutter (Dart 3.x) de gestão de barbearia multi-tenant.
- Firebase Auth + Cloud Firestore como fonte principal de dados
- SQLite (sqflite) como cache offline — arquitetura dual-write
- Provider (ChangeNotifier) para estado
- Estrutura Firestore: `barbearias/{shopId}/{collection}/{docId}`

**Objetivo deste prompt:** levar o app ao estado mínimo viável para produção.
Todos os itens abaixo são bugs ou gaps confirmados lendo o código-fonte atual.

---

## LEGENDA

```
[FIXAR]   → Implementar agora
[VERIFICAR] → Parcialmente resolvido, conferir e completar
[INFO]    → Contexto/referência, não implementar
```

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-01 — [FIXAR] AtendimentoService é 100% SQLite — dados não sincronizam
## ══════════════════════════════════════════════════════════════════

**Arquivo:** `lib/services/atendimento_service.dart`

**Problema:**
`AtendimentoService` usa exclusivamente `DatabaseHelper` (SQLite). Não tem Firebase,
não tem `FirebaseContextService`, não tem nenhum sync. Isso significa:
- Atendimentos criados em um dispositivo nunca aparecem em outro
- Reinstalar o app apaga todos os atendimentos
- Relatórios financeiros em `financeiro_service.dart → getResumo()` consultam
  `tableAtendimentos` via SQLite para "faturamento legado" — esses dados não existem
  no Firestore

**Fix — migrar AtendimentoService para Firestore com cache SQLite offline:**

```dart
// lib/services/atendimento_service.dart — REESCREVER COMPLETO

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
import 'connectivity_service.dart';
import 'cliente_service.dart';
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

  // ── READ ──────────────────────────────────────────────────────────────

  Future<List<Atendimento>> getAll({int? limit}) async {
    if (limit != null) {
      SecurityUtils.sanitizeIntRange(limit, fieldName: 'Limite', min: 1, max: 1000);
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
      id, fieldName: 'ID do atendimento', min: 1, max: 1 << 30,
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
    final inicio = DateTime.utc(agora.year, agora.month, agora.day).toIso8601String();
    final fim = DateTime.utc(agora.year, agora.month, agora.day, 23, 59, 59).toIso8601String();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: shopIdFiltro == null
          ? 'data BETWEEN ? AND ?'
          : 'data BETWEEN ? AND ? AND barbearia_id = ?',
      whereArgs: shopIdFiltro == null ? [inicio, fim] : [inicio, fim, shopIdFiltro],
      orderBy: 'data DESC',
    );
    final atendimentos = maps.map((m) => Atendimento.fromMap(m)).toList();
    return _anexarItens(atendimentos);
  }

  Future<List<Atendimento>> getPorPeriodo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Período inválido.');
    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final inicioUtc = inicio.toUtc().toIso8601String();
    final fimUtc = fim.toUtc().toIso8601String();
    final maps = await _db.queryAll(
      AppConstants.tableAtendimentos,
      where: shopIdFiltro == null
          ? 'data BETWEEN ? AND ?'
          : 'data BETWEEN ? AND ? AND barbearia_id = ?',
      whereArgs: shopIdFiltro == null ? [inicioUtc, fimUtc] : [inicioUtc, fimUtc, shopIdFiltro],
      orderBy: 'data DESC',
    );
    final atendimentos = maps.map((m) => Atendimento.fromMap(m)).toList();
    return _anexarItens(atendimentos);
  }

  // ── WRITE ─────────────────────────────────────────────────────────────

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

    // Escreve no Firestore primeiro (se online)
    if (shopId != null && uid != null) {
      await FirebaseErrorHandler.wrap(() async {
        final atRef = _context.collection(
          barbeariaId: shopId!,
          nome: AppConstants.tableAtendimentos,
        ).doc(firebaseId);

        final batch = FirebaseFirestore.instance.batch();
        batch.set(atRef, {
          'firebase_id': firebaseId,
          'barbearia_id': shopId,
          'created_by': uid,
          'cliente_id': safeAtendimento.clienteId,
          'cliente_nome': safeAtendimento.clienteNome,
          'forma_pagamento': safeAtendimento.formaPagamento,
          'total': safeAtendimento.total,
          'observacoes': safeAtendimento.observacoes,
          'data': Timestamp.fromDate(agora),
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        for (final item in safeAtendimento.itens) {
          final itemRef = atRef.collection('itens').doc(_uuid.v4());
          batch.set(itemRef, {
            'tipo': item.tipo,
            'item_id': item.itemId,
            'nome': item.nome,
            'quantidade': item.quantidade,
            'preco_unitario': item.precoUnitario,
            'subtotal': item.subtotal,
            'barbearia_id': shopId,
          });
        }
        await batch.commit();
      });
    }

    // Escreve no SQLite (cache local + fallback offline)
    final db = await _db.database;
    return db.transaction((txn) async {
      final localMap = <String, dynamic>{
        ...safeAtendimento.toMap(),
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

  Future<void> delete(int id) async {
    final safeId = SecurityUtils.sanitizeIntRange(
      id, fieldName: 'ID do atendimento', min: 1, max: 1 << 30,
    );

    // Remove do Firestore se tiver firebase_id
    if (await _isFirebaseOnline()) {
      final row = await _db.queryAll(
        AppConstants.tableAtendimentos,
        where: 'id = ?',
        whereArgs: [safeId],
        limit: 1,
      );
      final firebaseId = row.isEmpty ? null : row.first['firebase_id'] as String?;
      final shopId = await _context.getBarbeariaIdAtual();
      if (firebaseId != null && shopId != null) {
        await FirebaseErrorHandler.wrap(() => _context
            .collection(barbeariaId: shopId, nome: AppConstants.tableAtendimentos)
            .doc(firebaseId)
            .delete());
      }
    }

    await _db.delete(AppConstants.tableAtendimentos, 'id = ?', [safeId]);
  }

  // ── SYNC ──────────────────────────────────────────────────────────────

  Future<void> _syncFromFirestoreIfOnline() async {
    if (!await _isFirebaseOnline()) return;
    final shopId = await _context.getBarbeariaIdAtual();
    if (shopId == null) return;

    try {
      final snapshot = await _context
          .collection(barbeariaId: shopId, nome: AppConstants.tableAtendimentos)
          .orderBy('updated_at', descending: true)
          .limit(AppConstants.kSyncBatchSize)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        await _upsertAtendimentoLocal(doc.id, data, shopId);
      }
    } catch (_) {}
  }

  Future<void> _upsertAtendimentoLocal(
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
      'cliente_id': data['cliente_id'],
      'cliente_nome': data['cliente_nome'] ?? '',
      'forma_pagamento': data['forma_pagamento'] ?? AppConstants.pgDinheiro,
      'total': (data['total'] as num?)?.toDouble() ?? 0.0,
      'observacoes': data['observacoes'],
      'data': _normalizeTimestamp(data['data']),
      'created_at': _normalizeTimestamp(data['created_at']) ?? now,
      'updated_at': remoteUpdatedAt?.toIso8601String() ?? now,
      'created_by': data['created_by'],
    };

    if (existing.isEmpty) {
      await _db.insert(AppConstants.tableAtendimentos, localMap);
    } else {
      final localUpdatedAt = DateTime.tryParse(
        (existing.first['updated_at'] as String?) ?? '',
      );
      if (localUpdatedAt != null &&
          remoteUpdatedAt != null &&
          localUpdatedAt.isAfter(remoteUpdatedAt)) {
        return; // local é mais novo — não sobrescrever
      }
      await _db.update(
        AppConstants.tableAtendimentos,
        localMap,
        'firebase_id = ?',
        [firebaseId],
      );
    }
  }

  // ── ANALYTICS (mantidas, só adiciona filtro barbearia) ────────────────

  Future<double> getFaturamentoPeriodo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Período inválido.');
    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[inicio.toUtc().toIso8601String(), fim.toUtc().toIso8601String()];
    if (shopIdFiltro != null) args.add(shopIdFiltro);
    final result = await _db.rawQuery('''
      SELECT SUM(total) as total FROM ${AppConstants.tableAtendimentos}
      WHERE data BETWEEN ? AND ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
    ''', args);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getFaturamentoPorPagamento(
    DateTime inicio, DateTime fim,
  ) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Período inválido.');
    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[inicio.toUtc().toIso8601String(), fim.toUtc().toIso8601String()];
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
        row['forma_pagamento'] as String: (row['total'] as num).toDouble(),
    };
  }

  Future<int> getCountPeriodo(DateTime inicio, DateTime fim) async {
    SecurityUtils.ensure(!fim.isBefore(inicio), 'Período inválido.');
    _syncEmBackground();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[inicio.toUtc().toIso8601String(), fim.toUtc().toIso8601String()];
    if (shopIdFiltro != null) args.add(shopIdFiltro);
    final result = await _db.rawQuery('''
      SELECT COUNT(*) as total FROM ${AppConstants.tableAtendimentos}
      WHERE data BETWEEN ? AND ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
    ''', args);
    return (result.first['total'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getFaturamentoPorDia(int dias) async {
    final safeDias = SecurityUtils.sanitizeIntRange(
      dias, fieldName: 'Quantidade de dias', min: 1, max: 3650,
    );
    _syncEmBackground();
    final inicio = DateTime.now().toUtc().subtract(Duration(days: safeDias)).toIso8601String();
    final shopIdFiltro = await _barbeariaIdParaFiltro();
    final args = <dynamic>[inicio];
    if (shopIdFiltro != null) args.add(shopIdFiltro);
    return _db.rawQuery('''
      SELECT DATE(data) as dia, SUM(total) as total, COUNT(*) as quantidade
      FROM ${AppConstants.tableAtendimentos}
      WHERE data >= ?
        ${shopIdFiltro == null ? '' : 'AND barbearia_id = ?'}
      GROUP BY DATE(data) ORDER BY dia ASC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getHorariosMaisLucrativos() async {
    _syncEmBackground();
    return _db.rawQuery('''
      SELECT CAST(strftime('%H', data) AS INTEGER) as hora,
             COUNT(*) as quantidade, SUM(total) as faturamento
      FROM ${AppConstants.tableAtendimentos}
      GROUP BY hora ORDER BY faturamento DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getMapaHorarios() async {
    _syncEmBackground();
    return _db.rawQuery('''
      SELECT CAST(strftime('%H', data) AS INTEGER) as hora,
             COUNT(*) as total_atendimentos, SUM(total) as total_faturamento
      FROM ${AppConstants.tableAtendimentos}
      GROUP BY hora ORDER BY hora ASC
    ''');
  }

  // ── processar (mantido para compatibilidade) ──────────────────────────
  Future<void> processar(Atendimento _, int atendimentoId) async {
    SecurityUtils.sanitizeIntRange(
      atendimentoId, fieldName: 'ID do atendimento', min: 1, max: 1 << 30,
    );
    final existente = await getById(atendimentoId);
    if (existente == null) throw const NotFoundException('Atendimento não encontrado.');
  }

  // ── HELPERS ───────────────────────────────────────────────────────────

  Future<String?> _barbeariaIdParaFiltro() async {
    if (!_firebaseDisponivel) return null;
    return _context.getBarbeariaIdAtual();
  }

  Future<List<Atendimento>> _anexarItens(List<Atendimento> atendimentos) async {
    if (atendimentos.isEmpty) return atendimentos;
    final ids = atendimentos.map((a) => a.id).whereType<int>().toList();
    final itensPorAtendimento = await _getItensByAtendimentos(ids);
    return atendimentos
        .map((a) => a.copyWith(itens: itensPorAtendimento[a.id] ?? const []))
        .toList(growable: false);
  }

  Future<Map<int, List<AtendimentoItem>>> _getItensByAtendimentos(
    List<int> atendimentoIds,
  ) async {
    if (atendimentoIds.isEmpty) return {};
    final placeholders = List.filled(atendimentoIds.length, '?').join(', ');
    final rows = await _db.rawQuery('''
      SELECT * FROM ${AppConstants.tableAtendimentoItens}
      WHERE atendimento_id IN ($placeholders) ORDER BY id ASC
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

  void _validarTotal(Atendimento atendimento) {
    if (atendimento.itens.isEmpty) {
      throw const ValidationException('Atendimento deve conter ao menos um item.');
    }
    final totalCalculado =
        atendimento.itens.fold<double>(0, (soma, item) => soma + item.subtotal);
    if ((totalCalculado - atendimento.total).abs() > 0.01) {
      throw const ValidationException(
          'Total do atendimento não confere com os itens selecionados.');
    }
  }

  Atendimento _sanitizarAtendimento(Atendimento atendimento) {
    final safeClienteNome =
        SecurityUtils.sanitizeName(atendimento.clienteNome, fieldName: 'Nome do cliente');
    final safeFormaPagamento = SecurityUtils.sanitizeEnumValue(
      atendimento.formaPagamento,
      fieldName: 'Forma de pagamento',
      allowedValues: AppConstants.formasPagamento,
    );
    final safeTotal = SecurityUtils.sanitizeDoubleRange(
      atendimento.total, fieldName: 'Total', min: 0.01, max: 999999,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      atendimento.observacoes, maxLength: 600, allowNewLines: true,
    );
    final safeItens = atendimento.itens.map(_sanitizarItem).toList();
    return atendimento.copyWith(
      clienteNome: safeClienteNome,
      formaPagamento: safeFormaPagamento,
      total: safeTotal,
      observacoes: safeObs,
      itens: safeItens,
    );
  }

  AtendimentoItem _sanitizarItem(AtendimentoItem item) {
    return AtendimentoItem(
      id: item.id,
      atendimentoId: item.atendimentoId,
      tipo: SecurityUtils.sanitizeEnumValue(item.tipo,
          fieldName: 'Tipo do item', allowedValues: const ['servico', 'produto']),
      itemId: SecurityUtils.sanitizeIntRange(item.itemId,
          fieldName: 'ID do item', min: 1, max: 1 << 30),
      nome: SecurityUtils.sanitizeName(item.nome, fieldName: 'Nome do item', maxLength: 120),
      quantidade: SecurityUtils.sanitizeIntRange(item.quantidade,
          fieldName: 'Quantidade do item', min: 1, max: 1000),
      precoUnitario: SecurityUtils.sanitizeDoubleRange(item.precoUnitario,
          fieldName: 'Preco unitario', min: 0.01, max: 999999),
    );
  }
}
```

**Lembrete de migração de dados legados:**
Em `database_helper.dart → _migrateToV8` (ou a próxima versão do schema), adicionar:
```dart
// Adicionar coluna firebase_id na tabela atendimentos se não existir
await _addColumnIfMissing(db, AppConstants.tableAtendimentos, 'firebase_id', 'TEXT');
await _addColumnIfMissing(db, AppConstants.tableAtendimentos, 'barbearia_id', 'TEXT');
await _addColumnIfMissing(db, AppConstants.tableAtendimentos, 'created_by', 'TEXT');
await _addColumnIfMissing(db, AppConstants.tableAtendimentos, 'created_at', 'TEXT');
await _addColumnIfMissing(db, AppConstants.tableAtendimentos, 'updated_at', 'TEXT');
```

Atualizar `AppConstants.dbVersion` de 7 para 8.

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-02 — [FIXAR] Timezone: DateTime.now() sem .toUtc() em toda a codebase
## ══════════════════════════════════════════════════════════════════

**Arquivos afetados (buscar com grep):**
- `lib/services/comanda_service.dart` (linha 177: `getComandasHoje` usa `DateTime.now()`)
- `lib/services/financeiro_service.dart` (linha 536: `sangria()` usa `DateTime.now()`)
- Todos os services — grep por `DateTime.now().toIso8601String()`

**Problema confirmado em `getComandasHoje` (comanda_service.dart:173-179):**
```dart
// ATUAL — ERRADO (hora local, sem timezone)
final hoje = DateTime.now();
final inicio = DateTime(hoje.year, hoje.month, hoje.day).toIso8601String();
final fim = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59).toIso8601String();
```

**Fix global — aplicar em TODOS os arquivos de service e controller:**

REGRA 1 — Toda data armazenada deve ser UTC:
```dart
// Substituir:
DateTime.now().toIso8601String()
// Por:
DateTime.now().toUtc().toIso8601String()
```

REGRA 2 — Boundaries de data devem usar UTC midnight:
```dart
// Em getComandasHoje() e qualquer query "hoje":
final agora = DateTime.now().toUtc();
final inicio = DateTime.utc(agora.year, agora.month, agora.day).toIso8601String();
final fim = DateTime.utc(agora.year, agora.month, agora.day, 23, 59, 59).toIso8601String();
```

REGRA 3 — `_normalizeDate` / `_normalizeDateValue` em qualquer service já existente:
```dart
String _normalizeDate(dynamic value) {
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc().toIso8601String();
  }
  return DateTime.now().toUtc().toIso8601String();
}
```

REGRA 4 — Migração de dados existentes no SQLite (adicionar em `_migrateToV8`):
```dart
// Para cada tabela com campo de data, converter strings sem 'Z' para UTC
// Exemplo para tableDespesas:
final rows = await db.query(AppConstants.tableDespesas, columns: ['id', 'data']);
for (final row in rows) {
  final raw = row['data'] as String?;
  if (raw == null || raw.endsWith('Z')) continue;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) continue;
  await db.update(
    AppConstants.tableDespesas,
    {'data': parsed.toUtc().toIso8601String()},
    'id = ?',
    [row['id']],
  );
}
// Repetir para: tableComandas, tableCaixas, tableAtendimentos, tableAgendamentos
```

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-03 — [FIXAR] B-13: getComandasHoje usa data_abertura em vez de data_fechamento
## ══════════════════════════════════════════════════════════════════

**Arquivo:** `lib/services/comanda_service.dart → getComandasHoje()`

**Problema:**
A query atual filtra por `data_abertura`, que é quando a comanda foi aberta.
Para fins financeiros/operacionais do dia, a data relevante é `data_fechamento`
(quando foi paga). Uma comanda aberta ontem e fechada hoje aparece no dia errado.

**Fix:**
```dart
Future<List<Comanda>> getComandasHoje({String? barbeiroId}) async {
  _syncEmBackground();

  final agora = DateTime.now().toUtc();
  final inicio = DateTime.utc(agora.year, agora.month, agora.day).toIso8601String();
  final fim = DateTime.utc(agora.year, agora.month, agora.day, 23, 59, 59).toIso8601String();

  final safeBarbeiroId = barbeiroId == null
      ? null
      : SecurityUtils.sanitizeIdentifier(barbeiroId, fieldName: 'ID do barbeiro', minLength: 1);
  final shopIdFiltro = await _barbeariaIdParaFiltro();

  final whereParts = <String>[];
  final whereArgs = <dynamic>[];

  // Comandas fechadas hoje (financeiro) OU abertas hoje ainda em aberto (operacional)
  whereParts.add(
    '(data_fechamento BETWEEN ? AND ?) OR (status = ? AND data_abertura BETWEEN ? AND ?)',
  );
  whereArgs.addAll([inicio, fim, AppConstants.comandaAberta, inicio, fim]);

  if (safeBarbeiroId != null) {
    whereParts.add('barbeiro_id = ?');
    whereArgs.add(safeBarbeiroId);
  }
  if (shopIdFiltro != null) {
    whereParts.add('barbearia_id = ?');
    whereArgs.add(shopIdFiltro);
  }

  final maps = await _db.queryAll(
    AppConstants.tableComandas,
    where: whereParts.join(' AND '),
    whereArgs: whereArgs,
    orderBy: 'data_abertura DESC',
  );
  final comandas = maps.map((m) => Comanda.fromMap(m)).toList();
  return _anexarItens(comandas);
}
```

Verificar também `getFaturamentoPeriodo` em `comanda_service.dart` — garantir que
ele filtra por `data_fechamento` e não por `data_abertura` para faturamento correto:
```dart
// A query de faturamento deve usar data_fechamento:
WHERE status = '${AppConstants.comandaFechada}'
  AND data_fechamento BETWEEN ? AND ?
```

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-04 — [VERIFICAR] B-02: fecharCaixa — atomicidade SQLite↔Firebase
## ══════════════════════════════════════════════════════════════════

**Arquivo:** `lib/services/financeiro_service.dart → fecharCaixa()`

**Estado atual:**
O Firebase já usa `runTransaction` para `abrirCaixa` e `_registrarOperacaoCaixaFirebase`.
O `fecharCaixa` chama `_fecharCaixaFirebase` (que também usa `runTransaction`).
Porém, se Firebase confirmar o fechamento mas o SQLite update subsequente falhar,
o app fica em estado inconsistente (Firebase=fechado, SQLite=aberto).

**Fix — verificar e garantir a ordem:**
```dart
Future<void> fecharCaixa(int caixaId, {String? operationId}) async {
  // ... sanitização existente ...

  // 1. Atualizar SQLite primeiro com status 'fechando' (ou usar transação local)
  final db = await _db.database;
  await db.transaction((txn) async {
    // 2. Só depois chamar Firebase
    final session = await _firebaseSession();
    if (session != null) {
      final firebaseCaixaId = await _firebaseCaixaIdFromLocalId(safeCaixaId);
      if (firebaseCaixaId != null) {
        await _fecharCaixaFirebase(
          barbeariaId: session.barbeariaId,
          userId: session.userId,
          caixaId: firebaseCaixaId,
          operationId: operationId ?? 'fechamento_$firebaseCaixaId',
        );
      }
    }

    // 3. SQLite fecha atomicamente
    await txn.update(
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
  });
}
```

**Verificar também `_upsertCaixaLocalFromFirestore`:**
Garantir que ele tem a comparação de timestamps antes de sobrescrever estado local:
```dart
Future<void> _upsertCaixaLocalFromFirestore(
  Map<String, dynamic> data,
  String shopId,
) async {
  final firebaseId = data['firebase_id'] as String? ?? data['id'] as String?;
  if (firebaseId == null) return;

  final existing = await _db.queryAll(
    AppConstants.tableCaixas,
    where: 'firebase_id = ?',
    whereArgs: [firebaseId],
    limit: 1,
  );

  final remoteUpdatedAt = _parseOptionalDate(data['updated_at']);

  if (existing.isNotEmpty) {
    final localUpdatedAt = DateTime.tryParse(
      (existing.first['updated_at'] as String?) ?? '',
    );
    // Se local é mais novo, não sobrescrever (especialmente status 'fechado')
    if (localUpdatedAt != null &&
        remoteUpdatedAt != null &&
        localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return;
    }
  }

  // ... continuar com upsert normal ...
}
```

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-05 — [FIXAR] B-08: Sem resolução de conflito no sync bidirecional
## ══════════════════════════════════════════════════════════════════

**Arquivos:** `lib/services/comanda_service.dart`, `lib/services/financeiro_service.dart`,
`lib/services/cliente_service.dart`, `lib/services/produto_service.dart`,
`lib/services/servico_service.dart`, `lib/services/agenda_service.dart`

**Problema confirmado — padrão que repete em TODOS os upsert locais:**
```dart
// ERRADO — sobrescreve local sempre, ignorando updated_at
if (existing.isEmpty) {
  await _db.insert(tabela, localMap);
} else {
  await _db.update(tabela, localMap, 'firebase_id = ?', [firebaseId]); // sempre sobrescreve
}
```

**Fix — aplicar em TODOS os métodos `_upsert*LocalFromFirestore`:**
```dart
if (existing.isNotEmpty) {
  final localUpdatedAt = DateTime.tryParse(
    (existing.first['updated_at'] as String?) ?? '',
  );
  final remoteUpdatedAt = _parseOptionalDate(data['updated_at']);
  if (localUpdatedAt != null &&
      remoteUpdatedAt != null &&
      localUpdatedAt.isAfter(remoteUpdatedAt)) {
    return; // local é mais novo — não sobrescrever
  }
}
// proceed with insert or update
```

Aplicar em:
- `comanda_service.dart → _sincronizarComandasDoFirestore` (loop de docs)
- `financeiro_service.dart → _upsertDespesaLocalFromFirestore`
- `financeiro_service.dart → _upsertCaixaLocalFromFirestore`
- `cliente_service.dart → _upsertClienteLocalFromFirestore` (se existir)
- `produto_service.dart → _upsertProdutoLocalFromFirestore` (se existir)
- `agenda_service.dart → _upsertAgendamentoLocalFromFirestore` (se existir)

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-06 — [FIXAR] B-05: Async não cancelado no dispose (7 telas restantes)
## ══════════════════════════════════════════════════════════════════

**`caixa_screen.dart` JÁ tem `_disposed` — confirmado no código. NÃO re-aplicar.**

**Arquivos que ainda faltam:**
`lib/screens/financeiro/financeiro_screen.dart`,
`lib/screens/agenda/agenda_screen.dart`,
`lib/screens/dashboard/dashboard_screen.dart`,
`lib/screens/atendimentos/atendimentos_screen.dart`,
`lib/screens/comanda/comandas_screen.dart`,
`lib/screens/clientes/clientes_screen.dart`,
`lib/screens/estoque/estoque_screen.dart`

**Fix — aplicar em cada StatefulWidget com carregamento assíncrono:**
```dart
// Adicionar na classe State:
bool _disposed = false;

@override
void dispose() {
  _disposed = true;
  super.dispose();
}

// Modificar TODOS os métodos async de carregamento:
Future<void> _carregar() async {
  if (_disposed) return;
  if (mounted) setState(() => _loading = true);
  try {
    final results = await Future.wait([/* ... */]);
    if (_disposed || !mounted) return;
    setState(() {
      // atribuir resultados
    });
  } catch (e) {
    if (_disposed || !mounted) return;
    _erro('$e');
  } finally {
    if (!_disposed && mounted) setState(() => _loading = false);
  }
}
```

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-07 — [INFO] B-01 reforço() — JÁ CORRIGIDO NO CÓDIGO
## ══════════════════════════════════════════════════════════════════

Confirmado lendo `financeiro_service.dart:661-676`: `reforco()` já insere
uma Despesa com `valor: -safeValor` (inflow negativo) em vez de mutar `valor_inicial`.
A categoria `'Reforço'` já existe em `AppConstants.categoriasDespesa`.
NÃO re-aplicar esse fix.

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-08 — [INFO] B-03 idempotência — JÁ IMPLEMENTADO NO FIREBASE
## ══════════════════════════════════════════════════════════════════

Confirmado em `_registrarOperacaoCaixaFirebase`:
```dart
final existingOp = await txn.get(opRef);
if (existingOp.exists) return; // operação já registrada — no-op
```

O `operationId` é passado como ID do documento Firestore, garantindo idempotência
no lado Firebase. A coluna `operation_id UNIQUE` no SQLite é implementada no P-11
como parte da correção de sangria/reforço.

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-09 — [INFO] Firestore Security Rules — DEPLOY MANUAL NECESSÁRIO
## ══════════════════════════════════════════════════════════════════

O arquivo `firestore.rules` está completo e correto. Não precisa de modificações.
O deploy é uma operação de infra, não de código:

```bash
firebase deploy --only firestore:rules
```

Se o projeto não tem `firebase.json` configurado, criar:
```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  }
}
```

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-10 — [FIXAR] fecharCaixa apaga metadata/caixa_atual sem verificar ownership
## ══════════════════════════════════════════════════════════════════

**Contexto:** O Codex já implementou o Firebase ledger para caixa. A função
`_fecharCaixaFirebase` (financeiro_service.dart:841) usa `runTransaction` corretamente,
mas tem um bug: ao fechar, seta `metadata/caixa_atual.caixa_aberto_id = null`
**sem verificar** se o metadata aponta para ESTE caixa. Se `fecharCaixa` for chamado
para um caixa antigo (ex: retry de rede), pode silenciosamente limpar o ponteiro
de um caixa diferente que está atualmente aberto.

**Arquivo:** `lib/services/financeiro_service.dart → _fecharCaixaFirebase()`

**Fix — ler metadata dentro da transação e só limpar se apontar para este caixa:**
```dart
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
    // ... [verificações existentes inalteradas] ...

    final valorFinal = _saldoCaixaLedger(caixaData, operationDocs);
    final agora = DateTime.now().toUtc();
    txn.set(opRef, { /* ... dados da operação fechamento ... */ });
    txn.update(caixaRef, {
      'status': AppConstants.caixaFechado,
      'data_fechamento': Timestamp.fromDate(agora),
      'valor_final': valorFinal,
      'operation_ids': [...operationIds, operationId],
      'updated_at': Timestamp.fromDate(agora),
    });

    // NOVO: só limpar metadata se apontar para ESTE caixa
    final activeSnap = await txn.get(activeRef);
    final activeCaixaId = activeSnap.data()?['caixa_aberto_id'] as String?;
    if (activeCaixaId == caixaId) {
      txn.set(
        activeRef,
        {
          'caixa_aberto_id': null,
          'barbearia_id': barbeariaId,
          'updated_at': Timestamp.fromDate(agora),
        },
        SetOptions(merge: true),
      );
    }

    return _CaixaFechamentoResumo(valorFinal);
  });
}
```

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-11 — [FIXAR] operationId de sangria/reforco não é determinístico
## ══════════════════════════════════════════════════════════════════

**Problema:**
`sangria()` e `reforco()` geram `_uuid.v4()` internamente quando o caller não
passa `operationId`. Isso significa que cada chamada gera um UUID diferente.
Se o usuário confirma a operação mas a rede cai antes do Firestore responder,
o retry gera um novo UUID → cria uma segunda operação no Firestore (duplicata).

O Firebase protege de duplicatas idempotentes **pelo mesmo `operationId`**,
mas se o ID muda a cada tentativa, a proteção não funciona.

**Arquivo:** `lib/screens/caixa/caixa_screen.dart`

**Fix — gerar o UUID NA TELA antes de mostrar o dialog de confirmação:**

```dart
// Dentro de _confirmarSangria() / _confirmarReforco() em caixa_screen.dart:

Future<void> _confirmarSangria(Caixa caixa) async {
  if (_operacaoEmAndamento) return;

  // Gerar ANTES do dialog — mesmo ID em qualquer retry desta sessão
  final operationId = const Uuid().v4();

  final confirmado = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogSangria(/* ... */),
  );
  if (confirmado != true) return;
  if (_disposed || !mounted) return;
  if (_operacaoEmAndamento) return;

  setState(() => _operacaoEmAndamento = true);
  try {
    final valor = double.parse(/* campo de valor */);
    await _service.sangria(
      caixaId: caixa.id!,
      valor: valor,
      observacao: /* obs */,
      operationId: operationId, // ← passar o ID gerado antes do dialog
    );
    await _carregar();
  } catch (e) {
    if (_disposed || !mounted) return;
    _erro('$e');
  } finally {
    if (!_disposed && mounted) setState(() => _operacaoEmAndamento = false);
  }
}

// Aplicar o mesmo padrão em _confirmarReforco()
```

**Também corrigir no SQLite — evitar despesa duplicada em retry:**
Em `financeiro_service.dart → sangria()` e `reforco()`, adicionar coluna
`operation_id` na tabela `despesas` e usar `ConflictAlgorithm.ignore`:

```dart
// Em sangria() e reforco(), ao inserir a Despesa local:
await txn.insert(
  AppConstants.tableDespesas,
  {
    ...Despesa(...).toMap(),
    'operation_id': operationId, // ← incluir o operationId
    'created_at': agoraIso,
    'updated_at': agoraIso,
  },
  conflictAlgorithm: ConflictAlgorithm.ignore, // ← duplicate = no-op
);
```

E adicionar a migração de schema:
```dart
// Em database_helper.dart → _migrateToV8 (ou V9 se V8 já existir):
await _addColumnIfMissing(db, AppConstants.tableDespesas, 'operation_id', 'TEXT UNIQUE');
```

---

## ══════════════════════════════════════════════════════════════════
## ITEM P-12 — [FIXAR] Script de migração: 4 bugs confirmados no código
## ══════════════════════════════════════════════════════════════════

**Arquivo:** `tool/migrate_sqlite_to_firestore.dart`

---

### P-12a — Datas armazenadas como `stringValue` em vez de `timestampValue`

**Problema confirmado:** `_utcIso()` retorna `String`. Quando `_value(String)` recebe
uma String ISO, grava como `stringValue`. A query do Firestore por `Timestamp` não
encontra esses docs. `_fecharCaixaFirebase` não consegue ler `data_abertura` corretamente.

**Fix — converter datas para DateTime antes de passar para `_value()`:**
```dart
// Mudar _write() para converter campos de data conhecidos:
fs.Write _write(_Config config, String path, Map<String, Object?> data) {
  // Normalizar campos de data para DateTime
  final normalized = Map<String, Object?>.from(data);
  for (final key in const [
    'data', 'data_abertura', 'data_fechamento', 'timestamp',
    'created_at', 'updated_at',
  ]) {
    final raw = normalized[key];
    if (raw is String && raw.trim().isNotEmpty) {
      normalized[key] = DateTime.tryParse(raw) ?? raw;
    }
  }
  return fs.Write(
    update: fs.Document(
      name: 'projects/${config.projectId}/databases/(default)/documents/'
            'barbearias/${config.barbeariaId}/$path',
      fields: normalized.map((k, v) => MapEntry(k, _value(v))),
    ),
  );
}
```

---

### P-12b — `operation_ids` do caixa não inclui operações de sangria/reforço

**Problema confirmado:** O doc do caixa só inclui:
```dart
final operationIds = ['migracao_valor_inicial_$localId',
  if (status == 'fechado') 'migracao_fechamento_$localId'];
```
Mas as operações de sangria/reforço criadas a partir de despesas
(`migracao_despesa_$localId`) NÃO estão no array. `_saldoCaixaLedger()` itera
`operation_ids` para calcular o saldo — os migrados ficam com saldo errado.

**Fix — coletar os operationIds de despesas durante o loop e incluir no caixa:**
```dart
// Mapa: localId do caixa → lista de operationIds extras
final caixaExtraOperations = <int, List<String>>{};

// No loop de despesas, ao criar operação no caixa:
if (caixaDocId != null) {
  final operationId = 'migracao_despesa_$localId';
  caixaExtraOperations.putIfAbsent(caixaLocalId!, () => []).add(operationId);
  writes.add(_write(config, 'caixas/$caixaDocId/operacoes/$operationId', {...}));
}

// No loop de caixas, APÓS processar despesas, reconstruir o doc com operation_ids completo:
// (processar despesas ANTES de caixas, ou fazer dois passes)
final operationIds = <String>[
  'migracao_valor_inicial_$localId',
  ...?caixaExtraOperations[localId],         // ← sangrias e reforços migrados
  if (row['status'] == 'fechado') 'migracao_fechamento_$localId',
];
```

**IMPORTANTE:** Processar despesas antes de caixas no script, ou fazer um primeiro
passe em despesas apenas para construir o mapa `caixaExtraOperations`, depois
um segundo passe para criar os docs de caixa com o array correto.

---

### P-12c — Nenhum `metadata/caixa_atual` criado para caixas abertos

**Problema:** Se um caixa migrado ainda está `status = 'aberto'`, um dispositivo
novo consultando `metadata/caixa_atual` não encontra nada e permite abrir outro caixa,
duplicando a abertura de caixa.

**Fix — ao final do loop de caixas, criar metadata para o caixa aberto (se existir):**
```dart
// Após o loop de caixas:
final caixaAberto = caixas.where((r) => r['status'] == 'aberto').lastOrNull;
if (caixaAberto != null) {
  final localId = (caixaAberto['id'] as num).toInt();
  final docId = caixaIds[localId]!;
  writes.add(_write(config, 'metadata/caixa_atual', {
    'caixa_aberto_id': docId,
    'barbearia_id': config.barbeariaId,
    'updated_at': _utcIso(caixaAberto['data_abertura']),
  }));
}
```

---

### P-12d — Re-execução sobrescreve sem precondição (risco de apagar updates pós-migração)

**Fix — adicionar `--no-overwrite` flag e usar `currentDocument: null` como precondition:**
```dart
// Em _Config, adicionar:
final bool noOverwrite;

// Em _write(), quando config.noOverwrite é true:
fs.Write _write(_Config config, String path, Map<String, Object?> data) {
  return fs.Write(
    update: fs.Document(/* ... */),
    currentDocument: config.noOverwrite
        ? fs.Precondition(exists: false) // falha se já existir
        : null,
  );
}
```

Uso: `dart run tool/migrate_sqlite_to_firestore.dart ... --no-overwrite`
Para re-migração segura, rodar primeiro com `--dry-run`, depois sem `--no-overwrite`
apenas para docs novos.

---

## CHECKLIST FINAL

Após implementar todos os itens acima, verificar:

**Dados e sincronização:**
- [ ] `atendimento_service.dart` reescrito com Firestore + SQLite cache (P-01)
- [ ] `AppConstants.dbVersion` incrementado para 8 (ou 9 se já foi para 8)
- [ ] `_migrateToV*` em `database_helper.dart` adiciona colunas em `atendimentos` e `operation_id` em `despesas`
- [ ] `DateTime.now()` → `DateTime.now().toUtc()` em todos os services (P-02)
- [ ] `getComandasHoje` usa `data_fechamento` para financeiro (P-03)

**Caixa Firebase ledger:**
- [ ] `_fecharCaixaFirebase` lê `metadata/caixa_atual` dentro da transação e só limpa se `caixa_aberto_id == caixaId` (P-10)
- [ ] `caixa_screen.dart` gera `operationId = Uuid().v4()` ANTES do dialog de confirmação e passa para `sangria()`/`reforco()` (P-11)
- [ ] `sangria()` e `reforco()` usam `ConflictAlgorithm.ignore` ao inserir Despesa local (P-11)

**Sync bidirecional:**
- [ ] `_upsertCaixaLocalFromFirestore` compara timestamps antes de sobrescrever (P-04)
- [ ] Todos os `_upsert*LocalFromFirestore` têm comparação de timestamp (P-05)

**UI:**
- [ ] 7 StatefulWidgets restantes têm `_disposed` flag (P-06 — `caixa_screen.dart` já feito)

**Migration script:**
- [ ] Datas gravadas como `timestampValue` (não `stringValue`) — P-12a
- [ ] `operation_ids` do caixa inclui operações de sangria/reforço migradas — P-12b
- [ ] `metadata/caixa_atual` criado para caixa ainda aberto — P-12c
- [ ] Flag `--no-overwrite` com precondição Firestore — P-12d

**Infra:**
- [ ] `firebase deploy --only firestore:rules` executado no terminal (P-09)
- [ ] App compilado em release mode (`flutter build apk --release`) sem erros

---

## NOTAS PARA O CODEX

- NÃO remover `DatabaseHelper` nem o SQLite ainda — servem como cache offline
- NÃO alterar `firestore.rules` — está correto
- NÃO modificar `firebase_context_service.dart` — já foi refatorado
- NÃO re-aplicar fixes marcados como [INFO] (B-01, B-03)
- O padrão de injeção de dependência (`DatabaseHelper? db = null`) já está estabelecido
  em todos os services — manter no `AtendimentoService` reescrito
- `AppConstants.kSyncBatchSize` já existe e deve ser usado nos limits de query Firestore
