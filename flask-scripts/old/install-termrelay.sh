#!/usr/bin/env bash
# File: install-termrelay-http.sh
# Purpose: Create a systemd service that runs a long-lived HTTP tunnel to localhost.run
#          (anonymous, client-less, does NOT require SSH login or key).

set -euo pipefail

SERVICE_NAME="termrelay-tunnel.service"
RELAY_USER_DEFAULT="termrelay"
RELAY_USER="${RELAY_USER_DEFAULT}"
LOCAL_HTTP_PORT="${LOCAL_HTTP_PORT:-3000}"
REMOTE_HTTP_PORT="${REMOTE_HTTP_PORT:-0}"  # 0 = automatically assigned by localhost.run
TUNNEL_CMD=""
PROVIDER=""

fail() { echo "ERROR: $*" >&2; exit 1; }
require_root() { [ "$(id -u)" -eq 0 ] || fail "Run as root"; }

usage() {
  cat <<EOF
Usage: sudo $0 [--provider localhostrun] [--user <relay-user>] [--local-port <port>] [--remote-port <port>]

Examples:
  sudo $0 --provider localhostrun
  sudo LOCAL_HTTP_PORT=8080 REMOTE_HTTP_PORT=0 $0 --provider localhostrun

This installer will create a systemd service that runs an HTTP tunnel via localhost.run
as an unprivileged user. No SSH login is required.
EOF
  exit 1
}

# -------------------- parse args --------------------
if [ "$#" -eq 0 ]; then
  usage
fi
while [ "$#" -gt 0 ]; do
  case "$1" in
    --provider)
      shift; [ $# -ge 1 ] || usage
      PROVIDER="$1"; shift;;
    --user)
      shift; [ $# -ge 1 ] || usage
      RELAY_USER="$1"; shift;;
    --local-port)
      shift; [ $# -ge 1 ] || usage
      LOCAL_HTTP_PORT="$1"; shift;;
    --remote-port)
      shift; [ $# -ge 1 ] || usage
      REMOTE_HTTP_PORT="$1"; shift;;
    -h|--help)
      usage;;
    *)
      echo "Unknown arg: $1" >&2; usage;;
  esac
done

require_root

# -------------------- stop and remove previous service/user/processes --------------------
cleanup_previous() {
  if systemctl list-units --full -all | grep -q "${SERVICE_NAME}"; then
    systemctl stop "${SERVICE_NAME}" || true
    systemctl disable "${SERVICE_NAME}" || true
    rm -f "/etc/systemd/system/${SERVICE_NAME}"
    systemctl daemon-reload
    echo "Removed previous service: ${SERVICE_NAME}"
  fi

  if id -u "$RELAY_USER" >/dev/null 2>&1; then
    echo "User $RELAY_USER already exists — stopping processes and removing old user"
    pkill -u "$RELAY_USER" || true
    userdel -r "$RELAY_USER" || true
  fi
}

cleanup_previous

# -------------------- create relay user --------------------
create_relay_user() {
  useradd -m -s /usr/sbin/nologin "$RELAY_USER" || useradd -m -s /bin/false "$RELAY_USER"
  echo "Created user $RELAY_USER"
  mkdir -p /home/"$RELAY_USER"/.ssh
  chown "$RELAY_USER":"$RELAY_USER" /home/"$RELAY_USER"/.ssh
  chmod 700 /home/"$RELAY_USER"/.ssh
}

# -------------------- build-scripts tunnel command --------------------
build_cmd_for_provider() {
  case "$PROVIDER" in
    localhostrun)
      # localhost.run HTTP tunnel (anonymous, no SSH login)
      TUNNEL_CMD="curl -s https://localhost.run/${LOCAL_HTTP_PORT}:${REMOTE_HTTP_PORT} &"
      ;;
    "")
      fail "No provider selected."
      ;;
    *)
      fail "Unknown provider: $PROVIDER"
      ;;
  esac
}

if [ -n "$PROVIDER" ]; then
  build_cmd_for_provider
fi

# -------------------- write systemd unit --------------------
write_systemd_service() {
  SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
  ESCAPED_CMD=${TUNNEL_CMD//%/%%}

  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=TermRelay generic HTTP tunnel (runs provided tunnel/agent command)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$RELAY_USER
Environment="LOCAL_HTTP_PORT=$LOCAL_HTTP_PORT" "REMOTE_HTTP_PORT=$REMOTE_HTTP_PORT"
ExecStart=/bin/sh -lc 'exec $ESCAPED_CMD'
Restart=always
RestartSec=5
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

  chmod 644 "$SERVICE_PATH"
  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}"
}

# -------------------- run --------------------
create_relay_user
write_systemd_service

# final message
cat <<EOS
OK — systemd service installed: ${SERVICE_NAME}
Service runs as user: ${RELAY_USER}
Forwarding local HTTP port ${LOCAL_HTTP_PORT} to remote port ${REMOTE_HTTP_PORT} on localhost.run
To follow the tunnel output, run:
  journalctl -u ${SERVICE_NAME} -f

EOS

exit 0
