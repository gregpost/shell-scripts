#!/bin/bash
# Скрипт для подключения локального pacman-репозитория

set -e

echo "Введите путь до папки с локальными пакетами (.pkg.tar.zst):"
read repo_path

# Проверка существования папки
if [ ! -d "$repo_path" ]; then
    echo "Ошибка: папка $repo_path не существует"
    exit 1
fi

# Имя репозитория
repo_name="localrepo"

# Создание базы пакетов
cd "$repo_path"
repo-add "$repo_name.db.tar.gz" *.pkg.tar.zst

# Добавляем репозиторий в pacman.conf (если ещё не добавлен)
conf_line="[${repo_name}]"
server_line="Server = file://$repo_path"

if ! grep -q "$conf_line" /etc/pacman.conf; then
    echo "Добавляем репозиторий в /etc/pacman.conf..."
    sudo bash -c "echo -e '\n${conf_line}\nSigLevel = Optional TrustAll\n${server_line}' >> /etc/pacman.conf"
else
    echo "Репозиторий уже есть в /etc/pacman.conf"
fi

# Обновляем базы пакетов
sudo pacman -Sy

echo "Готово! Теперь можно ставить пакеты из $repo_name:"
echo "  sudo pacman -S <имя_пакета>"
