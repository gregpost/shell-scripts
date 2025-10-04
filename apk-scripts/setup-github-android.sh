#!/usr/bin/env bash
# Скрипт для подготовки Android-проекта на GitHub с CI-сборкой APK

# === Настройки ===
ZIP_FILE="MyAndroidApp.zip"   # твой zip с Kotlin проектом
REPO_NAME="my-android-app"    # имя нового репозитория на GitHub
WORKFLOW_FILE=".github/workflows/build.yml"

# === Проверки ===
if [ ! -f "$ZIP_FILE" ]; then
  echo "❌ Zip-файл $ZIP_FILE не найден. Помести его рядом со скриптом."
  exit 1
fi

# === Подготовка проекта ===
echo "📦 Распаковка проекта..."
rm -rf "$REPO_NAME"
mkdir "$REPO_NAME"
unzip -q "$ZIP_FILE" -d "$REPO_NAME"

cd "$REPO_NAME" || exit 1

# === Git init ===
echo "📂 Инициализация Git..."
git init
git add .
git commit -m "Initial commit with Android project"

# === Добавляем workflow ===
echo "⚙️  Создание GitHub Actions workflow..."
mkdir -p .github/workflows
cat > $WORKFLOW_FILE <<'EOF'
name: Android CI

on:
  push:
    branches: [ "main" ]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout source
        uses: actions/checkout@v3

      - name: Set up JDK 11
        uses: actions/setup-java@v3
        with:
          java-version: '11'
          distribution: 'temurin'

      - name: Set up Gradle
        uses: gradle/gradle-build-action@v2

      - name: Build APK
        run: ./gradlew assembleDebug

      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: my-android-apk
          path: app/build/outputs/apk/debug/app-debug.apk
EOF

git add .github/workflows/build.yml
git commit -m "Add GitHub Actions workflow to build APK"

# === Подсказка пользователю ===
echo "✅ Локальный проект подготовлен."
echo ""
echo "➡️ Теперь сделай следующее вручную:"
echo "1. Создай новый репозиторий $REPO_NAME на GitHub: https://github.com/new"
echo "2. Свяжи локальный проект с репозиторием:"
echo "   git remote add origin https://github.com/<ТВОЙ_ЛОГИН>/$REPO_NAME.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo "3. Перейди в раздел Actions в репозитории (https://github.com/<ТВОЙ_ЛОГИН>/$REPO_NAME/actions)"
echo "   Там появится pipeline, который автоматически соберёт APK."

