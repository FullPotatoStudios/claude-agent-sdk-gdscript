extends RefCounted
class_name ClaudeSessions

const ClaudeSessionInfoScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_session_info.gd")
const ClaudeSessionMessageScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_session_message.gd")

const LITE_READ_BUF_SIZE := 65536
const MAX_SANITIZED_LENGTH := 200
const TRANSCRIPT_ENTRY_TYPES := {
	"user": true,
	"assistant": true,
	"progress": true,
	"system": true,
	"attachment": true,
}

static var _uuid_regex: RegEx
static var _command_name_regex: RegEx


class LiteSessionFile:
	extends RefCounted

	var mtime: int = 0
	var size: int = 0
	var head: String = ""
	var tail: String = ""

	func _init(value_mtime: int, value_size: int, value_head: String, value_tail: String) -> void:
		mtime = value_mtime
		size = value_size
		head = value_head
		tail = value_tail


static func list_sessions(
	directory: String = "",
	limit: int = 0,
	offset: int = 0,
	include_worktrees: bool = true
) -> Array[ClaudeSessionInfo]:
	var normalized_limit := maxi(limit, 0)
	var normalized_offset := maxi(offset, 0)
	var resolved_directory := _resolve_directory(directory)

	if directory.is_empty():
		return _list_all_sessions(normalized_limit, normalized_offset)
	if resolved_directory.is_empty():
		return []
	return _list_sessions_for_project(resolved_directory, normalized_limit, normalized_offset, include_worktrees)


static func get_session_info(session_id: String, directory: String = ""):
	if not _is_valid_uuid(session_id):
		return null

	var resolved_directory := _resolve_directory(directory)
	if not directory.is_empty() and resolved_directory.is_empty():
		return null

	var file_name := "%s.jsonl" % session_id
	if not resolved_directory.is_empty():
		var project_dir := _find_project_dir(resolved_directory)
		if not project_dir.is_empty():
			var lite: Variant = _read_session_lite(_join_path(project_dir, file_name))
			if lite != null:
				return _parse_session_info_from_lite(session_id, lite, resolved_directory)

		for worktree_path in _get_worktree_paths(resolved_directory):
			if worktree_path == resolved_directory:
				continue
			var worktree_project_dir := _find_project_dir(worktree_path)
			if worktree_project_dir.is_empty():
				continue
			var worktree_lite: Variant = _read_session_lite(_join_path(worktree_project_dir, file_name))
			if worktree_lite != null:
				return _parse_session_info_from_lite(session_id, worktree_lite, worktree_path)
		return null

	var projects_dir := _get_projects_dir()
	var projects_access := DirAccess.open(projects_dir)
	if projects_access == null:
		return null
	for project_name in projects_access.get_directories():
		var lite: Variant = _read_session_lite(_join_path(_join_path(projects_dir, project_name), file_name))
		if lite != null:
			return _parse_session_info_from_lite(session_id, lite, "")
	return null


static func get_session_messages(
	session_id: String,
	directory: String = "",
	limit: int = 0,
	offset: int = 0
) -> Array[ClaudeSessionMessage]:
	if not _is_valid_uuid(session_id):
		return []

	var resolved_directory := _resolve_directory(directory)
	if not directory.is_empty() and resolved_directory.is_empty():
		return []

	var content := _read_session_file(session_id, resolved_directory)
	if content.is_empty():
		return []

	var entries := _parse_transcript_entries(content)
	var chain := _build_conversation_chain(entries)
	var messages: Array[ClaudeSessionMessage] = []
	for entry in chain:
		if _is_visible_message(entry):
			messages.append(_to_session_message(entry))

	var normalized_offset := maxi(offset, 0)
	if normalized_offset > 0:
		if normalized_offset >= messages.size():
			return []
		messages = messages.slice(normalized_offset)
	if limit > 0 and limit < messages.size():
		messages = messages.slice(0, limit)
	return messages


static func _is_valid_uuid(maybe_uuid: String) -> bool:
	if maybe_uuid.is_empty():
		return false
	if _uuid_regex == null:
		_uuid_regex = RegEx.new()
		_uuid_regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	return _uuid_regex.search(maybe_uuid) != null


