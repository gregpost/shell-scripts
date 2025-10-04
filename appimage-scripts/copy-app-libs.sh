#!/bin/bash
set -e

echo "=== 🧩 Copy ELF and libraries for AppImage (with linuxdeployqt) ==="

# --- Step 0: Find AppDir automatically ---
APPDIR_COUNT=$(ls -d *.AppDir 2>/dev/null | wc -l)
if [ "$APPDIR_COUNT" -eq 0 ]; then
    echo "❌ Error: No *.AppDir folder found in current directory."
    exit 1
elif [ "$APPDIR_COUNT" -gt 1 ]; then
    echo "❗ Warning: Multiple AppDir folders found. Using the first one."
fi

APPDIR=$(ls -d *.AppDir 2>/dev/null | head -n 1)
APP_NAME="${APPDIR%%.AppDir}"

echo "Detected AppDir: $APPDIR"
echo "App name: $APP_NAME"

# --- Step 1: Ask user for ELF path ---
DEFAULT_ELF="./$APPDIR/usr/bin/$APP_NAME"
read -p "Enter path to executable [$DEFAULT_ELF]: " ELF_PATH
ELF_PATH=${ELF_PATH:-"$DEFAULT_ELF"}

if [ ! -f "$ELF_PATH" ]; then
    echo "❌ Error: Executable '$ELF_PATH' not found!"
    exit 1
fi

# --- Step 1.1: Ask if app uses Qt ---
read -p "Does this application use Qt? [y/N]: " IS_QT_APP
IS_QT_APP=${IS_QT_APP:-N}

read -p "Do you want to try launching the executable to detect missing libraries? [Y/n]: " LAUNCH_LOG
LAUNCH_LOG=${LAUNCH_LOG:-Y}

LIB_DIR="./$APPDIR/usr/lib"
read -p "Enter path to lib folder [$LIB_DIR]: " INPUT_LIB_DIR
LIB_DIR=${INPUT_LIB_DIR:-"$LIB_DIR"}

# --- Step 1.2: Ask path to linuxdeployqt only if Qt used ---
if [[ "$IS_QT_APP" =~ ^[Yy]$ ]]; then
    DEFAULT_LDQ=$(which linuxdeployqt || echo "/usr/local/bin/linuxdeployqt")
    read -p "Enter path to linuxdeployqt utility [$DEFAULT_LDQ]: " LINUXDEPLOYQT
    LINUXDEPLOYQT=${LINUXDEPLOYQT:-"$DEFAULT_LDQ"}

    if [ ! -x "$LINUXDEPLOYQT" ]; then
        echo "❌ Error: linuxdeployqt not found or not executable at '$LINUXDEPLOYQT'."
        exit 1
    fi
fi

mkdir -p "$LIB_DIR"

# --- Step 2: Launch ELF and parse missing libraries from output ---
MISSING_LIBS=""
if [[ "$LAUNCH_LOG" =~ ^[Yy]$ ]]; then
    LOG_TMP=$(mktemp)
    echo "📄 Running executable and capturing output..."
    "$ELF_PATH" &> "$LOG_TMP" || true

    echo "📂 Parsing ELF log for missing libraries..."
    MISSING_LIBS=$(grep -oP 'error while loading shared libraries: \K[^:]+(?=: cannot open)' "$LOG_TMP" | sort -u)
    rm "$LOG_TMP"

    if [ -n "$MISSING_LIBS" ]; then
        echo "Detected missing libraries from ELF log:"
        for lib in $MISSING_LIBS; do
            echo "$lib"
        done

        read -p "Enter folder(s) to search for missing libraries (space-separated, e.g. /usr/lib /usr/local/lib ./your/folder): " SEARCH_FOLDERS
        for lib in $MISSING_LIBS; do
            FOUND=0
            for folder in $SEARCH_FOLDERS; do
                if [ -f "$folder/$lib" ]; then
                    # --- Fix: copy directly into LIB_DIR without preserving source path ---
                    ALL_LIBS="$ALL_LIBS $folder/$lib"
                    FOUND=1
                    break
                fi
            done
            if [ $FOUND -eq 0 ]; then
                echo "⚠️ Library '$lib' not found in specified folders, you will need to place it manually in $LIB_DIR"
            fi
        done
    else
        echo "ℹ️ No missing libraries detected in ELF log."
    fi
fi

# --- Step 3: Collect ELF dependencies via ldd ---
RAW_LIBS=$(ldd "$ELF_PATH" 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i ~ /^\//){print $i}}}' || true)
ALL_LIBS="$ALL_LIBS $RAW_LIBS"

# --- Step 4: Filter system libraries ---
SYSTEM_LIBS="
/lib64/ld-linux-x86-64.so.2
/lib/x86_64-linux-gnu/libc.so.6
/lib/x86_64-linux-gnu/libgcc_s.so.1
/lib/x86_64-linux-gnu/libm.so.6
/lib/x86_64-linux-gnu/libstdc++.so.6
"

FILTERED_LIBS=""
for lib in $ALL_LIBS; do
    if echo "$SYSTEM_LIBS" | grep -qx "$lib"; then
        continue
    fi
    FILTERED_LIBS="$FILTERED_LIBS $lib"
done
ALL_LIBS=$(echo $FILTERED_LIBS | xargs -n1 | sort -u)

# --- Step 5: Show libraries ---
echo
echo "📂 The following libraries will be copied to $LIB_DIR:"
echo "------------------------------------------------------"
if [ -n "$ALL_LIBS" ]; then
    for lib in $ALL_LIBS; do
        echo "$lib"
    done
else
    echo "ℹ️ No shared libraries detected."
fi
echo "------------------------------------------------------"

if [ -z "$ALL_LIBS" ]; then
    echo "✅ No additional libraries to copy. Nothing to do."
    exit 0
fi

if [[ "$IS_QT_APP" =~ ^[Yy]$ ]]; then
    read -p "Do you want to proceed with copying these libraries and running linuxdeployqt? [Y/n]: " CONFIRM
else
    read -p "Do you want to proceed with copying these libraries? [Y/n]: " CONFIRM
fi
CONFIRM=${CONFIRM:-Y}

# --- Step 6: Copy libraries ---
echo
echo "📦 Copying libraries..."
for lib in $ALL_LIBS; do
    if [ -f "$lib" ]; then
        cp -f "$lib" "$LIB_DIR/"
        echo "Copied $lib to $LIB_DIR/"
    else
        echo "⚠️ Library file '$lib' not found, please place it manually in $LIB_DIR"
    fi
done

# --- Step 7: Run linuxdeployqt on ELF if Qt app ---
if [[ "$IS_QT_APP" =~ ^[Yy]$ ]]; then
    echo
    echo "🚀 Running linuxdeployqt on $ELF_PATH..."
    "$LINUXDEPLOYQT" "$ELF_PATH" -appimage
    echo "✅ linuxdeployqt finished."
fi
