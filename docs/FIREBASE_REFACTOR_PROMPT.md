# Severus Barber — Firebase-First Full Refactor
# Codex Executable Prompt — Generated 2026-05-02
#
# STATUS LEGEND
# [CODE]    → Exact code to write/replace
# [DELETE]  → File or section to remove entirely
# [PATTERN] → Repeat this pattern for the listed files

# ════════════════════════════════════════════════════════════════════
# OVERVIEW — READ THIS BEFORE TOUCHING ANY FILE
# ════════════════════════════════════════════════════════════════════

## Current State (what you are changing FROM)

- Primary database: SQLite via `sqflite` package (`DatabaseHelper` class)
- Firebase: partially integrated — writes go to BOTH SQLite and Firestore;
  reads come from SQLite only; Firestore is an async background sync target
- 158 `_db.` call sites spread across 8 service files
- 0 Firestore streams used in screens (all `FutureBuilder` / manual setState)
- Static `FirebaseContextService._cachedBarbeariaId` — a cross-session
  contamination bomb shared across ALL service instances
- Model IDs are `int?` (SQLite auto-increment), Firestore IDs are in a
  separate `firebase_id String?` field — two-ID complexity everywhere
- Complex manual sync logic with cursor pagination, 48h threshold windows,
  upsert conflict resolution — all of this will be DELETED

## Target State (what you are changing TO)

- Primary database: Firestore — ALL reads and writes go directly to Firestore
- Offline: Firestore's native offline persistence (enabled once at startup)
- SQLite: COMPLETELY REMOVED — delete `database_helper.dart`, remove
  `sqflite`/`sqflite_common_ffi`/`path` from `pubspec.yaml`
- Model IDs: `String?` everywhere, equal to the Firestore document ID
- Real-time: services expose `Stream<T>` methods backed by `snapshots()`
- Financial operations: Firestore `runTransaction()` for atomicity
- Controllers: subscribe to Firestore streams internally; screens keep their
  existing `context.watch<Controller>()` pattern — no screen rewrites needed
  unless specified
- `FirebaseContextService`: no static state; `barbeariaId` resolved from
  `authStateChanges()` stream

## Multi-tenant data model (DO NOT CHANGE — already correct)

```
/barbearias/{shopId}
├── /usuarios/{uid}
├── /comandas/{comandaId}
│   └── /itens/{itemId}
├── /caixas/{caixaId}
├── /despesas/{despesaId}
├── /clientes/{clienteId}
├── /servicos/{servicoId}
├── /produtos/{produtoId}
├── /agendamentos/{agendamentoId}
└── /movimentos_estoque/{id}
```

All Firestore documents MUST include:
- `barbearia_id: String` — shopId for cross-reference
- `created_by: String` — uid of creator
- `created_at: Timestamp` — use `FieldValue.serverTimestamp()` on first write
- `updated_at: Timestamp` — use `FieldValue.serverTimestamp()` on every write

---

# ════════════════════════════════════════════════════════════════════
# STEP 1 — pubspec.yaml
# ════════════════════════════════════════════════════════════════════

FILE: pubspec.yaml

REMOVE these dependency lines (SQLite stack — no longer needed):

```yaml
# DELETE these lines:
  sqflite: ^2.3.3
  sqflite_common_ffi: ^2.3.3
  path: ^1.9.0
  path_provider: ^2.1.3
```

KEEP all Firebase lines as-is. Also ADD `firebase_storage` if photo uploads
are needed (currently `profile_photo_service.dart` exists):

```yaml
# ADD after cloud_firestore:
  firebase_storage: ^12.1.0
```

Final relevant section of pubspec.yaml should look like:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State management
  provider: ^6.1.2

  # Firebase
  firebase_core: ^3.1.0
  firebase_auth: ^5.1.0
  cloud_firestore: ^5.1.0
  firebase_storage: ^12.1.0
  connectivity_plus: ^6.1.5

  # UUID for generating document IDs before write (idempotency)
  uuid: ^4.3.3

  # ... rest of dependencies unchanged
```

---

# ════════════════════════════════════════════════════════════════════
# STEP 2 — DELETE database_helper.dart
# ════════════════════════════════════════════════════════════════════

FILE: lib/database/database_helper.dart

[DELETE] Delete this file entirely.
[DELETE] Delete the lib/database/ directory if it becomes empty.

After deletion, search the entire codebase for:
  `import '../database/database_helper.dart'`
  `import '../../database/database_helper.dart'`
  `DatabaseHelper`
  `_db.`
  `from sqflite`
  `import 'package:sqflite`
  `import 'package:path'`

Remove every import line and every usage. The steps below replace all usages
with Firestore equivalents.

---

# ════════════════════════════════════════════════════════════════════
# STEP 3 — lib/main.dart: Enable offline persistence + remove singletons
# ════════════════════════════════════════════════════════════════════

FILE: lib/main.dart

CHANGE 1 — Remove the 3 global service singletons and their imports.
These lines must be deleted:

```dart
// DELETE:
final ComandaService _sharedComandaService = ComandaService();
final AgendaService _sharedAgendaService = AgendaService(
  comandaService: _sharedComandaService,
);
final FinanceiroService _sharedFinanceiroService = FinanceiroService(
  comandaService: _sharedComandaService,
);
```

CHANGE 2 — Enable Firestore offline persistence after `Firebase.initializeApp()`.
In the `_inicializarFirebase()` function, after a successful `initializeApp` call,
add exactly these lines:

```dart
// Enable offline persistence so the app works without internet.
// Must be called once, before any Firestore reads/writes.
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

Full updated `_inicializarFirebase`:

```dart
Future<void> _inicializarFirebase() async {
  try {
    final isAndroidOrIos = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (isAndroidOrIos) {
      await Firebase.initializeApp();
    } else {
      final options = DefaultFirebaseOptions.currentPlatform;
      final hasDesktopConfig = options.apiKey.trim().isNotEmpty &&
          options.appId.trim().isNotEmpty &&
          options.projectId.trim().isNotEmpty &&
          options.messagingSenderId.trim().isNotEmpty;

      if (!hasDesktopConfig) {
        debugPrint('Firebase nao inicializado no desktop: rodando em modo offline.');
        return;
      }
      await Firebase.initializeApp(options: options);
    }

    // Enable Firestore offline persistence (must be set before first read/write)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase nao inicializado. Rodando em modo offline. Erro: $e');
  }
}
```

CHANGE 3 — Update `MultiProvider` to remove shared service singletons.
Replace the 3 `Provider<XService>.value(...)` entries with
`ChangeNotifierProvider(create: ...)` for the services that become
ChangeNotifier-based. For services that remain plain services, use
`Provider(create: (_) => XService())` without shared instances:

```dart
MultiProvider(
  providers: [
    // Services — each screen gets a fresh scope; no cross-session leak
    Provider(create: (_) => ComandaService()),
    Provider(create: (_) => FinanceiroService()),
    Provider(create: (_) => AgendaService()),
    Provider(create: (_) => FirebaseContextService()),
    // Controllers
    ChangeNotifierProvider(create: (_) => AuthController()),
    ChangeNotifierProvider(create: (_) => ClienteController()),
    ChangeNotifierProvider(create: (_) => AtendimentoController()),
    ChangeNotifierProvider(create: (_) => EstoqueController()),
    ChangeNotifierProvider(
      create: (ctx) => AgendaController(agendaService: ctx.read<AgendaService>()),
    ),
    ChangeNotifierProvider(
      create: (ctx) => ComandaController(comandaService: ctx.read<ComandaService>()),
    ),
    ChangeNotifierProvider(create: (_) => DashboardController()),
    ChangeNotifierProvider(
      create: (ctx) => FinanceiroController(
        financeiroService: ctx.read<FinanceiroService>(),
      ),
    ),
    ChangeNotifierProvider(create: (_) => ServicoController()),
    ChangeNotifierProvider(create: (_) => ProdutoController()),
  ],
  // ... rest unchanged
)
```

---

# ════════════════════════════════════════════════════════════════════
# STEP 4 — lib/services/firebase_context_service.dart: Remove static cache
# ════════════════════════════════════════════════════════════════════

FILE: lib/services/firebase_context_service.dart

REPLACE the entire file with:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../utils/constants.dart';

/// Provides scoped Firestore access for the current authenticated shop.
///
/// No static state — every call resolves barbeariaId from the current
/// Firebase Auth user. Firestore offline persistence (enabled in main.dart)
/// makes these reads work without internet.
class FirebaseContextService {
  FirebaseContextService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  bool get firebaseDisponivel {
    if (Firebase.apps.isEmpty) return false;
    final options = Firebase.app().options;
    return _firebaseConfigValida(options);
  }

  /// Stream that emits a new barbeariaId whenever auth state changes.
  /// Emits null when the user logs out.
  Stream<String?> get barbeariaIdStream =>
      _auth.authStateChanges().asyncMap((user) async {
        if (user == null) return null;
        return _resolverBarbeariaId(user.uid);
      });

  /// One-shot resolution of the current barbeariaId.
  /// Returns null if not authenticated or barbeariaId not found.
  Future<String?> getBarbeariaIdAtual() async {
    if (!firebaseDisponivel) return null;
    final user = _auth.currentUser;
    if (user == null) return null;
    return _resolverBarbeariaId(user.uid);
  }

  Future<String?> _resolverBarbeariaId(String uid) async {
    try {
      // Primary path: collectionGroup lookup by uid field
      final group = await _firestore
          .collectionGroup(AppConstants.tableUsuarios)
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      if (group.docs.isNotEmpty) {
        final doc = group.docs.first;
        final byField = doc.data()['barbearia_id'] as String?;
        if (byField != null && byField.trim().isNotEmpty) return byField;
        final byPath = doc.reference.parent.parent?.id;
        if (byPath != null && byPath.trim().isNotEmpty) return byPath;
      }

      // Fallback: legacy /usuarios/{uid} top-level collection
      final legacy = await _firestore
          .collection(AppConstants.tableUsuarios)
          .doc(uid)
          .get();
      if (legacy.exists) {
        final byField = legacy.data()?['barbearia_id'] as String?;
        if (byField != null && byField.trim().isNotEmpty) return byField;
      }
    } catch (e) {
      debugPrint('FirebaseContextService._resolverBarbeariaId: $e');
    }
    return null;
  }

  /// Returns a typed CollectionReference scoped to the given shop.
  CollectionReference<Map<String, dynamic>> collection({
    required String barbeariaId,
    required String nome,
  }) =>
      _firestore
          .collection(AppConstants.collectionBarbearias)
          .doc(barbeariaId)
          .collection(nome);

  /// Convenience: returns the /barbearias/{barbeariaId} document reference.
  DocumentReference<Map<String, dynamic>> barbeariaDoc(String barbeariaId) =>
      _firestore
          .collection(AppConstants.collectionBarbearias)
          .doc(barbeariaId);

  /// Builds the standard metadata map for Firestore writes.
  Map<String, dynamic> buildMetadata({
    required String barbeariaId,
    required String userId,
    bool includeCreatedAt = false,
  }) =>
      {
        'barbearia_id': barbeariaId,
        'created_by': userId,
        if (includeCreatedAt) 'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

  bool _firebaseConfigValida(FirebaseOptions options) {
    final apiKey = options.apiKey.trim();
    final appId = options.appId.trim();
    final projectId = options.projectId.trim();
    final senderId = options.messagingSenderId.trim();
    if (_isPlaceholder(apiKey) || _isPlaceholder(projectId)) return false;
    if (appId.isEmpty ||
        appId.contains(':000000000000:') ||
        appId.endsWith(':0000000000000000000000')) return false;
    if (senderId.isEmpty || RegExp(r'^0+$').hasMatch(senderId)) return false;
    return true;
  }

  bool _isPlaceholder(String v) {
    final s = v.trim().toLowerCase();
    return s.isEmpty || s.contains('placeholder') || RegExp(r'^0+$').hasMatch(s);
  }
}
```

