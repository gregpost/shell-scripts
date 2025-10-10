#!/usr/bin/env bash
# File: droidcam-linux-install.sh
# Purpose: Автоматически установить и настроить DroidCam под Linux.
# DroidCam предназначен для использования android-телефона как веб-камеры
# Поддерживает установку клиента, загрузку драйвера v4l2loopback и запуск камеры.
# Скрипт спрашивает путь установки клиента.

set -e

echo "=== Установка DroidCam для Linux ==="

# Проверка зависимостей
if ! command -v wget >/dev/null 2>&1; then
  echo "Устанавливается wget..."
  sudo apt install -y wget
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "Устанавливается unzip..."
  sudo apt install -y unzip
fi

if ! dpkg -l | grep -q v4l2loopback-dkms; then
  echo "Устанавливается модуль v4l2loopback..."
  sudo apt install -y v4l2loopback-dkms
fi

# Спросить папку установки
read -rp "Введите путь для установки DroidCam (например, /opt/droidcam): " INSTALL_DIR
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Загрузка последней версии DroidCam
echo "Скачивание последней версии DroidCam..."
wget -O droidcam_latest.zip https://files.dev47apps.net/linux/droidcam_latest.zip

# Распаковка архива
unzip -o droidcam_latest.zip
cd droidcam*

# Установка клиента
echo "Устанавливается клиент DroidCam..."
sudo ./install-client

# Проверка установки
if command -v droidcam >/dev/null 2>&1; then
  echo "✅ DroidCam установлен успешно!"
else
  echo "❌ Ошибка: DroidCam не найден после установки."
  exit 1
fi

# Загрузка модуля ядра
echo "Загружается модуль v4l2loopback..."
sudo modprobe v4l2loopback

# Инструкция по запуску
echo
echo "=== Установка завершена ==="
echo "1. Установи приложение DroidCam на телефон (Google Play)."
echo "2. Подключи телефон по USB или Wi-Fi."
echo "3. Запусти клиент командой: droidcam"
echo "4. Укажи IP телефона (если Wi-Fi) или выбери USB."
echo
echo "Папка установки: $INSTALL_DIR"
