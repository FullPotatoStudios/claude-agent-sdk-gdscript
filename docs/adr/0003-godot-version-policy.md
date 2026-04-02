# ADR 0003: Target Godot 4.6 First

## Status

Accepted as the current working direction.

## Context

The current feasibility and exported-app validation work was done with Godot `4.6.1`. Broad multi-version compatibility would add planning and testing overhead before the core SDK exists.

## Decision

Lock the initial implementation target to Godot `4.6`.

For Phase 3 and the first implementation slices:

- assume Godot `4.6` APIs and behavior
- do not spend effort on broad `4.x` compatibility shims yet
- treat compatibility widening as later work after the core SDK is usable

## Consequences

Benefits:

- fewer moving parts during early implementation
- clearer testing target
- less ambiguity around process, export, and scripting behavior

Costs:

- broader compatibility claims must wait
- future widening to additional `4.x` versions may require follow-up work

## Notes

- `4.6.1.stable.official.14d19694e` is the currently validated local version.
- This policy can be revisited after the core SDK is stable.
