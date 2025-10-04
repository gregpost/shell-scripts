#!/usr/bin/env bash
set -e

# === Настройки ===
ZIP_FILE="MyAndroidApp.zip"          # твой архив с исходниками
PROJECT_DIR="android-project"        # каталог для распаковки
OUTPUT_DIR="$(pwd)/output"           # куда сохранить APK
DOCKER_IMAGE="thyrlian/android-sdk"  # образ с Android SDK и Gradle

# === Проверки ===
if [ ! -f "$ZIP_FILE" ]; then
  echo "❌ Не найден $ZIP_FILE"
  exit 1
fi

# === Подготовка директорий ===
rm -rf "$PROJECT_DIR" "$OUTPUT_DIR"
mkdir -p "$PROJECT_DIR" "$OUTPUT_DIR"

echo "📦 Распаковка проекта..."
unzip -q "$ZIP_FILE" -d "$PROJECT_DIR"

# === Сборка внутри Docker ===
echo "🐳 Скачивание Docker-образа $DOCKER_IMAGE..."
docker pull $DOCKER_IMAGE

echo "⚙️  Запуск сборки..."
docker run --rm \
  -v "$(pwd)/$PROJECT_DIR:/workspace" \
  -v "$OUTPUT_DIR:/output" \
  -w /workspace \
  $DOCKER_IMAGE \
  bash -c "./gradlew assembleDebug && cp app/build/outputs/apk/debug/app-debug.apk /output/"

# === Итог ===
echo "✅ Готовый APK лежит в $OUTPUT_DIR/app-debug.apk"

