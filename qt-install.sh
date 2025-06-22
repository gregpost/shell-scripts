#!/bin/bash

# ==================== ROOT PATH ==========================
ROOT_DIR="/data/qt"

# ==================== QT VERSION =========================
MAJOR="6"
MINOR="8"
PATCH="0"
QT_VERSION="$MAJOR.$MINOR.$PATCH"
QT_TAG="v$QT_VERSION"

# Module repo URLs
QTBASE_REPO="https://code.qt.io/qt/qtbase.git"
QT5COMPAT_REPO="https://code.qt.io/qt/qt5compat.git"

# ====================== CONFIG ===========================
SRC_DIR="$ROOT_DIR/src"
BUILD_DIR="$ROOT_DIR/build"
INSTALL_PREFIX="$ROOT_DIR"

QT_BASE_SRC="$SRC_DIR/qtbase"
QT_COMPAT_SRC="$SRC_DIR/qt5compat"

QT_BASE_BUILD="$BUILD_DIR/qt-base"
QT_COMPAT_BUILD="$BUILD_DIR/qt-compat"

FORCE=false
set -e

# ======================== FLAGS ==========================
if [[ "$1" == "--force" ]]; then
  FORCE=true
  echo "⚠️  Force rebuild enabled: old source, build and install dirs will be reset"
fi

# ======================= HELPERS =========================
check_success() {
  if [ $? -ne 0 ]; then
    echo "❌ Error: $1"
    exit 1
  fi
}

clone_module() {
  local repo_url="$1"
  local dest_dir="$2"
  local module_name="$3"

  if [ "$FORCE" = true ] && [ -d "$dest_dir" ]; then
    echo "🗑️  Removing old $module_name source"
    rm -rf "$dest_dir"
  fi

  if [ ! -d "$dest_dir" ]; then
    echo "⬇️  Cloning $module_name from $repo_url (tag $QT_TAG)..."
    git clone --depth 1 --branch "$QT_TAG" "$repo_url" "$dest_dir"
    check_success "Failed to clone $module_name"
  else
    echo "✅  $module_name source already exists, fetching latest $QT_TAG..."
    cd "$dest_dir"
    git fetch --depth 1 origin "$QT_TAG"
    git checkout "$QT_TAG"
    check_success "Failed to update $module_name to $QT_TAG"
    cd - >/dev/null
  fi
}

build_module() {
  local src_dir="$1"
  local build_dir="$2"
  local module_name="$3"

  if [ "$FORCE" = true ]; then
    echo "🗑️  Removing old build dir for $module_name"
    rm -rf "$build_dir"
  fi

  if [ ! -d "$build_dir" ]; then
    echo "🔧 Preparing build directory for $module_name..."
    mkdir -p "$build_dir"
    check_success "Could not create $build_dir"
  else
    echo "✅ Build directory $build_dir exists."
  fi

  echo "⚙️  Configuring $module_name..."
  rm -f "$build_dir/CMakeCache.txt"

  # Point CMake at our just-built Qt only
  export PATH="$INSTALL_PREFIX/bin:$PATH"
  export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH"
  export CMAKE_PREFIX_PATH="$INSTALL_PREFIX/lib/cmake:$CMAKE_PREFIX_PATH"

  cmake -S "$src_dir" -B "$build_dir" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_PREFIX_PATH="$INSTALL_PREFIX/lib/cmake" \
    -DQt6_DIR="$INSTALL_PREFIX/lib/cmake/Qt6" \
    -DQT_NO_PACKAGE_VERSION_CHECK=TRUE \
    -DQT_NO_PACKAGE_VERSION_INCOMPATIBLE_WARNING=TRUE
  check_success "CMake configuration for $module_name failed"

  echo "🛠️  Cleaning previous $module_name build..."
  make -C "$build_dir" clean || true

  echo "🏗️  Building $module_name..."
  make -C "$build_dir" -j"$(nproc)"
  check_success "Build for $module_name failed"
}

install_module() {
  local build_dir="$1"
  local module_name="$2"
  local config_file="$INSTALL_PREFIX/lib/cmake/Qt6/Qt6Config.cmake"

  echo "📦 Installing $module_name..."
  make -C "$build_dir" install
  check_success "Installation for $module_name failed"

  if [ ! -f "$config_file" ]; then
    echo "❌ Error: Qt6Config.cmake not found after installing $module_name"
    echo "       Expected at: $config_file"
    exit 1
  fi
}

# ====================== MAIN FLOW ========================
echo "📁 Preparing directories..."
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_PREFIX"

# ---- Step 1: Clone Qt modules from Git ----
clone_module "$QTBASE_REPO"    "$QT_BASE_SRC"   "Qt Base"
clone_module "$QT5COMPAT_REPO" "$QT_COMPAT_SRC" "Qt 5Compat"

# ---- Step 2: Build ----
echo "🌐 Exporting environment to prefer local Qt over system Qt"
export PATH="$INSTALL_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:$LD_LIBRARY_PATH"
export CMAKE_PREFIX_PATH="$INSTALL_PREFIX/lib/cmake:$CMAKE_PREFIX_PATH"

build_module "$QT_BASE_SRC"   "$QT_BASE_BUILD"   "Qt Base"
build_module "$QT_COMPAT_SRC" "$QT_COMPAT_BUILD" "Qt 5Compat"

# ---- Step 3: Install ----
install_module "$QT_BASE_BUILD"   "Qt Base"
install_module "$QT_COMPAT_BUILD" "Qt 5Compat"

# ---- Step 4: Validate qmake ----
QMAKE_PATH="$INSTALL_PREFIX/bin/qmake"
if [ ! -f "$QMAKE_PATH" ]; then
  echo "❌ qmake not found at $QMAKE_PATH. Installation might be incomplete."
  exit 1
else
  echo "✅ qmake found at $QMAKE_PATH"
fi

# ---- Step 5: Persist environment ----
echo "🌐 Updating ~/.bashrc for future sessions..."
grep -q "$INSTALL_PREFIX/bin" ~/.bashrc || echo "export PATH=\"$INSTALL_PREFIX/bin:\$PATH\"" >> ~/.bashrc
grep -q "$INSTALL_PREFIX/lib" ~/.bashrc || echo "export LD_LIBRARY_PATH=\"$INSTALL_PREFIX/lib:\$LD_LIBRARY_PATH\"" >> ~/.bashrc
grep -q "$INSTALL_PREFIX/lib/cmake" ~/.bashrc || echo "export CMAKE_PREFIX_PATH=\"$INSTALL_PREFIX/lib/cmake:\$CMAKE_PREFIX_PATH\"" >> ~/.bashrc

echo "🎉 Qt $QT_VERSION from Git has been built and installed successfully."
