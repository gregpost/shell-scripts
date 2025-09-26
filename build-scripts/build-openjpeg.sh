#!/bin/bash
# install_openjpeg.sh
# This script installs openjpeg version v2.4.0.
#
# Directory structure:
#   Codec home directory: ~/openjpeg
#   Source directory:     ~/openjpeg/src
#   Build directory:      ~/openjpeg/build-scripts
#   Install directory:    ~/openjpeg/install
#
# Usage: ./install_openjpeg.sh [Release|Debug]
# Default build-scripts type is Release unless "Debug" is provided.

set -xe  # Exit on errors and print commands as they run

# Determine build-scripts type
if [ "$1" == "Debug" ]; then
    echo "Build configuration: Debug"
    TYPE=Debug
else
    echo "Build configuration: Release"
    TYPE=Release
fi

# Define directory variables
CODEC_HOME="${HOME}/openjpeg"
SRC_DIR="$CODEC_HOME/src"
BUILD_DIR="$CODEC_HOME/build/$TYPE"
INSTALL_DIR="$CODEC_HOME/install/$TYPE"
MAJOR_VER=2
MINOR_VER=4
PACK_VER=0

# Create source and install directories if they don't exist
mkdir -p "$SRC_DIR" "$INSTALL_DIR"

# Clear and recreate the build-scripts directory for a clean build-scripts environment-setup
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Clone the openjpeg repository into the source directory if it doesn't exist
if [ ! -d "$SRC_DIR/openjpeg" ]; then
    git clone --branch=v${MAJOR_VER}.${MINOR_VER}.${PACK_VER} --single-branch --depth 1 https://github.com/uclouvain/openjpeg.git "$SRC_DIR/openjpeg"
fi

cd "$SRC_DIR/openjpeg"
git pull

# Create and enter the build-scripts directory for openjpeg
OPENJPEG_BUILD_DIR="$BUILD_DIR/openjpeg-$TYPE"
mkdir -p "$OPENJPEG_BUILD_DIR"
cd "$OPENJPEG_BUILD_DIR"

# Configure openjpeg with CMake and set the installation prefix to INSTALL_DIR
cmake "$SRC_DIR/openjpeg" \
    -DCMAKE_BUILD_TYPE=$TYPE \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR

# Detect OS
OS="$(uname -s)"

if [[ "$OS" == "Linux" || "$OS" == "Darwin" ]]; then
    echo "Detected Linux/macOS: Using make"
    make -j$(nproc) install
elif [[ "$OS" == "CYGWIN"* || "$OS" == "MINGW"* || "$OS" == "MSYS"* ]]; then
    echo "Detected Windows: Using nmake"
    nmake /f Makefile install
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Check that installation completed successfully
if [ -f "$INSTALL_DIR/lib/openjpeg-${MAJOR_VER}.${MINOR_VER}/OpenJPEGConfig.cmake" ]; then
    echo "OpenJPEG installed successfully in $INSTALL_DIR"
else
    echo "OpenJPEG installation failed"
    exit 1
fi
