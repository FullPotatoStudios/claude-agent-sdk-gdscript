# Session History

`ClaudeSessions` provides scene-free access to Claude's local session history without opening a live `ClaudeSDKClient` connection.

This Phase 10H-capable API is intended for history browsers, transcript viewers, restore-style tooling, and basic session management. It supports visible-message history access, richer normalized transcript detail, explicit session forking, and rename/tag/delete mutations.

The canonical low-level entrypoint remains `ClaudeSessions`, but the same session surface is now also exposed through:

- `ClaudeClientAdapter`
- `ClaudeClientNode`
- the shipped `ClaudeChatPanel` reference UI, including saved-session forking with an optional title override and connected-idle live-session full-session fork handoff

## Public API

```gdscript
var sessions := ClaudeSessions.list_sessions()
var session_info := ClaudeSessions.get_session_info(session_id)
var messages := ClaudeSessions.get_session_messages(session_id)
var transcript := ClaudeSessions.get_session_transcript(session_id)
var fork_result := ClaudeSessions.fork_session(session_id)
var rename_error := ClaudeSessions.rename_session(session_id, "My session title")
```

Available methods:

- `ClaudeSessions.list_sessions(directory := "", limit := 0, offset := 0, include_worktrees := true)`
- `ClaudeSessions.get_session_info(session_id: String, directory := "")`
- `ClaudeSessions.get_session_messages(session_id: String, directory := "", limit := 0, offset := 0)`
- `ClaudeSessions.get_session_transcript(session_id: String, directory := "", limit := 0, offset := 0)`
- `ClaudeSessions.fork_session(session_id: String, directory := "", up_to_message_id := "", title := "")`
- `ClaudeSessions.rename_session(session_id: String, title: String, directory := "")`
- `ClaudeSessions.tag_session(session_id: String, tag := null, directory := "")`
- `ClaudeSessions.delete_session(session_id: String, directory := "")`
- `ClaudeSessions.get_last_error()`

Return types:

- `list_sessions()` returns `Array[ClaudeSessionInfo]`
- `get_session_info()` returns `ClaudeSessionInfo` or `null`
- `get_session_messages()` returns `Array[ClaudeSessionMessage]`
- `get_session_transcript()` returns `Array[ClaudeSessionTranscriptEntry]`
- `fork_session()` returns `ClaudeForkSessionResult` or `null`
- mutation methods return Godot `Error` codes and populate `ClaudeSessions.get_last_error()` on failure

## Directory semantics

The optional `directory` argument is the original project path that Claude used when creating the session, not a path under `~/.claude/projects/`.

Accepted forms:

- absolute filesystem paths
- `res://` paths resolved against the running Godot project
- `user://` paths resolved against the current Godot user data directory

Not supported in Phase 10G:

- plain relative filesystem paths

When `directory == ""`, the lookup is unscoped and searches across all stored projects.

## Local storage resolution

Session history is read from Claude's local config directory:

- `CLAUDE_CONFIG_DIR` if it is set
- otherwise `~/.claude`

Project sessions are expected under:

- `projects/`

`ClaudeSessions` mirrors the upstream Python SDK's session-directory lookup and worktree behavior closely enough for parity work:

- project paths are canonicalized before sanitization
- non-alphanumeric characters are sanitized to `-`
- long paths use a truncated prefix plus a hash suffix
- missing exact long-path directories fall back to prefix matching
- git worktrees are included when project-scoped listing is requested and `include_worktrees` is left enabled
- scoped rename, tag, and delete mutations use the same primary-project plus worktree lookup behavior
- scoped forking uses the same primary-project plus worktree lookup behavior as the other local mutation helpers

If `git` is unavailable or worktree discovery fails, lookup falls back to the primary project path.

## What the API returns

`ClaudeSessionInfo` contains lightweight session metadata:

- `session_id`
- `summary`
- `last_modified`
- nullable optional fields such as `custom_title`, `first_prompt`, `git_branch`, `cwd`, `tag`, `created_at`, and `file_size`

