# Integration Guide

The addon now exposes three layers for integrating Claude into Godot projects:

- `ClaudeQuery` for one-shot string prompts where you are happy to `await` a `ClaudeMessageStream`
- `ClaudeSDKClient` for scene-free interactive control over a long-lived Claude session
- `ClaudeClientAdapter` and `ClaudeClientNode` for Godot-native signal-driven integration
- `ClaudeChatPanel` for a ready-to-drop-in reference UI built on the Node layer

## Which layer to use

Use `ClaudeSDKClient` directly when:

- you want the closest surface to the upstream Python SDK
- your own code is already comfortable working with `await`
- you want to keep your integration scene-free and fully under your own control
- you want to attach SDK-hosted MCP tools through `ClaudeMcp` and `ClaudeAgentOptions.mcp_servers`
- you want to build your own built-in tool picker or configuration UI on top of `ClaudeBuiltInToolCatalog`

SDK-hosted MCP tool handlers should report tool-level failures by returning a
normal result dictionary with `is_error = true`. Unlike the upstream Python
SDK runtime, the GDScript bridge cannot safely trap arbitrary runtime faults
inside a `Callable`; uncaught script errors still surface as normal Godot
errors.

Use `ClaudeClientAdapter` when:

- you want Godot signals without introducing a `Node`
- you want a thin wrapper that drains the session-wide message stream for you
- you are building your own game/tool state around typed runtime messages
- you want adapter-level convenience access to session history and basic session mutations without calling `ClaudeSessions` directly

Use `ClaudeClientNode` when:

- you want scene-tree lifecycle hooks such as `_ready()` and `_exit_tree()`
- you want signal-based integration from a scene script with minimal glue code
- you want optional `auto_connect_on_ready` and `auto_disconnect_on_exit`
- you want the same session-history and basic session-mutation convenience methods from a `Node`

Use `ClaudeChatPanel` when:

- you want a working Claude chat UI with auth-state, saved-session browsing, connect controls, transcript rendering, disconnected prompt/tool configuration editing, and a composer immediately
- you want a reference implementation for custom UI work
- you are happy with the panel owning its own internal `ClaudeClientNode`

Because `Object` already defines `is_connected(signal_name, callable)`, the Godot-facing adapter layer uses `is_client_connected()` rather than `is_connected()`.

## Signal-driven flow

`ClaudeClientAdapter` and `ClaudeClientNode` expose the same signals:

- `session_ready(server_info)`
- `turn_started(prompt, session_id)`
- `message_received(message)`
- `turn_message_received(message)`
- `turn_finished(result_message)`
- `busy_changed(is_busy)`
- `error_occurred(message)`
- `session_closed()`

The adapter owns one background drain of `ClaudeSDKClient.receive_messages()`.

- `message_received` is the continuous session-wide stream
- `turn_message_received` only covers the currently active turn
- `turn_finished` fires on the first `ClaudeResultMessage` for that turn

## Scope and limits

The integration layer is intentionally thin.

- It does not replace the scene-free runtime
- It does not add transcript/history caches
- It does not add task-specific fanout signals
- It does not add custom-tool or SDK-hosted MCP abstractions
- It does not replace the reusable chat panel for users who want a drop-in UI
- It does not replace `ClaudeSessions` as the canonical scene-free session-history surface
- SDK-hosted MCP tool/server helpers live in the scene-free runtime through `ClaudeMcp`, not in the adapter layer
- richer `system_prompt` modes and base built-in tool selection live in `ClaudeAgentOptions` and flow through every layer, including the panel
- `ClaudeBuiltInToolCatalog` is the shared runtime source of truth for built-in Claude Code tool metadata used by the reference panel and available to custom panels

For panel-specific setup and usage guidance, see `docs/contributing/ui-panel.md`.
