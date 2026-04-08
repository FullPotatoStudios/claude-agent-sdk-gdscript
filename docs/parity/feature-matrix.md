# Feature Matrix

This matrix records the upstream Python SDK surface by subsystem and assigns each capability to a delivery bucket for the GDScript addon.

Buckets:

- `v1 core`: required for the first serious implementation target
- `v1 later`: important parity work after the core conversation loop is stable
- `deferred`: intentionally outside the first public release
- `not applicable`: Python-specific or mismatched with the current Godot addon design

Phase 1 findings that constrain this matrix:

- macOS exported headless transport is partially validated
- macOS exported GUI behavior is still unproven
- auth behavior must stay separate from transport viability
- exported builds cannot assume the project root is the process working directory

## Public one-shot API

| Capability | Upstream entrypoints | Why it matters in Godot | Dependency chain | Bucket | Notes |
| --- | --- | --- | --- | --- | --- |
| One-shot `query(prompt, options)` API | `query.py`, `tests/test_query.py`, `examples/quick_start.py` | Smallest useful SDK entrypoint for scripts and simple tools | transport, parser, core options | `v1 core` | Canonical one-shot API target |
| String prompt flow | `query.py`, `tests/test_client.py`, `examples/quick_start.py` | Most common call shape for gameplay tools and editor tools | query API, parser | `v1 core` | Should map to a simple `String` prompt |
| Async/streaming prompt input for one-shot mode | `query.py`, `tests/test_query.py` | Enables parity with upstream streaming input patterns | query API, transport lifecycle | `v1 later` | Delivered post-v1 in Phase 10T through `ClaudePromptStream` support on `ClaudeQuery.query()` |
| Public custom transport injection | `query.py`, `client.py` | Helps advanced embedders and parity testing | transport abstraction | `v1 later` | Keep internal transport abstraction in v1 even if public injection waits |

## Interactive client API

| Capability | Upstream entrypoints | Why it matters in Godot | Dependency chain | Bucket | Notes |
| --- | --- | --- | --- | --- | --- |
| `ClaudeSDKClient` as the interactive core | `client.py`, `tests/test_streaming_client.py`, `examples/streaming_mode.py` | Basis for chat UIs, tools, and adapters | transport, query control, parser | `v1 core` | Canonical interactive API target |
| `connect()` | `client.py`, `tests/test_client.py` | Opens a reusable Claude session | transport, initialize flow | `v1 core` | Delivered post-v1 in Phase 10U/10W through `connect_client(prompt)` support for `null`, string, and `ClaudePromptStream` prompts plus upstream-style reconnect semantics that recreate default transports and reuse injected custom transports cleanly |
| `query()` on connected client | `client.py`, `examples/streaming_mode.py` | Sends follow-up messages in active sessions | connect, transport writes | `v1 core` | Session-aware string follow-ups shipped in v1; streamed follow-up parity delivered post-v1 in Phase 10T through `ClaudePromptStream` |
| `receive_messages()` | `client.py` | Lowest-level interactive receive loop | parser, message routing | `v1 core` | Primary stream-consumption primitive |
| `receive_response()` | `client.py` | Convenient per-turn receive loop for UI code | `receive_messages`, result detection | `v1 core` | Stop after `ResultMessage` |
| `disconnect()` | `client.py` | Needed for predictable shutdown in Godot runtime | transport lifecycle | `v1 core` | Important because there is no Python async context manager equivalent |
| `interrupt()` | `client.py`, `e2e-tests/test_dynamic_control.py` | Needed for chat UIs and long-running tool use | control protocol | `v1 core` | Explicitly part of the first client spec |
| `set_permission_mode()` | `client.py`, `e2e-tests/test_dynamic_control.py` | Supports switching from planning to editing flows | control protocol | `v1 core` | Required dynamic control in v1 |
| `set_model()` | `client.py`, `e2e-tests/test_dynamic_control.py` | Lets clients escalate or cheapen a live session | control protocol | `v1 core` | Required dynamic control in v1 |
| `get_server_info()` | `client.py` | Exposes initialize result to clients and adapters | initialize flow | `v1 core` | Useful for commands, output styles, capability introspection |
| `get_context_usage()` | `client.py` | Valuable for advanced UIs and diagnostics | control protocol, typed response models | `v1 later` | Worth adding after core conversation flow |
| `get_mcp_status()` / reconnect / toggle | `client.py`, `e2e-tests/test_sdk_mcp_tools.py` | Important once MCP parity matters | control protocol, MCP config, typed responses | `v1 later` | Not on the critical path for core chat |
| `rewind_files()` | `client.py` | Depends on checkpointing and replayed user messages | file checkpointing, message UUIDs, control protocol | `deferred` | High complexity, not needed for first public release |
| `stop_task()` | `client.py` | Useful only once task notifications and task control are first-class | task messages, control protocol | `deferred` | Delivered post-v1 in Phase 10O through command-style `stop_task(task_id)` parity on the runtime, adapter, and node surfaces |
| Python async context manager | `client.py` `__aenter__` / `__aexit__` | Convenience only | connect/disconnect | `not applicable` | Use explicit lifecycle methods in GDScript |

