#!/bin/bash
# Скрипт для подключения локального pacman-репозитория
# Работает с папкой пакетов или с tar.gz архивом
# Автоматически добавляет репозиторий в /etc/pacman.conf
# По умолчанию использует RAM для временной папки

set -e

# Дефолтная папка для архивов tar.gz
DEFAULT_TAR_FOLDER="/shared"
# Дефолтное имя архива
DEFAULT_TAR_NAME="pacman-repo.tar.gz"
# Дефолтная временная папка в RAM
DEFAULT_TMP_DIR="/dev/shm/pacman-repo"

echo "Выберите источник локального репозитория:"
echo "1) Папка с пакетами"
echo "2) Архив tar.gz"
read -rp "Введите 1 или 2: " choice

# Спрашиваем, где хранить временные данные
echo "Выберите место для временных файлов (пакеты будут распакованы сюда):"
echo "1) Папка на диске"
echo "2) RAM (по умолчанию)"
read -rp "Введите 1 или 2 [по умолчанию 2]: " tmp_choice
tmp_choice=${tmp_choice:-2}

case "$tmp_choice" in
    1)
        read -rp "Введите путь для временной папки (по умолчанию: /tmp/pacman-repo): " TMP_DIR
        TMP_DIR=${TMP_DIR:-/tmp/pacman-repo}
        ;;
    2|*)
        TMP_DIR="$DEFAULT_TMP_DIR"
        ;;
esac

# Очищаем временную папку
mkdir -p "$TMP_DIR"
rm -rf "$TMP_DIR"/*
mkdir -p "$TMP_DIR"

case "$choice" in
    1)
        read -rp "Введите путь до папки с локальными пакетами (.pkg.tar.zst): " repo_path
        if [ ! -d "$repo_path" ]; then
            echo "Ошибка: папка $repo_path не существует"
            exit 1
        fi
        cp "$repo_path"/*.pkg.tar.zst "$TMP_DIR/"
        ;;
    2)
        read -rp "Введите путь к папке, где хранится архив (по умолчанию: $DEFAULT_TAR_FOLDER): " tar_folder
        tar_folder=${tar_folder:-$DEFAULT_TAR_FOLDER}

        read -rp "Введите имя архива (по умолчанию: $DEFAULT_TAR_NAME): " tar_name
        tar_name=${tar_name:-$DEFAULT_TAR_NAME}

        archive_path="$tar_folder/$tar_name"
        if [ ! -f "$archive_path" ]; then
            echo "Ошибка: файл $archive_path не существует"
            exit 1
        fi

        tar -xzf "$archive_path" -C "$TMP_DIR"
        ;;
    *)
        echo "Ошибка: нужно ввести 1 или 2"
        exit 1
        ;;
esac

# Имя репозитория
repo_name="localrepo"

# Создание базы пакетов
cd "$TMP_DIR"
repo-add "$repo_name.db.tar.gz" *.pkg.tar.zst

# Автоматическая модификация pacman.conf
conf_line="[${repo_name}]"
server_line="Server = file://$TMP_DIR"

echo "Обновляем /etc/pacman.conf (резервная копия: /etc/pacman.conf.bak)..."
sudo cp /etc/pacman.conf /etc/pacman.conf.bak

# Удаляем все старые вхождения localrepo
sudo sed -i "/^\[${repo_name}\]/,/^$/d" /etc/pacman.conf

# Вставляем новый блок в начало файла
sudo sed -i "1i ${conf_line}\nSigLevel = Optional TrustAll\n${server_line}\n" /etc/pacman.conf

# Обновление баз пакетов
sudo pacman -Sy

echo
echo "Готово! Репозиторий создан в $TMP_DIR"
echo "Теперь можно ставить пакеты из $repo_name:"
echo "  sudo pacman -S <имя_пакета>"
