#!/usr/bin/env bash
# File: send-command.sh
# Usage: ./send-command.sh "whoami && uname -a"
# Reads token from /data2/tmp/token.txt

set -euo pipefail

# Проверка аргумента
if [ $# -lt 1 ]; then
    echo "Usage: $0 \"<command>\""
    exit 1
fi

CMD="$1"
LOG_FILE="/tmp/localhost_run.log"
TOKEN_FILE="/data2/tmp/token.txt"

# Читаем токен из файла
if [ ! -f "$TOKEN_FILE" ]; then
    echo "Ошибка: токен не найден в $TOKEN_FILE"
    exit 1
fi
read -r TOKEN < "$TOKEN_FILE"
if [ -z "$TOKEN" ]; then
    echo "Ошибка: файл токена пустой: $TOKEN_FILE"
    exit 1
fi

# Получаем актуальный URL туннеля
URL=$(grep -oE 'https://[a-z0-9.-]+\.lhr\.life' "$LOG_FILE" | tail -n1 || true)

if [ -z "$URL" ]; then
    echo "Ошибка: не найден активный туннель в $LOG_FILE"
    exit 1
fi

echo "Использую URL туннеля: $URL"
echo "Выполняю команду: $CMD"

# Отправляем POST-запрос к Flask API
curl -s -X POST "$URL/run" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d "{\"cmd\":\"$CMD\"}"
echo
