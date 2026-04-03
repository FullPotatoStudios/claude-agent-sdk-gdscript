# Claude Agent SDK for GDScript

This repository aims to port the [Claude Agent SDK for Python](https://github.com/anthropics/claude-agent-sdk-python) to GDScript and ship it as a Godot addon that can be used directly in Godot projects.

The intended end state is:

- a reusable runtime addon under `addons/claude_agent_sdk/`
- a Godot-native API for building Claude-powered tools and UIs
- an optional fully featured chat panel scene included in the addon
- demo scenes and scripts under `demo/` used to validate the addon end to end

## Current status

The project now has a working Phase 6 runtime and integration layer under `addons/claude_agent_sdk/runtime/`.

Phase 7 is now implemented: the addon ships a reusable `ClaudeChatPanel` under `addons/claude_agent_sdk/ui/`, and the root Godot project opens a demo scene under `demo/` that exercises that shipped panel directly.

Phase 8 is now underway: the repo includes canonical addon versioning, release packaging scripts, a fresh-project packaged-consumer validation flow, and release/parity maintenance docs.

The current focus is packaging, release, and parity maintenance.

Phase 1 established that Godot can drive the Claude CLI in a way that supports the Python SDK's streaming control protocol model, including a packaged macOS headless validation run.
Phase 2 cut the upstream SDK into a concrete v1 scope for the first implementation target.
Phase 3 locked the repo structure, addon boundary, and GdUnit4-based development workflow.
Phase 4 delivered the first scene-free runtime with subprocess transport, control-protocol initialization, typed message parsing, a one-shot query API, and an interactive client backed by automated tests.
Phase 5 added hook callbacks, tool-permission callbacks, partial-message parsing, structured-output/result fields, context/MCP control operations, and an explicit CLI auth-status probe, with runtime validation recorded in `docs/investigations/phase-5-validation.md`.
Phase 6 added `ClaudeClientAdapter` and `ClaudeClientNode` as thin Godot-native wrappers over the scene-free core, plus adapter-focused tests and lightweight integration examples.
Phase 7 added the addon-owned `ClaudeChatPanel`, a demo scene that uses it directly, dedicated UI tests, and end-to-end validation coverage for baseline chat, structured output, and partial-message rendering.

Because `Object` and `RefCounted` already reserve names such as `connect()`, `disconnect()`, and `is_connected()` for Godot's own signal API, the Godot-facing integration layer uses names such as `connect_client()`, `disconnect_client()`, and `is_client_connected()` where needed.

The runtime stays scene-free at the API level, but the subprocess transport still requires an active Godot `SceneTree` so it can dispatch pipe events back onto the main loop safely.

Claude auth is treated as CLI-owned rather than SDK-owned. By default the runtime inherits the parent environment and reuses the installed Claude CLI's existing login and settings state. The runtime now exposes an explicit auth-status probe through `ClaudeSDKClient.get_auth_status()` and `ClaudeQuery.get_auth_status()` so callers can distinguish logged-out CLI state from transport failures.

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

The addon should be distributed as a self-contained `addons/claude_agent_sdk/` tree. The `demo/` content should remain separate from the distributable addon payload.

## Install

### GitHub Release ZIP

1. Download the release ZIP produced by `./tools/release/build_release.sh`.
2. Unzip it into the target Godot project's root so the addon lands at `res://addons/claude_agent_sdk/`.
3. Use the runtime, adapters, or `ClaudeChatPanel` directly from your project scenes/scripts.

No `plugin.cfg` or editor-plugin enablement is required for the current runtime/UI addon shape.

### Godot Asset Library

The intended Asset Library flow is to reference the same GitHub Release ZIP through a custom download provider.

Consumers should end up with the same installed layout:

- `res://addons/claude_agent_sdk/`

See `docs/release/asset-library.md` for the submission and metadata strategy.

## Known limitations

- Godot support target is `4.6` only.
- The addon depends on a user-installed `claude` CLI and reuses its existing login/config state.
- Desktop/editor use is the supported path for the first release.
- Exported macOS support remains limited to the unsandboxed scenarios validated so far.

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
- Phase 5 validation: `docs/investigations/phase-5-validation.md`
- Architecture ADR: `docs/adr/0001-core-architecture.md`
- Upstream tracking ADR: `docs/adr/0002-upstream-tracking.md`
- Godot version ADR: `docs/adr/0003-godot-version-policy.md`
- Package boundary ADR: `docs/adr/0004-package-boundary.md`
- Runtime class-shape ADR: `docs/adr/0005-runtime-class-shape.md`
- Testing ADR: `docs/adr/0006-testing-strategy.md`
- Upstream ledger: `docs/parity/upstream-ledger.md`
- Feature matrix: `docs/parity/feature-matrix.md`
- v1 scope: `docs/parity/v1-scope.md`
- Release install guide: `docs/release/install.md`
- Release packaging guide: `docs/release/packaging.md`
- Release process: `docs/release/release-process.md`
- Asset Library guide: `docs/release/asset-library.md`
- Contributor workflow: `docs/contributing/workflow.md`
- Testing workflow: `docs/contributing/testing.md`
- Integration guide: `docs/contributing/integration.md`
- Chat panel guide: `docs/contributing/ui-panel.md`
- Phase 7 validation: `docs/investigations/phase-7-validation.md`
- Phase 8 validation: `docs/investigations/phase-8-validation.md`

## Planned process

1. Prove Godot subprocess and pipe feasibility with the Claude CLI.
2. Define the supported platform/export matrix and CLI provisioning policy.
3. Map upstream Python SDK features into a v1 parity scope.
4. Lock architecture and scaffolding decisions in ADRs.
5. Scaffold the addon runtime and test layout.
6. Implement the core transport/protocol/types layers.
7. Expand runtime parity for high-value non-UI features.
8. Add Godot adapters, then the reusable chat panel, then the demo project.
9. Package the addon cleanly and establish an upstream parity maintenance flow.

## Important constraints

- The Python SDK is a reference implementation, not something this addon should depend on at runtime.
- If Asset Library distribution matters, required git submodules should be avoided.
- Testability matters early: transport, parser, and session behavior should be validated before UI work becomes the main focus.
- Only `addons/claude_agent_sdk/` is intended to become distributable addon payload; tests and probes are dev-only project content.