## Transport and process management

| Capability | Upstream entrypoints | Why it matters in Godot | Dependency chain | Bucket | Notes |
| --- | --- | --- | --- | --- | --- |
| Internal transport abstraction | `_internal/transport/__init__.py`, `query.py`, `client.py` | Keeps the core scene-free and testable | none | `v1 core` | Must exist even if only one concrete transport ships first |
| Claude CLI subprocess transport | `_internal/transport/subprocess_cli.py`, `tests/test_transport.py` | The actual runtime bridge to Claude Code | transport abstraction, OS process APIs | `v1 core` | Phase 1 already validated the direction |
| CLI path override | `ClaudeAgentOptions.cli_path`, `tests/test_transport.py` | Needed for existing local Claude setups | subprocess transport | `v1 core` | Mirrors sibling project usage |
| Host environment inheritance with extra env overrides | `ClaudeAgentOptions.env`, subprocess transport, sibling project reference | Needed to reuse installed Claude auth and shell setup | subprocess transport | `v1 core` | Default should inherit host env; explicit `env` adds overrides |
| Working directory override | `ClaudeAgentOptions.cwd`, `tests/test_client.py` | Needed for project-scoped Claude behavior | subprocess transport | `v1 core` | Must not rely on exported app cwd defaults |
| Command-building for core options | `tests/test_transport.py` | Defines the minimum supported CLI surface | subprocess transport, core options | `v1 core` | Cover core fields first |
| stdout and stderr draining | subprocess transport, `e2e-tests/test_stderr_callback.py` | Prevents deadlocks and preserves diagnostics | process lifecycle | `v1 core` | Phase 1 confirmed stderr handling is mandatory |
| Initialize handshake and control routing | `_internal/query.py`, `tests/test_query.py` | Core to streaming mode and client capability negotiation | transport, parser | `v1 core` | Required for both one-shot and interactive flows |
| String-prompt stdin lifetime rules | `tests/test_query.py` | Prevents deadlocks around late control requests | initialize flow, result tracking | `v1 core` | Important for hooks/MCP compatibility even before those features ship |
| CLI discovery fallback search | `_internal/transport/subprocess_cli.py` | Nice UX, but not essential if `claude` on `PATH` plus explicit path works | subprocess transport | `v1 later` | Start with `claude` on `PATH` plus override path |
| Broader CLI flag passthrough via `extra_args` | `ClaudeAgentOptions.extra_args` | Helps edge cases without widening the stable API too early | subprocess transport | `v1 later` | Delivered post-v1 in Phase 10L as transport-first ordered passthrough with flag/value support |
| Bundled CLI inside the SDK package | `_bundled/`, subprocess transport | Upstream convenience for Python packaging | packaging pipeline | `not applicable` | Conflicts with current addon strategy of using a user-installed CLI |

