# Workflow

## Current workflow

1. Check `README.md` and the roadmap before starting work.
2. Treat the Python SDK as the reference implementation, not as a dependency.
3. Record durable decisions in docs instead of relying on chat context.
4. Prefer incremental milestones with validation at each layer.
5. Keep the addon payload separate from demo-only material.
6. Keep scene-free runtime code under `addons/claude_agent_sdk/runtime/`.
7. Keep test code under `tests/`, not under the distributable addon tree.

## Near-term emphasis

During Phase 3:

- lock architecture and scaffolding decisions before core implementation starts
- target Godot `4.6` only
- use `RefCounted` for the scene-free runtime by default
- keep GdUnit4 as a development-only dependency
- do not add demo-project scaffolding yet
- do not add editor-plugin or autoload requirements yet
