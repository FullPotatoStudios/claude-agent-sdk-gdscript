# Phase 1 Support Matrix

## Purpose

This document narrows the initial target platforms and distribution assumptions for the addon based on the first subprocess feasibility work and Godot's platform documentation.

## Initial matrix

| Scenario | Status | Notes |
| --- | --- | --- |
| Godot editor on desktop development machines | Likely supported | Best initial target for addon development and validation. |
| Headless desktop validation runs | Supported in principle | Confirmed locally with the feasibility probe. |
| Exported desktop app on Linux | Plausible, unverified | Needs direct validation, but external process launching is conceptually aligned with the transport approach. |
| Exported desktop app on Windows | Plausible, unverified | Needs validation. No current blocker identified, but should be tested explicitly. |
| Exported desktop app on macOS, unsandboxed | Partially validated | Headless packaged-app probe succeeded locally; GUI-mode behavior and signing remain open. |
| Exported desktop app on macOS with App Sandbox enabled | Not a viable v1 target for external `claude` | Sandboxed apps are limited to embedded helper executables. |
| App Store distribution on macOS | Not a viable v1 target | Requires sandboxing, which conflicts with launching an external user-installed Claude CLI. |
| Web export | Out of scope / unsupported | `OS.execute_with_pipe()` is not available on Web. |
| Mobile export | Out of scope for v1 | Even where process APIs exist, the Claude CLI distribution model is not a fit. |

## macOS implications

macOS is the platform that most needs explicit scoping.

From Godot's docs:

- `OS.execute_with_pipe()` is implemented on desktop platforms including macOS.
- On macOS, sandboxed apps are limited to running embedded helper executables.
- In exported sandboxed apps, helper executables must be declared during export.
- Gatekeeper path randomization can break reliance on relative paths from the `.app` bundle.

Practical consequence:

- A macOS-exported app that expects to launch a user-installed `claude` binary from somewhere on the system should not be treated as compatible with App Sandbox or App Store distribution.
- If exported macOS support is desired in v1, the realistic target is unsandboxed desktop distribution first.
- Even in unsandboxed builds, the addon should avoid relative executable assumptions and support explicit CLI path configuration.
- In a packaged exported run, Claude saw the current working directory as the app bundle's `Contents/Resources` directory, not the original project root.

## CLI policy recommendation

For v1:

- require a user-installed Claude CLI
- default to resolving `claude` from `PATH`
- fall back to the same common local install locations tracked by upstream when `PATH` does not expose `claude`
- allow an explicit override path in addon configuration
- do not plan around bundling the CLI yet

This is the simplest path that fits the current addon goal and avoids prematurely designing around macOS helper-executable packaging.

## Proposed v1 CLI configuration surface

The canonical v1 shape should follow the Phase 2 scope docs and use:

- `cli_path: String = "claude"`
- `env: Dictionary = {}`

Recommended behavior:

- resolve the CLI from `PATH` by default
- if `PATH` lookup misses, try the upstream-style fallback locations before failing
- allow an absolute override path when needed
- inherit the host process environment by default so existing Claude CLI auth and shell configuration can flow through
- treat `env` as additive overrides layered on top of the inherited environment
- do not rewrite `HOME` or `XDG_*` paths in the normal runtime path

This mirrors the most important practical behavior observed in `t3code-analysis`:

- it stores a Claude `binaryPath`
- it launches the Agent SDK with that path
- it forwards `env: process.env`

That supports the user's claim that a sibling app can rely on the already installed/authenticated Claude CLI without an extra auth mechanism.

Earlier draft names such as `binary_path`, `inherit_environment`, and `extra_env` should be treated as superseded planning language rather than the implementation target.

## Testing implications

- All transport tests should read both stdout and stderr.
- macOS exported-app validation deserves its own checkpoint, not just editor validation.
- Auth and transport should be tested separately when possible.
- Probe runs should use the cheapest model configuration by default: `haiku` with `low` effort.
- Export validation should distinguish between headless packaged execution and interactive GUI launches.
- Auth-sensitive validation should keep the real user environment and redirect Godot logs with `--log-file` instead of isolating `HOME`.

## Auth diagnostics implication

The runtime now exposes an explicit Claude auth-status probe so callers can distinguish:

- a healthy authenticated Claude CLI
- a logged-out Claude CLI caused by environment isolation or real logout
- a transport or command-launch failure

## Local evidence worth carrying forward

An existing Godot experiment in another local project already encountered an `OS.execute_with_pipe()` failure mode caused by not draining `stderr` from a child process chain. That reinforces a design rule for this project:

- always handle both stdout and stderr from spawned Claude-related processes

## Open questions

1. What exact exported desktop scenarios do we want to claim in the first public release?
2. Do we want explicit project settings for CLI path discovery and validation?
3. Should macOS exported support remain experimental until verified with signed app bundles and GUI-mode launches?

## Reference sources

- Godot `OS.execute_with_pipe()` and related process APIs
- Godot export documentation for macOS App Sandbox and helper executables
- Godot macOS runtime guidance around Gatekeeper and path randomization