## Message parsing and typed event models

| Capability | Upstream entrypoints | Why it matters in Godot | Dependency chain | Bucket | Notes |
| --- | --- | --- | --- | --- | --- |
| Raw message parser | `_internal/message_parser.py`, `tests/test_message_parser.py` | Converts CLI JSON into stable GDScript data models | transport | `v1 core` | Core parser target |
| `TextBlock` / `ToolUseBlock` / `ToolResultBlock` | `types.py`, parser, examples | Needed for ordinary Claude conversations and tool traces | parser, typed models | `v1 core` | Minimum useful block set |
| `ThinkingBlock` parsing | `types.py`, parser, `e2e-tests/test_include_partial_messages.py` | Keeps parser compatible with richer model responses | parser, typed models | `v1 core` | Low-cost to support once content-block parsing exists |
| `UserMessage` / `AssistantMessage` / `SystemMessage` / `ResultMessage` | `types.py`, parser, tests | Minimum message model for v1 | parser, typed models | `v1 core` | Explicit v1 target set |
| Forward-compatible unknown message handling | parser | Prevents older SDK versions from crashing on new CLI events | parser | `v1 core` | Skip unknown message types |
| Specialized task system messages | parser, `types.py` | Useful once task-oriented features exist | system message parsing | `v1 later` | Delivered post-v1 in Phase 10O through typed task message subclasses that preserve generic `ClaudeSystemMessage` compatibility |
| `StreamEvent` partial-message model | parser, `e2e-tests/test_include_partial_messages.py` | Needed for token-by-token / delta UIs | parser, partial-message option | `v1 later` | Valuable, but not required for first full chat loop |
| `RateLimitEvent` model | parser | Useful for UX warnings and dashboards | parser | `v1 later` | Delivered post-v1 in Phase 10S through typed `ClaudeRateLimitEvent` and normalized `ClaudeRateLimitInfo` parsing |

## Dynamic control operations

| Capability | Upstream entrypoints | Why it matters in Godot | Dependency chain | Bucket | Notes |
| --- | --- | --- | --- | --- | --- |
| `initialize` request/response | `_internal/query.py`, control protocol types | Required to start streaming mode correctly | transport | `v1 core` | Core protocol capability |
| `interrupt` control | `_internal/query.py`, `client.py` | Required by interactive chat UIs | initialize flow | `v1 core` | First-class client control operation |
| `set_permission_mode` control | `_internal/query.py`, `client.py` | Supports plan/edit mode changes mid-session | initialize flow | `v1 core` | In the locked v1 client method set |
| `set_model` control | `_internal/query.py`, `client.py` | Allows dynamic model changes | initialize flow | `v1 core` | In the locked v1 client method set |
| `get_server_info` from initialize payload | `client.py` | Lets clients inspect capabilities without extra round trips | initialize flow | `v1 core` | Backed by stored initialize result |
| Context-usage control | `_internal/query.py`, `client.py` | Useful for advanced diagnostics | initialize flow, typed response | `v1 later` | Post-core |
| MCP status/reconnect/toggle controls | `_internal/query.py`, `client.py` | Needed once MCP support expands | initialize flow, MCP config | `v1 later` | Post-core |
| Rewind-files control | control protocol types, `client.py` | Depends on checkpointing and replay | initialize flow, file checkpointing | `deferred` | Not for first release |
| Stop-task control | control protocol types, `client.py` | Depends on task lifecycle support | initialize flow, task messages | `deferred` | Delivered post-v1 in Phase 10O through awaited control-request parity using `subtype: "stop_task"` and `task_id` |

## Hooks and tool-permission callbacks

