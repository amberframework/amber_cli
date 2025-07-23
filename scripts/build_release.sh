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
    BUILD_CMD="crystal build src/amber_cli.cr -o amber --release"
    if [ "${ARCH}" != "arm64" ]; then
      echo "⚠️  Warning: Building for ARM64 on ${ARCH} architecture"
      echo "   This will create a native build for your current architecture"
    fi
    ;;
  "linux")
    TARGET="linux-x86_64"
    BUILD_CMD="crystal build src/amber_cli.cr -o amber --release --static"
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

# Build binary
echo "🔨 Compiling binary..."
eval "${BUILD_CMD}"

# Verify binary
echo "✅ Verifying binary..."
file amber
./amber

# Create archive
echo "📦 Creating archive..."
tar -czf "${OUTPUT_DIR}/amber-cli-${TARGET}.tar.gz" amber

# Calculate checksum
echo "🔢 Calculating checksum..."
cd "${OUTPUT_DIR}"
sha256sum "amber-cli-${TARGET}.tar.gz" > "amber-cli-${TARGET}.tar.gz.sha256"
SHA256=$(cat "amber-cli-${TARGET}.tar.gz.sha256" | cut -d' ' -f1)

echo ""
echo "🎉 Build complete!"
echo "📁 Output: ${OUTPUT_DIR}/amber-cli-${TARGET}.tar.gz"
echo "🔑 SHA256: ${SHA256}"
echo ""
echo "To test the archive:"
echo "  tar -xzf ${OUTPUT_DIR}/amber-cli-${TARGET}.tar.gz"
echo "  ./amber --version" 