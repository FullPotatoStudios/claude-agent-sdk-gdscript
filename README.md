# Claude Agent SDK for GDScript

This repository aims to port the [Claude Agent SDK for Python](https://github.com/anthropics/claude-agent-sdk-python) to GDScript and ship it as a Godot addon that can be used directly in Godot projects.

The intended end state is:

- a reusable runtime addon under `addons/claude_agent_sdk/`
- a Godot-native API for building Claude-powered tools and UIs
- an optional fully featured chat panel scene included in the addon
- a separate minimal demo project used to validate the addon end to end

## Current status

The project now has a first working Phase 4 core runtime under `addons/claude_agent_sdk/runtime/`.

The current focus has moved from planning into validating and refining the core SDK implementation.

Phase 1 established that Godot can drive the Claude CLI in a way that supports the Python SDK's streaming control protocol model, including a packaged macOS headless validation run.
Phase 2 cut the upstream SDK into a concrete v1 scope for the first implementation target.
Phase 3 locked the repo structure, addon boundary, and GdUnit4-based development workflow.
Phase 4 delivered the first scene-free runtime with subprocess transport, control-protocol initialization, typed message parsing, a one-shot query API, and an interactive client backed by automated tests.

Because `RefCounted` already reserves `connect()` and `disconnect()` for Godot's signal API, the current GDScript-facing client uses `connect_client()` and `disconnect_client()` instead of the upstream-style method names.

The runtime stays scene-free at the API level, but the subprocess transport still requires an active Godot `SceneTree` so it can dispatch pipe events back onto the main loop safely.

The current upstream reference target is:

- Upstream repo: `https://github.com/anthropics/claude-agent-sdk-python`
- Local reference: a sibling checkout of the upstream repo, if available
- Upstream version: `v0.1.54`
- Upstream commit: `574044a1fcbaf89afc821bb742ccd8d31c4d6944`

## Working direction

The current recommended architecture is:

- scene-free core SDK classes in GDScript
- optional Godot-facing adapters built around signals and Node lifecycle
- optional reusable chat UI scene built on top of the adapters
- no required `EditorPlugin`
- no required autoload
- no required Python SDK git submodule

The addon should be distributed as a self-contained `addons/claude_agent_sdk/` tree. The demo project should remain separate from the distributable addon payload.

## Planned repository structure

This is the target structure as implementation begins:

```text
addons/claude_agent_sdk/
  runtime/
    protocol/
    transport/
    messages/
    parser/
  runtime/adapters/
  ui/
  icons/
demo/
docs/
tests/
tools/
```

`plugin.cfg` should only be added if we decide to ship optional editor tooling. The runtime addon itself should not depend on editor-plugin enablement.

## Project docs

- Roadmap: `docs/roadmap/roadmap.md`
- Phase 1 investigation: `docs/investigations/phase-1-feasibility.md`
- Phase 1 findings: `docs/investigations/phase-1-findings.md`
- Phase 1 support matrix: `docs/investigations/phase-1-support-matrix.md`
- Architecture ADR: `docs/adr/0001-core-architecture.md`
- Upstream tracking ADR: `docs/adr/0002-upstream-tracking.md`
- Godot version ADR: `docs/adr/0003-godot-version-policy.md`
- Package boundary ADR: `docs/adr/0004-package-boundary.md`
- Runtime class-shape ADR: `docs/adr/0005-runtime-class-shape.md`
- Testing ADR: `docs/adr/0006-testing-strategy.md`
- Upstream ledger: `docs/parity/upstream-ledger.md`
- Feature matrix: `docs/parity/feature-matrix.md`
- v1 scope: `docs/parity/v1-scope.md`
- Contributor workflow: `docs/contributing/workflow.md`
- Testing workflow: `docs/contributing/testing.md`

## Planned process

1. Prove Godot subprocess and pipe feasibility with the Claude CLI.
2. Define the supported platform/export matrix and CLI provisioning policy.
3. Map upstream Python SDK features into a v1 parity scope.
4. Lock architecture and scaffolding decisions in ADRs.
5. Scaffold the addon runtime and test layout.
6. Implement the core transport/protocol/types layers.
7. Add Godot adapters, then the reusable chat panel, then the demo project.

## Important constraints

- The Python SDK is a reference implementation, not something this addon should depend on at runtime.
- If Asset Library distribution matters, required git submodules should be avoided.
- Testability matters early: transport, parser, and session behavior should be validated before UI work becomes the main focus.
- Only `addons/claude_agent_sdk/` is intended to become distributable addon payload; tests and probes are dev-only project content.