| Capability | Upstream entrypoints | Why it matters in Godot | Dependency chain | Bucket | Notes |
| --- | --- | --- | --- | --- | --- |
| Hook matcher and callback configuration | `types.py`, `_internal/query.py`, `examples/hooks.py`, `e2e-tests/test_hooks.py` | Powerful extension point for advanced apps | initialize flow, callback routing | `v1 later` | Valuable parity, but not needed for core chat |
| Hook-specific input/output models | `types.py`, hook e2e tests | Needed for safe, typed callback integration | hooks | `v1 later` | Phase 10V adds typed hook-output helpers and runtime coercion for callback results; hook inputs intentionally remain dictionary-first in GDScript for compatibility |
| Tool-permission callback (`can_use_tool`) | `types.py`, `_internal/query.py`, `examples/tool_permission_callback.py`, `e2e-tests/test_tool_permissions.py` | Important for custom approval UX | initialize flow, permission result models | `v1 later` | Phase 5 delivered the callback path; Phase 10V widens it with additive typed permission-update helpers and typed suggestion exposure |
| Permission update suggestion/result models | `types.py`, hook and permission tests | Needed to mirror upstream callback semantics | permission callbacks | `v1 later` | Delivered post-v1 in Phase 10V through `ClaudePermissionUpdate`, `ClaudePermissionRuleValue`, and runtime coercion on permission callback results |

## Sessions and session mutations

| Capability | Upstream entrypoints | Why it matters in Godot | Dependency chain | Bucket | Notes |
| --- | --- | --- | --- | --- | --- |
| Session listing | `_internal/sessions.py`, `tests/test_sessions.py` | Useful for history browsers and chat restoration | Claude local storage knowledge | `v1 later` | Delivered in Phase 10A through `ClaudeSessions.list_sessions()` |
| Session transcript reading | `_internal/sessions.py`, `tests/test_sessions.py` | Needed for conversation history tooling | session listing, transcript parsing | `v1 later` | Delivered in Phase 10A through `ClaudeSessions.get_session_messages()` and extended in Phase 10G with normalized transcript-detail reading through `ClaudeSessions.get_session_transcript()` |
| Rename/tag/delete session helpers | `_internal/session_mutations.py`, `tests/test_session_mutations.py` | Useful for history management UIs | session file layout and mutation rules | `v1 later` | Delivered in Phase 10B through `ClaudeSessions.rename_session()`, `tag_session()`, and `delete_session()`; higher-layer wrapper and panel support shipped in Phase 10C |
| Session forking helpers | `_internal/session_mutations.py` | Advanced workflow for branching conversation history | session transcript mutation | `v1 later` | Delivered post-v1 in Phase 10H through `ClaudeSessions.fork_session()` plus adapter/node passthroughs |

## MCP integration and SDK MCP helpers

| Capability | Upstream entrypoints | Why it matters in Godot | Dependency chain | Bucket | Notes |
| --- | --- | --- | --- | --- | --- |
| External MCP server config passthrough | `types.py`, transport command building | Important once users need external tool ecosystems | transport, settings/config encoding | `v1 later` | Reasonable after core chat and core options settle |
| MCP status inspection and live toggling | `client.py`, e2e MCP tests | Operational tooling for advanced sessions | MCP config, control protocol | `v1 later` | Tied to broader MCP story |
| SDK MCP in-process tool helpers | `__init__.py` tool decorator and SDK MCP helpers, `e2e-tests/test_sdk_mcp_tools.py` | Powerful parity feature for in-process tool hosting without external MCP processes | MCP server runtime, callback plumbing | `v1 later` | Delivered post-v1 in Phase 10D with Godot-native builders instead of Python decorators |
| Python decorator-based tool definition API | `__init__.py` | Python convenience layer | language-specific reflection and decorators | `not applicable` | GDScript should use a different registration shape if/when this feature arrives |

## Structured output, agents, settings, and diagnostics

