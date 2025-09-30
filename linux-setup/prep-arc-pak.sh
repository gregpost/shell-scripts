#!/usr/bin/env bash
# Arch Linux: Create local package cache for offline installation
set -e

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: скрипт нужно запускать от root!"
    exit 1
fi

# Проверка переменной LOCAL_REPO
if [ -z "$LOCAL_REPO" ]; then
    echo "Ошибка: LOCAL_REPO не задан. Укажите путь при запуске скрипта."
    echo "Пример: LOCAL_REPO=/shared/arc-repo bash prep-arc-pak.sh"
    exit 1
fi

# Папка для локального хранилища пакетов
mkdir -p "$LOCAL_REPO"
chown root:root "$LOCAL_REPO"
chmod 755 "$LOCAL_REPO"

echo
echo "=================================================="
echo "=== Step 1: Updating package database ==="
echo "=================================================="
pacman -Sy --noconfirm

echo
echo "=================================================="
echo "=== Step 2: Packages list to download ==="
echo "=================================================="

PACKAGES=(
    base
    linux
    linux-firmware
    vim
    grub
    efibootmgr
    virtualbox-guest-utils
    xorg-server
    xorg-xinit
    xfce4
    xfce4-terminal
    lightdm
    lightdm-gtk-greeter
)

echo "Packages to download:"
printf " - %s\n" "${PACKAGES[@]}"

echo
echo "=================================================="
echo "=== Step 3: Downloading packages ==="
echo "=================================================="

# Скачиваем пакеты без установки
pacman -Sw --cachedir "$LOCAL_REPO" --noconfirm "${PACKAGES[@]}"

echo
echo "=================================================="
echo "=== Step 4: Create local repo database ==="
echo "=================================================="

# Создаем локальный репозиторий
rm -f "$LOCAL_REPO/local.db"* "$LOCAL_REPO/local.files"*
repo-add "$LOCAL_REPO/local.db.tar.gz" "$LOCAL_REPO"/*.pkg.tar.zst

echo
echo "=================================================="
echo "=== Done! Local package repository created at $LOCAL_REPO ==="
echo "Add this to /etc/pacman.conf:"
echo "[local]"
echo "SigLevel = Optional TrustAll"
echo "Server = file://$LOCAL_REPO"
echo "=================================================="
