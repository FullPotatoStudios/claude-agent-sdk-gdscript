# SessionStore port — API Ergonomics memo

Lens: how a Godot dev discovers, calls, and trips over this surface.
Anchor files: `addons/claude_agent_sdk/runtime/sessions/claude_sessions.gd`,
`addons/claude_agent_sdk/runtime/claude_agent_options.gd`,
`addons/claude_agent_sdk/runtime/adapters/claude_client_adapter.gd`,
`addons/claude_agent_sdk/ui/claude_chat_panel.gd`.

## 1. Discoverability — pick (c), with shim alias

Doubling `ClaudeSessions.*` autocomplete to 22 items is hostile. Position:

- **Primary surface = a `ClaudeSessionStore` instance.** Devs hold a store and call
  `store.list_sessions()`, `store.rename_session(id, title)`, etc.
- **`ClaudeSessions.*` statics stay** as the disk-backed implementation —
  unchanged, no deprecation. They are the "no store, just user://" path most
  Godot games will keep using.
- A thin **`ClaudeSessions.with_store(store)`** factory returns a wrapper that
  exposes the same 11 method names but routes through the store. This way
  existing tutorials (`ClaudeSessions.list_sessions()`) keep compiling, and the
  store path reads as `ClaudeSessions.with_store(s).list_sessions()` — same
  vocabulary, no `_from_store` / `_via_store` naming churn.

Reject (a): suffix soup on a static class is the worst autocomplete UX.
Reject (b): one method that switches behavior on a `null` arg hides intent and
breaks type hints. Reject (d): an "engine" object adds a third noun
(`Sessions` vs `Store` vs `Engine`) for no payoff.

## 2. Error contract — return `Variant`, keep `get_last_error()`

Stay with the house style. `ClaudeSessions` already returns `int` for
mutations and raw values for reads, with a sticky `get_last_error()` probe.
The store wrapper inherits exactly that contract:

- Mutations (`append`, `delete`, `rename_session`, `tag_session`, …) return
  `int` (`OK` / negative ERR_*).
- Reads (`load`, `list_sessions`, …) return their natural type or `null` /
  empty array on failure, and the wrapper sets `ClaudeSessions.get_last_error()`
  *and* a sibling `store.get_last_error()` (per-store, since two stores can
  coexist).
- Adapter authors raising / pushing errors are caught by the wrapper and
  funnelled into the same channel.

A boxed `ClaudeSessionStoreResult { ok, error, value }` is tempting but breaks
parity with every other API in the addon. Don't break consistency for one
subsystem.

## 3. Optional-method probing — explicit capability bitmask, no silent fallback

Silent `load`-each fallback is a footgun: someone's S3 bill explodes because
their `list_session_summaries` got NotImplementedError-swallowed.

Design:

```gdscript
class_name ClaudeSessionStore extends RefCounted

const CAP_LIST_SESSIONS      := 1 << 0
const CAP_LIST_SUMMARIES     := 1 << 1
const CAP_LIST_SUBKEYS       := 1 << 2
const CAP_DELETE             := 1 << 3

func capabilities() -> int: return CAP_LIST_SESSIONS  # author overrides
```

`ClaudeSessions.with_store(s).list_session_summaries()` checks the bit:

- bit set → call through.
- bit unset and caller passed `fallback := true` (default `false`) → run the
  load-each path with a `push_warning` once per session.
- bit unset, no fallback → return `null`, `get_last_error()` reports
  `"capability CAP_LIST_SUMMARIES not implemented"`.

This gives custom-store authors a single answer to "did I implement enough":
`assert(store.capabilities() & required_caps == required_caps)`.

## 4. Async — pick (b) but make sync the default sugar

Position: ship **both surfaces**, sync wins discoverability, async wins
correctness. The static disk path stays sync (no I/O backpressure to fix).
Store-backed methods exist in two flavors:

- `store.list_sessions()` — sync. Documented as "blocks; fine for editor
  tooling and `user://` adapters, dangerous for network adapters."
- `await store.list_sessions_async()` — coroutine, returns the same value;
  for Redis/S3/HTTP.

Tutorials open with the sync form (one line, no `await`, looks like the rest
of `ClaudeSessions`). Adapter docs flip to `_async` the moment a network
adapter shows up. Adapters declare `is_blocking_safe() -> bool`; the wrapper
`push_warning`s if you call sync on an unsafe store.

Reject (a) blanket-block: editor jank on remote stores is a support ticket
factory. Reject (c) signal-only: signals are right for `ClaudeClientNode` but
wrong as the *only* surface — they force every caller to be a Node.

## 5. Custom store — 30-line skeleton

