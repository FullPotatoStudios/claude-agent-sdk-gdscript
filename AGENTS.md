# AGENTS.md

Start by reading `README.md`.

Then use these files as the source of truth:

- `docs/roadmap/roadmap.md`
- `docs/contributing/workflow.md`
- `docs/contributing/maintainer-workflow.md`
- `docs/contributing/testing.md`
- `docs/contributing/integration.md`
- `docs/contributing/ui-panel.md`
- `docs/investigations/phase-1-feasibility.md`
- `docs/investigations/phase-1-findings.md`
- `docs/investigations/phase-1-support-matrix.md`
- `docs/investigations/phase-5-validation.md`
- `docs/investigations/phase-7-validation.md`
- `docs/investigations/phase-8-validation.md`
- `docs/adr/0001-core-architecture.md`
- `docs/adr/0002-upstream-tracking.md`
- `docs/adr/0003-godot-version-policy.md`
- `docs/adr/0004-package-boundary.md`
- `docs/adr/0005-runtime-class-shape.md`
- `docs/adr/0006-testing-strategy.md`
- `docs/parity/upstream-ledger.md`
- `docs/parity/feature-matrix.md`
- `docs/parity/v1-scope.md`
- `docs/release/install.md`
- `docs/release/packaging.md`
- `docs/release/release-process.md`
- `docs/release/asset-library.md`

Keep this file minimal. Put durable project knowledge in the docs above instead of expanding `AGENTS.md`.

Routing notes:

- use `README.md` for the public project shape and supported usage
- use `docs/contributing/workflow.md` for day-to-day repo workflow
- use `docs/contributing/maintainer-workflow.md` before preparing commits or releases
- use `docs/release/release-process.md` before publishing a version
- use `docs/parity/upstream-ledger.md` before making parity or upstream-sync claims

Local upstream reference:

- Prefer a sibling checkout of `claude-agent-sdk-python` if one exists.

Current rule of thumb:

- prove feasibility first
- track upstream explicitly
- keep the core scene-free
- use `RefCounted` for scene-free runtime classes by default
- prefer the Phase 2 `cli_path` and `env` option shape over earlier draft naming
- keep the addon payload separate from demo-only content
- use the shipped chat panel as a reference UI, not as a replacement for the lower runtime layers
