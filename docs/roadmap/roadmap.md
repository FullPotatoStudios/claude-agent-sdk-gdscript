# Roadmap

## Goal

Port the Claude Agent SDK from Python to GDScript as a Godot addon, while adapting the public integration surface to Godot-native patterns.

## Guiding decisions

- The core SDK should be scene-free and not depend on `Node` lifecycle.
- Godot-native adapters may expose signals and optional Node wrappers.
- The addon payload should stay self-contained under `addons/claude_agent_sdk/`.
- Demo content under `demo/` should validate the addon, but should not be required to consume it.
- The Python SDK is tracked as an upstream reference, not a runtime dependency.

## Phases

### Phase 1: Feasibility gate

Goal:
- prove that Godot can run and communicate with the Claude CLI in a way that supports streaming control-protocol behavior

Outputs:
- subprocess feasibility notes
- platform/export support assumptions
- initial CLI provisioning recommendation
- decision on whether to proceed with the current transport approach

### Phase 2: Upstream mapping and v1 scope

Goal:
- map the Python SDK into a realistic GDScript v1 scope

Outputs:
- detailed feature matrix grouped by subsystem
- explicit v1 scope cut
- identified deferred items with reasons
- implementation order for the first core SDK slice

### Phase 3: Architecture and repo scaffolding

Goal:
- turn the preliminary direction into durable repo structure and design decisions

Outputs:
- ADRs
- initial addon folder structure
- top-level test layout
- documentation layout
- tooling plan for Godot 4.6 and GdUnit4

### Phase 4: Core SDK implementation

Goal:
- implement transport, protocol, types, parsing, and the initial public API

Outputs:
- transport abstraction
- Claude CLI transport spike matured into implementation
- typed message and options models
- query/client API

Implementation order:
1. transport abstraction and Claude CLI subprocess transport
2. process lifecycle rules for cwd, env, stdout, stderr, and exported builds
3. initialize handshake and control-request routing
4. typed message/content models and parser
5. `query(prompt, options)`
6. `ClaudeSDKClient` core methods:
   - `connect`
   - `query`
   - `receive_messages`
   - `receive_response`
   - `disconnect`
   - `interrupt`
   - `set_permission_mode`
   - `set_model`
   - `get_server_info`
7. test coverage for transport, parser, one-shot flow, interactive flow, and exported-runtime assumptions

### Phase 5: Secondary SDK capabilities

Goal:
- implement the highest-value parity features beyond the core conversation loop

Delivered areas:
- hooks
- permission handling
- structured output support
- context-usage queries
- MCP status/reconnect/toggle
- partial-message / `stream_event` support

Still deferred within runtime parity:
- sessions
- custom tool support, if feasible in Godot

### Phase 6: Godot integration layer

Goal:
- expose the core SDK in Godot-native ways

Outputs:
- signal-based adapters
- optional Node facade(s)
- examples for custom UI integration

Delivered:
- `ClaudeClientAdapter` as a signal-based `RefCounted` facade over `ClaudeSDKClient`
- `ClaudeClientNode` as an optional scene-tree wrapper over the adapter
- lightweight custom-integration examples and docs

### Phase 7: Reusable chat panel and demo validation

Goal:
- ship a usable reference UI and validate the addon end to end

Outputs:
- reusable chat panel scene in the addon
- root-project demo scenes and scripts under `demo/`
- documentation for using the panel and replacing it

Delivered:
- `ClaudeChatPanel` under `addons/claude_agent_sdk/ui/`
- root-project demo scene under `demo/` that uses the shipped panel directly
- panel-focused UI tests and demo-scene validation tests
- runtime smoke validation kept intact for `baseline`, `structured`, and `partial`

### Phase 8: Packaging, release, and parity maintenance

Goal:
- make the addon easy to distribute and keep aligned with upstream over time

Outputs:
- release packaging flow
- parity update checklist in active use
- upstream ledger updates per sync cycle

### Phase 9: Hooks, scripted validation, and GitHub release automation

Goal:
- make validation and release publishing automation-first while keeping repo scripts as the source of truth

Outputs:
- repo-managed git hooks
- canonical validation and release-prep wrapper scripts
- GitHub Actions CI on pull requests and `main`
- tag-driven GitHub Release publishing
- automated Asset Library metadata preparation with a manual final submission boundary

### Phase 10: Post-v1 parity expansion

Goal:
- keep extending upstream parity in small, reviewable runtime slices after the `0.1.x` release baseline is established

Outputs:
- read-only local session history support
- basic session mutation helpers
- scene-free SDK-hosted MCP tool/server helpers
- richer chat-configuration parity for prompt and built-in tool selection
- runtime-first session forking helpers
- runtime-first agent definitions and `setting_sources` parity
- transport-first advanced CLI option parity
- transport-first `settings` and `sandbox` parity
- transport-first diagnostics and escape-hatch parity
- transport-first local plugin-dir and `fork_session` option parity
- future custom-tool / broader parity slices tracked against the upstream ledger

