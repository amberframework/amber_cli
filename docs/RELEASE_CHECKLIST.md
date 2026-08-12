# Amber V2 Beta Release Checklist

Release order matters because generated apps pin a framework version and the
Homebrew formula pins CLI archives and checksums.

## 1. Framework prerelease

1. Confirm `shard.yml`, `src/amber/version.cr`, and the changelog all say
   `2.0.0-beta.4`.
2. Run framework specs and formatting on macOS and Linux.
3. Tag the reviewed `v2-dev` commit as `v2.0.0-beta.4`.
4. Publish it as a GitHub prerelease with migration and support-matrix links.

## 2. CLI release

1. Confirm `shard.yml` and `AmberCLI::VERSION` both say `2.0.5`.
2. Generate a web app and verify it pins the framework prerelease.
3. Verify the generated app pins the reviewed Asset Pipeline revision and has
   no placeholder dependency revisions.
4. On macOS, x86-64 Linux, and ARM64 Linux, install shards; run
   `amber assets build` and `amber assets check`; run app specs; build and start
   the app; then follow the manifest-rendered CSS, JavaScript, SVG, and favicon
   URLs from `/`.
5. For fingerprinted responses, verify MIME, SRI in rendered tags, immutable
   caching, `nosniff`, and gzip negotiation. Confirm CSS rewrites its authored
   image URL and that `public/assets/` contains no source-owned raw entry point.
6. On macOS, reject any binary linked to `openssl@1.1`.
7. Confirm the Windows x86-64 generated app builds in CI. This is a compatibility
   check, not a beta release gate.
8. Tag `v2.0.5`, publish the release, and wait for all archives and checksum
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
   separate tap step, a personal Amber fork, a moving `v2-dev` dependency, or
   Slang for a new V2 app.
3. Verify all release/download links and commands from a clean shell.

Do not mark the beta complete if macOS, x86-64 Linux, or ARM64 Linux cannot
install the CLI and complete the generated web-app and asset smoke. Record a
Windows CI failure as a known compatibility issue; Windows does not gate this
beta.
