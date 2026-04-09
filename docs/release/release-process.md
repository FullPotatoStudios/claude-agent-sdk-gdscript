# Release Process

## Summary

Phase 8 release work treats the GitHub Release ZIP as the canonical install artifact and keeps Asset Library submission aligned with that same ZIP.

## Release checklist

1. Ensure the worktree is in the intended release state.
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
7. Let GitHub Actions publish:
   - the ZIP artifact
   - `SHA256SUMS.txt`
   - generated release notes
8. Update the Asset Library listing metadata using the generated summary and custom download provider flow.

For normal commit preparation, use `docs/contributing/maintainer-workflow.md`.

## Compatibility statement

Use this wording unless a release changes the support claim:

- Godot `4.6`
- desktop/editor workflows supported
- exported macOS support limited to the validated unsandboxed scenarios
- requires a user-installed `claude` CLI and existing Claude auth

## Manual authenticated validation

Run this locally before creating or pushing the release tag:

```bash
./tools/release/validate_live_cli.sh
```

For targeted authenticated reruns while investigating a later smoke mode, you can
repeat `--mode <name>` without changing the default full-wrapper pre-tag check:

```bash
./tools/release/validate_live_cli.sh --mode context_usage --mode mcp_status
```

## Known limitations section

Each public release note should include a concise limitations section covering:

- CLI dependency
- Godot `4.6` support target
- unsupported mobile/web/App Store-sandboxed workflows
- any still-deferred parity areas relevant to consumers

## Automation direction

- prefer the checked-in release scripts over ad hoc commands
- keep local live Claude validation as the explicit pre-tag check
- keep final Asset Library submission as the last manual step
