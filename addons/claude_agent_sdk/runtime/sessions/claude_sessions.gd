extends RefCounted
class_name ClaudeSessions

const ClaudeSessionInfoScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_session_info.gd")
const ClaudeSessionMessageScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_session_message.gd")
const ClaudeSessionTranscriptEntryScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_session_transcript_entry.gd")
const ClaudeForkSessionResultScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_fork_session_result.gd")

const LITE_READ_BUF_SIZE := 65536
const MAX_SANITIZED_LENGTH := 200
const SESSION_SEARCH_MISS := -10001
const TRANSCRIPT_ENTRY_TYPES := {
	"user": true,
	"assistant": true,
	"progress": true,
	"system": true,
	"attachment": true,
}
const FORK_CLEARED_FIELDS := [
	"teamName",
	"agentName",
	"slug",
	"sourceToolAssistantUUID",
]

static var _uuid_regex: RegEx
static var _command_name_regex: RegEx
static var _last_error := ""


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
	for project_name in _sorted_directory_names(projects_access):
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


static func get_session_transcript(
	session_id: String,
	directory: String = "",
	limit: int = 0,
	offset: int = 0
) -> Array[ClaudeSessionTranscriptEntry]:
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
	var transcript: Array[ClaudeSessionTranscriptEntry] = []
	for entry in chain:
		transcript.append_array(_expand_session_transcript_entry(entry))

	var normalized_offset := maxi(offset, 0)
	if normalized_offset > 0:
		if normalized_offset >= transcript.size():
			return []
		transcript = transcript.slice(normalized_offset)
	if limit > 0 and limit < transcript.size():
		transcript = transcript.slice(0, limit)
	return transcript


static func rename_session(session_id: String, title: String, directory: String = "") -> int:
	if not _is_valid_uuid(session_id):
		return _fail_mutation(ERR_INVALID_PARAMETER, "Invalid session_id: %s" % session_id)

	var stripped := title.strip_edges()
	if stripped.is_empty():
		return _fail_mutation(ERR_INVALID_PARAMETER, "title must be non-empty")

	var entry := {
		"type": "custom-title",
		"customTitle": stripped,
		"sessionId": session_id,
	}
	return _append_to_session(session_id, JSON.stringify(entry, "", false) + "\n", directory)


static func tag_session(session_id: String, tag: Variant = null, directory: String = "") -> int:
	if not _is_valid_uuid(session_id):
		return _fail_mutation(ERR_INVALID_PARAMETER, "Invalid session_id: %s" % session_id)
	if tag != null and not (tag is String):
		return _fail_mutation(ERR_INVALID_PARAMETER, "tag must be a String or null")

	var stored_tag := ""
	if tag != null:
		stored_tag = _sanitize_tag(str(tag)).strip_edges()
		if stored_tag.is_empty():
			return _fail_mutation(ERR_INVALID_PARAMETER, "tag must be non-empty (use null to clear)")

	var entry := {
		"type": "tag",
		"tag": stored_tag,
		"sessionId": session_id,
	}
	return _append_to_session(session_id, JSON.stringify(entry, "", false) + "\n", directory)


static func delete_session(session_id: String, directory: String = "") -> int:
	if not _is_valid_uuid(session_id):
		return _fail_mutation(ERR_INVALID_PARAMETER, "Invalid session_id: %s" % session_id)

	var file_result := _find_session_file_with_dir(session_id, directory) if not directory.is_empty() else _find_latest_visible_session_file(session_id)
	if file_result.has("error"):
		return _fail_mutation(
			int(file_result.get("error", ERR_CANT_OPEN)),
			str(file_result.get("message", "Failed to locate session %s for deletion" % session_id))
		)
	if file_result.is_empty():
		if directory.is_empty():
			return _fail_mutation(ERR_DOES_NOT_EXIST, "Session %s not found" % session_id)
		return _fail_mutation(
			ERR_DOES_NOT_EXIST,
			"Session %s not found in project directory for %s" % [session_id, directory]
		)

	var delete_error := DirAccess.remove_absolute(str(file_result.get("path", "")))
	if delete_error != OK:
		return _fail_mutation(delete_error, "Failed to delete session %s" % session_id)

	_clear_last_error()
	return OK


