# Sessions

Read-only session history support belongs here.

This layer is scene-free and independent from live `ClaudeSDKClient` sessions.

Public surface for Phase 10A:

- `ClaudeSessions`
- `ClaudeSessionInfo`
- `ClaudeSessionMessage`

The implementation reads Claude's local session storage under `CLAUDE_CONFIG_DIR`
or `~/.claude` and mirrors the upstream Python SDK's read-only session helpers in
a Godot-native static utility shape.
