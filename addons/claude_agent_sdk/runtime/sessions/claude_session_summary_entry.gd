extends RefCounted
class_name ClaudeSessionSummaryEntry

# A session summary record returned from `ClaudeSessionStore.list_session_summaries`.
#
# `mtime` is Unix epoch milliseconds. `data` is opaque, SDK-owned state used
# by upstream's `fold_session_summary` flow; the GDScript MVP keeps it as an
# empty dictionary and defers populating it to a v2 follow-up.

var session_id: String = ""
var mtime: int = 0
var data: Dictionary = {}


func _init(
	p_session_id: String = "",
	p_mtime: int = 0,
	p_data: Dictionary = {}
) -> void:
	session_id = p_session_id
	mtime = p_mtime
	data = p_data.duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"session_id": session_id,
		"mtime": mtime,
		"data": data.duplicate(true),
	}
