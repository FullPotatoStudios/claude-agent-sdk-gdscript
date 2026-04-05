# Runtime

Scene-free runtime code belongs here.

The intended Phase 4 layering is:

- `query.gd`
- `claude_agent_options.gd`
- `claude_sdk_client.gd`
- `tools/`
- `sessions/`
- `transport/`
- `protocol/`
- `messages/`
- `parser/`

Runtime classes in this layer should default to `RefCounted`.

Auth is CLI-owned in this layer:

- default runtime behavior reuses the installed `claude` binary and the inherited host environment
- the runtime should not rewrite `HOME` or `XDG_*` paths as part of normal execution
- `ClaudeSDKClient.get_auth_status()` and `ClaudeQuery.get_auth_status()` provide a lightweight auth diagnostic without opening a full Claude session
