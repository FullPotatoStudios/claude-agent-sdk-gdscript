# Changelog

All notable changes to this project will be documented in this file.

The format follows Keep a Changelog style headings and uses Semantic Versioning for addon releases.

## [Unreleased]

### Added

- read-only local session history support through `ClaudeSessions`, including session listing, metadata lookup, and transcript reading
- basic `ClaudeSessions` mutation helpers for rename, tag, delete, and mutation error reporting
- session-history and mutation convenience methods on `ClaudeClientAdapter` and `ClaudeClientNode`
- saved-session browsing, transcript restoration, resume, and basic session-management controls in `ClaudeChatPanel` and the shipped demo
- scene-free `ClaudeMcp` SDK-hosted MCP tool/server builders with runtime JSON-RPC bridging through `ClaudeAgentOptions.mcp_servers`
- richer `ClaudeAgentOptions.system_prompt` variants and upstream-style base built-in tool selection through `ClaudeAgentOptions.tools`
- disconnected `ClaudeChatPanel` controls for prompt/tool configuration, plus read-only MCP environment summary
- scene-free `ClaudeBuiltInToolCatalog` helper plus a grouped built-in tool picker in the reference panel, with advanced allow/deny passthrough preserved behind a collapsed section
- `ClaudeSessionTranscriptEntry` plus richer normalized transcript-detail reading through `ClaudeSessions.get_session_transcript()`
- transcript-detail convenience passthroughs on `ClaudeClientAdapter` and `ClaudeClientNode`
- `ClaudeForkSessionResult` plus runtime-first saved-session forking through `ClaudeSessions.fork_session()`, `ClaudeClientAdapter.fork_session()`, and `ClaudeClientNode.fork_session()`
- `ClaudeAgentDefinition` plus runtime-first agent-definition support and `setting_sources` parity through `ClaudeAgentOptions`
- transport-first advanced CLI option parity through `ClaudeAgentOptions`, including `continue_conversation`, `fallback_model`, `betas`, `permission_prompt_tool_name`, `add_dirs`, `max_budget_usd`, `thinking`, deprecated `max_thinking_tokens`, and `task_budget`
- transport-first `settings` and `sandbox` parity through `ClaudeAgentOptions`, including upstream-style `--settings` pass-through and sandbox merge behavior
- transport-first diagnostics parity through `ClaudeAgentOptions.extra_args` and best-effort `ClaudeAgentOptions.stderr` callback delivery
- transport-first local-plugin and `fork_session` option parity through `ClaudeAgentOptions.plugins` and `ClaudeAgentOptions.fork_session`

### Changed

- `ClaudeChatPanel` now uses a conversation-first `Chat` view with a separate `Settings` view, quick chat controls, transcript granularity toggles, de-duplicated result rendering, and richer saved/live transcript detail handling
- session-history docs and parity tracking now reflect explicit saved-session branching support
- initialize and transport parity now cover agent definitions via initialize payloads and `--setting-sources` passthrough without adding panel-specific agent UI
- transport parity now covers the current advanced CLI option slice while keeping those fields out of initialize payloads and preserving the existing `can_use_tool` auto-`stdio` path
- transport parity now covers `settings` and `sandbox` with upstream-style `--settings` merging while keeping those fields out of initialize payloads
- transport parity now also covers ordered `extra_args` passthrough and best-effort stderr callback diagnostics without widening the initialize payload surface
- transport parity now also covers ordered local `--plugin-dir` emission and `--fork-session` flag support without widening the initialize payload surface

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
