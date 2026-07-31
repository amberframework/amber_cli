---
name: Release Checklist
about: Track the full Amber CLI release flow from dry-run to announcement
title: "Release checklist: vX.Y.Z"
labels: ["release"]
assignees: []
---

## Release Goal

- Version:
- Type: `beta` / `rc` / `stable` / `patch`
- Announcement target:

## Preflight

- [ ] All release-impacting PRs include `Why`, `Release Impact`, and `Verification`
- [ ] Release notes draft is ready
- [ ] `RELEASE_SETUP.md` matches the intended flow
- [ ] Tap repo formula workflow is green on `main`

## Dry Run

- [ ] Run `gh workflow run release.yml --repo amberframework/amber_cli --ref <branch> -f ref=<branch>`
- [ ] Confirm `Build darwin-arm64` passed
- [ ] Confirm `Build linux-x86_64` passed

## Publish

- [ ] Tag pushed
- [ ] GitHub release published
- [ ] Release assets uploaded
- [ ] Checksums uploaded

## Homebrew

- [ ] `Update Formula` completed in `amberframework/homebrew-amber_cli`
- [ ] `Validate Install` passed on macOS
- [ ] `Validate Install` passed on Ubuntu
- [ ] Formula points at the new version and checksums

## Fresh Install Verification

- [ ] `brew install amberframework/amber_cli/amber_cli`
- [ ] `brew test amber_cli`
- [ ] macOS binaries do not link to `openssl@1.1`
- [ ] `amber new smoke_app --type web -y --no-deps`
- [ ] Generated app pins the reviewed Amber version and ECR template
- [ ] `shards install`, app specs, and app build pass
- [ ] Built app starts and serves `/` plus `/css/app.css`

## Post Release

- [ ] Announcement post updated or published
- [ ] README and docs still match the released commands
- [ ] Follow-up issues filed for anything deferred
