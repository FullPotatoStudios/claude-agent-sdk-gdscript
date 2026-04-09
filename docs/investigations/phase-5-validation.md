# Phase 5 Validation

## Summary

Phase 5 extended the runtime with:

- hook matcher configuration and inbound hook callbacks
- tool-permission callbacks and allow/deny result models
- `stream_event` parsing for partial-message support
- richer `ClaudeResultMessage` fields for structured output and related metadata
- context-usage and MCP control requests
- CLI option support for `include_partial_messages`, `output_format`, `mcp_servers`, and stdio permission prompting
- runtime auth-status diagnostics that reuse the same CLI path and environment rules as the main transport

## Automated validation

The automated test suite passed after the Phase 5 implementation and follow-up fixes:

- command-building coverage for Phase 5 flags
- parser coverage for `ClaudeStreamEvent` and richer result payloads
- session coverage for hook callbacks, permission callbacks, cancel handling, and outbound context/MCP control requests
- regression coverage for existing Phase 4 transport, parser, and client behavior

Current local result:

- `./tools/dev/run_tests.sh`
- result: `39/39` tests passing

Known local warning:

- Godot still prints the non-fatal ObjectDB snapshot-directory warning in this environment

## Manual validation

### Raw transport probe

The existing low-level CLI probe still validated the expected control-protocol flow:

- `control_response`
- `system/init`
- `assistant`
- `result`

### Runtime smoke probe

`tools/spikes/phase5_runtime_smoke.gd` was added as a reusable runtime validation entrypoint.

Validated modes:

- `baseline`
- `structured`
- `partial`
- `agents`
- `setting_sources_default`
- `setting_sources_project_included`
- `filesystem_agent_project`
- auth probe

Observed results in this environment:

- `baseline`: runtime path succeeded and produced typed `system`, `assistant`, and `result` messages with the real authenticated Claude environment
- `structured`: runtime path succeeded once the smoke runner allowed `max_turns = 2`, which matches Claude's tool-mediated structured-output flow; the final result included `structured_output = {"answer": "4"}`
- `partial`: runtime path succeeded and produced real `ClaudeStreamEvent` messages before the final `result`
- `agents`: runtime path succeeded and the init `SystemMessage` exposed the SDK-defined `test-agent`, matching the upstream initialize-path agent registration expectation
- `setting_sources_default`: runtime path succeeded and the init `SystemMessage` reported `output_style = "local-test-style"` from a temporary project-local `.claude/settings.local.json` with default CLI setting-source loading
- `setting_sources_project_included`: runtime path succeeded and the init `SystemMessage` again reported `output_style = "local-test-style"` when `setting_sources = ["user", "project", "local"]`
- `filesystem_agent_project`: runtime path succeeded and the init `SystemMessage` exposed the temporary filesystem `fs-test-agent`, while the response continued through `AssistantMessage` and `ResultMessage` instead of stalling after init
- `auth probe` with the real user environment: reported `logged_in = true`
- `auth probe` with isolated `HOME` and `XDG_*`: reported `error_code = "logged_out"` rather than misclassifying the issue as a transport failure
- the earlier structured-output failure was a smoke configuration bug: the runner forced `max_turns = 1`, but Claude consumed one turn for the `StructuredOutput` tool call and finished on turn two

## Auth conclusion

The earlier auth failures were caused by validation runs that rewrote `HOME` and `XDG_*`, which made Claude look in an empty user-state directory.

The current validated default path is:

- keep the real user environment
- redirect Godot logs with `--log-file` when sandbox-safe output paths are needed
- let the installed Claude CLI own auth, config, and session state

This means:

- the Godot transport and runtime path can reuse the user's existing Claude CLI login
- logged-out states can now be diagnosed explicitly through the runtime auth probe
- future auth-sensitive validation should not use isolated-home launch recipes unless the goal is to test logged-out behavior on purpose

## Structured output conclusion

The structured-output runtime path is working.

The root cause of the earlier smoke failure was:

- the smoke runner hardcoded `max_turns = 1`
- Claude implemented the structured response through a `StructuredOutput` tool call
- the final successful result therefore arrived on turn two

The smoke now treats structured mode as a two-turn validation path while keeping the cheaper one-turn budget for baseline and partial modes.

## Post-Phase-5 live smoke additions

Date reviewed: 2026-04-09

The reusable authenticated smoke entrypoint under `tools/spikes/phase5_runtime_smoke.gd` has since been widened beyond the original Phase 5 trio.

Additional implemented modes:

- `agents`
- `plugins`
- `setting_sources_default`
- `setting_sources_project_included`
- `filesystem_agent_project`
- `stderr_debug`
- `hook_pre_tool_use`
- `tool_permission_bash_touch`
- `user_current_user_auth`
- `user_current_user_baseline`
- `dynamic_permission_mode`
- `dynamic_model`
- `dynamic_interrupt`
- `context_usage`
- `mcp_status`
- `sdk_mcp_tool_execution`
- `sdk_mcp_permission_enforcement`
- `sdk_mcp_multiple_tools`
- `sdk_mcp_without_permissions`

