#!/usr/bin/env bash
set -euo pipefail

# The source commit is verified by its Git tree before it can run the web smoke.
minecart_commit=4fea47ce6561ea0612cf1e0cf6955d782ef27929
minecart_tree=e0a0214c14d71f1031d83b760d426b09509b5d9d
install_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/amber-pinned-minecart"

mkdir -p "$install_root"
git -C "$install_root" init -q
git -C "$install_root" remote add origin https://github.com/crimson-knight/shards.git
git -C "$install_root" fetch --depth=1 origin "$minecart_commit"
git -C "$install_root" checkout -q --detach FETCH_HEAD
test "$(git -C "$install_root" rev-parse HEAD)" = "$minecart_commit"
test "$(git -C "$install_root" rev-parse 'HEAD^{tree}')" = "$minecart_tree"

make -C "$install_root" bin/minecart CRYSTAL="${CRYSTAL:-crystal}"
test -x "$install_root/bin/minecart"
"$install_root/bin/minecart" --version | grep -F "Minecart 2025.11.25.7"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$install_root/bin" >> "$GITHUB_PATH"
else
  echo "Add $install_root/bin to PATH before running the web smoke."
fi