static func fork_session(
	session_id: String,
	directory: String = "",
	up_to_message_id: String = "",
	title: String = ""
):
	if not _is_valid_uuid(session_id):
		return _fail_fork("Invalid session_id: %s" % session_id)
	if not up_to_message_id.is_empty() and not _is_valid_uuid(up_to_message_id):
		return _fail_fork("Invalid up_to_message_id: %s" % up_to_message_id)

	var source := _find_session_file_with_dir(session_id, directory) if not directory.is_empty() else _find_latest_visible_session_file(session_id)
	if source.has("error"):
		return _fail_fork(str(source.get("message", "Failed to locate session %s for fork" % session_id)))
	if source.is_empty():
		if directory.is_empty():
			return _fail_fork("Session %s not found" % session_id)
		return _fail_fork("Session %s not found in project directory for %s" % [session_id, directory])

	var file_path := str(source.get("path", ""))
	var project_dir := str(source.get("project_dir", ""))
	var content := FileAccess.get_file_as_string(file_path)
	var parsed := _parse_fork_transcript(content, session_id)
	var transcript: Array[Dictionary] = parsed.get("transcript", [])
	var content_replacements: Array = parsed.get("content_replacements", [])
	if transcript.is_empty():
		return _fail_fork("Session %s has no messages to fork" % session_id)

	if not up_to_message_id.is_empty():
		var cutoff := -1
		for index in range(transcript.size()):
			if str(transcript[index].get("uuid", "")) == up_to_message_id:
				cutoff = index
				break
		if cutoff < 0:
			return _fail_fork("Message %s not found in session %s" % [up_to_message_id, session_id])
		transcript = transcript.slice(0, cutoff + 1)

	var uuid_mapping := {}
	for entry in transcript:
		uuid_mapping[str(entry.get("uuid", ""))] = _generate_uuid_v4()

	var writable: Array[Dictionary] = []
	var by_uuid := {}
	for entry in transcript:
		by_uuid[str(entry.get("uuid", ""))] = entry
		if str(entry.get("type", "")) != "progress":
			writable.append(entry)
	if writable.is_empty():
		return _fail_fork("Session %s has no messages to fork" % session_id)

	var forked_session_id := ""
	var fork_path := ""
	for _attempt in range(16):
		forked_session_id = _generate_uuid_v4()
		fork_path = _join_path(project_dir, "%s.jsonl" % forked_session_id)
		if not FileAccess.file_exists(fork_path):
			break
		forked_session_id = ""
		fork_path = ""
	if forked_session_id.is_empty():
		return _fail_fork("Failed to allocate a new session ID for fork of %s" % session_id)

	var now := _utc_now_iso8601_z()
	var lines: Array[String] = []
	for index in range(writable.size()):
		var original := writable[index]
		var forked := _duplicate_variant(original)
		if forked is not Dictionary:
			continue
		var original_uuid := str(original.get("uuid", ""))
		var parent_uuid := _resolve_fork_parent_uuid(original, by_uuid, uuid_mapping)
		var logical_parent := original.get("logicalParentUuid", null)
		var forked_timestamp := now if index == writable.size() - 1 else str(original.get("timestamp", now))

		forked["uuid"] = str(uuid_mapping.get(original_uuid, _generate_uuid_v4()))
		forked["parentUuid"] = parent_uuid
		forked["logicalParentUuid"] = uuid_mapping.get(str(logical_parent), null) \
			if logical_parent is String and not str(logical_parent).is_empty() \
			else null
		forked["sessionId"] = forked_session_id
		forked["timestamp"] = forked_timestamp
		forked["isSidechain"] = false
		forked["forkedFrom"] = {
			"sessionId": session_id,
			"messageUuid": original_uuid,
		}
		for stale_key in FORK_CLEARED_FIELDS:
			forked.erase(stale_key)
		lines.append(JSON.stringify(forked, "", false))

	if not content_replacements.is_empty():
		lines.append(JSON.stringify({
			"type": "content-replacement",
			"sessionId": forked_session_id,
			"replacements": _duplicate_variant(content_replacements),
		}, "", false))

	var fork_title := title.strip_edges()
	if fork_title.is_empty():
		fork_title = "%s (fork)" % _derive_fork_title_base(content)
	lines.append(JSON.stringify({
		"type": "custom-title",
		"sessionId": forked_session_id,
		"customTitle": fork_title,
	}, "", false))

	if FileAccess.file_exists(fork_path):
		return _fail_fork("Failed to create forked session file at %s" % fork_path)
	var file := FileAccess.open(fork_path, FileAccess.WRITE)
	if file == null:
		return _fail_fork("Failed to create forked session file at %s" % fork_path)
	file.store_string("\n".join(lines) + "\n")
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(fork_path)
		return _fail_fork("Failed to write forked session file at %s" % fork_path)

	_clear_last_error()
	return ClaudeForkSessionResultScript.new(forked_session_id)


