# Severus Barber - Modo Producao

## 1) Assinatura Android obrigatoria

1. Copie `android/key.properties.example` para `android/key.properties`.
2. Preencha com os dados reais da sua keystore.
3. Garanta que o caminho `storeFile` exista no ambiente de build.

Sem `android/key.properties`, o build `release` vai falhar por seguranca.

## 2) Credenciais Firebase e variaveis

Use `.env.example` como base e passe os valores reais com `--dart-define`.

Flags de seguranca:

- `ENABLE_FIREBASE_TEST_SHORTCUT=false` em producao.
- `ENABLE_OFFLINE_LOGIN=false` em producao.

## 3) Build release

```bash
flutter clean
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
```

## 4) Observacoes

- O login offline agora exige `ENABLE_OFFLINE_LOGIN=true` + credenciais explicitas.
- O atalho de conta de teste fica desativado em `release`.
- Nunca versionar `android/key.properties`, `.env`, `.jks` ou `.keystore`.

