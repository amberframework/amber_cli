# ADR 0001: Use a Dedicated Homebrew Tap For Amber CLI Releases

## Context

Amber v2 needs a low-friction install story for both developers and coding agents. The immediate goal is to let a new machine run:

```bash
brew tap amberframework/amber_cli
brew install amber_cli
amber new my_app
```

At the same time, the release process needs to stay under Amber's control while the CLI, tap, and generated scaffold are still moving quickly.

`homebrew/core` is still a future target, but it has a stricter review bar and is more likely to want a source-built formula than a formula that points at upstream prebuilt Amber CLI tarballs.

## Decision

For the Amber v2 release-candidate phase:

- publish release assets from `amberframework/amber_cli`
- distribute those assets through `amberframework/homebrew-amber_cli`
- automatically update the tap formula after a successful CLI release
- validate the tap on macOS and Linux by running `brew test amber_cli` and `amber new smoke_app -y --no-deps`

## Consequences

### Positive

- Amber controls the full release path while the tooling is still stabilizing
- new users and agents get a fast install story now
- CI can verify the real install path before announcements go out

### Tradeoffs

- release automation spans more than one repository
- we must keep the CLI repo, tap repo, and docs aligned
- this is not yet the final `homebrew/core` packaging story

### Follow-up

When the install flow and generated scaffold are stable enough, evaluate a source-built formula path for `homebrew/core`.
