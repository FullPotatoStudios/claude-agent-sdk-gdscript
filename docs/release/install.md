# Install Guide

## GitHub Release ZIP

1. Download the published GitHub Release ZIP.
2. Extract it into the target Godot project root.
3. Confirm the addon is installed at:
   - `res://addons/claude_agent_sdk/`
4. Use the shipped APIs directly:
   - `ClaudeQuery`
   - `ClaudeSDKClient`
   - `ClaudeClientAdapter`
   - `ClaudeClientNode`
   - `ClaudeChatPanel`

The current addon does not require `plugin.cfg`, autoload setup, or editor-plugin enablement.

## Godot Asset Library

The Asset Library distribution should point to the same GitHub Release ZIP through a custom download provider.

The expected installed result is identical to the GitHub ZIP path:

- `res://addons/claude_agent_sdk/`

## Compatibility

- Godot `4.6`
- desktop/editor workflows supported
- exported macOS support limited to the validated unsandboxed scenarios

## Known limitations

- requires a user-installed `claude` CLI available on `PATH`, or a configured `cli_path`
- reuses the caller's existing Claude auth and settings state
- mobile, web, and App Store-sandboxed macOS workflows remain out of scope

## Notes

- `demo/` content is validation/reference material and is not part of the installed addon payload
- the distributable payload is only `addons/claude_agent_sdk/`
