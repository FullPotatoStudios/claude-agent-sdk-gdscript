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

## Contents

This payload includes:

- the scene-free runtime core
- `ClaudeSDKClient`
- `ClaudeSessions`
- `ClaudeClientAdapter`
- `ClaudeClientNode`
- `ClaudeChatPanel`
- the canonical addon `VERSION`
- the addon-local `LICENSE.txt`

Development-only content such as `demo/`, `tests/`, `tools/`, and `addons/gdUnit4/` stays outside this payload boundary.

## More docs

- See the root repository `README.md` for the public project overview.
- See the repository docs, especially `docs/contributing/session-history.md`, for read-only local session-history usage.
- See the repository docs for install, integration, release, and parity details.
