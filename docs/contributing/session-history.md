# Session History

`ClaudeSessions` provides read-only access to Claude's local session history without opening a live `ClaudeSDKClient` connection.

This Phase 10A API is intended for history browsers, transcript viewers, and restore-style tooling. It does not add session mutation helpers such as rename, tag, delete, or fork.

## Public API

```gdscript
var sessions := ClaudeSessions.list_sessions()
var session_info := ClaudeSessions.get_session_info(session_id)
var messages := ClaudeSessions.get_session_messages(session_id)
```

Available methods:

- `ClaudeSessions.list_sessions(directory := "", limit := 0, offset := 0, include_worktrees := true)`
- `ClaudeSessions.get_session_info(session_id: String, directory := "")`
- `ClaudeSessions.get_session_messages(session_id: String, directory := "", limit := 0, offset := 0)`

Return types:

- `list_sessions()` returns `Array[ClaudeSessionInfo]`
- `get_session_info()` returns `ClaudeSessionInfo` or `null`
- `get_session_messages()` returns `Array[ClaudeSessionMessage]`

## Directory semantics

The optional `directory` argument is the original project path that Claude used when creating the session, not a path under `~/.claude/projects/`.

Accepted forms:

- absolute filesystem paths
- `res://` paths resolved against the running Godot project
- `user://` paths resolved against the current Godot user data directory

Not supported in Phase 10A:

- plain relative filesystem paths

When `directory == ""`, the lookup is unscoped and searches across all stored projects.

## Local storage resolution

Session history is read from Claude's local config directory:

- `CLAUDE_CONFIG_DIR` if it is set
- otherwise `~/.claude`

Project sessions are expected under:

- `projects/`

`ClaudeSessions` mirrors the upstream Python SDK's project-directory resolution rules closely enough for parity work:

- project paths are canonicalized before sanitization
- non-alphanumeric characters are sanitized to `-`
- long paths use a truncated prefix plus a hash suffix
- missing exact long-path directories fall back to prefix matching
- git worktrees are included when project-scoped listing is requested and `include_worktrees` is left enabled

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
- `parent_tool_use_id` is currently `null` in Phase 10A

Transcript reading reconstructs the main visible conversation chain and skips sidechain, meta, and team-only entries.

## Example

```gdscript
var history := ClaudeSessions.list_sessions("res://", 10)

for session in history:
	print(session.summary, " (", session.session_id, ")")

if not history.is_empty():
	var transcript := ClaudeSessions.get_session_messages(history[0].session_id, "res://")
	for entry in transcript:
		print(entry.type, ": ", JSON.stringify(entry.message))
```

## Current scope

Phase 10A is intentionally read-only. Use the parity docs for the current status of broader session and upstream parity work:

- `docs/parity/feature-matrix.md`
- `docs/parity/upstream-ledger.md`
