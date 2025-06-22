#!/usr/bin/env bash

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

# Flags
FORCE=false
SKIP_QT5COMPAT=false
set -euo pipefail

# ======================== PARSING ========================
for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE=true
      echo "⚠️  Force rebuild enabled"
      ;;
    --skip-qt5compat)
      SKIP_QT5COMPAT=true
      echo "⚠️  Skipping Qt5Compat module"
      ;;
    *)
      # ignore other args
      ;;
  esac
done

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
    echo "✅  $module_name source already exists"
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
    mkdir -p "$build_dir"
    check_success "Could not create $build_dir"
  fi

  echo "⚙️  Configuring $module_name..."
  rm -f "$build_dir/CMakeCache.txt"

  # Ensure environment variables won't cause unbound errors
  export PATH="$INSTALL_PREFIX/bin:$PATH"
  export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:${LD_LIBRARY_PATH:-}"
  export CMAKE_PREFIX_PATH="$INSTALL_PREFIX/lib/cmake${CMAKE_PREFIX_PATH:+:}${CMAKE_PREFIX_PATH:-}"

  cmake -S "$src_dir" -B "$build_dir" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_PREFIX_PATH="$INSTALL_PREFIX/lib/cmake" \
    -DQt6_DIR="$INSTALL_PREFIX/lib/cmake/Qt6" \
    -DQT_NO_PACKAGE_VERSION_CHECK=TRUE \
    -DQT_NO_PACKAGE_VERSION_INCOMPATIBLE_WARNING=TRUE
  check_success "CMake configuration for $module_name failed"

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
    exit 1
  fi
}

# ====================== MAIN FLOW ========================

echo "📁 Preparing directories..."
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_PREFIX"

# Clone Qt Base always
clone_module "$QTBASE_REPO" "$QT_BASE_SRC" "Qt Base"

# Clone Qt5Compat only if not skipped
if [ "$SKIP_QT5COMPAT" = false ]; then
  clone_module "$QT5COMPAT_REPO" "$QT_COMPAT_SRC" "Qt 5Compat"
fi

# Set environment for local Qt (guard unbound)
echo "🌐 Setting environment for local Qt"
export PATH="$INSTALL_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:${LD_LIBRARY_PATH:-}"
export CMAKE_PREFIX_PATH="$INSTALL_PREFIX/lib/cmake${CMAKE_PREFIX_PATH:+:}${CMAKE_PREFIX_PATH:-}"

# Build Qt Base
build_module "$QT_BASE_SRC" "$QT_BASE_BUILD" "Qt Base"

# Build Qt5Compat if not skipped
if [ "$SKIP_QT5COMPAT" = false ]; then
  build_module "$QT_COMPAT_SRC" "$QT_COMPAT_BUILD" "Qt 5Compat"
fi

# Install Qt Base
install_module "$QT_BASE_BUILD" "Qt Base"

# Install Qt5Compat if not skipped
if [ "$SKIP_QT5COMPAT" = false ]; then
  install_module "$QT_COMPAT_BUILD" "Qt 5Compat"
fi

# Validate qmake
QMAKE_PATH="$INSTALL_PREFIX/bin/qmake"
if [ ! -f "$QMAKE_PATH" ]; then
  echo "❌ qmake not found at $QMAKE_PATH"
  exit 1
fi

echo "✅ Qt $QT_VERSION installed in $INSTALL_PREFIX"
