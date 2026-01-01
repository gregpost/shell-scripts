#!/bin/bash

# Функция для запроса пути с значением по умолчанию
ask_path() {
    local prompt="$1"
    local default="$2"
    
    read -p "$prompt [$default]: " user_input
    if [ -z "$user_input" ]; then
        echo "$default"
    else
        echo "$user_input"
    fi
}

# Запрашиваем пути
TAR_GZ_PATH=$(ask_path "Введите путь к tar.gz архиву" "./local.db.tar.gz")
MOUNT_POINT=$(ask_path "Введите точку монтирования HDD" "/mnt")

# Создаем случайное имя для временной папки
TEMP_DIR="$MOUNT_POINT/tmp/$(date +%s%N | md5sum | head -c 8)"
echo "Создаем временную директорию: $TEMP_DIR"

# Создаем временную директорию
mkdir -p "$TEMP_DIR"

# Разархивируем tar.gz
echo "Распаковываем архив..."
tar -xzf "$TAR_GZ_PATH" -C "$TEMP_DIR"

# Находим все .zst архивы внутри и распаковываем их
echo "Распаковываем внутренние архивы..."
find "$TEMP_DIR" -name "*.zst" -type f -exec tar -xf {} -C "$TEMP_DIR" \;

# Создаем локальный репозиторий в точке монтирования
REPO_DIR="$MOUNT_POINT/local-repo"
mkdir -p "$REPO_DIR"

# Копируем все пакеты в репозиторий
echo "Копируем пакеты в репозиторий..."
find "$TEMP_DIR" -name "*.pkg.tar.zst" -type f -exec cp {} "$REPO_DIR" \;

# Создаем базу данных репозитория
echo "Создаем базу данных репозитория..."
cd "$REPO_DIR"
repo-add local-repo.db.tar.gz *.pkg.tar.zst

# Добавляем репозиторий в pacman.conf системы на HDD
echo "Добавляем репозиторий в систему..."
PACMAN_CONF="$MOUNT_POINT/etc/pacman.conf"
if [ -f "$PACMAN_CONF" ]; then
    echo -e "\n[local-repo]\nSigLevel = Optional TrustAll\nServer = file://$REPO_DIR" >> "$PACMAN_CONF"
fi

# Устанавливаем пакеты на систему в точке монтирования
echo "Устанавливаем пакеты..."
arch-chroot "$MOUNT_POINT" pacman -Sy --noconfirm
arch-chroot "$MOUNT_POINT" pacman -S --noconfirm $(pacman --root "$MOUNT_POINT" --sysroot "$MOUNT_POINT" -Sl local-repo 2>/dev/null | awk '{print $2}')

# Очищаем временную директорию
echo "Очищаем временную директорию..."
rm -rf "$TEMP_DIR"

echo "Готово!"
