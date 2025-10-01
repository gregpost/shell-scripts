#!/bin/bash
# Создание локального pacman-репозитория и упаковка его в tar.gz
# Run as root

set -e

# Дефолтный путь для временного репозитория
DEFAULT_REPO_PATH="/tmp/pacman-repo"
echo "Введите путь для временного локального репозитория (по умолчанию: $DEFAULT_REPO_PATH):"
read -r TMP_REPO_PATH
TMP_REPO_PATH=${TMP_REPO_PATH:-$DEFAULT_REPO_PATH}

mkdir -p "$TMP_REPO_PATH"

# Путь к архиву, который будет создан
echo "Введите путь для финального архива (.tar.gz), например ~/pacman-repo.tar.gz:"
read -r OUTPUT_ARCHIVE
if [ -z "$OUTPUT_ARCHIVE" ]; then
    OUTPUT_ARCHIVE="$HOME/pacman-repo.tar.gz"
fi

echo "Сохраняем все установленные пакеты в локальный репозиторий..."

# Сохраняем список установленных пакетов
pacman -Qq > /tmp/installed_packages.txt

for pkg in $(cat /tmp/installed_packages.txt); do
    echo "Обрабатываем пакет: $pkg"
    CACHE_FILE=$(find /var/cache/pacman/pkg -name "${pkg}-*.pkg.tar.zst" | head -n1)
    if [[ -f "$CACHE_FILE" ]]; then
        cp "$CACHE_FILE" "$TMP_REPO_PATH/"
    else
        # Скачиваем пакет, если не найден в кэше
        pacman -Sw --cachedir "$TMP_REPO_PATH" --noconfirm "$pkg"
        CACHE_FILE=$(find "$TMP_REPO_PATH" -name "${pkg}-*.pkg.tar.zst" | head -n1)
    fi
done

echo "Создаём базу локального репозитория..."
repo-add "$TMP_REPO_PATH/local.db.tar.gz" "$TMP_REPO_PATH/"*.pkg.tar.zst

echo "Создаём tar.gz архив репозитория..."
tar -czf "$OUTPUT_ARCHIVE" -C "$TMP_REPO_PATH" .

echo "Локальный репозиторий упакован в архив: $OUTPUT_ARCHIVE"
echo "Для использования архива: распакуйте его и добавьте в /etc/pacman.conf:"
echo "[local]"
echo "SigLevel = Optional TrustAll"
echo "Server = file://<path-to-extracted-repo>"
