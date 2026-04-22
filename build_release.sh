#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERRO: Arquivo .env nao encontrado. Copie .env.example para .env e preencha."
  exit 1
fi

# Carrega variaveis do .env
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# Verifica variaveis obrigatorias
REQUIRED_VARS=(
  FIREBASE_PROJECT_ID
  FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_ANDROID_API_KEY
  FIREBASE_ANDROID_APP_ID
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "ERRO: Variavel $var nao definida no .env"
    exit 1
  fi
done

echo "Variaveis verificadas. Iniciando build de producao..."

if [ ! -f "android/key.properties" ]; then
  echo "AVISO: android/key.properties ausente. Usando assinatura debug para gerar release local."
  export ORG_GRADLE_PROJECT_allowInsecureDebugSigning=true
fi

flutter build apk --release \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET:-}" \
  --dart-define=FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-}" \
  --dart-define=FIREBASE_WEB_API_KEY="${FIREBASE_WEB_API_KEY:-}" \
  --dart-define=FIREBASE_WEB_APP_ID="${FIREBASE_WEB_APP_ID:-}" \
  --dart-define=FIREBASE_ANDROID_API_KEY="$FIREBASE_ANDROID_API_KEY" \
  --dart-define=FIREBASE_ANDROID_APP_ID="$FIREBASE_ANDROID_APP_ID" \
  --dart-define=FIREBASE_IOS_API_KEY="${FIREBASE_IOS_API_KEY:-}" \
  --dart-define=FIREBASE_IOS_APP_ID="${FIREBASE_IOS_APP_ID:-}" \
  --dart-define=FIREBASE_IOS_BUNDLE_ID="${FIREBASE_IOS_BUNDLE_ID:-}" \
  --dart-define=FIREBASE_MACOS_API_KEY="${FIREBASE_MACOS_API_KEY:-}" \
  --dart-define=FIREBASE_MACOS_APP_ID="${FIREBASE_MACOS_APP_ID:-}" \
  --dart-define=FIREBASE_MACOS_BUNDLE_ID="${FIREBASE_MACOS_BUNDLE_ID:-}" \
  --dart-define=FIREBASE_WINDOWS_API_KEY="${FIREBASE_WINDOWS_API_KEY:-}" \
  --dart-define=FIREBASE_WINDOWS_APP_ID="${FIREBASE_WINDOWS_APP_ID:-}" \
  --dart-define=FIREBASE_LINUX_API_KEY="${FIREBASE_LINUX_API_KEY:-}" \
  --dart-define=FIREBASE_LINUX_APP_ID="${FIREBASE_LINUX_APP_ID:-}" \
  --dart-define=FIREBASE_TEST_ADMIN_EMAIL="${FIREBASE_TEST_ADMIN_EMAIL:-}" \
  --dart-define=FIREBASE_TEST_ADMIN_PASSWORD="${FIREBASE_TEST_ADMIN_PASSWORD:-}" \
  --dart-define=FIREBASE_TEST_ADMIN_NAME="${FIREBASE_TEST_ADMIN_NAME:-}" \
  --dart-define=OFFLINE_ADMIN_EMAIL="${OFFLINE_ADMIN_EMAIL:-}" \
  --dart-define=OFFLINE_ADMIN_PASSWORD="${OFFLINE_ADMIN_PASSWORD:-}" \
  --dart-define=ENABLE_FIREBASE_TEST_SHORTCUT=false \
  --dart-define=ENABLE_OFFLINE_LOGIN="${ENABLE_OFFLINE_LOGIN:-false}"

mkdir -p build/release
cp build/app/outputs/flutter-apk/app-release.apk build/release/severus-barber.apk

echo "APK gerado em: build/release/severus-barber.apk"
