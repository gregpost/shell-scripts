#!/bin/bash
# File: mount-usb.sh
# Script to mount USB flash

set -e

echo "=== Searching for USB flash with data partition ==="

# List removable drives
mapfile -t usb_drives < <(lsblk -dpno NAME,RM | awk '$2==1 {print $1}')

if [ ${#usb_drives[@]} -eq 0 ]; then
    echo "No removable USB drives detected. Insert your USB and try again."
    exit 1
fi

echo "Detected USB drives:"
for i in "${!usb_drives[@]}"; do
    echo "$((i+1))) ${usb_drives[$i]}"
done

# Ask user to choose USB
read -rp "Enter the number of your USB drive: " usb_num
usb_device="${usb_drives[$((usb_num-1))]}"

if [ ! -b "$usb_device" ]; then
    echo "Invalid selection."
    exit 1
fi

echo "Selected USB: $usb_device"

# List partitions
mapfile -t partitions < <(lsblk -ln -o NAME,TYPE "$usb_device" | awk '$2=="part" {print "/dev/" $1}')

if [ ${#partitions[@]} -eq 0 ]; then
    echo "No partitions found on $usb_device"
    exit 1
fi

echo "Detected partitions:"
for i in "${!partitions[@]}"; do
    echo "$((i+1))) ${partitions[$i]}"
done

read -rp "Enter the number of the partition that contains your data: " part_num
data_part="${partitions[$((part_num-1))]}"

if [ ! -b "$data_part" ]; then
    echo "Invalid partition selection."
    exit 1
fi

# Ask user for mount point
read -rp "Enter mount point path (or press Enter for default /mnt/usbdata): " custom_mount_point
mount_point="${custom_mount_point:-/mnt/usbdata}"

# Create and mount partition
sudo mkdir -p "$mount_point"

# Check if mount point is already in use
if mountpoint -q "$mount_point"; then
    echo "Mount point $mount_point is already in use. Attempting to unmount..."
    sudo umount "$mount_point"
fi

sudo mount "$data_part" "$mount_point"

echo "Partition $data_part mounted at $mount_point"

# Show mounted contents
echo "Available contents:"
ls -la "$mount_point"