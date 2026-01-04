#!/bin/bash

# Запрос пути к USB с пакетами
read -p "Путь к папке с пакетами на USB [/mnt/usb/data-pacman-repo]: " usb_path
usb_path=${usb_path:-/mnt/usb/data-pacman-repo}

# Запрос пути для копирования на HDD
read -p "Путь для локального репозитория на HDD [/mnt/root/arch-repo]: " hdd_path
hdd_path=${hdd_path:-/mnt/root/arch-repo}

# Проверка существования USB пути
if [ ! -d "$usb_path" ]; then
    echo "Ошибка: Папка $usb_path не существует!"
    exit 1
fi

# Создание директории на HDD
mkdir -p "$hdd_path"

# Копирование пакетов с USB на HDD
echo "Копирование пакетов из $usb_path в $hdd_path..."
cp -r "$usb_path"/* "$hdd_path"/ 2>/dev/null

# Проверка наличия файлов репозитория
if [ -f "$hdd_path"/localrepo.db ] || [ -f "$hdd_path"/*.db.tar.gz ]; then
    echo "Найдены файлы базы репозитория, repo-add не требуется."
else
    echo "Создание базы репозитория..."
    repo-add "$hdd_path"/localrepo.db.tar.gz "$hdd_path"/*.pkg.tar.zst 2>/dev/null
fi

# Создание временного pacman.conf
cat > /tmp/pacman-local.conf << EOF
[options]
RootDir = /mnt
DBPath = /var/lib/pacman/
CacheDir = /var/cache/pacman/pkg/

[core]
Include = /etc/pacman.d/mirrorlist

[localrepo]
SigLevel = Optional TrustAll
Server = file://$hdd_path
EOF

# Установка базовых пакетов через pacstrap
echo "Установка пакетов через pacstrap..."
pacstrap -C /tmp/pacman-local.conf /mnt base

echo "Готово! Репозиторий доступен по пути: $hdd_path"
