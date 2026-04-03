# Phase 7 Validation

## Summary

Phase 7 added the first addon-owned UI layer:

- reusable `ClaudeChatPanel` under `addons/claude_agent_sdk/ui/`
- root-project demo scene under `demo/`
- dedicated UI tests for the panel and demo scene

The root Godot project now opens the Phase 7 demo by default.

## Automated validation

Automated coverage now includes:

- panel instantiation and owned client-node creation
- pre-tree `setup()` with fake transport
- logged-in, logged-out, and transport-issue auth-state rendering
- connect/disconnect state transitions
- prompt submission and transcript updates
- partial-message coalescing into a single assistant bubble
- result-card rendering for structured output and reported errors
- interrupt-button busy-state behavior
- demo-scene loading and direct use of the shipped panel

Current local result:

- `./tools/dev/run_tests.sh`
- result: `55/55` tests passing

Known local warning:

- Godot still prints the non-fatal ObjectDB snapshot-directory warning in this environment

## Runtime smoke regression

Phase 7 kept the existing runtime smoke path intact.

Validated modes:

- `baseline`
- `structured`
- `partial`

Expected acceptance:

- `baseline`: successful result from the real authenticated CLI path
- `structured`: successful result with non-null `structured_output`
- `partial`: successful result with real `ClaudeStreamEvent` output before the final result

Current sandbox note:

- a rerun in this Codex sandbox with a writable temporary Godot home succeeded mechanically but still returned `Not logged in`
- the temporary-home workaround is enough for Godot file writes, but it does not fully reproduce the real authenticated Claude home state here
- the authenticated real-environment smoke success remains documented in `docs/investigations/phase-5-validation.md`

## Manual validation

Automated coverage now proves that the demo scene loads and uses the shipped panel, but normal interactive GUI validation still needs to be run manually in a local Godot session.

Manual Phase 7 acceptance remains:

- launch the root project normally
- verify auth banner and refresh flow
- connect successfully
- submit prompts through the panel
- observe streaming assistant output
- verify interrupt state during an active turn
- verify structured-output rendering in the result card

## Scope note

The chat panel and demo are now implemented project outputs, but they remain outside the scene-free upstream core-parity target:

- `addons/claude_agent_sdk/` remains the distributable addon payload
- `demo/` remains root-project validation content rather than required addon payload
