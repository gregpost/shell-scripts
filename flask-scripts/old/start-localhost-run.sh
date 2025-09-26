#!/usr/bin/env bash
# File: start-localhost-run.sh
# Description: ...
# Usage: ...

set -euo pipefail

APP_DIR="/data2/tmp"
APP_PORT=3000

# Create app directory if it doesn't exist
if [ ! -d "$APP_DIR" ]; then
    echo "Creating app directory $APP_DIR..."
    mkdir -p "$APP_DIR"
fi

cd "$APP_DIR"

# Create default index.html if not exists
if [ ! -f "$APP_DIR/index.html" ]; then
    echo "Creating default index.html..."
    cat <<EOF > index.html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Localhost.run Test</title>
</head>
<body>
<h1>Hello, localhost.run!</h1>
<p>This is a test page served from $APP_DIR</p>
</body>
</html>
EOF
fi

# Check if app is running
if ! curl -s "http://localhost:$APP_PORT" > /dev/null; then
    echo "Local app on port $APP_PORT not running. Starting dummy app..."
    nohup python3 -m http.server "$APP_PORT" >/dev/null 2>&1 &
    APP_PID=$!
    echo "Dummy app started with PID $APP_PID"
else
    echo "Local app on port $APP_PORT is already running."
fi

# Open localhost.run tunnel in background
echo "Opening localhost.run tunnel..."
nohup ssh -o ServerAliveInterval=60 -R 80:localhost:$APP_PORT nokey@localhost.run >/tmp/localhost_run.log 2>&1 &
TUNNEL_PID=$!
sleep 2

# Grab the tunnel URL from log
TUNNEL_URL=$(grep -oE 'https://[a-z0-9.-]+\.lhr\.life' /tmp/localhost_run.log | tail -n1)
echo "Tunnel URL: $TUNNEL_URL"
