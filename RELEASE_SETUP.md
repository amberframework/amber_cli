# Release Automation Setup

This guide explains how to set up automated binary building and Homebrew formula updates for Amber CLI.

## Overview

The release process consists of:

1. **GitHub Actions** builds cross-platform binaries when you publish a release
2. **Release assets** are automatically uploaded (tar.gz files + checksums)
3. **Homebrew tap** is automatically notified to update the formula
4. **Users** can install via `brew install crimsonknight/amber-cli/amber-cli`

## Setup Steps

### 1. GitHub Repository Secrets

You need to set up a GitHub token for the Homebrew tap automation:

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Create a new **Classic token** with these permissions:
   - `repo` (Full control of private repositories)
   - `workflow` (Update GitHub Action workflows)
3. Copy the token
4. In your `amber_cli` repository, go to Settings → Secrets and variables → Actions
5. Add a new repository secret:
   - **Name**: `HOMEBREW_TAP_TOKEN`
   - **Value**: Your personal access token

### 2. Homebrew Tap Repository

Create a new repository called `homebrew-amber-cli` with this structure:

```
homebrew-amber-cli/
├── Formula/
│   └── amber-cli.rb          # Homebrew formula
├── .github/
│   └── workflows/
│       └── update-formula.yml # Auto-update workflow
└── README.md                 # Installation instructions
```

**Files to create**: (Get the content from the previous assistance where I created these files)

### 3. Test Local Build

Before creating a release, test the build process locally:

```bash
# Test local build
./scripts/build_release.sh v0.1.0

# This should create:
# - dist/amber-cli-{platform}.tar.gz
# - dist/amber-cli-{platform}.tar.gz.sha256
```

### 4. Test GitHub Actions

Push your changes and test the build workflow:

```bash
git add .
git commit -m "Add release automation"
git push origin main
```

This should trigger the build workflow and test compilation on multiple platforms.

## Creating a Release

### 1. Version Management

Update the version in `shard.yml`:

```yaml
name: amber_cli
version: 1.0.0  # Update this
```

### 2. Create Release

1. Go to your GitHub repository
2. Click "Releases" → "Create a new release"
3. Create a new tag (e.g., `v1.0.0`)
4. Fill in the release title and description
5. Click "Publish release"

### 3. Automatic Process

When you publish the release:

1. **Build workflow** triggers automatically
2. **Binaries** are compiled for:
   - `darwin-arm64` (macOS Apple Silicon)
   - `linux-x86_64` (Linux)
3. **Assets** are uploaded to the release:
   - `amber-cli-darwin-arm64.tar.gz`
   - `amber-cli-linux-x86_64.tar.gz`
   - `.sha256` checksum files for each
4. **Homebrew tap** is notified to update the formula

## Supported Platforms

The automated builds create binaries for:

- **macOS**: Apple Silicon (M-series chips) - ARM64 architecture
- **Linux**: x86_64 architecture

**Note for Intel Mac users**: The ARM64 macOS binary will run via Rosetta 2, or you can build from source if needed.

## Manual Formula Update

If automatic updates don't work, you can manually update the Homebrew formula:

1. Download the release assets
2. Calculate SHA256 checksums: `sha256sum amber-cli-*.tar.gz`
3. Update `Formula/amber-cli.rb` with new version and checksums
4. Commit and push to the homebrew tap repository

## Testing Installation

After releasing, test the Homebrew installation:

```bash
# Add the tap
brew tap crimsonknight/amber-cli

# Install amber-cli
brew install amber-cli

# Test it works
amber --help
```

## Troubleshooting

### Build Failures

- Check the GitHub Actions logs
- Test locally with `./scripts/build_release.sh`
- Ensure all dependencies are properly specified in `shard.yml`

### Cross-compilation Issues

- macOS ARM64 cross-compilation might need adjustments
- Consider using native runners for each platform if cross-compilation fails

### Homebrew Formula Issues

- Verify SHA256 checksums match the uploaded assets
- Check that download URLs are correct
- Test formula locally: `brew install --build-from-source ./Formula/amber-cli.rb`

### Missing Dependencies

If builds fail due to missing system dependencies, update the workflows to install them:

```yaml
- name: Install system dependencies (Linux)
  if: matrix.os == 'ubuntu-latest'
  run: |
    sudo apt-get update
    sudo apt-get install -y build-essential libssl-dev
```

## Files Created

This setup created the following files:

- `.github/workflows/release.yml` - Main release workflow
- `.github/workflows/build.yml` - Build testing workflow  
- `scripts/build_release.sh` - Local build script
- `RELEASE_SETUP.md` - This setup guide

## Next Steps

1. Set up the GitHub token secret
2. Create the Homebrew tap repository
3. Test a local build
4. Create your first release
5. Verify the Homebrew installation works

Once this is working, your release process will be fully automated! 