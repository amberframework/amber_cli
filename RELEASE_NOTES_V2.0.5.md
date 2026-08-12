# Amber CLI 2.0.5

Amber CLI 2.0.5 makes production-safe static assets part of the same supported
Amber V2 web-app path as Grant, Micrate, and SQLite. A fresh application starts
with editable CSS, JavaScript, SVG, and font locations; a deterministic asset
manifest; manifest-aware ECR helpers; and browser-correct production headers.

## Start a complete web app

```bash
amber new pet_tracker --type web
cd pet_tracker
shards install
amber assets check
amber generate scaffold Pet name:string:required species:string:required adopted:bool
amber database migrate
crystal spec
amber watch
```

Open <http://127.0.0.1:3000/> and <http://127.0.0.1:3000/pets>. The homepage
uses the same Amber design language as the framework site and references
fingerprinted files from `public/assets/manifest.json`.

## What changed

- Added `amber assets build` for deterministic fingerprinting and
  `amber assets check` for strict release verification.
- Moved authored browser files to `app/assets/`; generated files under
  `public/assets/` are ignored and may be rebuilt at any time.
- Rewrites local CSS URLs and JavaScript module references to their
  fingerprinted image, font, stylesheet, and module targets.
- Generates manifest-aware stylesheet, import-map, preload, image, and favicon
  tags, including Subresource Integrity metadata where browsers support it.
- Rebuilds assets before application compilation in `amber watch`, including
  file additions, changes, and deletions.
- Boots generated applications in Unix and Windows CI and requests the real
  HTML, CSS, JavaScript, SVG, and compressed-asset paths instead of treating a
  successful compile as sufficient evidence.
- Publishes CLI archives for Apple Silicon macOS, x86_64 Linux, and ARM64 Linux;
  Windows x86_64 remains a source-build path with a release-gated app smoke.

Grant, SQLite, Micrate migrations, and generated HTML resource CRUD remain the
default persistence contract from CLI 2.0.4. Native applications,
authentication generators, and generated APIs remain preview surfaces.
