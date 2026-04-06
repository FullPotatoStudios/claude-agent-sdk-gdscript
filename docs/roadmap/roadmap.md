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
- future session forking helpers
- future custom-tool / broader parity slices tracked against the upstream ledger

Active slice:
- Phase 10G: transcript-detail parity and panel transcript controls

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

Still deferred within Phase 10:
- session forking helpers
- broader settings and agent-definition parity

## Current focus

Work should currently prioritize Phase 10G.