```gdscript
extends ClaudeSessionStore
class_name UserDirSessionStore

const _DIR := "user://claude_sessions"

func capabilities() -> int:
    return CAP_LIST_SESSIONS | CAP_DELETE  # opt in to what you handle

func is_blocking_safe() -> bool: return true  # disk is fine sync

# REQUIRED
func append(key: String, entries: Array) -> int:
    DirAccess.make_dir_recursive_absolute(_DIR)
    var f := FileAccess.open("%s/%s.jsonl" % [_DIR, key], FileAccess.READ_WRITE)
    if f == null: f = FileAccess.open("%s/%s.jsonl" % [_DIR, key], FileAccess.WRITE)
    if f == null: return ERR_CANT_OPEN
    f.seek_end()
    for e in entries: f.store_line(JSON.stringify(e))
    return OK

# REQUIRED
func load(key: String) -> Array:
    var path := "%s/%s.jsonl" % [_DIR, key]
    if not FileAccess.file_exists(path): return []
    var out: Array = []
    var f := FileAccess.open(path, FileAccess.READ)
    while not f.eof_reached():
        var line := f.get_line()
        if line.is_empty(): continue
        out.append(JSON.parse_string(line))
    return out

# OPTIONAL — only if CAP_DELETE set
func delete(key: String) -> int:
    return DirAccess.remove_absolute("%s/%s.jsonl" % [_DIR, key])
```

Two abstract methods, everything else opt-in via capability bits. The class
ships with `# REQUIRED` / `# OPTIONAL` comments in the base file so
autocomplete-driven discovery works.

## 6. `session_store_flush` — String + normalizer

Match `permission_mode: String = ""` precedent in
`claude_agent_options.gd:17`. Use:

```gdscript
var session_store_flush: String = "batched"  # _normalize accepts "batched"|"eager"
```

Reject the enum (forces a `ClaudeAgentOptions.FLUSH_EAGER` symbol that doesn't
match any sibling field). Reject the bool (`eager_session_store_flush=true`
hides the third future value, e.g. `"interval"`).

## 7. Mirror error UX — toast + log, never inline bubble

`MirrorErrorMessage` in the chat scroll is noise and panics non-technical
players. Design:

- `ClaudeChatPanel` filters `MirrorErrorMessage` out of the bubble list,
  forwards to a new `mirror_error(message)` signal.
- A small status pill in the panel header (red/amber dot) + a toast on first
  occurrence per session. Subsequent identical errors increment a counter,
  not the bubble stream.
- Always written to the SDK log. A "Show mirror diagnostics" debug toggle
  re-enables inline bubbles for adapter authors.

Graceful degradation: store goes down → eager flush flips to in-memory queue,
panel shows "session not synced" pill, on next successful append the queue
drains. User keeps chatting; nothing blocks.

## 8. `import_session_to_store` — runtime API first, editor action second

Order of work: (1) GDScript runtime API
`ClaudeSessionStoreMigrator.import(session_id, store, opts)` returning a
RefCounted with a `progress(current, total)` and `finished(result)` signal.
(2) Editor dock button "Import sessions to store…" calling the same API.
(3) Headless CLI is third — most Godot users will not touch a CLI.

Errors: **continue with errors logged**, finish with a `MigrationReport`
containing `failed_ids: Array[String]`. Fail-fast leaves users half-migrated
with no easy resume.

Progress UI: ProgressBar + "37 / 412 sessions" label, cancel button. Silent
mode is a `quiet := true` opt-in.

## 9. Docs surface

- `README.md` Supported Features: add a top-level **"Pluggable session
  storage"** bullet near the existing sessions row.
- `docs/parity/feature-matrix.md`: new "SessionStore" section with the 9
  helpers as rows and a capabilities column.
- New tutorial `docs/tutorials/custom-session-store.md` walking the 30-line
  skeleton above.
- Tagline: **"Ship a Claude-powered Godot game where conversations live in
  your save file, your backend, or your team's Postgres — not just on the
  player's `user://`."**

## 10. Top three footguns

1. **Same store, two `ClaudeAgentOptions`.** Two clients write interleaved
   `append`s to the same key. Heads-off: store carries a weak ref-count of
   active owners; assigning to a second `ClaudeAgentOptions` while
   `owners > 0` `push_error`s and the second assignment is rejected unless
   `allow_shared := true` is set explicitly.
2. **`append` implemented, subagent subkeys ignored.** Devs handle the parent
   `key` and silently drop `key + "/agents/<id>"` writes. Heads-off:
   `ClaudeSessionStore.append` base impl `assert`s subkey routing; the
   30-line skeleton's `append` shows the subkey case. Conformance test
   shipped in `tests/runtime/`.
3. **RefCounted store across scene reload.** Player saves, scene reloads, the
   store instance is freed mid-flush, half-written JSONL on disk. Heads-off:
   `ClaudeSessionStore` exposes `make_autoload()` helper that registers the
   store as a singleton; tutorial leads with it. Wrapper detects a freed
   store on call and returns `ERR_INVALID_DATA` with a clear message rather
   than crashing.
