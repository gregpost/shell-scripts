#!/bin/bash
# Скрипт для подключения локального pacman-репозитория
# Работает с папкой пакетов или архивом tar.gz
# Позволяет сохранить репозиторий в RAM или на диск

set -e

# --- Выбор источника пакетов ---
echo "Выберите источник локального репозитория:"
echo "1) Папка с пакетами"
echo "2) Архив tar.gz"
read -rp "Введите 1 или 2: " choice

case "$choice" in
    1)
        read -rp "Введите путь до папки с локальными пакетами (.pkg.tar.zst): " repo_path
        if [ ! -d "$repo_path" ]; then
            echo "Ошибка: папка $repo_path не существует"
            exit 1
        fi
        ;;
    2)
        default_archive_dir="/shared"
        read -rp "Введите путь к папке, где хранится архив (по умолчанию: $default_archive_dir): " archive_dir
        archive_dir=${archive_dir:-$default_archive_dir}

        default_archive="pacman-repo.tar.gz"
        read -rp "Введите имя архива (по умолчанию: $default_archive): " archive_name
        archive_name=${archive_name:-$default_archive}

        archive_path="$archive_dir/$archive_name"
        if [ ! -f "$archive_path" ]; then
            echo "Ошибка: файл $archive_path не существует"
            exit 1
        fi
        ;;
    *)
        echo "Ошибка: нужно ввести 1 или 2"
        exit 1
        ;;
esac

# --- Выбор места сохранения репозитория ---
echo "Выберите место для локального репозитория:"
echo "1) RAM (tmpfs, /tmp/pacman-repo)"
echo "2) На диск (например, /shared/pacman-repo)"
read -rp "Введите 1 или 2: " dest_choice

case "$dest_choice" in
    1)
        TMP_DIR="/tmp/pacman-repo"
        RAM_SIZE="2G"
        sudo mkdir -p "$TMP_DIR"
        sudo mount -t tmpfs -o size=$RAM_SIZE tmpfs "$TMP_DIR"
        echo "Репозиторий будет создан в RAM: $TMP_DIR (size=$RAM_SIZE)"
        ;;
    2)
        read -rp "Введите путь для сохранения репозитория (по умолчанию: /shared/pacman-repo): " TMP_DIR
        TMP_DIR=${TMP_DIR:-/shared/pacman-repo}
        mkdir -p "$TMP_DIR"
        echo "Репозиторий будет создан на диске: $TMP_DIR"
        ;;
    *)
        echo "Ошибка: нужно ввести 1 или 2"
        exit 1
        ;;
esac

# --- Подготовка пакетов ---
case "$choice" in
    1)
        cp "$repo_path"/*.pkg.tar.zst "$TMP_DIR/"
        ;;
    2)
        # Проверка ФС для tar
        fs_type=$(df -T "$TMP_DIR" | awk 'NR==2 {print $2}')
        if [[ "$fs_type" =~ (vfat|ntfs|exfat) ]]; then
            echo "Ошибка: выбранная папка на файловой системе $fs_type не поддерживает симлинки"
            exit 1
        fi
        tar --no-same-owner --no-same-permissions -xzf "$archive_path" -C "$TMP_DIR"
        ;;
esac

# --- Создание базы пакетов ---
repo_name="localrepo"
cd "$TMP_DIR"
repo-add "$repo_name.db.tar.gz" *.pkg.tar.zst

# --- Добавляем репозиторий в pacman.conf ---
conf_line="[${repo_name}]"
server_line="Server = file://$TMP_DIR"

if ! grep -q "$conf_line" /etc/pacman.conf; then
    echo "Добавляем репозиторий в /etc/pacman.conf..."
    sudo bash -c "echo -e '\n${conf_line}\nSigLevel = Optional TrustAll\n${server_line}' >> /etc/pacman.conf"
else
    echo "Репозиторий уже есть в /etc/pacman.conf"
fi

# --- Обновляем базы пакетов ---
sudo pacman -Sy

echo "Готово! Теперь можно ставить пакеты из $repo_name:"
echo "  sudo pacman -S <имя_пакета>"
echo "Репозиторий находится в $TMP_DIR"

if [ "$dest_choice" -eq 1 ]; then
    echo "Внимание: это tmpfs в RAM. После размонтирования или перезагрузки всё исчезнет."
    echo "Чтобы удалить RAM-репозиторий вручную:"
    echo "  sudo umount $TMP_DIR && sudo rmdir $TMP_DIR"
fi
