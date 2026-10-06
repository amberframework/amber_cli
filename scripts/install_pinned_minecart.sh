#!/usr/bin/env bash
set -euo pipefail

# The source commit is verified by its Git tree before it can run the web smoke.
minecart_commit=091e8e2da15a0a4885a40b174d5a561da0201c1b
minecart_tree=2d00f70352d6ff70b29b1037bc85a316a6a13117
minecart_repository="${MINECART_SOURCE_REPOSITORY:-https://github.com/crimson-knight/shards.git}"
minecart_source_ref="${MINECART_SOURCE_REF:-refs/tags/v2025.11.25.7}"
install_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/amber-pinned-minecart"

mkdir -p "$install_root"
git -C "$install_root" init -q
if git -C "$install_root" remote get-url origin >/dev/null 2>&1; then
  git -C "$install_root" remote set-url origin "$minecart_repository"
else
  git -C "$install_root" remote add origin "$minecart_repository"
fi
git -C "$install_root" fetch --depth=1 origin "$minecart_source_ref"
git -C "$install_root" checkout -q --detach FETCH_HEAD
test "$(git -C "$install_root" rev-parse HEAD)" = "$minecart_commit"
test "$(git -C "$install_root" rev-parse 'HEAD^{tree}')" = "$minecart_tree"

make -C "$install_root" bin/minecart bin/shards-alpha CRYSTAL="${CRYSTAL:-crystal-alpha}"
test -x "$install_root/bin/minecart"
test -x "$install_root/bin/shards-alpha"
"$install_root/bin/minecart" --version | grep -F "Minecart 2025.11.25.7"
"$install_root/bin/shards-alpha" --version | grep -F "Minecart 2025.11.25.7"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$install_root/bin" >> "$GITHUB_PATH"
else
  echo "Add $install_root/bin to PATH before running the web smoke."
fi
