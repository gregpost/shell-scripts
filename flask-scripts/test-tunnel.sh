#!/usr/bin/env bash
# File: test-tunnel-page.sh
# Purpose: Проверяет доступность index.html через текущий туннель

set -euo pipefail

LOG_FILE="/tmp/localhost_run.log"

# Получаем актуальный URL туннеля
URL=$(grep -oE 'https://[a-z0-9.-]+\.lhr\.life' "$LOG_FILE" | tail -n1)

if [ -z "$URL" ]; then
    echo "Ошибка: не найден активный туннель в $LOG_FILE"
    exit 1
fi

echo "Использую URL туннеля: $URL"
echo "Проверяю доступность index.html..."

# Получаем страницу index.html
HTTP_CODE=$(curl -s -o /tmp/index.html -w "%{http_code}" "$URL/")

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "Страница index.html успешно доступна!"
    echo "Путь к локальному сохранению для проверки: /tmp/index.html"
else
    echo "Ошибка: страница недоступна, код HTTP: $HTTP_CODE"
fi
