#!/usr/bin/env bash
# Repackage a release archive (amber + amber-lsp, static) as a .deb.
# Usage: build_deb.sh <version> <deb-arch: amd64|arm64> <archive.tar.gz> <expected-sha256> <out-dir>
# Needs only dpkg-deb, tar, sha256sum. Fails closed on any hash mismatch.
set -euo pipefail

version="$1"; deb_arch="$2"; archive="$3"; expected_sha="$4"; out_dir="$5"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$deb_arch" in amd64|arm64) ;; *) echo "unsupported arch: $deb_arch" >&2; exit 1 ;; esac
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.+~-][0-9A-Za-z.]+)?$ ]] || { echo "bad version: $version" >&2; exit 1; }

actual_sha="$(sha256sum "$archive" | cut -d' ' -f1)"
if [ "$actual_sha" != "$expected_sha" ]; then
  echo "sha256 mismatch for $archive: expected $expected_sha, got $actual_sha" >&2
  exit 1
fi

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
root="$work/pkg"
mkdir -p "$root/usr/bin" "$root/DEBIAN" "$root/usr/share/doc/amber-cli"
tar -xzf "$archive" -C "$work" amber amber-lsp
install -m 0755 "$work/amber" "$work/amber-lsp" "$root/usr/bin/"
install -m 0644 "$repo_root/packaging/deb/copyright" "$root/usr/share/doc/amber-cli/copyright"

installed_kb="$(du -sk "$root/usr" | cut -f1)"
cat > "$root/DEBIAN/control" <<CONTROL
Package: amber-cli
Version: ${version}
Section: devel
Priority: optional
Architecture: ${deb_arch}
Installed-Size: ${installed_kb}
Maintainer: Amber Framework <crimsonknightstudios@gmail.com>
Homepage: https://github.com/amberframework/amber_cli
Recommends: crystal-alpha | crystal
Description: Amber V2 command-line tool and language server
 The amber command generates, builds, and runs Amber V2 web applications.
 The amber-lsp command is the Amber language server.
 .
 Both programs are statically linked release binaries. A Crystal compiler
 (crystal-alpha or crystal, 1.20 or newer but earlier than 2.0) is needed
 to build the applications amber generates.
CONTROL

mkdir -p "$out_dir"
dpkg-deb --root-owner-group --build "$root" "$out_dir/amber-cli_${version}_${deb_arch}.deb" >/dev/null
echo "built $out_dir/amber-cli_${version}_${deb_arch}.deb"
