# ðŸ’ˆ Severus Barber

> **Sistema de gestão profissional para barbearias** â€” Flutter 3.x · Firebase · SQLite

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-orange?logo=firebase)](https://firebase.google.com)
[![SQLite](https://img.shields.io/badge/SQLite-Offline%20Cache-green?logo=sqlite)](https://www.sqlite.org)
[![License](https://img.shields.io/badge/License-Privado-red)](#)

---

## ðŸ“‹ Sobre o Projeto

O **Severus Barber** é um app mobile completo para gestão de barbearias multi-usuário. Suporta múltiplos barbeiros com controle de comissões, comandas em tempo real, histórico de clientes, controle financeiro, estoque e agenda â€” tudo sincronizado com Firebase Firestore e com fallback offline via SQLite local.

---

## ðŸš€ Stack Tecnológica

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

## âœ… O Que Está Funcionando

### ðŸ” Autenticação

- [x] Login com email/senha via Firebase Auth
- [x] Recuperação de senha (email de reset)
- [x] Alteração de senha (com revalidação)
- [x] Criação de barbeiro **sem deslogar o admin** (Firebase App secundário)
- [x] Detecção de `first_login` com redirecionamento à tela de troca de senha
- [x] Mensagens de erro em pt-BR (email inválido, senha fraca, muitas tentativas, sem internet etc.)
- [x] Fallback offline com credenciais configuráveis via `--dart-define`
- [x] Roteamento protegido por role (`admin` / `barbeiro`)
- [x] Tela de acesso negado para rotas exclusivas do admin

### ðŸ‘¤ Usuários & Roles

- [x] Role `admin` â€” acesso total
- [x] Role `barbeiro` â€” acesso restrito às próprias comandas e dados
- [x] `barbearia_id` presente em todos os documentos (multi-tenant)
- [x] Listagem e edição de barbeiros (admin)
- [x] Toggle ativo/inativo de barbeiros
- [x] Comissão percentual por barbeiro (padrão 50%)
- [x] Cadastro de admin público apenas quando não existe nenhum no sistema

### ðŸ“‹ Comandas

- [x] Abrir comanda com/sem cliente vinculado
- [x] Adicionar itens (serviços e produtos) com cálculo automático de comissão
- [x] Remover itens antes do fechamento
- [x] Fechar comanda com forma de pagamento (Dinheiro, Cartão, PIX, etc.)
- [x] Cancelamento de comanda aberta
- [x] Bloqueio de edição em comanda fechada/cancelada
- [x] Registro automático de comissão na tabela `comissoes` ao fechar
- [x] Baixa de estoque de produtos ao fechar comanda
- [x] Atualização de `total_atendimentos` e `total_gasto` do cliente ao fechar
- [x] Sincronização Firestore â†’ SQLite (write-through)
- [x] Barbeiro vê apenas suas próprias comandas; admin vê todas
- [x] Faturamento e comissão por barbeiro e por período

### ðŸ‘¥ Clientes

- [x] Cadastro, edição e exclusão de clientes
- [x] Campo `data_nascimento` com parse seguro
- [x] Histórico de atendimentos e total gasto
- [x] `pontos_fidelidade` e `total_atendimentos` atualizados automaticamente
- [x] Filtro por `barbearia_id`
- [x] Sincronização Firestore â†” SQLite

### ðŸ“¦ Produtos & Estoque

- [x] Cadastro completo (preço de venda, custo, quantidade, estoque mínimo)
- [x] Comissão percentual por produto (padrão 20%)
- [x] Baixa de estoque automática ao fechar comanda ou registrar atendimento
- [x] Movimentações de estoque registradas em `movimentos_estoque`
- [x] Alerta visual de estoque mínimo
- [x] Sincronização Firestore â†” SQLite

### âœ‚ï¸ Serviços

- [x] CRUD completo de serviços
- [x] Comissão padrão de 50%
- [x] Duração em minutos
- [x] Ativo/inativo
- [x] Dados padrão pre-populados no primeiro acesso (Corte, Barba, Corte+Barba, Sobrancelha, etc.)

### ðŸ’° Financeiro

- [x] Resumo financeiro: faturamento, despesas e lucro por período
- [x] Faturamento por forma de pagamento
- [x] Despesas categorizadas (CRUD completo)
- [x] Abertura e fechamento de caixa com resumo de pagamentos
- [x] Histórico de caixas
- [x] Simulação de mudança de preço com impacto projetado no faturamento
- [x] Gráficos de faturamento por dia (`fl_chart`)
- [x] Sincronização Firestore â†” SQLite
- [x] Acesso restrito a admin

### ðŸ“… Agenda

- [x] Agendamentos com `table_calendar`
- [x] Vinculação a cliente, serviço e barbeiro
- [x] Status: Pendente, Confirmado, Cancelado, Concluído
- [x] Sincronização Firestore â†” SQLite

### ðŸ† Ranking & Analytics

- [x] Ranking de barbeiros por faturamento (com comissão e total de comandas)
- [x] Tela de analytics (acesso admin)

### ðŸ“Š Relatórios

- [x] Exportação PDF (`pdf` + `printing`)
- [x] Exportação CSV (`csv`)
- [x] Exportação Excel (`excel`)
- [x] Compartilhamento via `share_plus`

### ðŸ—„ï¸ Banco de Dados (SQLite)

- [x] Schema versão 4 com migrações incrementais (`ALTER TABLE`, nunca `DROP`)
- [x] Colunas adicionadas: `comissao_percentual`, `data_nascimento`, `first_login`, `barbearia_id`, `barbeiro_uid`
- [x] `ConflictAlgorithm.replace` (UPSERT) em todos os inserts
- [x] `CREATE TABLE IF NOT EXISTS` em todas as tabelas
- [x] Foreign keys ativadas (`PRAGMA foreign_keys = ON`)
- [x] Índices de performance em todas as tabelas críticas
- [x] `onUpgrade` implementado corretamente com guards `if (oldVersion < N)`

### ðŸ”’ Segurança

- [x] `SecurityUtils` â€” sanitização de todos os inputs (nome, email, telefone, texto livre, UUIDs)
- [x] Senhas fortes obrigatórias
- [x] `firestore.rules` presente no repositório
- [x] Nenhum dado sensível em logs de produção

### ðŸŒ Conectividade

- [x] Detecção de online/offline via `connectivity_plus`
- [x] Todas as operações de escrita: online â†’ Firestore + SQLite / offline â†’ apenas SQLite
- [x] Sync pendente ao voltar online (push de registros locais sem `firebase_id`)

---

## âš ï¸ O Que Está Implementado mas Precisa de Atenção

## âš ï¸ O Que Está Implementado mas Precisa de Atenção

## 🧪 Testes

### Testes automatizados

`backend_simulation_test.dart` — 32+ testes de integração SQLite em 7 grupos:

- **Clientes:** cadastro UTF-8, atualização, listagem, histórico automático
- **Agenda:** agendamento com e sem cliente
- **Atendimentos:** registro atômico multi-item, decremento de estoque múltiplo
- **Comandas:** fluxo completo abrir→adicionar→fechar, `ValidationException` sem itens,
  `ConflictException` pós-fechamento/cancelamento, faturamento por barbeiro
- **Estoque:** concorrência (apenas 1 venda simultânea bem-sucedida), entrada com custo médio,
  saída acima do saldo
- **Financeiro — Despesas:** CRUD completo + `getResumo` (faturamento - despesas = lucro)
- **Financeiro — Caixa:** abrir/fechar, segunda abertura bloqueada, sangria cria despesa,
  reforço atualiza valor inicial
- **Modelos:** serialização `toMap/fromMap` de `Caixa` e `Despesa`

`widget_test.dart` — 5 testes de widget (init, drawer admin, drawer barbeiro,
rota bloqueada, rota liberada)

### Testes de regressão — Foto de perfil

`profile_photo_test.dart` (novo) — cobrindo:

- Seleção de nova foto: URL atualiza em Firestore + SQLite
- Troca de foto: `ImageProvider` invalida cache corretamente (sem cache stale)
- Remoção de foto: URL nula persiste e avatar padrão (iniciais) é exibido
- Comportamento offline: upload pendente sincroniza ao voltar online

## 🏗️ Build & APK

```bash
# 1. Rodar todos os testes
flutter test

# 2. Análise estática — zero warnings tolerados
flutter analyze

# 3. Gerar APK de release
flutter build apk --release

# APK gerado em:
# build/app/outputs/flutter-apk/app-release.apk
```

> `google-services.json` deve estar presente em `android/app/` (não versionado — ver **FIREBASE_SETUP.md**)

---

## �Œ Pendências Menores (sem impacto em funcionalidade)

| # | Item | Severidade | Status |
|---|---|---|---|
| 1 | APK de release â€” requer verificação manual | ðŸ”´ | Aguardando build |
| 2 | Regras Firestore e índices compostos â€” publicação manual necessária | ðŸŸ  | Documentado em FIREBASE_SETUP.md |
| 3 | Multi-dispositivo simultâneo â€” não testado em ambiente Android real | ðŸŸ¢ | Baixo impacto |
| 4 | Overflow em devices muito pequenos (<320px) â€” não validado | ðŸŸ¢ | Baixo impacto |

> âœ… Todos os bugs de severidade CRÍTICO, ALTO e MÃ‰DIO foram **resolvidos nesta versão**.


---

## ðŸ“ Estrutura do Projeto

```
lib/
â”œâ”€â”€ controllers/
â”‚   â”œâ”€â”€ auth_controller.dart        # Estado de autenticação (ChangeNotifier)
â”‚   â”œâ”€â”€ cliente_controller.dart     # Estado de clientes
â”‚   â”œâ”€â”€ atendimento_controller.dart # Estado de atendimentos
â”‚   â””â”€â”€ estoque_controller.dart     # Estado de estoque
â”œâ”€â”€ database/
â”‚   â””â”€â”€ database_helper.dart        # SQLite â€” schema v4, migrations, CRUD genérico
â”œâ”€â”€ models/
â”‚   â”œâ”€â”€ usuario.dart                # toMap/fromMap/fromFirestore + copyWith
â”‚   â”œâ”€â”€ cliente.dart                # dataNascimento parse seguro
â”‚   â”œâ”€â”€ comanda.dart                # barbeiro_uid + barbearia_id
â”‚   â”œâ”€â”€ item_comanda.dart           # comissaoValor calculado
â”‚   â”œâ”€â”€ servico.dart                # comissão default 50%
â”‚   â”œâ”€â”€ produto.dart                # estoque + comissão
â”‚   â”œâ”€â”€ atendimento.dart            # barbeiro_uid
â”‚   â”œâ”€â”€ agendamento.dart            # DateTime
â”‚   â”œâ”€â”€ despesa.dart                # categorias validadas
â”‚   â””â”€â”€ caixa.dart                  # status aberto/fechado
â”œâ”€â”€ services/
â”‚   â”œâ”€â”€ auth_service.dart           # Firebase Auth + Firestore + SQLite fallback
â”‚   â”œâ”€â”€ cliente_service.dart        # Stream realtime + aniversariantes
â”‚   â”œâ”€â”€ comanda_service.dart        # CRUD + estoque + comissão + sync
â”‚   â”œâ”€â”€ financeiro_service.dart     # Despesas + Caixa + Resumo + sync
â”‚   â”œâ”€â”€ produto_service.dart        # CRUD + movimentos de estoque
â”‚   â”œâ”€â”€ servico_service.dart        # CRUD de serviços
â”‚   â”œâ”€â”€ agenda_service.dart         # Agendamentos + sync
â”‚   â”œâ”€â”€ atendimento_service.dart    # Registro atômico
â”‚   â”œâ”€â”€ dashboard_service.dart      # Métricas para dashboard
â”‚   â”œâ”€â”€ connectivity_service.dart   # Online/offline detection
â”‚   â”œâ”€â”€ firebase_context_service.dart # Coleções por barbearia_id
â”‚   â””â”€â”€ service_exceptions.dart     # NotFoundException, ConflictException, etc.
â”œâ”€â”€ screens/
â”‚   â”œâ”€â”€ auth/           login, cadastro, primeiro_login, recuperar_senha
â”‚   â”œâ”€â”€ admin/          dashboard_admin, barbeiros
â”‚   â”œâ”€â”€ barbeiro/       dashboard_barbeiro
â”‚   â”œâ”€â”€ clientes/       lista + histórico
â”‚   â”œâ”€â”€ comanda/        abrir + listar
â”‚   â”œâ”€â”€ financeiro/     financeiro (despesas, caixa, resumo)
â”‚   â”œâ”€â”€ produtos/       lista + form
â”‚   â”œâ”€â”€ servicos/       lista + form
â”‚   â”œâ”€â”€ agenda/         calendar view
â”‚   â”œâ”€â”€ estoque/        movimentações
â”‚   â”œâ”€â”€ caixa/          abertura/fechamento
â”‚   â”œâ”€â”€ ranking/        ranking de barbeiros
â”‚   â”œâ”€â”€ analytics/      gráficos e indicadores
â”‚   â”œâ”€â”€ relatorios/     export PDF/CSV/Excel
â”‚   â””â”€â”€ atendimentos/   histórico
â”œâ”€â”€ utils/
â”‚   â”œâ”€â”€ app_theme.dart              # Dark theme + Light theme
â”‚   â”œâ”€â”€ constants.dart              # Constantes globais (tabelas, roles, status)
â”‚   â””â”€â”€ security_utils.dart         # Sanitização e validação de inputs
â”œâ”€â”€ widgets/                        # Widgets reutilizáveis
â”œâ”€â”€ firebase_options.dart           # Configuração Firebase por plataforma
â””â”€â”€ main.dart                       # Entrada do app + rotas + providers
```

---

## âš™ï¸ Configuração & Build

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

## ðŸ”¥ Configuração Firebase

1. Crie um projeto no [Firebase Console](https://console.firebase.google.com)
2. Habilite **Authentication â†’ Email/Password**
3. Habilite **Cloud Firestore**
4. Baixe o `google-services.json` e coloque em `android/app/`
5. Publique as regras de segurança:
   ```bash
   firebase deploy --only firestore:rules
   ```
6. Crie os índices compostos necessários para as queries:
   - `usuarios` â†’ `role` + `nome`
   - `comandas` â†’ `barbeiro_id` + `status` + `data_abertura`

---

## ðŸ§ª Rodando os Testes

```bash
flutter test
```

> âš ï¸ Os testes de integração SQLite rodam offline sem necessidade de Firebase.

---

## ðŸ“ Licença

Projeto privado â€” uso exclusivo interno. Todos os direitos reservados.

---

*Severus Barber · v2.0.0 · Stack: Flutter 3.x · Firebase Auth · Cloud Firestore · SQLite*
