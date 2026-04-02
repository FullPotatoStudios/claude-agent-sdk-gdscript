# Claude Agent SDK for GDScript

This repository aims to port the [Claude Agent SDK for Python](https://github.com/anthropics/claude-agent-sdk-python) to GDScript and ship it as a Godot addon that can be used directly in Godot projects.

The intended end state is:

- a reusable runtime addon under `addons/claude_agent_sdk/`
- a Godot-native API for building Claude-powered tools and UIs
- an optional fully featured chat panel scene included in the addon
- a separate minimal demo project used to validate the addon end to end

## Current status

This project is in preliminary work.

The first hard gate is **Phase 1: subprocess feasibility**. Before porting the SDK, we need to prove that Godot can drive the Claude CLI in a way that supports the Python SDK's streaming control protocol model.

The current upstream reference target is:

- Upstream repo: `https://github.com/anthropics/claude-agent-sdk-python`
- Local sibling checkout: `../claude-agent-sdk-python`
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
  runtime/adapters/
  ui/
  icons/
demo/
docs/
tools/
```

`plugin.cfg` should only be added if we decide to ship optional editor tooling. The runtime addon itself should not depend on editor-plugin enablement.

## Project docs

- Roadmap: `docs/roadmap/roadmap.md`
- Phase 1 investigation: `docs/investigations/phase-1-feasibility.md`
- Architecture ADR: `docs/adr/0001-core-architecture.md`
- Upstream tracking ADR: `docs/adr/0002-upstream-tracking.md`
- Upstream ledger: `docs/parity/upstream-ledger.md`
- Feature matrix: `docs/parity/feature-matrix.md`
- Contributor workflow: `docs/contributing/workflow.md`

## Planned process

1. Prove Godot subprocess and pipe feasibility with the Claude CLI.
2. Define the supported platform/export matrix and CLI provisioning policy.
3. Map upstream Python SDK features into a v1 parity scope.
4. Lock architecture and tracking decisions in ADRs.
5. Implement the core transport/protocol/types layers.
6. Add Godot adapters, then the reusable chat panel, then the demo project.

## Important constraints

- The Python SDK is a reference implementation, not something this addon should depend on at runtime.
- If Asset Library distribution matters, required git submodules should be avoided.
- Testability matters early: transport, parser, and session behavior should be validated before UI work becomes the main focus.