Validated in this environment during authenticated live runs:

- `agents`: `ClaudeAgentOptions.agents` appeared in the init `SystemMessage` and the query still completed with assistant plus result messages
- `plugins`: `ClaudeAgentOptions.plugins` loaded the local `demo-plugin` fixture from an absolute repo fixture path with repo-root `cwd`; the init payload exposed either `plugins = ["demo-plugin", ...]` or the `greet` command, which is truthful CLI-side evidence that the plugin directory was discovered even though this environment does not reliably prove `/greet` end-to-end execution from prompt text
- `setting_sources_default`: a temporary project-local `.claude/settings.local.json` was loaded when `setting_sources` was left unset, and init reported `output_style = "local-test-style"`
- `setting_sources_project_included`: the same local settings file was loaded when `setting_sources = ["user", "project", "local"]`, again surfacing `output_style = "local-test-style"` in init
- `filesystem_agent_project`: a temporary `.claude/agents/fs-test-agent.md` file was discovered when `setting_sources = ["project"]`; init listed `fs-test-agent`, and the session continued through assistant plus result messages instead of stopping at init-only
- `user_current_user_auth`: the auth probe succeeded with `ClaudeAgentOptions.user` set to the host's resolved current username after a real `sudo -n -u <current-user> /usr/bin/true` preflight confirmed that same-user relaunch is available on this POSIX machine
- `user_current_user_baseline`: a bounded baseline query succeeded with `ClaudeAgentOptions.user` set to the same resolved current username, continuing through init, assistant, and result messages without local transport or query errors

Implemented assertions for the new smoke modes:

- `stderr_debug`: requires the runtime `stderr` callback to capture at least one real Claude CLI `[DEBUG]` line when `extra_args = {"debug-to-stderr": null}`
- `hook_pre_tool_use`: requires a `PreToolUse` hook to match a real Bash invocation, see a non-empty `tool_use_id`, and allow the request through `hookSpecificOutput.permissionDecision = "allow"`
- `tool_permission_bash_touch`: connects a real `ClaudeSDKClient`, sends an interactive string `query("Run the command: touch ...")`, then requires a real Bash permission callback, a non-empty `tool_use_id`, and the prompted temp file created via `touch` outside the project cwd
- `user_current_user_auth`: resolves the current username with `id -un`, then `whoami`, then `USER` / `LOGNAME` / `USERNAME`; on POSIX it requires a real `sudo -n -u <current-user> /usr/bin/true` preflight before running the transport auth probe with `ClaudeAgentOptions.user = <current-user>` and requiring `logged_in = true`
- `user_current_user_baseline`: reuses the same username resolution plus preflight, then runs a bounded baseline query with `ClaudeAgentOptions.user = <current-user>` and requires init, assistant, and result messages without local query or stream failures
- `plugins`: runs a one-shot query with `cwd = res://` plus `plugins = [{"type": "local", "path": "<absolute demo fixture>"}]`, then requires either `init.plugins` to list `demo-plugin` or `init.commands` to expose `greet`; a metadata-only pass is documented as plugin discovery/configuration evidence rather than proof that the slash command executed end-to-end
- `dynamic_permission_mode`: connects a real `ClaudeSDKClient`, waits for initialize completion, switches from the default permission mode to `acceptEdits`, completes a first turn, switches back to `default`, and completes a second turn without control or stream errors
- `dynamic_model`: connects a real `ClaudeSDKClient`, completes one turn on the initial model, switches to `haiku`, completes another turn, then resets to the default model through local `set_model(null)` parity with upstream `set_model(None)` before attempting a third turn
- `dynamic_interrupt`: connects a real `ClaudeSDKClient`, starts a longer-running turn, sends `interrupt()`, and verifies the request does not surface a local client error while the response stream remains consumable without assuming a specific interrupted result shape
- `context_usage`: connects a real `ClaudeSDKClient`, completes one real turn, then requires `get_context_usage()` to return a typed response with non-empty categories and non-negative total/max token counts without assuming the CLI always returns a model string
- `mcp_status`: connects a real `ClaudeSDKClient` with an SDK MCP server, polls `get_mcp_status()` briefly for the configured server entry, and then requires concrete tool metadata for that SDK server without assuming a fixed live status string unless the CLI reports one deterministically
- `sdk_mcp_tool_execution`: connects a real `ClaudeSDKClient`, exposes an in-process `echo` SDK MCP tool through `ClaudeMcp`, and requires that the local tool handler actually executes while the stream completes without local client or protocol errors
- `sdk_mcp_permission_enforcement`: connects a real `ClaudeSDKClient`, exposes `greet` plus `echo` SDK MCP tools, allows only `greet`, explicitly disallows `echo`, and requires that the allowed handler executes while the disallowed handler never runs
- `sdk_mcp_multiple_tools`: connects a real `ClaudeSDKClient`, exposes `echo` plus `greet` SDK MCP tools, allows both, and requires that both local handlers execute during the same bounded turn budget
- `sdk_mcp_without_permissions`: connects a real `ClaudeSDKClient`, exposes an `echo` SDK MCP tool without `allowed_tools`, and requires that no local SDK MCP handler executes while the turn avoids local query or stream failures

