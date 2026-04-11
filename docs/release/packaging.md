# Packaging Guide

## Canonical artifact

The canonical install artifact is a ZIP containing only:

- `addons/claude_agent_sdk/`

Nothing else from the repository should ship inside the release archive.

The root-project `demo/` remains validation/reference content and does not ship inside the addon payload.

## Included content

The packaging flow includes the verbatim addon subtree, including:

- `.gd`, `.tscn`, `.tres`, and README files
- `.uid` files
- tracked `.import` files that live inside `addons/claude_agent_sdk/`
- `VERSION`
- `LICENSE.txt`
- `NOTICE.txt`

## Excluded content

The packaging flow must exclude:

- `demo/`
- `tests/`
- `tools/`
- `addons/gdUnit4/`
- root project files such as `project.godot`, `export_presets.cfg`, and release tooling itself

## Commands

Build the release ZIP:

```bash
./tools/release/build_release.sh
```

Validate the packaged addon in a fresh temporary Godot project:

```bash
./tools/release/validate_release.sh
```

By default the build output lands under:

- `.artifacts/release/v<version>/`

The build flow also writes:

- `SHA256SUMS.txt`

## Version source

The addon version is sourced from:

- `addons/claude_agent_sdk/VERSION`

Release scripts should read this file instead of accepting an ad hoc version override.

## Compatibility wording

Use the same baseline wording across README, addon README, release notes, and Asset Library metadata:

- Godot `4.6`
- desktop/editor workflows supported
- exported macOS support limited to the validated unsandboxed scenarios
- requires a user-installed `claude` CLI and existing Claude auth state
