#!/usr/bin/env bash
# connect_kontakt.sh
# Подключиться к Wi‑Fi (Arch Linux). Поддерживает nmcli или wpa_supplicant+dhcpcd fallback.
# Вводит SSID и пароль интерактивно. При отсутствии утилит предлагает команду pacman для установки.

set -euo pipefail

readonly LOG="/tmp/connect_kontakt.log"
: >"$LOG"

echo "# connect_kontakt $(date)" | tee -a "$LOG"

# Read SSID/password (default SSID = KONTAKT)
read -r -p "SSID (default: KONTAKT): " SSID
SSID=${SSID:-KONTAKT}
read -rs -p "Password for \"$SSID\": " WIFI_PASS
echo
echo

echo "Using SSID='$SSID'" | tee -a "$LOG"

# Helpers
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# Detect wireless interface (try iw, ip)
detect_iface() {
  local iface
  if has_cmd iw; then
    iface=$(iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}')
    [ -n "$iface" ] && echo "$iface" && return 0
  fi
  # fallback: try ip link pattern wlan or wlp
  iface=$(ip -o link show | awk -F': ' '{print $2}' | egrep '^(wlan|wlp|wl)' | head -n1 || true)
  if [ -n "$iface" ]; then
    echo "$iface" && return 0
  fi
  return 1
}

# Offer installation (or auto-install if run as root and confirmed)
offer_install() {
  local pkg=$1
  if has_cmd pacman; then
    echo "Package '$pkg' is missing. To install on Arch run:"
    echo "  sudo pacman -S --needed $pkg"
    if [ "$EUID" -eq 0 ]; then
      read -r -p "Install $pkg now with pacman? [y/N]: " yn
      if [[ "$yn" =~ ^[Yy] ]]; then
        pacman -S --noconfirm --needed $pkg
      fi
    fi
  else
    echo "Package '$pkg' is missing. Please install it (e.g. pacman -S $pkg) and re-run the script."
  fi
}

# Try nmcli method
try_nmcli() {
  echo "[*] Trying nmcli method..." | tee -a "$LOG"
  if ! has_cmd nmcli; then
    offer_install "networkmanager"
    return 1
  fi

  # ensure NetworkManager running (only try to start if root)
  if ! nmcli general status >/dev/null 2>&1; then
    if [ "$EUID" -eq 0 ]; then
      echo "[i] NetworkManager not running — пытаюсь запустить systemctl start NetworkManager" | tee -a "$LOG"
      systemctl start NetworkManager || true
      sleep 1
    else
      echo "[!] NetworkManager не запущен. Запустите его: sudo systemctl start NetworkManager" | tee -a "$LOG"
    fi
  fi

  # Create/modify connection
  if nmcli device wifi connect "$SSID" password "$WIFI_PASS" >/dev/null 2>&1; then
    echo "[OK] nmcli: подключено к '$SSID'." | tee -a "$LOG"
    nmcli -t -f ACTIVE,SSID,DEVICE connection show --active | tee -a "$LOG"
    return 0
  else
    echo "[!] nmcli: не удалось подключиться к '$SSID'." | tee -a "$LOG"
    return 1
  fi
}

# Try wpa_supplicant + dhcpcd
try_wpa() {
  echo "[*] Trying wpa_supplicant + dhcpcd method..." | tee -a "$LOG"

  for cmd in wpa_passphrase wpa_supplicant dhcpcd; do
    if ! has_cmd "$cmd"; then
      offer_install "wpa_supplicant dhcpcd"
      return 1
    fi
  done

  IFACE=$(detect_iface || true)
  if [ -z "${IFACE:-}" ]; then
    echo "[!] Не удалось определить беспроводной интерфейс. Укажите вручную (пример: wlp2s0)" | tee -a "$LOG"
    read -r -p "Wireless interface: " IFACE
    if [ -z "$IFACE" ]; then
      echo "Интерфейс не указан. Выход." | tee -a "$LOG"
      return 1
    fi
  fi

  TMP_CONF="/tmp/wpa_supplicant_${IFACE}_${SSID}.conf"
  echo "[i] Создаю временный wpa_supplicant конфиг $TMP_CONF" | tee -a "$LOG"
  wpa_passphrase "$SSID" "$WIFI_PASS" > "$TMP_CONF"

  echo "[i] Останавливаю NetworkManager (если мешает)" | tee -a "$LOG"
  if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    if [ "$EUID" -eq 0 ]; then
      systemctl stop NetworkManager || true
    else
      echo "[!] NetworkManager активен — возможно мешает. Остановите его: sudo systemctl stop NetworkManager" | tee -a "$LOG"
    fi
  fi

  echo "[i] Запускаю wpa_supplicant (foreground -> background) on $IFACE" | tee -a "$LOG"
  if [ "$EUID" -eq 0 ]; then
    # run as daemon for the iface
    if wpa_supplicant -B -i "$IFACE" -c "$TMP_CONF"; then
      echo "[i] wpa_supplicant запущен." | tee -a "$LOG"
    else
      echo "[!] wpa_supplicant не смог подключиться." | tee -a "$LOG"
      return 1
    fi

    echo "[i] Запрашиваю IP через dhcpcd на $IFACE" | tee -a "$LOG"
    dhcpcd "$IFACE"
    sleep 2
    ip addr show dev "$IFACE" | tee -a "$LOG"
    ping -c 3 -W 2 1.1.1.1 >/dev/null 2>&1 && echo "[OK] Пингуется 1.1.1.1" | tee -a "$LOG" || echo "[!] Не пингуется" | tee -a "$LOG"
    return 0
  else
    echo "[!] Для использования wpa_supplicant автоматом требуется root. Запустите скрипт с sudo." | tee -a "$LOG"
    return 1
  fi
}

# Main flow
if try_nmcli; then
  echo "Connected via nmcli." | tee -a "$LOG"
  exit 0
fi

echo "[i] nmcli method не сработал, пробую wpa_supplicant..." | tee -a "$LOG"

if try_wpa; then
  echo "Connected via wpa_supplicant." | tee -a "$LOG"
  exit 0
fi

echo "[!] Не удалось подключиться автоматически. Лог: $LOG" | tee -a "$LOG"
echo "Возможные дальнейшие шаги:"
echo " - Убедитесь, что SSID и пароль верны."
echo " - Проверьте видимость сети: sudo iw dev <iface> scan | grep -i '$SSID'"
echo " - Посмотрите журнал: journalctl -u NetworkManager -e"
echo " - Попробуйте подключиться вручную через nm-applet или другое GUI."
exit 2
