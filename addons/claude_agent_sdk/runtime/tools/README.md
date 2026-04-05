# Built-In Tool Catalog

This directory contains scene-free helpers for Claude Code's built-in tool catalog.

- `ClaudeBuiltInToolCatalog` is the shared runtime source of truth for:
  - the current default Claude Code built-in tool list
  - per-tool display/grouping metadata
  - selection/config mapping helpers that custom panels can reuse

The shipped `ClaudeChatPanel` uses this catalog, but the helper is not panel-specific.