| Capability | Upstream entrypoints | Why it matters in Godot | Dependency chain | Bucket | Notes |
| --- | --- | --- | --- | --- | --- |
| Core options object (`ClaudeAgentOptions`) | `types.py`, all tests/examples | Main configuration entrypoint for parity | typed models | `v1 core` | Keep the name and role close to upstream |
| Core option fields: `model`, `effort`, `cwd`, `cli_path`, `env`, `system_prompt`, `allowed_tools`, `disallowed_tools`, `permission_mode`, `max_turns`, `resume`, `session_id` | `types.py`, examples, transport tests | Defines the first stable config surface | transport, client/query APIs | `v1 core` | Locked by Phase 2 decisions |
| Base tool-set selection (`tools`) | `types.py`, `examples/tools_option.py` | Useful for advanced tool governance | command building | `v1 later` | Delivered post-v1 in Phase 10E with unset, empty, array, and `claude_code` preset semantics |
| System prompt preset/file variants | `types.py`, transport tests | Good parity with upstream configuration ergonomics | command building | `v1 later` | Delivered post-v1 in Phase 10E through preset omission, preset+append, and file-path support |
| Structured output (`output_format`) | `types.py`, `e2e-tests/test_structured_output.py` | Valuable for game/tool integrations consuming machine-readable results | result parsing, option encoding | `v1 later` | Strong candidate once the normal result flow is stable |
| Partial-message option (`include_partial_messages`) | `types.py`, `e2e-tests/test_include_partial_messages.py` | Needed for token-delta UIs | stream-event parsing | `v1 later` | Pair with `StreamEvent` support |
| Stderr callback / debug output plumbing | `types.py`, `examples/stderr_callback_example.py`, `e2e-tests/test_stderr_callback.py` | Important for diagnostics and developer UX | stderr draining | `v1 later` | Delivered post-v1 in Phase 10L through `ClaudeAgentOptions.stderr`; deprecated Python `debug_stderr` remains not applicable in GDScript |
| Agent definitions in initialize payload | `types.py`, `examples/agents.py`, `e2e-tests/test_agents_and_settings.py` | Advanced control over sub-agent behavior | initialize flow, typed models | `v1 later` | Delivered post-v1 in Phase 10I through `ClaudeAgentDefinition` and `ClaudeAgentOptions.agents` |
| Setting-source controls | `types.py`, `examples/setting_sources.py`, `e2e-tests/test_agents_and_settings.py` | Useful for advanced config control | option encoding, CLI settings model | `v1 later` | Delivered post-v1 in Phase 10I through `ClaudeAgentOptions.setting_sources` and `--setting-sources` parity |
| Continue-conversation flag, fallback model, betas, permission prompt tool, add_dirs, max budget, task budget, and advanced thinking config | `types.py`, examples, transport tests | Useful advanced transport/runtime parity once the core option model is stable | command building, CLI settings parity | `v1 later` | Delivered post-v1 in Phase 10J through additive `ClaudeAgentOptions` fields and transport-only flag emission without initialize payload changes |
| Settings and sandbox passthrough/merge behavior | `types.py`, `subprocess_cli.py`, transport tests | Important advanced transport parity for teams that already rely on Claude settings files or bash sandboxing | command building, CLI settings parity | `v1 later` | Delivered post-v1 in Phase 10K through `ClaudeAgentOptions.settings`, `ClaudeAgentOptions.sandbox`, and upstream-style `--settings` merge behavior |
| Plugin-dir and `fork_session` option parity | `types.py`, examples, transport tests | Useful bounded transport parity without widening initialize/runtime protocol scope | command building | `v1 later` | Delivered post-v1 in Phase 10M through `ClaudeAgentOptions.plugins`, `ClaudeAgentOptions.fork_session`, repeated `--plugin-dir`, and `--fork-session` parity |
| Process-user launch parity | `types.py`, transport tests | Legitimate parity surface for teams that need to run Claude Code as another local user | process-launch parity | `v1 later` | Delivered post-v1 in Phase 10P through `ClaudeAgentOptions.user` on POSIX shell-backed transports; Windows transports currently reject the option |

## Godot-only additions

