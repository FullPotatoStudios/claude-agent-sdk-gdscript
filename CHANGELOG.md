# Changelog

All notable changes to this project will be documented in this file.

The format follows Keep a Changelog style headings and uses Semantic Versioning for addon releases.

## [Unreleased]

## [0.2.0] - 2026-04-11

### Added

- scene-free local session history support through `ClaudeSessions`, including session listing, metadata lookup, normalized transcript reading, rename/tag/delete mutation helpers, and runtime-first session forking
- session-history, transcript-detail, and mutation convenience methods on `ClaudeClientAdapter` and `ClaudeClientNode`
- richer upstream parity across `ClaudeAgentOptions`, including `agents`, `setting_sources`, `continue_conversation`, `fallback_model`, `betas`, `permission_prompt_tool_name`, `add_dirs`, `max_budget_usd`, `thinking`, deprecated `max_thinking_tokens`, `task_budget`, `settings`, `sandbox`, `extra_args`, `stderr`, `plugins`, `fork_session`, `enable_file_checkpointing`, and POSIX `user`
- scene-free SDK-hosted MCP builders, typed MCP/context diagnostics models, typed task and rate-limit message models, `ClaudePromptStream`, and runtime `rewind_files()` / `stop_task()` controls
- expanded authenticated live validation covering bounded post-v1 parity slices such as agents, settings sources, hooks, tool permissions, same-user `user`, dynamic controls, plugin discovery, resumed-session forking, and external MCP reconnect
- runnable advanced examples under `tools/examples/` for agents, settings sources, plugins, stderr capture, hooks, budgets, tool permissions, partial messages, and SDK MCP tooling

### Changed

- `ClaudeChatPanel` now ships a fuller reference UI with conversation-first chat/settings views, session browsing, transcript restoration, saved-session forking, live context/MCP diagnostics, disconnected MCP authoring for simple external `stdio` entries, and bounded task controls
- the shipped panel now supports multiple simultaneous live sessions started within the current connection, fixes unlabeled assistant-message routing across session switches, and keeps older saved sessions on a truthful disconnect-and-resume handoff path
- transport/runtime parity now includes upstream-style CLI discovery fallback, stricter malformed-known-message handling, initialize timeout handling, shutdown grace after stdin EOF, and whole-string Unicode session-tag sanitization parity

### Known limitations

- Godot support target remains `4.6`
- the addon still depends on a user-installed `claude` CLI and reuses the caller's existing Claude auth
- mobile, web, and App Store-sandboxed macOS workflows remain out of scope
- `ClaudeAgentOptions.user` remains unsupported on Windows shell-backed transports
- the shipped panel only overlaps sessions that were started in the current live connection; older saved sessions still resume through disconnect-and-handoff

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
