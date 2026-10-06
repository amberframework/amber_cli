#!/bin/bash

# Build script for creating release binaries locally
# This mimics what the GitHub Actions workflow does

set -euo pipefail

VERSION=${1:?"usage: scripts/build_release.sh X.Y.Z"}
OUTPUT_DIR="dist"

test "$VERSION" = "$(awk '/^version:/ { print $2; exit }' shard.yml)"
test -z "$(git status --porcelain)" || { echo "Commit the reviewed source before packaging it" >&2; exit 1; }
command -v crystal-alpha >/dev/null 2>&1 || { echo "crystal-alpha is required" >&2; exit 1; }
command -v minecart >/dev/null 2>&1 || { echo "minecart is required" >&2; exit 1; }
test -s shard.lock
export CRYSTAL_CACHE_DIR="$PWD/.crystal-cache"

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
    BUILD_CLI="crystal-alpha build src/amber_cli.cr -o amber --release"
    BUILD_LSP="crystal-alpha build src/amber_lsp.cr -o amber-lsp --release"
    CHECKSUM_CMD="shasum -a 256"
    if [ "${ARCH}" != "arm64" ]; then
      echo "Intel macOS is not a release target; build darwin-arm64 on Apple Silicon" >&2
      exit 1
    fi
    ;;
  "linux")
    case "${ARCH}" in
      "x86_64"|"amd64") TARGET="linux-x86_64" ;;
      "aarch64"|"arm64") TARGET="linux-arm64" ;;
      *)
        echo "❌ Unsupported Linux architecture: ${ARCH}"
        exit 1
        ;;
    esac
    BUILD_CLI="crystal-alpha build src/amber_cli.cr -o amber --release --static"
    BUILD_LSP="crystal-alpha build src/amber_lsp.cr -o amber-lsp --release --static"
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
minecart install --production --skip-ai-docs

# Build binaries
echo "🔨 Compiling amber CLI..."
eval "${BUILD_CLI}"

echo "🔨 Compiling amber-lsp..."
eval "${BUILD_LSP}"

# Verify binaries
echo "✅ Verifying binaries..."
file amber
./amber --version
file amber-lsp
test -x amber-lsp

# Create archive
echo "📦 Creating archive..."
git archive --format=tar.gz --prefix="amber_cli-${VERSION}/" HEAD > "${OUTPUT_DIR}/amber_cli-source-${VERSION}.tar.gz"

# Calculate checksum
echo "🔢 Calculating checksum..."
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum amber amber-lsp > "${OUTPUT_DIR}/checksums.txt"
else
  shasum -a 256 amber amber-lsp > "${OUTPUT_DIR}/checksums.txt"
fi
tar -czf "${OUTPUT_DIR}/amber_cli-${TARGET}.tar.gz" amber amber-lsp -C "${OUTPUT_DIR}" checksums.txt
mkdir -p "${OUTPUT_DIR}/verify"
tar -xzf "${OUTPUT_DIR}/amber_cli-${TARGET}.tar.gz" -C "${OUTPUT_DIR}/verify"
if command -v sha256sum >/dev/null 2>&1; then
  (cd "${OUTPUT_DIR}/verify" && sha256sum --check checksums.txt)
else
  (cd "${OUTPUT_DIR}/verify" && shasum -a 256 -c checksums.txt)
fi
cd "${OUTPUT_DIR}"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "amber_cli-${TARGET}.tar.gz" > "amber_cli-${TARGET}.tar.gz.sha256"
  sha256sum "amber_cli-source-${VERSION}.tar.gz" > "amber_cli-source-${VERSION}.tar.gz.sha256"
else
  ${CHECKSUM_CMD} "amber_cli-${TARGET}.tar.gz" > "amber_cli-${TARGET}.tar.gz.sha256"
  ${CHECKSUM_CMD} "amber_cli-source-${VERSION}.tar.gz" > "amber_cli-source-${VERSION}.tar.gz.sha256"
fi
SHA256=$(cut -d' ' -f1 < "amber_cli-${TARGET}.tar.gz.sha256")

echo ""
echo "🎉 Build complete!"
echo "📁 Output: ${OUTPUT_DIR}/amber_cli-${TARGET}.tar.gz"
echo "🔒 Commit: $(git -C .. rev-parse HEAD)"
echo "🔑 SHA256: ${SHA256}"
echo "🔑 Source SHA256: $(cut -d' ' -f1 < "amber_cli-source-${VERSION}.tar.gz.sha256")"
echo ""
echo "To test the archive:"
echo "  tar -xzf ${OUTPUT_DIR}/amber_cli-${TARGET}.tar.gz"
echo "  ./amber --version"
echo "  test -x ./amber-lsp"
