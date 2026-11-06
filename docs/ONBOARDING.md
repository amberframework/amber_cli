# Start here: the Amber V2 toolchain

This page takes a new developer from a bare machine to an Amber V2 app with
checksum-verified dependencies, and with editor and coding-assistant rules active
from the first edit. It covers Amber CLI 2.0.9, Amber 2.0.0-beta.9 and Minecart
2025.11.25.8 on Apple Silicon macOS and Linux.

## What you get

| Tool | What it does | How it arrives |
|---|---|---|
| `amber` | Generates, runs and migrates apps | Homebrew formula |
| `amber-lsp` | Language server, API lookup and rule checks | Same formula |
| `minecart` | Installs dependencies and verifies their checksums | Dependency of the formula |
| Crystal | Compiles the app | Dependency of the formula |
| Amber 2.0.0-beta.9 | The framework, its rule pack and its guides | Pinned in each new app |
| Grant | The ORM and its tenancy rule pack | Pinned in each new app |
| Asset Pipeline | CSS, JavaScript and image assets | Pinned in each new app |
| micrate | Database migrations | Built into `amber database` |
| Mica | XML request bodies | Add it when an app accepts XML |

## 1. Install the tools

You need [Homebrew](https://brew.sh) 7 or newer and Git. This pins the tap to the
reviewed formula commit, so everyone on the team builds the same versions:

```bash
brew tap amberframework/amber_cli
brew trust --tap amberframework/amber_cli
tap_path="$(brew --repo amberframework/amber_cli)"
git -C "$tap_path" fetch origin
git -C "$tap_path" checkout --detach 018819c6340135c7b0d5b9767640e8ff9ad23491
HOMEBREW_NO_AUTO_UPDATE=1 brew install amberframework/amber_cli/amber_cli
```

Check the result:

```bash
amber --version      # Amber CLI v2.0.9
amber-lsp --version  # amber-lsp 1.0.0 (amber_cli 2.0.9, ...)
minecart --version   # Minecart 2025.11.25.8
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

`amber new` pins every dependency, writes a `shard.lock` with Git tree checksums,
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

Pin the release's commit and move the lock:

```yaml
dependencies:
  amber:
    github: amberframework/amber
    commit: 34a93352eaa89501d24e2b9ff90b058209a22720 # v2.0.0-beta.9
```

```bash
minecart update amber
grep -A2 '^  amber:' shard.lock   # checksum: git-tree:f1e7332d02229aec58ab5303ade7fc6c9d14fcee
amber setup:agent
```

Then read the
[beta.9 release notes](https://github.com/amberframework/amber/blob/v2.0.0-beta.9/RELEASE_NOTES_V2_BETA9.md).
