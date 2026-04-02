# Testing

## Purpose

This project uses two validation paths during early development:

- GdUnit4 for repeatable tests under `tests/`
- probe scripts under `tools/spikes/` for transport and runtime experiments

The addon payload is still only `addons/claude_agent_sdk/`. Tests and probes are development-only project content.

## Godot target

- Initial test target: Godot `4.6`
- Current validated local binary example:
  - `/Applications/Godot.app/Contents/MacOS/Godot`

## GdUnit4 policy

- GdUnit4 is a development-only dependency
- it should be installed locally under `addons/gdUnit4/`
- it is not part of the distributable addon payload

Install it with:

```bash
./tools/dev/install_gdunit4.sh
```

Run the test suite with:

```bash
./tools/dev/run_tests.sh
```

The default test report directory is:

- `res://.artifacts/gdunit`

## Current test split

- `tests/scaffolding/`
  - repository and layout checks
- future parser/model tests
- future transport/command-building tests
- future control-routing tests

## Probes vs tests

Use tests for:

- repeatable assertions
- repo/layout validation
- parser and runtime coverage that should stay stable

Use probes for:

- subprocess experimentation
- export/runtime validation
- temporary investigation work

Current probe entrypoints live under:

- `tools/spikes/`

## Phase 4 test targets

The first implementation phase should add explicit tests for:

- command building for the core options subset
- stdout and stderr draining behavior
- initialize/control-request routing
- parser coverage for `UserMessage`, `AssistantMessage`, `SystemMessage`, and `ResultMessage`
- one-shot query flow
- interactive client flow with `interrupt`, `set_permission_mode`, and `set_model`
- exported runtime assumptions already identified in Phase 1
