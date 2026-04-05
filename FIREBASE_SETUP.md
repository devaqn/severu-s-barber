# 🔥 Firebase — Guia de Configuração Completo

> **Severus Barber** — Configuração passo a passo do Firebase para Android

---

## Pré-requisitos

| Ferramenta | Versão mínima |
|---|---|
| Flutter SDK | 3.x |
| Dart SDK | 3.x |
| Node.js | 18+ |
| Firebase CLI | `npm install -g firebase-tools` |
| Conta Google | — |

---

## Passo 1 — Criar o Projeto no Firebase Console

1. Acesse [console.firebase.google.com](https://console.firebase.google.com)
2. Clique em **"Adicionar projeto"**
3. Nome sugerido: `severus-barber`
4. Desative o Google Analytics (opcional)
5. Clique em **"Criar projeto"**

---

## Passo 2 — Habilitar Autenticação

1. No menu lateral, clique em **Authentication**
2. Clique em **"Começar"**
3. Na aba **"Sign-in method"**, clique em **Email/senha**
4. Ative **"Email/senha"** → Clique em **"Salvar"**

> ⚠️ Não ative "Link de email (sem senha)" — não é usado pelo app.

---

## Passo 3 — Habilitar o Cloud Firestore

1. No menu lateral, clique em **Firestore Database**
2. Clique em **"Criar banco de dados"**
3. Selecione **"Iniciar no modo de produção"**
4. Escolha a região mais próxima (sugerido: `southamerica-east1` — São Paulo)
5. Clique em **"Ativar"**

---

## Passo 4 — Registrar o App Android

1. Na página inicial do projeto, clique no ícone **Android** (`</>`)
2. Preencha:
   - **Nome do pacote Android**: `com.example.barbearia_pro`
   - **Apelido do app**: Severus Barber (opcional)
3. Clique em **"Registrar app"**
4. Baixe o arquivo `google-services.json`
5. Coloque o arquivo em:
   ```
   android/app/google-services.json
   ```
6. Clique em **"Próximo"** até o final (o `build.gradle` já está configurado)

> ⚠️ **Nunca versione o `google-services.json` no Git.** Ele já está no `.gitignore`.

---

## Passo 5 — Publicar as Regras de Segurança do Firestore

As regras estão no arquivo `firestore.rules` na raiz do projeto.

### Via Firebase CLI

```bash
# Autentique-se (abre o browser)
firebase login

# Selecione o projeto
firebase use --add
# Quando pedir o alias, digite: default

# Publique as regras
firebase deploy --only firestore:rules
```

### Via Firebase Console (alternativa manual)

1. Acesse **Firestore Database → Regras**
2. Copie o conteúdo do arquivo `firestore.rules`
3. Cole na área de texto e clique em **"Publicar"**

---

## Passo 6 — Criar os Índices Compostos do Firestore

Algumas queries do app precisam de índices compostos. Crie-os via Firebase Console:

### Acessar

**Firestore Database → Índices → Criar índice**

### Índices necessários

| Coleção | Campo 1 | Campo 2 | Campo 3 | Escopo |
|---|---|---|---|---|
| `barbearias/{id}/usuarios` | `role` (Asc) | `nome` (Asc) | — | Coleção |
| `barbearias/{id}/usuarios` | `role` (Asc) | `ativo` (Asc) | `nome` (Asc) | Coleção |
| `barbearias/{id}/comandas` | `barbeiro_id` (Asc) | `status` (Asc) | `data_abertura` (Desc) | Coleção |
| `barbearias/{id}/comandas` | `status` (Asc) | `data_abertura` (Desc) | — | Coleção |
| `barbearias/{id}/despesas` | `data` (Desc) | — | — | Coleção |
| `barbearias/{id}/agendamentos` | `data_hora` (Asc) | `status` (Asc) | — | Coleção |

### Índices de Collection Group (para busca por UID)

| Collection Group | Campo | Escopo |
|---|---|---|
| `usuarios` | `uid` (Asc) | Collection Group |
| `usuarios` | `role` (Asc) | Collection Group |
| `usuarios` | `email` (Asc) | Collection Group |

> 💡 O link direto para criação de cada índice aparece automaticamente no **log de erros do app** na primeira vez que a query rodar sem o índice.

---

## Passo 7 — Verificar o `firebase_options.dart`

O arquivo `lib/firebase_options.dart` deve conter as configurações do seu projeto.

Se precisar regenerá-lo:

```bash
# Instale o FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure (escolha Android)
flutterfire configure
```

Isso vai sobrescrever `firebase_options.dart` automaticamente.

---

## Passo 8 — Configurar o Primeiro Administrador

Após instalar o app pela primeira vez:

1. **Se não existe nenhum admin cadastrado**, a tela de cadastro público é exibida automaticamente.
2. Preencha nome, email e senha (mínimo 8 caracteres, letras + números).
3. O sistema cria o documento na Firestore em:
   ```
   barbearias/shop_{uid}/usuarios/{uid}
   ```
4. Faça login com as credenciais cadastradas.

> ✅ A partir daí, o admin pode criar barbeiros sem sair da conta.

---

## Passo 9 — Primeiro Login do Barbeiro

Quando um barbeiro é criado pelo admin:
- `first_login: true` é setado no Firestore
- No primeiro acesso, o app redireciona para a tela de troca de senha obrigatória
- Após trocar a senha, `first_login` é atualizado para `false`

---

## Passo 10 — Testar a Configuração

```bash
flutter clean
flutter pub get
flutter run
```

Verifique:
- [ ] App inicia sem crash
- [ ] Tela de login aparece corretamente
- [ ] Cadastro do primeiro admin funciona
- [ ] Login com o admin funciona
- [ ] Dashboard admin é exibido
- [ ] Criação de barbeiro funciona sem deslogar o admin

---

## Estrutura do Firestore

```
barbearias/
  shop_{admin_uid}/
    usuarios/
      {uid}/          → role, nome, email, comissao_percentual, first_login
    clientes/
      {firebase_id}/
    comandas/
      {firebase_id}/
        itens/
          {item_id}/
    servicos/
      {firebase_id}/
    produtos/
      {firebase_id}/
    agendamentos/
      {firebase_id}/
    despesas/
      {firebase_id}/
    caixas/
      {firebase_id}/
    comissoes/
      {firebase_id}/
    atendimentos/
      {firebase_id}/
    estoque/
      {firebase_id}/
```

---

## Variáveis de Ambiente (Modo Offline / Dev)

Para rodar o app sem Firebase (útil em desenvolvimento):

```bash
flutter run \
  --dart-define=OFFLINE_ADMIN_EMAIL=admin@offline.test \
  --dart-define=OFFLINE_ADMIN_PASSWORD=senha123
```

> ⚠️ O modo offline **não funciona em produção** — é exclusivo para desenvolvimento e QA.

---

## Gerar APK de Release

```bash
flutter clean
flutter pub get
flutter analyze
flutter build apk --release
```

O APK será gerado em:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Troubleshooting

| Problema | Solução |
|---|---|
| `google-services.json not found` | Coloque o arquivo em `android/app/` |
| `FirebaseException: [firestore/permission-denied]` | Publique as regras do Firestore (Passo 5) |
| `Missing index` no log | Crie os índices compostos (Passo 6) |
| `Firebase not initialized` | Verifique `firebase_options.dart` e `google-services.json` |
| Query com `collectionGroup` falha | Ative os índices de Collection Group no Console |
| App travado na splash após update | Execute `flutter clean && flutter pub get` |

---

*Severus Barber · Firebase Setup Guide · v2.0*
