# 💈 Severus Barber

> **Sistema de gestão profissional para barbearias** — Flutter 3.x · Firebase · SQLite

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-orange?logo=firebase)](https://firebase.google.com)
[![SQLite](https://img.shields.io/badge/SQLite-v7-green?logo=sqlite)](https://www.sqlite.org)
[![Testes](https://img.shields.io/badge/Testes-115%20passando-brightgreen)](#-testes-automatizados)
[![Versão](https://img.shields.io/badge/Versão-5.0.0-purple)](#)
[![Última atualização](https://img.shields.io/badge/Atualizado-Abril%202026-brightgreen)](#)
[![License](https://img.shields.io/badge/License-Privado-red)](#)

---

## 📋 Sobre o Projeto

O **Severus Barber** é um app mobile e desktop completo para gestão de barbearias multi-usuário. Suporta múltiplos barbeiros com controle de comissões, comandas em tempo real, histórico de clientes, controle financeiro, estoque e agenda — tudo sincronizado com Firebase Firestore e com fallback offline via SQLite local.

- **Versão:** 5.0.0+5
- **Schema SQLite:** versão 7 (migrações incrementais, nunca DROP)
- **Plataformas:** Android · Windows (desktop)
- **Testes automatizados:** 115 passando (integração + unit + widget)
- **Última atualização:** 26/04/2026

---

## 🚀 Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| Framework | Flutter 3.x + Dart 3.x (SDK `>=3.2.0`) |
| Autenticação | Firebase Auth (email/senha) |
| Banco remoto | Cloud Firestore (multi-tenant por `barbearia_id`) |
| Banco local | SQLite via `sqflite` + `sqflite_common_ffi` (desktop) |
| Estado | Provider 6.x (`ChangeNotifier` + `ControllerMixin`) |
| UI | Material 3 · Tema escuro/claro · Google Fonts · Poppins/Inter |
| Charts | `fl_chart` |
| Agenda | `table_calendar` |
| Export | PDF (`pdf` + `printing`) · CSV · Excel (`excel`) |
| Compartilhamento | `share_plus` |
| Conectividade | `connectivity_plus` |
| UUIDs | `uuid` |
| Swipe actions | `flutter_slidable` |

---

## 🏗️ Arquitetura

```
Screens  →  Controllers (ChangeNotifier + ControllerMixin)
                   ↓
              Services (lógica de negócio + sanitização)
                   ↓
         DatabaseHelper (SQLite)  ↔  Cloud Firestore
```

- **Controllers** são finos (30–90 linhas) — apenas delegam para Services e gerenciam estado `isLoading` / `errorMsg`
- **Services** contêm toda a lógica de negócio, validação e sincronização
- **DatabaseHelper** expõe CRUD genérico com transações, foreign keys e migrations
- **Sync** é write-through: online → grava em Firestore + SQLite; offline → apenas SQLite, sincroniza ao reconectar
- **SecurityUtils** sanitiza todos os inputs antes de atingir qualquer camada de dados

---

## ✅ Funcionalidades Implementadas

### 🔐 Autenticação e Segurança

- [x] Login com email/senha via Firebase Auth
- [x] Recuperação de senha (email de reset)
- [x] Alteração de senha obrigatória no primeiro login do barbeiro
- [x] Criação de barbeiro **sem deslogar o admin** (Firebase App secundário efêmero)
- [x] Revogação de acesso de barbeiro com flag `revoked` — impede login mesmo com credenciais Firebase válidas
- [x] `SecurityUtils` — sanitização centralizada de todos os inputs (nome, e-mail, telefone, texto livre, enums, UUIDs)
- [x] Senhas fortes obrigatórias (8+ chars, maiúscula, minúscula, número, símbolo)
- [x] Mensagens de erro em pt-BR (e-mail inválido, senha fraca, muitas tentativas, sem internet…)
- [x] Roteamento protegido por role (`admin` / `barbeiro`) com `ProtectedRoute`
- [x] Tela de acesso negado para rotas exclusivas do admin
- [x] Fallback offline com credenciais configuráveis via `--dart-define` (bloqueado em release)
- [x] Todos os atalhos de teste bloqueados em `kReleaseMode`

### 👤 Usuários e Perfis

- [x] Role `admin` — acesso total ao sistema
- [x] Role `barbeiro` — acesso restrito às próprias comandas e dados
- [x] `barbearia_id` em todos os documentos (multi-tenant isolado)
- [x] Listagem, edição e inativação de barbeiros (admin)
- [x] Comissão percentual por barbeiro (padrão 50%)
- [x] Foto de perfil via câmera ou galeria
- [x] Cadastro de admin público apenas quando não há nenhum admin no sistema (bootstrap seguro)

### 📋 Comandas

- [x] Abrir comanda com ou sem cliente vinculado (cliente avulso disponível)
- [x] Adicionar serviços e produtos com cálculo automático de comissão por item
- [x] Remover itens antes do fechamento (com recálculo atômico via transação SQLite)
- [x] Fechar comanda com seleção de forma de pagamento (Dinheiro, PIX, Crédito, Débito)
- [x] Cancelamento de comanda aberta
- [x] Optimistic locking no fechamento (`AND status = 'aberta'`) — impede duplo fechamento
- [x] Bloqueio de edição em comanda fechada ou cancelada
- [x] Registro automático de comissão na tabela `comissoes` ao fechar
- [x] Baixa de estoque de produtos ao fechar comanda (dentro da mesma transação)
- [x] Atualização de `total_atendimentos`, `total_gasto` e `pontos_fidelidade` do cliente ao fechar
- [x] Sincronização Firestore → SQLite com cursor paginado (`startAfterDocument`, lotes de 20)
- [x] Barbeiro vê apenas suas próprias comandas; admin vê todas

### 👥 Clientes

- [x] Cadastro, edição e exclusão de clientes
- [x] Busca por nome ou telefone
- [x] Histórico de atendimentos e total gasto
- [x] Pontos de fidelidade e total de atendimentos atualizados automaticamente ao fechar comanda
- [x] Detecção de "clientes sumidos" — SQL único com `GROUP BY/HAVING/julianday` (sem N+1)
- [x] Stream Firestore → upsert SQLite em tempo real
- [x] Aniversariantes do dia
- [x] Ranking de melhores clientes por total gasto

### 📦 Produtos e Estoque

- [x] CRUD completo (preço de venda, custo, quantidade, estoque mínimo)
- [x] Comissão percentual por produto
- [x] Baixa de estoque automática ao fechar comanda
- [x] Entrada de estoque com cálculo de custo médio ponderado
- [x] Movimentações registradas em `movimentos_estoque`
- [x] Alerta visual de estoque abaixo do mínimo
- [x] Ranking de mais vendidos — une vendas de comandas e atendimentos legados (UNION ALL)
- [x] Sugestões de reposição com média móvel de 30 dias
- [x] Sincronização Firestore ↔ SQLite

### ✂️ Serviços

- [x] CRUD completo de serviços com duração em minutos
- [x] Comissão percentual configurável por serviço (padrão 50%)
- [x] Soft delete (ativo/inativo)
- [x] Ranking dos mais realizados — une `atendimento_itens` e `comandas_itens` (UNION ALL)
- [x] Dados padrão pré-populados no primeiro acesso (Corte, Barba, Corte+Barba, Sobrancelha…)

### 💰 Financeiro e Caixa

- [x] Resumo financeiro: faturamento, despesas e lucro por período
- [x] Faturamento por forma de pagamento
- [x] Despesas categorizadas — CRUD completo (Aluguel, Produtos, Energia Elétrica, Salários…)
- [x] Abertura e fechamento de caixa com resumo automático de pagamentos
- [x] Sangria (retirada) com validação de saldo disponível — impede saldo negativo
- [x] Reforço (adição) de caixa
- [x] Histórico de caixas com paginação
- [x] Simulação de mudança de preço com impacto projetado no faturamento
- [x] Gráficos de faturamento por dia (`fl_chart`)
- [x] Acesso restrito a admin

### 📅 Agenda

- [x] Calendário visual com `table_calendar`
- [x] Agendamentos vinculados a cliente, serviço e barbeiro
- [x] Detecção de conflito de horário por barbeiro (`_verificarConflito` com overlap exato)
- [x] Status: Pendente, Confirmado, Cancelado, Concluído
- [x] Ao marcar como Concluído, abre e fecha comanda automaticamente — com seleção da forma de pagamento pelo barbeiro
- [x] Campo `faturamento_registrado` evita duplo faturamento
- [x] Sincronização Firestore ↔ SQLite

### 🏆 Dashboard e Analytics

- [x] Dashboard com KPIs do dia, semana e mês (admin)
- [x] Ranking de barbeiros por faturamento e comissão
- [x] Alertas de aniversariantes
- [x] Gráficos interativos de receita e despesas
- [x] Dashboard simplificado para barbeiro (apenas seus dados)

### 📊 Relatórios e Export

- [x] Exportação PDF (`pdf` + `printing`)
- [x] Exportação CSV
- [x] Exportação Excel (`.xlsx`)
- [x] Compartilhamento via `share_plus`

### 🌐 Offline e Sincronização

- [x] Detecção de conectividade via `connectivity_plus`
- [x] Writes: online → Firestore + SQLite / offline → apenas SQLite
- [x] Sync pendente ao voltar online (push de registros locais sem `firebase_id`)
- [x] Cursor de sync Firestore com `startAfterDocument` (lotes de 20 documentos)
- [x] `FirebaseErrorHandler.wrapSilent` — falha no sync nunca derruba o app
- [x] Firebase inicializado com fallback gracioso se credenciais não configuradas
- [x] Detecção de credenciais placeholder (`0+` patterns)

### 🗄️ Banco de Dados

- [x] 14 tabelas com schema versão 7
- [x] Migrações incrementais via `ALTER TABLE` — nunca DROP TABLE
- [x] `_addColumnIfMissing()` garante idempotência nas migrations
- [x] `PRAGMA foreign_keys = ON` em toda conexão
- [x] 20+ índices incluindo compostos e UNIQUE parciais (`WHERE firebase_id IS NOT NULL`)
- [x] Transações SQLite em todas as operações multi-step críticas
- [x] Suporte a desktop via `sqflite_common_ffi`

### 🔒 Regras Firestore

- [x] Isolamento multi-tenant: toda coleção sob `/barbearias/{shopId}/`
- [x] `isInShop()` valida autenticação + existência do perfil + `revoked != true`
- [x] Barbeiros não podem modificar `total_gasto`, `pontos_fidelidade`, `total_atendimentos` de clientes
- [x] Barbeiros não podem modificar `preco_venda`, `preco_custo`, `estoque_minimo` de produtos
- [x] Despesas e caixas: somente admin
- [x] Comandas: update apenas por admin ou barbeiro dono da comanda
- [x] Bootstrap seguro: primeiro admin criado via `isBootstrapAdmin` com path `shop_{uid}`

---

## ⚠️ Pendências e Riscos Residuais

| # | Item | Severidade | Detalhe |
|---|---|---|---|
| 1 | Histórico git com chave Firebase exposta | 🔴 | Arquivo removido do tracking (Tarefa 1). Chave deve ser rotada no Firebase Console e histórico purgado com git filter-repo manualmente |
| 2 | Publicação manual das regras Firestore | 🟠 | Use `make deploy-rules` ou `make deploy-all` após qualquer alteração em `firestore.rules` |
| 3 | APK não validado em dispositivo físico | 🟡 | Validar com `docs/QA_DEVICE_CHECKLIST.md` |
| 4 | `_offlineLoginEnabled` ativo em builds `--profile` | 🟢 | Resolvido — guard alterado para `kDebugMode` |
| 5 | Overflow em devices < 320 px | 🟢 | Mitigação aplicada nos Rows prioritários de dashboard e caixa; manter validação visual em QA |

---

## 🧪 Testes Automatizados

**115 testes passando** · `flutter test` → `All tests passed!`

| Arquivo | Tipo | O que cobre |
|---|---|---|
| `backend_simulation_test.dart` | Integração SQLite | Clientes, Agenda, Atendimentos, Comandas, Estoque, Financeiro, Caixa, Comissões — 7 grupos, banco real via `sqflite_ffi` |
| `services/comissao_calculo_test.dart` | Unit | Cálculo de comissão e getters computados de `ItemComanda` |
| `services/firebase_error_handler_test.dart` | Unit | `FirebaseErrorHandler.wrap()` e `wrapSilent()` |
| `services/sync_pagination_test.dart` | Unit | Constante `kSyncBatchSize` |
| `controllers/auth_controller_test.dart` | Unit | Login, logout e transições de estado com `AuthService` fake |
| `controllers/cliente_controller_test.dart` | Unit | Controller de clientes com service fake |
| `models/comanda_test.dart` | Unit | Serialização e `copyWith` de `Comanda` |
| `models/usuario_test.dart` | Unit | Modelo `Usuario` e getters de role |
| `models/usuario_comissao_test.dart` | Unit | Conversão de escala de comissão (0..1 ↔ 0..100) |
| `profile_photo_test.dart` | Unit | Seleção, troca, remoção e comportamento offline de foto de perfil |
| `widget_test.dart` | Widget | Splash, drawer admin, drawer barbeiro, rota bloqueada, rota liberada |

```bash
# Rodar todos os testes
flutter test

# Rodar com cobertura
flutter test --coverage
```

---

## 📁 Estrutura do Projeto

```
lib/
├── controllers/
│   ├── auth_controller.dart          # Estado de autenticação (ChangeNotifier)
│   ├── controller_mixin.dart         # runSilent / runCatch / runOrThrow — padrão comum
│   ├── agenda_controller.dart
│   ├── atendimento_controller.dart
│   ├── cliente_controller.dart       # StreamSubscription Firestore em tempo real
│   ├── comanda_controller.dart
│   ├── dashboard_controller.dart
│   ├── estoque_controller.dart
│   ├── financeiro_controller.dart
│   ├── produto_controller.dart
│   └── servico_controller.dart
│
├── database/
│   └── database_helper.dart          # SQLite singleton — schema v7, 14 tabelas, migrations
│
├── models/
│   ├── agendamento.dart
│   ├── atendimento.dart              # Modelo legado (histórico pré-comanda)
│   ├── caixa.dart
│   ├── cliente.dart
│   ├── comanda.dart
│   ├── despesa.dart
│   ├── fornecedor.dart
│   ├── item_comanda.dart             # subtotal / comissaoValor / lucroCasa computados
│   ├── movimento_estoque.dart
│   ├── produto.dart
│   ├── servico.dart
│   └── usuario.dart                  # UserRole enum + comissaoDecimal getter
│
├── services/
│   ├── agenda_service.dart           # CRUD + conflict detection + auto-faturamento
│   ├── atendimento_service.dart
│   ├── auth_service.dart             # Firebase Auth + Firestore + SQLite fallback
│   ├── cliente_service.dart          # CRUD + stream + getClientesSumidos (SQL único)
│   ├── comanda_service.dart          # CRUD + estoque + comissão + sync cursor
│   ├── connectivity_service.dart
│   ├── dashboard_service.dart
│   ├── financeiro_service.dart       # Despesas + Caixa + sangria + sync
│   ├── firebase_context_service.dart # Coleções por barbearia_id + cache shopId
│   ├── firebase_error_handler.dart   # wrap() / wrapSilent()
│   ├── produto_service.dart          # CRUD + custo médio ponderado + sugestões
│   ├── profile_photo_service.dart
│   ├── service_exceptions.dart       # ValidationException, NotFoundException, ConflictException…
│   └── servico_service.dart
│
├── screens/
│   ├── admin/          # Dashboard admin · Barbeiros · Criar barbeiro
│   ├── agenda/         # Calendário + gestão de agendamentos
│   ├── analytics/      # Gráficos e indicadores (admin)
│   ├── atendimentos/   # Histórico e novo atendimento legado
│   ├── auth/           # Login · Cadastro · Primeiro login · Recuperar senha
│   ├── barbeiro/       # Dashboard barbeiro
│   ├── caixa/          # Abertura · Fechamento · Sangria · Reforço
│   ├── clientes/       # Lista · Detalhe · Formulário
│   ├── comanda/        # Abrir · Listar · Fechar
│   ├── dashboard/      # Dashboard geral
│   ├── estoque/        # Movimentações de estoque
│   ├── financeiro/     # Despesas · Caixa · Resumo financeiro
│   ├── produtos/       # Lista · Formulário
│   ├── ranking/        # Ranking de barbeiros
│   ├── relatorios/     # Export PDF / CSV / Excel
│   └── servicos/       # Lista · Formulário
│
├── utils/
│   ├── app_routes.dart               # Todas as rotas nomeadas como constantes
│   ├── app_theme.dart                # Dark + Light theme completo (Material 3)
│   ├── constants.dart                # Magic strings centralizadas (tabelas, status, pagamentos)
│   ├── formatters.dart               # Moeda, data, duração
│   └── security_utils.dart           # Sanitização: nome, e-mail, telefone, enums, ranges
│
├── widgets/
│   ├── app_drawer.dart               # Menu lateral com roles + foto de perfil
│   ├── stat_card.dart
│   └── ui_helpers.dart
│
├── firebase_options.dart             # Credenciais via String.fromEnvironment() — seguro no git
└── main.dart                         # App entry · MultiProvider · Rotas · AuthWrapper
```

---

## ⚙️ Configuração e Deploy

### Pré-requisitos

- Flutter 3.x instalado (`flutter --version`)
- Dart SDK `>=3.2.0`
- Android SDK (`minSdkVersion 21`)
- Conta no Firebase com projeto criado

### 1. Instalar dependências

```bash
flutter pub get
```

### 2. Configurar Firebase

1. Acesse o [Firebase Console](https://console.firebase.google.com) e abra (ou crie) o projeto
2. Em **Authentication → Sign-in method**, habilite **E-mail/senha**
3. Em **Firestore Database**, crie o banco em **modo de produção**
4. Em **Configurações do projeto → Android**, registre o package `com.severus.barbearia_pro`
5. Baixe o `google-services.json` gerado e coloque em `android/app/google-services.json`

> ⚠️ **Nunca versione o `google-services.json` no git.** O `.gitignore` já exclui o arquivo. Em CI/CD, injete via secret ou variável de ambiente.

6. Publique as regras de segurança do Firestore:

```bash
firebase deploy --only firestore:rules
```

7. Crie os índices compostos necessários no Firestore Console:
   - Coleção `usuarios` → `role` (ASC) + `nome` (ASC)
   - Coleção `comandas` → `barbeiro_id` (ASC) + `status` (ASC) + `data_abertura` (DESC)
   - Coleção `agendamentos` → `data_hora` (ASC) + `status` (ASC)

> Detalhes completos em **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)**

### 3. Assinar o APK

```bash
# Gerar keystore (apenas uma vez — armazene em local seguro, NUNCA no git)
keytool -genkey -v -keystore android/app/keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias severus_key

# Configurar credenciais de assinatura
cp android/key.properties.example android/key.properties
# Preencha android/key.properties com os dados do keystore
```

### 4. Gerar o APK de release

```bash
# Script automatizado
bash build_release.sh

# Ou manualmente
flutter build apk --release
# APK gerado em: build/app/outputs/flutter-apk/app-release.apk
```

### 5. Primeiro acesso

Na **primeira execução** com Firebase configurado, a tela de cadastro do admin aparece automaticamente — o sistema detecta que não há nenhum admin no Firestore. Após criar o admin, novos barbeiros são cadastrados pelo menu **Adicionar Barbeiro** no painel admin.

---

## 🤖 Automação

O projeto inclui um `Makefile` para padronizar comandos recorrentes:

```bash
make test
make deploy-rules
make deploy-all
```

- `make test` executa a suíte automatizada (`flutter test`)
- `make deploy-rules` publica `firestore.rules` no Firebase
- `make deploy-all` roda análise, testes, build de release e deploy das regras

O workflow `.github/workflows/ci.yml` executa `flutter analyze` e `flutter test` a cada push ou pull request para `main`.

---

## 🧑‍💻 Desenvolvimento Local

### Modo debug com Firebase real

```bash
flutter run
# Requer android/app/google-services.json válido
```

### Modo offline (sem Firebase — ideal para desenvolvimento rápido)

```bash
flutter run \
  --dart-define=ENABLE_OFFLINE_LOGIN=true \
  --dart-define=OFFLINE_ADMIN_EMAIL=admin@offline.local \
  --dart-define=OFFLINE_ADMIN_PASSWORD=SenhaForte@123
```

### Atalho de conta de teste Firebase (apenas debug/QA)

```bash
flutter run \
  --dart-define=ENABLE_FIREBASE_TEST_SHORTCUT=true \
  --dart-define=FIREBASE_TEST_ADMIN_NAME="Admin Teste" \
  --dart-define=FIREBASE_TEST_ADMIN_EMAIL=teste@severus.app \
  --dart-define=FIREBASE_TEST_ADMIN_PASSWORD=Teste@123!
```

### Exibir botão "Entrar sem login" na tela de login (apenas debug)

```bash
flutter run --dart-define=ENABLE_BYPASS_LOGIN_BUTTON=true
```

> ⚠️ Todos os `--dart-define` de teste e bypass são **bloqueados em `kReleaseMode`** e jamais chegam ao APK de produção.

### Análise estática e testes

```bash
flutter analyze   # deve retornar "No issues found!"
flutter test      # deve retornar "All tests passed!" (115/115)
```

---

## 🗃️ Schema do Banco de Dados (SQLite v7)

| Tabela | Propósito |
|---|---|
| `clientes` | Cadastro de clientes com pontos de fidelidade e total gasto |
| `servicos` | Catálogo de serviços com duração e comissão |
| `fornecedores` | Cadastro de fornecedores de produtos |
| `produtos` | Estoque com preço de venda, custo e custo médio ponderado |
| `atendimentos` | Registros legados (fluxo anterior à comanda) |
| `atendimento_itens` | Itens dos atendimentos legados |
| `agendamentos` | Agenda com detecção de conflito e controle de faturamento |
| `despesas` | Despesas categorizadas por barbearia |
| `movimentos_estoque` | Histórico de entradas e saídas de estoque |
| `caixas` | Controle de caixa diário com resumo de pagamentos em JSON |
| `usuarios` | Perfis (admin/barbeiro) sincronizados com Firebase Auth |
| `comandas` | Comandas abertas/fechadas/canceladas (fluxo atual) |
| `comandas_itens` | Itens de comandas (serviços e produtos) |
| `comissoes` | Ledger de comissões por barbeiro e comanda |

Migrações v1→v7 — cada versão acrescenta colunas via `ALTER TABLE` com `_addColumnIfMissing()`, garantindo idempotência e zero downtime.

---

## 📝 Documentação Adicional

| Arquivo | Conteúdo |
|---|---|
| [FIREBASE_SETUP.md](FIREBASE_SETUP.md) | Configuração completa do Firebase (Auth, Firestore, regras, índices) |
| [docs/GUIA_DESENVOLVIMENTO.md](docs/GUIA_DESENVOLVIMENTO.md) | Guia para novos desenvolvedores |
| [docs/PRODUCAO.md](docs/PRODUCAO.md) | Checklist e procedimentos de deploy em produção |
| [docs/SECURITY_HARDENING.md](docs/SECURITY_HARDENING.md) | Hardening de segurança aplicado |
| [docs/qa_fluxo_completo.md](docs/qa_fluxo_completo.md) | Roteiro de QA manual do fluxo completo |

---

## 📄 Licença

Projeto privado — uso exclusivo interno. Todos os direitos reservados.

---

*Severus Barber · v5.0.0+5 · Flutter 3.x · Firebase Auth · Cloud Firestore · SQLite v7 · 115 testes · Atualizado em 26/04/2026*
