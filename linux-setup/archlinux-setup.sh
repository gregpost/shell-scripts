#!/usr/bin/env bash
# Arch Linux safe installer with partition number selection and confirmation
set -e

MOUNTPOINT="/mnt"

echo "=== Step 1: Show available disks ==="
DISKS=($(lsblk -dno NAME,SIZE))   # получаем список: NAME SIZE NAME SIZE ...

# Формируем нумерованный список
i=1
for ((j=0; j<${#DISKS[@]}; j+=2)); do
    NAME="${DISKS[j]}"
    SIZE="${DISKS[j+1]}"
    echo "$i) /dev/$NAME  ($SIZE)"
    ((i++))
done

# Выбор по номеру
read -rp "Enter the disk number to install: " DISKNUM
INDEX=$(( (DISKNUM - 1) * 2 ))

if [ $INDEX -lt 0 ] || [ $INDEX -ge ${#DISKS[@]} ]; then
    echo "Error: invalid disk number"
    exit 1
fi

DISK="/dev/${DISKS[$INDEX]}"

# Показываем выбранный диск и информацию о нём
echo "You selected disk: $DISK"
lsblk "$DISK" -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL

# Подтверждение
read -rp "Are you sure you want to use this disk? All data on it may be lost! (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Installation aborted by user."
    exit 0
fi

echo "=== Step 2: Partition & Format Disk ==="
# Partitioning (GPT + EFI + root) if not exists
if ! blkid "${DISK}2" >/dev/null 2>&1; then
    echo "Creating GPT and partitions..."
    parted --script "$DISK" mklabel gpt
    parted --script "$DISK" mkpart ESP fat32 1MiB 513MiB
    parted --script "$DISK" set 1 esp on
    parted --script "$DISK" mkpart primary ext4 513MiB 100%
else
    echo "Partitions already exist, skipping partitioning"
fi

# Format if not mounted
if ! mount | grep -q "${DISK}1"; then
    echo "Formatting EFI partition..."
    mkfs.fat -F32 -n EFI "${DISK}1"
else
    echo "EFI partition already mounted, skipping formatting"
fi

if ! mount | grep -q "${DISK}2"; then
    echo "Formatting ROOT partition..."
    mkfs.ext4 -F -L ROOT "${DISK}2"
else
    echo "ROOT partition already mounted, skipping formatting"
fi

echo "=== Step 3: Mount partitions ==="
mount --mkdir "${DISK}2" "$MOUNTPOINT"
mount --mkdir "${DISK}1" "$MOUNTPOINT/boot"

echo "=== Step 4: Install base system if not installed ==="
if [ ! -f "$MOUNTPOINT/etc/arch-release" ]; then
    echo "Installing base system..."
    pacstrap -K "$MOUNTPOINT" base linux linux-firmware mkinitcpio
else
    echo "Base system already installed, skipping pacstrap"
fi

echo "=== Step 5: Generate fstab ==="
if [ ! -f "$MOUNTPOINT/etc/fstab" ] || ! grep -q "${DISK}2" "$MOUNTPOINT/etc/fstab"; then
    genfstab -U "$MOUNTPOINT" >> "$MOUNTPOINT/etc/fstab"
    echo "fstab generated"
else
    echo "fstab already exists, skipping"
fi

echo "=== Step 6: Chroot configuration (packages, user, GUI) ==="
arch-chroot "$MOUNTPOINT" bash <<'EOF'
set -e

# Timezone
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Locale
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# Hostname
HOSTNAME="arch-vm"
echo "$HOSTNAME" > /etc/hostname
if ! grep -q "$HOSTNAME" /etc/hosts; then
cat <<EOT > /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    $HOSTNAME.localdomain $HOSTNAME
EOT
fi

# Root password (ask only if empty)
if ! grep -q root /etc/shadow; then
    echo "Set root password:"
    passwd
fi

# Network + utilities (mc, nano)
pacman -S --needed --noconfirm networkmanager iptables mc nano

systemctl enable NetworkManager

# Bootloader
if [ ! -d /boot/grub ]; then
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
fi

# VirtualBox detection and Guest Additions
if systemd-detect-virt | grep -iq virtualbox; then
    echo "Detected VirtualBox, installing guest-utils..."
    pacman -S --needed --noconfirm virtualbox-guest-utils
    systemctl enable vboxservice
fi
EOF

# Optional: create user if not exists
read -rp "Enter new username (leave empty to skip): " USERNAME
if [ -n "$USERNAME" ]; then
    if ! arch-chroot "$MOUNTPOINT" id "$USERNAME" >/dev/null 2>&1; then
        arch-chroot "$MOUNTPOINT" useradd -m -G wheel -s /bin/bash "$USERNAME"
        echo "Set password for $USERNAME:"
        arch-chroot "$MOUNTPOINT" passwd "$USERNAME"
        echo "%wheel ALL=(ALL) ALL" | arch-chroot "$MOUNTPOINT" tee /etc/sudoers.d/wheel
    else
        echo "User $USERNAME already exists, skipping"
    fi
fi

# Optional: install XFCE GUI
read -rp "Install XFCE + LightDM? (y/N): " GUI
if [[ "$GUI" =~ ^[Yy]$ ]]; then
    arch-chroot "$MOUNTPOINT" pacman -S --needed --noconfirm xorg-server xorg-xinit xfce4 xfce4-terminal lightdm lightdm-gtk-greeter
    arch-chroot "$MOUNTPOINT" systemctl enable lightdm.service
fi

echo "=== Arch Linux installation complete! Reboot to use your persistent system ==="
