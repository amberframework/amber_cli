#!/bin/bash

# Build script for creating release binaries locally
# This mimics what the GitHub Actions workflow does

set -euo pipefail

VERSION=${1:-"dev"}
OUTPUT_DIR="dist"

echo "🔨 Building Amber CLI v${VERSION}"

# Clean previous builds
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Get current platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "${OS}" in
  "darwin")
    TARGET="darwin-arm64"
    BUILD_CLI="crystal build src/amber_cli.cr -o amber --release"
    BUILD_LSP="crystal build src/amber_lsp.cr -o amber-lsp --release"
    CHECKSUM_CMD="shasum -a 256"
    if [ "${ARCH}" != "arm64" ]; then
      echo "⚠️  Warning: Building for ARM64 on ${ARCH} architecture"
      echo "   This will create a native build for your current architecture"
    fi
    ;;
  "linux")
    TARGET="linux-x86_64"
    BUILD_CLI="crystal build src/amber_cli.cr -o amber --release --static"
    BUILD_LSP="crystal build src/amber_lsp.cr -o amber-lsp --release --static"
    CHECKSUM_CMD="sha256sum"
    ;;
  *)
    echo "❌ Unsupported OS: ${OS}"
    exit 1
    ;;
esac

echo "🎯 Building for target: ${TARGET}"

# Install dependencies
echo "📦 Installing dependencies..."
shards install --production

# Build binaries
echo "🔨 Compiling amber CLI..."
eval "${BUILD_CLI}"

echo "🔨 Compiling amber-lsp..."
eval "${BUILD_LSP}"

# Verify binaries
echo "✅ Verifying binaries..."
file amber
./amber
file amber-lsp
test -x amber-lsp

# Create archive
echo "📦 Creating archive..."
tar -czf "${OUTPUT_DIR}/amber_cli-${TARGET}.tar.gz" amber amber-lsp

# Calculate checksum
echo "🔢 Calculating checksum..."
cd "${OUTPUT_DIR}"
${CHECKSUM_CMD} "amber_cli-${TARGET}.tar.gz" > "amber_cli-${TARGET}.tar.gz.sha256"
SHA256=$(cut -d' ' -f1 < "amber_cli-${TARGET}.tar.gz.sha256")

echo ""
echo "🎉 Build complete!"
echo "📁 Output: ${OUTPUT_DIR}/amber_cli-${TARGET}.tar.gz"
echo "🔑 SHA256: ${SHA256}"
echo ""
echo "To test the archive:"
echo "  tar -xzf ${OUTPUT_DIR}/amber_cli-${TARGET}.tar.gz"
echo "  ./amber --version"
echo "  test -x ./amber-lsp"
