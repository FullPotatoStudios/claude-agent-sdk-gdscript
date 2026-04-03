# Release Process

## Summary

Phase 8 release work treats the GitHub Release ZIP as the canonical install artifact and keeps Asset Library submission aligned with that same ZIP.

## Release checklist

1. Ensure the worktree is in the intended release state.
2. Update:
   - `addons/claude_agent_sdk/VERSION`
   - `CHANGELOG.md`
   - `docs/parity/upstream-ledger.md`
3. Run repo regression checks:
   - `./tools/dev/run_tests.sh`
4. Build the release artifact:
   - `./tools/release/build_release.sh`
5. Validate the packaged addon in a fresh temp project:
   - `./tools/release/validate_release.sh`
6. Run the manual authenticated CLI checklist in a clean Godot project.
7. Prepare GitHub release notes from `docs/release/release-notes-template.md`.
8. Upload:
   - the ZIP artifact
   - `SHA256SUMS.txt`
9. Update the Asset Library listing metadata so it points at the GitHub Release ZIP through the custom download provider flow.

## Compatibility statement

Use this wording unless a release changes the support claim:

- Godot `4.6`
- desktop/editor workflows supported
- exported macOS support limited to the validated unsandboxed scenarios
- requires a user-installed `claude` CLI and existing Claude auth

## Manual authenticated validation

1. Create a clean Godot project outside this repo.
2. Install the packaged addon under `res://addons/claude_agent_sdk/`.
3. Instantiate `ClaudeChatPanel`.
4. Verify auth status renders correctly.
5. Connect a live session.
6. Send a baseline prompt.
7. Confirm partial-message rendering still works.
8. Confirm structured-output rendering still works.

## Known limitations section

Each public release note should include a concise limitations section covering:

- CLI dependency
- Godot `4.6` support target
- unsupported mobile/web/App Store-sandboxed workflows
- any still-deferred parity areas relevant to consumers
