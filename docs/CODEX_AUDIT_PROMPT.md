# Severus Barber Pro — Codex Audit Prompt (Full)
# Generated after QA + Architecture audit — 2026-05-02

## STATUS LEGEND
# [FIXED]   → Already applied in this session
# [OPEN]    → Not yet fixed — needs implementation
# [ARCH]    → Architecture-level — requires design decision before coding

---

## ────────────────────────────────────────────────────────────────
## BLOCK A — ALREADY FIXED (do not re-apply, document only)
## ────────────────────────────────────────────────────────────────

### [FIXED] A-01 — Debug login bypass active in profile builds
File: lib/controllers/auth_controller.dart
Was: `if (kReleaseMode) return false;`
Fix: Changed to `if (!kDebugMode) return false;`

### [FIXED] A-02 — Debug bypass did not set barbearia cache
File: lib/controllers/auth_controller.dart
Fix: Added `FirebaseContextService.setCachedBarbeariaId(AppConstants.localBarbeariaId)` after
     setting the debug user.

### [FIXED] A-03 — Double-tap guard on fecharCaixa / sangria / reforço
File: lib/screens/caixa/caixa_screen.dart
Fix: Added `_operacaoEmAndamento` boolean flag; all three methods check it before
     proceeding and reset it in a `finally` block.

### [FIXED] A-04 — Zero-value sangria/reforço silently accepted
File: lib/screens/caixa/caixa_screen.dart
Fix: Added `if (valor <= 0) { _erro(...); return; }` before the service call.

### [FIXED] A-05 — PrimeiroLoginScreen called inicializar() after password save
File: lib/screens/auth/primeiro_login_screen.dart
Fix: Removed the `await authController.inicializar()` call. Now only calls
     `setSessaoAposLogin(usuarioAtual.copyWith(firstLogin: false))`.

### [FIXED] A-06 — Firestore expense/caixa sync fetched ALL documents without limit
File: lib/services/financeiro_service.dart
Fix: Added `.limit(AppConstants.kSyncBatchSize)` to both queries.

### [FIXED] A-07 — Despesa sync pushed every local record on every load
File: lib/services/financeiro_service.dart
Fix: Split into two-step sync: unsent (firebase_id IS NULL) + recently modified
     (updated_at >= 48h threshold), each capped at kSyncBatchSize.

### [FIXED] A-08 — Comanda sync cursor not reset on barbearia change
File: lib/services/comanda_service.dart
Fix: Added `_lastSyncShopId` tracker; cursor is reset when shopId changes.

### [FIXED] A-09 — concluirPrimeiroLoginComNovaSenha did not update _usuario.firstLogin
File: lib/controllers/auth_controller.dart
Fix: Added `_usuario = _usuario!.copyWith(firstLogin: false)` before returning true.

### [FIXED] A-10 — Firestore comanda update rule allowed ownership hijack
File: firestore.rules
Was: `|| request.resource.data.barbeiro_uid == request.auth.uid`
Fix: Removed the third OR branch — only `resource.data.barbeiro_uid` (existing state)
     is checked now.

### [FIXED] A-11 — _hasAnyAdmin treated permission-denied as "no admin exists"
File: lib/services/auth_service.dart
Fix: permission-denied now returns `true` (assume admin exists), blocking
     unauthorised public registration.

### [FIXED] A-12 — inicializar() swallowed all exceptions silently
File: lib/controllers/auth_controller.dart
Fix: Changed `catch (_)` to `catch (e, st)` with `debugPrint` logging.

---

## ────────────────────────────────────────────────────────────────
## BLOCK B — OPEN BUGS (implement these)
## ────────────────────────────────────────────────────────────────

### [OPEN] B-01 — reforço() corrupts audit trail by mutating valor_inicial
File: lib/services/financeiro_service.dart → reforco()

Problem:
  `valor_inicial` is mutated in place. Multiple reforços per day erase the previous.
  `observacoes` is also overwritten. This destroys the audit trail.

