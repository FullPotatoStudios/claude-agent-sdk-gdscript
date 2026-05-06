extends ClaudeSessionStore
class_name ClaudeOnDiskSessionStore

# Wraps the existing on-disk JSONL layout (the same files the Claude CLI writes
# to `~/.claude/projects/...` and that `ClaudeSessions` reads from).
#
# `project_key` for this adapter is the *sanitized projects-dir name* — the
# string `ClaudeSessions._sanitize_path(directory)` produces. Use
# `ClaudeSessions.project_key_for_directory(directory)` to derive it.
#
# Disk I/O is fast enough at game-loop / editor-tooling scale, so
# `is_blocking_safe()` returns true. Custom adapters with network backends
# should override that.

const ClaudeSessionsScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_sessions.gd")


func capabilities() -> int:
	return CAP_LIST_SESSIONS | CAP_LIST_SUMMARIES | CAP_LIST_SUBKEYS | CAP_DELETE


func is_blocking_safe() -> bool:
	return true


# This adapter wraps the same JSONL files the Claude CLI writes itself, so the
# runtime must NOT mirror parsed CLI stdout into it — that would duplicate every
# entry and race with the CLI's own append stream. Manual `append()` calls from
# user code remain supported (e.g. tagging/rename markers).
func should_mirror_cli_writes() -> bool:
	return false


func append(key: ClaudeSessionKey, entries: Array) -> int:
	var key_error := _validate_key_for_disk(key)
	if key_error != OK:
		return key_error
	if entries.is_empty():
		_clear_last_error()
		return OK

	var target_path := _resolve_target_path(key)
	if target_path.is_empty() or not _path_within_projects_dir(target_path):
		_set_last_error("could not resolve safe on-disk path for %s" % key.to_canonical_string())
		return ERR_CANT_OPEN

	var make_dir_error := DirAccess.make_dir_recursive_absolute(target_path.get_base_dir())
	if make_dir_error != OK and not DirAccess.dir_exists_absolute(target_path.get_base_dir()):
		_set_last_error("failed to create directory for %s" % target_path)
		return make_dir_error

	var lines: PackedStringArray = []
	for entry_variant in entries:
		lines.append(JSON.stringify(entry_variant))
	# Trailing newline keeps the JSONL byte layout identical to ClaudeSessions writes.
	var serialized := "\n".join(lines) + "\n"

	var write_error := _append_text(target_path, serialized)
	if write_error != OK:
		_set_last_error("failed to append to %s" % target_path)
		return write_error
	_clear_last_error()
	return OK


func load(key: ClaudeSessionKey) -> Array:
	if _validate_key_for_disk(key) != OK:
		return []
	var target_path := _resolve_target_path(key)
	if target_path.is_empty() or not _path_within_projects_dir(target_path) or not FileAccess.file_exists(target_path):
		_clear_last_error()
		return []

	var content := FileAccess.get_file_as_string(target_path)
	var result: Array = []
	for line_variant in content.split("\n", false):
		var line := str(line_variant).strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			result.append(parsed)
	_clear_last_error()
	return result


func delete(key: ClaudeSessionKey) -> int:
	var key_error := _validate_key_for_disk(key)
	if key_error != OK:
		return key_error
	var target_path := _resolve_target_path(key)
	if target_path.is_empty() or not _path_within_projects_dir(target_path):
		_set_last_error("could not resolve safe on-disk path for %s" % key.to_canonical_string())
		return ERR_DOES_NOT_EXIST
	if not FileAccess.file_exists(target_path):
		_set_last_error("session file %s does not exist" % target_path)
		return ERR_DOES_NOT_EXIST

	var remove_error := DirAccess.remove_absolute(target_path)
	if remove_error != OK:
		_set_last_error("failed to delete %s" % target_path)
		return remove_error

	if key.subpath.is_empty():
		# Best-effort drop of the session's subagents tree to mirror
		# `ClaudeSessions.delete_session` behavior.
		var subagents_dir := target_path.get_basename().path_join("subagents")
		_remove_tree_best_effort(subagents_dir)
		var session_dir := target_path.get_basename()
		_remove_directory_if_empty(session_dir)
	_clear_last_error()
	return OK


func list_sessions(project_key: String) -> Array:
	if not _is_safe_project_key(project_key):
		_clear_last_error()
		return []
	var project_dir := _project_dir_for_key(project_key)
	var result: Array = []
	if project_dir.is_empty() or not _path_within_projects_dir(project_dir):
		_clear_last_error()
		return result
	var access := DirAccess.open(project_dir)
	if access == null:
		_clear_last_error()
		return result
	for file_name in access.get_files():
		if not file_name.ends_with(".jsonl"):
			continue
		var session_id := file_name.trim_suffix(".jsonl")
		var path := project_dir.path_join(file_name)
		var mtime := int(FileAccess.get_modified_time(path) * 1000.0)
		result.append(ClaudeSessionStoreListEntry.new(session_id, mtime))
	result.sort_custom(func(a: ClaudeSessionStoreListEntry, b: ClaudeSessionStoreListEntry):
		return a.mtime > b.mtime
	)
	_clear_last_error()
	return result


func list_session_summaries(project_key: String) -> Array:
	var entries := list_sessions(project_key)
	var summaries: Array = []
	for entry_variant in entries:
		var entry: ClaudeSessionStoreListEntry = entry_variant
		summaries.append(ClaudeSessionSummaryEntry.new(entry.session_id, entry.mtime, {}))
	_clear_last_error()
	return summaries