static func get_last_error() -> String:
	return _last_error


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


static func _sanitize_tag(value: String) -> String:
	var current := value
	for _i in range(10):
		var next := ""
		for j in range(current.length()):
			var code := current.unicode_at(j)
			if _should_strip_tag_codepoint(code):
				continue
			var compatibility := _compatibility_tag_replacement(code)
			if not compatibility.is_empty():
				next += compatibility
				continue
			next += char(code)
		if next == current:
			return next
		current = next
	return current


static func _compatibility_tag_replacement(code: int) -> String:
	if code == 0x3000:
		return " "
	if code >= 0xff01 and code <= 0xff5e:
		return char(code - 0xfee0)
	if code == 0x24ea:
		return "0"
	if code >= 0x2460 and code <= 0x2473:
		return str(code - 0x245f)
	if code >= 0x24b6 and code <= 0x24cf:
		return char(65 + code - 0x24b6)
	if code >= 0x24d0 and code <= 0x24e9:
		return char(97 + code - 0x24d0)

	match code:
		0x00aa:
			return "a"
		0x00ba:
			return "o"
		0x00b2:
			return "2"
		0x00b3:
			return "3"
		0x00b9:
			return "1"
		0x0132:
			return "IJ"
		0x0133:
			return "ij"
		0x01c7:
			return "LJ"
		0x01c8:
			return "Lj"
		0x01c9:
			return "lj"
		0x01ca:
			return "NJ"
		0x01cb:
			return "Nj"
		0x01cc:
			return "nj"
		0x01f1:
			return "DZ"
		0x01f2:
			return "Dz"
		0x01f3:
			return "dz"
		0x1d2c:
			return "A"
		0x1d2e:
			return "B"
		0x1d30:
			return "D"
		0x1d31:
			return "E"
		0x1d33:
			return "G"
		0x1d34:
			return "H"
		0x1d35:
			return "I"
		0x1d36:
			return "J"
		0x1d37:
			return "K"
		0x1d38:
			return "L"
		0x1d39:
			return "M"
		0x1d3a:
			return "N"
		0x1d3c:
			return "O"
		0x1d3d:
			return "P"
		0x1d3e:
			return "R"
		0x1d3f:
			return "T"
		0x1d40:
			return "U"
		0x1d41:
			return "W"
		0x2070:
			return "0"
		0x2071:
			return "i"
		0x2074:
			return "4"
		0x2075:
			return "5"
		0x2076:
			return "6"
		0x2077:
			return "7"
		0x2078:
			return "8"
		0x2079:
			return "9"
		0x207f:
			return "n"
		0x2080:
			return "0"
		0x2081:
			return "1"
		0x2082:
			return "2"
		0x2083:
			return "3"
		0x2084:
			return "4"
		0x2085:
			return "5"
		0x2086:
			return "6"
		0x2087:
			return "7"
		0x2088:
			return "8"
		0x2089:
			return "9"
		0x2160:
			return "I"
		0x2161:
			return "II"
		0x2162:
			return "III"
		0x2163:
			return "IV"
		0x2164:
			return "V"
		0x2165:
			return "VI"
		0x2166:
			return "VII"
		0x2167:
			return "VIII"
		0x2168:
			return "IX"
		0x2169:
			return "X"
		0x2170:
			return "i"
		0x2171:
			return "ii"
		0x2172:
			return "iii"
		0x2173:
			return "iv"
		0x2174:
			return "v"
		0x2175:
			return "vi"
		0x2176:
			return "vii"
		0x2177:
			return "viii"
		0x2178:
			return "ix"
		0x2179:
			return "x"
		0xfb00:
			return "ff"
		0xfb01:
			return "fi"
		0xfb02:
			return "fl"
		0xfb03:
			return "ffi"
		0xfb04:
			return "ffl"
		0xfb05:
			return "st"
		0xfb06:
			return "st"
	return ""


static func _should_strip_tag_codepoint(code: int) -> bool:
	if code == 0xfeff:
		return true
	if code >= 0x200b and code <= 0x200d:
		return true
	if code >= 0x202a and code <= 0x202e:
		return true
	if code >= 0x2066 and code <= 0x2069:
		return true
	if code >= 0xe000 and code <= 0xf8ff:
		return true
	return false


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
	for entry in _sorted_directory_names(projects_access):
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


