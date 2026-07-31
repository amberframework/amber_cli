# Amber V2 Beta Release Checklist

Release order matters because generated apps pin a framework version and the
Homebrew formula pins CLI archives and checksums.

## 1. Framework prerelease

1. Confirm `shard.yml`, `src/amber/version.cr`, and the changelog all say
   `2.0.0-beta.2`.
2. Run framework specs and formatting on macOS and Linux.
3. Tag the reviewed `v2-dev` commit as `v2.0.0-beta.2`.
4. Publish it as a GitHub prerelease with migration and support-matrix links.

## 2. CLI release

1. Confirm `shard.yml` and `AmberCLI::VERSION` both say `2.0.2`.
2. Generate a web app and verify it pins the framework prerelease.
3. On both supported platforms, install shards, run app specs, build the app,
   start it, and request `/` plus `/css/app.css`.
4. On macOS, reject any binary linked to `openssl@1.1`.
5. Tag `v2.0.2`, publish the release, and wait for both archives and checksum
   files to upload.

## 3. Homebrew

1. Update the underscore tap, `amberframework/homebrew-amber_cli`.
2. Verify both archive checksums in the formula.
3. Run `brew install amberframework/amber_cli/amber_cli` on macOS and Linux.
4. Repeat the complete generated-web-app smoke test from the installed formula.

## 4. Documentation

1. Publish framework, CLI, and website guides with the same command names,
   versions, platform matrix, and preview labels.
2. Check that no onboarding page uses a hyphenated tap or formula name, a
   separate tap step, a personal fork, a moving `v2-dev` dependency, or Slang
   for a new V2 app.
3. Verify all release/download links and commands from a clean shell.

Do not mark the beta complete if either supported platform cannot install the
CLI and build the generated web application.
