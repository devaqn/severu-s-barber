# 💈 Severus Barber

> **Sistema de gestão profissional para barbearias** — Flutter 3.x · Firebase · SQLite

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-orange?logo=firebase)](https://firebase.google.com)
[![SQLite](https://img.shields.io/badge/SQLite-Offline%20Cache-green?logo=sqlite)](https://www.sqlite.org)
[![Versão](https://img.shields.io/badge/Versão-5.0.0-purple)](#)
[![Última atualização](https://img.shields.io/badge/Atualizado-Abril%202026-brightgreen)](#)
[![License](https://img.shields.io/badge/License-Privado-red)](#)

---

## 📋 Sobre o Projeto

O **Severus Barber** é um app mobile completo para gestão de barbearias multi-usuário. Suporta múltiplos barbeiros com controle de comissões, comandas em tempo real, histórico de clientes, controle financeiro, estoque e agenda — tudo sincronizado com Firebase Firestore e com fallback offline via SQLite local.

- **Versão atual:** 5.0.0+5
- **Schema SQLite:** versão 7 (migrações incrementais, nunca DROP)
- **Plataformas:** Android · Windows (desktop)
- **Última atualização:** 23/04/2026

---

## 🚀 Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| Mobile | Flutter 3.x + Dart 3.x |
| Autenticação | Firebase Auth (email/senha) |
| Banco remoto | Cloud Firestore (multi-tenant por barbearia) |
| Banco local | SQLite via `sqflite` + `sqflite_common_ffi` |
| Estado | Provider (`ChangeNotifier`) |
| UI | Material 3 · Tema escuro e claro · Google Fonts |
| Charts | `fl_chart` |
| Agenda | `table_calendar` |
| Export | PDF (`pdf` + `printing`) · CSV (`csv`) · Excel (`excel`) |
| Compartilhamento | `share_plus` |
| Conectividade | `connectivity_plus` |
| UUIDs | `uuid` |
| Swipe actions | `flutter_slidable` |

---

## ✅ O Que Está Implementado e Funcionando

### 🔐 Autenticação

- [x] Login com email/senha via Firebase Auth
- [x] Recuperação de senha (email de reset)
- [x] Alteração de senha no primeiro login
- [x] Criação de barbeiro **sem deslogar o admin** (Firebase App secundário)
- [x] Detecção de `first_login` com redirecionamento à tela de troca de senha
- [x] Mensagens de erro em pt-BR (email inválido, senha fraca, muitas tentativas, sem internet…)
- [x] Fallback offline com credenciais configuráveis via `--dart-define`
- [x] Roteamento protegido por role (`admin` / `barbeiro`)
- [x] Tela de acesso negado para rotas exclusivas do admin

### 👤 Usuários & Roles

- [x] Role `admin` — acesso total ao sistema
- [x] Role `barbeiro` — acesso restrito às próprias comandas e dados
- [x] `barbearia_id` em todos os documentos (multi-tenant)
- [x] Listagem, edição e inativação de barbeiros (admin)
- [x] Comissão percentual por barbeiro (padrão 50%)
- [x] Cadastro de admin público apenas quando não existe nenhum no sistema

### 📋 Comandas

- [x] Abrir comanda com/sem cliente vinculado (cliente avulso disponível)
- [x] Adicionar serviços e produtos com cálculo automático de comissão
- [x] Remover itens antes do fechamento
- [x] Fechar comanda com forma de pagamento (Dinheiro, PIX, Crédito, Débito)
- [x] Cancelamento de comanda aberta
- [x] Bloqueio de edição em comanda fechada/cancelada
- [x] Registro automático de comissão na tabela `comissoes` ao fechar
- [x] Baixa de estoque de produtos ao fechar comanda
- [x] Atualização de `total_atendimentos` e `total_gasto` do cliente ao fechar
- [x] Sincronização Firestore → SQLite (write-through + pendentes)
- [x] Barbeiro vê apenas suas próprias comandas; admin vê todas
- [x] Faturamento e comissão por barbeiro e por período

### 👥 Clientes

- [x] Cadastro, edição e exclusão de clientes
- [x] Campo `data_nascimento` com parse seguro
- [x] Histórico de atendimentos e total gasto
- [x] `pontos_fidelidade` e `total_atendimentos` atualizados automaticamente
- [x] Filtro por `barbearia_id`
- [x] Sincronização Firestore ↔ SQLite

### 📦 Produtos & Estoque

- [x] Cadastro completo (preço de venda, custo, quantidade, estoque mínimo)
- [x] Comissão percentual por produto (padrão 20%)
- [x] Baixa de estoque automática ao fechar comanda ou registrar atendimento
- [x] Movimentações registradas em `movimentos_estoque`
- [x] Alerta visual de estoque mínimo
- [x] Custo médio ponderado atualizado nas entradas de estoque
- [x] Ranking de mais vendidos unificando vendas de comandas e atendimentos
- [x] Sincronização Firestore ↔ SQLite

### ✂️ Serviços

- [x] CRUD completo de serviços
- [x] Comissão padrão de 50%
- [x] Duração em minutos
- [x] Ativo/inativo
- [x] Dados padrão pré-populados no primeiro acesso (Corte, Barba, Corte+Barba, Sobrancelha…)

### 💰 Financeiro

- [x] Resumo: faturamento, despesas e lucro por período
- [x] Faturamento por forma de pagamento
- [x] Despesas categorizadas — CRUD completo
- [x] Abertura e fechamento de caixa com resumo de pagamentos
- [x] Sangria (retirada) e Reforço (adição) de caixa
- [x] Histórico de caixas
- [x] Simulação de mudança de preço com impacto projetado no faturamento
- [x] Gráficos de faturamento por dia (`fl_chart`)
- [x] Sincronização Firestore ↔ SQLite
- [x] Acesso restrito a admin

### 📅 Agenda

- [x] Agendamentos com `table_calendar`
- [x] Vinculação a cliente, serviço e barbeiro
- [x] Status: Pendente, Confirmado, Cancelado, Concluído
- [x] Campo `faturamento_registrado` para controle de agendamento já faturado
- [x] Sincronização Firestore ↔ SQLite

### 🏆 Ranking & Analytics

- [x] Ranking de barbeiros por faturamento (com comissão e total de comandas)
- [x] Dashboard com métricas do dia, semana e mês
- [x] Analytics com gráficos interativos (acesso admin)

### 📊 Relatórios

- [x] Exportação PDF (`pdf` + `printing`)
- [x] Exportação CSV (`csv`)
- [x] Exportação Excel (`excel`)
- [x] Compartilhamento via `share_plus`

### 🗄️ Banco de Dados (SQLite)

- [x] Schema versão 7 com migrações incrementais (`ALTER TABLE`, nunca `DROP`)
- [x] `ConflictAlgorithm.replace` (UPSERT) em todos os inserts
- [x] `CREATE TABLE IF NOT EXISTS` em todas as tabelas
- [x] Foreign keys ativadas (`PRAGMA foreign_keys = ON`)
- [x] Índices de performance em todas as tabelas críticas
- [x] `onUpgrade` com guards `if (oldVersion < N)` para cada versão

### 🔒 Segurança

- [x] `SecurityUtils` — sanitização de todos os inputs (nome, email, telefone, texto livre, UUIDs)
- [x] Senhas fortes obrigatórias
- [x] `firestore.rules` presente no repositório
- [x] Nenhum dado sensível em logs de produção
- [x] `created_by` e `barbearia_id` em todos os documentos Firestore

### 🌐 Conectividade & Offline

- [x] Detecção de online/offline via `connectivity_plus`
- [x] Writes: online → Firestore + SQLite / offline → apenas SQLite
- [x] Sync pendente ao voltar online (push de registros locais sem `firebase_id`)
- [x] Firebase inicializado com fallback gracioso se credenciais não configuradas

### 🎨 UI & Tema

- [x] Tema escuro (padrão) e claro com troca em runtime pelo drawer
- [x] Material 3 com paleta dourada da marca
- [x] Tema claro com Switch, Checkbox, Radio, Dialog, ListTile, SegmentedButton, SnackBar e FAB configurados corretamente
- [x] Foto de perfil no drawer (câmera ou galeria)

---

## ⚠️ Pendências & Riscos Residuais

| # | Item | Severidade | Detalhe |
|---|---|---|---|
| 1 | APK release — teste em dispositivo físico | 🟠 | Não validado em Android real após última build |
| 2 | Regras Firestore e índices compostos | 🟠 | Publicação manual necessária (ver `FIREBASE_SETUP.md`) |
| 3 | Multi-dispositivo simultâneo | 🟡 | Race condition teórico na sync offline→online |
| 4 | Atendimentos legados excluídos do total do caixa | 🟡 | `fecharCaixa` só soma comandas; atendimentos diretos não entram |
| 5 | Overflow em devices muito pequenos (<320 px) | 🟢 | Baixo impacto |

---

## 🧪 Testes Automatizados

### `backend_simulation_test.dart` — 32+ testes de integração SQLite em 7 grupos

- **Clientes:** cadastro UTF-8, atualização, listagem, histórico automático
- **Agenda:** agendamento com e sem cliente
- **Atendimentos:** registro atômico multi-item, decremento de estoque múltiplo
- **Comandas:** fluxo abrir→adicionar→fechar, `ValidationException` sem itens, `ConflictException` pós-fechamento/cancelamento, faturamento por barbeiro
- **Estoque:** concorrência (apenas 1 venda simultânea bem-sucedida), entrada com custo médio, saída acima do saldo
- **Financeiro — Despesas:** CRUD completo + `getResumo`
- **Financeiro — Caixa:** abrir/fechar, segunda abertura bloqueada, sangria cria despesa, reforço atualiza valor inicial

### `widget_test.dart` — 5 testes de widget

Init, drawer admin, drawer barbeiro, rota bloqueada, rota liberada.

### `profile_photo_test.dart`

Seleção, troca, remoção e comportamento offline de foto de perfil.

---

## 🏗️ Build & APK

```bash
# 1. Instalar dependências
flutter pub get

# 2. Análise estática
flutter analyze

# 3. Rodar todos os testes
flutter test

# 4. Gerar APK debug
flutter build apk --debug

# 5. Gerar APK release
flutter build apk --release

# APK em: build/app/outputs/flutter-apk/app-release.apk
```

---

## ⚙️ Colocar em Produção — Passo a Passo

### Pré-requisitos

- Flutter 3.x instalado (`flutter --version`)
- Dart 3.x
- Android SDK com `minSdkVersion 21`
- Conta no Firebase com projeto criado

### 1. Configurar Firebase

1. Acesse [Firebase Console](https://console.firebase.google.com) e crie (ou abra) o projeto
2. Em **Authentication → Sign-in method**, habilite **E-mail/senha**
3. Em **Firestore Database**, crie o banco em modo de produção
4. Em **Configurações do projeto → Android**, registre o app com o package `com.severus.barbearia_pro`
5. Baixe o `google-services.json` gerado e coloque em `android/app/google-services.json`
6. Publique as regras de segurança:

```bash
firebase deploy --only firestore:rules
```

7. Crie os índices compostos no Firestore:
   - Coleção `usuarios` → campos `role` (ASC) + `nome` (ASC)
   - Coleção `comandas` → campos `barbeiro_id` (ASC) + `status` (ASC) + `data_abertura` (DESC)

> 📝 Detalhes completos em **`FIREBASE_SETUP.md`**

### 2. Configurar assinatura do APK

```bash
# Gerar keystore (faça uma vez e guarde em local seguro — NUNCA no git)
keytool -genkey -v -keystore android/app/keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias severus_key

# Copiar e preencher android/key.properties
cp android/key.properties.example android/key.properties
# Edite android/key.properties com os dados do keystore
```

### 3. Gerar o APK de release

```bash
bash build_release.sh
```

Ou manualmente:

```bash
flutter build apk --release
```

### 4. Primeiro acesso ao sistema

Na **primeira execução** com o Firebase configurado, a tela de cadastro do admin aparece automaticamente — o sistema detecta que não há nenhum admin no Firestore. Crie o administrador com e-mail e senha forte.

A partir daí, o admin pode criar barbeiros pela tela **Adicionar Barbeiro** no menu lateral.

---

## 🧑‍💻 Desenvolvimento Local

### Modo debug com Firebase

```bash
flutter run
# Requer android/app/google-services.json real
```

### Modo offline (sem Firebase — ideal para dev rápido)

```bash
flutter run \
  --dart-define=ENABLE_OFFLINE_LOGIN=true \
  --dart-define=OFFLINE_ADMIN_EMAIL=admin@offline.local \
  --dart-define=OFFLINE_ADMIN_PASSWORD=SenhaForte@123
```

### Atalho de conta de teste Firebase (somente debug/QA)

```bash
flutter run \
  --dart-define=ENABLE_FIREBASE_TEST_SHORTCUT=true \
  --dart-define=FIREBASE_TEST_ADMIN_NAME="Admin Teste" \
  --dart-define=FIREBASE_TEST_ADMIN_EMAIL=teste@severus.app \
  --dart-define=FIREBASE_TEST_ADMIN_PASSWORD=Teste@123!
```

> ⚠️ Esses `--dart-define` de teste são bloqueados em `kReleaseMode` e nunca chegam ao APK de produção.

---

## 📁 Estrutura do Projeto

```
lib/
├── controllers/
│   ├── auth_controller.dart          # Estado de autenticação (ChangeNotifier)
│   ├── agenda_controller.dart
│   ├── atendimento_controller.dart
│   ├── cliente_controller.dart
│   ├── comanda_controller.dart
│   ├── dashboard_controller.dart
│   ├── estoque_controller.dart
│   ├── financeiro_controller.dart
│   ├── produto_controller.dart
│   └── servico_controller.dart
├── database/
│   └── database_helper.dart          # SQLite — schema v7, migrations, CRUD genérico
├── models/
│   ├── agendamento.dart · atendimento.dart · caixa.dart
│   ├── cliente.dart · comanda.dart · despesa.dart
│   ├── fornecedor.dart · item_comanda.dart
│   ├── movimento_estoque.dart · produto.dart
│   ├── servico.dart · usuario.dart
├── services/
│   ├── agenda_service.dart
│   ├── atendimento_service.dart
│   ├── auth_service.dart             # Firebase Auth + Firestore + SQLite fallback
│   ├── cliente_service.dart
│   ├── comanda_service.dart          # CRUD + estoque + comissão + sync
│   ├── connectivity_service.dart
│   ├── dashboard_service.dart
│   ├── financeiro_service.dart       # Despesas + Caixa + Resumo + sync
│   ├── firebase_context_service.dart # Coleções por barbearia_id
│   ├── produto_service.dart
│   ├── profile_photo_service.dart
│   ├── service_exceptions.dart       # NotFoundException, ConflictException…
│   └── servico_service.dart
├── screens/
│   ├── admin/          dashboard_admin · barbeiros · criar_barbeiro
│   ├── agenda/         calendar view
│   ├── analytics/      gráficos e indicadores
│   ├── atendimentos/   histórico + novo atendimento
│   ├── auth/           login · cadastro · primeiro_login · recuperar_senha
│   ├── barbeiro/       dashboard_barbeiro
│   ├── caixa/          abertura/fechamento
│   ├── clientes/       lista · detalhe · form
│   ├── comanda/        abrir · listar
│   ├── dashboard/      dashboard geral
│   ├── estoque/        movimentações
│   ├── financeiro/     despesas · caixa · resumo
│   ├── produtos/       lista · form
│   ├── ranking/        ranking de barbeiros
│   ├── relatorios/     export PDF/CSV/Excel
│   └── servicos/       lista · form
├── utils/
│   ├── app_routes.dart               # Todas as rotas nomeadas
│   ├── app_theme.dart                # Dark + Light theme (Material 3 completo)
│   ├── constants.dart                # Constantes globais
│   ├── formatters.dart               # Formatadores de moeda, data…
│   └── security_utils.dart           # Sanitização e validação de inputs
├── widgets/
│   ├── app_drawer.dart               # Menu lateral com roles + foto de perfil
│   ├── stat_card.dart
│   └── ui_helpers.dart
├── firebase_options.dart             # Configuração Firebase por plataforma
└── main.dart                         # Entrada do app + rotas + providers
```

---

## ⚠️ Aviso de Segurança

O `android/app/google-services.json` versionado neste repositório contém **zeros/placeholders** de propósito.
Nunca versione credenciais Firebase reais no git.
Em CI/CD, injete o arquivo real via secret ou variável de ambiente segura.

---

## 📝 Licença

Projeto privado — uso exclusivo interno. Todos os direitos reservados.

---

*Severus Barber · v5.0.0 · Flutter 3.x · Firebase Auth · Cloud Firestore · SQLite · Última atualização: 23/04/2026*