Active slice:
- no new bounded slice selected; next parity planning should start from a fresh upstream diff review

Delivered in Phase 10A:
- `ClaudeSessions` as a scene-free static runtime utility
- `ClaudeSessionInfo` and `ClaudeSessionMessage` typed history models
- read-only session listing, metadata lookup, and transcript reading against local Claude session storage
- project-path sanitization, long-path fallback, and git-worktree-aware lookup

Delivered in Phase 10B:
- `ClaudeSessions.rename_session()`
- `ClaudeSessions.tag_session()`
- `ClaudeSessions.delete_session()`
- `ClaudeSessions.get_last_error()` for mutation failures

Delivered in Phase 10C:
- `ClaudeClientAdapter` session-history and session-mutation convenience methods
- `ClaudeClientNode` session-history and session-mutation convenience methods
- `ClaudeChatPanel` session browser, transcript restoration, saved-session resume, and basic rename/tag/delete controls
- demo copy and validation updated around session-aware reference UI

Delivered in Phase 10D:
- `ClaudeMcp` scene-free SDK MCP tool/server builders
- typed runtime MCP models `ClaudeMcpTool`, `ClaudeMcpToolAnnotations`, and `ClaudeSdkMcpServer`
- mixed external plus SDK-hosted `ClaudeAgentOptions.mcp_servers` handling
- inbound `mcp_message` control-request bridging for `initialize`, `notifications/initialized`, `tools/list`, and `tools/call`

Delivered in Phase 10E:
- richer `ClaudeAgentOptions.system_prompt` variants: plain string, `claude_code` preset, preset+append, and file-backed prompts
- upstream-style base built-in tool selection through `ClaudeAgentOptions.tools`
- subprocess command-building parity for prompt/tool flag emission
- `ClaudeChatPanel` disconnected prompt/tool configuration controls and MCP environment summary
- demo configuration updated to showcase prompt and custom-tool setup through the shipped panel

Delivered in Phase 10F:
- `ClaudeChatPanel` conversation-first `Chat` view and separate `Settings` view
- quick chat-view controls for model, effort, and permission mode
- the shipped panel documentation repositioned around reference-UI usage for custom project panels

Delivered in Phase 10G:
- `ClaudeSessionTranscriptEntry` and `ClaudeSessions.get_session_transcript()`
- `ClaudeClientAdapter.get_session_transcript()` and `ClaudeClientNode.get_session_transcript()`
- saved-session transcript restoration upgraded to normalized thinking/tool/system/result detail
- transcript filtering and de-duplication controls in `ClaudeChatPanel`
- incremental live transcript rendering and live user-side tool-result classification under the `Tools` toggle

Delivered in Phase 10H:
- `ClaudeForkSessionResult`
- `ClaudeSessions.fork_session()` with optional cutoff/title support
- `ClaudeClientAdapter.fork_session()` and `ClaudeClientNode.fork_session()`
- runtime-first saved-session branching with UUID remapping, `forkedFrom` metadata, worktree-aware lookup, and title/content-replacement preservation

Delivered in Phase 10I:
- `ClaudeAgentDefinition`
- `ClaudeAgentOptions.agents` and `ClaudeAgentOptions.setting_sources`
- initialize-payload agent serialization with upstream wire keys
- `--setting-sources` CLI parity while keeping agents initialize-only

Delivered in Phase 10J:
- transport-first advanced CLI option parity for `continue_conversation`, `fallback_model`, `betas`, `permission_prompt_tool_name`, `add_dirs`, `max_budget_usd`, `thinking`, deprecated `max_thinking_tokens`, and `task_budget`
- local conflict validation for `permission_prompt_tool_name` versus `can_use_tool` while preserving the existing auto-`stdio` callback path
- initialize/runtime boundary coverage proving these options stay CLI-only rather than entering initialize payloads

Delivered in Phase 10K:
- transport-first `ClaudeAgentOptions.settings` and `ClaudeAgentOptions.sandbox`
- upstream-style `--settings` pass-through and sandbox merge behavior, including JSON-string passthrough, file-path loading, and sandbox-only fallback on parse/load failure
- initialize/runtime boundary coverage proving `settings` and `sandbox` stay CLI-only rather than entering initialize payloads

Delivered in Phase 10L:
- transport-first `ClaudeAgentOptions.extra_args` and `ClaudeAgentOptions.stderr`
- upstream-style extra-flag passthrough ordering and best-effort per-line stderr diagnostics callback delivery
- initialize/runtime boundary coverage proving `extra_args` and `stderr` stay CLI-only rather than entering initialize payloads

Delivered in Phase 10M:
- transport-first `ClaudeAgentOptions.plugins` with local-plugin `--plugin-dir` emission
- transport-first `ClaudeAgentOptions.fork_session` with upstream-style `--fork-session` flag parity
- initialize/runtime boundary coverage proving `plugins` and `fork_session` stay CLI-only rather than entering initialize payloads

