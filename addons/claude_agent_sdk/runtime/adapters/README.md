# Adapters

Godot-native integration code belongs here.

This layer now provides thin Godot-facing wrappers over the scene-free runtime.

Current contents:

- `claude_client_adapter.gd`: a signal-based `RefCounted` facade over `ClaudeSDKClient`
- `claude_client_node.gd`: an optional `Node` wrapper that mirrors the adapter API and signals

This layer should stay thin:

- it should not reimplement transport, parsing, auth, or session routing
- it should not become a transcript/history store
- it should not add UI or editor-plugin requirements

Higher-level UI belongs in later phases under `ui/`.
