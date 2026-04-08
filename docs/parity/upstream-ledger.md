# Upstream Ledger

## Current baseline

- Upstream repository: `https://github.com/anthropics/claude-agent-sdk-python`
- Local reference checkout: a sibling checkout of the upstream repo, if available
- Version: `v0.1.54`
- Commit: `574044a1fcbaf89afc821bb742ccd8d31c4d6944`
- Reviewed on: `2026-04-02`
- Local project phase at pin time: preliminary work / Phase 1 feasibility

## Initial parity cut

- Parity cut reviewed on: `2026-04-03`
- Local project phase: Phase 2 upstream mapping and v1 scope
- Core scope direction:
  - `core chat first`
  - `mirror upstream`
- Canonical Phase 2 docs:
  - `docs/parity/feature-matrix.md`
  - `docs/parity/v1-scope.md`
  - `docs/roadmap/roadmap.md`

This parity cut classifies the current upstream SDK surface into:

- `v1 core`
- `v1 later`
- `deferred`
- `not applicable`

The first public implementation target is the scene-free core conversation loop, not full upstream breadth.

## Local release baseline

- Local addon version: `0.1.0`
- Release channels:
  - GitHub Release ZIP
  - Godot Asset Library via custom download provider pointing at that ZIP
- Release-prep reviewed on: `2026-04-04`
- Compatibility/support claim:
  - Godot `4.6`
  - desktop/editor workflows supported
  - exported macOS support limited to currently validated unsandboxed scenarios
- Deferred beyond release prep:
  - custom tool hosting
  - deeper upstream parity slices beyond the current runtime/UI surface

## Post-v1 parity progress

- Active roadmap slice: Phase 10S typed rate-limit event parity
- Delivered after `0.1.0`:
  - `ClaudeSessions.list_sessions()`
  - `ClaudeSessions.get_session_info()`
  - `ClaudeSessions.get_session_messages()`
  - `ClaudeSessions.get_session_transcript()`
  - typed read-only history models `ClaudeSessionInfo` and `ClaudeSessionMessage`
  - typed transcript-detail history model `ClaudeSessionTranscriptEntry`
  - `ClaudeSessions.rename_session()`
  - `ClaudeSessions.tag_session()`
  - `ClaudeSessions.delete_session()`
  - `ClaudeSessions.fork_session()`
  - `ClaudeSessions.get_last_error()` for mutation failures
  - `ClaudeAgentDefinition`
  - `ClaudeAgentOptions.agents`
  - `ClaudeAgentOptions.setting_sources`
  - `ClaudeClientAdapter` session-history and mutation convenience methods
  - `ClaudeClientNode` session-history and mutation convenience methods
  - `ClaudeChatPanel` session browser, transcript restoration, saved-session resume, and basic session-management controls
  - `ClaudeMcp` scene-free SDK MCP builders and typed runtime MCP models
  - mixed external plus SDK-hosted `ClaudeAgentOptions.mcp_servers` handling
  - `ClaudeQuerySession` runtime JSON-RPC bridging for SDK-hosted MCP `initialize`, `notifications/initialized`, `tools/list`, and `tools/call`
  - richer `ClaudeAgentOptions.system_prompt` variants: plain string, `claude_code` preset, preset+append, and file-backed prompts
  - upstream-style base built-in tool selection through `ClaudeAgentOptions.tools`
  - `ClaudeChatPanel` disconnected prompt/tool configuration controls plus MCP environment summary
  - `ClaudeChatPanel` conversation-first `Chat` / `Settings` split with quick chat controls and secondary prompt/tool configuration
  - `ClaudeChatPanel` transcript granularity controls for thinking, tools, results, system, and raw detail
  - richer saved-session transcript restoration using normalized thinking/tool/system/result detail
  - runtime-first session forking helpers with adapter/node passthroughs, UUID remapping, cutoff support, and preserved `content-replacement` / title metadata
  - runtime-first agent-definition parity through initialize-payload serialization and `setting_sources` CLI passthrough
  - transport-first advanced CLI option parity for `continue_conversation`, `fallback_model`, `betas`, `permission_prompt_tool_name`, `add_dirs`, `max_budget_usd`, `thinking`, deprecated `max_thinking_tokens`, and `task_budget`
  - transport-first `settings` and `sandbox` parity through `ClaudeAgentOptions`, including upstream-style `--settings` pass-through and sandbox merge behavior
  - transport-first diagnostics parity through `ClaudeAgentOptions.extra_args` and best-effort `ClaudeAgentOptions.stderr` callback delivery
  - transport-first plugin-dir parity through `ClaudeAgentOptions.plugins` with local `--plugin-dir` emission
  - transport-first `fork_session` option parity through `ClaudeAgentOptions.fork_session` and `--fork-session`
  - transport-first file checkpointing parity through `ClaudeAgentOptions.enable_file_checkpointing` and `CLAUDE_CODE_ENABLE_SDK_FILE_CHECKPOINTING=true`
  - connected-session `rewind_files(user_message_id)` parity through `ClaudeQuerySession`, `ClaudeSDKClient`, `ClaudeClientAdapter`, and `ClaudeClientNode`
  - command-style `stop_task(task_id)` parity through `ClaudeQuerySession`, `ClaudeSDKClient`, `ClaudeClientAdapter`, and `ClaudeClientNode`
  - typed task system message parity through `ClaudeTaskStartedMessage`, `ClaudeTaskProgressMessage`, and `ClaudeTaskNotificationMessage`
  - transport-first process-user launch parity through `ClaudeAgentOptions.user` on POSIX shell-backed transports
  - `ClaudeChatPanel` task-aware transcript controls with per-task stop actions and saved-session `progress` routing
  - `ClaudeChatPanel` saved-session forking UI backed by the existing runtime `fork_session()` helpers
  - typed `ClaudeRateLimitInfo` and `ClaudeRateLimitEvent` parsing for top-level `rate_limit_event` messages
  - `ClaudeChatPanel` rendering for rate-limit events through the existing `System` transcript path
- Known GDScript/runtime difference:
  - upstream Python SDK can catch tool-handler exceptions inside its MCP server runtime
  - local GDScript MCP tool handlers should report tool-level failures with `is_error = true`; uncaught script runtime faults still surface as Godot errors
  - upstream `user=` process launch is modeled in local Godot runtime via a POSIX `sudo -n -u` shell-wrapper path; Windows shell-backed transports still reject `ClaudeAgentOptions.user`

## Update process

For each future upstream sync review:

1. Record the new version and commit here.
2. Diff from the previously recorded commit, not from `main`.
3. Review changes in:
   - `src/claude_agent_sdk/`
   - `examples/`
   - `tests/`
   - `e2e-tests/`
4. Update `docs/parity/feature-matrix.md`.
5. Update `docs/parity/v1-scope.md` if the parity cut or implementation order changes.
6. Update ADRs or roadmap docs if upstream changes alter assumptions.
7. Record the local addon version and release date if the sync is shipped publicly.
8. Update `docs/release/release-process.md` and the changelog if the sync changes the support claim or release notes.
