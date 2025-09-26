#!/usr/bin/env bash
set -euo pipefail


# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ============= ROOT PATH (FILL ONLY THIS) ================
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
ROOT_DIR="${ROOT_DIR:-/data/qt}"
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


# README:
# This script installs Qt6 + Qt5 Compatibility module to the ROOT_DIR
#
# Usage:
# --force: completely remove all files (source code will be downloaded again)
# --force-build-scripts: clear only the build-scripts and install directory
# --skip-qt5compat: skip Qt5 Compatibility module


# ==================== QT VERSION =========================
MAJOR="6"; MINOR="8"; PATCH="0"
QT_VERSION="$MAJOR.$MINOR.$PATCH"
QT_ROOT_URL="https://mirror.yandex.ru/mirrors/qt.io/official_releases/qt/$MAJOR.$MINOR/$QT_VERSION"
QT_BASE_ARCHIVE="qt-everywhere-src-$QT_VERSION.tar.xz"
QT_BASE_URL="$QT_ROOT_URL/single/$QT_BASE_ARCHIVE"
QT5_COMPAT_ARCHIVE="qt5compat-everywhere-src-$QT_VERSION.tar.xz"
QT5_COMPAT_URL="$QT_ROOT_URL/submodules/$QT5_COMPAT_ARCHIVE"

echo "📁 ROOT_DIR = $ROOT_DIR"
echo "🌐 QT_BASE_URL     = $QT_BASE_URL"

SRC_DIR="$ROOT_DIR/src"
BUILD_DIR="$ROOT_DIR/build"
INSTALL_PREFIX="$ROOT_DIR/qt-install"

QT_SRC="$SRC_DIR/qt-everywhere-src-$QT_VERSION"
QT5COMPAT_SRC="$SRC_DIR/qt5compat-everywhere-src-$QT_VERSION"
QT_BUILD="$BUILD_DIR/qt6"
QT5COMPAT_BUILD="$BUILD_DIR/qt5compat"

# ========== Обработка аргументов ==========
FORCE_ALL=false
FORCE_BUILD=false
SKIP_QT5COMPAT=false
for arg in "$@"; do
  case "$arg" in
    --force)           FORCE_ALL=true ;;
    --force-build-scripts)     FORCE_BUILD=true ;;
    --skip-qt5compat)  SKIP_QT5COMPAT=true ;;
    *) ;;
  esac
done

echo "FORCE_ALL = $FORCE_ALL"
echo "FORCE_BUILD = $FORCE_BUILD"
echo "SKIP_QT5COMPAT = $SKIP_QT5COMPAT"

err() { echo "❌ $*" >&2; exit 1; }

# Проверка и установка зависимостей xcb
REQUIRED_PKGS=(
  libx11-dev libx11-xcb-dev libxcb1-dev libxcb-glx0-dev libxcb-icccm4-dev
  libxcb-image0-dev libxcb-keysyms1-dev libxcb-randr0-dev libxcb-render-util0-dev
  libxcb-shape0-dev libxcb-shm0-dev libxcb-sync-dev libxcb-xfixes0-dev
  libxcb-xinerama0-dev libxcb-xkb-dev libxcb-cursor-dev libxkbcommon-dev
  libxkbcommon-x11-dev
)

MISSING_PKGS=()
for pkg in "${REQUIRED_PKGS[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    MISSING_PKGS+=("$pkg")
  fi
done

if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
  echo "📦 Installing missing packages: ${MISSING_PKGS[*]}"
  sudo apt-get update
  sudo apt-get install -y "${MISSING_PKGS[@]}"
else
  echo "✅ All required xcb packages are already installed."
fi

# Полная очистка при --force
if [ "$FORCE_ALL" = true ] && [ -d "$ROOT_DIR" ]; then
  echo "⚠️  --force: removing $ROOT_DIR"
  rm -rf "$ROOT_DIR"
fi

# Очистка только build-scripts при --force-build-scripts
if [ "$FORCE_BUILD" = true ] && [ -d "$BUILD_DIR" ]; then
  echo "⚠️  --force-build: removing $BUILD_DIR and $INSTALL_PREFIX"
  rm -rf "$BUILD_DIR"
  rm -rf "$INSTALL_PREFIX"
fi

echo "📁 Prepare dirs..."
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$INSTALL_PREFIX"

