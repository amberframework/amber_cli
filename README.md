# Amber CLI

[![GitHub release](https://img.shields.io/github/release/amberframework/amber_cli.svg)](https://github.com/amberframework/amber_cli/releases)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://amberframework.github.io/amber_cli/)

Amber CLI is the standalone command-line companion for Amber V2. CLI `2.0.7`
creates the supported Amber `2.0.0-beta.5` ECR web application and includes
development, generator, database, and LSP tooling. Its agent tooling also
works in plain Crystal apps and shards; see
[Agent tooling](#agent-tooling-for-any-crystal-project).

Amber V2 is a beta. The release-gated path is a web application on Apple
Silicon macOS, x86_64 Linux, or ARM64 Linux. Windows x86-64 passes the complete
generated-app smoke in CI, but has no release archive yet. See
[Generator support](docs/GENERATOR_SUPPORT.md) before relying
on authentication, API-resource, or native output.

## Install

Prerequisites: Homebrew 7 or newer and Git. The formula installs Crystal,
Minecart, and the native libraries used by the default web app.

### Homebrew on macOS or Linux

Run `brew trust --tap amberframework/amber_cli`, then follow the
[installation guide](https://amberframework.org/docs/v2/getting-started/installation/)
to fetch and pin the reviewed tap commit. With that commit checked out, run:

```bash
HOMEBREW_NO_AUTO_UPDATE=1 brew install amberframework/amber_cli/amber_cli
amber --version
minecart --version
```

The single install command brings `amber`, `amber-lsp`, Minecart, Crystal, and
SQLite/OpenSSL/PostgreSQL/MySQL client libraries. The tap commit fixes formula
content and source-archive SHA-256 values. Homebrew-core dependency versions
are selected by the installed core catalog, not pinned by this tap.

### Direct release archive

The CLI `2.0.7` release has `darwin-arm64`, `linux-x86_64`, and
`linux-arm64` binary archives. A direct archive does not install Minecart or
the native dependencies, so Homebrew is the beginner path. Windows x86-64 has
no release archive.

```bash
version=v2.0.7
platform=darwin-arm64
asset="amber_cli-${platform}.tar.gz"

curl -fLO "https://github.com/amberframework/amber_cli/releases/download/${version}/${asset}"
curl -fLO "https://github.com/amberframework/amber_cli/releases/download/${version}/${asset}.sha256"
shasum -a 256 -c "${asset}.sha256"
tar -xzf "${asset}"
install -m 0755 amber amber-lsp /usr/local/bin/
install -d -m 0755 /usr/local/share/amber_cli/api
install -m 0644 share/amber_cli/api/crystal.yml /usr/local/share/amber_cli/api/
amber --version
```

On Linux, use `sha256sum -c` for the checksum. Prefix the `install` commands
with `sudo` if `/usr/local` is not writable.

## Create and verify a web app

```bash
amber new my_app --type web -y
cd my_app
minecart install --frozen --skip-ai-docs
amber assets check
crystal spec
crystal build src/my_app.cr -o bin/my_app
amber watch
```

`amber new` runs Minecart by default. It writes exact root dependency pins,
a `shard.lock` with Git tree checksums, `.minecart-policy.yml`, and `.claude/`
assistant files, then installs the Claude Code and Codex hooks and prints an
`amber doctor` summary. Commit the generated files. With `--no-deps`, the first
Minecart install and assistant setup are deliberately deferred; run `minecart
install --strict-pinning --skip-ai-docs` and `minecart assistant init
--skip-ai-docs` before frozen installs. Pass `--skip-agent-setup` to generate
the app without the agent files.
`amber watch` recompiles assets before the application whenever an ECR template
or a file under `app/assets/` changes. Open <http://127.0.0.1:3000>.

The web template is deliberately small:

- Amber from `amberframework/amber`, pinned to `2.0.0-beta.5`
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
AMBER_ENV=test amber database migrate
crystal spec
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
| `amber setup:lsp` | Available | Register only the project-local Claude `amber-lsp` plugin |
| `amber setup:agent` (`amber agent`) | Available | Set up Claude Code and Codex in any Crystal project |
| `amber doctor` | Available | Check LSP readiness, hook trust, ignore rules, and API lookup status |

Run `amber --help` or `amber COMMAND --help` for command syntax. The detailed
[web-app walkthrough](docs/BETA_WEB_APP.md) and
[generator table](docs/GENERATOR_SUPPORT.md) define what is release-gated.

## Update and troubleshoot

```bash
HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade amberframework/amber_cli/amber_cli
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

## Agent tooling for any Crystal project

`amber-lsp` and `amber setup:agent` help Claude Code and Codex write Crystal
that compiles the first time. They work in Amber V2 apps, plain Crystal apps,
and Crystal shards. From the project root:

```bash
amber setup:agent   # install Claude Code and Codex hooks and the amber-lsp plugin
amber doctor        # confirm the setup, binary checksum, and agent trust
```

The agent then looks up each library method before calling it:

```bash
amber-lsp lookup 'Dir.mkdir_p'      # class method
amber-lsp lookup 'String#split'     # instance method
crystal build src/my_app.cr 2>&1 | amber-lsp hint
```

Lookup answers from the project's own code, every shard in `lib/`, and the
Crystal standard library. In Amber V2 apps, edits are also checked against the
Amber rules. `amber new` runs `setup:agent` automatically; run it again after
upgrading. Commit the generated `.amber/`, `.claude/settings.json`, and
`.codex/hooks.json` so clones and worktrees share the setup.

The [agent tooling guide](docs/guides/ai-assistants.md) covers trust prompts,
what each hook does, every `amber-lsp` command, API cards for library authors,
and troubleshooting.

## Contributing

```bash
minecart install --frozen --skip-ai-docs
crystal-alpha tool format --check src spec
crystal-alpha spec
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the project workflow.
