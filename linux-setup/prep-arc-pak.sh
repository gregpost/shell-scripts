#!/usr/bin/env bash
# Arch Linux: Create local package cache for offline installation
set -e

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: скрипт нужно запускать от root!"
    exit 1
fi

# Папка для локального хранилища пакетов
LOCAL_REPO="./arc-repo"
mkdir -p "$LOCAL_REPO"

echo
echo "=================================================="
echo "=== Step 1: Updating package database ==="
echo "=================================================="
pacman -Sy --noconfirm

echo
echo "=================================================="
echo "=== Step 2: Packages list to download ==="
echo "=================================================="

# Базовые пакеты из твоего скрипта
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
for pkg in "${PACKAGES[@]}"; do
    echo "Downloading $pkg..."
    pacman -Sw --cachedir "$LOCAL_REPO" --noconfirm "$pkg"
done

echo
echo "=================================================="
echo "=== Step 4: Optional - create local repo database ==="
echo "=================================================="

# Создаем локальный репозиторий
repo-add "$LOCAL_REPO/local.db.tar.gz" "$LOCAL_REPO"/*.pkg.tar.zst

echo
echo "=================================================="
echo "=== Done! Local package repository created at $LOCAL_REPO ==="
echo "You can use it in your offline installation by adding:"
echo "[local]"
echo "SigLevel = Optional TrustedOnly"
echo "Server = file://$LOCAL_REPO"
echo "to /etc/pacman.conf"
echo "=================================================="
