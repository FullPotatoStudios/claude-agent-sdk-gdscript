# Sessions

Session history support belongs here.

This layer is scene-free and independent from live `ClaudeSDKClient` sessions.

Public scene-free surface for Phase 10C:

- `ClaudeSessions`
- `ClaudeSessionInfo`
- `ClaudeSessionMessage`

The implementation reads Claude's local session storage under `CLAUDE_CONFIG_DIR`
or `~/.claude` and mirrors the upstream Python SDK's session helpers in
a Godot-native static utility shape.

Higher layers now reuse this runtime surface through:

- `ClaudeClientAdapter`
- `ClaudeClientNode`
- `ClaudeChatPanel`
