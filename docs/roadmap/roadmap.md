# Roadmap

## Goal

Port the Claude Agent SDK from Python to GDScript as a Godot addon, while adapting the public integration surface to Godot-native patterns.

## Guiding decisions

- The core SDK should be scene-free and not depend on `Node` lifecycle.
- Godot-native adapters may expose signals and optional Node wrappers.
- The addon payload should stay self-contained under `addons/claude_agent_sdk/`.
- Demo content under `demo/` should validate the addon, but should not be required to consume it.
- The Python SDK is tracked as an upstream reference, not a runtime dependency.

## Phases

### Phase 1: Feasibility gate

Goal:
- prove that Godot can run and communicate with the Claude CLI in a way that supports streaming control-protocol behavior

Outputs:
- subprocess feasibility notes
- platform/export support assumptions
- initial CLI provisioning recommendation
- decision on whether to proceed with the current transport approach

### Phase 2: Upstream mapping and v1 scope

Goal:
- map the Python SDK into a realistic GDScript v1 scope

Outputs:
- detailed feature matrix grouped by subsystem
- explicit v1 scope cut
- identified deferred items with reasons
- implementation order for the first core SDK slice

### Phase 3: Architecture and repo scaffolding

Goal:
- turn the preliminary direction into durable repo structure and design decisions

Outputs:
- ADRs
- initial addon folder structure
- top-level test layout
- documentation layout
- tooling plan for Godot 4.6 and GdUnit4

### Phase 4: Core SDK implementation

Goal:
- implement transport, protocol, types, parsing, and the initial public API

Outputs:
- transport abstraction
- Claude CLI transport spike matured into implementation
- typed message and options models
- query/client API

Implementation order:
1. transport abstraction and Claude CLI subprocess transport
2. process lifecycle rules for cwd, env, stdout, stderr, and exported builds
3. initialize handshake and control-request routing
4. typed message/content models and parser
5. `query(prompt, options)`
6. `ClaudeSDKClient` core methods:
   - `connect`
   - `query`
   - `receive_messages`
   - `receive_response`
   - `disconnect`
   - `interrupt`
   - `set_permission_mode`
   - `set_model`
   - `get_server_info`
7. test coverage for transport, parser, one-shot flow, interactive flow, and exported-runtime assumptions

### Phase 5: Secondary SDK capabilities

Goal:
- implement the highest-value parity features beyond the core conversation loop

Delivered areas:
- hooks
- permission handling
- structured output support
- context-usage queries
- MCP status/reconnect/toggle
- partial-message / `stream_event` support

Still deferred within runtime parity:
- sessions
- custom tool support, if feasible in Godot

### Phase 6: Godot integration layer

Goal:
- expose the core SDK in Godot-native ways

Outputs:
- signal-based adapters
- optional Node facade(s)
- examples for custom UI integration

Delivered:
- `ClaudeClientAdapter` as a signal-based `RefCounted` facade over `ClaudeSDKClient`
- `ClaudeClientNode` as an optional scene-tree wrapper over the adapter
- lightweight custom-integration examples and docs

### Phase 7: Reusable chat panel and demo validation

Goal:
- ship a usable reference UI and validate the addon end to end

Outputs:
- reusable chat panel scene in the addon
- root-project demo scenes and scripts under `demo/`
- documentation for using the panel and replacing it

Delivered:
- `ClaudeChatPanel` under `addons/claude_agent_sdk/ui/`
- root-project demo scene under `demo/` that uses the shipped panel directly
- panel-focused UI tests and demo-scene validation tests
- runtime smoke validation kept intact for `baseline`, `structured`, and `partial`

### Phase 8: Packaging, release, and parity maintenance

Goal:
- make the addon easy to distribute and keep aligned with upstream over time

Outputs:
- release packaging flow
- parity update checklist in active use
- upstream ledger updates per sync cycle

### Phase 9: Hooks, scripted validation, and GitHub release automation

Goal:
- make validation and release publishing automation-first while keeping repo scripts as the source of truth

Outputs:
- repo-managed git hooks
- canonical validation and release-prep wrapper scripts
- GitHub Actions CI on pull requests and `main`
- tag-driven GitHub Release publishing
- automated Asset Library metadata preparation with a manual final submission boundary

## Current focus

Work should currently prioritize Phase 9.
