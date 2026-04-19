# Architecture Decision Records

This directory keeps short records of long-lived decisions that affect the Amber CLI release path, install story, or generated project behavior.

## When To Add One

Add or update an ADR when a change:

- affects how users install or upgrade Amber
- changes the release pipeline or packaging strategy
- changes the default scaffold in a way we expect to defend later
- introduces a tradeoff that is likely to come up again in reviews

## Format

Use one file per decision:

- `0001-short-title.md`
- `0002-another-title.md`

Keep each ADR short and concrete:

1. Context
2. Decision
3. Consequences

PRs that touch long-lived decisions should link the ADR they add or update.