Fix:
  Instead of `_db.update(tableCaixas, {'valor_inicial': ...})`, insert a Despesa record:

  ```dart
  final now = DateTime.now().toUtc();
  final nowIso = now.toIso8601String();
  await _db.transaction((txn) async {
    await txn.insert(
      AppConstants.tableDespesas,
      {
        ...Despesa(
          descricao: safeObs?.isNotEmpty == true ? safeObs! : 'Reforço de Caixa',
          categoria: 'Reforço',
          valor: -safeValor,          // negative = inflow
          data: now,
          observacoes: 'Reforço — Caixa #$safeCaixaId',
        ).toMap(),
        'created_at': nowIso,
        'updated_at': nowIso,
      },
    );
  });
  await _syncCaixaByLocalIdIfOnline(safeCaixaId);
  ```

  NOTE: AppConstants.categoriasDespesa must include 'Reforço' or use a dedicated
  sign convention. Coordinate with the financial report to sum negative despesas
  as inflows.

---

### [OPEN] B-02 — fecharCaixa is NOT atomic between SQLite and Firebase
File: lib/services/financeiro_service.dart → fecharCaixa()

Problem:
  1. SQLite is updated (status = 'fechado', valor_final = X)
  2. `_syncCaixaByLocalIdIfOnline` writes to Firebase — can fail silently
  3. If next session syncs from Firebase, Firebase's still-open record
     overwrites the locally-closed record → caixa is "re-opened" silently.

Root cause: `_upsertCaixaLocalFromFirestore` unconditionally overwrites local state
            with remote state, with no conflict resolution.

Fix (two parts):

PART 1 — Add a `local_updated_at` timestamp and honour it during upsert:

  In `_upsertCaixaLocalFromFirestore`, before overwriting:
  ```dart
  final localUpdatedAt = DateTime.tryParse(
    (existing.first['updated_at'] as String?) ?? ''
  );
  final remoteUpdatedAt = updatedAt; // already parsed
  if (localUpdatedAt != null && localUpdatedAt.isAfter(remoteUpdatedAt)) {
    return; // local is newer — do not overwrite
  }
  ```

PART 2 — Same pattern for `_upsertDespesaLocalFromFirestore` and
          `_sincronizarComandasDoFirestore`.

---

### [OPEN] B-03 — No idempotency keys on critical write operations
Files: lib/services/financeiro_service.dart, lib/services/comanda_service.dart

Problem:
  If the app crashes, loses connection, or the user restarts mid-operation,
  the same financial event (fechar caixa, sangria, comanda close) can execute
  twice. UUID generation at the *start* of an operation (not before the user
  confirms) would help, but there is no server-side deduplication either.

Fix:
  Generate the operation UUID before showing the confirmation dialog, then pass
  it all the way through to the Firestore document ID. Use `SetOptions(merge: false)`
  combined with Firestore's built-in "document already exists" guard:

  ```dart
  // Generate BEFORE dialog
  final operationId = _uuid.v4();

  final confirm = await showDialog<bool>(...);
  if (confirm != true) return;

  // Pass operationId as the Firestore doc ID
  await _context.collection(...).doc(operationId).set({
    ...data,
  }); // Firestore rejects if doc already exists → second tap is a no-op
  ```

  For SQLite: add a `operation_id TEXT UNIQUE` column to comandas, caixas,
  and despesas. Use `ConflictAlgorithm.ignore` on insert.

---

### [OPEN] B-04 — Timezone bug: DateTime.now() stored as local time, Firebase uses UTC internally
Files: ALL services (63 DateTime.now() calls, 113 toIso8601String calls, 0 toUtc() calls)

Problem:
  `DateTime.now().toIso8601String()` produces a string WITHOUT timezone suffix
  (e.g., "2024-01-15T21:00:00.000") when the device is set to UTC-3.
  SQLite has no timezone awareness and stores this as-is.
  
  Firebase's `Timestamp.toDate()` in Dart returns a local DateTime — so far
  consistent. BUT:
  - If a device changes timezone (travel, DST change), historical records
    shift visually even though the stored string didn't change.
  - `getComandasHoje` computes `DateTime(y, m, d)` — midnight LOCAL. If the
    timezone changes, "today" boundaries shift, orphaning records.
  - Two devices in different timezones querying the same barbearia
    see different "hoje" windows.

