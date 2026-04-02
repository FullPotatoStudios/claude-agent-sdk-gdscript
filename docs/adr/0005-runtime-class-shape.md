# ADR 0005: Use RefCounted for the Scene-Free Runtime

## Status

Accepted as the current working direction.

## Context

The Phase 2 scope cut locked a scene-free core that mirrors the upstream SDK closely enough for parity tracking. Godot integration should remain possible without tying the runtime layer to the scene tree.

## Decision

Use `RefCounted` as the default base type for scene-free runtime classes.

This applies to:

- public core runtime classes such as `ClaudeAgentOptions` and `ClaudeSDKClient`
- transport and protocol coordination classes
- parser helpers and related scene-free support code

Reserve `Node` and signal-heavy integration for later adapter and UI layers.

The one-shot entrypoint should live in `addons/claude_agent_sdk/runtime/query.gd` as a dedicated runtime script that will expose the upstream-style `query(prompt, options)` entrypoint during implementation.

## Consequences

Benefits:

- keeps the runtime portable and testable
- avoids hidden scene lifecycle assumptions
- aligns with the scene-free-core decision from ADR 0001

Costs:

- some Godot-facing ergonomics must be added in a later adapter layer
- lifecycle and signal convenience do not come for free in the core

## Notes

- This ADR locks the class-style rule, not the final implementation details of each API.
- Adapter and UI layers may use `Node` later without changing this core rule.
