#!/bin/bash
# Script to mount USB flash and read local scripts

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

# Mount partition
mount_point="/mnt/usbdata"
sudo mkdir -p "$mount_point"
sudo mount "$data_part" "$mount_point"

echo "Partition mounted at $mount_point"

# Check if folder exists
script_folder="$mount_point/shell-scripts/linux-setup"
if [ -d "$script_folder" ]; then
    echo "Your scripts are here:"
    ls "$script_folder"
else
    echo "Folder shell-scripts/linux-setup not found on this partition."
fi

echo "Done. You can now access your scripts at $script_folder"
