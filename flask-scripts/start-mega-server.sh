#!/usr/bin/env bash
# File: run-mega-server.sh
# Purpose: Поднять Flask API с токеном и открыть туннель (localhost.run или ngrok)
# Usage:
#   ./run-mega-server.sh
#   ./run-mega-server.sh --ngrok
#   ./run-mega-server.sh -h | --help

set -euo pipefail

APP_DIR="/data2/tmp"
APP_PORT=3000
TOKEN_FILE="$APP_DIR/token.txt"
TUNNEL_LOG="/tmp/localhost_run.log"

USE_NGROK=false

print_help() {
    cat <<EOF
Использование: $0 [ОПЦИИ]

Опции:
  --ngrok     Использовать ngrok вместо localhost.run
  -h, --help  Показать это сообщение и выйти

Примеры:
  $0
  $0 --ngrok
EOF
}

# -------------------- парсим аргументы --------------------
for arg in "$@"; do
    case "$arg" in
        --ngrok)
            USE_NGROK=true
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Неизвестный аргумент: $arg"
            print_help
            exit 1
            ;;
    esac
done

# -------------------- подготовка директории --------------------
if [ ! -d "$APP_DIR" ]; then
    mkdir -p "$APP_DIR"
fi
cd "$APP_DIR"

# -------------------- проверка Flask --------------------
if ! python3 -c "import flask" &>/dev/null; then
    echo "Flask не найден. Установите его командой: pip install flask"
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
from flask import Flask, request, jsonify, send_from_directory
import subprocess, os

app = Flask(__name__)
TOKEN = "$TOKEN"
APP_DIR = "$APP_DIR"

@app.route("/", methods=["GET"])
def index():
    return send_from_directory(APP_DIR, "index.html")

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

# -------------------- запускаем Flask API --------------------
if ! lsof -i :$APP_PORT -sTCP:LISTEN &>/dev/null; then
    nohup python3 "$APP_FILE" >/tmp/termrelay_app.log 2>&1 &
    sleep 2
fi

# -------------------- открываем туннель --------------------
: > "$TUNNEL_LOG"

if [ "$USE_NGROK" = true ]; then
    if ! command -v ngrok &>/dev/null; then
        echo "Ошибка: ngrok не найден."
        echo "Для установки выполните:"
        echo "  sudo apt update && sudo apt install -y snapd"
        echo "  sudo snap install ngrok"
        exit 1
    fi
    nohup ngrok http $APP_PORT >"$TUNNEL_LOG" 2>&1 &
    sleep 5
    TUNNEL_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -oE 'https://[a-z0-9.-]+\.ngrok-free\.app' | head -n1)
else
    # добавляем опции, чтобы подавить yes/no/fingerprint
    nohup ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o ServerAliveInterval=60 -R 80:localhost:$APP_PORT nokey@localhost.run \
          >"$TUNNEL_LOG" 2>&1 &
    sleep 3
    TUNNEL_URL=$(grep -oE 'https://[a-z0-9.-]+\.lhr\.life' "$TUNNEL_LOG" | tail -n1)
fi

if [ -z "$TUNNEL_URL" ]; then
    echo "Ошибка: не удалось получить URL туннеля. Лог:"
    head -n 20 "$TUNNEL_LOG"
    exit 1
fi

echo "Публичный URL туннеля: $TUNNEL_URL"
echo "Токен доступа: $TOKEN"
