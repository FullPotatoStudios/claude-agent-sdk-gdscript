# Automation

## Summary

This project uses repo-managed shell scripts as the source of truth for automation. Local hooks, GitHub Actions, and release publishing should call the same scripts instead of duplicating logic.

## Canonical script entrypoints

### Fast local checks

- `./tools/dev/check_docs.sh`
- `./tools/dev/run_fast_checks.sh`

Use these for quick local validation that does not require Godot, GdUnit4, network access, or Claude auth.

### Full deterministic validation

- `./tools/dev/run_push_checks.sh`

This is the normal branch/push validation path. It installs GdUnit4 if needed, runs the full test suite, builds the release ZIP, and validates the packaged addon in a clean temp project.

### Local authenticated Claude validation

- `./tools/release/validate_live_cli.sh`

This is the local-only authenticated runtime smoke. It now covers the original `baseline`, `structured`, and `partial` modes plus first-slice parity checks for `agents`, default `setting_sources`, explicit project/local `setting_sources`, and filesystem agents loaded from `.claude/agents/`, all against the real installed Claude CLI using the real local environment.

### Release prep

- `./tools/release/verify_release_metadata.sh`
- `./tools/release/render_release_metadata.sh`
- `./tools/release/prepare_release.sh`

`prepare_release.sh` is the canonical release-prep entrypoint. It validates release metadata, runs deterministic checks, runs the authenticated Claude validation, checks upstream drift, renders release notes, and can create the annotated release tag.

## Local git hooks

Install the repo-managed hooks with:

```bash
./tools/dev/install_git_hooks.sh
```

This configures `core.hooksPath` to `.githooks`.

Current behavior:

- `pre-commit` runs `./tools/dev/run_fast_checks.sh`
- `pre-push` runs `./tools/dev/run_push_checks.sh`
- pushing version tags also runs `./tools/release/verify_release_metadata.sh --tag <tag>`

Hooks are opt-in per clone. GitHub Actions remains the shared mandatory gate.

## GitHub workflows

### CI

`.github/workflows/ci.yml` runs on pull requests and pushes to `main`.

It:

- installs Godot `4.6`
- installs GdUnit4
- runs fast checks
- runs full deterministic push checks
- uploads CI artifacts

### Release

`.github/workflows/release.yml` runs on pushed `v*` tags.

It:

- verifies release metadata
- runs deterministic release checks
- renders release notes and Asset Library summary
- publishes the GitHub Release ZIP and checksum

### Upstream drift

`.github/workflows/upstream-drift.yml` runs weekly or on manual dispatch.

It checks for drift from the pinned upstream Python SDK baseline and uploads a summary artifact.

## Manual boundary

The remaining manual steps are intentional:

- run the local authenticated Claude validation before pushing a release tag
- update the Godot Asset Library listing with the generated summary output

Everything else in the release flow should be script-driven or GitHub-driven.
