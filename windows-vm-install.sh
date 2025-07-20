#!/bin/bash


# README
# В файле vm.conf можно определить:
#
# Root directory where all the script files will be located:
# ROOT_DIR="/path/to/vms"
#
# URL of Windows ISO
# ISO_URL="https://example.com/path/to/windows.iso"


set -euo pipefail

# ================= CONFIGURATION FILE ======================
# Скрипт сначала пытается загрузить конфигурацию из этого файла,
# в котором можно указать ROOT_DIR и ISO_URL.
CONFIG_FILE="${CONFIG_FILE:-$HOME/vm.conf}"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

# Если переменная ISO_URL не задана в конфиге или окружении, используем значение по умолчанию
ISO_URL="${ISO_URL:-https://example.com/path/to/windows.iso}"

# ====================== VM CONFIGURATION ==================
ISO_PATH="$ROOT_DIR/iso/windows.iso"
VM_NAME="WindowsVM"
VM_DIR="$ROOT_DIR/$VM_NAME"
VDI_PATH="$VM_DIR/$VM_NAME.vdi"
VDI_SIZE=50000      # in MB
RAM_SIZE=4096       # in MB
CPU_COUNT=2
VM_TYPE="gui"     # "gui" или "headless"

# Путь к общей папке на хосте
SHARED_FOLDER_HOST_PATH="$ROOT_DIR/shared"
SHARED_FOLDER_NAME="shared"

# ===================== DOWNLOAD ISO =========================
echo "[1/5] Downloading Windows ISO from: $ISO_URL"
mkdir -p "$(dirname "$ISO_PATH")"
wget -O "$ISO_PATH" "$ISO_URL"

# =================== INSTALL VIRTUALBOX =====================
echo "[2/5] Installing VirtualBox..."
sudo apt-get update
sudo apt-get install -y virtualbox virtualbox-ext-pack

# ===================== CREATE VM ============================
echo "[3/5] Creating VirtualBox VM..."
VBoxManage createvm --name "$VM_NAME" --ostype Windows10_64 --register
VBoxManage modifyvm "$VM_NAME" --memory $RAM_SIZE --cpus $CPU_COUNT --nic1 nat

mkdir -p "$VM_DIR"
VBoxManage createmedium disk --filename "$VDI_PATH" --size $VDI_SIZE
VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach "$VM_NAME" \
  --storagectl "SATA" --port 0 --device 0 \
  --type hdd --medium "$VDI_PATH"
VBoxManage storageattach "$VM_NAME" \
  --storagectl "SATA" --port 1 --device 0 \
  --type dvddrive --medium "$ISO_PATH"

# Создаём общую папку на хосте
mkdir -p "$SHARED_FOLDER_HOST_PATH"

# Добавляем shared folder в VirtualBox
VBoxManage sharedfolder add "$VM_NAME" --name "$SHARED_FOLDER_NAME" --hostpath "$SHARED_FOLDER_HOST_PATH" --automount

# ===================== START VM =============================
echo "[4/5] Starting Virtual Machine..."
VBoxManage startvm "$VM_NAME" --type "$VM_TYPE"

echo "[5/5] Setup complete. Не забудьте установить VirtualBox Guest Additions в Windows для работы общей папки."

echo "Общая папка смонтирована из Ubuntu: $SHARED_FOLDER_HOST_PATH"
echo "В Windows она появится как \\VBOXSVR\\$SHARED_FOLDER_NAME после установки Guest Additions."