Current local rerun status:

- a fresh `./tools/release/validate_live_cli.sh` run on `2026-04-09` now succeeds through the full current bounded wrapper, including `tool_permission_bash_touch`, `dynamic_model`, `dynamic_interrupt`, `context_usage`, `mcp_status`, and the SDK MCP live modes
- direct authenticated reruns on `2026-04-09` now also pass for the new `plugins` mode, with this environment surfacing `demo-plugin` in init plugin metadata even when slash-command execution is not separately proven
- direct authenticated reruns on `2026-04-10` also pass for `user_current_user_auth` and `user_current_user_baseline`, validating the local POSIX same-user `sudo -n -u` relaunch path for `ClaudeAgentOptions.user` in this machine's real logged-in Claude environment
- the same authenticated environment also passes upstream Python `e2e-tests/test_tool_permissions.py`, confirming the local smoke now matches the pinned `v0.1.54` callback path instead of relying on the earlier in-project workaround
- the `dynamic_model` reset leg now passes after the local runtime widened `set_model()` to nullable/default-null control requests, so the wire payload mirrors upstream `{"subtype": "set_model", "model": null}` semantics instead of sending an empty string
- the new SDK MCP modes were re-validated directly on `2026-04-09` through authenticated `tools/spikes/phase5_runtime_smoke.gd` invocations:
  - `sdk_mcp_tool_execution`
  - `sdk_mcp_permission_enforcement`
  - `sdk_mcp_multiple_tools`
  - `sdk_mcp_without_permissions`
- the new diagnostics-focused live modes were also re-validated directly on `2026-04-09` before the wrapper advanced past `tool_permission_bash_touch`:
  - `context_usage`
  - `mcp_status`
- those direct SDK MCP reruns only passed after a transport parity fix made local `--mcp-config` emission match upstream by including SDK server metadata while stripping the runtime-only `instance`
- deterministic runtime coverage now also proves `ClaudeSDKClient.reconnect_mcp_server()` and `toggle_mcp_server()` emit the same wire keys as upstream (`subtype = "mcp_reconnect"` / `"mcp_toggle"` with camelCase `serverName`), with direct adapter/node passthrough coverage on top
- a same-environment `2026-04-10` repro against both the local GDScript runtime and the sibling pinned Python SDK showed that the explored Bash-based live `rewind_files()` flow is not yet a passing parity proof at `v0.1.54`: rewinding to the plain-string replayed `UserMessage.uuid` resolves but leaves the edited file unchanged, while rewinding to the replayed top-level `tool_result` `UserMessage.uuid` returns `No file checkpoint found for this message.`
- a same-environment `2026-04-09` repro against both the local GDScript runtime and the sibling pinned Python SDK showed that live SDK-hosted `toggle_mcp_server()` semantics are currently blocked by upstream Claude CLI behavior at `v0.1.54`: after disable, `get_mcp_status()` can report the SDK server with `tools: []` while the SDK tool handler still executes, and re-enable raises `SDK servers should be handled in print.ts`

Scope note:

- this still only covers a bounded scripted live-parity slice rather than the full post-v1 surface
- the new `user` live modes only prove the local POSIX same-user relaunch path for the host's current account; they do not prove arbitrary cross-user support, and Windows remains unsupported for `ClaudeAgentOptions.user` in the shell-backed runtime
- live `rewind_files()` coverage remains future follow-up work even though deterministic `rewind_files(user_message_id)` parity is already delivered; the explored authenticated Bash edit flow currently reproduces the same non-restoring/no-checkpoint behavior in both local GDScript and the sibling pinned Python SDK
- live `stop_task()` coverage remains future follow-up work
- live SDK-hosted `toggle_mcp_server()` / `reconnect_mcp_server()` coverage is not in the passing wrapper because the pinned upstream Python SDK reproduces the same runtime limitation; any future live toggle/reconnect slice should target an external MCP server or another harness that can create a genuine disabled/disconnected state truthfully
- `./tools/release/validate_live_cli.sh` now accepts repeatable `--mode <name>` filters so later targeted smokes can still run while new parity slices are being developed or debugged
