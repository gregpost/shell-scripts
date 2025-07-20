#!/bin/bash

##########################################################
#                     CONFIGURATION                      #
#               Set your project root directory          #
ROOT_DIR="/data/gp/android"
##########################################################

PROJECT_DIR="$ROOT_DIR/HelloWorld"
ANDROID_STUDIO_DIR="$HOME/android-studio"
ANDROID_STUDIO_BIN="$ANDROID_STUDIO_DIR/bin/studio.sh"
ANDROID_STUDIO_DOWNLOAD_URL="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2022.3.1.20/android-studio-2022.3.1.20-linux.tar.gz"
GRADLEW="./gradlew"

# Function to install Android Studio if missing
install_android_studio() {
    echo "Android Studio not found. Installing..."

    # Download Android Studio
    wget -O /tmp/android-studio.tar.gz "$ANDROID_STUDIO_DOWNLOAD_URL"
    if [ $? -ne 0 ]; then
        echo "Failed to download Android Studio."
        exit 1
    fi

    # Extract to home directory
    tar -xzf /tmp/android-studio.tar.gz -C "$HOME"
    if [ $? -ne 0 ]; then
        echo "Failed to extract Android Studio."
        exit 1
    fi

    echo "Android Studio installed to $ANDROID_STUDIO_DIR"
    echo "Please run Android Studio once manually to complete setup and install SDK."
    echo "After that, re-run this script."
    exit 0
}

# Check if Android Studio is installed
if [ ! -f "$ANDROID_STUDIO_BIN" ]; then
    install_android_studio
else
    echo "Android Studio found at $ANDROID_STUDIO_BIN"
fi

# Check for Gradle wrapper in project folder
if [ ! -f "$PROJECT_DIR/$GRADLEW" ]; then
    echo "Gradle wrapper not found in $PROJECT_DIR"
    echo "Please create or copy your Android project with gradlew script."
    exit 1
fi

# Build APK
cd "$PROJECT_DIR" || { echo "Project directory not found!"; exit 1; }

echo "Cleaning previous builds..."
./gradlew clean

echo "Building APK..."
./gradlew assembleDebug
if [ $? -ne 0 ]; then
  echo "Build failed!"
  exit 1
fi

echo "Build succeeded!"
APK_PATH="$PROJECT_DIR/app/build/outputs/apk/debug/app-debug.apk"
echo "APK location: $APK_PATH"

# Optional: install APK on connected device (uncomment if needed)
# echo "Installing APK on connected device..."
# ./gradlew installDebug

