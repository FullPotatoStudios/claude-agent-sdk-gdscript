# SessionStore port — Scope & Risk memo

Lens: scope and risk. Other teammates own architecture and API ergonomics.
Bottom line up front: **port a tiny slice or skip it entirely.** The full
upstream surface is mismatched to the Godot audience, and we already own the
on-disk read path via `addons/claude_agent_sdk/runtime/claude_sessions.gd`.

## 1. MVP slice

In MVP:
- `SessionStore` interface (abstract `RefCounted` with the 2 required methods
  only: append + read). 4 optional methods stay un-required; default
  implementation raises `ERR_UNAVAILABLE` like upstream's default-raises.
- `InMemorySessionStore` reference adapter — needed for tests.
- `OnDiskSessionStore` thin wrapper over existing `ClaudeSessions` — this is
  the only adapter actual Godot devs will use.
- One options field: `session_store` (the adapter instance). No flush mode
  yet; synchronous append is fine.

Deferred to v2:
- `import_session_to_store` (JSONL importer) — purely a migration tool.
- `materialize_resume_session` — only matters when a non-disk store ships.
- `validate_session_store_options` — validate lazily at first call instead.

Skipped permanently: see §10.

Justification: the integration boundary in this SDK is the CLI subprocess,
which writes JSONL itself. Unlike Python, our SDK is *not* the writer —
`ClaudeSessions` is a *reader*. Building a write-side mirror surface is
inventing problems the audience doesn't have.

## 2. Why would a Godot dev use a SessionStore?

Brutally: I can find **one** use case, maybe one and a half.

1. Editor-tool authors building plugins that talk to a remote Claude service
   and want to persist conversation history in their team's existing store
   (Postgres, etc.). Real but niche.
2. (Half) Game devs wanting NPC dialogue history persisted in the game's own
   save system — but for that they want a save-system *hook*, not the
   upstream Protocol surface. They'd write a 30-line listener on
   `ClaudeClientNode` signals.

Use cases that don't apply: multi-tenant SaaS, distributed worker pools,
long-running server processes. Godot games are single-process, single-user.

Position: **the upside is small enough that I'd accept a "skip permanently"
outcome** if the architecture teammate can show the interface bleeds into
hot paths. If we ship, ship the smallest thing.

## 3. Reference adapters

- In-memory: **ship MVP.** Required for tests; ~50 lines.
- On-disk: **ship MVP** as wrapper around `ClaudeSessions.append_*` /
  `list_sessions` / `get_session_messages`. This is the only adapter the
  audience will actually use.
- Redis / S3 / Postgres: **skip permanently.** No native Godot client; would
  require GDExtension or shelling out. Even as `tools/examples/` skeletons
  they're misleading — devs will hit the missing-driver wall.
- HTTP/REST: **defer indefinitely.** `HTTPRequest` makes it technically
  possible, but it implies an unbounded design space (auth, retry, schema)
  that we cannot maintain without a real consumer asking for it.

## 4. Mirror batcher: ship or defer?

**Defer to v2.** The batcher solves a problem (async serialisation under
high message volume) that doesn't manifest at game-loop scale. Ship
synchronous append in MVP. Loss: marginal throughput on chatty sessions;
no in-band `MirrorErrorMessage` until v2.

If the synchronous adapter ever blocks the runtime visibly we'll know
because `ClaudeClientNode` integration tests will hang — that's a real
signal, not a theoretical one.

## 5. Resume materialisation: required or optional?

For an **on-disk** store, resume already works — the CLI reads
`~/.claude/projects/...` directly, which is what `ClaudeSessions` mirrors.
No materialisation needed.

For a **non-disk** store, without `materialize_resume_session` the store is
write-only. That's fine. Position: **ship resume only when we ship a
non-disk adapter.** Since §3 says we don't, we don't need materialisation.

## 6. `continue_conversation` + store

