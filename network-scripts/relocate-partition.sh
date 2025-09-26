#!/bin/bash
#
# File: relocate_partition.sh
# Description: Remounts a partition currently auto-mounted by label "data_fs" to /data, unmounting any busy mount if needed, and updates /etc/fstab.
#

set -e

TARGET="/data"
LABEL="data_fs"

echo "📌 Starting partition relocation script..."
echo "📌 Target mount point: $TARGET"
echo "📌 Target label: $LABEL"

# Create mount point
if [ ! -d "$TARGET" ]; then
    echo "📌 Mount point $TARGET does not exist. Creating..."
    sudo mkdir -p "$TARGET"
    echo "✅ Created mount point $TARGET"
else
    echo "📌 Mount point $TARGET already exists."
fi

# Find the device with label
echo "📌 Searching for device with label $LABEL..."
DEVICE=$(blkid -o device -t LABEL=$LABEL)
if [ -z "$DEVICE" ]; then
    echo "❌ Device with label $LABEL not found."
    exit 1
fi
echo "✅ Found device: $DEVICE"

# Find current mount point
echo "📌 Checking if device is currently mounted..."
CURRENT_MOUNT=$(findmnt -n -o TARGET "$DEVICE" || true)
if [ -n "$CURRENT_MOUNT" ]; then
    echo "📌 Device currently mounted at: $CURRENT_MOUNT"
    echo "📌 Attempting lazy unmount..."
    sudo umount -l "$CURRENT_MOUNT"
    echo "✅ Successfully unmounted $CURRENT_MOUNT"
else
    echo "📌 Device is not currently mounted."
fi

# Backup fstab
echo "📌 Backing up /etc/fstab..."
sudo cp /etc/fstab /etc/fstab.bak
echo "✅ /etc/fstab backed up to /etc/fstab.bak"

# Remove old fstab entry for this device
echo "📌 Removing any old fstab entry for $DEVICE..."
sudo sed -i "\|$DEVICE|d" /etc/fstab
echo "✅ Old fstab entries removed (if any)"

# Add new fstab entry using LABEL
echo "📌 Adding new fstab entry..."
echo "LABEL=$LABEL  $TARGET  ext4  defaults  0  2" | sudo tee -a /etc/fstab
echo "✅ New fstab entry added"

# Mount at new location
echo "📌 Mounting $TARGET..."
sudo mount "$TARGET"
echo "✅ Partition mounted at $TARGET"

# Show new mount
echo "📌 Current mount information for $TARGET:"
mount | grep "$TARGET"
echo "📌 Partition relocation completed successfully."

