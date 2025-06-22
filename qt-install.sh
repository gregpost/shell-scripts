#!/bin/bash

# ==================== ROOT PATH ==========================
ROOT_DIR="/data/qt"

# ==================== QT VERSION =========================
MAJOR="6"
MINOR="8"
PATCH="0"
QT_VERSION="$MAJOR.$MINOR.$PATCH"
QT_BASE_URL="https://mirror.yandex.ru/mirrors/qt.io/official_releases/qt/$MAJOR.$MINOR/$QT_VERSION/submodules/qtbase-everywhere-src-$QT_VERSION.tar.xz"
QT_COMPAT_URL="https://mirror.yandex.ru/mirrors/qt.io/official_releases/qt/$MAJOR.$MINOR/$QT_VERSION/submodules/qt5compat-everywhere-src-$QT_VERSION.tar.xz"

# ====================== CONFIG ===========================
DOWNLOAD_DIR="$ROOT_DIR/download"
SRC_DIR="$ROOT_DIR/src"
BUILD_DIR="$ROOT_DIR/build"
INSTALL_PREFIX="$ROOT_DIR"

QT_BASE_TAR="$DOWNLOAD_DIR/qtbase-everywhere-src-$QT_VERSION.tar.xz"
QT_COMPAT_TAR="$DOWNLOAD_DIR/qt5compat-everywhere-src-$QT_VERSION.tar.xz"

QT_BASE_SRC="$SRC_DIR/qtbase-everywhere-src-$QT_VERSION"
QT_COMPAT_SRC="$SRC_DIR/qt5compat-everywhere-src-$QT_VERSION"

QT_BASE_BUILD="$BUILD_DIR/qt-base"
QT_COMPAT_BUILD="$BUILD_DIR/qt-compat"

FORCE=false
set -e

# ======================== FLAGS ==========================
if [[ "$1" == "--force" ]]; then
  FORCE=true
  echo "⚠️ Force rebuild and reinstall enabled"
fi

# ======================= HELPERS =========================
check_success() {
  if [ $? -ne 0 ]; then
    echo "❌ Ошибка: $1"
    exit 1
  fi
}

download_file() {
  local url="$1"
  local dest="$2"
  if [ "$FORCE" = true ] || [ ! -f "$dest" ]; then
    echo "⬇️ Downloading $url..."
    wget -q "$url" -O "$dest"
    check_success "Failed to download $url"
  else
    echo "✅ File $dest already exists. Skipping download."
  fi
}

extract_tar() {
  local tarball="$1"
  local dest_dir="$2"
  if [ "$FORCE" = true ] || [ ! -d "$dest_dir" ]; then
    echo "📦 Extracting $tarball..."
    mkdir -p "$SRC_DIR"
    tar -xf "$tarball" -C "$SRC_DIR"
    check_success "Failed to extract $tarball"
  else
    echo "✅ Directory $dest_dir already exists. Skipping extraction."
  fi
}

build_module() {
  local src_dir="$1"
  local build_dir="$2"
  local module_name="$3"

  if [ "$FORCE" = true ]; then
    sudo rm -rf "$build_dir"
  fi

  if [ "$FORCE" = true ] || [ ! -d "$build_dir" ]; then
    echo "🔧 Preparing build directory for $module_name..."
    mkdir -p "$build_dir"
    check_success "Could not create $build_dir"
  else
    echo "✅ Build directory $build_dir exists."
  fi

  echo "⚙️ Configuring $module_name..."
  cmake -S "$src_dir" -B "$build_dir" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_PREFIX_PATH="$INSTALL_PREFIX/lib/cmake"
  check_success "CMake configuration for $module_name failed"

  echo "🛠️ Cleaning previous build of $module_name..."
  make -C "$build_dir" clean || true

  echo "🏗️ Building $module_name..."
  make -C "$build_dir" -j$(nproc)
  check_success "Build for $module_name failed"
}

install_module() {
  local build_dir="$1"
  local module_name="$2"
  local config_file="$INSTALL_PREFIX/lib/cmake/Qt6/Qt6Config.cmake"

  if [ "$FORCE" = true ] || [ ! -f "$config_file" ]; then
    echo "📦 Installing $module_name..."
    make -C "$build_dir" install
    check_success "Installation for $module_name failed"
  else
    echo "✅ $module_name already installed. Skipping."
  fi

  if [ ! -f "$config_file" ]; then
    echo "❌ Error: Qt6Config.cmake not found after installing $module_name"
    echo "       Expected at: $config_file"
    exit 1
  fi
}


# ====================== MAIN FLOW ========================
echo "📁 Preparing directories..."
mkdir -p "$DOWNLOAD_DIR" "$SRC_DIR" "$BUILD_DIR"
cd "$DOWNLOAD_DIR" || exit 1

# ---- Step 1: Download ----
download_file "$QT_BASE_URL" "$QT_BASE_TAR"
download_file "$QT_COMPAT_URL" "$QT_COMPAT_TAR"

# ---- Step 2: Extract ----
extract_tar "$QT_BASE_TAR" "$QT_BASE_SRC"
extract_tar "$QT_COMPAT_TAR" "$QT_COMPAT_SRC"

# ---- Step 3: Build ----
build_module "$QT_BASE_SRC" "$QT_BASE_BUILD" "Qt Base"
build_module "$QT_COMPAT_SRC" "$QT_COMPAT_BUILD" "Qt 5Compat"

# ---- Step 4: Install ----
install_module "$QT_BASE_BUILD" "Qt Base"
install_module "$QT_COMPAT_BUILD" "Qt 5Compat"

# ---- Step 5: Validate qmake ----
QMAKE_PATH="$INSTALL_PREFIX/bin/qmake"
if [ ! -f "$QMAKE_PATH" ]; then
  echo "❌ qmake not found at $QMAKE_PATH. Installation might be incomplete."
  exit 1
else
  echo "✅ qmake found at $QMAKE_PATH"
fi

# ---- Step 6: Environment variables ----
echo "🌐 Updating environment variables..."
grep -q "$INSTALL_PREFIX/bin" ~/.bashrc || echo "export PATH=\"$INSTALL_PREFIX/bin:\$PATH\"" >> ~/.bashrc
grep -q "$INSTALL_PREFIX/lib" ~/.bashrc || echo "export LD_LIBRARY_PATH=\"$INSTALL_PREFIX/lib:\$LD_LIBRARY_PATH\"" >> ~/.bashrc
grep -q "$INSTALL_PREFIX/lib/cmake" ~/.bashrc || echo "export CMAKE_PREFIX_PATH=\"$INSTALL_PREFIX/lib/cmake:\$CMAKE_PREFIX_PATH\"" >> ~/.bashrc

# Apply for current session
export PATH="$INSTALL_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH"
export CMAKE_PREFIX_PATH="$INSTALL_PREFIX/lib/cmake:$CMAKE_PREFIX_PATH"

echo "🎉 Qt $QT_VERSION installation completed successfully."

