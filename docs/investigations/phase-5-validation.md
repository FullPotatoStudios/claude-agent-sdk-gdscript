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
- auth probe

Observed results in this environment:

- `baseline`: runtime path succeeded and produced typed `system`, `assistant`, and `result` messages with the real authenticated Claude environment
- `structured`: runtime path succeeded once the smoke runner allowed `max_turns = 2`, which matches Claude's tool-mediated structured-output flow; the final result included `structured_output = {"answer": "4"}`
- `partial`: runtime path succeeded and produced real `ClaudeStreamEvent` messages before the final `result`
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

Additional validated modes:

- `agents`
- `setting_sources_default`
- `setting_sources_project_included`
- `filesystem_agent_project`

Observed results in this environment:

- `agents`: `ClaudeAgentOptions.agents` appeared in the init `SystemMessage` and the query still completed with assistant plus result messages
- `setting_sources_default`: a temporary project-local `.claude/settings.local.json` was loaded when `setting_sources` was left unset, and init reported `output_style = "local-test-style"`
- `setting_sources_project_included`: the same local settings file was loaded when `setting_sources = ["user", "project", "local"]`, again surfacing `output_style = "local-test-style"` in init
- `filesystem_agent_project`: a temporary `.claude/agents/fs-test-agent.md` file was discovered when `setting_sources = ["project"]`; init listed `fs-test-agent`, and the session continued through assistant plus result messages instead of stopping at init-only

Scope note:

- this still only covers the first scripted live-parity expansion slice
- dynamic control, hook/tool-permission, SDK MCP, stderr, session-forking, rewind/task, context/MCP diagnostics, `plugins`, and `user` coverage remain future follow-up work
