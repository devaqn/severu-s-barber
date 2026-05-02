# Checklist QA — Dispositivo Físico

## Pré-requisitos

- Android 5.0+ (API 21+)
- USB debugging ativado
- `adb devices` mostra o dispositivo

## Instalar o APK de release no dispositivo

```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Fluxos críticos a validar manualmente

- Login
- Cadastro admin
- Criar barbeiro
- Abrir comanda
- Adicionar serviço
- Fechar comanda
- Verificar estoque baixou
- Abrir/fechar caixa
- Sangria
- Agendar
- Concluir agendamento com pagamento
- Offline → fechar app → voltar online → conferir sync
- Tema claro / escuro
- Exportar PDF/CSV

## Critérios de aceite

- Sem crashes em nenhum fluxo
- Layout sem overflow visível em 360x800px e 390x844px
- Faturamento e comissão batem com os valores registrados
