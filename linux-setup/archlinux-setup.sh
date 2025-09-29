#!/usr/bin/env bash
# File: setup-arch.sh
# Purpose: Initial setup for Arch Linux (English locale, Moscow timezone)

set -e

echo "=== Arch Linux initial setup (English, Moscow time) ==="

# Update system clock
echo "[1/6] Setting timezone to Europe/Moscow..."
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Configure locale
echo "[2/6] Setting locale to en_US.UTF-8..."
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set console keymap
echo "[3/6] Setting console keymap to US..."
echo "KEYMAP=us" > /etc/vconsole.conf

# Set hostname
echo "[4/6] Setting hostname..."
read -rp "Enter hostname: " HOSTNAME
echo "$HOSTNAME" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    $HOSTNAME.localdomain $HOSTNAME
EOF

# Network setup
echo "[5/6] Installing and enabling NetworkManager..."
pacman -Sy --noconfirm networkmanager
systemctl enable NetworkManager

# Basic utilities
echo "[6/6] Installing base packages..."
pacman -Sy --noconfirm \
    vim sudo git wget curl htop man-db man-pages base-devel

echo "=== Setup complete! Reboot recommended. ==="