| Capability | Upstream entrypoints | Why it matters in Godot | Dependency chain | Bucket | Notes |
| --- | --- | --- | --- | --- | --- |
| Scene-free core mirroring upstream concepts | project ADRs, roadmap | Keeps parity work testable and portable | core SDK implementation | `v1 core` | Godot-specific architectural rule |
| Signal-based adapters | project roadmap, ADR 0001 | Godot-native integration surface for games/tools | scene-free core | `v1 later` | Implemented in Phase 6; extended in Phase 10C with session-history and mutation convenience methods |
| Optional Node wrappers | project roadmap, ADR 0001 | Convenience for scene-tree users | adapters | `v1 later` | Implemented in Phase 6; extended in Phase 10C with session-history and mutation convenience methods |
| Reusable chat panel | project roadmap | Validation UI and reference implementation | adapters | `deferred` | Implemented in Phase 7 as addon UI and expanded in Phase 10C with session browsing, transcript restoration, saved-session resume, and basic session-management controls |
| Demo validation project | project roadmap | End-to-end validation and onboarding | core SDK, adapters, chat panel | `deferred` | Implemented in Phase 7 as root-project demo content outside the addon payload |

## Current Phase 2 conclusion

The first implementation target should stay narrow:

- build the scene-free core around `query()`, `ClaudeSDKClient`, and `ClaudeAgentOptions`
- implement subprocess transport, initialize/control routing, and typed message parsing first
- keep hooks, permissions, structured output, and MCP status work as the next parity slice
- leave session tooling, SDK MCP helpers, broad agent/settings parity, and UI work outside the first public release

Status note:

- that first public-release core has now been extended with Phase 5 runtime parity work, Phase 6 adapters, and Phase 7 UI/demo work
- Phase 10A adds read-only session history support through `ClaudeSessions`
- Phase 10B adds basic session mutations through `ClaudeSessions.rename_session()`, `tag_session()`, and `delete_session()`
- Phase 10C lifts the current session feature set into `ClaudeClientAdapter`, `ClaudeClientNode`, and the shipped `ClaudeChatPanel`
- Phase 10D adds runtime-first SDK-hosted MCP tool/server helpers through `ClaudeMcp` and mixed `mcp_servers` handling
- Phase 10E adds richer `system_prompt` variants, base built-in tool selection, and disconnected prompt/tool configuration controls in the shipped panel
- Phase 10F refactors the shipped panel into a conversation-first `Chat` view with a separate `Settings` view and quick chat controls
- Phase 10G adds normalized transcript-detail reading plus transcript filtering/de-duplication behavior in the shipped panel
- Phase 10H adds runtime-first session forking helpers with adapter/node passthroughs
- Phase 10I adds runtime-first agent definitions and `setting_sources` parity
- Phase 10J adds transport-first advanced CLI option parity without widening the initialize payload surface
- Phase 10K adds transport-first `settings` and `sandbox` parity without widening the initialize payload surface
- Phase 10L adds transport-first `extra_args` and `stderr` diagnostics parity without widening the initialize payload surface
- Phase 10M adds transport-first local-plugin and `fork_session` option parity without widening the initialize payload surface
- Phase 10N adds transport-first file checkpointing plus connected-session `rewind_files()` parity without widening the initialize payload surface
- Phase 10O adds task-control `stop_task()` parity plus typed task system message parsing without widening the transport or initialize payload surfaces
- Phase 10P adds transport-first `ClaudeAgentOptions.user` parity through a POSIX `sudo -n -u` launch wrapper while keeping `user` out of initialize payloads
- Phase 10V adds typed hook-output helpers plus typed permission-update helpers while keeping hook callback inputs dictionary-first for backward compatibility
- Phase 10W closes the remaining `connect()` lifecycle gap by making repeated local `connect_client()` calls reopen cleanly instead of no-oping, and the reference chat panel now showcases disconnected connect-and-send behavior directly
- the reusable chat panel and demo are available project outputs, but they remain outside the upstream core-parity target and distributable addon core rules
