# Amber CLI 2.0.6

Amber CLI 2.0.6 is the coordinated generator release for Amber
`2.0.0-beta.5`. Fresh web applications now use the framework's automatically
enforced schema contracts instead of constructing and validating a second
schema object inside each controller action.

## Generate a complete web application

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

The generated project pins canonical Amber `2.0.0-beta.5`, uses ECR, Grant,
SQLite, Micrate, local front-end assets, and a manifest-backed asset pipeline.

## What changed

- Resource scaffolds bind `PetSchema` automatically to `create` and `update`
  and read typed request-local values with `validated_as(PetSchema)`.
- HTML form schemas declare URL-encoded input and return the generated ECR form
  with visible field errors and HTTP 422 when a well-formed request is invalid.
- Malformed or unsupported form bodies preserve the framework's explicit 400
  or 415 status instead of being flattened into a generic validation error.
- Preview API generators bind the same executable schema contract for JSON
  writes while retaining structured JSON failures.
- `amber generate schema` teaches the executable controller declaration as the
  primary application path; direct construction remains available for isolated
  schema unit tests.
- The Unix and Windows generated-app smoke harnesses can test an exact framework
  repository and commit during coordinated development, while normal and
  release CI now exercise the published beta emitted by the template.

## Upgrade compatibility

Amber's deprecated `params.validation` API remains functional. Existing Amber
applications can update the framework first, verify their current behavior,
and migrate validation one controller action at a time. CLI 2.0.6 changes new
generators; it does not force an existing application to regenerate its
controllers.

## Release proof

- 412 Amber CLI examples pass.
- Apple Silicon macOS and x86_64 Linux release-style binaries generate, build,
  migrate, run, and exercise the complete web application.
- Linux ARM64 and Windows x86_64 compile and run the generated web application
  in GitHub Actions.
- The Pet Tracker smoke proves invalid HTML form input returns one HTML
  document with status 422 and a visible field error before proving persisted
  create and PATCH update behavior.
- Fingerprinted CSS, JavaScript, SVG, and favicon responses retain integrity,
  MIME, immutable caching, URL rewriting, and gzip checks.

Windows remains a source-build compatibility path; this release publishes CLI
archives for Apple Silicon macOS, x86_64 Linux, and ARM64 Linux.
