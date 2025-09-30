#!/usr/bin/env bash
# Arch Linux safe installer with partition number selection, confirmation, logging, and optional GUI
set -e

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: скрипт нужно запускать от root!"
    echo "Используйте: sudo $0"
    exit 1
fi

echo
echo "=================================================="
echo "=== Step 1: LOG FILE SETUP ==="
echo "=================================================="
echo

LOGFILE="/shared/log.txt"
mkdir -p "$(dirname "$LOGFILE")"

# Очистка предыдущего лога перед запуском скрипта
> "$LOGFILE"

# Перенаправление всего вывода в лог и на экран
exec > >(tee -a "$LOGFILE") 2>&1
##################################################

echo
echo "=================================================="
echo "=== Step 2: CHECK IF /MNT IS EMPTY ==="
echo "=================================================="
echo

MOUNTPOINT="/mnt"

# Проверяем, есть ли что-то смонтированное или файлы в /mnt
if mountpoint -q "$MOUNTPOINT" || [ "$(ls -A "$MOUNTPOINT" 2>/dev/null)" ]; then
    echo
    echo "=================================================="
    echo "WARNING: $MOUNTPOINT is not empty! Previous installation data may exist."
    echo "You can clean or unmount this partition before proceeding."
    echo "=================================================="
    read -rp "Do you want to unmount and clean $MOUNTPOINT? (yes/no): " CLEANMNT
    if [[ "$CLEANMNT" == "yes" ]]; then
        echo "Unmounting all mounts under $MOUNTPOINT..."
        umount -Rl "$MOUNTPOINT" || echo "Warning: Some mounts could not be unmounted."
        rm -rf "${MOUNTPOINT:?}/"*
        echo "$MOUNTPOINT is now clean and ready for installation."
        mkdir -p "$MOUNTPOINT"
    else
        echo "Installation aborted. Please manually clean or unmount $MOUNTPOINT."
        exit 1
    fi
fi

echo
echo "=================================================="
echo "=== Step 3: Start Arch Linux installer ==="
echo "=================================================="
echo

echo
echo "=================================================="
echo "=== Step 4: Show available disks ==="
echo "=================================================="
echo
DISKS=($(lsblk -dno NAME,SIZE))
i=1
for ((j=0; j<${#DISKS[@]}; j+=2)); do
    NAME="${DISKS[j]}"
    SIZE="${DISKS[j+1]}"
    echo "$i) /dev/$NAME  ($SIZE)"
    ((i++))
done

# выбор по номеру
read -rp "Enter the disk number to install: " DISKNUM
INDEX=$(( (DISKNUM - 1) * 2 ))

if [ $INDEX -lt 0 ] || [ $INDEX -ge ${#DISKS[@]} ]; then
    echo "Error: invalid disk number"
    exit 1
fi

DISK="/dev/${DISKS[$INDEX]}"
echo
echo "You selected disk: $DISK"
lsblk "$DISK" -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL
echo
read -rp "Are you sure you want to use this disk? All data on it may be lost! (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Installation aborted by user."
    exit 0
fi

echo
echo "=================================================="
echo "=== Step 5: Partition & Format Disk ==="
echo "=================================================="
echo
if ! blkid "${DISK}2" >/dev/null 2>&1; then
    echo "Creating GPT and partitions..."
    parted --script "$DISK" mklabel gpt
    parted --script "$DISK" mkpart ESP fat32 1MiB 513MiB
    parted --script "$DISK" set 1 esp on
    parted --script "$DISK" mkpart primary ext4 513MiB 100%
else
    echo "Partitions already exist, skipping partitioning"
fi

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

echo
echo "=================================================="
echo "=== Step 6: Mount partitions ==="
echo "=================================================="
echo
mount --mkdir "${DISK}2" "$MOUNTPOINT"
mount --mkdir "${DISK}1" "$MOUNTPOINT/boot"

# Проверяем успешность монтирования
if ! mountpoint -q "$MOUNTPOINT" || ! mountpoint -q "$MOUNTPOINT/boot"; then
    echo "Error: partitions not mounted correctly!"
    exit 1
fi
echo "Partitions mounted successfully."

echo
echo "=================================================="
echo "=== Step 7: Generate fstab ==="
echo "=================================================="
echo
if [ ! -f "$MOUNTPOINT/etc/fstab" ] || ! grep -q "${DISK}2" "$MOUNTPOINT/etc/fstab"; then
    genfstab -U "$MOUNTPOINT" >> "$MOUNTPOINT/etc/fstab"
    echo "fstab generated"
else
    echo "fstab already exists, skipping"
fi

echo
echo "=================================================="
echo "=== Step 8: Chroot configuration (packages, user, GUI) ==="
echo "=================================================="
echo
arch-chroot "$MOUNTPOINT" bash <<'EOF'
set -e

echo
echo "---- Configuring timezone, locale, hostname ----"
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

HOSTNAME="arch-vm"
echo "$HOSTNAME" > /etc/hostname
if ! grep -q "$HOSTNAME" /etc/hosts; then
cat <<EOT > /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    $HOSTNAME.localdomain $HOSTNAME
EOT
fi

echo
echo "---- Setting root password ----"
if ! grep -q root /etc/shadow; then
    echo "Set root password:"
    passwd
fi

echo
echo "---- Installing bootloader ----"
if [ ! -d /boot/grub ]; then
    pacman -S --needed --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
fi

echo
echo "---- Installing VirtualBox guest utilities ----"
if systemd-detect-virt | grep -iq virtualbox; then
    pacman -S --needed --noconfirm virtualbox-guest-utils
    systemctl enable vboxservice
fi
EOF

# Optional: create user if not exists
echo
echo "=================================================="
echo "=== Step 9: Create user ==="
echo "=================================================="
echo
read -rp "Enter new username (leave empty to skip): " USERNAME
if [ -n "$USERNAME" ]; then
    if ! arch-chroot "$MOUNTPOINT" id "$USERNAME" >/dev/null 2>&1; then
        arch-chroot "$MOUNTPOINT" useradd -m -G wheel -s /bin/bash "$USERNAME"
        echo "Set password for $USERNAME:"
        arch-chroot "$MOUNTPOINT" passwd "$USERNAME"
        mkdir -p "$MOUNTPOINT/etc/sudoers.d"
        echo "%wheel ALL=(ALL) ALL" | arch-chroot "$MOUNTPOINT" tee /etc/sudoers.d/wheel
    else
        echo "User $USERNAME already exists, skipping"
    fi
fi

# Optional: install XFCE GUI
echo
echo "=================================================="
echo "=== Step 10: Install XFCE GUI (optional) ==="
echo "=================================================="
echo
read -rp "Install XFCE + LightDM? (y/N): " GUI
if [[ "$GUI" =~ ^[Yy]$ ]]; then
    arch-chroot "$MOUNTPOINT" pacman -S --needed --noconfirm xorg-server xorg-xinit xfce4 xfce4-terminal lightdm lightdm-gtk-greeter
    arch-chroot "$MOUNTPOINT" systemctl enable lightdm.service
fi

echo
echo "=================================================="
echo "=== Arch Linux installation complete! Reboot to use your persistent system ==="
echo "=================================================="
echo