Fix:
  STEP 1 — Standardise ALL DateTime.now() to UTC at storage time:
  ```dart
  // Replace everywhere:
  DateTime.now().toIso8601String()
  // With:
  DateTime.now().toUtc().toIso8601String()
  // Result: "2024-01-16T00:00:00.000Z" (unambiguous)
  ```

  STEP 2 — When reading back from SQLite, parse as UTC:
  ```dart
  DateTime.parse(row['data'] as String).toLocal()
  // Because DateTime.parse("...Z") auto-detects UTC; .toLocal() for display
  ```

  STEP 3 — Fix date boundary queries to use UTC midnight:
  ```dart
  // In getComandasHoje():
  final agora = DateTime.now().toUtc();
  final inicio = DateTime.utc(agora.year, agora.month, agora.day).toIso8601String();
  final fim    = DateTime.utc(agora.year, agora.month, agora.day, 23, 59, 59).toIso8601String();
  ```

  STEP 4 — Update _normalizeDate / _normalizeDateValue to always produce UTC:
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

  WARNING: This is a breaking migration. Existing SQLite records have local-time
  strings without 'Z'. Add a one-time migration in _migrateToV8 that parses
  each date as local and re-saves as UTC.

---

### [OPEN] B-05 — Async operations not cancelled on widget dispose (memory leaks + setState after dispose)
Files: All screen files with async operations

Problem:
  Confirmed: 0 uses of CancelableOperation, no Completer cancellation patterns.
  64 uses of `if (mounted)` — but these only protect setState, not the async
  operation itself. The operation continues running after dispose.

  Example in caixa_screen.dart:
  ```dart
  Future<void> _carregar() async {
    setState(() => _loading = true);
    final results = await Future.wait([...]);  // still runs after dispose
    if (mounted) setState(() { ... });          // only guard is here
  ```

  If the user navigates away during the await, the Future completes,
  `_loading` setter fires, and — if setState is somehow reached — crashes.
  Worse: the DB/network call still happened, wasting resources.

Fix:
  Add a `_disposed` flag to each StatefulWidget with async loads:

  ```dart
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _carregar() async {
    if (_disposed) return;
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([...]);
      if (_disposed || !mounted) return;
      setState(() { ... });
    } catch (e) {
      if (_disposed || !mounted) return;
      _erro('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  ```

  Apply to: caixa_screen.dart, financeiro_screen.dart, agenda_screen.dart,
  dashboard_screen.dart, atendimentos_screen.dart, comandas_screen.dart,
  clientes_screen.dart, estoque_screen.dart.

---

### [OPEN] B-06 — Main thread blocked by sync loops (ANR risk on Android)
Files: lib/services/financeiro_service.dart, lib/services/comanda_service.dart

Problem:
  Every call to getDespesas(), getCaixaAberto(), getCaixas(), getAll() etc.
  runs `await _syncFromFirestoreIfOnline()` synchronously on the Dart main
  isolate BEFORE returning local data. This sync loop:
  1. Checks connectivity
  2. Iterates ALL pending local records (loop with individual DB + Firebase writes)
  3. Fetches batch from Firebase (network call)

  On Android, >5 s of UI thread block = ANR dialog. Even 1-2 s = visible freeze.

Fix:
  Fire sync in background, return local data immediately:

  ```dart
  Future<List<Despesa>> getDespesas({...}) async {
    // Fire sync in background — do NOT await
    if (await _isFirebaseOnline()) {
      _syncDespesasFromFirestoreIfOnline().ignore();
      // .ignore() is the Dart-idiomatic way to explicitly discard the future
    }

    // Return local data immediately
    final maps = await _db.queryAll(AppConstants.tableDespesas, ...);
    return maps.map((m) => Despesa.fromMap(m)).toList();
  }
  ```

  Apply the same pattern to ALL service methods that currently await sync before
  returning: getAll (comanda), getCaixaAberto, getCaixas, getUltimoCaixa,
  getDespesas, getFaturamentoPeriodo.

  NOTE: `.ignore()` was added in Dart 2.15. If on older SDK, use
  `unawaited(future)` from `package:async`.

