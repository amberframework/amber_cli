# Start here: the Amber V2 toolchain

This page takes a new developer from a bare machine to an Amber V2 app with
checksum-verified dependencies, and with editor and coding-assistant rules active
from the first edit. It covers Amber CLI 2.0.16, Amber 2.0.0-beta.15 and Minecart
2025.11.25.9 on Apple Silicon macOS and Linux.

## What you get

| Tool | What it does | How it arrives |
|---|---|---|
| `amber` | Generates, runs and migrates apps | Homebrew formula |
| `amber-lsp` | Language server, API lookup and rule checks | Same formula |
| `minecart` | Installs dependencies and verifies their checksums | Dependency of the formula |
| Crystal | Compiles the app | Dependency of the formula |
| Amber 2.0.0-beta.15 | The framework, its rule pack and its guides | Pinned in each new app |
| Grant | The ORM and its tenancy rule pack | Pinned in each new app |
| Asset Pipeline | CSS, JavaScript and image assets | Pinned in each new app |
| grant | Database migrations (runs Micrate `.sql` files) | Built into `amber database` |
| Mica | XML request bodies | Add it when an app accepts XML |

## 1. Install the tools

You need [Homebrew](https://brew.sh) 7 or newer and Git. This pins the tap to the
reviewed formula commit, so everyone on the team builds the same versions:

```bash
brew tap amberframework/amber_cli
brew trust --tap amberframework/amber_cli
tap_path="$(brew --repo amberframework/amber_cli)"
git -C "$tap_path" fetch origin
git -C "$tap_path" checkout --detach 094eeae5cddf297fc4d74852bc3a83409d1e3d1b
HOMEBREW_NO_AUTO_UPDATE=1 brew install amberframework/amber_cli/amber_cli
```

Check the result:

```bash
amber --version      # Amber CLI v2.0.16
amber-lsp --version  # amber-lsp 1.0.0 (amber_cli 2.0.16, ...)
minecart --version   # Minecart 2025.11.25.9
```

### Optional: the Crystal Alpha compiler

Crystal Alpha adds incremental compilation and `crystal-alpha watch`. `amber-lsp`
and the assistant hooks use it when it is installed.

```bash
brew tap crimson-knight/agent-crystal
brew trust --tap crimson-knight/agent-crystal
HOMEBREW_NO_AUTO_UPDATE=1 brew install crimson-knight/agent-crystal/agent-crystal
crystal-alpha --version
```

## 2. Create an app

```bash
amber new my_app --type web -y
cd my_app
amber doctor
```

`amber new` pins every dependency, writes a `shard.lock` with SHA-256 checksums,
installs the assistant guides and connects Claude Code and Codex to `amber-lsp`.
SQLite is the default database, and it needs no server. Pass `-d pg` or `-d mysql`
to choose another.

Commit everything it generated, including `shard.lock`, `.minecart-policy.yml`,
`.amber/`, `.claude/` and `.codex/`, so every clone gets the same setup.

`amber doctor` ends with exit 0 when the project is ready. It names the fix for
each item it reports. On a new project it asks you to open it once in Claude Code
and accept the trust prompt. For Codex, trust `.codex/hooks.json`.

## 3. Run it

```bash
amber generate scaffold Pet name:string:required species:string:required adopted:bool
amber database migrate
AMBER_ENV=test amber database migrate
crystal spec
amber watch
```

Open <http://127.0.0.1:3000/pets/new>.

Teammates who clone the app run one command to install exactly what the lock says:

```bash
minecart install --frozen
```

Everyone on the team uses Minecart 2025.11.25.9 or newer, the version these steps
install. An older Minecart reports a checksum mismatch on this `shard.lock`.

## 4. See the rules work

Amber ships its rules with the framework, and they apply with no setup. Print the
rules for your project:

```bash
amber-lsp context
```

Check a file by hand:

```bash
amber-lsp --check src/controllers/pet_controller.cr
```

| Rule | Severity | What it asks for |
|---|---|---|
| `amber/models-inherit-grant` | Error | Models inherit from `Grant::Base` |
| `amber/security-headers-pipe` | Error | `Amber::Pipe::SecurityHeaders` |
| `amber/views-are-ecr` | Error | ECR views |
| `amber/json-perimeter` | Warning | Payloads parsed into `JSON::Serializable` types |
| `amber/narrow-nil` | Warning | `if value = maybe`, or a named error |
| `amber/output-through-log` | Warning | `Log.info { "message" }` |
| `grant/*` | Error or warning | Tenant-scoped queries, when the app uses tenancy |

These sit alongside the built-in checks for controllers, routes, schemas, jobs,
mailers, sockets, file names and type signatures. Turn off a rule or change its
severity in `.amber-lsp.yml`.

Before calling a library method, look it up. The answer comes from the source your
project actually compiles against:

```bash
amber-lsp lookup 'Grant::Base.where'
amber-lsp lookup 'String#split'
```

### In Claude Code and Codex

The generated hooks do this for you. Each session starts with the rules, each
Crystal edit is formatted and checked, and the project builds when the assistant
stops. Each dependency's guides are in `.claude/skills/`.

### In another editor

Point your editor's language server client at the `amber-lsp` command for `.cr`
files; it speaks LSP over standard input and output. It provides diagnostics, hover,
go-to-definition and workspace symbols. It has no autocomplete yet.

## 5. Accept XML with Mica

Amber links no XML library and answers XML requests with `415` until an app opts in.
Add Mica to `shard.yml`:

```yaml
dependencies:
  mica:
    github: amberframework/mica
    commit: 80f4b7a4d3f3365fadda160554bf68001b394a82 # v0.1.1
```

```bash
minecart update mica
grep -A3 '^  mica:' shard.lock   # checksum: sha256-v2:f13de354cf66409ccbc1e975f08b23e230620fc895309d057b7ba79aa07ce4e4
```

Then register it in `config/initializers/request_body_parsers.cr`:

```crystal
require "mica/xml/fields"

{"application/xml", "text/xml"}.each do |media_type|
  Amber::Schema::Parser::ParserRegistry.register_body_parser(media_type) do |body|
    Mica::XML::Fields.read(body)
  end
end
```

## 6. Before production

- Build with `crystal build src/my_app.cr --release -o bin/my_app`.
- Behind a load balancer or reverse proxy, list it in `server.trusted_proxies`.
  Amber reads the client address and scheme only from listed proxies.
- New apps plug `Amber::Pipe::SecurityHeaders` into the web, static and API
  pipelines. Tune it in the `security_headers` settings section.
- Set `AMBER_ENV=production` and run `amber database migrate` as a release step.
- Amber V2 is a beta. See [Generator support](GENERATOR_SUPPORT.md) for which
  generators are release-gated and which are previews.

## Upgrade an existing app

Pin the release commits and move the lock:

```yaml
dependencies:
  amber:
    github: amberframework/amber
    commit: 0830e3fdbc5e05be851c3c7ae7bf03b67be10732 # v2.0.0-beta.15
  grant:
    github: crimson-knight/grant
    commit: b83a82f0261509d4ce1f26fadb318c8ba132a066 # v0.26.0
  asset_pipeline:
    github: amberframework/asset_pipeline
    commit: 84f3188239e43dc6e0bcfd2e72074e8ec67156cd # v0.40.0
```

```bash
minecart update amber grant asset_pipeline
grep -A3 '^  amber:' shard.lock   # checksum: sha256-v2:14df1ff766414599f53a8be6816023374ba01cc6a2bd6d61ad1cabb81d88ad28
amber setup:agent
```

An app that serves HTTPS itself (`server.ssl`) or sends mail with mailer
`use_tls` adds `require "amber/tls"` right after `require "amber"` in
`config/application.cr`. TLS is opt-in from Amber 2.0.0-beta.15; without that
line such an app stops at start with `Amber::Exceptions::TLSNotCompiledIn`.

`git-tree:` entries already in your lock keep verifying, and Minecart prints a
notice about them. Minecart 2025.11.25.9 stops on a folder in `lib/` that
`shard.lock` does not pin, and names it. Remove that folder and install again.

Then read the
[beta.15 release notes](https://github.com/amberframework/amber/blob/v2.0.0-beta.15/RELEASE_NOTES_V2_BETA15.md).