static func _read_session_lite_result(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {
			"error": _map_open_error(FileAccess.get_open_error()),
		}
	var size := file.get_length()
	if size <= 0:
		file.close()
		return {
			"stub": true,
		}
	var mtime := int(FileAccess.get_modified_time(file_path) * 1000.0)
	var head_bytes := file.get_buffer(mini(LITE_READ_BUF_SIZE, size))
	if head_bytes.is_empty():
		file.close()
		return {
			"stub": true,
		}
	var head := head_bytes.get_string_from_utf8()
	var tail := head
	if size > LITE_READ_BUF_SIZE:
		file.seek(size - LITE_READ_BUF_SIZE)
		tail = file.get_buffer(LITE_READ_BUF_SIZE).get_string_from_utf8()
		var first_tail_newline := tail.find("\n")
		tail = tail.substr(first_tail_newline + 1) if first_tail_newline >= 0 else ""
	file.close()
	return {
		"lite": LiteSessionFile.new(mtime, size, head, tail),
	}


static func _read_session_lite(file_path: String):
	var result := _read_session_lite_result(file_path)
	return result.get("lite") if result.has("lite") else null


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
	var tail_lines := lite.tail.split("\n", false)
	for line_index in range(tail_lines.size() - 1, -1, -1):
		var line := str(tail_lines[line_index]).strip_edges()
		if line.is_empty():
			continue
		if not ('"type":"tag"' in line or '"type": "tag"' in line):
			continue
		var candidate_tag = _extract_json_string_field(line, "tag")
		if candidate_tag != null:
			tag = candidate_tag if not str(candidate_tag).is_empty() else null
			break

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


static func _sorted_directory_names(projects_access: DirAccess) -> Array[String]:
	var result: Array[String] = []
	for directory_name in projects_access.get_directories():
		result.append(str(directory_name))
	result.sort()
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

	for entry in _sorted_directory_names(projects_access):
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
	for project_name in _sorted_directory_names(projects_access):
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
	for project_name in _sorted_directory_names(projects_access):
		var content := _try_read_session_file(_join_path(projects_dir, project_name), file_name)
		if not content.is_empty():
			return content
	return ""


static func _find_session_file_with_dir(session_id: String, directory: String = "") -> Dictionary:
	var file_name := "%s.jsonl" % session_id
	if not directory.is_empty():
		var resolved_directory := _resolve_directory(directory)
		if resolved_directory.is_empty():
			return {}
		var first_error: Dictionary = {}

		var project_dir := _find_project_dir(resolved_directory)
		if not project_dir.is_empty():
			var direct_result := _try_find_session_file(_join_path(project_dir, file_name), project_dir)
			if direct_result.has("error"):
				first_error = direct_result
			elif not direct_result.is_empty():
				return direct_result

		for worktree_path in _get_worktree_paths(resolved_directory):
			if worktree_path == resolved_directory:
				continue
			var worktree_project_dir := _find_project_dir(worktree_path)
			if worktree_project_dir.is_empty():
				continue
			var worktree_result := _try_find_session_file(
				_join_path(worktree_project_dir, file_name),
				worktree_project_dir
			)
			if worktree_result.has("error"):
				if first_error.is_empty():
					first_error = worktree_result
			elif not worktree_result.is_empty():
				return worktree_result
		return first_error

	var projects_dir := _get_projects_dir()
	var projects_access := DirAccess.open(projects_dir)
	if projects_access == null:
		return {}
	var first_error: Dictionary = {}
	for project_name in _sorted_directory_names(projects_access):
		var project_dir := _join_path(projects_dir, project_name)
		var result := _try_find_session_file(_join_path(project_dir, file_name), project_dir)
		if result.has("error"):
			if first_error.is_empty():
				first_error = result
		elif not result.is_empty():
			return result
	return first_error


static func _try_find_session_file(file_path: String, project_dir: String) -> Dictionary:
	var lite_result := _read_session_lite_result(file_path)
	if lite_result.is_empty() or lite_result.has("stub"):
		return {}
	if lite_result.has("error"):
		return {
			"error": int(lite_result.get("error", ERR_CANT_OPEN)),
			"path": file_path,
			"project_dir": project_dir,
			"message": "Failed to access session file at %s" % file_path,
		}
	return {
		"path": file_path,
		"project_dir": project_dir,
	}


static func _append_to_session(session_id: String, data: String, directory: String = "") -> int:
	var file_name := "%s.jsonl" % session_id
	if not directory.is_empty():
		var resolved_directory := _resolve_directory(directory)
		if resolved_directory.is_empty():
			return _fail_mutation(
				ERR_DOES_NOT_EXIST,
				"Session %s not found in project directory for %s" % [session_id, directory]
			)
		var first_error_code := OK
		var first_error_message := ""

		var project_dir := _find_project_dir(resolved_directory)
		if not project_dir.is_empty():
			var append_result := _try_append(_join_path(project_dir, file_name), data)
			if append_result == OK:
				_clear_last_error()
				return OK
			if append_result != SESSION_SEARCH_MISS:
				first_error_code = append_result
				first_error_message = "Failed to append metadata for session %s at %s" % [session_id, _join_path(project_dir, file_name)]

		for worktree_path in _get_worktree_paths(resolved_directory):
			if worktree_path == resolved_directory:
				continue
			var worktree_project_dir := _find_project_dir(worktree_path)
			if worktree_project_dir.is_empty():
				continue
			var worktree_result := _try_append(_join_path(worktree_project_dir, file_name), data)
			if worktree_result == OK:
				_clear_last_error()
				return OK
			if worktree_result != SESSION_SEARCH_MISS:
				if first_error_message.is_empty():
					first_error_code = worktree_result
					first_error_message = "Failed to append metadata for session %s at %s" % [session_id, _join_path(worktree_project_dir, file_name)]
		if not first_error_message.is_empty():
			return _fail_mutation(first_error_code, first_error_message)
		return _fail_mutation(
			ERR_DOES_NOT_EXIST,
			"Session %s not found in project directory for %s" % [session_id, directory]
		)

	var target := _find_latest_visible_session_file(session_id)
	if target.has("error"):
		return _fail_mutation(
			int(target.get("error", ERR_CANT_OPEN)),
			str(target.get("message", "Failed to append metadata for session %s" % session_id))
		)
	if target.is_empty():
		return _fail_mutation(ERR_DOES_NOT_EXIST, "Session %s not found in any project directory" % session_id)
	var append_result := _try_append(str(target.get("path", "")), data)
	if append_result == OK:
		_clear_last_error()
		return OK
	return _fail_mutation(append_result, "Failed to append metadata for session %s" % session_id)


static func _find_latest_visible_session_file(session_id: String) -> Dictionary:
	var projects_dir := _get_projects_dir()
	var projects_access := DirAccess.open(projects_dir)
	if projects_access == null:
		return {}

	var file_name := "%s.jsonl" % session_id
	var visible_matches: Array[Dictionary] = []
	var first_error: Dictionary = {}
	for project_name in _sorted_directory_names(projects_access):
		var project_dir := _join_path(projects_dir, project_name)
		var file_path := _join_path(project_dir, file_name)
		var lite_result := _read_session_lite_result(file_path)
		if lite_result.is_empty() or lite_result.has("stub"):
			continue
		if lite_result.has("error"):
			if first_error.is_empty():
				first_error = {
					"error": int(lite_result.get("error", ERR_CANT_OPEN)),
					"path": file_path,
					"project_dir": project_dir,
					"message": "Failed to access session file at %s" % file_path,
				}
			continue
		var lite: LiteSessionFile = lite_result["lite"]
		var info = _parse_session_info_from_lite(session_id, lite)
		if info == null:
			continue
		visible_matches.append({
			"path": file_path,
			"project_dir": project_dir,
			"mtime": int(info.last_modified),
		})

	if visible_matches.is_empty():
		return first_error
	visible_matches.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("mtime", 0)) > int(b.get("mtime", 0)))
	return visible_matches[0]


