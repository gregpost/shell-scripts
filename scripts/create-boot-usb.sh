#!/usr/bin/env bash
#
# create-boot-usb.sh - безопасное добавление ISO на Ventoy USB
# автоматически определяет внешний USB-диск и проверяет успешность установки
#

set -e

### 🔧 НАСТРОЙКИ ISO
ISO_DIR="/data/iso"
ISOS=("ubuntu-22.04.5-live-server-amd64.iso" "ubuntu-20.04.6-live-server-amd64.iso" "Windows-10.iso" "ru-ru_windows_11_21H2_10.0.22000.376_x64_dvd_msdn.iso")
VENTOY_VERSION="1.0.99"
###

# Проверка root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Этот скрипт нужно запускать с sudo или от root"
    exit 1
fi

# Проверяем наличие ISO
for iso in "${ISOS[@]}"; do
    if [[ ! -f "$ISO_DIR/$iso" ]]; then
        echo "❌ Не найден файл ISO: $ISO_DIR/$iso"
        exit 1
    fi
done

# Ищем первый внешний USB-диск
USB_DEVICE=$(lsblk -nr -o NAME,RM,TYPE | awk '$2==1 && $3=="disk"{print "/dev/"$1}' | head -n1)

if [[ -z "$USB_DEVICE" ]]; then
    echo "❌ Не найдено внешних USB-дисков"
    lsblk -o NAME,SIZE,RM,RO,TYPE,MOUNTPOINT
    exit 1
fi

echo ">>> Найден USB-диск: $USB_DEVICE"

# Установка Etcher (appimage-scripts) — если нужен для альтернативной записи ISO
if ! command -v balena-etcher &> /dev/null; then
    echo ">>> Скачиваем balenaEtcher..."
    wget -O /tmp/balena-etcher.AppImage https://github.com/balena-io/etcher/releases/download/v1.19.25/balenaEtcher-1.19.25-x64.AppImage
    chmod +x /tmp/balena-etcher.AppImage
    mv /tmp/balena-etcher.AppImage /usr/local/bin/balena-etcher
    echo ">>> balenaEtcher установлен (запуск: balena-etcher)"
fi

# Установка Ventoy
VENTOY_DIR="/opt/ventoy"
VENTOY_TAR="/tmp/ventoy.tar.gz"
VENTOY_PATH="$VENTOY_DIR/ventoy-$VENTOY_VERSION"

if ! [ -d "$VENTOY_PATH" ]; then
    echo ">>> Скачиваем Ventoy..."
    wget -O "$VENTOY_TAR" "https://github.com/ventoy/Ventoy/releases/download/v$VENTOY_VERSION/ventoy-$VENTOY_VERSION-linux.tar.gz"
    mkdir -p "$VENTOY_DIR"
    tar -xzf "$VENTOY_TAR" -C "$VENTOY_DIR"
fi

VENTOY_SCRIPT="$VENTOY_PATH/Ventoy2Disk.sh"
if [[ ! -f "$VENTOY_SCRIPT" ]]; then
    echo "❌ Не найден Ventoy2Disk.sh в $VENTOY_PATH"
    exit 1
fi

# Проверяем, установлен ли Ventoy на USB
if ! "$VENTOY_SCRIPT" -l "$USB_DEVICE" &> /dev/null; then
    echo "⚠️ ВНИМАНИЕ: Ventoy не найден на $USB_DEVICE. Все данные на диске будут удалены!"
    read -p "Продолжить установку Ventoy? [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Отмена."
        exit 0
    fi

    # Отмонтируем все разделы флешки
    umount "${USB_DEVICE}"* || true

    echo ">>> Установка Ventoy на $USB_DEVICE..."
    "$VENTOY_SCRIPT" -I "$USB_DEVICE"
    echo ">>> Ventoy успешно установлен!"
else
    echo "✅ Ventoy уже установлен на $USB_DEVICE, пропускаем установку."
fi

# Монтируем первый раздел флешки для копирования ISO
MOUNT_TMP="/mnt/ventoy"
mkdir -p "$MOUNT_TMP"
mount "${USB_DEVICE}1" "$MOUNT_TMP"

# Копируем только новые ISO
echo ">>> Копирование новых ISO на флешку..."
ALL_OK=true
for iso in "${ISOS[@]}"; do
    if [[ -f "$MOUNT_TMP/$iso" ]]; then
        echo "ℹ️ ISO $iso уже существует на флешке, пропускаем."
        continue
    fi
    cp "$ISO_DIR/$iso" "$MOUNT_TMP"/
    if [[ ! -f "$MOUNT_TMP/$iso" ]]; then
        echo "❌ Ошибка: ISO $iso не удалось скопировать!"
        ALL_OK=false
    else
        echo "✅ ISO $iso успешно скопирован."
    fi
done

# Отмонтируем флешку
umount "$MOUNT_TMP"

# Финальный результат
if $ALL_OK; then
    echo "✅ Готово! Все новые ISO скопированы на $USB_DEVICE."
else
    echo "⚠️ Копирование завершено с ошибками!"
fi

echo ">>> Можно загружаться с флешки и выбирать любую из систем."

