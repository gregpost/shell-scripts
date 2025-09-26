#!/usr/bin/env bash
# File: start-termrelay-api.sh
# Purpose: Поднять локальный HTTP API на порту 3000, который принимает POST /run { "cmd": "..." }
#          и выполняет команду на Linux, возвращая stdout/stderr.
#          Затем автоматически открывает туннель через localhost.run и выводит публичный URL и токен.
#
# Безопасность:
#  - Запросы к /run требуют заголовка Authorization: Bearer <TOKEN>.
#  - TOKEN генерируется автоматически и сохраняется в /home/$(whoami)/.termrelay_token (только для текущего пользователя).
#  - Это минимальная защита — НЕ используйте в продакшене без дополнительной аутентификации/ограничений.
#
# Запуск:
#   chmod +x start-termrelay-api.sh
#   ./start-termrelay-api.sh
#
# После запуска:
#   - будет выведен публичный адрес туннеля (https://...). Откройте его в браузере для index.html.
#   - для вызова команды с Windows используйте:
#       curl -s -X POST https://<tunnel>/run -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" -d '{"cmd":"ls -la"}'
#
set -euo pipefail

APP_DIR="/data2/tmp"
APP_PORT=3000
TUNNEL_LOG="/tmp/localhost_run.log"
TOKEN_FILE="$HOME/.termrelay_token"
TUNNEL_USER="nokey"
TUNNEL_HOST="localhost.run"
TUNNEL_REMOTE_PORT=80

# -------- ensure app dir exists --------
if [ ! -d "$APP_DIR" ]; then
    echo "Создаём директорию приложения $APP_DIR..."
    mkdir -p "$APP_DIR"
fi
cd "$APP_DIR"

# -------- create default index.html --------
if [ ! -f "$APP_DIR/index.html" ]; then
    cat <<'HTML' > index.html
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <title>TermRelay API</title>
</head>
<body>
  <h1>TermRelay API</h1>
  <p>Этот хост служит как тестовая страница. Для выполнения команд используйте POST /run с токеном.</p>
</body>
</html>
HTML
fi

# -------- create Flask app (app.py) --------
cat <<'PY' > app.py
#!/usr/bin/env python3
from flask import Flask, request, jsonify
import subprocess, os, shlex, textwrap

app = Flask(__name__)

# Токен хранится в переменной окружения TERMRELAY_TOKEN или в файле, который подставит скрипт-стартер.
TOKEN = os.environ.get("TERMRELAY_TOKEN", None)

@app.route("/", methods=["GET"])
def index():
    return open("index.html").read(), 200

@app.route("/run", methods=["POST"])
def run_cmd():
    auth = request.headers.get("Authorization", "")
    if not TOKEN:
        return jsonify({"error":"Server misconfigured: no token"}), 500
    if not auth.startswith("Bearer "):
        return jsonify({"error":"Unauthorized"}), 401
    token = auth.split(" ",1)[1].strip()
    if token != TOKEN:
        return jsonify({"error":"Unauthorized"}), 401

    data = request.get_json(silent=True)
    if not data or "cmd" not in data:
        return jsonify({"error":"No command provided"}), 400

    # Ограничение: запрет пустых команд и некоторых опасных символов можно добавить здесь.
    cmd = data["cmd"]
    if not isinstance(cmd, str) or not cmd.strip():
        return jsonify({"error":"Empty command"}), 400

    # Выполнение команды (shell=True) — удобно, но потенциально опасно.
    try:
        # Используем subprocess.run для контроля таймаута/выхода
        completed = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
        return jsonify({
            "returncode": completed.returncode,
            "output": completed.stdout
        }), 200 if completed.returncode == 0 else 500
    except subprocess.TimeoutExpired as e:
        return jsonify({"error":"timeout","output":e.stdout or ""}), 504
    except Exception as e:
        return jsonify({"error":"exception","message":str(e)}), 500

