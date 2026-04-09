# Examples

`tools/examples/` contains development-only examples for the local GDScript SDK.

These files are not part of the distributable addon payload.

## Snippet examples

These two files stay as lightweight integration snippets:

- `adapter_usage_example.gd`
- `node_usage_example.gd`

They are useful as copy/paste references inside your own scenes, but they are
not standalone runners.

## Runnable advanced examples

The files below are headless-runnable `SceneTree` entrypoints that mirror the
post-v1 Python SDK examples the roadmap calls out as missing locally.

Run them from the repo root with a Godot 4.6 binary:

```bash
godot4 --headless --path . -s tools/examples/agents_example.gd
```

You can substitute `godot4` with your local `GODOT_BIN` path if needed.

Available advanced examples:

- `agents_example.gd`
  Upstream parity target: `examples/agents.py`
- `setting_sources_example.gd`
  Upstream parity target: `examples/setting_sources.py`
- `plugin_example.gd`
  Upstream parity target: `examples/plugin_example.py`
- `stderr_callback_example.gd`
  Upstream parity target: `examples/stderr_callback_example.py`
- `include_partial_messages_example.gd`
  Upstream parity target: `examples/include_partial_messages.py`
- `hooks_example.gd`
  Upstream parity target: `examples/hooks.py`
- `tool_permission_callback_example.gd`
  Upstream parity target: `examples/tool_permission_callback.py`
- `max_budget_usd_example.gd`
  Upstream parity target: `examples/max_budget_usd.py`
- `sdk_mcp_calculator_example.gd`
  Upstream parity target: `examples/mcp_calculator.py`

## Fixtures

`tools/examples/fixtures/` contains the local project fixtures used by the
settings-source and plugin examples.

- the settings-source example copies a fixture workspace into `user://` before
  connecting so it does not depend on repo-root or personal Claude config
- the plugin example points at a local demo plugin fixture that mirrors the
  upstream Python example layout

The settings-source example intentionally focuses on deterministic `project`
and default-source loading through a fixture `.claude/settings.local.json`,
matching this repo's validated live-parity notes. User-level Claude settings
still come from the host environment, so the example documents them as opt-in
and host-dependent rather than pretending they are fully reproducible.
