extends RefCounted
class_name ClaudeSessionListSubkeysKey

# Lookup key for `ClaudeSessionStore.list_subkeys`.
#
# Mirrors upstream's session-subkeys list shape: identifies a single session by
# `project_key` + `session_id`. The store enumerates known subkeys (e.g.
# `subagents/agent-<id>`) under that session.

var project_key: String = ""
var session_id: String = ""


func _init(p_project_key: String = "", p_session_id: String = "") -> void:
	project_key = p_project_key
	session_id = p_session_id


func to_dictionary() -> Dictionary:
	return {
		"project_key": project_key,
		"session_id": session_id,
	}
