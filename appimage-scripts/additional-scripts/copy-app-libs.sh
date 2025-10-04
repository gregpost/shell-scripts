#!/bin/bash

# This script copies executable dependencies from /usr/lib Linux system folder to the destination folder
# This is needs to build AppImage package. The output libraries need to be stored in usr/lib folder inside
# the AppImage. Also is need to set LD_LIBRARY_PARH in AppRun script in appname.AppDir folder of the AppImage.

executable="./app_name.AppDir/usr/bin/app_name"
destination="./lib"

mkdir -p "$destination"

for lib in $(ldd "$executable" | grep "=>" | awk '{print $3}'); do
    cp --parents "$lib" "$destination"
done

# Optional: handling for libraries that may not have the '=>' symbol
for lib in $(ldd "$executable" | grep "ld-linux" | awk '{print $1}'); do
    cp --parents "$lib" "$destination"
done