`ClaudeSessionMessage` contains visible top-level transcript messages:

- `type` is `"user"` or `"assistant"`
- `uuid`
- `session_id`
- `message` holds the raw historical payload
- `parent_tool_use_id` is currently `null`

Transcript reading reconstructs the main visible conversation chain and skips sidechain, meta, and team-only entries.

`ClaudeSessionTranscriptEntry` contains richer normalized transcript detail for custom transcript UIs:

- `kind` can be `user`, `assistant`, `thinking`, `tool_use`, `tool_result`, `system`, `progress`, `attachment`, or `result`
- `title` and `text` provide best-effort readable labels/content for UI use
- `payload` preserves the normalized underlying block/message payload for custom consumers
- `raw_data` preserves the original historical entry dictionary
- `parent_tool_use_id` is included when it exists in the underlying history

`get_session_messages()` remains the compatibility API for visible top-level user/assistant messages. `get_session_transcript()` is the richer API for UIs that want the same thinking/tool/system granularity used by the shipped panel.

Panel-specific note:

- `ClaudeChatPanel` now exposes saved-session and connected-idle live-session full-session forking through the selected-session card
- `ClaudeChatPanel` also exposes disconnected saved-session `Fork from here` actions on user/assistant chat bubbles plus thinking/tool/system/progress/attachment detail cards that pass the clicked transcript UUID through `up_to_message_id`
- progress-card cutoffs still omit historical `progress` entries in the written fork, matching the existing runtime mutation semantics

Basic mutation behavior:

- `fork_session()` creates a new session file with a fresh session UUID and remapped message UUIDs
- `fork_session()` can optionally stop at `up_to_message_id` inclusive and apply an explicit fork title
- forked entries preserve the visible parent chain while skipping historical `progress` entries in the written output
- forked entries include `forkedFrom = { "sessionId": <source>, "messageUuid": <original> }`
- forked sessions preserve `content-replacement` metadata and append a `custom-title` entry for the fork title
- `rename_session()` appends a `custom-title` JSONL entry and the latest title wins in `list_sessions()` / `get_session_info()`
- `tag_session()` appends a `tag` JSONL entry; passing `null` clears the tag by appending an empty-string tag entry
- `delete_session()` hard-deletes the session `.jsonl` file
- missing sessions return `ERR_DOES_NOT_EXIST`
- invalid UUIDs and empty title/tag inputs return `ERR_INVALID_PARAMETER`
- tag sanitization now uses generated upstream-derived single-codepoint NFKC compatibility rewrites plus iterative stripping of format/private-use/unassigned codepoint ranges; full multi-codepoint Unicode normalization/composition still remains narrower than upstream Python's `unicodedata` pipeline

## Example

```gdscript
var history := ClaudeSessions.list_sessions("res://", 10)

for session in history:
	print(session.summary, " (", session.session_id, ")")

if not history.is_empty():
	var session_id := history[0].session_id
	var transcript := ClaudeSessions.get_session_messages(session_id, "res://")
	for entry in transcript:
		print(entry.type, ": ", JSON.stringify(entry.message))

	var detail := ClaudeSessions.get_session_transcript(session_id, "res://")
	for entry in detail:
		print(entry.kind, ": ", entry.title)

	var fork_result := ClaudeSessions.fork_session(session_id, "res://", "", "Branch A")
	if fork_result != null:
		print("Forked to ", fork_result.session_id)

	var rename_error := ClaudeSessions.rename_session(session_id, "Review notes", "res://")
	if rename_error != OK:
		push_error(ClaudeSessions.get_last_error())
```

## Current scope

Phase 10H delivered explicit session forking, and later slices also delivered the broader settings and agent-definition parity that used to be deferred here. Use the parity docs for the current status of active session and upstream parity follow-ups:

- `docs/parity/feature-matrix.md`
- `docs/parity/upstream-ledger.md`
