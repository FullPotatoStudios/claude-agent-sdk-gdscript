# Godot Asset Library Guide

## Submission strategy

The Godot Asset Library listing should reference the same GitHub Release ZIP used for direct installs.

The intended flow is:

1. Build the canonical ZIP from `addons/claude_agent_sdk/`.
2. Publish that ZIP in a GitHub Release.
3. Configure the Asset Library entry to use a custom download provider pointing at the GitHub Release asset.

This keeps GitHub and Asset Library installs aligned to one tested payload.

Machine-readable listing metadata lives in:

- `docs/release/asset-library.json`

Release automation renders:

- `.artifacts/release/vX.Y.Z/ASSET_LIBRARY_SUMMARY.md`

Use that generated summary as the source for the final manual listing update.

## Listing requirements to prepare

- title and short description
- compatibility statement for Godot `4.6`
- repository URL
- issue tracker/support URL
- license reference
- addon icon
- screenshots captured from the shipped demo/panel
- download URL for the GitHub Release ZIP

These values should stay aligned with `docs/release/asset-library.json` and the generated summary.

## Packaging rule

Do not rely on the repository root layout as the install payload.

The submitted/installable content must resolve to:

- `res://addons/claude_agent_sdk/`

## Current assumptions

- `plugin.cfg` is still intentionally absent because the addon is currently a runtime/UI payload rather than an editor plugin
- if Asset Library review proves `plugin.cfg` is mandatory for this submission type, revisit that decision in a follow-up phase rather than silently changing the addon shape here
- the Asset Library install path must remain identical to the GitHub Release ZIP install path
- `demo/` content is not part of the submitted addon payload
- final Asset Library submission remains manual in this slice; only the metadata preparation is automated

## Compatibility/support wording

Use this baseline wording for the listing unless a release changes it:

- Godot `4.6`
- desktop/editor workflows supported
- exported macOS support limited to the validated unsandboxed scenarios
- requires a user-installed `claude` CLI
- mobile, web, and App Store-sandboxed macOS workflows are out of scope