static func _simple_hash(value: String) -> String:
	var hash_value: int = 0
	for i in range(value.length()):
		hash_value = ((hash_value << 5) - hash_value + value.unicode_at(i)) & 0xffffffff
		if hash_value >= 0x80000000:
			hash_value -= 0x100000000
	hash_value = abs(hash_value)
	if hash_value == 0:
		return "0"
	var digits := "0123456789abcdefghijklmnopqrstuvwxyz"
	var result := ""
	while hash_value > 0:
		result = digits.substr(hash_value % 36, 1) + result
		hash_value = int(hash_value / 36)
	return result


static func _sanitize_path(name: String) -> String:
	var sanitized := ""
	for i in range(name.length()):
		var code := name.unicode_at(i)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_upper or is_lower:
			sanitized += name.substr(i, 1)
		else:
			sanitized += "-"
	if sanitized.length() <= MAX_SANITIZED_LENGTH:
		return sanitized
	return "%s-%s" % [sanitized.substr(0, MAX_SANITIZED_LENGTH), _simple_hash(name)]


static func _get_claude_config_home_dir() -> String:
	var override := OS.get_environment("CLAUDE_CONFIG_DIR")
	if not override.is_empty():
		return _resolve_absolute_path(override)
	var home_dir := OS.get_environment("HOME")
	if home_dir.is_empty():
		home_dir = OS.get_environment("USERPROFILE")
	if home_dir.is_empty():
		return ""
	return _join_path(_resolve_absolute_path(home_dir), ".claude")


static func _get_projects_dir() -> String:
	var config_home := _get_claude_config_home_dir()
	if config_home.is_empty():
		return ""
	return _join_path(config_home, "projects")


static func _resolve_directory(directory: String) -> String:
	if directory.is_empty():
		return ""
	if directory.begins_with("res://") or directory.begins_with("user://"):
		return _resolve_absolute_path(ProjectSettings.globalize_path(directory))
	if directory.is_absolute_path():
		return _resolve_absolute_path(directory)
	return ""


static func _resolve_absolute_path(path: String) -> String:
	var normalized := path.simplify_path()
	while normalized.contains("//"):
		normalized = normalized.replace("//", "/")
	if normalized.is_empty() or not normalized.is_absolute_path():
		return normalized

	var existing_dir := normalized
	while not existing_dir.is_empty() and not DirAccess.dir_exists_absolute(existing_dir):
		var next_dir := existing_dir.get_base_dir()
		if next_dir == existing_dir:
			existing_dir = ""
			break
		existing_dir = next_dir

	if not existing_dir.is_empty():
		var canonical_existing := _canonicalize_existing_directory(existing_dir)
		if not canonical_existing.is_empty():
			if existing_dir == normalized:
				return _apply_platform_path_aliases(canonical_existing)
			var suffix := normalized.trim_prefix(existing_dir)
			while suffix.begins_with("/"):
				suffix = suffix.trim_prefix("/")
			return _apply_platform_path_aliases(_join_path(canonical_existing, suffix))

	return _apply_platform_path_aliases(normalized)


static func _canonicalize_existing_directory(path: String) -> String:
	if OS.get_name() == "Windows":
		return ""
	var output: Array = []
	var exit_code := OS.execute(
		"sh",
		["-c", "cd -- \"$0\" 2>/dev/null && pwd -P", path],
		output,
		true
	)
	if exit_code != 0 or output.is_empty():
		return ""

	var stdout := ""
	for chunk in output:
		if not stdout.is_empty():
			stdout += "\n"
		stdout += str(chunk)
	var lines := stdout.split("\n", false)
	if lines.is_empty():
		return ""
	return str(lines[0]).strip_edges()


static func _apply_platform_path_aliases(path: String) -> String:
	if OS.get_name() != "macOS":
		return path
	if path == "/tmp" or path.begins_with("/tmp/"):
		return "/private" + path
	if path == "/var" or path.begins_with("/var/"):
		return "/private" + path
	return path


static func _find_project_dir(project_path: String) -> String:
	if project_path.is_empty():
		return ""
	var exact := _join_path(_get_projects_dir(), _sanitize_path(project_path))
	if DirAccess.dir_exists_absolute(exact):
		return exact

	var sanitized := _sanitize_path(project_path)
	if sanitized.length() <= MAX_SANITIZED_LENGTH:
		return ""

	var projects_dir := _get_projects_dir()
	var projects_access := DirAccess.open(projects_dir)
	if projects_access == null:
		return ""

	var prefix := sanitized.substr(0, MAX_SANITIZED_LENGTH)
	for entry in projects_access.get_directories():
		if entry.begins_with(prefix + "-"):
			return _join_path(projects_dir, entry)
	return ""