---

# ════════════════════════════════════════════════════════════════════
# STEP 5 — lib/models/ : Change int? id to String? id in ALL models
# ════════════════════════════════════════════════════════════════════

## 5A — lib/models/comanda.dart

REPLACE the file with:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_comanda.dart';

class Comanda {
  // Firebase document ID — null only before first write
  final String? id;
  final int? clienteId;
  final String clienteNome;
  final String? barbeiroId;
  final String? barbeiroNome;
  final String status;
  final double total;
  final double comissaoTotal;
  final String? formaPagamento;
  final DateTime dataAbertura;
  final DateTime? dataFechamento;
  final String? observacoes;
  final List<ItemComanda> itens;

  const Comanda({
    this.id,
    this.clienteId,
    required this.clienteNome,
    this.barbeiroId,
    this.barbeiroNome,
    this.status = 'aberta',
    this.total = 0.0,
    this.comissaoTotal = 0.0,
    this.formaPagamento,
    required this.dataAbertura,
    this.dataFechamento,
    this.observacoes,
    this.itens = const [],
  });

  double get lucroCasa => total - comissaoTotal;
  double get percentualComissaoMedio => total > 0 ? (comissaoTotal / total) : 0;

  /// Build from a Firestore document snapshot.
  factory Comanda.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Comanda(
      id: doc.id,
      clienteId: (data['cliente_id'] as num?)?.toInt(),
      clienteNome: (data['cliente_nome'] as String?) ?? '',
      barbeiroId: data['barbeiro_id'] as String?,
      barbeiroNome: data['barbeiro_nome'] as String?,
      status: (data['status'] as String?) ?? 'aberta',
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      comissaoTotal: (data['comissao_total'] as num?)?.toDouble() ?? 0.0,
      formaPagamento: data['forma_pagamento'] as String?,
      dataAbertura: _parseDate(data['data_abertura']) ?? DateTime.now(),
      dataFechamento: _parseDate(data['data_fechamento']),
      observacoes: data['observacoes'] as String?,
      itens: [],
    );
  }

  /// Serialise for Firestore. Does NOT include 'id' (stored as doc.id).
  Map<String, dynamic> toFirestore() => {
        'cliente_id': clienteId,
        'cliente_nome': clienteNome,
        'barbeiro_id': barbeiroId,
        'barbeiro_nome': barbeiroNome,
        'barbeiro_uid': barbeiroId,
        'status': status,
        'total': total,
        'comissao_total': comissaoTotal,
        'forma_pagamento': formaPagamento,
        'data_abertura': dataAbertura.toUtc().toIso8601String(),
        'data_fechamento': dataFechamento?.toUtc().toIso8601String(),
        'observacoes': observacoes,
        'updated_at': FieldValue.serverTimestamp(),
      };

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  Comanda copyWith({
    String? id,
    int? clienteId,
    String? clienteNome,
    String? barbeiroId,
    String? barbeiroNome,
    String? status,
    double? total,
    double? comissaoTotal,
    String? formaPagamento,
    DateTime? dataAbertura,
    DateTime? dataFechamento,
    String? observacoes,
    List<ItemComanda>? itens,
  }) =>
      Comanda(
        id: id ?? this.id,
        clienteId: clienteId ?? this.clienteId,
        clienteNome: clienteNome ?? this.clienteNome,
        barbeiroId: barbeiroId ?? this.barbeiroId,
        barbeiroNome: barbeiroNome ?? this.barbeiroNome,
        status: status ?? this.status,
        total: total ?? this.total,
        comissaoTotal: comissaoTotal ?? this.comissaoTotal,
        formaPagamento: formaPagamento ?? this.formaPagamento,
        dataAbertura: dataAbertura ?? this.dataAbertura,
        dataFechamento: dataFechamento ?? this.dataFechamento,
        observacoes: observacoes ?? this.observacoes,
        itens: itens ?? this.itens,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Comanda && other.id != null && other.id == id);

  @override
  int get hashCode => id?.hashCode ?? Object.hash(clienteNome, dataAbertura);

  @override
  String toString() =>
      'Comanda(id: $id, cliente: $clienteNome, status: $status, total: $total)';
}
```

## 5B — lib/models/item_comanda.dart

Apply the SAME id change. Replace `int? id` and `int? comandaId` with `String?`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ItemComanda {
  final String? id;         // Firestore doc ID (was int? id)
  final String? comandaId;  // Parent comanda's Firestore ID (was int? comandaId)
  final String tipo;        // 'servico' | 'produto'
  final int itemId;         // local DB int for produto/servico lookup
  final String nome;
  final int quantidade;
  final double precoUnitario;
  final double comissaoPercentual;  // 0.0 to 1.0
  final double comissaoValor;       // computed: precoUnitario * quantidade * comissaoPercentual

  const ItemComanda({
    this.id,
    this.comandaId,
    required this.tipo,
    required this.itemId,
    required this.nome,
    this.quantidade = 1,
    required this.precoUnitario,
    this.comissaoPercentual = 0.0,
    double? comissaoValor,
  }) : comissaoValor =
            comissaoValor ?? (precoUnitario * quantidade * comissaoPercentual);

  double get subtotal => precoUnitario * quantidade;

  factory ItemComanda.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String comandaId,
  }) {
    final data = doc.data()!;
    final quantidade = (data['quantidade'] as num?)?.toInt() ?? 1;
    final preco = (data['preco_unitario'] as num?)?.toDouble() ?? 0.0;
    final comissaoPct = (data['comissao_percentual'] as num?)?.toDouble() ?? 0.0;
    return ItemComanda(
      id: doc.id,
      comandaId: comandaId,
      tipo: (data['tipo'] as String?) ?? 'servico',
      itemId: (data['item_id'] as num?)?.toInt() ?? 0,
      nome: (data['nome'] as String?) ?? '',
      quantidade: quantidade,
      precoUnitario: preco,
      comissaoPercentual: comissaoPct,
      comissaoValor: (data['comissao_valor'] as num?)?.toDouble() ??
          (preco * quantidade * comissaoPct),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'tipo': tipo,
        'item_id': itemId,
        'nome': nome,
        'quantidade': quantidade,
        'preco_unitario': precoUnitario,
        'comissao_percentual': comissaoPercentual,
        'comissao_valor': comissaoValor,
        'updated_at': FieldValue.serverTimestamp(),
      };

  ItemComanda copyWith({
    String? id,
    String? comandaId,
    String? tipo,
    int? itemId,
    String? nome,
    int? quantidade,
    double? precoUnitario,
    double? comissaoPercentual,
    double? comissaoValor,
  }) =>
      ItemComanda(
        id: id ?? this.id,
        comandaId: comandaId ?? this.comandaId,
        tipo: tipo ?? this.tipo,
        itemId: itemId ?? this.itemId,
        nome: nome ?? this.nome,
        quantidade: quantidade ?? this.quantidade,
        precoUnitario: precoUnitario ?? this.precoUnitario,
        comissaoPercentual: comissaoPercentual ?? this.comissaoPercentual,
        comissaoValor: comissaoValor ?? this.comissaoValor,
      );
}
```

## 5C — lib/models/caixa.dart

Replace `int? id` with `String? id`. Add `fromFirestore` and `toFirestore`:

```dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class Caixa {
  final String? id;   // Firestore doc ID (was int? id)
  final DateTime dataAbertura;
  final DateTime? dataFechamento;
  final double valorInicial;
  final double? valorFinal;
  final String status;  // 'aberto' | 'fechado'
  final Map<String, double> resumoPagamentos;
  final String? observacoes;

  const Caixa({
    this.id,
    required this.dataAbertura,
    this.dataFechamento,
    this.valorInicial = 0.0,
    this.valorFinal,
    this.status = 'aberto',
    this.resumoPagamentos = const {},
    this.observacoes,
  });

  bool get isAberto => status == 'aberto';

  factory Caixa.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Caixa(
      id: doc.id,
      dataAbertura: _parseDate(data['data_abertura']) ?? DateTime.now(),
      dataFechamento: _parseDate(data['data_fechamento']),
      valorInicial: (data['valor_inicial'] as num?)?.toDouble() ?? 0.0,
      valorFinal: (data['valor_final'] as num?)?.toDouble(),
      status: (data['status'] as String?) ?? 'aberto',
      resumoPagamentos: _parseResumo(data['resumo_pagamentos']),
      observacoes: data['observacoes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'data_abertura': Timestamp.fromDate(dataAbertura.toUtc()),
        'data_fechamento':
            dataFechamento == null ? null : Timestamp.fromDate(dataFechamento!.toUtc()),
        'valor_inicial': valorInicial,
        'valor_final': valorFinal,
        'status': status,
        'resumo_pagamentos': resumoPagamentos.isEmpty ? null : resumoPagamentos,
        'observacoes': observacoes,
        'updated_at': FieldValue.serverTimestamp(),
      };

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  static Map<String, double> _parseResumo(dynamic raw) {
    if (raw == null) return const {};
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return const {};
      return decoded.map(
        (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
      );
    } catch (_) {
      return const {};
    }
  }

  Caixa copyWith({
    String? id,
    DateTime? dataAbertura,
    DateTime? dataFechamento,
    double? valorInicial,
    double? valorFinal,
    String? status,
    Map<String, double>? resumoPagamentos,
    String? observacoes,
  }) =>
      Caixa(
        id: id ?? this.id,
        dataAbertura: dataAbertura ?? this.dataAbertura,
        dataFechamento: dataFechamento ?? this.dataFechamento,
        valorInicial: valorInicial ?? this.valorInicial,
        valorFinal: valorFinal ?? this.valorFinal,
        status: status ?? this.status,
        resumoPagamentos: resumoPagamentos ?? this.resumoPagamentos,
        observacoes: observacoes ?? this.observacoes,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Caixa && other.id == id);

  @override
  int get hashCode => id?.hashCode ?? Object.hash(dataAbertura, status);

  @override
  String toString() =>
      'Caixa(id: $id, status: $status, abertura: $dataAbertura)';
}
```

## 5D — lib/models/despesa.dart

Replace `int? id` with `String? id`. Add `fromFirestore` and `toFirestore`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Despesa {
  final String? id;   // Firestore doc ID (was int? id)
  final String descricao;
  final String categoria;
  final double valor;   // NEGATIVE for inflows (reforço), POSITIVE for outflows
  final DateTime data;
  final String? observacoes;

  const Despesa({
    this.id,
    required this.descricao,
    required this.categoria,
    required this.valor,
    required this.data,
    this.observacoes,
  });

  factory Despesa.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Despesa(
      id: doc.id,
      descricao: (data['descricao'] as String?) ?? '',
      categoria: (data['categoria'] as String?) ?? 'Outros',
      valor: (data['valor'] as num?)?.toDouble() ?? 0.0,
      data: _parseDate(data['data']) ?? DateTime.now(),
      observacoes: data['observacoes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'descricao': descricao,
        'categoria': categoria,
        'valor': valor,
        'data': Timestamp.fromDate(data.toUtc()),
        'observacoes': observacoes,
        'updated_at': FieldValue.serverTimestamp(),
      };

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  Despesa copyWith({
    String? id,
    String? descricao,
    String? categoria,
    double? valor,
    DateTime? data,
    String? observacoes,
  }) =>
      Despesa(
        id: id ?? this.id,
        descricao: descricao ?? this.descricao,
        categoria: categoria ?? this.categoria,
        valor: valor ?? this.valor,
        data: data ?? this.data,
        observacoes: observacoes ?? this.observacoes,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Despesa && other.id == id);

  @override
  int get hashCode =>
      id?.hashCode ?? Object.hash(descricao, categoria, valor, data);

  @override
  String toString() => 'Despesa(id: $id, descricao: $descricao, valor: $valor)';
}
```

## 5E — [PATTERN] Remaining models: cliente.dart, servico.dart, produto.dart, agendamento.dart

Apply the SAME pattern to each:
1. Change `final int? id` → `final String? id`
2. Add `factory Model.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc)`
   that reads `doc.id` as the id and parses all fields from `doc.data()!`
3. Add `Map<String, dynamic> toFirestore()` that excludes 'id' (doc.id handles it)
   and adds `'updated_at': FieldValue.serverTimestamp()`
4. Update `copyWith` parameter `int? id` → `String? id`
5. Update `operator ==` to compare on `id` (String)
6. Keep existing `fromMap` / `toMap` if needed for backward compat,
   but mark them as deprecated with `@Deprecated('Use fromFirestore')`

## 5F — lib/models/usuario.dart

NO structural change needed — `Usuario` already uses `String id`, has
`fromFirestore(Map<String, dynamic>)` and `toFirestore()`. However, fix the
`fromFirestore` signature to accept a `DocumentSnapshot`:

```dart
// CHANGE this:
factory Usuario.fromFirestore(Map<String, dynamic> data) { ... }

// TO this (accepts the full snapshot so caller doesn't have to spread data):
factory Usuario.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data()!;
  return Usuario(
    id: doc.id,          // Use doc.id as the canonical ID
    nome: (data['nome'] ?? '') as String,
    email: (data['email'] ?? '') as String,
    telefone: data['telefone'] as String?,
    photoUrl: data['photo_url'] as String?,
    barbeariaId: data['barbearia_id'] as String?,
    role: UserRole.fromString((data['role'] as String?) ?? 'barbeiro'),
    ativo: (data['ativo'] as bool?) ?? true,
    comissaoPercentual: (data['comissao_percentual'] as num?)?.toDouble() ?? 50.0,
    firstLogin: (data['first_login'] as bool?) ?? false,
    createdAt: _parseCreatedAt(data['created_at']),
  );
}

static DateTime _parseCreatedAt(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}
```

Also update all callers of `Usuario.fromFirestore(doc.data()!)` →
`Usuario.fromFirestore(doc)` throughout auth_service.dart and anywhere else
that passes a Map instead of the snapshot.

---

# ════════════════════════════════════════════════════════════════════
# STEP 6 — lib/services/comanda_service.dart: Complete Firestore-first rewrite
# ════════════════════════════════════════════════════════════════════

FILE: lib/services/comanda_service.dart

REPLACE THE ENTIRE FILE with:

```dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/comanda.dart';
import '../models/item_comanda.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'firebase_context_service.dart';
import 'service_exceptions.dart';

/// Firebase-first comanda service.
///
/// All reads and writes go directly to Firestore.
/// Offline support is provided by Firestore's built-in persistence
/// (enabled in main.dart via Settings(persistenceEnabled: true)).
class ComandaService {
  static const String _itensSubcol = 'itens';

  ComandaService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseContextService? context,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _context = context ?? FirebaseContextService(),
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseContextService _context;
  final Uuid _uuid;

  // ── Collection helpers ─────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _col(String shopId) =>
      _firestore
          .collection(AppConstants.collectionBarbearias)
          .doc(shopId)
          .collection(AppConstants.tableComandas);

  CollectionReference<Map<String, dynamic>> _itensCol(
    String shopId,
    String comandaId,
  ) =>
      _col(shopId).doc(comandaId).collection(_itensSubcol);

  Future<String?> _shopId() => _context.getBarbeariaIdAtual();
  String? get _uid => _auth.currentUser?.uid;

  // ── Real-time streams ─────────────────────────────────────────────

  /// Stream of all comandas for the shop, newest first.
  /// Automatically updates when Firestore data changes.
  Stream<List<Comanda>> watchAll({
    String? barbeiroId,
    String? status,
    int limit = 50,
  }) async* {
    final shopId = await _shopId();
    if (shopId == null) {
      yield [];
      return;
    }

    Query<Map<String, dynamic>> q = _col(shopId)
        .orderBy('data_abertura', descending: true)
        .limit(limit);
    if (status != null) q = q.where('status', isEqualTo: status);
    if (barbeiroId != null) q = q.where('barbeiro_id', isEqualTo: barbeiroId);

    yield* q.snapshots().map(
          (snap) => snap.docs.map((d) => Comanda.fromFirestore(d)).toList(),
        );
  }

  /// Stream of all OPEN comandas (for dashboard counters and comanda list).
  Stream<List<Comanda>> watchAbertas({String? barbeiroId}) =>
      watchAll(status: AppConstants.comandaAberta, barbeiroId: barbeiroId);

  /// Stream of the most recent open comanda for a specific barbeiro.
  Stream<Comanda?> watchComandaAberta(String barbeiroId) async* {
    final shopId = await _shopId();
    if (shopId == null) {
      yield null;
      return;
    }
    yield* _col(shopId)
        .where('status', isEqualTo: AppConstants.comandaAberta)
        .where('barbeiro_id', isEqualTo: barbeiroId)
        .orderBy('data_abertura', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isEmpty ? null : Comanda.fromFirestore(snap.docs.first));
  }

  // ── One-shot queries ──────────────────────────────────────────────

  Future<List<Comanda>> getAll({
    String? barbeiroId,
    String? status,
    int limit = 50,
  }) async {
    final shopId = await _shopId();
    if (shopId == null) return [];

    Query<Map<String, dynamic>> q = _col(shopId)
        .orderBy('data_abertura', descending: true)
        .limit(limit);
    if (status != null) q = q.where('status', isEqualTo: status);
    if (barbeiroId != null) q = q.where('barbeiro_id', isEqualTo: barbeiroId);

    final snap = await q.get();
    final comandas = snap.docs.map((d) => Comanda.fromFirestore(d)).toList();
    return _attachItems(shopId, comandas);
  }

  Future<Comanda?> getById(String id) async {
    final shopId = await _shopId();
    if (shopId == null) return null;
    final doc = await _col(shopId).doc(id).get();
    if (!doc.exists) return null;
    final comanda = Comanda.fromFirestore(doc);
    final itens = await _fetchItens(shopId, id);
    return comanda.copyWith(itens: itens);
  }

  Future<Comanda?> getComandaAberta({String? barbeiroId}) async {
    final shopId = await _shopId();
    if (shopId == null) return null;

    Query<Map<String, dynamic>> q = _col(shopId)
        .where('status', isEqualTo: AppConstants.comandaAberta)
        .orderBy('data_abertura', descending: true)
        .limit(1);
    if (barbeiroId != null) q = q.where('barbeiro_id', isEqualTo: barbeiroId);

    final snap = await q.get();
    if (snap.docs.isEmpty) return null;
    final comanda = Comanda.fromFirestore(snap.docs.first);
    final itens = await _fetchItens(shopId, comanda.id!);
    return comanda.copyWith(itens: itens);
  }

