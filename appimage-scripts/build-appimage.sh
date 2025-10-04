#!/bin/bash
set -e

echo "=== 🧱 AppImage Builder Script ==="

# --- Default AppDir path ---
DEFAULT_APPDIR="./app_name.AppDir"
read -p "Enter path to AppImage folder [default: $DEFAULT_APPDIR]: " APPDIR
APPDIR=${APPDIR:-$DEFAULT_APPDIR}

if [ ! -d "$APPDIR" ]; then
    echo "❌ Error: Directory '$APPDIR' does not exist."
    exit 1
fi

echo "Using AppImage directory: $APPDIR"
echo

# --- Check required structure ---
echo "🔍 Checking AppDir structure..."

MISSING=0
if [ ! -f "$APPDIR/AppRun" ]; then
    echo "❌ Missing AppRun file in $APPDIR"
    MISSING=1
fi
if [ ! -f "$APPDIR/app_name.desktop" ]; then
    echo "❌ Missing .desktop file (app_name.desktop) in $APPDIR"
    MISSING=1
fi
if [ ! -f "$APPDIR/icon_name.png" ]; then
    echo "❌ Missing icon file (icon_name.png) in $APPDIR"
    MISSING=1
fi

if [ $MISSING -eq 1 ]; then
    echo "⚠️  Please fix the missing files before building AppImage."
    exit 1
fi

# --- Check appimagetool ---
APPIMAGE_TOOL="./appimagetool-x86_64.AppImage"
if [ ! -f "$APPIMAGE_TOOL" ]; then
    echo "🔽 appimagetool not found. Downloading..."
    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O $APPIMAGE_TOOL
    chmod +x $APPIMAGE_TOOL
    echo "✅ appimagetool downloaded successfully."
else
    echo "✅ appimagetool already exists, skipping download."
fi

# --- Build AppImage ---
OUTPUT_NAME="$(basename "$APPDIR" .AppDir)-x86_64.AppImage"
echo "🚧 Building $OUTPUT_NAME ..."
ARCH=x86_64 $APPIMAGE_TOOL "$APPDIR" "$OUTPUT_NAME"

if [ $? -ne 0 ]; then
    echo "❌ Build failed. Check AppDir contents and dependencies."
    exit 1
fi

chmod a+x "$OUTPUT_NAME"
echo "✅ AppImage built successfully: $OUTPUT_NAME"
echo "📌 You can run it with: ./$OUTPUT_NAME"
