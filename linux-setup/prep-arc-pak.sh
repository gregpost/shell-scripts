#!/bin/bash
# Save all installed Arch packages to a local repository
# Run as root

set -e

echo "Enter the path to save the local repository (will be created if not exists):"
read -r REPO_PATH

# Create directory
mkdir -p "$REPO_PATH"

echo "Saving all installed packages to $REPO_PATH..."
# Download all installed packages from pacman cache (or re-download if missing)
pacman -Qq > /tmp/installed_packages.txt
for pkg in $(cat /tmp/installed_packages.txt); do
    echo "Processing package: $pkg"
    # Check if package exists in cache
    CACHE_FILE=$(find /var/cache/pacman/pkg -name "${pkg}-*.pkg.tar.zst" | head -n1)
    if [[ -f "$CACHE_FILE" ]]; then
        cp "$CACHE_FILE" "$REPO_PATH/"
    else
        # Download package if not in cache
        pacman -Sw --cachedir "$REPO_PATH" --noconfirm "$pkg"
    fi
done

echo "Creating local repository database..."
repo-add "$REPO_PATH/local.db.tar.gz" "$REPO_PATH/"*.pkg.tar.zst

echo "Local repository created at $REPO_PATH"
echo "To use it in future installation, add the following to /etc/pacman.conf:"
echo "[local]"
echo "SigLevel = Optional TrustAll"
echo "Server = file://$REPO_PATH"
