extends RefCounted
class_name ClaudeSessionKey

# Identifies a session entry within a ClaudeSessionStore.
#
# `project_key` is the sanitized project identifier (matches
# `ClaudeSessions._sanitize_path` output for on-disk stores). `session_id` is
# the session UUID. `subpath` is reserved for subagent transcripts; leave it
# empty for top-level session entries.

var project_key: String = ""
var session_id: String = ""
var subpath: String = ""


func _init(
	p_project_key: String = "",
	p_session_id: String = "",
	p_subpath: String = ""
) -> void:
	project_key = p_project_key
	session_id = p_session_id
	subpath = p_subpath
	if project_key.is_empty():
		push_warning("ClaudeSessionKey created with empty project_key")
	if session_id.is_empty():
		push_warning("ClaudeSessionKey created with empty session_id")


func to_dictionary() -> Dictionary:
	var result: Dictionary = {
		"project_key": project_key,
		"session_id": session_id,
	}
	if not subpath.is_empty():
		result["subpath"] = subpath
	return result


static func from_dictionary(d: Dictionary) -> ClaudeSessionKey:
	return ClaudeSessionKey.new(
		str(d.get("project_key", "")),
		str(d.get("session_id", "")),
		str(d.get("subpath", ""))
	)


func equals(other: ClaudeSessionKey) -> bool:
	if other == null:
		return false
	return (
		project_key == other.project_key
		and session_id == other.session_id
		and subpath == other.subpath
	)


func to_canonical_string() -> String:
	if subpath.is_empty():
		return "%s/%s" % [project_key, session_id]
	return "%s/%s/%s" % [project_key, session_id, subpath]
