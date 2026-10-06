#!/bin/bash

# Build release binaries and archives locally in the same layout as the workflow.

set -euo pipefail

VERSION=${1:?"usage: scripts/build_release.sh X.Y.Z"}
OUTPUT_DIR="$PWD/.luna/release-assets/amber_cli-${VERSION}-final"
BUILD_DIR="$OUTPUT_DIR/build"
PACKAGE_ROOT="$OUTPUT_DIR/package"

test "$VERSION" = "$(awk '/^version:/ { print $2; exit }' shard.yml)"
test -z "$(git status --porcelain)" || { echo "Commit the reviewed source before packaging it" >&2; exit 1; }
command -v crystal-alpha >/dev/null 2>&1 || { echo "crystal-alpha is required" >&2; exit 1; }
test -s shard.lock
export CRYSTAL_CACHE_DIR="$PWD/.crystal-cache"

echo "Building Amber CLI v${VERSION}"

rm -rf "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR" "$PACKAGE_ROOT/share/amber_cli/api"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
PLATFORM_FLAG=""

case "$OS" in
  darwin)
    TARGET="darwin-arm64"
    CHECKSUM_CMD=(shasum -a 256)
    if [ "$ARCH" != "arm64" ]; then
      echo "Intel macOS is not a release target; build darwin-arm64 on Apple Silicon" >&2
      exit 1
    fi
    ;;
  linux)
    case "$ARCH" in
      x86_64|amd64) TARGET="linux-x86_64" ;;
      aarch64|arm64) TARGET="linux-arm64" ;;
      *)
        echo "Unsupported Linux architecture: $ARCH" >&2
        exit 1
        ;;
    esac
    PLATFORM_FLAG="--static"
    CHECKSUM_CMD=(sha256sum)
    ;;
  *)
    echo "Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

echo "Building for target: $TARGET"

echo "Installing dependencies..."
if command -v minecart >/dev/null 2>&1; then
  minecart install --frozen --production --skip-ai-docs
else
  command -v shards-alpha >/dev/null 2>&1 || { echo "minecart or shards-alpha is required" >&2; exit 1; }
  shards-alpha install --production --frozen
fi

echo "Compiling amber..."
if [ -n "$PLATFORM_FLAG" ]; then
  crystal-alpha build src/amber_cli.cr -o "$BUILD_DIR/amber" --release "$PLATFORM_FLAG"
else
  crystal-alpha build src/amber_cli.cr -o "$BUILD_DIR/amber" --release
fi

echo "Compiling amber-lsp..."
if [ -n "$PLATFORM_FLAG" ]; then
  crystal-alpha build src/amber_lsp.cr -o "$BUILD_DIR/amber-lsp" --release "$PLATFORM_FLAG"
else
  crystal-alpha build src/amber_lsp.cr -o "$BUILD_DIR/amber-lsp" --release
fi

"$BUILD_DIR/amber" --version
"$BUILD_DIR/amber-lsp" --version
test -x "$BUILD_DIR/amber"
test -x "$BUILD_DIR/amber-lsp"

echo "Creating checksummed release archive..."
cp "$BUILD_DIR/amber" "$BUILD_DIR/amber-lsp" "$PACKAGE_ROOT/"
cp src/amber_lsp/cards/crystal.yml "$PACKAGE_ROOT/share/amber_cli/api/crystal.yml"
(
  cd "$PACKAGE_ROOT"
  "${CHECKSUM_CMD[@]}" amber amber-lsp > checksums.txt
)
ARCHIVE="$OUTPUT_DIR/amber_cli-${TARGET}.tar.gz"
tar -czf "$ARCHIVE" -C "$PACKAGE_ROOT" amber amber-lsp checksums.txt share

VERIFY_DIR="$OUTPUT_DIR/verify"
mkdir -p "$VERIFY_DIR"
tar -xzf "$ARCHIVE" -C "$VERIFY_DIR"
(
  cd "$VERIFY_DIR"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum --check checksums.txt
  else
    shasum -a 256 -c checksums.txt
  fi
)
tar -tzf "$ARCHIVE" | grep -Fx "share/amber_cli/api/crystal.yml"

SOURCE_ARCHIVE="$OUTPUT_DIR/amber_cli-source-${VERSION}.tar.gz"
git archive --format=tar.gz --prefix="amber_cli-${VERSION}/" HEAD > "$SOURCE_ARCHIVE"

(
  cd "$OUTPUT_DIR"
  "${CHECKSUM_CMD[@]}" "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256"
  "${CHECKSUM_CMD[@]}" "$(basename "$SOURCE_ARCHIVE")" > "$(basename "$SOURCE_ARCHIVE").sha256"
)

echo
echo "Build complete"
echo "Output: $OUTPUT_DIR"
echo "Commit: $(git rev-parse HEAD)"
echo "Archive SHA-256: $(awk '{print $1}' "$ARCHIVE.sha256")"
echo "Source SHA-256: $(awk '{print $1}' "$SOURCE_ARCHIVE.sha256")"
echo "Checksums:"
cat "$PACKAGE_ROOT/checksums.txt"
echo "Archive listing:"
tar -tzf "$ARCHIVE"