static func _join_path(base_path: String, child_path: String) -> String:
	if base_path.is_empty():
		return child_path
	if child_path.is_empty():
		return base_path
	return base_path.path_join(child_path)


static func _unescape_json_string(raw: String) -> String:
	if raw.find("\\") == -1:
		return raw
	var result = JSON.parse_string("\"%s\"" % raw)
	if result is String:
		return result
	return raw


static func _extract_json_string_field(text: String, key: String):
	var patterns: Array[String] = ['"%s":"' % key, '"%s": "' % key]
	for pattern in patterns:
		var idx := text.find(pattern)
		if idx < 0:
			continue
		var value_start: int = idx + pattern.length()
		var cursor: int = value_start
		while cursor < text.length():
			var code := text.unicode_at(cursor)
			if code == 92:
				cursor += 2
				continue
			if code == 34:
				return _unescape_json_string(text.substr(value_start, cursor - value_start))
			cursor += 1
	return null


static func _extract_last_json_string_field(text: String, key: String):
	var patterns: Array[String] = ['"%s":"' % key, '"%s": "' % key]
	var last_value: Variant = null
	for pattern in patterns:
		var search_from: int = 0
		while true:
			var idx := text.find(pattern, search_from)
			if idx < 0:
				break
			var value_start: int = idx + pattern.length()
			var cursor: int = value_start
			while cursor < text.length():
				var code := text.unicode_at(cursor)
				if code == 92:
					cursor += 2
					continue
				if code == 34:
					last_value = _unescape_json_string(text.substr(value_start, cursor - value_start))
					break
				cursor += 1
			search_from = cursor + 1
	return last_value


static func _extract_first_prompt_from_head(head: String) -> String:
	var command_fallback := ""
	for line_variant in head.split("\n", false):
		var line := str(line_variant)
		if not ('"type":"user"' in line or '"type": "user"' in line):
			continue
		if '"tool_result"' in line:
			continue
		if '"isMeta":true' in line or '"isMeta": true' in line:
			continue
		if '"isCompactSummary":true' in line or '"isCompactSummary": true' in line:
			continue

		var entry = JSON.parse_string(line)
		if not (entry is Dictionary):
			continue
		if str(entry.get("type", "")) != "user":
			continue

		var message = entry.get("message")
		if not (message is Dictionary):
			continue

		var texts: Array[String] = []
		var content = message.get("content")
		if content is String:
			texts.append(str(content))
		elif content is Array:
			for block in content:
				if block is Dictionary and str(block.get("type", "")) == "text":
					texts.append(str(block.get("text", "")))

		for raw_text in texts:
			var normalized := raw_text.replace("\n", " ").strip_edges()
			if normalized.is_empty():
				continue

			var command_name := _extract_command_name(normalized)
			if not command_name.is_empty():
				if command_fallback.is_empty():
					command_fallback = command_name
				continue

			if _should_skip_first_prompt(normalized):
				continue

			if normalized.length() > 200:
				normalized = normalized.substr(0, 200).rstrip(" ") + "..."
			return normalized

	if not command_fallback.is_empty():
		return command_fallback
	return ""


static func _extract_command_name(text: String) -> String:
	if _command_name_regex == null:
		_command_name_regex = RegEx.new()
		_command_name_regex.compile("<command-name>(.*?)</command-name>")
	var match := _command_name_regex.search(text)
	if match == null:
		return ""
	return match.get_string(1)


static func _should_skip_first_prompt(text: String) -> bool:
	return text.begins_with("<local-command-stdout>") \
		or text.begins_with("<session-start-hook>") \
		or text.begins_with("<tick>") \
		or text.begins_with("<goal>") \
		or text.begins_with("[Request interrupted by user") \
		or (text.contains("<ide_opened_file>") and text.contains("</ide_opened_file>")) \
		or (text.contains("<ide_selection>") and text.contains("</ide_selection>"))


static func _read_session_lite(file_path: String):
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	var size := file.get_length()
	if size <= 0:
		return null
	var mtime := int(FileAccess.get_modified_time(file_path) * 1000.0)
	var head_bytes := file.get_buffer(mini(LITE_READ_BUF_SIZE, size))
	if head_bytes.is_empty():
		return null
	var head := head_bytes.get_string_from_utf8()
	var tail := head
	if size > LITE_READ_BUF_SIZE:
		file.seek(size - LITE_READ_BUF_SIZE)
		tail = file.get_buffer(LITE_READ_BUF_SIZE).get_string_from_utf8()
	return LiteSessionFile.new(mtime, size, head, tail)