func list_subkeys(key: ClaudeSessionListSubkeysKey) -> Array:
	if key == null:
		_clear_last_error()
		return []
	if not _is_safe_project_key(key.project_key) or not _is_safe_session_id(key.session_id):
		_clear_last_error()
		return []
	var project_dir := _project_dir_for_key(key.project_key)
	if project_dir.is_empty() or not _path_within_projects_dir(project_dir):
		_clear_last_error()
		return []
	var subagents_dir := project_dir.path_join(key.session_id).path_join("subagents")
	var result: Array = []
	_collect_subagent_subkeys(subagents_dir, "", result)
	result.sort()
	_clear_last_error()
	return result


func _resolve_target_path(key: ClaudeSessionKey) -> String:
	var project_dir := _project_dir_for_key(key.project_key)
	if project_dir.is_empty():
		return ""
	if key.subpath.is_empty():
		return project_dir.path_join("%s.jsonl" % key.session_id)
	# subpath is e.g. "subagents/agent-<id>". Store under the session's
	# sidecar directory: <project>/<session_id>/<subpath>.jsonl
	return project_dir.path_join(key.session_id).path_join("%s.jsonl" % key.subpath)


func _project_dir_for_key(project_key: String) -> String:
	if project_key.is_empty():
		return ""
	var projects_dir := ClaudeSessionsScript._get_projects_dir()
	if projects_dir.is_empty():
		return ""
	return projects_dir.path_join(project_key)


func _append_text(file_path: String, payload: String) -> int:
	var file := FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		var open_error := FileAccess.get_open_error()
		if open_error == ERR_FILE_NOT_FOUND or open_error == ERR_FILE_BAD_PATH:
			file = FileAccess.open(file_path, FileAccess.WRITE)
			if file == null:
				return FileAccess.get_open_error()
		else:
			return open_error
	else:
		file.seek_end()
	file.store_string(payload)
	var write_error := file.get_error()
	file.close()
	return write_error if write_error != OK else OK


func _collect_subagent_subkeys(current_dir: String, relative_prefix: String, results: Array) -> void:
	var access := DirAccess.open(current_dir)
	if access == null:
		return
	access.list_dir_begin()
	while true:
		var entry_name := access.get_next()
		if entry_name.is_empty():
			break
		if entry_name == "." or entry_name == "..":
			continue
		var child_relative := entry_name if relative_prefix.is_empty() else "%s/%s" % [relative_prefix, entry_name]
		if access.current_is_dir():
			_collect_subagent_subkeys(current_dir.path_join(entry_name), child_relative, results)
			continue
		if not entry_name.begins_with("agent-") or not entry_name.ends_with(".jsonl"):
			continue
		var stripped := child_relative.trim_suffix(".jsonl")
		results.append("subagents/%s" % stripped)
	access.list_dir_end()


func _remove_tree_best_effort(path: String) -> void:
	var access := DirAccess.open(path)
	if access == null:
		return
	for directory_name in access.get_directories():
		_remove_tree_best_effort(path.path_join(directory_name))
	for file_name in access.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


func _remove_directory_if_empty(path: String) -> void:
	var access := DirAccess.open(path)
	if access == null:
		return
	if access.get_files().is_empty() and access.get_directories().is_empty():
		DirAccess.remove_absolute(path)


# Validates that a key's fields are safe to join under the projects directory.
# Returns OK or a negative ERR_* (and records `_last_error`).
#
# The on-disk adapter writes / reads / deletes under
# `~/.claude/projects/<project_key>/<session_id>[/<subpath>].jsonl`. Without
# validation, a `project_key`/`session_id`/`subpath` containing `..` or path
# separators (besides the legitimate `/` inside `subpath`) lets a caller escape
# the projects tree. Reject anything that doesn't match the sanitized layout
# the runtime itself produces.
func _validate_key_for_disk(key: ClaudeSessionKey) -> int:
	if key == null:
		_set_last_error("key is null")
		return ERR_INVALID_PARAMETER
	if not _is_safe_project_key(key.project_key):
		_set_last_error("project_key %s contains unsafe characters" % JSON.stringify(key.project_key))
		return ERR_INVALID_PARAMETER
	if not _is_safe_session_id(key.session_id):
		_set_last_error("session_id %s is not a valid UUID" % JSON.stringify(key.session_id))
		return ERR_INVALID_PARAMETER
	if not _is_safe_subpath(key.subpath):
		_set_last_error("subpath %s contains unsafe characters" % JSON.stringify(key.subpath))
		return ERR_INVALID_PARAMETER
	return OK


func _is_safe_project_key(project_key: String) -> bool:
	if project_key.is_empty():
		return false
	if project_key.contains("..") or project_key.contains("/") or project_key.contains("\\"):
		return false
	if project_key.contains(" "):
		return false
	return true


func _is_safe_session_id(session_id: String) -> bool:
	# session_ids are UUIDs by construction. Use the existing validator so the
	# disk adapter mirrors `ClaudeSessions.*` mutation guards.
	return ClaudeSessionsScript._is_valid_uuid(session_id)


func _is_safe_subpath(subpath: String) -> bool:
	if subpath.is_empty():
		return true
	if subpath.contains("..") or subpath.contains("\\") or subpath.contains(" "):
		return false
	if subpath.begins_with("/") or subpath.ends_with("/"):
		return false
	for segment in subpath.split("/", false):
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	return true


func _path_within_projects_dir(path: String) -> bool:
	var projects_dir := ClaudeSessionsScript._get_projects_dir()
	if projects_dir.is_empty():
		return false
	var projects_prefix := projects_dir if projects_dir.ends_with("/") else projects_dir + "/"
	return path == projects_dir or path.begins_with(projects_prefix)
