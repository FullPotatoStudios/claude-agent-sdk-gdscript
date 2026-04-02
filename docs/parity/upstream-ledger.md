# Upstream Ledger

## Current baseline

- Upstream repository: `https://github.com/anthropics/claude-agent-sdk-python`
- Local reference checkout: a sibling checkout of the upstream repo, if available
- Version: `v0.1.54`
- Commit: `574044a1fcbaf89afc821bb742ccd8d31c4d6944`
- Reviewed on: `2026-04-02`
- Local project phase at pin time: preliminary work / Phase 1 feasibility

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
5. Update ADRs or roadmap docs if upstream changes alter assumptions.
