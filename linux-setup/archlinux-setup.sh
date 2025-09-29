#!/usr/bin/env bash
# File: archlinux-setup.sh
# Purpose: Minimal Arch Linux setup for VirtualBox VM with XFCE
# Handles partial disk usage to save host space
# Run as root

set -e

DISK="/dev/sda"
ROOT_SIZE="20G"   # Размер root-раздела, оставляем остальное свободным
HOSTNAME="arch-vm"
USERNAME="user"
PASSWORD="password"

echo "=== Preparing disk $DISK with $ROOT_SIZE root partition ==="

# Удаляем старые таблицы разделов (если есть)
parted --script "$DISK" mklabel gpt

# Создаём ESP для UEFI
parted --script "$DISK" mkpart ESP fat32 1MiB 513MiB
parted --script "$DISK" set 1 esp on

# Создаём root-раздел (только часть диска, не всю)
parted --script "$DISK" mkpart primary ext4 513MiB $ROOT_SIZE

# Форматируем разделы
mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -F "${DISK}2"

# Монтируем root и ESP
mount "${DISK}2" /mnt
mount --mkdir "${DISK}1" /mnt/boot

echo "=== Disk mounted. Remaining free space: $(parted $DISK print free | grep 'Free Space') ==="

echo "=== Minimal system installation ==="
pacstrap -K /mnt base linux linux-firmware vim networkmanager

echo "=== Generating fstab ==="
genfstab -U /mnt >> /mnt/etc/fstab

echo "=== Chroot configuration ==="
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname
cat <<EOT > /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    $HOSTNAME.localdomain $HOSTNAME
EOT

systemctl enable NetworkManager

# Set root password
echo "root:$PASSWORD" | chpasswd

# Create user
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Install bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Install minimal GUI (XFCE)
pacman -S --noconfirm xorg-server xorg-xinit xfce4 xfce4-terminal lightdm lightdm-gtk-greeter
systemctl enable lightdm.service

# VirtualBox Guest Additions
pacman -S --noconfirm virtualbox-guest-utils
systemctl enable vboxservice
EOF

echo "=== Minimal Arch Linux setup complete! Reboot recommended. ==="
