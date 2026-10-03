# Arch Linux and Omarchy packaging

`amber-cli-bin/` is an AUR-style `PKGBUILD` that installs the prebuilt static
`amber` and `amber-lsp` binaries from a GitHub release (`x86_64` and
`aarch64`). Omarchy is Arch-based, so the same package works there.

## Install from a local checkout

```bash
cd packaging/arch/amber-cli-bin
makepkg -si        # run as a normal user, not root
amber --version
```

Once published to the AUR: `yay -S amber-cli-bin`.

## Every pin lives in the PKGBUILD

Each source has a `sha256sums` entry. `makepkg` fails closed on a mismatch;
never run it with `--skipchecksums` or `SKIPINTEGRITY`.

## Bump to a new release

1. Set `pkgver` (and reset `pkgrel=1`) in `PKGBUILD`.
2. Download each release archive and the tagged `LICENSE`, hash them with
   `sha256sum`, and compare the archive hashes with the release's published
   `.sha256` files. Put the hashes in `sha256sums`, `sha256sums_x86_64`, and
   `sha256sums_aarch64`.
3. Update `packaging/pinned_release.env` to the same version and hashes.
4. Regenerate `.SRCINFO`: `makepkg --printsrcinfo > .SRCINFO`.
5. Test in a clean Arch container as a non-root user (CI does this on every
   pull request that touches `packaging/`).

## First AUR submission (maintainer only, manual)

1. Create an AUR account and add your SSH public key to it.
2. `git clone ssh://aur@aur.archlinux.org/amber-cli-bin.git`
3. Copy `PKGBUILD` and `.SRCINFO` into the clone.
4. `git add PKGBUILD .SRCINFO && git commit -m "Initial import: amber-cli-bin 2.0.6"`
5. `git push` (the AUR accepts the `master` branch).

For later releases, repeat steps 3 to 5 with the bumped files. Nothing in this
repository publishes to the AUR automatically.

## Not provided

A source-build `amber-cli` PKGBUILD is intentionally absent. A reproducible
source build needs the Crystal toolchain plus `shards install --frozen` with
hash-verified shards, and the release job already produces the static binaries
the `-bin` package repackages.