static func _try_append(file_path: String, data: String) -> int:
	var file := FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		return _map_open_error(FileAccess.get_open_error())

	if file.get_length() <= 0:
		file.close()
		return SESSION_SEARCH_MISS

	file.seek_end()
	file.store_string(data)
	var write_error := file.get_error()
	file.close()
	return write_error if write_error != OK else OK


static func _map_open_error(error_code: int) -> int:
	if error_code == ERR_FILE_NOT_FOUND or error_code == ERR_FILE_BAD_PATH:
		return SESSION_SEARCH_MISS
	return error_code if error_code != OK else SESSION_SEARCH_MISS


static func _clear_last_error() -> void:
	_last_error = ""


static func _fail_mutation(error_code: int, message: String) -> int:
	_last_error = message
	return error_code


static func _fail_fork(message: String):
	_last_error = message
	return null


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


static func _parse_fork_transcript(content: String, session_id: String) -> Dictionary:
	var transcript: Array[Dictionary] = []
	var content_replacements: Array = []
	for line_variant in content.split("\n", false):
		var line := str(line_variant).strip_edges()
		if line.is_empty():
			continue
		var entry = JSON.parse_string(line)
		if not (entry is Dictionary):
			continue
		var dictionary := entry as Dictionary
		var entry_type := str(dictionary.get("type", ""))
		if TRANSCRIPT_ENTRY_TYPES.has(entry_type) and dictionary.get("uuid") is String:
			if bool(dictionary.get("isSidechain", false)):
				continue
			transcript.append(dictionary)
			continue
		if entry_type == "content-replacement" \
			and str(dictionary.get("sessionId", "")) == session_id \
			and dictionary.get("replacements") is Array:
			content_replacements.append_array((dictionary.get("replacements") as Array).duplicate(true))
	return {
		"transcript": transcript,
		"content_replacements": content_replacements,
	}


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


