# Phase 1: Godot-to-Claude CLI Feasibility

## Purpose

Before porting the Python SDK, prove that Godot can drive the Claude CLI with enough fidelity to support the SDK's streaming/control-protocol design.

## Questions to answer

1. Can Godot launch the Claude CLI in a way that supports bidirectional communication?
2. Can Godot read streaming JSON messages incrementally without blocking the main thread?
3. Can Godot write user/control messages to the CLI stdin reliably?
4. Can interruption, shutdown, and stream completion be modeled safely?
5. What platforms should be supported initially?
6. Is the initial target editor-only, desktop export, or both?
7. Should the addon require a system-installed `claude` binary, or support configurable paths, or both?

## Acceptance criteria

Phase 1 is successful if we can show all of the following:

- a Godot spike can start the Claude CLI with redirected IO
- the spike can send at least one prompt over stdin or the chosen startup path
- the spike can receive multiple streamed JSON messages from stdout
- the spike can avoid freezing the main thread while reading
- the spike can shut down cleanly
- known platform restrictions are documented

## Early risks

- Godot process APIs may be awkward for long-lived bidirectional streams.
- Exported desktop apps, especially on macOS, may impose process-launch restrictions.
- The CLI installation story may materially affect addon usability.
- If streaming is unreliable, the architecture may need to narrow scope or change approach.

## Planned outputs

- a feasibility spike or prototype
- a written findings summary
- an initial support matrix
- a recommendation on whether to proceed with the planned transport architecture