---

### [OPEN] B-07 — SQLite database is completely unencrypted
File: lib/database/database_helper.dart

Problem:
  Standard `sqflite` stores the database as a plain SQLite file. On Android
  (non-rooted), the file is protected by the app sandbox. On rooted devices,
  any other app with root access, or a physical device with USB debugging,
  can read all financial data including:
  - Client PII (names, phones, birthdays)
  - Complete revenue figures
  - Barbeiro commission data
  - Cash register history

Fix (pragmatic — not full encryption):
  OPTION A — Use `sqflite_sqlcipher` package to encrypt the DB at rest.
  This requires replacing `sqflite` in pubspec.yaml and providing a key
  derived from `flutter_secure_storage` (stored in Android Keystore).

  OPTION B (minimum viable) — At least move sensitive fields to
  `flutter_secure_storage` and store only non-PII in plain SQLite.

  Minimum steps for Option B:
  ```yaml
  # pubspec.yaml
  dependencies:
    flutter_secure_storage: ^9.2.2
  ```
  Store user credentials and barbeariaId in secure storage; reference by
  opaque ID in SQLite.

  IMPORTANT: Any migration must handle existing installs that already have
  an unencrypted DB. Provide a migration path that reads the plain DB,
  re-encrypts, and deletes the original.

---

### [OPEN] B-08 — No conflict resolution in bidirectional sync (last-write-wins silently)
Files: lib/services/comanda_service.dart, lib/services/financeiro_service.dart

Problem:
  When a record exists both locally (modified offline) and in Firestore
  (modified by another device/session), the current sync always overwrites
  local with remote during _sincronizarComandasDoFirestore and
  _upsertDespesaLocalFromFirestore.

  Confirmed pattern in comanda sync:
  ```dart
  if (existing.isEmpty) {
    localComandaId = await _db.insert(...);
  } else {
    await _db.update(...map...);  // always overwrites
  }
  ```

  There is an `updated_at` field in both stores but it is NOT compared before
  overwriting.

Fix:
  Compare timestamps before overwriting (see also B-02 PART 1):

  ```dart
  if (existing.isNotEmpty) {
    final localTs = DateTime.tryParse(
        (existing.first['updated_at'] as String?) ?? '');
    final remoteTs = _parseOptionalDate(data['updated_at']);
    if (localTs != null && remoteTs != null && localTs.isAfter(remoteTs)) {
      continue; // local is newer — skip remote overwrite
    }
    await _db.update(...);
  }
  ```

  This is a "last-writer-wins by timestamp" strategy — simple and good enough
  for a single-shop app. Document the assumption: system clocks across devices
  must be within a reasonable tolerance (NTP-synced).

---

### [FIXED] B-09 — Test account email displayed in plain text in login screen UI
File: lib/screens/auth/login_screen.dart:353-360

Problem:
  ```dart
  if (_contaTesteEmail.trim().isNotEmpty) ...[
    Text('Conta teste Firebase: $_contaTesteEmail'),
  ]
  ```
  If a demo build is shipped with FIREBASE_TEST_ADMIN_EMAIL set, the account
  email is visible to anyone who opens the login screen.

Fix:
  Remove the Text widget entirely. The OutlinedButton label is sufficient to
  communicate that a test account is available. The email is only useful for
  the developer, who already knows it from the build config.

  ```dart
  // DELETE these 4 lines:
  if (_contaTesteEmail.trim().isNotEmpty) ...[
    const SizedBox(height: 8),
    Text('Conta teste Firebase: $_contaTesteEmail', ...),
  ],
  ```

---

### [FIXED] B-10 — agendamento delete rule allows barbeiro to erase any own appointment
File: firestore.rules

