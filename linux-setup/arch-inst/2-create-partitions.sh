#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

clear
echo -e "${NC}===BTRFS Setup ==="
echo

DEFAULT_DEVICE='/dev/sda'
read -p "Input device name for EFI/BTRFS partitions creating (press Enter to use ${DEFAULT_DEVICE}): " DEVICE
DEVICE=${DEVICE:-${DEFAULT_DEVICE}}
echo

echo "Choosed device: $DEVICE"
echo

DEFAULT_ROOT_DIR='/mnt/root'
read -p "Input mount point path (press Enter to use ${DEFAULT_ROOT_DIR}): " ROOT_DIR
ROOT_DIR=${ROOT_DIR:-${DEFAULT_ROOT_DIR}}
mkdir -p "${ROOT_DIR}"

echo
echo "Choosed mount point: $ROOT_DIR"
echo

# 1. Labeling (512M EFI + all free space for BTRFS) 
echo -e  "${GREEN}Disk labeling...${NC}"
parted -s "$DEVICE" mklabel gpt
parted -s "$DEVICE" mkpart ESP fat32 1MiB 513Mib
parted -s "$DEVICE" set 1 esp on
parted -s "$DEVICE" mkpart primary btrfs 513MiB 100%
sync
partprobe "$DEVICE"
sleep 2

# 2. Formatting
echo -e "${GREEN} Formatting...${NC}"
mkfs.fat -F32 "${DEVICE}1"
mkfs.btrfs -f "${DEVICE}2"

# 3. Subvolumes creating
echo -e "${GREEN} Creating of BTRFS subvolumes...${NC}"
mount "${DEVICE}2" ${ROOT_DIR}
btrfs subvolume create ${ROOT_DIR}/@
btrfs subvolume create ${ROOT_DIR}/@home
btrfs subvolume create ${ROOT_DIR}/@varlog
btrfs subvolume create ${ROOT_DIR}/@varcache
umount ${ROOT_DIR}

# 4. Mounting
echo -e "${GREEN} Mounting...${NC}"
mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@ "${DEVICE}2" ${ROOT_DIR}
mkdir -p ${ROOT_DIR}/{boot/efi,home,var/{log,cache/pacman/pkg}}
mount "${DEVICE}1" ${ROOT_DIR}/boot/efi
mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@home "${DEVICE}2" ${ROOT_DIR}/home
mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@varlog "${DEVICE}2" ${ROOT_DIR}/var/log
mount -o noatime,compress=zstd:1,space_cache=v2,subvol=@varcache "${DEVICE}2" ${ROOT_DIR}/var/cache/pacman/pkg

# 5. Setup base system
