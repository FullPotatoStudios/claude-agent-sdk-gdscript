extends RefCounted
class_name ClaudeSessionStoreListEntry

# A lightweight session record returned from `ClaudeSessionStore.list_sessions`.
#
# `mtime` is in Unix epoch milliseconds (matches upstream `types.py:1308` and
# the existing `ClaudeSessionInfo.last_modified` units).

var session_id: String = ""
var mtime: int = 0


func _init(p_session_id: String = "", p_mtime: int = 0) -> void:
	session_id = p_session_id
	mtime = p_mtime


func to_dictionary() -> Dictionary:
	return {
		"session_id": session_id,
		"mtime": mtime,
	}
