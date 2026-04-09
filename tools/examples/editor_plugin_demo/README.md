# Editor Plugin Demo

This development-only example shows one way to host `ClaudeChatPanel` inside a
Godot editor dock without changing the distributable addon payload.

It is intentionally not part of `addons/claude_agent_sdk/`.

## What it includes

- a copy-ready `EditorPlugin` under `addons/claude_agent_sdk_editor_demo/`
- a dock wrapper scene that instantiates `ClaudeChatPanel`
- project-scoped default options for editor use:
  - `cwd = ProjectSettings.globalize_path("res://")`
  - `model = "haiku"`
  - `effort = "low"`
  - `permission_mode = "plan"`

## How to try it

1. Install the main addon so the target project already contains:
   - `res://addons/claude_agent_sdk/`
2. Copy this example plugin folder into the target project's `addons/`:
   - `tools/examples/editor_plugin_demo/addons/claude_agent_sdk_editor_demo/`
3. In Godot, open `Project > Project Settings > Plugins`.
4. Enable `Claude Agent SDK Editor Demo`.

The plugin adds a `Claude` dock on the right side of the editor. The dock keeps
using the shipped `ClaudeChatPanel`; it does not add new runtime APIs or turn
the main addon into an editor plugin.
