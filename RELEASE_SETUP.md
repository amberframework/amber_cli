# Release Process

This guide documents the current Amber CLI release path and the checks we expect before updating any public install instructions.

## What "Done" Looks Like

A successful release means all of the following happen without manual file editing:

1. A published GitHub release in `amberframework/amber_cli` builds macOS and Linux binaries.
2. The workflow uploads release archives and checksum files to that release.
3. The workflow dispatches `amberframework/homebrew-amber_cli`.
4. The tap rewrites `Formula/amber_cli.rb` with the new version and checksums.
5. The tap explicitly dispatches its install validation after the bot pushes the
   formula. This is required because pushes made by `GITHUB_TOKEN` do not start
   push-triggered workflows.
6. On Apple Silicon macOS and x86_64 Linux, that validation proves a clean
   machine can:
   - `brew install amberframework/amber_cli/amber_cli`
   - `brew test amber_cli`
   - create the ECR web template with `amber new smoke_app --type web`
   - install shards, run specs, and build the generated app
   - launch the built app and request `/` plus `/css/app.css`

The fully qualified Homebrew command trusts only the `amber_cli` formula under
Homebrew's third-party tap trust model. Do not replace it with a separate
`brew tap` step in public installation instructions.

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
./scripts/build_release.sh X.Y.Z
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
git tag vX.Y.Z
git push origin vX.Y.Z
gh release create vX.Y.Z --repo amberframework/amber_cli --generate-notes
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
brew install amberframework/amber_cli/amber_cli
brew test amber_cli
amber new smoke_app --type web -y --no-deps
cd smoke_app
shards install
crystal spec
crystal build src/smoke_app.cr -o bin/smoke_app
```

It then starts the built application and probes the homepage and generated CSS.
The macOS job also rejects binaries linked to `openssl@1.1`.

## Manual Recovery

If the tap update fails after a release:

1. Download the release assets and checksum files from GitHub.
2. Update `Formula/amber_cli.rb` in `amberframework/homebrew-amber_cli`.
3. Commit and push to `main`.
4. Explicitly dispatch `.github/workflows/validate-install.yml`; a bot-token
   push alone will not trigger it.

If the release build fails before the tap update:

1. fix the workflow on a branch
2. re-run the dry-run build with `workflow_dispatch`
3. cut a new tag or recreate the release once the build is green

## Current Packaging Direction

The Homebrew tap and matching release archives are the supported install paths
for Apple Silicon macOS and x86_64 Linux today. Other operating systems and
architectures remain preview or contributor build-from-source targets until
they have published artifacts and the same end-to-end release gates.

For eventual `homebrew/core` inclusion, we should plan for a source-building formula and a clean `brew audit --new --formula amber_cli` story. The current tap keeps release onboarding fast, while the source-build path is the more likely route for upstream Homebrew acceptance.
