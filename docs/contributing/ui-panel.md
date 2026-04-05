# Chat Panel Guide

`ClaudeChatPanel` is the addon's reusable reference UI for the SDK.

It lives at:

- `res://addons/claude_agent_sdk/ui/claude_chat_panel.tscn`

The panel owns one internal `ClaudeClientNode`. In Phase 7 it does not support external client injection.

## When to use it

Use `ClaudeChatPanel` when:

- you want a ready-made Claude chat surface in a Godot project
- you want auth-state, saved-session browsing, connect/disconnect controls, transcript rendering, and a composer without building UI glue first
- you want disconnected chat-configuration editing for system prompts, built-in tools, and tool allow/deny lists
- you want a resizable two-pane layout with a saved-session browser on the left and chat on the right
- you want a reference for building your own UI on top of `ClaudeClientAdapter` or `ClaudeClientNode`

Use the lower layers instead when:

- you want a very custom UX
- you want to own scene layout, transcript rendering, or message presentation yourself
- you do not want the panel to own the client lifecycle

## Basic usage

Instantiate the scene and optionally call `setup()` before the panel connects:

```gdscript
var panel: ClaudeChatPanel = preload("res://addons/claude_agent_sdk/ui/claude_chat_panel.tscn").instantiate()
panel.setup(ClaudeAgentOptions.new({
	"model": "haiku",
	"effort": "low",
}))
add_child(panel)
```

`setup(options, transport)` is intended for:

- pre-tree option configuration
- tests
- custom transport injection during development

`setup()` must be called before the first successful `connect_client()`.

## Public panel API

Signals:

- `auth_status_changed(status)`
- `prompt_submitted(prompt)`
- `message_received(message)`
- `turn_finished(result_message)`
- `error_occurred(message)`

Methods:

- `connect_client()`
- `disconnect_client()`
- `submit_prompt(prompt)`
- `refresh_auth_status()`
- `clear_transcript()`
- `get_client_node()`

## Default lifecycle

- auth status is probed on `_ready()`
- connection is manual
- prompt submission is disabled until connected
- the panel renders typed runtime messages and partial stream events from the internal client node

## Current scope

The shipped panel currently includes:

- auth/status header
- top-level `Chat` and `Settings` views, with `Chat` as the default
- a compact read-only chat-view configuration summary
- a resizable session browser pane scoped to the configured project path
- saved transcript loading and read-only browsing while disconnected
- reconnect/resume into selected saved sessions
- idle-time live switching between saved sessions inside an already connected panel
- basic rename, tag, clear-tag, and delete controls for saved sessions
- connect/disconnect controls
- transcript rendering for user, assistant, system, tool, thinking, stream, and result output
- interrupt support during active turns
- disconnected-only settings for model, permission mode, system prompt, built-in tools, advanced allow/deny rules, and MCP summary in the separate `Settings` view

The panel intentionally does not yet include:

- multiple simultaneous in-flight sessions inside one panel instance
- session forking
- task-specific UI beyond the generic typed messages
- SDK-hosted MCP/custom-tool authoring UX
- editor-plugin workflows

The built-in tool picker only covers Claude's built-in tools. SDK/external MCP
tools still stay code-driven through `ClaudeMcp` and `ClaudeAgentOptions`.