# ========== Qt Base sources ==========
QT_BASE_ARCHIVE_PATH="$SRC_DIR/$QT_BASE_ARCHIVE"
if [ ! -d "$QT_SRC" ]; then
  [ -f "$QT_BASE_ARCHIVE_PATH" ] || {
    echo "⬇️  Downloading Qt base..."
    curl -L -o "$QT_BASE_ARCHIVE_PATH" "$QT_BASE_URL" || err "Download failed"
  }
  tar -xf "$QT_BASE_ARCHIVE_PATH" -C "$SRC_DIR" || err "Extraction failed"
fi

# ========== qt5compat sources (если нужно) ==========
if [ "$SKIP_QT5COMPAT" = false ]; then
  QT5_COMPAT_ARCHIVE_PATH="$SRC_DIR/$QT5_COMPAT_ARCHIVE"
  if [ ! -d "$QT5COMPAT_SRC" ]; then
    [ -f "$QT5_COMPAT_ARCHIVE_PATH" ] || {
      echo "⬇️  Downloading qt5compat from $QT5_COMPAT_URL"
      curl -L -o "$QT5_COMPAT_ARCHIVE_PATH" "$QT5_COMPAT_URL" || err "qt5compat download failed"
    }
    tar -xf "$QT5_COMPAT_ARCHIVE_PATH" -C "$SRC_DIR" || err "qt5compat extract failed"
  fi
fi

# ========== Модули, которые мы пропускаем ==========
ALL_MODULES=(
  qt3d qt3danimation qt3dcore qt3dextras qt3dinput qt3dlogic qt3drender qt3dscene2d
  qtactiveqt qtaxcontainer qtaxserver
  qtbluetooth qtcharts qtcoap qtconcurrent qtdatavis3d qtdesigner qtdoc
  qtgamepad qtgrpc qtgraphs qthttpserver qthelp
  qtlanguageserver qtlocation qtlottie qtmqtt qtmultimedia
  qtnfc qtnetworkauth qtopcua qtopengl qtpdf qtpositioning qtprintsupport
  qtquick3d qtquick3dphysics qtquickcontrols qtquickcontrols2 qtquicktest qtquicktimeline qtquickeffectmaker qtquickwidgets
  qtremoteobjects qtscxml qtsensors qtserialbus qtserialport qtspatialaudio
  qtstatemachine qtspeech qtsql qtsvg qttexttospeech qttranslations
  qtuitools qtvirtualkeyboard qtwaylandcompositor
  qtwebchannel qtwebengine qtwebenginecore qtwebenginequick qtwebenginewidgets qtwebglplugin qtwebsockets qtwebview
  qtxml qtxmlpatterns qttools
  qtcanvas3d qtconnectivity qtgraphicaleffects qtpurchasing qtscript
  qtimageformats qtshadertools qtdeclarative
  qtx11extras
)

SKIP_FLAGS=()
for m in "${ALL_MODULES[@]}"; do
  SKIP_FLAGS+=("-skip" "$m")
done
if [ "$SKIP_QT5COMPAT" = true ]; then
  SKIP_FLAGS+=("-skip" "qt5compat")
fi

# ========== Сборка Qt Base ==========
echo "⚙️  Configuring Qt6 (qtbase only)..."
mkdir -p "$QT_BUILD" && pushd "$QT_BUILD" >/dev/null

# This flags need to reduce build-scripts size:
# -reduce-exports, -no-pch, -no-gtk, -no-cups, -no-gbm
# -nomake examples -nomake tests
bash "$QT_SRC/configure" \
  --prefix="$INSTALL_PREFIX" \
  -opensource -confirm-license -release \
  -nomake examples -nomake tests \
  -reduce-exports \
  -no-pch \
  -no-gtk \
  -no-cups \
  -no-gbm \
  "${SKIP_FLAGS[@]}" || err "configure failed"

echo "🏗️  Building Qt6..."
cmake --build-scripts . --parallel || err "build failed"

echo "📦 Installing Qt6..."
cmake --install . || err "install failed"
popd >/dev/null

if [ "$SKIP_QT5COMPAT" = false ]; then
  echo "⚙️  Configuring qt5compat..."
  mkdir -p "$QT5COMPAT_BUILD" && pushd "$QT5COMPAT_BUILD" >/dev/null
  cmake "$QT5COMPAT_SRC" -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" || err "cmake failed"
  echo "🏗️  Building qt5compat..."
  cmake --build-scripts . --parallel || err "qt5compat build failed"
  echo "📦 Installing qt5compat..."
  cmake --install . || err "qt5compat install failed"
  popd >/dev/null
fi

echo "✅ Qt $QT_VERSION installed in $INSTALL_PREFIX"
echo "   Add to PATH: export PATH=\"$INSTALL_PREFIX/bin:\$PATH\""