static func _get_worktree_paths(cwd: String) -> Array[String]:
	var output: Array = []
	var exit_code := OS.execute("git", ["-C", cwd, "worktree", "list", "--porcelain"], output, true)
	if exit_code != 0 or output.is_empty():
		return []
	var stdout := ""
	for chunk in output:
		if not stdout.is_empty():
			stdout += "\n"
		stdout += str(chunk)
	var result: Array[String] = []
	for line_variant in stdout.split("\n", false):
		var line := str(line_variant)
		if line.begins_with("worktree "):
			result.append(_resolve_absolute_path(line.trim_prefix("worktree ")))
	return result


static func _parse_session_info_from_lite(session_id: String, lite: LiteSessionFile, project_path: String = ""):
	var first_newline := lite.head.find("\n")
	var first_line := lite.head if first_newline < 0 else lite.head.substr(0, first_newline)
	if '"isSidechain":true' in first_line or '"isSidechain": true' in first_line:
		return null

	var custom_title = _extract_last_json_string_field(lite.tail, "customTitle")
	if custom_title == null:
		custom_title = _extract_last_json_string_field(lite.head, "customTitle")
	if custom_title == null:
		custom_title = _extract_last_json_string_field(lite.tail, "aiTitle")
	if custom_title == null:
		custom_title = _extract_last_json_string_field(lite.head, "aiTitle")

	var first_prompt = _extract_first_prompt_from_head(lite.head)
	var summary = custom_title
	if summary == null:
		summary = _extract_last_json_string_field(lite.tail, "lastPrompt")
	if summary == null:
		summary = _extract_last_json_string_field(lite.tail, "summary")
	if summary == null and not first_prompt.is_empty():
		summary = first_prompt
	if summary == null or str(summary).is_empty():
		return null

	var git_branch = _extract_last_json_string_field(lite.tail, "gitBranch")
	if git_branch == null:
		git_branch = _extract_json_string_field(lite.head, "gitBranch")

	var session_cwd = _extract_json_string_field(lite.head, "cwd")
	if session_cwd == null and not project_path.is_empty():
		session_cwd = project_path

	var tag = null
	for line_variant in lite.tail.split("\n", false):
		var line := str(line_variant).strip_edges()
		if line.is_empty():
			continue
		var tag_entry = JSON.parse_string(line)
		if tag_entry is Dictionary and str(tag_entry.get("type", "")) == "tag" and tag_entry.get("tag") is String:
			tag = str(tag_entry.get("tag"))

	var created_at = null
	var first_timestamp = _extract_json_string_field(first_line, "timestamp")
	if first_timestamp != null:
		var unix_time = Time.get_unix_time_from_datetime_string(str(first_timestamp))
		if unix_time > 0.0:
			created_at = int(unix_time * 1000.0)

	return ClaudeSessionInfoScript.new(
		session_id,
		str(summary),
		lite.mtime,
		lite.size,
		custom_title,
		first_prompt if not first_prompt.is_empty() else null,
		git_branch,
		session_cwd,
		tag,
		created_at
	)


static func _read_sessions_from_dir(project_dir: String, project_path: String = "") -> Array[ClaudeSessionInfo]:
	var access := DirAccess.open(project_dir)
	if access == null:
		return []

	var result: Array[ClaudeSessionInfo] = []
	for file_name in access.get_files():
		if not file_name.ends_with(".jsonl"):
			continue
		var session_id := file_name.trim_suffix(".jsonl")
		if not _is_valid_uuid(session_id):
			continue
		var lite = _read_session_lite(_join_path(project_dir, file_name))
		if lite == null:
			continue
		var info = _parse_session_info_from_lite(session_id, lite, project_path)
		if info != null:
			result.append(info)
	return result


static func _deduplicate_by_session_id(sessions: Array[ClaudeSessionInfo]) -> Array[ClaudeSessionInfo]:
	var by_id := {}
	for session in sessions:
		var existing = by_id.get(session.session_id)
		if existing == null or session.last_modified > existing.last_modified:
			by_id[session.session_id] = session
	var result: Array[ClaudeSessionInfo] = []
	for session_id in by_id.keys():
		result.append(by_id[session_id])
	return result


