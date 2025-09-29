#!/usr/bin/env bash
# Arch Linux setup on VirtualBox with XFCE (based on official guide)
set -e

DISK="/dev/sda"
HOSTNAME="arch-vm"
MOUNTPOINT="/mnt"

echo "=== Step 1: Partition & Format Disk ==="

# Разделы создаём только если их нет
if ! blkid "${DISK}2" >/dev/null 2>&1; then
    echo "Создаём GPT и разделы..."
    parted --script "$DISK" mklabel gpt
    parted --script "$DISK" mkpart ESP fat32 1MiB 513MiB
    parted --script "$DISK" set 1 esp on
    parted --script "$DISK" mkpart primary ext4 513MiB 100%
else
    echo "Разделы уже существуют, форматирование пропускаем"
fi

# Форматируем только если разделы не смонтированы
if ! mount | grep -q "${DISK}1"; then
    echo "Форматируем EFI-раздел..."
    mkfs.fat -F32 -n EFI "${DISK}1"
else
    echo "${DISK}1 уже смонтирован, форматирование пропускаем"
fi

if ! mount | grep -q "${DISK}2"; then
    echo "Форматируем ROOT-раздел..."
    mkfs.ext4 -F -L ROOT "${DISK}2"
else
    echo "${DISK}2 уже смонтирован, форматирование пропускаем"
fi

echo "=== Step 2: Mount Disk ==="
mount --mkdir "${DISK}2" "$MOUNTPOINT"
mount --mkdir "${DISK}1" "$MOUNTPOINT/boot"

echo "=== Step 3: Install Base System ==="
pacstrap -K "$MOUNTPOINT" base linux linux-firmware mkinitcpio

echo "=== Step 4: Generate fstab ==="
genfstab -U "$MOUNTPOINT" >> "$MOUNTPOINT/etc/fstab"

echo "=== Step 5: Chroot configuration ==="
arch-chroot "$MOUNTPOINT" <<EOF
# Timezone
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Locale
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname
if ! grep -q "$HOSTNAME" /etc/hosts; then
cat <<EOT > /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    $HOSTNAME.localdomain $HOSTNAME
EOT
fi

# Root password (если ещё не установлен)
if ! grep -q root /etc/shadow; then
    echo "Set root password:"
    passwd
fi

# Network + mc
pacman -S --noconfirm networkmanager iptables mc
systemctl enable NetworkManager

# Bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

# Optional: user
read -rp "Enter new username (leave empty to skip): " USERNAME
if [ -n "$USERNAME" ]; then
    if ! id "$USERNAME" >/dev/null 2>&1; then
        arch-chroot "$MOUNTPOINT" useradd -m -G wheel -s /bin/bash "$USERNAME"
        echo "Set password for $USERNAME:"
        arch-chroot "$MOUNTPOINT" passwd "$USERNAME"
        echo "%wheel ALL=(ALL) ALL" | arch-chroot "$MOUNTPOINT" tee /etc/sudoers.d/wheel
    else
        echo "Пользователь $USERNAME уже существует, пропускаем"
    fi
fi

# Optional: GUI
read -rp "Install XFCE + LightDM? (y/N): " GUI
if [[ "$GUI" =~ ^[Yy]$ ]]; then
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm xorg-server xorg-xinit xfce4 xfce4-terminal lightdm lightdm-gtk-greeter
    arch-chroot "$MOUNTPOINT" systemctl enable lightdm.service
fi

echo "=== Arch Linux installation complete! Reboot recommended. ==="
