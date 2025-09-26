#!/usr/bin/env bash
set -euo pipefail

# Base directories
USERVER_BASE_DIR="/data/gp/userver"
USERVER_SRC_DIR="${USERVER_BASE_DIR}/src"
USERVER_BUILD_DIR="${USERVER_BASE_DIR}/build"
USERVER_INSTALL_DIR="${USERVER_BASE_DIR}/install"

# Detect Ubuntu version for dependencies
UBUNTU_VER="$(. /etc/os-release && echo "${VERSION_ID}")"
DEPS_FILE="https://raw.githubusercontent.com/userver-framework/userver/refs/heads/develop/scripts/docs/en/deps/ubuntu-${UBUNTU_VER}.md"

# 1) Install build-scripts dependencies
echo "🔧 Installing dependencies for Ubuntu ${UBUNTU_VER}..."
sudo apt update
sudo apt install --allow-downgrades -y $(wget -q -O - "${DEPS_FILE}")

# 2) Clean previous build-scripts and install directories
echo "🚹 Cleaning old build and install directories..."
rm -rf "${USERVER_BUILD_DIR:?}" "${USERVER_INSTALL_DIR:?}"

# 3) Recreate build-scripts/install directories
echo "📁 Creating build/install directories..."
mkdir -p "${USERVER_BUILD_DIR}" "${USERVER_INSTALL_DIR}"

# 4) Prepare source directory
if [[ -d "${USERVER_SRC_DIR}" ]]; then
  echo "❗ Source directory exists. Removing: ${USERVER_SRC_DIR}"
  rm -rf "${USERVER_SRC_DIR}"
fi
mkdir -p "${USERVER_SRC_DIR}"

# 5) Clone the userver repository
echo "📥 Cloning userver into ${USERVER_SRC_DIR}..."
git clone https://github.com/userver-framework/userver.git "${USERVER_SRC_DIR}"

# 6) Build and install the Userver framework with tests and samples enabled
# This ensures userver_testsuite_add_simple and other macros are available
echo "⚙️  Configuring and building the Userver framework..."
cd "${USERVER_BUILD_DIR}"
cmake -Wno-dev \
  -DCMAKE_INSTALL_PREFIX="${USERVER_INSTALL_DIR}" \
  -DUSERVER_FEATURE_POSTGRESQL=1 \
  -DUSERVER_BUILD_SAMPLES=ON \
  -DUSERVER_BUILD_TESTS=ON \
  "${USERVER_SRC_DIR}"
echo "🔨 Building Userver framework..."
cmake --build-scripts . -- -j$(nproc)

echo "📦 Installing Userver framework..."
cmake --install .

# 7) Locate a valid sample service dynamically
echo "📂 Searching for sample services..."
SAMPLE_SRC=$(find "${USERVER_SRC_DIR}" -type f -name CMakeLists.txt -path '*/samples/*' -exec dirname {} \; | head -n 1)

if [[ -z "${SAMPLE_SRC}" ]]; then
  echo "❌ No sample service found (CMakeLists.txt under samples directory)."
  exit 1
fi

echo "✅ Found sample service at: ${SAMPLE_SRC}"

# 8) Configure & build-scripts the sample service in a fresh build-scripts subdirectory
echo "⚙️ Configuring build for sample service..."
SAMPLE_BUILD_DIR="${USERVER_BUILD_DIR}/sample"
rm -rf "${SAMPLE_BUILD_DIR}"
mkdir -p "${SAMPLE_BUILD_DIR}"
cd "${SAMPLE_BUILD_DIR}"
cmake -Wno-dev \
  -DCMAKE_PREFIX_PATH="${USERVER_INSTALL_DIR}" \
  -DCMAKE_INSTALL_PREFIX="${USERVER_INSTALL_DIR}" \
  -DUSERVER_FEATURE_POSTGRESQL=1 \
  "${SAMPLE_SRC}"

echo "🔨 Building sample service..."
cmake --build-scripts . -- -j$(nproc)

# 9) Locate and verify the built sample binary
echo "🚀 Locating built binary..."
SAMPLE_BIN=$(find "${SAMPLE_BUILD_DIR}" -type f -executable -maxdepth 2 | head -n 1)

if [[ -x "${SAMPLE_BIN}" ]]; then
  echo "✅ Found binary: ${SAMPLE_BIN}"
  "${SAMPLE_BIN}" --version || { echo "❌ Error running binary"; exit 1; }
else
  echo "❌ Binary not found after build."
  exit 1
fi

echo "🎉 Build and verification of sample service completed successfully!"