static func _resolve_fork_parent_uuid(original: Dictionary, by_uuid: Dictionary, uuid_mapping: Dictionary) -> Variant:
	var parent_id := original.get("parentUuid", null)
	while parent_id is String and not str(parent_id).is_empty():
		var parent := by_uuid.get(str(parent_id), null)
		if not (parent is Dictionary):
			break
		if str((parent as Dictionary).get("type", "")) != "progress":
			return uuid_mapping.get(str(parent_id), null)
		parent_id = (parent as Dictionary).get("parentUuid", null)
	return null


static func _derive_fork_title_base(content: String) -> String:
	var head := content.substr(0, mini(content.length(), LITE_READ_BUF_SIZE))
	var tail_start := maxi(0, content.length() - LITE_READ_BUF_SIZE)
	var tail := content.substr(tail_start)
	var custom_title = _extract_last_json_string_field(tail, "customTitle")
	if custom_title == null:
		custom_title = _extract_last_json_string_field(head, "customTitle")
	if custom_title != null and not str(custom_title).strip_edges().is_empty():
		return str(custom_title).strip_edges()
	var ai_title = _extract_last_json_string_field(tail, "aiTitle")
	if ai_title == null:
		ai_title = _extract_last_json_string_field(head, "aiTitle")
	if ai_title != null and not str(ai_title).strip_edges().is_empty():
		return str(ai_title).strip_edges()
	var first_prompt := _extract_first_prompt_from_head(head).strip_edges()
	if not first_prompt.is_empty():
		return first_prompt
	return "Forked session"


static func _generate_uuid_v4() -> String:
	var random_bytes := Crypto.new().generate_random_bytes(16)
	if random_bytes.size() < 16:
		return "%08x-%04x-4%03x-8%03x-%012x" % [
			randi(),
			randi() & 0xffff,
			randi() & 0x0fff,
			randi() & 0x0fff,
			randi(),
		]
	random_bytes[6] = (int(random_bytes[6]) & 0x0f) | 0x40
	random_bytes[8] = (int(random_bytes[8]) & 0x3f) | 0x80
	var parts := [
		_hex_bytes(random_bytes, 0, 4),
		_hex_bytes(random_bytes, 4, 2),
		_hex_bytes(random_bytes, 6, 2),
		_hex_bytes(random_bytes, 8, 2),
		_hex_bytes(random_bytes, 10, 6),
	]
	return "-".join(parts)


static func _hex_bytes(bytes: PackedByteArray, offset: int, count: int) -> String:
	var result := ""
	for index in range(offset, offset + count):
		result += "%02x" % int(bytes[index])
	return result


static func _utc_now_iso8601_z() -> String:
	return Time.get_datetime_string_from_system(true, true).replace(" ", "T") + "Z"


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


static func _expand_session_transcript_entry(entry: Dictionary) -> Array[ClaudeSessionTranscriptEntry]:
	var entry_type := str(entry.get("type", ""))
	if entry_type == "user":
		return _expand_user_transcript_entry(entry)
	if entry_type == "assistant":
		return _expand_assistant_transcript_entry(entry)
	if entry_type == "system":
		return [_build_non_chat_transcript_entry(entry, "System", entry.get("subtype"))]
	if entry_type == "progress":
		return [_build_non_chat_transcript_entry(entry, "Progress")]
	if entry_type == "attachment":
		return [_build_non_chat_transcript_entry(entry, "Attachment")]
	return []


