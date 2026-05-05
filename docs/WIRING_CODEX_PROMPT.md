# Severus Barber Pro — Codex Prompt: Wiring de Controllers
# Gerado em 2026-05-04 — último gap de código antes da produção

## CONTEXTO

App Flutter multi-tenant com Firebase Firestore. Arquitetura dual-write
(Firestore primário + SQLite cache offline).

Em `lib/main.dart`, os services críticos são instanciados uma vez e
compartilhados via Provider:

```dart
// Singletons globais em main.dart
SessionManager _sharedSessionManager
FirebaseContextService _sharedFirebaseContext   // ← depende do _sharedSessionManager
ComandaService _sharedComandaService            // ← depende do _sharedFirebaseContext
AgendaService _sharedAgendaService
FinanceiroService _sharedFinanceiroService
AtendimentoService _sharedAtendimentoService
AuthService _sharedAuthService
```

## PROBLEMA

**5 controllers são criados sem receber o contexto compartilhado:**

```dart
// main.dart — ATUAL (errado)
ChangeNotifierProvider(create: (_) => ClienteController()),
ChangeNotifierProvider(create: (_) => AtendimentoController(
    atendimentoService: _sharedAtendimentoService)),
ChangeNotifierProvider(create: (_) => EstoqueController()),
// ...
ChangeNotifierProvider(create: (_) => DashboardController()),
ChangeNotifierProvider(create: (_) => ServicoController()),
ChangeNotifierProvider(create: (_) => ProdutoController()),
```

Quando `ClienteController()` é criado sem argumento, ele cria internamente:
`ClienteService()` → `FirebaseContextService()` → `SessionManager()`

Cada `SessionManager` orphan:
1. Faz até **3 queries Firestore** para resolver `barbeariaId` (incluindo uma
   `collectionGroup` query cara) — multiplicado por 5 controllers = ~15 reads extras
2. Abre um `authStateChanges().listen(...)` que **nunca é cancelado** (leak)
3. Pode retornar `barbeariaId == null` na primeira leitura se a resolução
   ainda não terminou, causando flicker nos dados

## FIX

### PASSO 1 — Criar services compartilhados para os controllers orphans

Em `lib/main.dart`, adicionar ao final de `_inicializarServicosCompartilhados()`:

```dart
// Adicionar estas variáveis no topo do arquivo (junto com os outros _shared*):
ClienteService? _sharedClienteService;
ProdutoService? _sharedProdutoService;
ServicoService? _sharedServicoService;
DashboardService? _sharedDashboardService;

// Adicionar no corpo de _inicializarServicosCompartilhados():
final produto = _sharedProdutoService ??= ProdutoService(
  context: firebaseContext,
);
_sharedClienteService ??= ClienteService(
  context: firebaseContext,
);
_sharedServicoService ??= ServicoService(
  context: firebaseContext,
);
_sharedDashboardService ??= DashboardService(
  comandaService: comanda,
  financeiroService: _sharedFinanceiroService!,
  produtoService: produto,
  clienteService: _sharedClienteService!,
  agendaService: _sharedAgendaService!,
);
```

### PASSO 2 — Passar os services para os controllers no MultiProvider

Substituir as 5 linhas no `MultiProvider` em `SeverusBarberApp.build()`:

```dart
// ANTES (cria instâncias orphans):
ChangeNotifierProvider(create: (_) => ClienteController()),
ChangeNotifierProvider(create: (_) => AtendimentoController(
    atendimentoService: _sharedAtendimentoService)),
ChangeNotifierProvider(create: (_) => EstoqueController()),
ChangeNotifierProvider(create: (_) => DashboardController()),
ChangeNotifierProvider(create: (_) => ServicoController()),
ChangeNotifierProvider(create: (_) => ProdutoController()),

// DEPOIS (usa singletons compartilhados):
ChangeNotifierProvider(create: (_) => ClienteController(
    clienteService: _sharedClienteService)),
ChangeNotifierProvider(create: (_) => AtendimentoController(
    atendimentoService: _sharedAtendimentoService)),
ChangeNotifierProvider(create: (_) => EstoqueController(
    produtoService: _sharedProdutoService)),
ChangeNotifierProvider(create: (_) => DashboardController(
    dashboardService: _sharedDashboardService)),
ChangeNotifierProvider(create: (_) => ServicoController(
    servicoService: _sharedServicoService)),
ChangeNotifierProvider(create: (_) => ProdutoController(
    produtoService: _sharedProdutoService)),
```

### PASSO 3 — Garantir que _inicializarServicosCompartilhados() é idempotente

A função já é chamada duas vezes (em `main()` e em `SeverusBarberApp.build()`).
O padrão `??=` garante idempotência — não modificar esse comportamento.

Verificar que a ordem de inicialização dentro de `_inicializarServicosCompartilhados()`
respeita as dependências:

```
SessionManager
  └─ FirebaseContextService
       ├─ ComandaService
       │    └─ AgendaService
       │    └─ FinanceiroService
       │    └─ AtendimentoService (novo — já wired)
       ├─ ClienteService  (novo)
       ├─ ProdutoService  (novo)
       ├─ ServicoService  (novo)
       └─ DashboardService (novo — depende de todos acima)
```

`DashboardService` deve ser inicializado POR ÚLTIMO pois depende de todos os outros.

### PASSO 4 — Verificar construtores dos controllers

Confirmar que cada controller já aceita o service por injeção.
Se algum não aceitar, adicionar o parâmetro opcional:

```dart
// Padrão esperado em cada controller:
class ClienteController extends ChangeNotifier with ControllerMixin {
  ClienteController({ClienteService? clienteService})
      : _service = clienteService ?? ClienteService();
  // ...
}
// O ?? ClienteService() é o fallback para testes — manter.
```

Se o parâmetro não existir, adicionar seguindo o mesmo padrão.

## ARQUIVOS A MODIFICAR

1. `lib/main.dart` — único arquivo com mudanças reais
   - Adicionar 4 variáveis `_shared*` no topo
   - Inicializar os 4 services em `_inicializarServicosCompartilhados()`
   - Passar os services nos 5 `ChangeNotifierProvider` do MultiProvider

2. Verificar (provavelmente não precisam de mudança):
   - `lib/controllers/cliente_controller.dart`
   - `lib/controllers/estoque_controller.dart`
   - `lib/controllers/dashboard_controller.dart`
   - `lib/controllers/servico_controller.dart`
   - `lib/controllers/produto_controller.dart`

## VALIDAÇÃO

```bash
flutter analyze        # deve retornar "No issues found"
flutter test           # deve passar todos os testes
```

Verificar manualmente que não há regressão no comportamento do dashboard,
clientes, estoque, serviços e produtos ao rodar o app em debug.

## NOTAS

- NÃO remover o `??=` pattern — é a proteção de idempotência
- NÃO passar `_sharedSessionManager` diretamente para os controllers —
  isso já é encapsulado dentro do `_sharedFirebaseContext`
- NÃO alterar nenhum outro arquivo além de `lib/main.dart`
  (e controllers se precisar adicionar parâmetro)
- Este é o ÚNICO gap de código restante para produção