Problem:
  ```
  allow delete: if isInShop(shopId) &&
    (isAdmin(shopId) || resource.data.barbeiro_id == request.auth.uid);
  ```
  A barbeiro can permanently delete their own scheduled appointments.
  This is a compliance/audit problem: deleted appointments leave no trace,
  allowing a barbeiro to hide missed or cancelled bookings from the admin.

Fix:
  Remove the barbeiro delete permission:
  ```
  allow delete: if isInShop(shopId) && isAdmin(shopId);
  ```
  Barbeiros should only be able to change status (e.g. to 'Cancelado')
  via an update, which leaves an audit trail.

---

### [FIXED] B-11 — _addColumnIfMissing uses unsanitised table name in raw SQL
File: lib/database/database_helper.dart:719

Problem:
  ```dart
  final info = await db.rawQuery('PRAGMA table_info($tableName)');
  ```
  `tableName` is interpolated directly. Currently all callers pass AppConstants
  values so this is unexploitable. But the pattern is dangerous.

Fix:
  Add an assertion guard:
  ```dart
  Future<void> _addColumnIfMissing(
    Database db, String tableName, String columnName, String columnDefinition,
  ) async {
    assert(
      RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(tableName),
      'Invalid table name passed to _addColumnIfMissing: $tableName',
    );
    final info = await db.rawQuery('PRAGMA table_info($tableName)');
    ...
  }
  ```

---

### [FIXED] B-12 — Implicit dependency: PrimeiroLoginScreen relies on undocumented side-effect
File: lib/screens/auth/primeiro_login_screen.dart

Problem:
  The screen calls `setSessaoAposLogin(usuarioAtual.copyWith(firstLogin: false))`
  BEFORE the controller's own `concluirPrimeiroLoginComNovaSenha` has updated
  `_usuario`. After FIX A-09, the controller now updates `_usuario` internally,
  making `setSessaoAposLogin` redundant and misleading. The screen still calls it
  as a "just in case" belt-and-suspenders, which is confusing to future devs.

Fix:
  Remove the manual `setSessaoAposLogin` call from the screen. The controller
  now handles it. Document in the controller that it guarantees `_usuario.firstLogin`
  is false after a successful `concluirPrimeiroLoginComNovaSenha`.

  ```dart
  // DELETE from primeiro_login_screen.dart:
  final usuarioAtual = authController.usuario;
  if (usuarioAtual != null) {
    authController.setSessaoAposLogin(usuarioAtual.copyWith(firstLogin: false));
  }
  ```

---

### [OPEN] B-13 — getComandasHoje uses data_abertura causing semantic confusion
File: lib/services/comanda_service.dart:166-199

Problem:
  - Comandas opened near midnight (e.g., 23:50) show in "today" even if
    closed and paid tomorrow.
  - Comandas opened yesterday but closed today do NOT appear.
  - Affects: dashboard atendimentos count, caixa "today" totals.

