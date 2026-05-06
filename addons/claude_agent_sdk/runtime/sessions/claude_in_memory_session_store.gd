extends ClaudeSessionStore
class_name ClaudeInMemorySessionStore

# In-process session store. Useful for tests and short-lived gameplay flows
# that just want transcripts in RAM. Implements the full optional surface.

# Backing dict: canonical-string key -> Array of Dictionary entries.
var _entries_by_key: Dictionary = {}
# Per-project session summary sidecar: project_key -> { session_id -> { mtime, data } }
var _summaries_by_project: Dictionary = {}
# Strictly-monotonic mtime allocator (Unix epoch milliseconds).
var _next_mtime: int = 0


func _init() -> void:
	super()
	_next_mtime = int(Time.get_unix_time_from_system() * 1000.0)


func capabilities() -> int:
	return CAP_LIST_SESSIONS | CAP_LIST_SUMMARIES | CAP_LIST_SUBKEYS | CAP_DELETE


func is_blocking_safe() -> bool:
	return true


func append(key: ClaudeSessionKey, entries: Array) -> int:
	if key == null:
		_set_last_error("append called with null key")
		return ERR_INVALID_PARAMETER
	if key.session_id.is_empty() or key.project_key.is_empty():
		_set_last_error("append requires non-empty project_key and session_id")
		return ERR_INVALID_PARAMETER
	var canonical := key.to_canonical_string()
	var bucket: Array = _entries_by_key.get(canonical, [])
	for entry_variant in entries:
		if entry_variant is Dictionary:
			bucket.append((entry_variant as Dictionary).duplicate(true))
		else:
			bucket.append(entry_variant)
	_entries_by_key[canonical] = bucket
	_record_summary(key)
	_clear_last_error()
	return OK


func load(key: ClaudeSessionKey) -> Array:
	if key == null:
		_set_last_error("load called with null key")
		return []
	var canonical := key.to_canonical_string()
	var stored: Array = _entries_by_key.get(canonical, [])
	var result: Array = []
	for entry in stored:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
		else:
			result.append(entry)
	_clear_last_error()
	return result


func delete(key: ClaudeSessionKey) -> int:
	if key == null:
		_set_last_error("delete called with null key")
		return ERR_INVALID_PARAMETER
	var canonical := key.to_canonical_string()
	if key.subpath.is_empty():
		# Drop everything under this session_id, including subagent subpaths.
		var prefix := canonical + "/"
		var to_remove: Array[String] = []
		for stored_key_variant in _entries_by_key.keys():
			var stored_key := str(stored_key_variant)
			if stored_key == canonical or stored_key.begins_with(prefix):
				to_remove.append(stored_key)
		for stored_key in to_remove:
			_entries_by_key.erase(stored_key)
		var project_summaries: Dictionary = _summaries_by_project.get(key.project_key, {})
		project_summaries.erase(key.session_id)
		if project_summaries.is_empty():
			_summaries_by_project.erase(key.project_key)
		else:
			_summaries_by_project[key.project_key] = project_summaries
		_clear_last_error()
		return OK
	if not _entries_by_key.has(canonical):
		_set_last_error("subkey %s not present" % canonical)
		return ERR_DOES_NOT_EXIST
	_entries_by_key.erase(canonical)
	_clear_last_error()
	return OK


func list_sessions(project_key: String) -> Array:
	var result: Array = []
	var project_summaries: Dictionary = _summaries_by_project.get(project_key, {})
	for session_id_variant in project_summaries.keys():
		var session_id := str(session_id_variant)
		var summary: Dictionary = project_summaries[session_id_variant]
		result.append(ClaudeSessionStoreListEntry.new(session_id, int(summary.get("mtime", 0))))
	result.sort_custom(func(a: ClaudeSessionStoreListEntry, b: ClaudeSessionStoreListEntry):
		return a.mtime > b.mtime
	)
	_clear_last_error()
	return result


func list_session_summaries(project_key: String) -> Array:
	var result: Array = []
	var project_summaries: Dictionary = _summaries_by_project.get(project_key, {})
	for session_id_variant in project_summaries.keys():
		var session_id := str(session_id_variant)
		var summary: Dictionary = project_summaries[session_id_variant]
		var data: Dictionary = summary.get("data", {}) if summary.get("data", {}) is Dictionary else {}
		result.append(ClaudeSessionSummaryEntry.new(session_id, int(summary.get("mtime", 0)), data))
	result.sort_custom(func(a: ClaudeSessionSummaryEntry, b: ClaudeSessionSummaryEntry):
		return a.mtime > b.mtime
	)
	_clear_last_error()
	return result


func list_subkeys(key: ClaudeSessionListSubkeysKey) -> Array:
	if key == null:
		_set_last_error("list_subkeys called with null key")
		return []
	var prefix := "%s/%s/" % [key.project_key, key.session_id]
	var result: Array = []
	for stored_key_variant in _entries_by_key.keys():
		var stored_key := str(stored_key_variant)
		if stored_key.begins_with(prefix):
			result.append(stored_key.trim_prefix(prefix))
	result.sort()
	_clear_last_error()
	return result


# Test-only: returns the raw bucket for the given key (no defensive copy).
func get_entries(key: ClaudeSessionKey) -> Array:
	if key == null:
		return []
	return _entries_by_key.get(key.to_canonical_string(), [])


# Test-only: total number of entries across every key.
func size() -> int:
	var total := 0
	for stored_key_variant in _entries_by_key.keys():
		var bucket: Array = _entries_by_key[stored_key_variant]
		total += bucket.size()
	return total


# Test-only: drop all entries and summaries.
func clear() -> void:
	_entries_by_key.clear()
	_summaries_by_project.clear()
	_clear_last_error()


func _record_summary(key: ClaudeSessionKey) -> void:
	if not key.subpath.is_empty():
		# Subagent / sub-key writes do not roll up into the session-level summary list.
		return
	var project_summaries: Dictionary = _summaries_by_project.get(key.project_key, {})
	var allocated_mtime := _allocate_mtime()
	var existing: Dictionary = project_summaries.get(key.session_id, {}) if project_summaries.get(key.session_id, {}) is Dictionary else {}
	existing["mtime"] = allocated_mtime
	if not existing.has("data"):
		existing["data"] = {}
	project_summaries[key.session_id] = existing
	_summaries_by_project[key.project_key] = project_summaries


func _allocate_mtime() -> int:
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	if now <= _next_mtime:
		_next_mtime += 1
	else:
		_next_mtime = now
	return _next_mtime
