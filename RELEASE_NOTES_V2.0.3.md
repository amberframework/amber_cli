# Amber CLI 2.0.3

Amber CLI 2.0.3 is the supported standalone CLI for Amber
`2.0.0-beta.2`. This patch brings the generated web application into the same
visual and front-end language as the Amber V2 website.

## Install

```bash
brew install amberframework/amber_cli/amber_cli
amber --version
```

Direct release assets are provided for Apple Silicon macOS and x86_64 Linux.
Download the matching `.tar.gz` and `.sha256` files and verify the checksum
before installing `amber` and `amber-lsp`.

## What changed

- New web applications open with a responsive Amber V2 starter page instead of
  the generic welcome screen.
- The starter carries Amber's warm paper palette, faceted-crystal motif,
  editorial type scale, status chips, and clear first-edit paths.
- The generated ECR layout now uses a browser-native import map and a local ES
  module entry point.
- CSS and JavaScript remain local to the application; the supported starter has
  no Node, npm, bundler, CDN, remote font, or UI-library requirement.
- Generator specs and the release smoke test verify the branded page, local
  stylesheet, import map, application specs, production build, and live HTTP
  responses.

## Supported beta path

```bash
amber new my_app --type web
cd my_app
crystal spec
crystal build src/my_app.cr -o bin/my_app
amber watch
```

See the [web-app guide](https://github.com/amberframework/amber_cli/blob/v2.0.3/docs/BETA_WEB_APP.md)
and [generator support table](https://github.com/amberframework/amber_cli/blob/v2.0.3/docs/GENERATOR_SUPPORT.md).

Model, scaffold, API-resource, auth, and native app generators remain preview
surfaces in this release.