**Ignore the combo in MVP.** Don't add a validator for an interaction 99%
of users won't trigger. If a user passes both, behave as if no store
(continue still works via on-disk path). Document, don't validate.

## 7. Versioning bumps

**Option (d): one PR per logical unit, batched aggressively.** Reviewers
are PR-fatigued (the previous batch landed 11 PRs). Concrete plan:
- PR 1: interface + InMemory + OnDisk + tests. *This is the whole MVP.*
- PR 2 (only if v2 happens): batcher + eager flush + MirrorErrorMessage.
- PR 3 (only if v2 happens): import + materialize + validator.

That's 1 PR for the slice that ships, 3 PRs total if we ever do v2. Avoid
upstream's 4-version mirror — bisection across our own commits matters
more than mapping to their releases. The upstream-ledger entry can list
"ported in MVP" / "deferred indefinitely" per upstream version.

## 8. What can break — top 3 risks + mitigations

1. **`ClaudeSessions` semantics drift** if we route the on-disk path
   through a `SessionStore` wrapper. The static API is documented as the
   supported path. Mitigation: `OnDiskSessionStore` is a *wrapper*, not a
   replacement; existing `ClaudeSessions.*` callers stay untouched. Add a
   parity test pinning identical observable output.
2. **Buggy custom store stalls the runtime.** Mitigation: every store call
   wrapped in a timeout-bounded `call_deferred` path or, simpler, document
   "stores must not block; use threads if they do" and add a watchdog test.
3. **Two resume paths bitrot.** Mitigation: don't add a second path. §5
   says we ship only the on-disk adapter, so resume stays single-path.

## 9. Test cost

MVP test count estimate:
- Interface contract (3) + InMemory (5) + OnDisk wrapper / parity vs
  ClaudeSessions (8) + options wiring (3) + ClaudeClientNode integration
  (3) ≈ **22 new tests**. Comfortably under 50.

If the count creeps over 35, that's a smell — re-cut the slice.

## 10. Defer-permanently table

| Piece | Decision | Reason |
|---|---|---|
| Postgres / Redis / S3 reference adapters | **skip permanently** | no native Godot client; misleading examples |
| Batch session summaries (multi-session reads) | **ship v2** | low-effort once interface lands, no MVP demand |
| Eager flush mode | **defer indefinitely** | only meaningful with batcher |
| `validate_session_store_options` | **ship v2** | premature in MVP; lazy errors suffice |
| In-band `MirrorErrorMessage` | **ship v2** | requires batcher to even be reachable |

## 11. End-state acceptance criteria

1. Devs can pass a `session_store` to `ClaudeAgentOptions` and observe each
   message appended to it via the adapter.
2. `OnDiskSessionStore` produces JSONL byte-equivalent to existing
   `ClaudeSessions` paths for identical message streams (parity test).
3. `InMemorySessionStore` round-trips a session: append → list → read.
4. Existing `ClaudeSessions.*` static API behaviour unchanged (regression
   suite green).
5. `docs/parity/upstream-ledger.md` entry lists which upstream
   versions/symbols are MVP, v2-deferred, or skipped — with rationale.
6. No new third-party dependencies introduced into `addons/`.

## 12. Counterfactual — what we lose by not porting

- Upstream tutorial sections that wire a custom store to Claude Agent SDK
  do not translate. Workaround: signal-listener pattern on
  `ClaudeClientNode` — already idiomatic in Godot.
- The "swap on-disk for Redis in production" story doesn't translate.
  This is **not** a Godot story; nobody loses anything real.
- `import_session_to_store` migration tutorial — irrelevant without a
  non-disk store.

Sized honestly, the counterfactual cost is *low*. That's the strongest
argument for the minimal slice in §1, and a defensible argument for
**not porting at all** if architecture review surfaces meaningful blast
radius into the runtime.

**My recommendation: ship the §1 MVP, behind a "v2-pending" note in the
ledger, and resist any pressure to grow it before a real Godot user
asks.**
