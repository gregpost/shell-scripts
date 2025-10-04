#!/bin/bash
set -e

# VTK with VTK-DICOM support build from source

#############################
# Define directories
#############################
VTK_ROOT_DIR="$HOME/vtk"
VTK_SOURCE_DIR="$VTK_ROOT_DIR/src"
VTK_BUILD_DIR="$VTK_ROOT_DIR/build"
#VTK_INSTALL_DIR="$VTK_ROOT_DIR/install"
VTK_INSTALL_DIR="/usr/local"

INSTALL_PACKAGES=0 # включена установка пакетов apt
DOWNLOAD_SOURCES=0 # включена загрузка исходников

# Обработка аргументов командной строки
for arg in "$@"; do
  case $arg in
    --no-download)
      DOWNLOAD_SOURCES=0
      shift
      ;;
    --no-install)
      INSTALL_PACKAGES=0
      shift
      ;;
    *)
      echo "Неизвестный аргумент: $arg"
      exit 1
      ;;
  esac
done

#############################
# Install build dependencies
#############################
if [ "$INSTALL_PACKAGES" -eq 1 ]; then
  echo "Updating package lists..."
  sudo apt-get update

  echo "Installing build dependencies..."
  sudo apt-get install -y ninja-build cmake git build-essential libgdcm-dev libgdcm-tools libgl1-mesa-dev libxt-dev
else
  echo "Skipping package installation (--no-install flag detected)."
fi

#############################
# Clean previous directories
#############################
if [ -d "$VTK_BUILD_DIR" ]; then
  echo "Cleaning existing build directory: $VTK_BUILD_DIR"
  rm -rf "$VTK_BUILD_DIR"
fi

#############################
# Clone VTK source code
#############################
if [ "$DOWNLOAD_SOURCES" -eq 1 ]; then
  if [ -d "$VTK_SOURCE_DIR" ]; then
    echo "Cleaning existing source directory: $VTK_SOURCE_DIR"
    rm -rf "$VTK_SOURCE_DIR"
  fi

  echo "Cloning VTK source into $VTK_SOURCE_DIR..."
  git clone https://gitlab.kitware.com/vtk/vtk.git "$VTK_SOURCE_DIR"
else
  echo "Skipping source download (--no-download flag detected)."
fi

#############################
# Create build directory
#############################
mkdir -p "$VTK_BUILD_DIR"
cd "$VTK_BUILD_DIR"

#############################
# Configure the build with CMake
#############################
cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$VTK_INSTALL_DIR" \
  -DVTK_MODULE_ENABLE_VTK_DICOMParser:STRING=YES \
  -DVTK_GROUP_ENABLE_Qt:STRING=YES \
  -DVTK_MODULE_ENABLE_VTK_GUISupportQt:STRING=YES \
  -DVTK_MODULE_ENABLE_VTK_GUISupportQtQuick:STRING=NO \
  -DVTK_MODULE_ENABLE_VTK_GUISupportQtSQL:STRING=NO \
  -DVTK_MODULE_ENABLE_VTK_RenderingQt:STRING=YES \
  -DVTK_MODULE_ENABLE_VTK_ViewsQt:STRING=YES \
  "$VTK_SOURCE_DIR"

cmake -G Ninja \
  -DUSE_GDCM:BOOL=ON \
  -DVTK_MODULE_ENABLE_VTK_vtkDICOM:STRING=YES \
  -DVTK_MODULE_ENABLE_VTK_DICOM:STRING=YES \
  "$VTK_SOURCE_DIR"
  
#############################
# Build VTK using Ninja
#############################
echo "Building VTK..."
ninja -j$(nproc)

#############################
# Install VTK
#############################
echo "Installing VTK..."
sudo ninja install

#############################
# Final success installation check
#############################
if ls "$VTK_INSTALL_DIR"/lib/cmake/*/vtk-config.cmake >/dev/null 2>&1; then
  echo "VTK with VTK-DICOM support has been successfully installed in $VTK_INSTALL_DIR."
else
  echo "Installation appears to have failed: VTKConfig.cmake not found in $VTK_INSTALL_DIR/lib/cmake/*"
  exit 1
fi