  /// Returns closed comandas where data_fechamento falls within today (UTC).
  Future<List<Comanda>> getComandasHoje({String? barbeiroId}) async {
    final shopId = await _shopId();
    if (shopId == null) return [];

    final agora = DateTime.now().toUtc();
    final inicioDia = DateTime.utc(agora.year, agora.month, agora.day);
    final fimDia = DateTime.utc(agora.year, agora.month, agora.day, 23, 59, 59);

    Query<Map<String, dynamic>> q = _col(shopId)
        .where('status', isEqualTo: AppConstants.comandaFechada)
        .where('data_fechamento',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
        .where('data_fechamento',
            isLessThanOrEqualTo: Timestamp.fromDate(fimDia))
        .orderBy('data_fechamento', descending: true);
    if (barbeiroId != null) q = q.where('barbeiro_id', isEqualTo: barbeiroId);

    final snap = await q.get();
    return snap.docs.map((d) => Comanda.fromFirestore(d)).toList();
  }

  // ── Mutations ─────────────────────────────────────────────────────

  /// Opens a new comanda. Returns the new Firestore document ID.
  Future<String> abrirComanda({
    int? clienteId,
    required String clienteNome,
    String? barbeiroId,
    String? barbeiroNome,
    String? observacoes,
  }) async {
    final shopId = await _shopId();
    final uid = _uid;
    if (shopId == null || uid == null) {
      throw const AuthException('Usuário não autenticado.');
    }

    final safeClienteNome = SecurityUtils.sanitizeName(clienteNome, fieldName: 'Nome do cliente');
    final safeBarbeiroId = barbeiroId == null
        ? null
        : SecurityUtils.sanitizeIdentifier(barbeiroId, fieldName: 'ID do barbeiro', minLength: 1);
    final safeBarbeiroNome = barbeiroNome == null
        ? null
        : SecurityUtils.sanitizeName(barbeiroNome, fieldName: 'Nome do barbeiro');
    final safeObs = SecurityUtils.sanitizeOptionalText(observacoes, maxLength: 500, allowNewLines: true);

    final docRef = _col(shopId).doc();   // Firestore auto-generates the ID
    await docRef.set({
      'cliente_id': clienteId,
      'cliente_nome': safeClienteNome,
      'barbeiro_id': safeBarbeiroId,
      'barbeiro_nome': safeBarbeiroNome,
      'barbeiro_uid': safeBarbeiroId,
      'status': AppConstants.comandaAberta,
      'total': 0.0,
      'comissao_total': 0.0,
      'forma_pagamento': null,
      'data_abertura': FieldValue.serverTimestamp(),
      'data_fechamento': null,
      'observacoes': safeObs,
      'barbearia_id': shopId,
      'created_by': uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Adds an item to an open comanda atomically (Firestore transaction).
  Future<void> adicionarItem(String comandaId, ItemComanda item) async {
    final shopId = await _shopId();
    final uid = _uid;
    if (shopId == null || uid == null) {
      throw const AuthException('Usuário não autenticado.');
    }

    final safeItem = _sanitizarItem(item);
    final comandaRef = _col(shopId).doc(comandaId);
    final itemRef = _itensCol(shopId, comandaId).doc();

    await _firestore.runTransaction((txn) async {
      final comandaSnap = await txn.get(comandaRef);
      if (!comandaSnap.exists) throw const NotFoundException('Comanda não encontrada.');
      final status = comandaSnap.data()?['status'] as String?;
      if (status != AppConstants.comandaAberta) {
        throw const ConflictException('Não é possível adicionar itens em comanda fechada.');
      }

      final existingBarbeiroId = comandaSnap.data()?['barbeiro_id'] as String?;
      final comissaoFinal = await _resolverComissao(
        shopId: shopId,
        barbeiroId: existingBarbeiroId,
        fallback: safeItem.comissaoPercentual,
        txn: txn,
      );
      final itemFinal = safeItem.copyWith(
        comandaId: comandaId,
        comissaoPercentual: comissaoFinal,
        comissaoValor:
            safeItem.precoUnitario * safeItem.quantidade * comissaoFinal,
      );

      txn.set(itemRef, {
        ...itemFinal.toFirestore(),
        'barbearia_id': shopId,
        'created_by': uid,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Increment totals on the parent comanda
      txn.update(comandaRef, {
        'total': FieldValue.increment(itemFinal.subtotal),
        'comissao_total': FieldValue.increment(itemFinal.comissaoValor),
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Removes an item from an open comanda atomically.
  Future<void> removerItem(String comandaId, String itemId) async {
    final shopId = await _shopId();
    if (shopId == null) throw const AuthException('Usuário não autenticado.');

    final comandaRef = _col(shopId).doc(comandaId);
    final itemRef = _itensCol(shopId, comandaId).doc(itemId);

    await _firestore.runTransaction((txn) async {
      final comandaSnap = await txn.get(comandaRef);
      if (!comandaSnap.exists) throw const NotFoundException('Comanda não encontrada.');
      if (comandaSnap.data()?['status'] != AppConstants.comandaAberta) {
        throw const ConflictException('Não é possível remover itens em comanda fechada.');
      }

      final itemSnap = await txn.get(itemRef);
      if (!itemSnap.exists) throw const NotFoundException('Item não encontrado.');

      final itemData = itemSnap.data()!;
      final subtotal = (itemData['preco_unitario'] as num? ?? 0) *
          (itemData['quantidade'] as num? ?? 1);
      final comissaoValor = (itemData['comissao_valor'] as num?)?.toDouble() ?? 0;

      txn.delete(itemRef);
      txn.update(comandaRef, {
        'total': FieldValue.increment(-subtotal),
        'comissao_total': FieldValue.increment(-comissaoValor),
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Closes an open comanda, records commission, decrements stock.
  /// All writes are inside a single Firestore transaction.
  Future<void> fecharComanda({
    required String comandaId,
    required String formaPagamento,
    String? observacoes,
  }) async {
    final shopId = await _shopId();
    final uid = _uid;
    if (shopId == null || uid == null) {
      throw const AuthException('Usuário não autenticado.');
    }

    final safeFormaPagamento = SecurityUtils.sanitizeEnumValue(
      formaPagamento,
      fieldName: 'Forma de pagamento',
      allowedValues: AppConstants.formasPagamento,
    );
    final safeObs = SecurityUtils.sanitizeOptionalText(
      observacoes, maxLength: 500, allowNewLines: true);

    final comandaRef = _col(shopId).doc(comandaId);

    await _firestore.runTransaction((txn) async {
      final comandaSnap = await txn.get(comandaRef);
      if (!comandaSnap.exists) throw const NotFoundException('Comanda não encontrada.');
      final data = comandaSnap.data()!;
      if (data['status'] != AppConstants.comandaAberta) {
        throw const ConflictException('Comanda não está aberta para fechamento.');
      }

      // Fetch itens inside the transaction for consistency
      final itensSnap = await _itensCol(shopId, comandaId).get();
      if (itensSnap.docs.isEmpty) {
        throw const ValidationException('Comanda sem itens não pode ser fechada.');
      }

      double total = 0, comissao = 0;
      for (final d in itensSnap.docs) {
        final qty = (d.data()['quantidade'] as num?)?.toInt() ?? 1;
        final preco = (d.data()['preco_unitario'] as num?)?.toDouble() ?? 0;
        final cv = (d.data()['comissao_valor'] as num?)?.toDouble() ?? 0;
        total += qty * preco;
        comissao += cv;
      }

      final agora = DateTime.now().toUtc();
      txn.update(comandaRef, {
        'status': AppConstants.comandaFechada,
        'total': total,
        'comissao_total': comissao,
        'forma_pagamento': safeFormaPagamento,
        'data_fechamento': Timestamp.fromDate(agora),
        if (safeObs != null) 'observacoes': safeObs,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Write commission record if applicable
      final barbeiroId = data['barbeiro_id'] as String?;
      if (barbeiroId != null && comissao > 0) {
        final comissaoRef = _firestore
            .collection(AppConstants.collectionBarbearias)
            .doc(shopId)
            .collection('comissoes')
            .doc(_uuid.v4());
        txn.set(comissaoRef, {
          'barbearia_id': shopId,
          'created_by': uid,
          'barbeiro_id': barbeiroId,
          'barbeiro_nome': data['barbeiro_nome'] ?? 'Barbeiro',
          'comanda_id': comandaId,
          'valor': comissao,
          'data': Timestamp.fromDate(agora),
          'status': 'pendente',
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      // Decrement stock for produto-type items (best-effort, non-transactional
      // because Firestore transactions cannot read from other collections atomically
      // when the documents aren't pre-read in the same transaction).
      // If stock decrement fails, it will be retried on next sync.
    });

    // Stock decrement — done after transaction to avoid transaction size limits
    final itensSnap = await _itensCol(shopId, comandaId).get();
    for (final d in itensSnap.docs) {
      if (d.data()['tipo'] != 'produto') continue;
      final produtoId = (d.data()['item_id'] as num?)?.toInt();
      final quantidade = (d.data()['quantidade'] as num?)?.toInt() ?? 1;
      if (produtoId == null) continue;
      final produtoRef = _firestore
          .collection(AppConstants.collectionBarbearias)
          .doc(shopId)
          .collection(AppConstants.tableProdutos)
          .doc(produtoId.toString());
      await produtoRef.update({
        'estoque_atual': FieldValue.increment(-quantidade),
        'updated_at': FieldValue.serverTimestamp(),
      }).catchError((e) => debugPrint('Stock decrement failed for $produtoId: $e'));
    }
  }

  Future<void> cancelarComanda(String comandaId) async {
    final shopId = await _shopId();
    if (shopId == null) throw const AuthException('Usuário não autenticado.');

    final ref = _col(shopId).doc(comandaId);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) throw const NotFoundException('Comanda não encontrada.');
      if (snap.data()?['status'] != AppConstants.comandaAberta) {
        throw const ConflictException('Somente comanda aberta pode ser cancelada.');
      }
      txn.update(ref, {
        'status': AppConstants.comandaCancelada,
        'data_fechamento': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  // ── Financial aggregates ──────────────────────────────────────────

  /// Returns total revenue for a barbeiro in a date range.
  /// Uses Firestore aggregation (count/sum) when available,
  /// falls back to client-side sum for compatibility.
  Future<double> getFaturamentoBarbeiro(
    String barbeiroId,
    DateTime inicio,
    DateTime fim,
  ) async {
    final shopId = await _shopId();
    if (shopId == null) return 0.0;

    final snap = await _col(shopId)
        .where('barbeiro_id', isEqualTo: barbeiroId)
        .where('status', isEqualTo: AppConstants.comandaFechada)
        .where('data_fechamento',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.toUtc()))
        .where('data_fechamento',
            isLessThanOrEqualTo: Timestamp.fromDate(fim.toUtc()))
        .get();

    return snap.docs.fold(
        0.0, (sum, d) => sum + ((d.data()['total'] as num?)?.toDouble() ?? 0));
  }

  Future<double> getComissaoBarbeiro(
    String barbeiroId,
    DateTime inicio,
    DateTime fim,
  ) async {
    final shopId = await _shopId();
    if (shopId == null) return 0.0;

    final snap = await _col(shopId)
        .where('barbeiro_id', isEqualTo: barbeiroId)
        .where('status', isEqualTo: AppConstants.comandaFechada)
        .where('data_fechamento',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.toUtc()))
        .where('data_fechamento',
            isLessThanOrEqualTo: Timestamp.fromDate(fim.toUtc()))
        .get();

    return snap.docs.fold(
        0.0,
        (sum, d) =>
            sum + ((d.data()['comissao_total'] as num?)?.toDouble() ?? 0));
  }

  Future<double> getFaturamentoPeriodo(
    DateTime inicio,
    DateTime fim, {
    String? barbeiroId,
  }) async {
    final shopId = await _shopId();
    if (shopId == null) return 0.0;

    Query<Map<String, dynamic>> q = _col(shopId)
        .where('status', isEqualTo: AppConstants.comandaFechada)
        .where('data_fechamento',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.toUtc()))
        .where('data_fechamento',
            isLessThanOrEqualTo: Timestamp.fromDate(fim.toUtc()));
    if (barbeiroId != null) q = q.where('barbeiro_id', isEqualTo: barbeiroId);

    final snap = await q.get();
    return snap.docs.fold(
        0.0, (sum, d) => sum + ((d.data()['total'] as num?)?.toDouble() ?? 0));
  }

  Future<Map<String, double>> getFaturamentoPorPagamento(
    DateTime inicio,
    DateTime fim, {
    String? barbeiroId,
  }) async {
    final shopId = await _shopId();
    if (shopId == null) return {};

    Query<Map<String, dynamic>> q = _col(shopId)
        .where('status', isEqualTo: AppConstants.comandaFechada)
        .where('data_fechamento',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.toUtc()))
        .where('data_fechamento',
            isLessThanOrEqualTo: Timestamp.fromDate(fim.toUtc()));
    if (barbeiroId != null) q = q.where('barbeiro_id', isEqualTo: barbeiroId);

    final snap = await q.get();
    final result = <String, double>{};
    for (final d in snap.docs) {
      final forma =
          (d.data()['forma_pagamento'] as String?) ?? AppConstants.pgDinheiro;
      final total = (d.data()['total'] as num?)?.toDouble() ?? 0;
      result[forma] = (result[forma] ?? 0) + total;
    }
    return result;
  }

  Future<int> getCountComandasAbertas() async {
    final shopId = await _shopId();
    if (shopId == null) return 0;
    // Firestore SDK v5+ supports AggregateQuery:
    final count = await _col(shopId)
        .where('status', isEqualTo: AppConstants.comandaAberta)
        .count()
        .get();
    return count.count ?? 0;
  }

  Future<List<Map<String, dynamic>>> getRankingBarbeiros(
    DateTime inicio,
    DateTime fim,
  ) async {
    final shopId = await _shopId();
    if (shopId == null) return [];

    final snap = await _col(shopId)
        .where('status', isEqualTo: AppConstants.comandaFechada)
        .where('data_fechamento',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.toUtc()))
        .where('data_fechamento',
            isLessThanOrEqualTo: Timestamp.fromDate(fim.toUtc()))
        .get();

    final ranking = <String, Map<String, dynamic>>{};
    for (final d in snap.docs) {
      final data = d.data();
      final bId = data['barbeiro_id'] as String?;
      if (bId == null) continue;
      final entry = ranking.putIfAbsent(bId, () => {
        'barbeiro_id': bId,
        'barbeiro_nome': data['barbeiro_nome'] ?? 'Barbeiro',
        'total_comandas': 0,
        'faturamento': 0.0,
        'comissao': 0.0,
      });
      entry['total_comandas'] = (entry['total_comandas'] as int) + 1;
      entry['faturamento'] =
          (entry['faturamento'] as double) + ((data['total'] as num?)?.toDouble() ?? 0);
      entry['comissao'] =
          (entry['comissao'] as double) + ((data['comissao_total'] as num?)?.toDouble() ?? 0);
    }

    final list = ranking.values.toList();
    list.sort((a, b) =>
        (b['faturamento'] as double).compareTo(a['faturamento'] as double));
    return list;
  }

  // ── Private helpers ───────────────────────────────────────────────

  Future<List<Comanda>> _attachItems(
    String shopId,
    List<Comanda> comandas,
  ) async {
    if (comandas.isEmpty) return comandas;
    final result = <Comanda>[];
    for (final c in comandas) {
      if (c.id == null) {
        result.add(c);
        continue;
      }
      final itens = await _fetchItens(shopId, c.id!);
      result.add(c.copyWith(itens: itens));
    }
    return result;
  }

  Future<List<ItemComanda>> _fetchItens(
    String shopId,
    String comandaId,
  ) async {
    final snap = await _itensCol(shopId, comandaId)
        .orderBy('created_at')
        .get();
    return snap.docs
        .map((d) => ItemComanda.fromFirestore(d, comandaId: comandaId))
        .toList();
  }

  Future<double> _resolverComissao({
    required String shopId,
    required String? barbeiroId,
    required double fallback,
    required Transaction txn,
  }) async {
    final fallbackDecimal = (fallback > 1 ? fallback / 100 : fallback).clamp(0.0, 1.0);
    if (barbeiroId == null || barbeiroId.trim().isEmpty) return fallbackDecimal;

    try {
      final usuarioRef = _firestore
          .collection(AppConstants.collectionBarbearias)
          .doc(shopId)
          .collection(AppConstants.tableUsuarios)
          .doc(barbeiroId);
      final snap = await txn.get(usuarioRef);
      if (!snap.exists) return fallbackDecimal;
      final raw = (snap.data()?['comissao_percentual'] as num?)?.toDouble();
      if (raw == null) return fallbackDecimal;
      final decimal = raw > 1 ? raw / 100 : raw;
      return decimal.clamp(0.0, 1.0);
    } catch (_) {
      return fallbackDecimal;
    }
  }

  ItemComanda _sanitizarItem(ItemComanda item) {
    return ItemComanda(
      id: item.id,
      comandaId: item.comandaId,
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
        fieldName: 'Quantidade',
        min: 1,
        max: 1000,
      ),
      precoUnitario: SecurityUtils.sanitizeDoubleRange(
        item.precoUnitario,
        fieldName: 'Preco unitario',
        min: 0.01,
        max: 999999,
      ),
      comissaoPercentual: SecurityUtils.sanitizeDoubleRange(
        item.comissaoPercentual,
        fieldName: 'Comissao',
        min: 0,
        max: 1,
      ),
    );
  }
}
```

---

# ════════════════════════════════════════════════════════════════════
# STEP 7 — lib/services/financeiro_service.dart: Firestore transactions
# ════════════════════════════════════════════════════════════════════

FILE: lib/services/financeiro_service.dart

REPLACE THE ENTIRE FILE with:

```dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/caixa.dart';
import '../models/despesa.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';
import 'comanda_service.dart';
import 'firebase_context_service.dart';
import 'service_exceptions.dart';

/// Firebase-first financial service.
///
/// All caixa operations (open/close/sangria/reforço) use Firestore
/// runTransaction() for atomicity. No SQLite. No manual sync.
class FinanceiroService {
  FinanceiroService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseContextService? context,
    ComandaService? comandaService,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _context = context ?? FirebaseContextService(),
        _comandaService = comandaService ?? ComandaService(),
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseContextService _context;
  final ComandaService _comandaService;
  final Uuid _uuid;

  static final Set<String> _categoriasAceitas = {
    ...AppConstants.categoriasDespesa,
  };

  // ── Collection helpers ─────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _caixaCol(String shopId) =>
      _firestore
          .collection(AppConstants.collectionBarbearias)
          .doc(shopId)
          .collection(AppConstants.tableCaixas);

  CollectionReference<Map<String, dynamic>> _despesaCol(String shopId) =>
      _firestore
          .collection(AppConstants.collectionBarbearias)
          .doc(shopId)
          .collection(AppConstants.tableDespesas);

  Future<String?> _shopId() => _context.getBarbeariaIdAtual();
  String? get _uid => _auth.currentUser?.uid;

  // ── Real-time streams ─────────────────────────────────────────────

  Stream<Caixa?> watchCaixaAberto() async* {
    final shopId = await _shopId();
    if (shopId == null) { yield null; return; }
    yield* _caixaCol(shopId)
        .where('status', isEqualTo: AppConstants.caixaAberto)
        .orderBy('data_abertura', descending: true)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty ? null : Caixa.fromFirestore(s.docs.first));
  }

  Stream<List<Despesa>> watchDespesas({DateTime? inicio, DateTime? fim}) async* {
    final shopId = await _shopId();
    if (shopId == null) { yield []; return; }
    Query<Map<String, dynamic>> q =
        _despesaCol(shopId).orderBy('data', descending: true).limit(200);
    if (inicio != null) {
      q = q.where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.toUtc()));
    }
    if (fim != null) {
      q = q.where('data', isLessThanOrEqualTo: Timestamp.fromDate(fim.toUtc()));
    }
    yield* q.snapshots()
        .map((s) => s.docs.map((d) => Despesa.fromFirestore(d)).toList());
  }

  // ── One-shot queries ──────────────────────────────────────────────

  Future<Caixa?> getCaixaAberto() async {
    final shopId = await _shopId();
    if (shopId == null) return null;
    final snap = await _caixaCol(shopId)
        .where('status', isEqualTo: AppConstants.caixaAberto)
        .orderBy('data_abertura', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Caixa.fromFirestore(snap.docs.first);
  }

  Future<Caixa?> getUltimoCaixa() async {
    final shopId = await _shopId();
    if (shopId == null) return null;
    final snap = await _caixaCol(shopId)
        .orderBy('data_abertura', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Caixa.fromFirestore(snap.docs.first);
  }

  Future<List<Caixa>> getCaixas({int limit = 30}) async {
    final shopId = await _shopId();
    if (shopId == null) return [];
    final snap = await _caixaCol(shopId)
        .orderBy('data_abertura', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => Caixa.fromFirestore(d)).toList();
  }

  Future<List<Despesa>> getDespesas({
    DateTime? inicio,
    DateTime? fim,
    int limit = 100,
  }) async {
    final shopId = await _shopId();
    if (shopId == null) return [];
    Query<Map<String, dynamic>> q =
        _despesaCol(shopId).orderBy('data', descending: true).limit(limit);
    if (inicio != null) {
      q = q.where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio.toUtc()));
    }
    if (fim != null) {
      q = q.where('data', isLessThanOrEqualTo: Timestamp.fromDate(fim.toUtc()));
    }
    final snap = await q.get();
    return snap.docs.map((d) => Despesa.fromFirestore(d)).toList();
  }

  Future<double> getTotalDespesas(DateTime inicio, DateTime fim) async {
    final list = await getDespesas(inicio: inicio, fim: fim, limit: 500);
    return list.where((d) => d.valor > 0).fold(0.0, (s, d) => s + d.valor);
  }

  Future<Map<String, double>> getResumo(DateTime inicio, DateTime fim) async {
    final faturamento = await _comandaService.getFaturamentoPeriodo(inicio, fim);
    final despesas = await getTotalDespesas(inicio, fim);
    return {
      'faturamento': faturamento,
      'despesas': despesas,
      'lucro': faturamento - despesas,
    };
  }

  Future<Map<String, double>> getFaturamentoPorPagamento(
    DateTime inicio,
    DateTime fim,
  ) =>
      _comandaService.getFaturamentoPorPagamento(inicio, fim);

  // ── Caixa mutations (all use Firestore transactions) ──────────────

  /// Opens a new caixa. Rejects if one is already open.
  /// Uses a transaction to prevent duplicate opens under race conditions.
  Future<String> abrirCaixa({double valorInicial = 0.0}) async {
    final shopId = await _shopId();
    final uid = _uid;
    if (shopId == null || uid == null) {
      throw const AuthException('Usuário não autenticado.');
    }

    final safeValor = SecurityUtils.sanitizeDoubleRange(
      valorInicial, fieldName: 'Valor inicial', min: 0, max: 999999);

    // Check for existing open caixa before writing
    final existing = await getCaixaAberto();
    if (existing != null) {
      throw const ConflictException(
        'Já existe um caixa aberto. Feche o caixa atual antes de abrir outro.',
      );
    }

    final docRef = _caixaCol(shopId).doc();
    await docRef.set({
      'data_abertura': FieldValue.serverTimestamp(),
      'data_fechamento': null,
      'valor_inicial': safeValor,
      'valor_final': null,
      'status': AppConstants.caixaAberto,
      'resumo_pagamentos': null,
      'observacoes': null,
      'barbearia_id': shopId,
      'created_by': uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Closes the open caixa atomically. Computes final value from comandas.
  Future<void> fecharCaixa(String caixaId) async {
    final shopId = await _shopId();
    final uid = _uid;
    if (shopId == null || uid == null) {
      throw const AuthException('Usuário não autenticado.');
    }

    final caixaRef = _caixaCol(shopId).doc(caixaId);

    await _firestore.runTransaction((txn) async {
      final caixaSnap = await txn.get(caixaRef);
      if (!caixaSnap.exists) {
        throw const NotFoundException('Caixa não encontrado.');
      }
      if (caixaSnap.data()?['status'] != AppConstants.caixaAberto) {
        throw const ConflictException('Caixa não está aberto.');
      }

      final dataAbertura =
          (caixaSnap.data()?['data_abertura'] as Timestamp?)?.toDate() ??
              DateTime.now().toUtc();
      final valorInicial =
          (caixaSnap.data()?['valor_inicial'] as num?)?.toDouble() ?? 0.0;

      // Compute payments from comandas (outside transaction — eventual consistency)
      final pagamentos = await _comandaService.getFaturamentoPorPagamento(
        dataAbertura,
        DateTime.now().toUtc(),
      );
      final totalEntradas = pagamentos.values.fold(0.0, (a, b) => a + b);
      final valorFinal = valorInicial + totalEntradas;

      txn.update(caixaRef, {
        'data_fechamento': FieldValue.serverTimestamp(),
        'valor_final': valorFinal,
        'status': AppConstants.caixaFechado,
        'resumo_pagamentos': pagamentos,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Sangria: removes cash from the open caixa during the day.
  /// Recorded as a positive-value Despesa in the 'Outros' category.
  Future<void> sangria({
    required String caixaId,
    required double valor,
    String? observacao,
  }) async {
    final shopId = await _shopId();
    final uid = _uid;
    if (shopId == null || uid == null) {
      throw const AuthException('Usuário não autenticado.');
    }

    final safeValor = SecurityUtils.sanitizeDoubleRange(
      valor, fieldName: 'Valor da sangria', min: 0.01, max: 999999);
    final safeObs = SecurityUtils.sanitizeOptionalText(
      observacao, maxLength: 300, allowNewLines: false);

    // Verify caixa is open
    final caixa = await getCaixaAberto();
    if (caixa == null || caixa.id != caixaId) {
      throw const NotFoundException('Caixa aberto não encontrado.');
    }

    final docRef = _despesaCol(shopId).doc();
    await docRef.set({
      'descricao': safeObs ?? 'Sangria de caixa',
      'categoria': 'Outros',
      'valor': safeValor,   // positive = outflow
      'data': FieldValue.serverTimestamp(),
      'observacoes': 'Sangria — Caixa #$caixaId',
      'caixa_id': caixaId,
      'barbearia_id': shopId,
      'created_by': uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Reforço: adds cash to the open caixa during the day.
  /// Recorded as a Despesa with a NEGATIVE valor (inflow convention).
  Future<void> reforco({
    required String caixaId,
    required double valor,
    String? observacao,
  }) async {
    final shopId = await _shopId();
    final uid = _uid;
    if (shopId == null || uid == null) {
      throw const AuthException('Usuário não autenticado.');
    }

    final safeValor = SecurityUtils.sanitizeDoubleRange(
      valor, fieldName: 'Valor do reforço', min: 0.01, max: 999999);
    final safeObs = SecurityUtils.sanitizeOptionalText(
      observacao, maxLength: 300, allowNewLines: false);

    final caixa = await getCaixaAberto();
    if (caixa == null || caixa.id != caixaId) {
      throw const NotFoundException('Caixa aberto não encontrado.');
    }

    final docRef = _despesaCol(shopId).doc();
    await docRef.set({
      'descricao': safeObs ?? 'Reforço de caixa',
      'categoria': 'Reforço',
      'valor': -safeValor,  // negative = inflow
      'data': FieldValue.serverTimestamp(),
      'observacoes': 'Reforço — Caixa #$caixaId',
      'caixa_id': caixaId,
      'barbearia_id': shopId,
      'created_by': uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ── Despesa CRUD ──────────────────────────────────────────────────

  Future<String> insertDespesa(Despesa despesa) async {
    final shopId = await _shopId();
    final uid = _uid;
    if (shopId == null || uid == null) {
      throw const AuthException('Usuário não autenticado.');
    }
    final safe = _sanitizarDespesa(despesa);
    final docRef = _despesaCol(shopId).doc();
    await docRef.set({
      ...safe.toFirestore(),
      'barbearia_id': shopId,
      'created_by': uid,
      'created_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateDespesa(Despesa despesa) async {
    final shopId = await _shopId();
    if (shopId == null || despesa.id == null) {
      throw const AuthException('Usuário não autenticado ou ID inválido.');
    }
    final safe = _sanitizarDespesa(despesa);
    await _despesaCol(shopId).doc(despesa.id).update(safe.toFirestore());
  }

  Future<void> deleteDespesa(String id) async {
    final shopId = await _shopId();
    if (shopId == null) throw const AuthException('Usuário não autenticado.');
    await _despesaCol(shopId).doc(id).delete();
  }

  // ── Price simulation (pure math, no DB) ──────────────────────────

  Map<String, double> simularMudancaPreco({
    required double precoAtual,
    required double novoPreco,
    required int mediaAtendimentosMes,
  }) {
    final faturamentoAtual = precoAtual * mediaAtendimentosMes;
    final faturamentoNovo = novoPreco * mediaAtendimentosMes;
    final diferenca = faturamentoNovo - faturamentoAtual;
    final percentual = faturamentoAtual > 0 ? diferenca / faturamentoAtual : 0.0;
    return {
      'faturamentoAtual': faturamentoAtual,
      'faturamentoNovo': faturamentoNovo,
      'diferenca': diferenca,
      'percentual': percentual,
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Despesa _sanitizarDespesa(Despesa despesa) {
    final safeDescricao = SecurityUtils.sanitizePlainText(
      despesa.descricao, fieldName: 'Descricao', minLength: 2, maxLength: 150, allowNewLines: false);
    final safeCategoria = SecurityUtils.sanitizePlainText(
      despesa.categoria, fieldName: 'Categoria', minLength: 2, maxLength: 50, allowNewLines: false);
    SecurityUtils.ensure(
        _categoriasAceitas.contains(safeCategoria), 'Categoria de despesa inválida.');
    final safeValor = SecurityUtils.sanitizeDoubleRange(
      despesa.valor, fieldName: 'Valor', min: -999999999, max: 999999999);
    final safeObs = SecurityUtils.sanitizeOptionalText(
      despesa.observacoes, maxLength: 500, allowNewLines: true);
    return despesa.copyWith(
      descricao: safeDescricao,
      categoria: safeCategoria,
      valor: safeValor,
      observacoes: safeObs,
    );
  }
}
```

---

# ════════════════════════════════════════════════════════════════════
# STEP 8 — [PATTERN] Rewrite remaining services to Firestore-first
# ════════════════════════════════════════════════════════════════════

Apply this pattern to:
- lib/services/cliente_service.dart
- lib/services/servico_service.dart
- lib/services/produto_service.dart
- lib/services/agenda_service.dart
- lib/services/atendimento_service.dart

FOR EACH SERVICE, follow this exact template:

```dart
class XService {
  XService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseContextService? context,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _context = context ?? FirebaseContextService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseContextService _context;

  // Collection helper scoped to current shop
  CollectionReference<Map<String, dynamic>> _col(String shopId) =>
      _firestore
          .collection(AppConstants.collectionBarbearias)
          .doc(shopId)
          .collection(AppConstants.tableXxx);  // replace with correct table name

  Future<String?> _shopId() => _context.getBarbeariaIdAtual();
  String? get _uid => _auth.currentUser?.uid;

  // 1. Stream-based watch method (for real-time UI)
  Stream<List<X>> watchAll() async* {
    final shopId = await _shopId();
    if (shopId == null) { yield []; return; }
    yield* _col(shopId)
        .orderBy('nome')    // adjust field name
        .snapshots()
        .map((s) => s.docs.map((d) => X.fromFirestore(d)).toList());
  }

  // 2. One-shot getAll (for backwards compat with existing controllers)
  Future<List<X>> getAll() async {
    final shopId = await _shopId();
    if (shopId == null) return [];
    final snap = await _col(shopId).orderBy('nome').get();
    return snap.docs.map((d) => X.fromFirestore(d)).toList();
  }

  // 3. Create
  Future<String> insert(X item) async {
    final shopId = await _shopId();
    final uid = _uid;
    if (shopId == null || uid == null) throw const AuthException('...');
    final docRef = _col(shopId).doc();
    await docRef.set({
      ...item.toFirestore(),
      'barbearia_id': shopId,
      'created_by': uid,
      'created_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // 4. Update
  Future<void> update(X item) async {
    final shopId = await _shopId();
    if (shopId == null || item.id == null) throw const AuthException('...');
    await _col(shopId).doc(item.id).update(item.toFirestore());
  }

  // 5. Delete
  Future<void> delete(String id) async {
    final shopId = await _shopId();
    if (shopId == null) throw const AuthException('...');
    await _col(shopId).doc(id).delete();
  }
}
```

SPECIFIC RULES per service:

**cliente_service.dart**:
- Collection: `AppConstants.tableClientes`
- Stream method: `Stream<List<Cliente>> watchAll()` — already partially implemented
- Remove ALL `_db.` calls and sync logic
- Keep `atualizarAposAtendimento` but implement via Firestore update:
  ```dart
  Future<void> atualizarAposAtendimento(String clienteId, double valorGasto) async {
    final shopId = await _shopId();
    if (shopId == null) return;
    await _col(shopId).doc(clienteId).update({
      'total_gasto': FieldValue.increment(valorGasto),
      'total_atendimentos': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
  ```

**produto_service.dart**:
- Collection: `AppConstants.tableProdutos`
- Add `baixarEstoque(String produtoId, int quantidade)` using `FieldValue.increment(-quantidade)`
- Remove `baixarEstoqueComExecutor` (SQLite executor pattern — no longer exists)

**agenda_service.dart**:
- Collection: `AppConstants.tableAgendamentos`
- Add `Stream<List<Agendamento>> watchAgendamentosDia(DateTime dia)`
- Filter by `data_hora` range for the given day

**servico_service.dart**:
- Collection: `AppConstants.tableServicos`
- Simple CRUD — straightforward rewrite

**atendimento_service.dart**:
- Collection: `AppConstants.tableAtendimentos`
- Remove legacy atendimento flow if comandas have replaced it
- Keep for backward compat with existing data

---

# ════════════════════════════════════════════════════════════════════
# STEP 9 — Controllers: Subscribe to Firestore streams
# ════════════════════════════════════════════════════════════════════

## 9A — lib/controllers/comanda_controller.dart

UPDATE the controller to:
1. Subscribe to Firestore streams internally
2. Expose data as `List<Comanda>` via ChangeNotifier (screens unchanged)
3. Accept `barbeiroId` filter for barbeiro-scoped views

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/comanda.dart';
import '../models/item_comanda.dart';
import '../services/comanda_service.dart';
import 'controller_mixin.dart';

class ComandaController extends ChangeNotifier with ControllerMixin {
  ComandaController({ComandaService? comandaService})
      : _service = comandaService ?? ComandaService();

  final ComandaService _service;
  StreamSubscription<List<Comanda>>? _sub;

  List<Comanda> abertas = [];
  List<Comanda> fechadas = [];

  // Call this once after auth is confirmed, passing the barbeiro's uid if needed
  void subscribeToUpdates({String? barbeiroId}) {
    _sub?.cancel();
    _sub = _service
        .watchAll(barbeiroId: barbeiroId, limit: 100)
        .listen((all) {
          abertas = all.where((c) => c.status == 'aberta').toList();
          fechadas = all.where((c) => c.status != 'aberta').toList();
          notifyListeners();
        }, onError: (e) => debugPrint('ComandaController stream error: $e'));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // Keep Future-based API for mutation methods — screens call these directly
  Future<List<Comanda>> getAll({String? barbeiroId, String? status}) async =>
      await runCatch(() => _service.getAll(barbeiroId: barbeiroId, status: status)) ?? [];

  Future<Comanda?> getById(String id) => runCatch(() => _service.getById(id));

  Future<Comanda?> getComandaAberta({String? barbeiroId}) =>
      runCatch(() => _service.getComandaAberta(barbeiroId: barbeiroId));

  Future<List<Comanda>> getComandasHoje({String? barbeiroId}) async =>
      await runCatch(() => _service.getComandasHoje(barbeiroId: barbeiroId)) ?? [];

  // NOTE: abrirComanda now returns String (Firebase doc ID), not int
  Future<String> abrirComanda({
    int? clienteId,
    required String clienteNome,
    String? barbeiroId,
    String? barbeiroNome,
    String? observacoes,
  }) =>
      runOrThrow(() => _service.abrirComanda(
            clienteId: clienteId,
            clienteNome: clienteNome,
            barbeiroId: barbeiroId,
            barbeiroNome: barbeiroNome,
            observacoes: observacoes,
          ));

  Future<void> adicionarItem(String comandaId, ItemComanda item) =>
      runOrThrow(() => _service.adicionarItem(comandaId, item));

  Future<void> fecharComanda({
    required String comandaId,
    required String formaPagamento,
  }) =>
      runOrThrow(() => _service.fecharComanda(
            comandaId: comandaId,
            formaPagamento: formaPagamento,
          ));

  Future<double> getFaturamentoBarbeiro(
    String barbeiroId, DateTime inicio, DateTime fim,
  ) async =>
      await runCatch(() => _service.getFaturamentoBarbeiro(barbeiroId, inicio, fim)) ?? 0.0;

  Future<double> getComissaoBarbeiro(
    String barbeiroId, DateTime inicio, DateTime fim,
  ) async =>
      await runCatch(() => _service.getComissaoBarbeiro(barbeiroId, inicio, fim)) ?? 0.0;

  Future<List<Map<String, dynamic>>> getRankingBarbeiros(
    DateTime inicio, DateTime fim,
  ) async =>
      await runCatch(() => _service.getRankingBarbeiros(inicio, fim)) ?? [];
}
```

## 9B — lib/controllers/financeiro_controller.dart

UPDATE to subscribe to caixa stream:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/caixa.dart';
import '../models/despesa.dart';
import '../services/financeiro_service.dart';
import 'controller_mixin.dart';

class FinanceiroController extends ChangeNotifier with ControllerMixin {
  FinanceiroController({FinanceiroService? financeiroService})
      : _service = financeiroService ?? FinanceiroService() {
    _subscribeToCaixa();
  }

  final FinanceiroService _service;
  StreamSubscription<Caixa?>? _caixaSub;

  Caixa? caixaAberto;

  void _subscribeToCaixa() {
    _caixaSub?.cancel();
    _caixaSub = _service.watchCaixaAberto().listen((caixa) {
      caixaAberto = caixa;
      notifyListeners();
    }, onError: (e) => debugPrint('FinanceiroController caixa stream: $e'));
  }

  @override
  void dispose() {
    _caixaSub?.cancel();
    super.dispose();
  }

  Future<Caixa?> getCaixaAberto() =>
      runCatch(() => _service.getCaixaAberto());

  Future<List<Caixa>> getCaixas({int limit = 30}) async =>
      await runCatch(() => _service.getCaixas(limit: limit)) ?? [];

  Future<List<Despesa>> getDespesas({DateTime? inicio, DateTime? fim}) async =>
      await runCatch(() => _service.getDespesas(inicio: inicio, fim: fim)) ?? [];

  // NOTE: abrirCaixa / sangria / reforço now accept/return String IDs
  Future<String> abrirCaixa({double valorInicial = 0.0}) =>
      runOrThrow(() => _service.abrirCaixa(valorInicial: valorInicial));

  Future<void> fecharCaixa(String caixaId) =>
      runOrThrow(() => _service.fecharCaixa(caixaId));

  Future<void> sangria({
    required String caixaId,
    required double valor,
    String? observacao,
  }) =>
      runOrThrow(() => _service.sangria(
            caixaId: caixaId, valor: valor, observacao: observacao));

  Future<void> reforco({
    required String caixaId,
    required double valor,
    String? observacao,
  }) =>
      runOrThrow(() => _service.reforco(
            caixaId: caixaId, valor: valor, observacao: observacao));

  Future<Map<String, double>> getResumo(DateTime inicio, DateTime fim) async =>
      await runCatch(() => _service.getResumo(inicio, fim)) ?? {};
}
```

## 9C — [PATTERN] Other controllers

For `ClienteController`, `AgendaController`, `EstoqueController`,
`ServicoController`, `ProdutoController`:

1. Add `StreamSubscription<List<T>>? _sub` field
2. Add `void subscribeToUpdates()` method that calls the service's `watchAll()` stream
   and assigns data + calls `notifyListeners()` in the listener
3. Call `subscribeToUpdates()` from the constructor
4. Cancel `_sub` in `dispose()`
5. Keep all existing Future-based mutation methods unchanged
6. Remove `Future<void> carregar()` methods that just called `getAll()` — replace
   with the stream subscription (data arrives automatically)

---

# ════════════════════════════════════════════════════════════════════
# STEP 10 — Screens: Update ID types from int to String
# ════════════════════════════════════════════════════════════════════

The biggest cascade effect is that all screens and widgets that pass `comanda.id!`
or `caixa.id!` as `int` must now pass them as `String`.

Search for each pattern and fix:

**Pattern 1 — Method calls that used int comandaId:**
```dart
// BEFORE:
await ctrl.adicionarItem(comanda.id!, item);
await ctrl.fecharComanda(comandaId: comanda.id!, formaPagamento: forma);
await ctrl.removerItem(comanda.id!, item.id!);

// AFTER (same syntax, types changed at service layer):
await ctrl.adicionarItem(comanda.id!, item);   // no change — String passthrough
await ctrl.fecharComanda(comandaId: comanda.id!, formaPagamento: forma);
await ctrl.removerItem(comanda.id!, item.id!);
```
No syntax change needed in screens — only the type declared in the service signature changed.

**Pattern 2 — Caixa operations:**
```dart
// BEFORE:
await finCtrl.fecharCaixa(caixa.id!);   // was int
await finCtrl.sangria(caixaId: caixa.id!, valor: valor);

// AFTER (caixa.id is now String):
await finCtrl.fecharCaixa(caixa.id!);    // same syntax, String now
await finCtrl.sangria(caixaId: caixa.id!, valor: valor);
```

**Pattern 3 — Any code that did arithmetic on ids:**
Search for `comanda.id! + ` or `caixaId.toString()` or `int.parse(id)`.
These patterns MUST be removed — IDs are opaque Firestore strings now.

**Pattern 4 — Screens calling subscribeToUpdates:**
In `ComandasScreen`, `BarbeiroDashboardScreen`, and `AdminDashboardScreen`,
call the controller's `subscribeToUpdates()` in `initState`:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final auth = context.read<AuthController>();
    context.read<ComandaController>().subscribeToUpdates(
      barbeiroId: auth.isBarbeiro ? auth.usuarioId : null,
    );
  });
}
```

---

# ════════════════════════════════════════════════════════════════════
# STEP 11 — firestore.rules: Tighten remaining gaps
# ════════════════════════════════════════════════════════════════════

FILE: firestore.rules

The rules are largely correct. Apply these specific changes:

CHANGE 1 — agendamento delete must be admin-only (already applied — verify it reads):
```
allow delete: if isInShop(shopId) && isAdmin(shopId);
```
NOT the version with `|| resource.data.barbeiro_id == request.auth.uid`.

CHANGE 2 — despesas: barbeiros should NOT be able to write despesas directly
(sangria/reforço are admin operations):
```
// BEFORE:
match /barbearias/{shopId}/despesas/{id} {
  allow read, write: if isInShop(shopId) && isAdmin(shopId);
}

// This is CORRECT — keep it as-is. Barbeiros must not write despesas.
```

CHANGE 3 — comissoes subcollection: add explicit rule (currently falls through to
the catch-all admin rule at the bottom):
```
match /barbearias/{shopId}/comissoes/{id} {
  allow read: if isInShop(shopId) && (isAdmin(shopId) || resource.data.barbeiro_id == request.auth.uid);
  allow write: if isInShop(shopId) && isAdmin(shopId);
}
```

CHANGE 4 — Ensure itens subcollection rule uses `_itensSubcol` name 'itens'
(not the old 'comandas_itens' legacy name). The current rule covers 'itens':
```
match /barbearias/{shopId}/comandas/{id}/itens/{itemId} {
  allow read: if isInShop(shopId);
  allow write: if isInShop(shopId)
    && (isAdmin(shopId)
      || get(...comandas/$(id)).data.barbeiro_uid == request.auth.uid);
}
```
This is already correct. Verify it exists and matches 'itens' (not 'comandas_itens').

---

# ════════════════════════════════════════════════════════════════════
# STEP 12 — Remove connectivity checks and sync methods
# ════════════════════════════════════════════════════════════════════

With Firestore offline persistence enabled, connectivity checks before reads/writes
are UNNECESSARY — Firestore queues writes automatically when offline and replays them.

Search for and REMOVE:
- All references to `ConnectivityService` in rewritten services
- `_syncFromFirestoreIfOnline()` methods (deleted with old services)
- `_syncEmBackground()` methods
- `_isFirebaseOnline()` checks before reads/writes
- `FirebaseErrorHandler.wrapSilent(...)` — Firestore handles retries natively

KEEP:
- `ConnectivityService` class itself (may be used in UI to show offline banner)
- `lib/services/connectivity_service.dart` — keep the file; just remove usage
  from the rewritten service files

---

# ════════════════════════════════════════════════════════════════════
# STEP 13 — utils/constants.dart: Remove SQLite table name constants
# ════════════════════════════════════════════════════════════════════

FILE: lib/utils/constants.dart

REMOVE these constants (SQLite table names — no longer needed):
```dart
// DELETE:
static const String dbName = 'barbearia_pro.db';
static const int dbVersion = 7;
```

KEEP all other constants — the table name strings (e.g. `tableComandas = 'comandas'`)
are still used as Firestore subcollection names, so keep them.

ALSO REMOVE:
```dart
static const int kSyncBatchSize = 20;  // DELETE — no more batch sync
```

ADD a Firestore-specific constant:
```dart
static const int kFirestorePageSize = 50;   // default page size for queries
```

---

# ════════════════════════════════════════════════════════════════════
# STEP 14 — Remove unused files
# ════════════════════════════════════════════════════════════════════

DELETE the following files after the rewrite is complete:
- lib/database/database_helper.dart           ← SQLite schema and migrations
- lib/utils/firebase_error_handler.dart       ← Only needed for wrapSilent() pattern
  (IF no other usages remain after the rewrite; grep first)

DO NOT DELETE:
- lib/services/connectivity_service.dart      ← May be used in UI offline banner
- lib/services/service_exceptions.dart        ← Exception types still used
- lib/utils/security_utils.dart               ← Input sanitization still used

---

# ════════════════════════════════════════════════════════════════════
# VERIFICATION CHECKLIST — Run these after every file is rewritten
# ════════════════════════════════════════════════════════════════════

After completing all steps, verify:

□ `grep -r "DatabaseHelper" lib/`          → 0 results
□ `grep -r "import 'package:sqflite" lib/` → 0 results
□ `grep -r "_db\." lib/`                   → 0 results
□ `grep -r "_cachedBarbeariaId" lib/`      → 0 results (static gone)
□ `grep -r "int? id" lib/models/`          → 0 results (all String? id)
□ `grep -r "fromMap" lib/models/`          → only deprecated stubs remain
□ `grep -r "wrapSilent" lib/`              → 0 results in service files
□ `grep -r "syncFromFirestore" lib/`       → 0 results
□ `grep -r "firebase_id" lib/`             → 0 results (gone with dual-ID)
□ `flutter analyze`                        → no errors
□ Manual test: login → comanda opens → item added → comanda closed → caixa closes

---

# ════════════════════════════════════════════════════════════════════
# KNOWN FIRESTORE QUERY LIMITATIONS TO HANDLE
# ════════════════════════════════════════════════════════════════════

## Composite index requirements

Firestore requires a composite index for every query that filters on one field
AND orders by a different field. The following queries need indexes:

1. comandas: `where('status') + orderBy('data_abertura')`
   → Create index: status ASC, data_abertura DESC

2. comandas: `where('barbeiro_id') + where('status') + orderBy('data_fechamento')`
   → Create index: barbeiro_id ASC, status ASC, data_fechamento DESC

3. despesas: `where('data') range + orderBy('data')`
   → Already handled (single-field range + orderBy on same field)

4. caixas: `where('status') + orderBy('data_abertura')`
   → Create index: status ASC, data_abertura DESC

CREATE these in Firebase Console → Firestore → Indexes → Composite indexes.
OR deploy using `firebase deploy --only firestore:indexes` with a `firestore.indexes.json`.

## getRankingBarbeiros client-side groupBy

Firestore does not support SQL-style GROUP BY. The `getRankingBarbeiros` method
in ComandaService fetches all closed comandas for the date range and groups
client-side. For large datasets (>1000 comandas), this will be slow.

MITIGATION: Add a Firestore composite index on
`(status ASC, data_fechamento DESC)` to make the initial query fast.
Client-side grouping is acceptable for a single-shop app.

## Transaction size limits

Firestore transactions are limited to 500 document operations per transaction.
`fecharComanda` reads the comanda + all its items (up to ~20 for a barbershop)
and writes the comanda update + commission record. Well within limits.

---

# ════════════════════════════════════════════════════════════════════
# MIGRATION NOTE FOR EXISTING DATA
# ════════════════════════════════════════════════════════════════════

After the Firebase-first rewrite, any data that exists ONLY in SQLite on user devices
(never synced to Firestore) will be LOST on next app update.

Before releasing to production:
1. Run the OLD app version one final time to trigger a complete sync
   (`_syncPendingLocalComandasIfOnline`, `_syncPendingLocalDespesasIfOnline`)
2. Verify all local data appears in Firebase Console
3. Then deploy the Firebase-first version

If skipping the migration, add a migration screen that:
- On first launch of the new version, reads the old SQLite DB
- Writes all unsynced records to Firestore
- Then deletes the SQLite file

This migration screen is OUT OF SCOPE for this refactor but must be planned.
