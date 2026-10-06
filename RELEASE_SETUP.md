# Release Process

This guide documents the current Amber CLI release path and the checks we expect before updating any public install instructions.

## What "Done" Looks Like

A successful release means all of the following have been reviewed and run:

1. A published GitHub release in `amberframework/amber_cli` builds macOS and Linux binaries.
2. The workflow uploads binary archives and checksum files. It packages a
   source archive from the tagged commit and uploads its SHA-256 for Homebrew.
3. The reviewed tap commit contains the Amber and Minecart source archive URLs
   and SHA-256 values. It is pushed only after both archives are available.
4. Tap install validation passes on supported Homebrew platforms.
5. On Apple Silicon macOS, x86_64 Linux, and ARM64 Linux, validation proves a clean
   machine can:
   - `brew install amberframework/amber_cli/amber_cli`
   - `brew test amber_cli`
   - create the ECR web template with `amber new smoke_app --type web`
   - use Minecart to write and verify the app lock, build and verify assets, run
     specs, and build the generated app
   - launch the built app and request `/` plus its manifest-rendered
     fingerprinted CSS, JavaScript, image, and favicon URLs

The assistant runs `brew trust --tap amberframework/amber_cli`, fetches the
tap, checks out the reviewed full commit, and disables Homebrew auto-update
for the single `brew install` command. Trust covers the tap; the commit fixes
the formula content. Homebrew-core dependencies still follow the local core
catalog rather than exact versions pinned by this tap.

If any one of those steps is red, the release is not ready to announce.

## PR Expectations For Release Work

Every PR that changes installation, packaging, generated scaffolds, or release automation should document:

- why the change is needed now
- whether it affects the release or install path
- what verification proves it works
- which ADR or SOP entry explains the longer-lived decision

Use the repository PR template for this so release context stays attached to the code review itself.

## Repositories and Workflows

- `amberframework/amber_cli`
  - [`.github/workflows/release.yml`](.github/workflows/release.yml)
  - [`scripts/build_release.sh`](scripts/build_release.sh)
- `amberframework/homebrew-amber_cli`
  - `Formula/amber_cli.rb` and `Formula/minecart.rb`
  - `.github/workflows/validate-install.yml`

## Required Secrets

No cross-repository token is needed. Formula updates are reviewed and committed
with the exact source archive SHA-256 values after the release assets exist.

## Release Flow

### 1. Update the version

Update `shard.yml` to the release version you want to publish.

### 2. Run the local release build

From the CLI repo:

```bash
./scripts/build_release.sh X.Y.Z
```

That should produce:

- `dist/amber_cli-darwin-arm64.tar.gz`,
  `dist/amber_cli-linux-x86_64.tar.gz`, or
  `dist/amber_cli-linux-arm64.tar.gz`
- matching `.sha256` output

### 3. Dry-run the GitHub build matrix

Before publishing a release, test the exact workflow on the branch you plan to tag:

```bash
gh workflow run release.yml \
  --repo amberframework/amber_cli \
  --ref <branch> \
  -f ref=<branch>
```

This exercises the same build matrix as the release workflow without uploading assets or touching the tap.

### 4. Publish the release

After the dry-run is green:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
gh release create vX.Y.Z --repo amberframework/amber_cli --generate-notes
```

Publishing the release triggers the automated flow:

1. build macOS and Linux binaries
2. upload archives and checksums to the release
3. package the tagged source and publish its archive and checksum

Before pushing the tap commit, download the published
`amber_cli-source-2.0.7.tar.gz` archive, verify its sidecar checksum, and compare
its SHA-256 with `Formula/amber_cli.rb`. The CI-generated gzip archive can
have different bytes from a local archive of the same commit, so update the
formula to the published asset hash when they differ. Then run the tap smoke
on macOS and Linux.

## CI Gates To Check

### Release build

In `amberframework/amber_cli`, the release workflow must be green for:

- `Build darwin-arm64`
- `Build linux-x86_64`
- `Build linux-arm64`
- `Upload Release Assets`

### Tap install smoke

In `amberframework/homebrew-amber_cli`, the install smoke workflow must be green for:

- `Install Smoke Test (macos-latest)`
- `Install Smoke Test (ubuntu-latest)`

That workflow explicitly runs:

```bash
brew trust --tap amberframework/amber_cli
HOMEBREW_NO_AUTO_UPDATE=1 brew install amberframework/amber_cli/amber_cli
brew test amber_cli
amber new smoke_app --type web -y
cd smoke_app
minecart install --frozen
amber assets build
amber assets check
crystal spec
crystal build src/smoke_app.cr -o bin/smoke_app
```

It then starts the built application and probes the homepage plus the
manifest-rendered CSS, JavaScript, image, and favicon URLs. It verifies asset
MIME types, immutable cache headers, SRI, and gzip negotiation. The macOS job
also rejects binaries linked to `openssl@1.1`.

## Manual Recovery

If the tap update fails after a release:

1. Download the release assets and checksum files from GitHub.
2. Compare the source asset hash with `Formula/amber_cli.rb` and the Minecart
   source asset hash with `Formula/minecart.rb`.
3. Fix any mismatch in the review branch; never skip verification.
4. Push the reviewed tap commit only after validation passes.

If the release build fails before the tap update:

1. fix the workflow on a branch
2. re-run the dry-run build with `workflow_dispatch`
3. cut a new tag or recreate the release once the build is green

## Current Packaging Direction

The Homebrew tap is the one-install beginner path after trust and tap pinning.
Windows x86-64 passes the generated-app CI gate but has no release archive.

The tap builds both Minecart and Amber CLI from hash-checked source archives.
For eventual `homebrew/core` inclusion, validate the formula against core's
additional audit rules.
