# Amber CLI 2.0.2

Amber CLI 2.0.2 is the supported standalone CLI for Amber
`2.0.0-beta.2`.

## Install

```bash
brew install amberframework/amber_cli/amber_cli
amber --version
```

Direct assets are provided for Apple Silicon macOS and x86_64 Linux. Download
the matching `.tar.gz` and `.sha256` files and verify the checksum before
installing `amber` and `amber-lsp`.

## What changed

- Web apps now pin `amberframework/amber` at `2.0.0-beta.2`.
- The generated web app is ECR-only and uses typed V2 environment YAML.
- Personal fork, implicit Grant/Gemma, asset pipeline, and all-database-driver
  dependencies were removed from the core template.
- Static CSS and JavaScript use an explicit wildcard static route.
- Generated app specs no longer start the server or use invalid dynamic
  includes.
- Absolute destination paths resolve correctly.
- Dependencies install by default; `--no-deps` keeps offline/CI control.
- CLI and generator help label native and persistence-backed output as preview.
- Release CI rejects macOS binaries linked to `openssl@1.1` and exercises the
  complete generated web-app path on both supported platforms.

## Supported beta path

```bash
amber new my_app --type web
cd my_app
crystal spec
crystal build src/my_app.cr -o bin/my_app
amber watch
```

See the [web-app guide](https://github.com/amberframework/amber_cli/blob/v2.0.2/docs/BETA_WEB_APP.md)
and [generator support table](https://github.com/amberframework/amber_cli/blob/v2.0.2/docs/GENERATOR_SUPPORT.md).

Model, scaffold, API-resource, auth, and native app generators remain preview
surfaces in this release.
