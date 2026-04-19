# Release Process

This guide documents the current Amber CLI release path and the checks we expect before updating any public install instructions.

## What "Done" Looks Like

A successful release means all of the following happen without manual file editing:

1. A published GitHub release in `amberframework/amber_cli` builds macOS and Linux binaries.
2. The workflow uploads release archives and checksum files to that release.
3. The workflow dispatches `amberframework/homebrew-amber_cli`.
4. The tap rewrites `Formula/amber_cli.rb` with the new version and checksums.
5. The tap's smoke test proves a clean machine can:
   - `brew tap amberframework/amber_cli`
   - `brew install amber_cli`
   - `brew test amber_cli`
   - `amber new smoke_app -y --no-deps`

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
  - `Formula/amber_cli.rb`
  - `.github/workflows/update-formula.yml`
  - `.github/workflows/validate-install.yml`

## Required Secrets

`amberframework/amber_cli` needs a `HOMEBREW_TAP_TOKEN` secret that can dispatch workflows in `amberframework/homebrew-amber_cli`.

Recommended scopes for a classic PAT:

- `repo`
- `workflow`

## Release Flow

### 1. Update the version

Update `shard.yml` to the release version you want to publish.

### 2. Run the local release build

From the CLI repo:

```bash
./scripts/build_release.sh 2.0.1
```

That should produce:

- `dist/amber_cli-darwin-arm64.tar.gz` or `dist/amber_cli-linux-x86_64.tar.gz`
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
git tag v2.0.1
git push origin v2.0.1
gh release create v2.0.1 --repo amberframework/amber_cli --generate-notes
```

Publishing the release triggers the automated flow:

1. build macOS and Linux binaries
2. upload archives and checksums to the release
3. dispatch the Homebrew tap update
4. run the tap smoke test on macOS and Linux

## CI Gates To Check

### Release build

In `amberframework/amber_cli`, the release workflow must be green for:

- `Build darwin-arm64`
- `Build linux-x86_64`
- `Upload Release Assets`
- `Notify Homebrew Tap`

### Tap update

In `amberframework/homebrew-amber_cli`, the formula update workflow must be green for:

- `Update Formula`

### Tap install smoke

In `amberframework/homebrew-amber_cli`, the install smoke workflow must be green for:

- `Install Smoke Test (macos-latest)`
- `Install Smoke Test (ubuntu-latest)`

That workflow explicitly runs:

```bash
brew tap amberframework/amber_cli
brew install amber_cli
brew test amber_cli
amber new smoke_app -y --no-deps
```

and then verifies the scaffolded app can resolve shards and compile.

## Manual Recovery

If the tap update fails after a release:

1. Download the release assets and checksum files from GitHub.
2. Update `Formula/amber_cli.rb` in `amberframework/homebrew-amber_cli`.
3. Commit and push to `main`.
4. Re-run `.github/workflows/validate-install.yml`.

If the release build fails before the tap update:

1. fix the workflow on a branch
2. re-run the dry-run build with `workflow_dispatch`
3. cut a new tag or recreate the release once the build is green

## Current Packaging Direction

The Homebrew tap is our supported install path today.

For eventual `homebrew/core` inclusion, we should plan for a source-building formula and a clean `brew audit --new --formula amber_cli` story. The current tap keeps release onboarding fast, while the source-build path is the more likely route for upstream Homebrew acceptance.
