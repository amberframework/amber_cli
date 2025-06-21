# GitHub Actions CI/CD Setup

This directory contains the GitHub Actions workflows for the Amber CLI project, providing comprehensive continuous integration and deployment across all major operating systems.

## Workflows

### 1. CI Workflow (`.github/workflows/ci.yml`)

**Triggers:** Push to main/master branches, Pull Requests

**Purpose:** Ensures code quality and compatibility across platforms

**Jobs:**
- **test**: Runs on Ubuntu, macOS, and Windows
  - Installs Crystal using platform-specific methods
  - Caches shard dependencies for faster builds
  - Checks code formatting with `crystal tool format`
  - Runs Ameba linter (with soft failure)
  - Compiles the project to ensure no build errors
  - Runs the full test suite with `crystal spec`
  - Builds a release binary (Linux only)

- **platform-specific**: Additional platform-specific testing
  - Tests CLI functionality by running `--help` and `--version`
  - Ensures the compiled binary works on each platform

- **integration**: Runs integration tests if they exist
  - Currently checks for and runs tests in `spec/integration/`

### 2. Release Workflow (`.github/workflows/release.yml`)

**Triggers:** Push to version tags (`v*`), Manual dispatch

**Purpose:** Builds and publishes release binaries for all platforms

**Features:**
- Builds static binaries for Linux (fully portable)
- Builds optimized binaries for macOS and Windows
- Automatically creates GitHub releases with binaries attached
- Generates release notes automatically

### 3. Dependabot Configuration (`.github/dependabot.yml`)

**Purpose:** Keeps GitHub Actions dependencies up to date

**Features:**
- Weekly updates for GitHub Actions
- Ready for Crystal shards support when available

## Platform-Specific Notes

### Linux (Ubuntu Latest)
- Uses the official Crystal installer script
- Builds static binaries for maximum portability
- Includes build-essential for static compilation

### macOS (macOS Latest)
- Installs Crystal via Homebrew
- Builds standard dynamic binaries

### Windows (Windows Latest)
- Installs Crystal via Chocolatey
- Uses PowerShell for Windows-specific commands
- Some CLI tests use `continue-on-error` due to potential Windows-specific issues

## Caching Strategy

The workflows use GitHub Actions caching to speed up builds:
- **Shard cache**: Caches `~/.cache/shards` and `./lib` based on `shard.lock` hash
- **OS-specific**: Separate caches for each operating system

## Usage

### For Contributors
1. The CI workflow runs automatically on every push and pull request
2. All tests must pass on all platforms before merging
3. Code formatting and linting issues are reported but don't fail the build

### For Releases
1. Create a git tag with version format: `git tag v1.0.0`
2. Push the tag: `git push origin v1.0.0`
3. The release workflow automatically builds binaries for all platforms
4. A GitHub release is created with the binaries attached

### Manual Testing
You can trigger the release workflow manually from the GitHub Actions tab for testing purposes.

## Troubleshooting

### Common Issues
1. **Crystal installation fails**: Usually due to temporary network issues or package manager problems
2. **Shard installation fails**: Often due to missing system dependencies
3. **Windows-specific failures**: Crystal on Windows can be less stable; some tests use `continue-on-error`

### Debugging
- Check the Actions tab in your GitHub repository for detailed logs
- Each step shows its output and any error messages
- Failed workflows will show which specific step failed

## Adding New Tests

To add new tests that run in CI:
1. Add test files to the `spec/` directory
2. Integration tests go in `spec/integration/`
3. The workflows will automatically pick up and run new tests

## Future Improvements

1. **Code coverage reporting**: Add a code coverage tool
2. **Performance benchmarks**: Track performance across releases
3. **Docker builds**: Add containerized builds for additional consistency
4. **Cross-compilation**: Explore Crystal's cross-compilation features
5. **Shard dependency updates**: When Dependabot supports Crystal, enable automatic dependency updates 