if __name__ == "__main__":
    # Запуск в режиме 0.0.0.0 чтобы localhost.run мог подключиться
    app.run(host="0.0.0.0", port=int(os.environ.get("TERMRELAY_PORT", 3000)))
PY

# -------- ensure Python + Flask available --------
if ! command -v python3 >/dev/null 2>&1; then
    echo "Ошибка: python3 не найден. Установите Python 3."
    exit 1
fi

# Попробуем импортировать Flask, если нет — установим локально (возможно потребует прав)
python3 - <<'PY' || true
import sys
try:
    import flask
except Exception:
    print("no_flask")
    sys.exit(1)
sys.exit(0)
PY

if ! python3 -c "import flask" >/dev/null 2>&1; then
    echo "Flask не найден — пытаюсь установить через pip (потребуются права сети)..."
    # пробуем установить в пользовательский каталог
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user Flask >/dev/null 2>&1 || true
    else
        echo "pip3 не найден — установите pip3 или пакет python3-flask через пакетный менеджер."
        exit 1
    fi
fi

# -------- generate or read token --------
if [ -f "$TOKEN_FILE" ]; then
    TOKEN=$(cat "$TOKEN_FILE")
else
    TOKEN=$(openssl rand -hex 16 2>/dev/null || python3 -c "import secrets,sys;print(secrets.token_hex(16))")
    echo "$TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
fi

# -------- start Flask app in background if not running --------
if ! nc -z 127.0.0.1 "$APP_PORT"; then
    echo "Запускаем API-сервер на порту $APP_PORT..."
    # Экспортим переменные для app
    export TERMRELAY_TOKEN="$TOKEN"
    export TERMRELAY_PORT="$APP_PORT"
    nohup python3 app.py >/tmp/termrelay_app.log 2>&1 &
    APP_PID=$!
    sleep 1
    echo "API-сервер запущен с PID $APP_PID"
else
    echo "API уже слушает порт $APP_PORT"
fi

# -------- open localhost.run tunnel in background and capture URL --------
echo "Открываем туннель через localhost.run..."
# убираем старый лог
: > "$TUNNEL_LOG"

nohup ssh -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -R ${TUNNEL_REMOTE_PORT}:localhost:${APP_PORT} ${TUNNEL_USER}@${TUNNEL_HOST} >"$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!
sleep 3

# Попытка прочитать URL из лога (несколько форматов: lhr.life или localhost.run)
TUNNEL_URL=""
for i in $(seq 1 8); do
    sleep 1
    TUNNEL_URL=$(grep -oE 'https://[a-z0-9.-]+\.lhr\.life|https://[a-z0-9.-]+\.localhost\.run' "$TUNNEL_LOG" | tail -n1 || true)
    if [ -n "$TUNNEL_URL" ]; then
        break
    fi
done

# Если не найден, показываем первые строки лога для отладки
if [ -z "$TUNNEL_URL" ]; then
    echo "Не удалось автоматически получить публичный URL из лога туннеля. Просмотрите лог:"
    echo "---- начало лога туннеля ----"
    head -n 40 "$TUNNEL_LOG" || true
    echo "---- конец ----"
else
    echo "Публичный URL туннеля: $TUNNEL_URL"
    echo
    echo "Токен доступа (Authorization: Bearer <TOKEN>):"
    echo "$TOKEN"
    echo
    echo "Пример запроса с Windows (PowerShell):"
    echo "curl -X POST $TUNNEL_URL/run -H \"Authorization: Bearer $TOKEN\" -H \"Content-Type: application/json\" -d '{\"cmd\":\"whoami && uname -a\"}'"
fi

# -------- вывод путей и PID --------
echo
echo "Пути логов:"
echo "  Приложение: /tmp/termrelay_app.log"
echo "  Туннель: $TUNNEL_LOG"
echo
echo "PID процессов:"
ps -o pid,cmd -u $(whoami) | grep -E "python3 .*app.py|ssh .*localhost.run" || true

exit 0
