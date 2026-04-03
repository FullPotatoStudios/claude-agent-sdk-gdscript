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

During Phase 8:

- keep the addon payload limited to `addons/claude_agent_sdk/`
- use the GitHub Release ZIP as the canonical install artifact
- keep Asset Library submission aligned with that same ZIP via a custom download provider
- validate the packaged addon in a fresh temporary Godot project, not only inside this dev repo
- track the local addon version alongside the pinned upstream Python SDK commit
- defer deeper upstream parity work until the release and maintenance flow is proven
