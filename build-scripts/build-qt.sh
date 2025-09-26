#!/bin/bash

# Qt install script

sudo apt install -y gcc build-essential
sudo apt install --reinstall libxcb-xinerama0

# Define installation directory
DOWNLOAD_DIR="$HOME"
mkdir "$DOWNLOAD_DIR"

# Download Qt Maintenance Tool
echo "Downloading Qt Maintenance Tool..."
wget -O "$DOWNLOAD_DIR/qt-installer.run" "https://d13lb3tujbc8s0.cloudfront.net/onlineinstallers/qt-online-installer-linux-x64-4.8.1.run"

# Make the installer executable
chmod +x "$DOWNLOAD_DIR/qt-installer.run"

# Start VPN (you need execute `sudo apt install wireguard' and copy the VPN tunnel to /etc/wireguard first)
sudo wg-quick up wg0

# Check connection after VPN start
ping -c 1 google.com

# Run the installer in non-interactive mode
# Check that Qt version is compatible with your GCC version
echo "Starting Qt installer..."
"$DOWNLOAD_DIR/qt-installer.run" \
  --mirror https://mirror.yandex.ru/mirrors/qt.io \
  --accept-licenses \
  --default-answer \
  --confirm-command \
  --email gpostolskiy@gmail.com \
  --pw kojqOjef9.t \
  install qt.qt6.672.gcc_64 qt.qt6.672.gcc_64.compatibility.qt5

# Disable VPN
sudo wg-quick down wg0
