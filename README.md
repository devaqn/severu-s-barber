# 💈 Severus Barber

> Sistema profissional de gestão de barbearia **SaaS Multi-Usuário** — desenvolvido em Flutter com Firebase.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-orange?logo=firebase)
![SQLite](https://img.shields.io/badge/Banco-SQLite%20%2B%20Firestore-green?logo=sqlite)
![Versão](https://img.shields.io/badge/Versão-2.0.0-brightgreen)
![Platform](https://img.shields.io/badge/Plataforma-Android%20%7C%20Windows-lightgrey)

---

## 📋 Descrição

O **Severus Barber** é um sistema completo de gestão para barbearias com suporte a múltiplos barbeiros e controle de comissões. Funciona **offline via SQLite** e pode ser expandido com **Firebase** para sincronização em nuvem e multi-dispositivo.

### Principais diferenciais
- 🔐 Sistema de login com controle de acesso (Admin / Barbeiro)
- 💈 Sistema de comandas com cálculo automático de comissão
- 📊 Dashboard distintos: visão do barbeiro e visão administrativa
- 🏆 Ranking e performance por barbeiro
- 📦 Controle de estoque integrado ao fechamento de comanda
- 💰 Controle financeiro completo com simulador de lucro
- 📄 Exportação de relatórios em PDF e CSV

---

## ✨ Funcionalidades

### 🔐 Autenticação e Usuários
- Login com email/senha (Firebase Auth)
- Cadastro de administrador (primeiro acesso)
- Recuperação de senha por email
- Tipos de acesso: **Admin** e **Barbeiro**
- Modo offline: SQLite local (sem Firebase)

### 👨‍💼 Dashboard do Admin
- Faturamento hoje e no mês
- Lucro estimado e despesas
- Gráfico de faturamento (30 dias)
- **Ranking de barbeiros** por faturamento e comissão
- Alertas de comandas em aberto e estoque baixo

### 💈 Dashboard do Barbeiro
- Faturamento pessoal hoje e no mês
- **Comissão pessoal** hoje e no mês
- Alerta de comanda em aberto
- Histórico de atendimentos do dia

### 🧾 Sistema de Comanda
- Abertura com seleção de cliente (ou avulso)
- Adição de serviços e produtos com comissão visível
- Recalculo automático do total e da comissão
- Fechamento com forma de pagamento
- Continuação de commandas abertas

### 💸 Comissão Automática
- Cada serviço tem `%` de comissão configurável (padrão 50%)
- Cada produto tem `%` de comissão configurável (padrão 20%)
- Ao fechar a comanda: comissão registrada automaticamente
- Lucro da casa = Total − Comissão

### 👥 Gestão de Clientes
- Cadastro com nome, telefone e observações
- Histórico de atendimentos e total gasto
- Programa de fidelidade (10 cortes = 1 grátis)
- Identificação de clientes sumidos

### ✂️ Gestão de Serviços e Produtos
- Cadastro com preço, duração e % de comissão
- Vínculo de produtos com fornecedores
- Margem de lucro calculada automaticamente

### 📦 Controle de Estoque
- Entrada e saída com histórico completo
- Baixa automática ao fechar comanda
- Alertas de estoque mínimo
- Custo médio ponderado

### 💰 Controle Financeiro
- Receitas (atendimentos) e despesas por categoria
- Resumo: faturamento, despesas, lucro líquido
- Simulador de preços embutido
- Controle de caixa diário (abertura/fechamento)

### 📅 Agenda
- Calendário visual com agendamentos por status
- Status: Pendente → Confirmado → Concluído / Cancelado

### 📄 Relatórios
- Exportação em PDF (financeiro completo)
- Exportação em CSV (atendimentos, clientes)

---

## 🛠️ Tecnologias

| Tecnologia | Uso |
|---|---|
| Flutter 3.x | Framework UI (Android, Windows) |
| Dart 3.x | Linguagem de programação |
| Firebase Auth | Login e controle de sessão |
| Cloud Firestore | Sincronização em nuvem (opcional) |
| sqflite / sqflite_ffi | Banco SQLite local (offline) |
| fl_chart | Gráficos interativos |
| table_calendar | Calendário da agenda |
| pdf + printing | Geração de PDF |
| google_fonts | Tipografia Inter e Poppins |
| intl | Formatação pt-BR |
| provider | Gerenciamento de estado |

---

## 🏗️ Estrutura do Projeto

```
lib/
├── main.dart                        # Entrada do app + AuthWrapper
├── models/
│   ├── usuario.dart                 # Admin / Barbeiro
│   ├── comanda.dart                 # Comanda multi-item
│   ├── item_comanda.dart            # Item com cálculo de comissão
│   ├── cliente.dart
│   ├── servico.dart                 # Com comissao_percentual
│   ├── produto.dart                 # Com comissao_percentual
│   ├── atendimento.dart
│   ├── agendamento.dart
│   ├── despesa.dart
│   ├── movimento_estoque.dart
│   └── caixa.dart
├── database/
│   └── database_helper.dart         # SQLite v2 com migrations
├── services/
│   ├── auth_service.dart            # Firebase Auth + Firestore
│   ├── comanda_service.dart         # CRUD + fechamento + comissões
│   ├── cliente_service.dart
│   ├── servico_service.dart
│   ├── produto_service.dart
│   ├── atendimento_service.dart
│   ├── financeiro_service.dart
│   ├── agenda_service.dart
│   └── dashboard_service.dart
├── controllers/
│   ├── auth_controller.dart         # Estado de autenticação
│   ├── atendimento_controller.dart
│   ├── cliente_controller.dart
│   └── estoque_controller.dart
├── screens/
│   ├── auth/                        # Login, Cadastro, Recuperar Senha
│   ├── admin/                       # Dashboard administrativo
│   ├── barbeiro/                    # Dashboard do barbeiro
│   ├── comanda/                     # Abrir, listar, fechar comandas
│   ├── dashboard/                   # Dashboard padrão
│   ├── clientes/
│   ├── servicos/
│   ├── produtos/
│   ├── estoque/
│   ├── atendimentos/
│   ├── financeiro/
│   ├── agenda/
│   ├── caixa/
│   ├── analytics/
│   ├── ranking/
│   └── relatorios/
├── widgets/
│   ├── stat_card.dart
│   └── app_drawer.dart              # Menu com logout e Comandas
└── utils/
    ├── app_theme.dart               # Tema dark/light
    ├── constants.dart               # Constantes globais
    └── formatters.dart              # Formatadores pt-BR
```

---

## 🚀 Como Rodar

### Pré-requisitos

- Flutter 3.16+ com Dart 3.2+
- Para Windows: Visual Studio Build Tools
- Para Android: Android Studio + SDK

```bash
# Verificar instalação
flutter doctor

# Instalar dependências
cd barbearia_pro
flutter pub get
```

### Desenvolvimento (sem Firebase)

O app funciona em modo offline completo com SQLite:

```bash
# Windows Desktop
flutter run -d windows

# Android (emulador ou dispositivo)
flutter run

# Chrome (Web)
flutter run -d chrome
```

---

## 🔥 Configurar Firebase (Multi-Usuário em Nuvem)

### 1. Criar projeto no Firebase
1. Acesse [console.firebase.google.com](https://console.firebase.google.com)
2. Crie um projeto (ex: `severus-barber`)
3. Habilite **Authentication → Email/Password**
4. Habilite **Cloud Firestore** (modo de teste para dev)

### 2. Conectar ao projeto Flutter

```bash
# Instalar FlutterFire CLI
dart pub global activate flutterfire_cli

# Conectar (gera lib/firebase_options.dart automaticamente)
flutterfire configure --project=severus-barber
```

### 3. Ativar inicialização no main.dart

Descomente a linha de options no `main.dart`:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform, // gerado pelo CLI
);
```

### 4. Regras de segurança do Firestore

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.role == 'admin';
    }

    match /usuarios/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && isAdmin();
    }

    match /{collection}/{doc} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 5. Primeiro acesso
1. Abra o app → tela de Login → toque **"Criar conta admin"**
2. Cadastre o dono (Admin)
3. No app como Admin → Barbeiros → **Adicionar Barbeiro**
4. Barbeiro recebe email/senha e loga no seu dispositivo

---

## 📱 Gerar APK Android

```bash
flutter build apk --release
# Saída: build/app/outputs/flutter-apk/app-release.apk
```

## 🖥️ Gerar Executável Windows

```bash
flutter build windows --release
# Saída: build/windows/x64/runner/Release/barbearia_pro.exe
```

> Para distribuir o Windows: copie **toda a pasta** `Release/` — o `.exe` depende das DLLs ao redor.

---

## 📸 Fluxo de Uso

### Fluxo completo de atendimento com comanda
1. Barbeiro loga → vê seu Dashboard pessoal
2. Toca **Nova Comanda** → seleciona cliente
3. Marca serviços (Corte, Barba…) — comissão exibida em tempo real
4. Adiciona produtos opcionais com quantidade
5. Seleciona forma de pagamento → **Fechar Comanda**
6. Sistema: registra comissão, baixa estoque, atualiza histórico

### Visão do Admin após fechar o dia
1. Admin abre o app → Dashboard Administrativo
2. Vê faturamento total, ranking de barbeiros, comandas do dia
3. Gera relatório PDF em **Relatórios**

---

## 🗄️ Banco de Dados

| Tabela | Descrição |
|--------|-----------|
| `clientes` | Cadastro com fidelidade |
| `servicos` | Com `comissao_percentual` |
| `produtos` | Com `comissao_percentual` |
| `fornecedores` | Vínculo com produtos |
| `atendimentos` | Histórico de atendimentos |
| `atendimento_itens` | Itens de cada atendimento |
| `agendamentos` | Agenda com status |
| `despesas` | Controle financeiro |
| `movimentos_estoque` | Histórico de entrada/saída |
| `caixas` | Abertura/fechamento diário |
| `usuarios` | Admin e barbeiros (v2) |
| `comandas` | Comandas abertas/fechadas (v2) |
| `comandas_itens` | Itens das comandas (v2) |
| `comissoes` | Registro de comissões pagas (v2) |

---

## 📝 Arquitetura

```
UI (Screens) → Controllers (ChangeNotifier) → Services (lógica) → DatabaseHelper (SQLite)
                                                                 → Firebase (opcional)
```

- **Models** — entidades puras de dados
- **Database** — acesso SQLite com transactions
- **Services** — regras de negócio (cálculo de comissão, baixa de estoque)
- **Controllers** — estado reativo com Provider
- **Screens** — UI consumindo Controllers/Services

---

## 📄 Licença

MIT © 2025 — Livre para uso pessoal e comercial.

---

*Desenvolvido com Flutter 💙 — para barbeiros que valorizam profissionalismo.*
