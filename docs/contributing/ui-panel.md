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
- you want disconnected chat-configuration editing for system prompts, built-in tools, tool allow/deny lists, and rewind support
- you want connected-session context-usage inspection and MCP server health controls in the same reference panel
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
- the `Settings` view keeps disconnected-only option editing separate from connected-only live diagnostics for context usage and MCP server status

## Current scope

The shipped panel currently includes:

- auth/status header
- top-level `Chat` and `Settings` views, with `Chat` as the default
- quick chat-view controls for model, reasoning effort, and permission mode
- a resizable session browser pane scoped to the configured project path
- saved transcript loading and read-only browsing while disconnected
- reconnect/resume into selected saved sessions
- reconnect/resume handoff for selected saved sessions while keeping the active live session authoritative until disconnect
- basic rename, tag, clear-tag, delete, and full-session fork controls for saved sessions
- connected-idle live-session full-session fork handoff through the same fork controls when the active runtime session has a resolved session UUID
- disconnected saved-session `Fork from here` actions on user/assistant chat bubbles plus saved transcript detail cards backed by runtime `up_to_message_id` support
- connect/disconnect controls
- disconnected composer-driven connect-and-send flow, including selected saved-session resume targets
- transcript rendering for user, assistant, system, tool, thinking, stream, and result output
- transcript granularity toggles for `Thinking`, `Tasks`, `Tools`, `Results`, `System`, and `Raw`
- live task cards for typed `task_started`, `task_progress`, and `task_notification` messages, including per-task `stop_task(task_id)` controls while a task is active
- rate-limit warning cards for typed `rate_limit_event` messages through the existing `System` transcript path
- interrupt support during active turns
- live model and permission-mode changes while connected
- reconnect-only effort changes, exposed in the chat view but disabled while connected
- connected-only live context-usage inspection with manual refresh plus automatic refresh after connect and turn results
- connected-only MCP server status cards with reconnect and enable/disable controls in the separate `Settings` view
- typed runtime live-diagnostics models underneath those cards via `ClaudeContextUsageResponse` and `ClaudeMcpStatusResponse`
- disconnected-only system prompt, built-in tool, advanced allow/deny, rewind-support, and bounded MCP configuration editing in the separate `Settings` view
- disconnected-only editing for simple external dictionary-backed `stdio` MCP servers, with add/remove rows plus name/command/args controls
- read-only MCP inventory cards for SDK-hosted servers, raw passthrough `mcp_servers` config, and external non-`stdio` server configs that the panel does not rewrite
- per-user rewind actions in the transcript when the active session has rewindable user-message UUIDs available

Live transcript detail uses the same normalized transcript model as saved-session restoration:

- user and assistant text stay visible as the primary chat surface
- task cards stay grouped under the `Tasks` toggle, and saved-session `progress` entries reuse that same toggle when restored offline
- tool-use and tool-result entries stay grouped under the `Tools` toggle, including tool blocks carried inside top-level live `user` messages
- raw inspection stays hidden by default and is only shown through the `Raw` toggle
- saved-session transcript loading uses the richer `ClaudeSessions.get_session_transcript()` detail model under the same filter toggles
- saved-session forking uses the existing runtime `fork_session()` helper, supports an optional title override, auto-selects the new fork, and restores its transcript immediately
- connected-idle live-session forking uses a disconnect-and-handoff flow backed by the same runtime `fork_session()` helper, sources the authoritative runtime session UUID, and leaves the new fork selected offline instead of pretending the live runtime branched in place
- saved-session user/assistant chat bubbles plus thinking/tool/system/progress/attachment detail cards branch from the clicked transcript UUID inclusively and reuse the same fork-title input as the selected-session card
- progress-card cutoffs stop at that point, but the forked session still omits historical `progress` entries because the runtime fork writer preserves only the visible retained message chain
- the rewind toggle is panel-owned: it enables file checkpointing and adds `replay-user-messages` so user transcript entries can expose rewind actions without hand-editing `extra_args`

The panel intentionally does not yet include:

- richer task dashboards beyond the current per-task transcript cards and stop control
- shipped editor-plugin wiring inside the addon payload

The lower runtime still rejects same-session overlap so one live conversation
does not race itself inside the shared panel state, but the shipped panel now
surfaces different-session overlap directly:

- one connected panel can keep multiple live sessions active at once
- selecting a saved or live session swaps the transcript/composer immediately
- `New chat` while connected selects a fresh live draft session instead of
  disconnecting
- background messages, results, task cards, and draft-to-resolved-session
  promotion are tracked per session without overwriting the selected transcript
- composer send/edit enablement is scoped to the selected session's busy state,
  while `Interrupt` remains connection-global and stays available when any live
  session is busy

For a development-only editor-dock starting point that keeps `plugin.cfg` out
of the distributable addon payload, see
`tools/examples/editor_plugin_demo/README.md`.

The built-in tool picker only covers Claude's built-in tools. SDK/external MCP
tools still stay code-driven through `ClaudeMcp` and `ClaudeAgentOptions`.
The panel can edit simple external `stdio` config and inspect existing
SDK-hosted tool inventory, but it does not author tool handlers or schemas.
