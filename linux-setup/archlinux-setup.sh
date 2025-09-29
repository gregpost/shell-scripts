#!/usr/bin/env bash
# File: setup-arch-vbox-min.sh
# Purpose: Minimal Arch Linux setup for VirtualBox VM with GNOME, low disk usage
# Run as root

set -e

echo "=== Minimal Arch Linux setup for VirtualBox ==="

# 0. Update system
echo "[0/8] Updating system..."
pacman -Syu --noconfirm

# 1. Set timezone
echo "[1/8] Setting timezone to Europe/Moscow..."
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# 2. Configure locale
echo "[2/8] Setting locale to en_US.UTF-8..."
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 3. Set console keymap
echo "[3/8] Setting console keymap to US..."
echo "KEYMAP=us" > /etc/vconsole.conf

# 4. Set hostname
echo "[4/8] Setting hostname..."
read -rp "Enter hostname: " HOSTNAME
echo "$HOSTNAME" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    $HOSTNAME.localdomain $HOSTNAME
EOF

# 5. Network setup
echo "[5/8] Installing and enabling NetworkManager..."
pacman -Sy --noconfirm networkmanager
systemctl enable NetworkManager

# 6. Minimal graphical interface
echo "[6/8] Installing Xorg minimal..."
pacman -S --noconfirm xorg-server xorg-xinit xorg-drivers

echo "[7/8] Installing minimal GNOME..."
pacman -S --noconfirm gnome gdm

echo "[8/8] Installing VirtualBox Guest Additions..."
pacman -S --noconfirm virtualbox-guest-utils virtualbox-guest-dkms linux-headers
systemctl enable gdm.service vboxservice

echo "=== Minimal VirtualBox setup complete! Reboot recommended. ==="
