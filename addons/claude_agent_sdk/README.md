# Claude Agent SDK Addon

This directory is the distributable addon payload for Claude Agent SDK for GDScript.

## Install

Copy this directory into the target project's `addons/` folder so the final path is:

- `res://addons/claude_agent_sdk/`

The current addon does not require `plugin.cfg`, autoloads, or editor-plugin enablement.

## Compatibility

- Godot `4.6`
- desktop/editor workflows supported
- exported macOS support limited to the validated unsandboxed scenarios
- mobile, web, and App Store-sandboxed macOS workflows remain out of scope

## Runtime expectations

- the addon uses the system-installed `claude` CLI
- existing Claude auth is reused from the caller's environment
- the packaged chat panel is optional and can be replaced with custom UI built on the lower runtime layers
- session history is available directly through `ClaudeSessions` and through convenience passthroughs on `ClaudeClientAdapter` / `ClaudeClientNode`, including richer normalized transcript detail via `get_session_transcript()` and explicit saved-session branching via `fork_session()`
- richer `system_prompt` and base `tools` configuration is available through `ClaudeAgentOptions`
- runtime-first custom agent definitions and `setting_sources` control are available through `ClaudeAgentOptions`
- transport-first advanced CLI option parity is also available through `ClaudeAgentOptions`, including `continue_conversation`, `fallback_model`, `betas`, `permission_prompt_tool_name`, `add_dirs`, `max_budget_usd`, `thinking`, deprecated `max_thinking_tokens`, and `task_budget`
- transport-first `settings` and `sandbox` support is available through `ClaudeAgentOptions`, with sandbox merged into the CLI `--settings` value when configured
- transport-first diagnostics support is also available through `ClaudeAgentOptions.extra_args` and `ClaudeAgentOptions.stderr`
- transport-first local-plugin and `fork_session` option parity is available through `ClaudeAgentOptions.plugins` and `ClaudeAgentOptions.fork_session`
- `ClaudeBuiltInToolCatalog` exposes the shipped built-in Claude Code tool metadata for custom panel/tool-picker UIs
- SDK-hosted MCP/custom-tool registration stays code-driven through `ClaudeMcp` and `ClaudeAgentOptions.mcp_servers`

## Contents

This payload includes:

- the scene-free runtime core
- `ClaudeSDKClient`
- `ClaudeSessions`
- `ClaudeForkSessionResult`
- `ClaudeAgentDefinition`
- transport-first advanced CLI option fields on `ClaudeAgentOptions`
- transport-first `settings` and `sandbox` fields on `ClaudeAgentOptions`
- transport-first diagnostics fields on `ClaudeAgentOptions`
- transport-first local-plugin and `fork_session` fields on `ClaudeAgentOptions`
- `ClaudeMcp`, `ClaudeMcpTool`, `ClaudeMcpToolAnnotations`, and `ClaudeSdkMcpServer`
- `ClaudeBuiltInToolCatalog`
- `ClaudeClientAdapter`
- `ClaudeClientNode`
- `ClaudeChatPanel` with saved-session browsing, transcript restoration, transcript granularity filters, idle-time live switching, resume, basic rename/tag/delete controls, and disconnected prompt/tool configuration controls
- the canonical addon `VERSION`
- the addon-local `LICENSE.txt`

Development-only content such as `demo/`, `tests/`, `tools/`, and `addons/gdUnit4/` stays outside this payload boundary.

## More docs

- See the root repository `README.md` for the public project overview.
- See the repository docs, especially `docs/contributing/session-history.md`, for session-history and basic mutation usage.
- See `docs/contributing/integration.md` and `docs/contributing/ui-panel.md` for prompt/tool configuration and panel behavior details.
- See the repository docs for install, integration, release, and parity details.
