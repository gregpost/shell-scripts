#!/bin/bash
#
# move-snap-folder.sh — перенос snap в новый каталог с полной переустановкой snapd.
#
# Использование:
#   ./move-snap-folder.sh [новый_путь]
#
# Опции:
#   -h, --help     Показать справку
#

set -e

show_help() {
    sed -n '2,20p' "$0"
}

# --- Обработка аргументов ---
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

NEW_SNAP_PATH="$1"

if [[ -z "$NEW_SNAP_PATH" ]]; then
    read -rp "Введите новый путь для папки snap: " NEW_SNAP_PATH
fi

if [[ -z "$NEW_SNAP_PATH" ]]; then
    echo "Ошибка: путь не указан."
    exit 1
fi

echo "Новый путь для snap будет: $NEW_SNAP_PATH"
read -rp "Продолжить? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 1

# --- Проверка sudo ---
if [[ "$EUID" -ne 0 ]]; then
    echo "Для выполнения потребуется sudo..."
    sudo -v
fi

# --- Шаг 1: Остановка сервисов snapd ---
echo "[1/6] Остановка сервисов snapd..."
sudo systemctl stop snapd.socket snapd.seeded.service snapd.service 2>/dev/null || true
sudo systemctl disable snapd.socket snapd.seeded.service snapd.service 2>/dev/null || true

# --- Шаг 2: Удаление snapd и всех snaps ---
echo "[2/6] Полное удаление snapd и всех пакетов..."
sudo apt purge --yes snapd || true

# --- Шаг 3: Очистка старых каталогов ---
echo "[3/6] Очистка старых каталогов..."
sudo rm -rf ~/snap /snap /var/snap /var/lib/snapd /var/cache/snapd

# --- Шаг 4: Создание новой папки snap ---
echo "[4/6] Создание новой папки в $NEW_SNAP_PATH..."
sudo mkdir -p "$NEW_SNAP_PATH"
sudo chown "$USER":"$USER" "$NEW_SNAP_PATH"

# создаём симлинк ~/snap → новый путь
rm -rf ~/snap
ln -s "$NEW_SNAP_PATH" ~/snap

# создаём симлинк /snap → новый путь
sudo rm -rf /snap
sudo ln -s "$NEW_SNAP_PATH" /snap

# --- Шаг 5: Очистка проблемных репозиториев ---
echo "[5/6] Проверка сторонних репозиториев..."
if ls /etc/apt/sources.list.d/mono-official*.list >/dev/null 2>&1; then
    echo "⚠️  Найден старый репозиторий Mono. Удаляю..."
    sudo rm -f /etc/apt/sources.list.d/mono-official*.list
fi

# --- Шаг 6: Переустановка snapd ---
echo "[6/6] Установка snapd заново..."
sudo apt update -y
sudo apt install --yes snapd

echo "=== Готово. Snap перенесён в $NEW_SNAP_PATH и переустановлен ==="