static func _expand_user_transcript_entry(entry: Dictionary) -> Array[ClaudeSessionTranscriptEntry]:
	var message := entry.get("message", {}) if entry.get("message", {}) is Dictionary else {}
	var text := _session_message_text(message)
	if text.is_empty():
		return []
	return [
		ClaudeSessionTranscriptEntryScript.new(
			"user",
			str(entry.get("uuid", "")),
			str(entry.get("sessionId", "")),
			"You",
			text,
			_duplicate_variant(message),
			_duplicate_variant(entry),
			null
		),
	]


static func _expand_assistant_transcript_entry(entry: Dictionary) -> Array[ClaudeSessionTranscriptEntry]:
	var message := entry.get("message", {}) if entry.get("message", {}) is Dictionary else {}
	var content: Variant = message.get("content")
	if content is String:
		var text := str(content).strip_edges()
		if text.is_empty():
			return []
		return [
			ClaudeSessionTranscriptEntryScript.new(
				"assistant",
				str(entry.get("uuid", "")),
				str(entry.get("sessionId", "")),
				"Claude",
				text,
				_duplicate_variant(message),
				_duplicate_variant(entry),
				str(entry.get("parent_tool_use_id", ""))
			),
		]
	if content is not Array:
		return []

	var transcript: Array[ClaudeSessionTranscriptEntry] = []
	var current_kind := ""
	var current_title := ""
	var current_parts: Array[String] = []
	var current_payloads: Array = []

	for block_variant in content:
		if block_variant is not Dictionary:
			continue
		var block := block_variant as Dictionary
		match str(block.get("type", "")):
			"text":
				if current_kind != "assistant":
					_flush_assistant_transcript_segment(
						transcript,
						entry,
						current_kind,
						current_title,
						current_parts,
						current_payloads
					)
					current_kind = "assistant"
					current_title = "Claude"
				var text := str(block.get("text", "")).strip_edges()
				if not text.is_empty():
					current_parts.append(text)
					current_payloads.append(_duplicate_variant(block))
			"thinking":
				if current_kind != "thinking":
					_flush_assistant_transcript_segment(
						transcript,
						entry,
						current_kind,
						current_title,
						current_parts,
						current_payloads
					)
					current_kind = "thinking"
					current_title = "Thinking"
				var thinking := str(block.get("thinking", "")).strip_edges()
				if not thinking.is_empty():
					current_parts.append(thinking)
					current_payloads.append(_duplicate_variant(block))
			"tool_use":
				_flush_assistant_transcript_segment(
					transcript,
					entry,
					current_kind,
					current_title,
					current_parts,
					current_payloads
				)
				current_kind = ""
				current_title = ""
				current_parts.clear()
				current_payloads.clear()
				transcript.append(
					ClaudeSessionTranscriptEntryScript.new(
						"tool_use",
						str(entry.get("uuid", "")),
						str(entry.get("sessionId", "")),
						"Tool use · %s" % str(block.get("name", "")),
						_session_transcript_body_text(block.get("input", {}) if block.get("input", {}) is Dictionary else {}),
						_duplicate_variant(block.get("input", {}) if block.get("input", {}) is Dictionary else {}),
						_duplicate_variant(block),
						str(block.get("id", ""))
					)
				)
			"tool_result":
				_flush_assistant_transcript_segment(
					transcript,
					entry,
					current_kind,
					current_title,
					current_parts,
					current_payloads
				)
				current_kind = ""
				current_title = ""
				current_parts.clear()
				current_payloads.clear()
				var result_title := "Tool result"
				if bool(block.get("is_error", false)):
					result_title += " · error"
				transcript.append(
					ClaudeSessionTranscriptEntryScript.new(
						"tool_result",
						str(entry.get("uuid", "")),
						str(entry.get("sessionId", "")),
						result_title,
						_session_transcript_body_text(block.get("content")),
						_duplicate_variant(block.get("content")),
						_duplicate_variant(block),
						str(block.get("tool_use_id", ""))
					)
				)
			_:
				continue

	_flush_assistant_transcript_segment(
		transcript,
		entry,
		current_kind,
		current_title,
		current_parts,
		current_payloads
	)
	return transcript


