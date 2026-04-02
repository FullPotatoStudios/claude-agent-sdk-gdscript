# ADR 0001: Scene-Free Core With Godot Adapters

## Status

Accepted as the current working direction.

## Context

The Python SDK is layered around a transport, control protocol, parser, typed models, and public client/query APIs. Godot integration should feel native without tying the core SDK to the scene tree.

## Decision

Build the core SDK as scene-free GDScript classes.

Use Godot-native adapters at the boundary for:

- signals
- optional Node lifecycle integration
- reusable UI scenes

The reusable chat panel should depend on the adapter layer, not on low-level transport code directly.

## Consequences

Benefits:

- easier testing
- less coupling to scene lifecycle
- easier reuse in custom UIs
- closer parity with upstream SDK layering

Costs:

- extra adapter layer to design and maintain
- some APIs will need explicit Godot wrapping instead of direct core exposure

## Notes

- The core should avoid hidden `Node` assumptions.
- Polling, threading, and process lifecycle concerns should stay out of the pure core where possible.
