# Claude Agent SDK Addon

This directory is the distributable addon payload.

The addon now contains:

- the scene-free runtime core
- Godot adapters and an optional `ClaudeClientNode`
- the reusable `ClaudeChatPanel`
- the canonical addon version file at `VERSION`
- the addon-local MIT license at `LICENSE.txt`

Current subtrees:

- `runtime/`
- `runtime/transport/`
- `runtime/protocol/`
- `runtime/messages/`
- `runtime/parser/`
- `runtime/adapters/`
- `ui/`
- `icons/`

Development-only tooling such as tests, probes, and GdUnit4 should stay outside this addon payload boundary.

## Install

Copy this directory into the target project's `addons/` folder so the final path is:

- `res://addons/claude_agent_sdk/`

The current addon does not require `plugin.cfg`, autoloads, or editor-plugin enablement.

## Compatibility

- Godot `4.6`
- desktop/editor workflows first
- exported macOS support currently limited to the validated unsandboxed scenarios

## Runtime expectations

- the addon uses the system-installed `claude` CLI
- existing Claude auth is reused from the caller's environment
- the packaged chat panel is optional and can be replaced with custom UI built on the lower runtime layers
