# Phase 1 Findings

## Summary

Initial feasibility looks promising.

In a local headless Godot probe, Godot successfully:

- launched the Claude CLI as a subprocess
- wrote `stream-json` control and user messages to stdin
- received multiple streamed JSON messages from stdout
- parsed a control initialize response
- observed the CLI `system/init` message
- observed a terminal `result` message
- completed without blocking the event loop

This is enough to keep the current transport direction alive.

## Local environment used

- Godot binary: a local Godot 4.6.1 desktop install
- Godot version: `4.6.1.stable.official.14d19694e`
- Claude CLI path: a local `claude` executable available on `PATH` or passed explicitly
- Claude CLI version: `2.1.90`

## Probe artifact

- `tools/spikes/godot_cli_pipe_probe.gd`

Example invocation:

```bash
HOME=/tmp/godot-home \
XDG_DATA_HOME=/tmp/godot-home \
XDG_CONFIG_HOME=/tmp/godot-config \
XDG_CACHE_HOME=/tmp/godot-cache \
"$GODOT_BIN" \
  --headless \
  --path . \
  --script res://tools/spikes/godot_cli_pipe_probe.gd \
  -- \
  --claude-path=/path/to/claude
```

The spike launches Claude with:

- `--output-format stream-json`
- `--input-format stream-json`
- `--verbose`
- `--tools ""`
- `--max-turns 1`

It then sends:

1. an `initialize` control request
2. one user message

It polls the redirected pipes in non-blocking mode until a terminal `result` message is seen or the timeout is reached.

## Observed result

The local probe observed all of the following in one run:

- `control_response` for initialize
- `system/init`
- `assistant`
- `result`

The run ended with authentication failure because the local Claude session was not logged in, but that did not prevent validation of the subprocess and message-stream mechanics.

## Important caveat

Godot crashed under the Codex sandbox when run with its default macOS user-data path, because it tried to create directories outside the writable sandbox roots.

The probe worked once Godot was launched with writable overrides:

- `HOME=/tmp/godot-home`
- `XDG_DATA_HOME=/tmp/godot-home`
- `XDG_CONFIG_HOME=/tmp/godot-config`
- `XDG_CACHE_HOME=/tmp/godot-cache`

This appears to be a local execution-environment constraint, not a project architecture problem, but it is worth remembering for automated validation.

## Recommendation after the first probe

Proceed with the current architecture direction:

- scene-free core
- explicit transport abstraction
- Godot adapters at the boundary

But keep the following open until Phase 1 is fully closed:

- exact CLI discovery policy
- supported platform/export matrix
- exported macOS behavior

## Initial support recommendation

For v1 planning, assume:

- supported first: local desktop development environments
- likely supported first: editor use and headless validation
- unproven: exported desktop applications
- especially risky: macOS sandboxed exports that may restrict launching external executables
- out of scope for v1 unless proven otherwise: web and mobile

## CLI provisioning recommendation

Current best direction:

- require a user-installed Claude CLI for v1
- support configurable CLI paths
- do not plan on bundling the CLI in the addon yet

This keeps the addon lighter and avoids making packaging decisions before the transport story is stable.

## Next Phase 1 tasks

1. Make the probe easier to run and document the invocation.
2. Investigate exported desktop implications, especially macOS.
3. Define the initial support matrix explicitly.
4. Decide the v1 CLI path/discovery policy.
5. Move into upstream feature mapping once those decisions are stable.
