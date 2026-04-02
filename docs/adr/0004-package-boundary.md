# ADR 0004: Keep the Addon Payload Isolated

## Status

Accepted as the current working direction.

## Context

This repository contains implementation work, probes, tests, and later a demo project. Users of the addon should only need the addon payload itself, not development-only tooling or validation content.

## Decision

Treat `addons/claude_agent_sdk/` as the only future distributable addon payload.

Keep these areas outside the distributable addon tree:

- `tests/`
- `tools/`
- future `demo/`
- development-only dependencies such as GdUnit4

Do not add `plugin.cfg` for this addon in Phase 3, because editor tooling is not part of the current runtime target.

## Consequences

Benefits:

- cleaner release packaging later
- less risk of shipping test-only or probe-only files
- clearer separation between runtime code and project tooling

Costs:

- project-level tooling has to be documented clearly
- contributors need to understand the boundary instead of assuming everything under `addons/` ships

## Notes

- A local development dependency may still live under `addons/` if required by Godot conventions, but it is not part of the addon payload unless it is under `addons/claude_agent_sdk/`.
