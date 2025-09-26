#!/bin/bash

ROOT_DIR="/data/niftyreg"
SOURCE_DIR="$ROOT_DIR/src"
BUILD_DIR="$ROOT_DIR/build"
INSTALL_DIR="$ROOT_DIR/install"

rm -rf "$ROOT_DIR"
mkdir -p "$ROOT_DIR"
cd "$ROOT_DIR"

# Clone the repo
git clone https://github.com/KCL-BMEIS/niftyreg.git "$SOURCE_DIR"

# Create and enter build-scripts directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with custom install prefix
cmake -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" "$SOURCE_DIR"

# Build
make -j4

# Install
make install

# Optionally, update your environment-setup
echo "export PATH=$INSTALL_DIR/bin:\$PATH" >> ~/.bashrc
echo "export LD_LIBRARY_PATH=$INSTALL_DIR/lib:\$LD_LIBRARY_PATH" >> ~/.bashrc
source ~/.bashrc