Fix:
  Separate the two use cases:
  - For OPERATIONAL view (what's currently open): filter by status='aberta'
    regardless of date.
  - For FINANCIAL reporting (today's revenue): filter by data_fechamento
    (closed today).

  ```dart
  // For financial "today" queries, use:
  var where = "status = 'fechada' AND data_fechamento BETWEEN ? AND ?";
  ```

---

## ────────────────────────────────────────────────────────────────
## BLOCK C — ARCHITECTURE RECOMMENDATIONS (design decisions)
## ────────────────────────────────────────────────────────────────

### [ARCH] C-01 — Static _cachedBarbeariaId is a cross-session contamination bomb
File: lib/services/firebase_context_service.dart

Risk level: CRITICAL for multi-device or re-login scenarios.

Pattern that causes the problem:
  All services (ComandaService, FinanceiroService, AuthService, AgendaService, etc.)
  share a single static String? _cachedBarbeariaId.
  Any code path that skips logout() leaves this stale.
  Services created as singletons in main.dart (3 shared instances) compound the risk.

The five-step failure path:
  1. User A logs in → cache = "shop_A"
  2. App is backgrounded
  3. User B opens app → some auth path sets _usuario but doesn't call setCachedBarbeariaId
  4. getBarbeariaIdAtual() returns cached "shop_A"
  5. All reads/writes now target User A's barbearia silently

Recommended fix strategy:
  OPTION A (minimum, immediate): Ensure EVERY login path calls
  `FirebaseContextService.setCachedBarbeariaId(newId)` and every logout path
  calls `setCachedBarbeariaId(null)`. Add an assertion in `getBarbeariaIdAtual`
  that the cached value matches the authenticated user's UID-derived shopId.

  OPTION B (correct, medium effort): Make _cachedBarbeariaId an instance field
  (not static). Pass FirebaseContextService as a constructor argument to all
  services, and recreate service instances on each login/logout cycle:
  ```dart
  // In AuthController, after successful login:
  final context = FirebaseContextService(barbeariaId: usuario.barbeariaId);
  // Recreate services with new context
  _comandaService = ComandaService(context: context);
  ```
  This requires changing main.dart's shared singleton pattern.

  OPTION C (correct, more effort): Use a reactive approach — store barbeariaId
  in a ValueNotifier and have services listen to it. When it changes, services
  invalidate their local caches automatically.

---

### [ARCH] C-02 — Source of truth is undefined in bidirectional sync
Files: All services

Current state:
  - SQLite is written first in some operations (fecharCaixa)
  - Firebase is written first in others (insertDespesa, abrirComanda when online)
  - Sync fetches remote and overwrites local unconditionally
  - No version vector, no CRDT, no conflict log

Risk:
  In any scenario with two active sessions (admin on desktop + barbeiro on phone),
  or after any connectivity recovery, data from the more recent write on any device
  can silently overwrite the other device's changes.

Recommended decision (document explicitly in codebase):
  The project should adopt a "local-first, cloud-backup" model explicitly:
  1. All writes go to SQLite first (source of truth for reads)
  2. Firebase is the durable backup and cross-device sync channel
  3. Sync is "push local to remote, pull remote only for IDs not in local"
  4. Conflicts (same firebase_id, different updated_at) resolve by latest timestamp

  Document this in CLAUDE.md or a ARCHITECTURE.md so future developers don't
  accidentally implement the inverse.

---

### [ARCH] C-03 — No structured logging / observability
Files: entire codebase

Current state: 0 structured log calls. Only `debugPrint` scattered inconsistently.
In production, when a financial bug occurs, there is no way to reconstruct the
sequence of events that led to it.

Minimum viable fix:
  Add a simple event logger that writes to SQLite:
  ```dart
  // lib/utils/app_logger.dart
  class AppLogger {
    static Future<void> event(String category, String message, {Map<String, dynamic>? data}) async {
      if (kReleaseMode) {
        // In release, only log errors to a 'logs' table (capped at 500 rows)
        if (category == 'error') await _writeToDb(category, message, data);
      } else {
        debugPrint('[$category] $message ${data ?? ''}');
      }
    }
  }
  ```
  Log at minimum: login/logout, caixa open/close, comanda close, sync failures.

---

### [ARCH] C-04 — Services are tightly coupled through shared service instances
File: lib/main.dart:46-52

Pattern:
  ```dart
  final ComandaService _sharedComandaService = ComandaService();
  final AgendaService _sharedAgendaService = AgendaService(
    comandaService: _sharedComandaService,
  );
  final FinanceiroService _sharedFinanceiroService = FinanceiroService(
    comandaService: _sharedComandaService,
  );
  ```

Risk:
  - These singletons are never torn down between sessions
  - All their internal state (cursors, caches) persists across logout/login
  - If any service adds mutable instance state in the future, it leaks

Fix (if adopting ARCH C-01 Option B):
  Create a `ServiceLocator` that is re-instantiated on each login. In main.dart,
  expose it via Provider and dispose it on logout. This is the standard approach
  for apps with multi-user or multi-tenant session requirements.
```
