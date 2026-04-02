# Runtime

Scene-free runtime code belongs here.

The intended Phase 4 layering is:

- `query.gd`
- `claude_agent_options.gd`
- `claude_sdk_client.gd`
- `transport/`
- `protocol/`
- `messages/`
- `parser/`

Runtime classes in this layer should default to `RefCounted`.
