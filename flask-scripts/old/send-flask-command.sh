#!/usr/bin/env bash
# send-flask-command.sh
#
# Отправляет команду на Flask API через localhost.run туннель и выводит результат.
# Вход: $1 - команда для выполнения
# Пример:
#   ./send-flask-command.sh "whoami && uname -a"

set -euo pipefail

# =================== Настройка ===================
TUNNEL_URL="https://06f38baffec192.lhr.life"
API_TOKEN="ef43818d21a0fc2f3c5d834e29adae27"
# ==================================================

if [ "$#" -ne 1 ]; then
    echo "Использование: $0 <команда>"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq не найден. Установите: sudo apt install jq"
    exit 1
fi

COMMAND="$1"

echo "Отправка команды на Flask API..."
RESPONSE=$(curl -s -X POST "$TUNNEL_URL/run" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"cmd\":\"$COMMAND\"}")

OUTPUT=$(echo "$RESPONSE" | jq -r '.output')

echo "Результат:"
echo "$OUTPUT"