static func _apply_sort_limit_offset(
	sessions: Array[ClaudeSessionInfo],
	limit: int,
	offset: int
) -> Array[ClaudeSessionInfo]:
	sessions.sort_custom(func(a: ClaudeSessionInfo, b: ClaudeSessionInfo): return a.last_modified > b.last_modified)
	if offset > 0:
		if offset >= sessions.size():
			return []
		sessions = sessions.slice(offset)
	if limit > 0 and limit < sessions.size():
		sessions = sessions.slice(0, limit)
	return sessions


static func _list_sessions_for_project(
	directory: String,
	limit: int,
	offset: int,
	include_worktrees: bool
) -> Array[ClaudeSessionInfo]:
	var canonical_dir := _resolve_absolute_path(directory)
	var worktree_paths: Array[String] = []
	if include_worktrees:
		worktree_paths.append_array(_get_worktree_paths(canonical_dir))

	if worktree_paths.size() <= 1:
		var project_dir := _find_project_dir(canonical_dir)
		if project_dir.is_empty():
			return []
		return _apply_sort_limit_offset(_read_sessions_from_dir(project_dir, canonical_dir), limit, offset)

	var projects_dir := _get_projects_dir()
	var projects_access := DirAccess.open(projects_dir)
	if projects_access == null:
		var fallback_project_dir := _find_project_dir(canonical_dir)
		if fallback_project_dir.is_empty():
			return []
		return _apply_sort_limit_offset(_read_sessions_from_dir(fallback_project_dir, canonical_dir), limit, offset)

	var case_insensitive := OS.get_name() == "Windows"
	var indexed_worktrees: Array[Dictionary] = []
	for worktree_path in worktree_paths:
		var sanitized := _sanitize_path(worktree_path)
		indexed_worktrees.append({
			"path": worktree_path,
			"prefix": sanitized.to_lower() if case_insensitive else sanitized,
		})
	indexed_worktrees.sort_custom(func(a: Dictionary, b: Dictionary): return str(a["prefix"]).length() > str(b["prefix"]).length())

	var all_sessions: Array[ClaudeSessionInfo] = []
	var seen_dirs := {}
	var canonical_project_dir := _find_project_dir(canonical_dir)
	if not canonical_project_dir.is_empty():
		var dir_base := canonical_project_dir.get_file()
		seen_dirs[dir_base.to_lower() if case_insensitive else dir_base] = true
		all_sessions.append_array(_read_sessions_from_dir(canonical_project_dir, canonical_dir))

	for entry in projects_access.get_directories():
		var normalized_entry := entry.to_lower() if case_insensitive else entry
		if seen_dirs.has(normalized_entry):
			continue
		for worktree in indexed_worktrees:
			var prefix := str(worktree["prefix"])
			var is_match := normalized_entry == prefix
			if not is_match and prefix.length() >= MAX_SANITIZED_LENGTH:
				is_match = normalized_entry.begins_with(prefix + "-")
			if not is_match:
				continue
			seen_dirs[normalized_entry] = true
			all_sessions.append_array(_read_sessions_from_dir(_join_path(projects_dir, entry), str(worktree["path"])))
			break

	return _apply_sort_limit_offset(_deduplicate_by_session_id(all_sessions), limit, offset)


static func _list_all_sessions(limit: int, offset: int) -> Array[ClaudeSessionInfo]:
	var projects_dir := _get_projects_dir()
	var projects_access := DirAccess.open(projects_dir)
	if projects_access == null:
		return []

	var all_sessions: Array[ClaudeSessionInfo] = []
	for project_name in projects_access.get_directories():
		all_sessions.append_array(_read_sessions_from_dir(_join_path(projects_dir, project_name)))
	return _apply_sort_limit_offset(_deduplicate_by_session_id(all_sessions), limit, offset)


static func _try_read_session_file(project_dir: String, file_name: String) -> String:
	var path := _join_path(project_dir, file_name)
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


