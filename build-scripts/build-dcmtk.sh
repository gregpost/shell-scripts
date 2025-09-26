#!/bin/bash

# ------------------------------
# Set version and download source
# ------------------------------
DCMTK_MAJOR_VERSION="3"
DCMTK_MINOR_VERSION="6"
DCMTK_PACKAGE_VERSION="9"
DCMTK_VERSION="${DCMTK_MAJOR_VERSION}.${DCMTK_MINOR_VERSION}.${DCMTK_PACKAGE_VERSION}"
DCMTK_VERSION_SHORT="${DCMTK_MAJOR_VERSION}${DCMTK_MINOR_VERSION}${DCMTK_PACKAGE_VERSION}"

DCMTK_URL="https://dicom.offis.de/download/dcmtk/dcmtk${DCMTK_VERSION_SHORT}/dcmtk-${DCMTK_VERSION}.tar.gz"
DCMTK_DIR="${HOME}/dcmtk"
DCMTK_INSTALL_DIR="${DCMTK_DIR}/install"

# Exit immediately if a command exits with a non-zero status.
set -e

# ------------------------------
# Update system and install dependencies
# ------------------------------
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    cmake \
    wget \
    libpng-dev \
    libtiff-dev \
    libxml2-dev \
    libssl-dev \
    zlib1g-dev

sudo rm -rf ${DCMTK_DIR}
mkdir ${DCMTK_DIR}
cd ${DCMTK_DIR}

# ------------------------------
# Download sources
# ------------------------------
wget ${DCMTK_URL}
tar -xzf "dcmtk-${DCMTK_VERSION}.tar.gz"
cd "dcmtk-${DCMTK_VERSION}"

# ------------------------------
# Create build-scripts directory and configure with CMake
# ------------------------------
sudo rm -rf build
mkdir build && cd build

# Configure the build-scripts with the desired options.
cmake .. \
  -DCMAKE_INSTALL_PREFIX=${DCMTK_INSTALL_DIR} \
  -DBUILD_SHARED_LIBS=ON \
  -DDCMTK_ENABLE_CHARSET_CONVERSION=oficonv \
  -DDCMTK_WITH_PNG=ON \
  -DDCMTK_WITH_OPENSSL=ON \
  -DDCMTK_WITH_TIFF=ON \
  -DDCMTK_WITH_ZLIB=ON \

# ------------------------------
# Compile and install
# ------------------------------
make -j"$(nproc)"
sudo make install

# ------------------------------
# Check if DCMTK is installed in the custom install directory
# ------------------------------
if [ -x "${DCMTK_INSTALL_DIR}/bin/dcmdjpeg" ]; then
    echo "DCMTK installed successfully at ${DCMTK_INSTALL_DIR}."
else
    echo "DCMTK installation failed or dcmdjpeg is not found in ${DCMTK_INSTALL_DIR}."
    exit 1
fi
