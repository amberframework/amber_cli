# Amber CLI

[![GitHub release](https://img.shields.io/github/release/amberframework/amber_cli.svg)](https://github.com/amberframework/amber_cli/releases)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://amberframework.github.io/amber_cli/)

Amber CLI is the standalone command-line companion for Amber V2. CLI `2.0.3`
creates the supported Amber `2.0.0-beta.2` ECR web application and includes
development, generator, database, and LSP tooling.

Amber V2 is a beta. The release-gated path is a web application on Apple
Silicon macOS or x86_64 Linux. See [Generator support](docs/GENERATOR_SUPPORT.md)
before relying on persistence, authentication, API-resource, or native output.

## Install

Prerequisites: Crystal 1.20 or newer (but earlier than 2.0), `shards`, and Git.

### Homebrew on macOS or Linux

The tap and formula names contain underscores; the installed executable is
`amber`:

```bash
brew install amberframework/amber_cli/amber_cli
amber --version
```

The fully qualified command follows Homebrew's tap-trust model and trusts only
the `amber_cli` formula.

### Direct release archive

Use `darwin-arm64` on Apple Silicon macOS or `linux-x86_64` on x86_64 Linux:

```bash
version=v2.0.3
platform=darwin-arm64
asset="amber_cli-${platform}.tar.gz"

curl -fLO "https://github.com/amberframework/amber_cli/releases/download/${version}/${asset}"
curl -fLO "https://github.com/amberframework/amber_cli/releases/download/${version}/${asset}.sha256"
shasum -a 256 -c "${asset}.sha256"
tar -xzf "${asset}"
install -m 0755 amber amber-lsp /usr/local/bin/
amber --version
```

On Linux, use `sha256sum -c` for the checksum. Prefix only the `install`
command with `sudo` if `/usr/local/bin` is not writable.

## Create and verify a web app

```bash
amber new my_app --type web
cd my_app
crystal spec
crystal build src/my_app.cr -o bin/my_app
amber watch
```

`amber new` installs shards by default; pass `--no-deps` when an offline or CI
workflow needs to run `shards install` later. Open <http://127.0.0.1:3000> and
<http://127.0.0.1:3000/css/app.css>.

The web template is deliberately small:

- Amber from `amberframework/amber`, pinned to `2.0.0-beta.2`
- ECR views (Slang and Kilt are not supported in Amber V2)
- typed development, test, and production YAML
- branded homepage, controller spec, and static CSS/JavaScript
- a browser-native import map with a local JavaScript module entry point
- no ORM or database driver by default

The `-d pg|mysql|sqlite` option records metadata and suggested URLs for future
persistence tooling. It does not add an ORM or driver to the core web app.

## Commands

| Command | Status | Purpose |
|---|---|---|
| `amber new APP --type web` | Supported | Create the beta web application |
| `amber watch` | Supported | Rebuild and restart during development |
| `amber routes` | Supported | Inspect application routes |
| `amber pipelines` | Supported | Inspect configured pipelines |
| `amber generate` | Mixed | Core generators supported; dependency-backed generators preview |
| `amber database` | Preview for new apps | Requires an explicitly configured persistence stack |
| `amber new APP --type native` | Preview | Not part of the beta platform guarantee |
| `amber setup:lsp` | Available | Configure the bundled diagnostics LSP |

Run `amber --help` or `amber COMMAND --help` for command syntax. The detailed
[web-app walkthrough](docs/BETA_WEB_APP.md) and
[generator table](docs/GENERATOR_SUPPORT.md) define what is release-gated.

## Update and troubleshoot

```bash
brew update
brew upgrade amber_cli
type -a amber
amber --version
```

If an older Amber V1 executable appears first, remove or rename it or put the
new installation directory earlier in `PATH`. On macOS, include
`otool -L "$(command -v amber)"` in install bug reports; release binaries must
not require the retired `openssl@1.1` library.

Report CLI, template, or binary problems at
<https://github.com/amberframework/amber_cli/issues>. Include OS/architecture,
`crystal --version`, `amber --version`, install method, command, and complete
output.

## LSP

The release archive includes `amber-lsp`. From an Amber project:

```bash
amber setup:lsp
```

See the [LSP setup guide](https://github.com/amberframework/amber/blob/v2.0.0-beta.2/docs/guides/lsp-setup.md).

## Contributing

```bash
shards install
crystal tool format --check src spec
crystal spec
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the project workflow.
