# Phase 8 Validation

This document records the first release-packaging and packaged-consumer validation work.

## Goals

- prove that the addon can be packaged as a standalone `addons/claude_agent_sdk/` payload
- prove that the packaged addon can be installed into a fresh Godot project outside this repo
- lock the release workflow around a canonical ZIP artifact plus checksum

## Validation commands

```bash
./tools/release/build_release.sh --allow-dirty
./tools/release/validate_release.sh
./tools/release/check_upstream_diff.sh
./tools/dev/run_tests.sh
```

## Acceptance targets

- release ZIP contains only `addons/claude_agent_sdk/`
- checksum file is generated beside the ZIP
- packaged addon loads in a fresh temporary Godot project
- packaged `ClaudeChatPanel`, `ClaudeClientNode`, `ClaudeClientAdapter`, and `ClaudeAgentOptions` instantiate successfully
- the packaged panel can become ready against a temporary fake transport without repo-local support files

## Results

Date reviewed: 2026-04-04

- `./tools/release/build_release.sh --allow-dirty` succeeded and produced:
  - `.artifacts/release/v0.1.0/claude-agent-sdk-gdscript-v0.1.0.zip`
  - `.artifacts/release/v0.1.0/SHA256SUMS.txt`
- ZIP contents were spot-checked with `unzip -Z1` and contained only the distributable `addons/claude_agent_sdk/` subtree.
- `./tools/release/validate_release.sh` succeeded in a fresh temporary Godot project outside the repo tree.
- The packaged consumer validation instantiated:
  - `ClaudeAgentOptions`
  - `ClaudeClientAdapter`
  - `ClaudeClientNode`
  - `ClaudeChatPanel`
- The packaged panel became ready against a temporary fake transport without relying on repo-local test helpers.
- `./tools/release/check_upstream_diff.sh` reported no upstream drift from the pinned Python SDK commit.
- `./tools/dev/run_tests.sh` passed with `62/62` test cases.

## Notes

- the packaged-consumer validation intentionally uses a temporary fake transport so it validates installability independently of local Claude auth state
- manual real-CLI validation should still be run in a clean Godot project before publishing a public release
- Godot still emits non-blocking ObjectDB/resource warnings at process exit in headless validation runs; these did not prevent packaging or consumer validation success

## Review status

- A follow-up Phase 8 review did not identify a release-blocking packaging or versioning defect in the current implementation.
- The main remaining follow-up work is documentation and maintainer-workflow polish:
  - make the root `README.md` user-facing instead of roadmap-heavy
  - add a canonical maintainer workflow doc for commit and release preparation
  - keep automation as a planned next slice rather than implying local hooks or GitHub release workflows already exist
