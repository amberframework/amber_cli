#!/usr/bin/env bash
set -euo pipefail

crystal_version="1.21.1"
target="${1:-${TARGET:-}}"
install_root="${CRYSTAL_INSTALL_ROOT:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/amber-crystal-${crystal_version}-${target}}"

case "$target" in
  darwin-arm64)
    archive="crystal-1.21.1-1-darwin-universal.tar.gz"
    sha256="ba34fa7fb8bc8b951f12d17e12f69c9d7ccce38900caa4b8a17f1b4f29d37605"
    ;;
  linux-x86_64)
    archive="crystal-1.21.1-1-linux-x86_64.tar.gz"
    sha256="08b5779df8cf280c4a799599862bbe4d42103ba082aa73429562713c8a9f3b43"
    ;;
  linux-arm64)
    archive="crystal-1.21.1-1-linux-aarch64.tar.gz"
    sha256="a37365b79f58d4cd32b6113bbb9983e21eb41d233667e003c019520e3c245e49"
    ;;
  *)
    printf 'Unsupported Crystal release target: %s\n' "$target" >&2
    exit 2
    ;;
esac

mkdir -p "$install_root"
archive_path="$install_root/$archive"
download_url="https://github.com/crystal-lang/crystal/releases/download/1.21.1/$archive"
curl --fail --location --silent --show-error --retry 3 --output "$archive_path" "$download_url"

if command -v sha256sum >/dev/null 2>&1; then
  printf '%s  %s\n' "$sha256" "$archive_path" | sha256sum --check --status -
else
  printf '%s  %s\n' "$sha256" "$archive_path" | shasum --algorithm 256 --check --status -
fi

tar -xzf "$archive_path" -C "$install_root"
compiler_path="$(find "$install_root" -path '*/bin/crystal' -print -quit)"
if [[ -z "$compiler_path" ]]; then
  printf 'Crystal %s archive did not contain bin/crystal\n' "$crystal_version" >&2
  exit 1
fi

bin_directory="$(dirname "$compiler_path")"
ln -sfn crystal "$bin_directory/crystal-alpha"
version_output="$("$bin_directory/crystal-alpha" --version)"
if [[ "$version_output" != *"Crystal ${crystal_version} "* ]]; then
  printf 'Unexpected compiler version in verified archive: %s\n' "$version_output" >&2
  exit 1
fi

printf 'Verified Crystal %s archive for %s: %s\n' "$crystal_version" "$target" "$sha256"
printf '%s\n' "$version_output"
if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "$bin_directory" >> "$GITHUB_PATH"
else
  printf 'Add this directory to PATH before building: %s\n' "$bin_directory"
fi
