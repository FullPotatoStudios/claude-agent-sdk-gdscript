# Changelog

All notable changes to this project will be documented in this file.

The format follows Keep a Changelog style headings and uses Semantic Versioning for addon releases.

## [Unreleased]

### Added

- read-only local session history support through `ClaudeSessions`, including session listing, metadata lookup, and transcript reading
- basic `ClaudeSessions` mutation helpers for rename, tag, delete, and mutation error reporting
- session-history and mutation convenience methods on `ClaudeClientAdapter` and `ClaudeClientNode`
- saved-session browsing, transcript restoration, resume, and basic session-management controls in `ClaudeChatPanel` and the shipped demo

## [0.1.0] - 2026-04-04

### Added

- scene-free Claude SDK runtime with subprocess transport, control protocol, typed messages, and one-shot plus interactive APIs
- hook callbacks, permission callbacks, structured output, partial-message support, and auth diagnostics
- Godot-native adapter and node wrappers
- reusable `ClaudeChatPanel` and root-project demo scene
- release packaging, consumer validation, and upstream parity-maintenance tooling

### Changed

- session readiness now follows initialize control-response success instead of requiring a streamed `system/init` message
- release metadata now comes from `addons/claude_agent_sdk/VERSION`

### Known limitations

- Godot support target is `4.6` only
- the addon depends on a user-installed `claude` CLI and reuses its existing auth
- exported macOS support is limited to unsandboxed desktop scenarios validated so far
