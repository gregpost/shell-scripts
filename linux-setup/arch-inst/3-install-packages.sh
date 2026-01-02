#!/bin/bash
set -e

clear
read -p "Путь к папке с zst-файлами [/mnt/usb/data/pacman-repo]: " repo_path
repo_path=${repo_path:-/mnt/usb/data/pacman-repo}

read -p "Путь к точке монтирования [/mnt/root]: " mount_point
mount_point=${mount_point:-/mnt/root}

cd "$repo_path"
pacstrap -U "$mount_point" *.zst
