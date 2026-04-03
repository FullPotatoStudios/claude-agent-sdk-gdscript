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
6. Install repo-managed hooks if you want automatic local validation:
   - `./tools/dev/install_git_hooks.sh`

## Before creating a normal commit

Run the checks appropriate to the change:

- Fast local validation:
  - `./tools/dev/run_fast_checks.sh`
- Full deterministic push-ready validation:
  - `./tools/dev/run_push_checks.sh`
- Local authenticated Claude validation when preparing a release or checking live runtime behavior:
  - `./tools/release/validate_live_cli.sh`

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
3. Run local release prep:
   - `./tools/release/prepare_release.sh --tag vX.Y.Z`
4. Create the annotated tag:
   - `./tools/release/prepare_release.sh --tag vX.Y.Z --create-tag`
5. Push `main`.
6. Push the version tag.
7. Let GitHub publish the release automatically.

## Publish flow

Use `docs/release/release-process.md` as the canonical publishing checklist. The normal publish sequence is:

1. run local release prep, including the authenticated Claude check
2. create the annotated release tag
3. push `main`
4. push the version tag
5. let GitHub publish the GitHub Release ZIP, checksum, and notes
6. update the Asset Library listing using the generated summary

Asset Library submission details live in:

- `docs/release/asset-library.md`
- `docs/contributing/automation.md`

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

- prefer scripts over ad hoc manual commands
- use repo-managed hooks for local automation when available
- let GitHub Actions own CI and GitHub Release publishing
- keep local live Claude validation and final Asset Library submission as the remaining manual boundaries