static func _flush_assistant_transcript_segment(
	transcript: Array[ClaudeSessionTranscriptEntry],
	entry: Dictionary,
	current_kind: String,
	current_title: String,
	current_parts: Array[String],
	current_payloads: Array
) -> void:
	if current_parts.is_empty():
		return
	var part_snapshot := current_parts.duplicate()
	var payload_snapshot := _duplicate_variant(current_payloads)
	var combined_text := "\n\n".join(part_snapshot).strip_edges()
	current_parts.clear()
	current_payloads.clear()
	if combined_text.is_empty():
		return
	transcript.append(
		ClaudeSessionTranscriptEntryScript.new(
			current_kind,
			str(entry.get("uuid", "")),
			str(entry.get("sessionId", "")),
			current_title,
			combined_text,
			payload_snapshot,
			_duplicate_variant(entry),
			str(entry.get("parent_tool_use_id", ""))
		)
	)


static func _build_non_chat_transcript_entry(
	entry: Dictionary,
	base_title: String,
	subtype: Variant = null
) -> ClaudeSessionTranscriptEntry:
	var entry_type := str(entry.get("type", ""))
	var title := base_title
	var subtype_text := str(subtype).strip_edges()
	if subtype_text.is_empty():
		var message = entry.get("message")
		if message is Dictionary:
			subtype_text = str((message as Dictionary).get("subtype", "")).strip_edges()
	if entry_type == "system" and not subtype_text.is_empty():
		title = "%s · %s" % [base_title, subtype_text]
	var payload := _session_transcript_payload(entry)
	return ClaudeSessionTranscriptEntryScript.new(
		entry_type,
		str(entry.get("uuid", "")),
		str(entry.get("sessionId", "")),
		title,
		_non_chat_transcript_text(entry_type, payload, entry),
		_duplicate_variant(payload),
		_duplicate_variant(entry),
		str(entry.get("parent_tool_use_id", ""))
	)


static func _session_transcript_payload(entry: Dictionary) -> Variant:
	var message := entry.get("message", null)
	if message != null:
		return message
	return entry


static func _non_chat_transcript_text(entry_type: String, payload: Variant, entry: Dictionary) -> String:
	match entry_type:
		"system":
			var system_text := _extract_first_non_empty_text([
				_extract_dictionary_string(payload, ["content", "text", "message", "summary", "status"]),
				_extract_dictionary_string(entry, ["content", "text", "message", "summary", "status"]),
			])
			if not system_text.is_empty():
				return system_text
		"progress":
			var progress_text := _extract_first_non_empty_text([
				_extract_dictionary_string(payload, ["summary", "message", "status", "content", "text"]),
				_extract_dictionary_string(entry, ["summary", "message", "status", "content", "text"]),
			])
			if not progress_text.is_empty():
				return progress_text
		"attachment":
			var attachment_text := _extract_first_non_empty_text([
				_extract_dictionary_string(payload, ["name", "title", "filename", "path", "description", "mimeType"]),
				_extract_dictionary_string(entry, ["name", "title", "filename", "path", "description", "mimeType"]),
			])
			if not attachment_text.is_empty():
				return attachment_text
	return _session_transcript_body_text(payload)


static func _extract_first_non_empty_text(values: Array[String]) -> String:
	for value in values:
		var normalized := value.strip_edges()
		if not normalized.is_empty():
			return normalized
	return ""


static func _extract_dictionary_string(value: Variant, keys: Array[String]) -> String:
	if value is not Dictionary:
		return ""
	var dictionary := value as Dictionary
	for key in keys:
		if not dictionary.has(key):
			continue
		var candidate := dictionary.get(key)
		if candidate is String:
			var normalized := str(candidate).strip_edges()
			if not normalized.is_empty():
				return normalized
	return ""


static func _session_message_text(message: Dictionary) -> String:
	var content: Variant = message.get("content")
	if content is String:
		return str(content).strip_edges()
	if content is not Array:
		return ""
	var parts: Array[String] = []
	for block_variant in content:
		if block_variant is not Dictionary:
			continue
		var block := block_variant as Dictionary
		if str(block.get("type", "")) != "text":
			continue
		var text := str(block.get("text", "")).strip_edges()
		if not text.is_empty():
			parts.append(text)
	return "\n\n".join(parts)


static func _session_transcript_body_text(value: Variant) -> String:
	if value == null:
		return "null"
	if value is Dictionary or value is Array:
		return JSON.stringify(value, "\t")
	return str(value)


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
