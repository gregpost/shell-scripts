#!/usr/bin/env bash
# Script: stop-terminal-api.sh
# Purpose: Terminate Flask API and localhost.run tunnel processes on port 3000

APP_PORT=3000

echo "🔹 Проверка процессов перед завершением..."
lsof -i :$APP_PORT
ps aux | grep '[s]sh .*localhost.run'

echo "🔹 Завершаем процессы на порту $APP_PORT и туннель..."
# Завершение Flask и связанных процессов
PIDS=$(lsof -ti :$APP_PORT)
if [ -n "$PIDS" ]; then
    kill -9 $PIDS
    echo "Завершены процессы Flask: $PIDS"
else
    echo "Процесс Flask не найден"
fi

# Завершение SSH туннеля
TUNNEL_PIDS=$(ps aux | grep '[s]sh .*localhost.run' | awk '{print $2}')
if [ -n "$TUNNEL_PIDS" ]; then
    kill -9 $TUNNEL_PIDS
    echo "Завершены процессы SSH туннеля: $TUNNEL_PIDS"
else
    echo "SSH туннель не найден"
fi

echo "🔹 Проверка после завершения..."
lsof -i :$APP_PORT
ps aux | grep '[s]sh .*localhost.run'

echo "✅ Завершение процессов выполнено."
