#!/usr/bin/env bash
# Arch Linux setup on VirtualBox with XFCE (based on official guide)
set -e

DISK="/dev/sda"
HOSTNAME="arch-vm"

echo "=== Step 1: Partition & Format Disk ==="
if ! blkid "${DISK}2" >/dev/null 2>&1; then
    parted --script "$DISK" mklabel gpt
    parted --script "$DISK" mkpart ESP fat32 1MiB 513MiB
    parted --script "$DISK" set 1 esp on
    parted --script "$DISK" mkpart primary ext4 513MiB 100%
fi

# Format partitions
mkfs.fat -F32 -n EFI "${DISK}1"
mkfs.ext4 -F -L ROOT "${DISK}2"

echo "=== Step 2: Mount Disk ==="
mount "${DISK}2" /mnt
mount --mkdir "${DISK}1" /mnt/boot

echo "=== Step 3: Install Base System ==="
# Явно указываем mkinitcpio как initramfs provider, чтобы не было ручного выбора
pacstrap -K /mnt base linux linux-firmware mkinitcpio

echo "=== Step 4: Generate fstab ==="
genfstab -U /mnt >> /mnt/etc/fstab

echo "=== Step 5: Chroot configuration ==="
arch-chroot /mnt << EOF
# Timezone
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Locale
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# Hostname
echo "arch-vm" > /etc/hostname
cat <<EOT > /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    arch-vm.localdomain arch-vm
EOT

# Root password
echo "Set root password:"
passwd

# Network + mc
pacman -S --noconfirm networkmanager iptables mc
systemctl enable NetworkManager

# Bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Optional: user
read -rp "Enter new username (leave empty to skip): " USERNAME
if [ -n "$USERNAME" ]; then
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "Set password for $USERNAME:"
    passwd "$USERNAME"
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
fi

# Optional: GUI
read -rp "Install XFCE + LightDM? (y/N): " GUI
if [[ "$GUI" =~ ^[Yy]$ ]]; then
    pacman -S --noconfirm xorg-server xorg-xinit xfce4 xfce4-terminal lightdm lightdm-gtk-greeter
    systemctl enable lightdm.service
fi
EOF

echo "=== Arch Linux installation complete! Reboot recommended. ==="
