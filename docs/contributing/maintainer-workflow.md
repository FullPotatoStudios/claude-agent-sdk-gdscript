# Maintainer Workflow

## Summary

Use this document for normal commit preparation, release preparation, and version publishing. Keep `workflow.md` as the short day-to-day guide and treat this file as the canonical maintainer checklist.

## Orient before editing

1. Read the root `README.md` for the public project shape.
2. Check `docs/roadmap/roadmap.md` for current phase and active priorities.
3. Use the parity docs before making parity or support claims:
   - `docs/parity/feature-matrix.md`
   - `docs/parity/upstream-ledger.md`
4. Use the release docs before touching packaging or publishing:
   - `docs/release/packaging.md`
   - `docs/release/release-process.md`

## Normal development flow

1. Keep changes scoped to the current milestone.
2. Update docs whenever behavior, public APIs, support claims, install steps, or release workflow changes.
3. Keep distributable addon code under `addons/claude_agent_sdk/`.
4. Keep tests under `tests/` and validation/probe code under `tools/`.
5. Prefer the existing scripts for validation instead of ad hoc commands where possible.

## Before creating a normal commit

Run the checks appropriate to the change:

- Always run:
  - `./tools/dev/run_tests.sh`
- Run runtime smokes when runtime, adapters, or UI behavior changed:
  - `tools/spikes/phase5_runtime_smoke.gd` modes `baseline`, `structured`, and `partial`
- Run packaged-consumer validation when packaging, install flow, release docs, or addon payload shape changed:
  - `./tools/release/validate_release.sh`

Also confirm:

- public docs still match the current behavior
- release/support wording is still accurate
- no development-only content leaked into `addons/claude_agent_sdk/`

## When docs must change with code

Update docs in the same slice when you change:

- public API shape
- install steps
- supported platform/export claims
- release process
- parity/support statements
- shipped UI behavior that affects screenshots or user-facing usage guidance

Typical homes:

- public overview: `README.md`
- daily workflow: `docs/contributing/workflow.md`
- maintainer/release workflow: this file and `docs/release/release-process.md`
- parity state: `docs/parity/upstream-ledger.md`

## `CHANGELOG.md` and `VERSION`

Normal feature and fix commits do not bump the addon version by default.

Update `CHANGELOG.md` only when intentionally preparing a release or when staging release-note-ready entries as part of that prep.

Update `addons/claude_agent_sdk/VERSION` only when intentionally preparing a release.

When a release is being prepared, keep these in sync:

- `addons/claude_agent_sdk/VERSION`
- `CHANGELOG.md`
- `docs/parity/upstream-ledger.md`

## Release preparation

1. Confirm the worktree is the intended release state.
2. Update:
   - `addons/claude_agent_sdk/VERSION`
   - `CHANGELOG.md`
   - `docs/parity/upstream-ledger.md`
3. Run:
   - `./tools/dev/run_tests.sh`
   - `./tools/release/build_release.sh`
   - `./tools/release/validate_release.sh`
   - `./tools/release/check_upstream_diff.sh`
4. Run the manual authenticated clean-project checklist from `docs/release/release-process.md`.
5. Prepare release notes from `docs/release/release-notes-template.md`.

## Publish flow

Use `docs/release/release-process.md` as the canonical publishing checklist. The normal publish sequence is:

1. build the canonical ZIP and checksum
2. validate the packaged addon in a fresh temporary project
3. validate the real authenticated CLI path manually
4. publish the GitHub Release with the ZIP, checksum, and release notes
5. update the Asset Library listing metadata to point at the GitHub Release ZIP

Asset Library submission details live in:

- `docs/release/asset-library.md`

## Upstream parity maintenance

Before parity updates, check:

- `docs/parity/upstream-ledger.md`
- `./tools/release/check_upstream_diff.sh`

Record each reviewed release baseline in `docs/parity/upstream-ledger.md`, including:

- addon version
- upstream version and commit
- review date
- support claim
- notable deferred gaps

## Automation policy

The project should automate repetitive validation and publishing steps where practical, but this slice does not add hooks or CI/release workflow automation yet.

Current rule of thumb:

- prefer scripts over ad hoc manual commands
- keep human review over release gating
- treat local hooks and GitHub release automation as the next execution slice, not an assumed current capability
