# 💈 Severus Barber

> **Sistema de gestão profissional para barbearias** — Flutter 3.x · Firebase · SQLite

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-orange?logo=firebase)](https://firebase.google.com)
[![SQLite](https://img.shields.io/badge/SQLite-Offline%20Cache-green?logo=sqlite)](https://www.sqlite.org)
[![License](https://img.shields.io/badge/License-Privado-red)](#)

---

## 📋 Sobre o Projeto

O **Severus Barber** é um app mobile completo para gestão de barbearias multi-usuário. Suporta múltiplos barbeiros com controle de comissões, comandas em tempo real, histórico de clientes, controle financeiro, estoque e agenda — tudo sincronizado com Firebase Firestore e com fallback offline via SQLite local.

---

## 🚀 Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| Mobile | Flutter 3.x + Dart 3.x |
| Autenticação | Firebase Auth (email/senha) |
| Banco remoto | Cloud Firestore (multi-tenant por barbearia) |
| Banco local | SQLite via `sqflite` + `sqflite_common_ffi` |
| Estado | Provider (`ChangeNotifier`) |
| UI | Material 3 · Dark theme · Google Fonts |
| Charts | `fl_chart` |
| Agenda | `table_calendar` |
| Export | PDF (`pdf` + `printing`) · CSV · Excel |
| Conectividade | `connectivity_plus` |

---

## ✅ O Que Está Funcionando

### 🔐 Autenticação

- [x] Login com email/senha via Firebase Auth
- [x] Recuperação de senha (email de reset)
- [x] Alteração de senha (com revalidação)
- [x] Criação de barbeiro **sem deslogar o admin** (Firebase App secundário)
- [x] Detecção de `first_login` com redirecionamento à tela de troca de senha
- [x] Mensagens de erro em pt-BR (email inválido, senha fraca, muitas tentativas, sem internet etc.)
- [x] Fallback offline com credenciais configuráveis via `--dart-define`
- [x] Roteamento protegido por role (`admin` / `barbeiro`)
- [x] Tela de acesso negado para rotas exclusivas do admin

### 👤 Usuários & Roles

- [x] Role `admin` — acesso total
- [x] Role `barbeiro` — acesso restrito às próprias comandas e dados
- [x] `barbearia_id` presente em todos os documentos (multi-tenant)
- [x] Listagem e edição de barbeiros (admin)
- [x] Toggle ativo/inativo de barbeiros
- [x] Comissão percentual por barbeiro (padrão 50%)
- [x] Cadastro de admin público apenas quando não existe nenhum no sistema

### 📋 Comandas

- [x] Abrir comanda com/sem cliente vinculado
- [x] Adicionar itens (serviços e produtos) com cálculo automático de comissão
- [x] Remover itens antes do fechamento
- [x] Fechar comanda com forma de pagamento (Dinheiro, Cartão, PIX, etc.)
- [x] Cancelamento de comanda aberta
- [x] Bloqueio de edição em comanda fechada/cancelada
- [x] Registro automático de comissão na tabela `comissoes` ao fechar
- [x] Baixa de estoque de produtos ao fechar comanda
- [x] Atualização de `total_atendimentos` e `total_gasto` do cliente ao fechar
- [x] Sincronização Firestore → SQLite (write-through)
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
- [x] Movimentações de estoque registradas em `movimentos_estoque`
- [x] Alerta visual de estoque mínimo
- [x] Sincronização Firestore ↔ SQLite

### ✂️ Serviços

- [x] CRUD completo de serviços
- [x] Comissão padrão de 50%
- [x] Duração em minutos
- [x] Ativo/inativo
- [x] Dados padrão pre-populados no primeiro acesso (Corte, Barba, Corte+Barba, Sobrancelha, etc.)

### 💰 Financeiro

- [x] Resumo financeiro: faturamento, despesas e lucro por período
- [x] Faturamento por forma de pagamento
- [x] Despesas categorizadas (CRUD completo)
- [x] Abertura e fechamento de caixa com resumo de pagamentos
- [x] Histórico de caixas
- [x] Simulação de mudança de preço com impacto projetado no faturamento
- [x] Gráficos de faturamento por dia (`fl_chart`)
- [x] Sincronização Firestore ↔ SQLite
- [x] Acesso restrito a admin

### 📅 Agenda

- [x] Agendamentos com `table_calendar`
- [x] Vinculação a cliente, serviço e barbeiro
- [x] Status: Pendente, Confirmado, Cancelado, Concluído
- [x] Sincronização Firestore ↔ SQLite

### 🏆 Ranking & Analytics

- [x] Ranking de barbeiros por faturamento (com comissão e total de comandas)
- [x] Tela de analytics (acesso admin)

### 📊 Relatórios

- [x] Exportação PDF (`pdf` + `printing`)
- [x] Exportação CSV (`csv`)
- [x] Exportação Excel (`excel`)
- [x] Compartilhamento via `share_plus`

### 🗄️ Banco de Dados (SQLite)

- [x] Schema versão 4 com migrações incrementais (`ALTER TABLE`, nunca `DROP`)
- [x] Colunas adicionadas: `comissao_percentual`, `data_nascimento`, `first_login`, `barbearia_id`, `barbeiro_uid`
- [x] `ConflictAlgorithm.replace` (UPSERT) em todos os inserts
- [x] `CREATE TABLE IF NOT EXISTS` em todas as tabelas
- [x] Foreign keys ativadas (`PRAGMA foreign_keys = ON`)
- [x] Índices de performance em todas as tabelas críticas
- [x] `onUpgrade` implementado corretamente com guards `if (oldVersion < N)`

### 🔒 Segurança

- [x] `SecurityUtils` — sanitização de todos os inputs (nome, email, telefone, texto livre, UUIDs)
- [x] Senhas fortes obrigatórias
- [x] `firestore.rules` presente no repositório
- [x] Nenhum dado sensível em logs de produção

### 🌐 Conectividade

- [x] Detecção de online/offline via `connectivity_plus`
- [x] Todas as operações de escrita: online → Firestore + SQLite / offline → apenas SQLite
- [x] Sync pendente ao voltar online (push de registros locais sem `firebase_id`)

---

## ⚠️ O Que Está Implementado mas Precisa de Atenção

## ⚠️ O Que Está Implementado mas Precisa de Atenção

### 🧪 Testes

- [x] `backend_simulation_test.dart` — **32+ testes de integração SQLite** em 7 grupos:
  - **Clientes**: cadastro UTF-8, atualização, listagem, histórico automático
  - **Agenda**: agendamento com e sem cliente
  - **Atendimentos**: registro atômico multi-item, decremento de estoque múltiplo
  - **Comandas**: fluxo completo abrir→adicionar→fechar, ValidationException sem itens, ConflictException pós-fechamento/cancelamento, faturamento por barbeiro
  - **Estoque**: concorrência (apenas 1 venda simultânea bem-sucedida), entrada com custo médio, saída acima do saldo
  - **Financeiro — Despesas**: CRUD completo + getResumo (faturamento - despesas = lucro)
  - **Financeiro — Caixa**: abrir/fechar, segunda abertura bloqueada, sangria cria despesa, reforço atualiza valor inicial
  - **Modelos**: serialização `toMap/fromMap` de `Caixa` e `Despesa`
- [x] `widget_test.dart` — 5 testes de widget (init, drawer admin, drawer barbeiro, rota bloqueada, rota liberada)

### 🏗️ Build & APK

- [ ] Histórico de falha na geração do APK relacionada a Gradle — requer execução manual de `flutter build apk --release` para verificação final
- [ ] `google-services.json` deve estar presente em `android/app/` (não versionado por segurança — ver [FIREBASE_SETUP.md](FIREBASE_SETUP.md))

---

## ❌ Pendências Menores (sem impacto em funcionalidade)

| # | Item | Severidade | Status |
|---|---|---|---|
| 1 | APK de release — requer verificação manual | 🔴 | Aguardando build |
| 2 | Regras Firestore e índices compostos — publicação manual necessária | 🟠 | Documentado em FIREBASE_SETUP.md |
| 3 | Multi-dispositivo simultâneo — não testado em ambiente Android real | 🟢 | Baixo impacto |
| 4 | Overflow em devices muito pequenos (<320px) — não validado | 🟢 | Baixo impacto |

> ✅ Todos os bugs de severidade CRÍTICO, ALTO e MÉDIO foram **resolvidos nesta versão**.


---

## 📁 Estrutura do Projeto

```
lib/
├── controllers/
│   ├── auth_controller.dart        # Estado de autenticação (ChangeNotifier)
│   ├── cliente_controller.dart     # Estado de clientes
│   ├── atendimento_controller.dart # Estado de atendimentos
│   └── estoque_controller.dart     # Estado de estoque
├── database/
│   └── database_helper.dart        # SQLite — schema v4, migrations, CRUD genérico
├── models/
│   ├── usuario.dart                # toMap/fromMap/fromFirestore + copyWith
│   ├── cliente.dart                # dataNascimento parse seguro
│   ├── comanda.dart                # barbeiro_uid + barbearia_id
│   ├── item_comanda.dart           # comissaoValor calculado
│   ├── servico.dart                # comissão default 50%
│   ├── produto.dart                # estoque + comissão
│   ├── atendimento.dart            # barbeiro_uid
│   ├── agendamento.dart            # DateTime
│   ├── despesa.dart                # categorias validadas
│   └── caixa.dart                  # status aberto/fechado
├── services/
│   ├── auth_service.dart           # Firebase Auth + Firestore + SQLite fallback
│   ├── cliente_service.dart        # Stream realtime + aniversariantes
│   ├── comanda_service.dart        # CRUD + estoque + comissão + sync
│   ├── financeiro_service.dart     # Despesas + Caixa + Resumo + sync
│   ├── produto_service.dart        # CRUD + movimentos de estoque
│   ├── servico_service.dart        # CRUD de serviços
│   ├── agenda_service.dart         # Agendamentos + sync
│   ├── atendimento_service.dart    # Registro atômico
│   ├── dashboard_service.dart      # Métricas para dashboard
│   ├── connectivity_service.dart   # Online/offline detection
│   ├── firebase_context_service.dart # Coleções por barbearia_id
│   └── service_exceptions.dart     # NotFoundException, ConflictException, etc.
├── screens/
│   ├── auth/           login, cadastro, primeiro_login, recuperar_senha
│   ├── admin/          dashboard_admin, barbeiros
│   ├── barbeiro/       dashboard_barbeiro
│   ├── clientes/       lista + histórico
│   ├── comanda/        abrir + listar
│   ├── financeiro/     financeiro (despesas, caixa, resumo)
│   ├── produtos/       lista + form
│   ├── servicos/       lista + form
│   ├── agenda/         calendar view
│   ├── estoque/        movimentações
│   ├── caixa/          abertura/fechamento
│   ├── ranking/        ranking de barbeiros
│   ├── analytics/      gráficos e indicadores
│   ├── relatorios/     export PDF/CSV/Excel
│   └── atendimentos/   histórico
├── utils/
│   ├── app_theme.dart              # Dark theme + Light theme
│   ├── constants.dart              # Constantes globais (tabelas, roles, status)
│   └── security_utils.dart         # Sanitização e validação de inputs
├── widgets/                        # Widgets reutilizáveis
├── firebase_options.dart           # Configuração Firebase por plataforma
└── main.dart                       # Entrada do app + rotas + providers
```

---

## ⚙️ Configuração & Build

### Pré-requisitos

- Flutter 3.x (`flutter --version`)
- Dart 3.x
- Android SDK com `minSdkVersion 21`
- Firebase project com Auth (email/senha) e Firestore habilitados
- `google-services.json` em `android/app/`

### Instalação

```bash
flutter clean
flutter pub get
flutter analyze
```

### Rodar em modo debug

```bash
flutter run
```

### Gerar APK de release

```bash
flutter build apk --release
```

### Modo offline (dev/QA)

```bash
flutter run \
  --dart-define=OFFLINE_ADMIN_EMAIL=admin@offline.test \
  --dart-define=OFFLINE_ADMIN_PASSWORD=senha123
```

---

## 🔥 Configuração Firebase

1. Crie um projeto no [Firebase Console](https://console.firebase.google.com)
2. Habilite **Authentication → Email/Password**
3. Habilite **Cloud Firestore**
4. Baixe o `google-services.json` e coloque em `android/app/`
5. Publique as regras de segurança:
   ```bash
   firebase deploy --only firestore:rules
   ```
6. Crie os índices compostos necessários para as queries:
   - `usuarios` → `role` + `nome`
   - `comandas` → `barbeiro_id` + `status` + `data_abertura`

---

## 🧪 Rodando os Testes

```bash
flutter test
```

> ⚠️ Os testes de integração SQLite rodam offline sem necessidade de Firebase.

---

## 📝 Licença

Projeto privado — uso exclusivo interno. Todos os direitos reservados.

---

*Severus Barber · v2.0.0 · Stack: Flutter 3.x · Firebase Auth · Cloud Firestore · SQLite*