static func _read_session_file(session_id: String, directory: String = "") -> String:
	var file_name := "%s.jsonl" % session_id
	if not directory.is_empty():
		var canonical_dir := _resolve_absolute_path(directory)
		var project_dir := _find_project_dir(canonical_dir)
		if not project_dir.is_empty():
			var content := _try_read_session_file(project_dir, file_name)
			if not content.is_empty():
				return content
		for worktree_path in _get_worktree_paths(canonical_dir):
			if worktree_path == canonical_dir:
				continue
			var worktree_project_dir := _find_project_dir(worktree_path)
			if worktree_project_dir.is_empty():
				continue
			var worktree_content := _try_read_session_file(worktree_project_dir, file_name)
			if not worktree_content.is_empty():
				return worktree_content
		return ""

	var projects_dir := _get_projects_dir()
	var projects_access := DirAccess.open(projects_dir)
	if projects_access == null:
		return ""
	for project_name in projects_access.get_directories():
		var content := _try_read_session_file(_join_path(projects_dir, project_name), file_name)
		if not content.is_empty():
			return content
	return ""


static func _parse_transcript_entries(content: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for line_variant in content.split("\n", false):
		var line := str(line_variant).strip_edges()
		if line.is_empty():
			continue
		var entry = JSON.parse_string(line)
		if not (entry is Dictionary):
			continue
		var entry_type := str(entry.get("type", ""))
		if not TRANSCRIPT_ENTRY_TYPES.has(entry_type):
			continue
		if not (entry.get("uuid") is String):
			continue
		entries.append(entry)
	return entries


static func _build_conversation_chain(entries: Array[Dictionary]) -> Array[Dictionary]:
	if entries.is_empty():
		return []

	var by_uuid := {}
	var entry_index := {}
	for i in entries.size():
		var entry := entries[i]
		by_uuid[str(entry.get("uuid", ""))] = entry
		entry_index[str(entry.get("uuid", ""))] = i

	var parent_uuids := {}
	for entry in entries:
		var parent = entry.get("parentUuid", "")
		if parent is String and not str(parent).is_empty():
			parent_uuids[str(parent)] = true

	var terminals: Array[Dictionary] = []
	for entry in entries:
		var uuid := str(entry.get("uuid", ""))
		if not parent_uuids.has(uuid):
			terminals.append(entry)

	var leaves: Array[Dictionary] = []
	for terminal in terminals:
		var current = terminal
		var seen := {}
		while current != null:
			var current_uuid := str(current.get("uuid", ""))
			if seen.has(current_uuid):
				break
			seen[current_uuid] = true
			var current_type := str(current.get("type", ""))
			if current_type == "user" or current_type == "assistant":
				leaves.append(current)
				break
			var parent_uuid = current.get("parentUuid", "")
			current = by_uuid.get(str(parent_uuid)) if parent_uuid is String and not str(parent_uuid).is_empty() else null
	if leaves.is_empty():
		return []

	var main_leaves: Array[Dictionary] = []
	for leaf in leaves:
		if bool(leaf.get("isSidechain", false)):
			continue
		if leaf.get("teamName") != null:
			continue
		if bool(leaf.get("isMeta", false)):
			continue
		main_leaves.append(leaf)

	var leaf = _pick_best_leaf(main_leaves if not main_leaves.is_empty() else leaves, entry_index)
	var chain: Array[Dictionary] = []
	var chain_seen := {}
	var current = leaf
	while current != null:
		var current_uuid := str(current.get("uuid", ""))
		if chain_seen.has(current_uuid):
			break
		chain_seen[current_uuid] = true
		chain.append(current)
		var parent_uuid = current.get("parentUuid", "")
		current = by_uuid.get(str(parent_uuid)) if parent_uuid is String and not str(parent_uuid).is_empty() else null
	chain.reverse()
	return chain


static func _pick_best_leaf(candidates: Array[Dictionary], entry_index: Dictionary) -> Dictionary:
	var best := candidates[0]
	var best_index := int(entry_index.get(str(best.get("uuid", "")), -1))
	for i in range(1, candidates.size()):
		var current := candidates[i]
		var current_index := int(entry_index.get(str(current.get("uuid", "")), -1))
		if current_index > best_index:
			best = current
			best_index = current_index
	return best


static func _is_visible_message(entry: Dictionary) -> bool:
	var entry_type := str(entry.get("type", ""))
	if entry_type != "user" and entry_type != "assistant":
		return false
	if bool(entry.get("isMeta", false)):
		return false
	if bool(entry.get("isSidechain", false)):
		return false
	return entry.get("teamName") == null


static func _to_session_message(entry: Dictionary) -> ClaudeSessionMessage:
	return ClaudeSessionMessageScript.new(
		str(entry.get("type", "")),
		str(entry.get("uuid", "")),
		str(entry.get("sessionId", "")),
		_duplicate_variant(entry.get("message")),
		null
	)


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
