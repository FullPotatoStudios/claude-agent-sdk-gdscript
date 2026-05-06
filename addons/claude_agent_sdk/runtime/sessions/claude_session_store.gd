extends RefCounted
class_name ClaudeSessionStore

# Abstract pluggable session storage interface.
#
# This is the GDScript MVP slice of upstream Python's `SessionStore` Protocol
# (v0.1.64). Subclasses must implement `append` and `load`. Optional methods
# (`delete`, `list_sessions`, `list_session_summaries`, `list_subkeys`) report
# capability through `capabilities()` and `ERR_UNAVAILABLE` from the default
# bodies. See `docs/investigations/session-store-scope-risk-memo.md` for the
# scope decision and what is intentionally deferred to v2.
#
# REQUIRED methods (default bodies assert):
#   - append(key, entries) -> int (OK or ERR_*)
#   - load(key) -> Array of Dictionary
#
# OPTIONAL methods (default bodies return a sentinel and record an error):
#   - delete(key) -> int
#   - list_sessions(project_key) -> Array[ClaudeSessionStoreListEntry]
#   - list_session_summaries(project_key) -> Array[ClaudeSessionSummaryEntry]
#   - list_subkeys(key) -> Array[String]

const CAP_LIST_SESSIONS := 1 << 0
const CAP_LIST_SUMMARIES := 1 << 1
const CAP_LIST_SUBKEYS := 1 << 2
const CAP_DELETE := 1 << 3

var _last_error: String = ""


func _init() -> void:
	_clear_last_error()


# REQUIRED — append entries to the session referenced by `key`.
func append(_key: ClaudeSessionKey, _entries: Array) -> int:
	assert(false, "ClaudeSessionStore.append is abstract; override in your subclass")
	return ERR_UNAVAILABLE


# REQUIRED — load entries previously appended for `key`.
func load(_key: ClaudeSessionKey) -> Array:
	assert(false, "ClaudeSessionStore.load is abstract; override in your subclass")
	return []


# OPTIONAL — delete a session. Default returns ERR_UNAVAILABLE.
func delete(_key: ClaudeSessionKey) -> int:
	_set_last_error("delete capability not implemented")
	return ERR_UNAVAILABLE


# OPTIONAL — list sessions for a project. Default returns [].
func list_sessions(_project_key: String) -> Array:
	_set_last_error("list_sessions capability not implemented")
	return []


# OPTIONAL — list session summaries for a project. Default returns [].
func list_session_summaries(_project_key: String) -> Array:
	_set_last_error("list_session_summaries capability not implemented")
	return []


# OPTIONAL — list subkeys (e.g. subagent paths) for a session. Default returns [].
func list_subkeys(_key: ClaudeSessionListSubkeysKey) -> Array:
	_set_last_error("list_subkeys capability not implemented")
	return []


# Bitmask of supported optional capabilities. Subclasses override.
func capabilities() -> int:
	return 0


# Whether sync calls are safe on the main thread. Subclasses override (e.g. a
# remote/network adapter should return false to warn callers off the sync path).
func is_blocking_safe() -> bool:
	return true


# Whether the runtime should mirror parsed CLI stdout entries into this store.
# Most stores want the mirror (true). An adapter that wraps the same JSONL the
# CLI itself writes (e.g. `ClaudeOnDiskSessionStore`) overrides this to return
# false — otherwise the mirror duplicates entries and races with the CLI's own
# append stream.
func should_mirror_cli_writes() -> bool:
	return true


func get_last_error() -> String:
	return _last_error


func _set_last_error(message: String) -> void:
	_last_error = message


func _clear_last_error() -> void:
	_last_error = ""
