#!/bin/bash
set -e

# Каталог установки
CHROME_DIR="/data2/chrome"
mkdir -p "$CHROME_DIR"
cd "$CHROME_DIR"

# Ссылка на Chrome
URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
DEB_FILE="google-chrome-stable_current_amd64.deb"

echo "Скачиваем Google Chrome..."
wget -O "$DEB_FILE" "$URL"

echo "Устанавливаем Google Chrome..."
sudo apt install -y ./"$DEB_FILE" || {
    echo "Ошибка установки через apt. Попробуем установить с флагом --fix-broken..."
    sudo apt install -f -y
    sudo apt install -y ./"$DEB_FILE"
}

echo "Создаём ярлык для GNOME..."
DESKTOP_FILE="$HOME/.local/share/applications/google-chrome.desktop"
mkdir -p "$(dirname "$DESKTOP_FILE")"

cat > "$DESKTOP_FILE" <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Chrome
Icon=/usr/share/icons/hicolor/256x256/apps/google-chrome.png
Exec=/usr/bin/google-chrome-stable %U
Comment=Google Chrome Web Browser
Categories=Network;WebBrowser;
Terminal=false
EOL

chmod +x "$DESKTOP_FILE"

# Добавляем в избранное GNOME, если есть gsettings
if command -v gsettings >/dev/null 2>&1; then
    current_favorites=$(gsettings get org.gnome.shell favorite-apps)
    if [[ "$current_favorites" != *"google-chrome.desktop"* ]]; then
        new_favorites=${current_favorites%]}
        new_favorites+=", 'google-chrome.desktop']"
        gsettings set org.gnome.shell favorite-apps "$new_favorites"
        echo "Google Chrome добавлен в избранное GNOME."
    else
        echo "Google Chrome уже в избранном."
    fi
fi

echo "Установка Google Chrome завершена."
