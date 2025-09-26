#!/usr/bin/env bash

# File: start-terminal-api-2.sh
# Script to...
# Usage: ...

set -euo pipefail

APP_DIR="/data2/tmp"
APP_PORT=3000
TOKEN_FILE="$APP_DIR/token.txt"

# -------------------- подготовка директории --------------------
if [ ! -d "$APP_DIR" ]; then
    echo "Создаём директорию $APP_DIR..."
    mkdir -p "$APP_DIR"
fi

cd "$APP_DIR"

# -------------------- проверка Flask --------------------
if ! python3 -c "import flask" &>/dev/null; then
    echo "Flask не найден — установите его командой: pip install flask"
    exit 1
fi

# -------------------- создаём токен --------------------
if [ ! -f "$TOKEN_FILE" ]; then
    TOKEN=$(head -c 16 /dev/urandom | xxd -p)
    echo "$TOKEN" > "$TOKEN_FILE"
else
    TOKEN=$(cat "$TOKEN_FILE")
fi

# -------------------- создаём Flask API --------------------
APP_FILE="$APP_DIR/app.py"

cat > "$APP_FILE" <<EOF
from flask import Flask, request, jsonify
import subprocess

app = Flask(__name__)
TOKEN = "$TOKEN"

@app.route("/run", methods=["POST"])
def run_cmd():
    auth = request.headers.get("Authorization","")
    if auth != f"Bearer {TOKEN}":
        return jsonify({"error":"Unauthorized"}), 403
    data = request.get_json(force=True)
    cmd = data.get("cmd")
    if not cmd:
        return jsonify({"error":"No command"}), 400
    try:
        output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True)
    except subprocess.CalledProcessError as e:
        output = e.output
    return jsonify({"output": output})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=$APP_PORT)
EOF

# -------------------- проверка запущенного приложения --------------------
if lsof -i :$APP_PORT -sTCP:LISTEN &>/dev/null; then
    echo "API уже слушает порт $APP_PORT"
else
    echo "Запускаем Flask API..."
    nohup python3 "$APP_FILE" >/tmp/termrelay_app.log 2>&1 &
    sleep 2
fi

# -------------------- открываем туннель через localhost.run --------------------
echo "Открываем туннель через localhost.run..."
LOG_FILE="/tmp/localhost_run.log"
nohup ssh -o ServerAliveInterval=60 -R 80:localhost:$APP_PORT nokey@localhost.run >"$LOG_FILE" 2>&1 &

sleep 3
TUNNEL_URL=$(grep -oE 'https://[a-z0-9.-]+\.lhr\.life' "$LOG_FILE" | tail -n1)

# -------------------- вывод информации --------------------
echo ""
echo "Публичный URL туннеля: $TUNNEL_URL"
echo ""
echo "Токен доступа (Authorization: Bearer <TOKEN>):"
echo "$TOKEN"
echo ""
echo "Пример запроса с Windows (PowerShell):"
echo "curl -X POST $TUNNEL_URL/run -H \"Authorization: Bearer $TOKEN\" -H \"Content-Type: application/json\" -d '{\"cmd\":\"whoami && uname -a\"}'"
echo ""
echo "Пути логов:"
echo "  Приложение: /tmp/termrelay_app.log"
echo "  Туннель: $LOG_FILE"
echo ""
echo "PID процессов:"
ps aux | grep "[p]ython3 $APP_FILE\|ssh .*localhost.run" | awk '{print $2, $11, $12, $13}'
