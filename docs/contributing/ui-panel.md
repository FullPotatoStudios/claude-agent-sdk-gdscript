# Chat Panel Guide

`ClaudeChatPanel` is the addon's reusable reference UI for the SDK.

It lives at:

- `res://addons/claude_agent_sdk/ui/claude_chat_panel.tscn`

The panel owns one internal `ClaudeClientNode`. It does not currently support external client injection.

## When to use it

Use `ClaudeChatPanel` when:

- you want a ready-made Claude chat surface in a Godot project
- you want auth-state, saved-session browsing, connect/disconnect controls, transcript rendering, and a composer without building UI glue first
- you want quick model, effort, and permission controls in the main chat workflow
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
- the disconnected composer now doubles as a connect-and-send shortcut: submitting text while logged in and disconnected calls the internal `connect_client(prompt)` path
- if a saved session is selected while disconnected, the same composer shortcut resumes that session and still sends the first user payload through the normal string prompt-on-connect path
- prompt submission is only disabled while connecting, while a live turn is busy, or while auth is unavailable
- the panel renders typed runtime messages and partial stream events from the internal client node
- the default transcript view is simplified chat first, with thinking/tasks/tools/system/raw detail hidden behind transcript toggles

## Current scope

The shipped panel currently includes:

- auth/status header
- top-level `Chat` and `Settings` views, with `Chat` as the default
- quick chat-view controls for model, reasoning effort, and permission mode
- a resizable session browser pane scoped to the configured project path
- saved transcript loading and read-only browsing while disconnected
- reconnect/resume into selected saved sessions
- idle-time live switching between saved sessions inside an already connected panel
- basic rename, tag, clear-tag, delete, and full-session fork controls for saved sessions
- connect/disconnect controls
- disconnected composer-driven connect-and-send flow, including selected saved-session resume targets
- transcript rendering for user, assistant, system, tool, thinking, stream, and result output
- transcript granularity toggles for `Thinking`, `Tasks`, `Tools`, `Results`, `System`, and `Raw`
- live task cards for typed `task_started`, `task_progress`, and `task_notification` messages, including per-task `stop_task(task_id)` controls while a task is active
- rate-limit warning cards for typed `rate_limit_event` messages through the existing `System` transcript path
- interrupt support during active turns
- live model and permission-mode changes while connected
- reconnect-only effort changes, exposed in the chat view but disabled while connected
- disconnected-only system prompt, built-in tool, advanced allow/deny, and MCP-summary editing in the separate `Settings` view

Live transcript detail uses the same normalized transcript model as saved-session restoration:

- user and assistant text stay visible as the primary chat surface
- task cards stay grouped under the `Tasks` toggle, and saved-session `progress` entries reuse that same toggle when restored offline
- tool-use and tool-result entries stay grouped under the `Tools` toggle, including tool blocks carried inside top-level live `user` messages
- raw inspection stays hidden by default and is only shown through the `Raw` toggle
- saved-session transcript loading uses the richer `ClaudeSessions.get_session_transcript()` detail model under the same filter toggles
- saved-session forking uses the existing runtime `fork_session()` helper, supports an optional title override, auto-selects the new fork, and restores its transcript immediately

The panel intentionally does not yet include:

- multiple simultaneous in-flight sessions inside one panel instance
- cutoff selection or transcript-entry-level fork points
- richer task dashboards beyond the current per-task transcript cards and stop control
- live-session forking UX
- SDK-hosted MCP/custom-tool authoring UX
- editor-plugin workflows

The built-in tool picker only covers Claude's built-in tools. SDK/external MCP
tools still stay code-driven through `ClaudeMcp` and `ClaudeAgentOptions`.
