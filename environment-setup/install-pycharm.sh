#!/bin/bash
set -e

#TODO: I haven't tested this script yet
# Script to download, extract PyCharm Community, and add it as a favorite app (GNOME)

# Variables
URL="https://download-cdn.jetbrains.com/python/pycharm-community-2024.3.4.tar.gz?_gl=1*anx8m*_gcl_au*MTU5MDg3MDA3Ny4xNzQxNjA3MTE2*FPAU*MTU5MDg3MDA3Ny4xNzQxNjA3MTE2*_ga*MjA4OTU0NjUyLjE3NDE2MDcxMTQ.*_ga_9J976DJZ68*MTc0MTg2ODI1MC4yLjEuMTc0MTg2ODI2Mi40OC4wLjA."
TARBALL="pycharm-community-2024.3.4.tar.gz"
# The tarball usually extracts to a folder with the same version name;
# adjust INSTALL_DIR if the folder name differs.
PYCHARM_ROOT_DIR="/data2/pycharm"
INSTALL_DIR="$PYCHARM_ROOT_DIR/pycharm-community-2024.3.4"
DESKTOP_FILE="$HOME/.local/share/applications/pycharm-community.desktop"

# Download the tarball
echo "Downloading PyCharm Community..."
cd $PYCHARM_ROOT_DIR
wget -O "$TARBALL" "$URL"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download PyCharm Community."
    exit 1
fi

# Extract the tarball to the home directory
echo "Extracting $TARBALL..."
tar -xzf "$TARBALL" -C "$PYCHARM_ROOT_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Extraction failed."
    exit 1
fi

# Create a desktop entry
echo "Creating desktop entry at $DESKTOP_FILE..."
mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=PyCharm Community
Icon=$INSTALL_DIR/bin/pycharm.png
Exec="$INSTALL_DIR/bin/pycharm.sh" %f
Comment=Python IDE for Professional Developers
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-pycharm
EOL

chmod +x "$DESKTOP_FILE"

# Add the new app to GNOME favorites if gsettings is available
if command -v gsettings >/dev/null 2>&1; then
    current_favorites=$(gsettings get org.gnome.shell favorite-apps)
    # Check if the entry is already present
    if [[ "$current_favorites" != *"pycharm-community.desktop"* ]]; then
        # Remove the trailing "]" then append the new entry and a closing bracket
        new_favorites=${current_favorites%]}
        new_favorites+=", 'pycharm-community.desktop']"
        gsettings set org.gnome.shell favorite-apps "$new_favorites"
        echo "PyCharm Community added to GNOME favorites."
    else
        echo "PyCharm Community is already in GNOME favorites."
    fi
else
    echo "gsettings not found. Skipping addition to GNOME favorites."
fi

echo "Installation complete."
