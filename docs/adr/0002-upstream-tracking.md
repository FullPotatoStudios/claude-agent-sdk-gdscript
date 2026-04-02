# ADR 0002: Track Upstream Explicitly Without a Required Git Submodule

## Status

Accepted as the current working direction.

## Context

The Python SDK is the reference implementation for feature parity, but this repository should remain easy to clone, package, and distribute as a Godot addon.

## Decision

Do not make the upstream Python SDK a required git submodule for this repository.

Instead:

- keep a pinned upstream version and commit in project docs
- maintain an upstream ledger
- maintain a feature matrix
- review upstream changes incrementally from the last pinned commit

## Consequences

Benefits:

- less contributor friction
- cleaner addon packaging
- avoids shipping or depending on submodule contents
- keeps the boundary clear between reference implementation and addon

Costs:

- parity maintenance requires discipline and documentation
- tooling may need to locate a sibling checkout or temporary clone when diffing upstream

## Notes

- This can be revisited later if parity tooling proves too painful without a pinned in-repo checkout.
- If Asset Library distribution matters, avoiding required submodules is preferable.
