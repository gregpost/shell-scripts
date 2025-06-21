#!/bin/bash

# === CONFIGURATION ===
UE_VERSION="5.3"
INSTALL_DIR="/data/gp/unreal"
REPO_URL="https://github.com/EpicGames/UnrealEngine.git"
BRANCH="release"

# === FUNCTIONALITY ===

echo "[1/7] Checking dependencies..."
sudo apt update
sudo apt install -y \
    git curl wget unzip tar \
    build-essential clang lld cmake ninja-build \
    libxcb1 libx11-dev libxcursor-dev libxrandr-dev libxinerama-dev \
    libxi-dev libgl1-mesa-dev libvulkan-dev libvulkan1 \
    mono-complete dos2unix zlib1g-dev libgtk-3-dev \
    libsdl2-dev python-is-python3

echo "[2/7] Cloning Unreal Engine source from GitHub..."
if [ ! -d "$INSTALL_DIR" ]; then
    git clone --depth=1 -b $BRANCH $REPO_URL "$INSTALL_DIR"
else
    echo "Unreal Engine directory already exists, skipping clone."
fi

cd "$INSTALL_DIR"

echo "[3/7] Running Setup.sh to download dependencies..."
chmod +x Setup.sh
./Setup.sh

echo "[4/7] Generating project files..."
chmod +x GenerateProjectFiles.sh
./GenerateProjectFiles.sh

echo "[5/7] Compiling Unreal Engine (this may take 1–3+ hours)..."
make -j$(nproc)

echo "[6/7] Verifying build success..."
if [ -f "$INSTALL_DIR/Engine/Binaries/Linux/UnrealEditor" ]; then
    echo "✅ Unreal Engine built successfully."
else
    echo "❌ Build failed. Check logs."
    exit 1
fi

echo "[7/7] Launching Unreal Editor..."
"$INSTALL_DIR/Engine/Binaries/Linux/UnrealEditor"

