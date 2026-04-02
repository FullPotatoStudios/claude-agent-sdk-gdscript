# AGENTS.md

Start by reading `README.md`.

Then use these files as the source of truth:

- `docs/roadmap/roadmap.md`
- `docs/investigations/phase-1-feasibility.md`
- `docs/adr/0001-core-architecture.md`
- `docs/adr/0002-upstream-tracking.md`
- `docs/adr/0003-godot-version-policy.md`
- `docs/adr/0004-package-boundary.md`
- `docs/adr/0005-runtime-class-shape.md`
- `docs/adr/0006-testing-strategy.md`
- `docs/parity/upstream-ledger.md`
- `docs/parity/feature-matrix.md`
- `docs/parity/v1-scope.md`
- `docs/contributing/testing.md`

Keep this file minimal. Put durable project knowledge in the docs above instead of expanding `AGENTS.md`.

Local upstream reference:

- Prefer a sibling checkout of `claude-agent-sdk-python` if one exists.

Current rule of thumb:

- prove feasibility first
- track upstream explicitly
- keep the core scene-free
- use `RefCounted` for scene-free runtime classes by default
- keep the addon payload separate from demo-only content
