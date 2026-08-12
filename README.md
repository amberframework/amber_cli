# Amber CLI

[![GitHub release](https://img.shields.io/github/release/amberframework/amber_cli.svg)](https://github.com/amberframework/amber_cli/releases)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://amberframework.github.io/amber_cli/)

Amber CLI is the standalone command-line companion for Amber V2. CLI `2.0.5`
creates the supported Amber `2.0.0-beta.4` ECR web application and includes
development, generator, database, and LSP tooling.

Amber V2 is a beta. The release-gated path is a web application on Apple
Silicon macOS, x86_64 Linux, or ARM64 Linux. Windows x86-64 generated-app
compilation is checked in CI for compatibility, but Windows does not block this
beta release. See [Generator support](docs/GENERATOR_SUPPORT.md) before relying
on authentication, API-resource, or native output.

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

CLI `2.0.5` publishes `darwin-arm64`, `linux-x86_64`, and `linux-arm64`
archives. Windows x86-64 is compiled in CI but does not yet have a release
archive.

```bash
version=v2.0.5
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
amber assets check
crystal spec
crystal build src/my_app.cr -o bin/my_app
amber watch
```

`amber new` installs shards by default and compiles the starter assets. Pass
`--no-deps` when an offline or CI workflow needs to run `shards install` later.
`amber watch` recompiles assets before the application whenever an ECR template
or a file under `app/assets/` changes. Open <http://127.0.0.1:3000>.

The web template is deliberately small:

- Amber from `amberframework/amber`, pinned to `2.0.0-beta.4`
- ECR views (Slang and Kilt are not supported in Amber V2)
- typed development, test, and production YAML
- branded homepage, controller spec, and fingerprinted CSS, JavaScript, SVG,
  font, image, and general static-file support
- a browser-native import map with a local JavaScript module entry point
- Grant ORM, Micrate-powered migration commands, and the selected database driver
- SQLite by default, so the first persisted feature needs no database server

The `-d pg|mysql|sqlite` option selects the generated driver, connection, and
development/test URLs. SQLite is the default; PostgreSQL and MySQL expect their
respective local servers or a `DATABASE_URL`.

### Static assets: source versus generated output

Write application-owned files in these directories:

```text
app/assets/
├── stylesheets/  # CSS; starter entry: app.css
├── javascript/   # browser modules; starter entry: app.js
├── images/       # SVG, PNG, JPEG, WebP, AVIF, and icons
├── fonts/        # WOFF, WOFF2, TTF, and OTF
└── files/        # PDFs, web manifests, and other downloads
```

Run the compiler after an authored asset changes outside watch mode:

```bash
amber assets build
amber assets check
```

The build fingerprints every file into `public/assets/`, rewrites local CSS and
JavaScript references, writes SRI and response metadata to
`public/assets/manifest.json`, and creates deterministic gzip siblings for
compressible files. `public/assets/` is generated and gitignored; do not edit or
commit it. Keep stable root files such as `public/robots.txt` in `public/`.

In `src/views/layouts/application.ecr`, resolve authored logical names through
`stylesheet_link_tag`, `javascript_importmap_tag`, `image_tag`, and
`favicon_tag`. In CSS, references are relative to that CSS source file; for
example, `app/assets/stylesheets/app.css` uses
`url("../images/amber-crystal.svg")`. The compiler replaces that reference with
the image's fingerprinted URL.

Create the first complete resource and its database table:

```bash
amber generate scaffold Pet name:string:required species:string:required adopted:bool
amber database migrate
amber watch
```

The generator writes the Grant model to `src/models/pet.cr`, the request schema
to `src/schemas/pet_schema.cr`, the controller to
`src/controllers/pet_controller.cr`, ECR views to `src/views/pet/`, a Micrate
SQL migration to `db/migrations/`, and the resource route to `config/routes.cr`.

## Commands

| Command | Status | Purpose |
|---|---|---|
| `amber new APP --type web` | Supported | Create the beta web application |
| `amber watch` | Supported | Rebuild and restart during development |
| `amber routes` | Supported | Inspect application routes |
| `amber pipelines` | Supported | Inspect configured pipelines |
| `amber generate` | Mixed | Model, scaffold, migration, and core generators supported; auth and API preview |
| `amber database` | Supported | Apply, roll back, inspect, redo, and seed the generated database |
| `amber assets build` | Supported | Fingerprint `app/assets/` into generated `public/assets/` output |
| `amber assets check` | Supported | Verify manifest, bytes, integrity, MIME, and compressed output without changing it |
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

See the [LSP setup guide](https://github.com/amberframework/amber/blob/v2.0.0-beta.4/docs/guides/lsp-setup.md).

## Contributing

```bash
shards install
crystal tool format --check src spec
crystal spec
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the project workflow.
