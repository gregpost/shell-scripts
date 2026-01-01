#!/bin/bash

set -e
clear

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

# Request of archive path
DEFAULT_ARCHIVE_DIR='/mnt/usb/data/pacman-repo.tar.gz'
echo -en "${GREEN}Input path to pacman package archive [${DEFAULT_ARCHIVE_DIR}]: ${NC}"
read -r ARCHIVE_DIR
ARCHIVE_DIR=${ARCHIVE_DIR:-${DEFAULT_ARCHIVE_DIR}}

# Request path to anarchive .zst files
DEFAULT_ROOT_DIR='/mnt/root'
echo -en "${GREEN}Input path to HDD mount point [${DEFAULT_ROOT_DIR}]: ${NC}"
read -r ROOT_DIR
ROOT_DIR=${ROOT_DIR:-${DEFAULT_ROOT_DIR}}

# Create temp dir /tmp/tmp.abcdef123456
TEMP_DIR="${ROOT_DIR}$(mktemp -d)"
mkdir -p "${TEMP_DIR}"
echo -e "${GREEN}Archive unpacking to temp folder: ${TEMP_DIR}${NC}"
pv "$ARCHIVE_DIR" | tar -xzf - -C "$TEMP_DIR"

# Check existance of local.db.tar.gz and package files
if [[ ! -f "$TEMP_DIR/local.db.tar.gz" ]];
then
    echo -e "${RED}Error: local.db.tar.gz not found in archive!${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo -e "${GREEN}Archive unpacked successfully!${NC}" 
echo -e "${GREEN}Unpacked folder size: $(du -sh ${TEMP_DIR})${NC}"

# Copy pacman database
mkdir -p "$ROOT_DIR/var/lib/pacman/local" "$ROOT_DIR/var/cache/pacman/pkg"
cp "$TEMP_DIR/local.db.tar.gz" "$ROOT_DIR/var/lib/pacman/local/"

# Create pacman.conf
mkdir -p "${ROOT_DIR}/etc"
cat > "$ROOT_DIR/etc/pacman.conf" << EOF
[options]
Architecture = auto
SigLevel = Never
EOF

# Install packages
echo -e "${GREEN}Installing packages...${NC}"
for pkg in "$TEMP_DIR"/*.pkg.tar.zst; do
    if [[ -f "$pkg" ]]; then
        echo "  $(basename "$pkg")"
        bsdtar -xpf "$pkg" -C "$ROOT_DIR"
    fi
done

# Cleaning
rm -rf "$TEMP_DIR"

echo -e "\n${GREEN} Installation complete!${NC}"
