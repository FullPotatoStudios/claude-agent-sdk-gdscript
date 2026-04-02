# ADR 0006: Use GdUnit4 as a Development-Only Test Dependency

## Status

Accepted as the current working direction.

## Context

Phase 3 needs a real testing path before core implementation begins. The project is a Godot addon, so the test approach should run against Godot itself rather than relying on a custom harness alone.

## Decision

Use GdUnit4 as the primary test framework for the project.

Testing assumptions for the current phase:

- target Godot `4.6`
- run tests headlessly in local development
- keep GdUnit4 as a development-only dependency
- keep tests under `tests/`, outside `addons/claude_agent_sdk/`

## Consequences

Benefits:

- real Godot-native test execution path
- easier unit-style and integration-style test growth
- less need to invent custom testing infrastructure early

Costs:

- local setup is a little heavier than plain headless scripts
- GdUnit4 itself must stay outside the addon payload boundary

## Notes

- Existing probe scripts remain useful and should stay separate from the formal GdUnit4 test suite.
- Headless test execution should be documented in contributor docs and runnable from project scripts.
