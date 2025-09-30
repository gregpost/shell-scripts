#!/bin/bash
set -e

echo "=== Arch Linux Local Repo USB Copier ==="

# Запрос пути к локальному репо
read -rp "Enter path to your local Arch repo: " LOCAL_REPO
if [ ! -d "$LOCAL_REPO" ]; then
    echo "Error: '$LOCAL_REPO' is not a valid directory."
    exit 1
fi

# Список смонтированных USB
echo
echo "Detecting mounted USB drives..."
mapfile -t USB_LIST < <(lsblk -o NAME,MOUNTPOINT,LABEL,SIZE,TRAN | grep -E 'part.*(usb|disk)' | awk '{print $2 " " $3 " " $4}')

if [ ${#USB_LIST[@]} -eq 0 ]; then
    echo "No USB drives detected. Please insert a USB and try again."
    exit 1
fi

echo "Available USB drives:"
for i in "${!USB_LIST[@]}"; do
    echo "$((i+1))) ${USB_LIST[$i]}"
done

# Выбор USB по номеру
while true; do
    read -rp "Enter the number of the USB to use: " USB_NUM
    if [[ "$USB_NUM" =~ ^[0-9]+$ ]] && (( USB_NUM >= 1 && USB_NUM <= ${#USB_LIST[@]} )); then
        USB_PATH=$(echo "${USB_LIST[$((USB_NUM-1))]}" | awk '{print $1}')
        break
    else
        echo "Invalid selection. Try again."
    fi
done

# Проверка директории на флешке
if [ ! -d "$USB_PATH" ]; then
    echo "Creating mount directory: $USB_PATH"
    mkdir -p "$USB_PATH"
fi

# Создать папку на флешке для хранения репозитория
DEST="$USB_PATH/arch_local_repo"
mkdir -p "$DEST"

echo "Copying files from '$LOCAL_REPO' to '$DEST'..."
cp -a "$LOCAL_REPO"/. "$DEST"/

echo "Copy completed successfully!"
echo "Your local Arch repo is now on USB at: $DEST"
