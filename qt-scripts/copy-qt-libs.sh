#!/bin/bash

# Copies Qt libraries and plugins to the lib folder of the appimage-scripts.

APPLICATION="./viewer.AppDir/usr/bin/viewer"
QT_PLUGIN_PATH="/${HOME}/Qt/6.5.0/gcc_64/plugins"
LIB_DIR="./viewer.AppDir/usr/lib"

# Terminate the script if an error occurs
set -e

# Check if the application exists
if [ ! -f "$APPLICATION" ]; then
    echo "Error: Application '$APPLICATION' not found!"
    exit 1
fi

# Use ldd to find the Qt dependencies and copy them
echo "Copying Qt libraries to LIB_DIR..."

# Get the list of libraries
libs=$(ldd "$APPLICATION" | grep "Qt" | awk '{print $3}' | grep -v '^$')

# Copy each library to the lib folder
for lib in $libs; do
    if [ -f "$lib" ]; then
        cp -u "$lib" "$LIB_DIR"
        echo "Copied $lib to $LIB_DIR"
    fi
done

# Copy Qt plugins
cp -r "$QT_PLUGIN_PATH"/* "$DEST_FOLDER"