Delivered in Phase 10N:
- transport-first `ClaudeAgentOptions.enable_file_checkpointing`
- transport-side `CLAUDE_CODE_ENABLE_SDK_FILE_CHECKPOINTING=true` emission when checkpointing is enabled
- connected-session `rewind_files(user_message_id)` parity on `ClaudeQuerySession`, `ClaudeSDKClient`, `ClaudeClientAdapter`, and `ClaudeClientNode`
- initialize/runtime boundary coverage proving checkpointing stays transport-only rather than entering initialize payloads

Delivered in Phase 10O:
- command-style `stop_task(task_id)` parity on `ClaudeQuerySession`, `ClaudeSDKClient`, `ClaudeClientAdapter`, and `ClaudeClientNode`
- parser-level typed `task_started`, `task_progress`, and `task_notification` message parity while preserving generic `ClaudeSystemMessage` compatibility
- runtime/parser coverage for task-control requests and backward-compatible task system message parsing

Delivered in Phase 10P:
- transport-first `ClaudeAgentOptions.user` parity for POSIX shell-backed process launch
- shared transport/auth-probe launch coverage proving `user` stays transport-only rather than entering initialize payloads
- documented Windows caveat for the shell-backed runtime, where `ClaudeAgentOptions.user` remains unsupported

Delivered in Phase 10Q:
- `ClaudeChatPanel` task-aware transcript controls for typed `task_started`, `task_progress`, and `task_notification` messages
- per-task `stop_task(task_id)` controls in the reference panel while a task is active
- saved-session `progress` transcript routing under the same `Tasks` filter as live task cards

Delivered in Phase 10R:
- `ClaudeChatPanel` saved-session forking UI backed by the existing runtime `fork_session()` helpers
- optional fork-title override in the panel, plus post-fork auto-selection and transcript restoration
- mutation locking for saved-session fork controls while connected or connecting

Delivered in Phase 10S:
- typed `ClaudeRateLimitInfo` and `ClaudeRateLimitEvent` runtime models
- parser support for top-level `rate_limit_event` messages with normalized upstream wire keys
- reference-panel rendering for rate-limit events through the existing `System` transcript path

Delivered in Phase 10T:
- `ClaudePromptStream` as a scene-free streamed prompt input helper for outbound query payloads
- streamed prompt input parity on `ClaudeQuery.query()` and `ClaudeSDKClient.query()`, with upstream-style `session_id` handling differences between one-shot and interactive query flows
- adapter/node passthrough widening for streamed `query()` calls while keeping `turn_started(prompt, session_id)` string-only

Delivered in Phase 10U:
- `connect_client(prompt)` parity on `ClaudeSDKClient`, `ClaudeClientAdapter`, and `ClaudeClientNode`
- string connect prompts queued through the existing initialize-aware prompt path with literal `session_id = "default"`
- connect-time `ClaudePromptStream` payload preservation without session-id backfill
- explicit local lifecycle divergence documentation for repeated `connect_client()` calls, which still keep the existing no-op behavior instead of recreating the session

Delivered in Phase 10V:
- `ClaudePermissionRuleValue` and `ClaudePermissionUpdate` for typed runtime permission-update construction and serialization
- `ClaudeHookOutput` plus event-specific hook output helper classes for typed runtime hook callback responses
- additive hook-output coercion in `ClaudeQuerySession`, including Python-style `continue_` / `async_` alias handling for raw dictionaries
- additive typed suggestion exposure on `ClaudeToolPermissionContext` while preserving the existing raw `suggestions` array
- explicit local compatibility note that hook callback inputs remain dictionary-first in GDScript

Delivered in Phase 10W:
- repeated `connect_client()` calls on `ClaudeSDKClient`, `ClaudeClientAdapter`, and `ClaudeClientNode` now follow upstream reconnect semantics by closing the active session and reopening cleanly
- default transports are recreated on reconnect, while injected custom transports are reused without leaking old session drains or signal listeners
- reconnect clears stale client error state before reopening and preserves the existing prompt-on-connect wire behavior for string and `ClaudePromptStream` inputs
- `ClaudeChatPanel` now treats the disconnected composer as a connect-and-send entrypoint, including saved-session resume targets, so the reference UI showcases prompt-on-connect behavior directly
- roadmap, parity, and panel docs updated to treat reconnect parity as delivered reference-panel behavior rather than a remaining lifecycle gap

Delivered in Phase 10X:
- `ClaudeHookInput` plus event-specific hook input classes for additive typed hook callback input wrappers
- additive `ClaudeHookContext.typed_input` / `hook_input` exposure while preserving the existing raw dictionary callback signature
- `ClaudeQuerySession` typed hook-input coercion with tool-lifecycle `tool_use_id` backfill from the outer control request without mutating the raw input payload

## Current focus

The last bounded post-v1 runtime parity gap from the current docs is now delivered. The next parity planning pass should start with a fresh upstream diff review, then decide whether any new bounded runtime slice is worth taking on beyond the remaining Windows `user` caveat and intentionally deferred broader parity work.
