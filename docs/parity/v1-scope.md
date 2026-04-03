# v1 Scope

## Summary

The first public implementation target for this repository is a scene-free GDScript core that mirrors the upstream Python SDK's main concepts closely enough for parity tracking, while deliberately narrowing the shipped feature set to the core conversation loop.

The guiding decisions for this scope cut are:

- `core chat first`
- `mirror upstream`
- Godot-native adapters are additive, not replacements for the core API

## v1 Core

### Core public API target

- `query(prompt, options)` for one-shot usage
- `ClaudeSDKClient` for interactive usage
- `ClaudeAgentOptions` as the primary configuration object

### Core client methods

- `connect`
- `query`
- `receive_messages`
- `receive_response`
- `disconnect`
- `interrupt`
- `set_permission_mode`
- `set_model`
- `get_server_info`

GDScript naming note:

- the conceptual upstream methods remain `connect` and `disconnect`
- the concrete `RefCounted` implementation uses `connect_client()` and `disconnect_client()` because Godot already reserves `connect()` and `disconnect()` on `Object`/`RefCounted` for signal wiring

### Core runtime capabilities

- Claude CLI subprocess launch
- stdout and stderr draining
- streaming control-protocol initialize flow
- typed message parsing
- configurable CLI path and working directory
- inherited host environment by default, with explicit env overrides
- forward-compatible unknown-message skipping

### Core options fields

These are the `ClaudeAgentOptions` fields that the first implementation should support intentionally and test explicitly:

- `model`
- `effort`
- `cwd`
- `cli_path`
- `env`
- `system_prompt`
- `allowed_tools`
- `disallowed_tools`
- `permission_mode`
- `max_turns`
- `resume`
- `session_id`

Core field defaults and assumptions:

- `cli_path` defaults to `claude` resolved from `PATH`
- environment inheritance is on by default
- `env` is additive and can override inherited values
- the addon must not assume the process cwd is the project root in exported builds
- CLI auth is reused from the installed Claude environment rather than reimplemented in the addon

### Core typed message model

The minimum typed message/content model for v1 is:

- `UserMessage`
- `AssistantMessage`
- `SystemMessage`
- `ResultMessage`
- `TextBlock`
- `ThinkingBlock`
- `ToolUseBlock`
- `ToolResultBlock`

`SystemMessage` is sufficient for the first release even if some upstream system subtypes remain unspecialized at first.

## v1 Later

These are the next parity slice after the core conversation loop is working and validated:

- hook callbacks and hook matcher configuration
- tool-permission callbacks and permission update/result models
- structured output via `output_format`
- `get_context_usage`
- MCP status inspection, reconnect, and toggle support
- stream-event / partial-message support
- public stderr callback plumbing
- base tool-set selection via `tools`
- system prompt preset/file variants
- external MCP server config passthrough
- signal-based adapters and optional Node wrappers

These features matter, but they should not block the initial usable SDK core.

## Deferred

These capabilities are intentionally outside the first public release:

- session listing and transcript reading
- session mutations: rename, tag, delete, fork
- SDK MCP in-process tool helpers
- file checkpointing and `rewind_files`
- task-control APIs such as `stop_task`
- broad agent-definition parity
- setting-source parity
- broad config parity for sandboxing, plugins, beta flags, budget controls, advanced thinking config, settings passthrough, `add_dirs`, `continue_conversation`, and similar advanced options
- reusable chat panel
- demo validation project

Deferred does not mean rejected. It means the feature is real, tracked, and intentionally held back so the first public release stays implementable and testable.

## Not Applicable

The following upstream concepts should not be mirrored literally in GDScript:

- Python async context-manager helpers on `ClaudeSDKClient`
- Python decorator-based SDK MCP tool registration
- Python-package bundled CLI behavior

If equivalent capabilities are added later, they should use Godot-appropriate shapes rather than Python-specific API patterns.

## Implementation Order

Phase 4 should implement the core in this order:

1. transport abstraction and Claude CLI subprocess transport
2. process lifecycle rules: env, cwd, stdout/stderr, exported-app assumptions
3. initialize handshake and control-request routing
4. typed blocks/messages and raw message parser
5. one-shot `query(prompt, options)`
6. interactive `ClaudeSDKClient` methods in the locked core set
7. tests covering transport, parser, query flow, client flow, and exported-runtime assumptions

Phase 5 should start with the `v1 later` slice in this order:

1. hooks and tool-permission callbacks
2. structured output and partial-message support
3. context-usage and MCP status controls
4. Godot adapters and Node wrappers

## Test Inventory

The implementation plan should reserve explicit coverage for:

- command building for the core option set
- subprocess startup, shutdown, and stderr draining
- initialize/control routing and string-prompt stdin lifetime
- parser coverage for the v1 message and content-block model
- one-shot query flow
- interactive client flow with `interrupt`, `set_permission_mode`, and `set_model`
- exported-desktop runtime assumptions, especially macOS headless behavior and cwd handling

## Acceptance Criteria

Phase 2 is complete when:

- the feature matrix classifies all upstream-visible capabilities into a bucket
- the core API target is explicit
- the deferred list has reasons instead of silent omissions
- the roadmap's Phase 4 order matches this document
- another implementer can start Phase 4 without deciding what "v1 parity" means
