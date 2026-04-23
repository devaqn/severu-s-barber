# Guia de Desenvolvimento

Guia rapido para subir, validar e depurar o app `barbearia_pro`.

## Estado validado em 23/04/2026

Os comandos abaixo foram executados com sucesso neste workspace:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Resultados esperados:

- analise estatica sem issues
- todos os testes passando
- APK debug gerado em `build/app/outputs/flutter-apk/app-debug.apk`

## Ambiente usado na validacao

- Flutter `3.41.6`
- Dart `3.11.4`
- Windows desktop disponivel
- Android build funcionando

## Primeiro setup

```powershell
flutter pub get
```

Se quiser garantir um ambiente limpo:

```powershell
flutter clean
flutter pub get
```

## Rodando em desenvolvimento

### Windows desktop

Modo offline recomendado para desenvolvimento local:

```powershell
flutter run -d windows `
  --dart-define=ENABLE_OFFLINE_LOGIN=true `
  --dart-define=OFFLINE_ADMIN_EMAIL=admin@offline.local `
  --dart-define=OFFLINE_ADMIN_PASSWORD=SenhaForte@123
```

Observacoes:

- se nao houver credenciais Firebase validas para desktop, o app entra em fallback offline
- o executavel debug fica em `build/windows/x64/runner/Debug/barbearia_pro.exe`

### Android

Para compilar e testar no Android:

```powershell
flutter build apk --debug
```

Para rodar em um dispositivo conectado:

```powershell
flutter devices
flutter run -d <device-id> `
  --dart-define=ENABLE_OFFLINE_LOGIN=true `
  --dart-define=OFFLINE_ADMIN_EMAIL=admin@offline.local `
  --dart-define=OFFLINE_ADMIN_PASSWORD=SenhaForte@123
```

## Validacao rapida antes de mexer em feature

```powershell
flutter analyze
flutter test
```

## Fluxo recomendado de verificacao manual

1. Abrir o app.
2. Fazer login.
3. Validar dashboard.
4. Navegar por comandas, atendimentos, agenda e clientes.
5. Se for admin, validar produtos, estoque, financeiro, caixa, analytics e relatorios.
6. Abrir e fechar uma comanda de teste.

Para um roteiro mais completo, veja `docs/qa_fluxo_completo.md`.

## Firebase

- Android/iOS usam configuracao nativa
- Desktop pode rodar offline quando o Firebase nao estiver configurado
- para fluxo online real, passe as credenciais com `--dart-define` conforme o `README.md`

## Troubleshooting

### `flutter run` no Windows compila, mas falha ao conectar no service protocol

Isso pode acontecer mesmo quando o `.exe` abre corretamente. Se ocorrer:

```powershell
Get-Process barbearia_pro -ErrorAction SilentlyContinue | Stop-Process -Force
flutter run -d windows `
  --dart-define=ENABLE_OFFLINE_LOGIN=true `
  --dart-define=OFFLINE_ADMIN_EMAIL=admin@offline.local `
  --dart-define=OFFLINE_ADMIN_PASSWORD=SenhaForte@123
```

### App abriu em modo offline

Comportamento esperado quando:

- `firebase_options.dart` nao tem credenciais validas para desktop
- ou o Firebase nao inicializa no desktop

### Onde ficam os principais artefatos

- APK debug: `build/app/outputs/flutter-apk/app-debug.apk`
- EXE debug Windows: `build/windows/x64/runner/Debug/barbearia_pro.exe`
