#!/bin/bash
# install_jpeg2000.sh
# This script installs the JPEG2000 decompression codec (fmjpeg2koj)
# Assumes DCMTK and openjpeg are already installed.
#
# Directory structure:
#   Codec home directory: ~/jpeg2000
#   Source directory:     ~/jpeg2000/src
#   Build directory:      ~/jpeg2000/build-scripts
#   Install directory:    ~/jpeg2000/install
#
# Usage: ./install_jpeg2000.sh [Release|Debug]
# Default build-scripts type is Debug unless "Release" is provided.

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
CODEC_HOME="${HOME}/jpeg2000"
SRC_DIR="$CODEC_HOME/src"
BUILD_DIR="$CODEC_HOME/build/$TYPE"
INSTALL_DIR="$CODEC_HOME/install/$TYPE"
DCMTK_DIR="${HOME}/dcmtk/install"
OPENJPEG_DIR="${HOME}/openjpeg/install"

# Create necessary directories
mkdir -p "$SRC_DIR"
# Clear and recreate the build-scripts directory for a clean build-scripts environment-setup
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Clone fmjpeg2koj into the source directory if it doesn't exist
if [ ! -d "$SRC_DIR" ]; then
    git clone https://github.com/DraconPern/fmjpeg2koj.git "$SRC_DIR"
fi

# Check that openjpeg is already installed.
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Error: OpenJPEG is not installed in $INSTALL_DIR. Please install it first."
    exit 1
fi

##############################
# Build fmjpeg2koj (JPEG2000 Codec)
##############################
# Create and enter the build-scripts directory for fmjpeg2koj
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure fmjpeg2koj with CMake, providing paths to DCMTK,
# fmjpeg2koj sources, and openjpeg.
cmake "$SRC_DIR" \
    -DCMAKE_BUILD_TYPE=$TYPE \
    -DBUILD_SHARED_LIBS=ON \
    -DDCMTK_ROOT="$DCMTK_DIR" \
    -Dfmjpeg2k_ROOT="$SRC_DIR" \
    -DOpenJPEG_ROOT="$OPENJPEG_DIR" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

# Build the codec
make -j$(nproc) install

# Check that fmjpeg2koj built successfully.
# (Assumes "dcmcjp2k" is one of the expected executables.)
if [ -f "dcmcjp2k" ]; then
    echo "fmjpeg2koj built successfully. Installation completed."
else
    echo "fmjpeg2koj build failed: dcmcjp2k executable not found."
    exit 1
fi
