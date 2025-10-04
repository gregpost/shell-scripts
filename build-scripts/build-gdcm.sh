#!/bin/bash
set -e

#####################################
# Configuration Variables
#####################################
# URL of the GDCM repository and branch to clone
GDCM_REPO_URL="git://git.code.sf.net/p/gdcm/gdcm"
GDCM_BRANCH="release"
GDCM_CLONE_OPTIONS="--branch ${GDCM_BRANCH}"
# Directory where the GDCM repository will be cloned
GDCM_ROOT_DIR="${HOME}/gdcm"
GDCM_REPO_DIR="${GDCM_ROOT_DIR}/repo"
# Directory for out-of-source build
GDCM_BUILD_DIR="${GDCM_ROOT_DIR}/build"
# Default installation prefix (can be overridden via command-line)
DEFAULT_INSTALL_PREFIX="/usr/local" # or manual path: "${GDCM_ROOT_DIR}/install"
#####################################

# Check for required tools: git, cmake, make, etc.
for tool in git cmake make; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Error: $tool is not installed. Please install it and try again."
        exit 1
    fi
done

# Clone the GDCM repository if not already cloned
if [ ! -d "$GDCM_REPO_DIR" ]; then
    echo "Cloning GDCM repository..."
    git clone $GDCM_CLONE_OPTIONS "$GDCM_REPO_URL" "$GDCM_REPO_DIR"
fi

# Create and enter the build directory
rm -rf "$GDCM_BUILD_DIR"
mkdir -p "$GDCM_BUILD_DIR"
cd "$GDCM_BUILD_DIR"

# Configure the project with cmake:
# - Enable VTK support (GDCM_USE_VTK=ON)
# - Enable shared library build (GDCM_BUILD_SHARED_LIBS=ON)
# - Set CMAKE_INSTALL_PREFIX if installation is requested.
echo "Configuring GDCM build..."
cmake \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
  -DGDCM_USE_VTK:BOOL=OFF \
  -DGDCM_BUILD_SHARED_LIBS:BOOL=ON \
  -DGDCM_USE_JPEGLS:BOOL=ON \
  -DOPJ_USE_THREAD:BOOL=ON \
   "$GDCM_REPO_DIR"

# Build using all available CPU cores
echo "Building GDCM..."
make -j$(nproc)

# Perform installation
echo "Installing GDCM to $INSTALL_PREFIX (you might need sudo privileges)..."
sudo make install

# Check if GDCM is installed properly by verifying the existence of 'gdcmdump'
# If installed, check in the specified install directory or in PATH
if [ -x "$INSTALL_PREFIX/bin/gdcmdump" ] || command -v gdcmdump &> /dev/null; then
     echo "GDCM installation complete."
else
     echo "Error: GDCM installation check failed. 'gdcmdump' not found."
     exit 1
fi