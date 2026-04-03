# Upstream Ledger

## Current baseline

- Upstream repository: `https://github.com/anthropics/claude-agent-sdk-python`
- Local reference checkout: a sibling checkout of the upstream repo, if available
- Version: `v0.1.54`
- Commit: `574044a1fcbaf89afc821bb742ccd8d31c4d6944`
- Reviewed on: `2026-04-02`
- Local project phase at pin time: preliminary work / Phase 1 feasibility

## Initial parity cut

- Parity cut reviewed on: `2026-04-03`
- Local project phase: Phase 2 upstream mapping and v1 scope
- Core scope direction:
  - `core chat first`
  - `mirror upstream`
- Canonical Phase 2 docs:
  - `docs/parity/feature-matrix.md`
  - `docs/parity/v1-scope.md`
  - `docs/roadmap/roadmap.md`

This parity cut classifies the current upstream SDK surface into:

- `v1 core`
- `v1 later`
- `deferred`
- `not applicable`

The first public implementation target is the scene-free core conversation loop, not full upstream breadth.

## Local release baseline

- Local addon version: `0.1.0`
- Release channels:
  - GitHub Release ZIP
  - Godot Asset Library via custom download provider pointing at that ZIP
- Release-prep reviewed on: `2026-04-04`
- Compatibility/support claim:
  - Godot `4.6`
  - desktop/editor workflows supported
  - exported macOS support limited to currently validated unsandboxed scenarios
- Deferred beyond release prep:
  - sessions
  - custom tool hosting
  - deeper upstream parity slices beyond the current runtime/UI surface

## Update process

For each future upstream sync review:

1. Record the new version and commit here.
2. Diff from the previously recorded commit, not from `main`.
3. Review changes in:
   - `src/claude_agent_sdk/`
   - `examples/`
   - `tests/`
   - `e2e-tests/`
4. Update `docs/parity/feature-matrix.md`.
5. Update `docs/parity/v1-scope.md` if the parity cut or implementation order changes.
6. Update ADRs or roadmap docs if upstream changes alter assumptions.
7. Record the local addon version and release date if the sync is shipped publicly.
8. Update `docs/release/release-process.md` and the changelog if the sync changes the support claim or release notes.
