extends RefCounted
class_name ClaudeSessionTranscriptEntry

var kind: String = ""
var uuid: String = ""
var session_id: String = ""
var title: String = ""
var text: String = ""
var payload: Variant = null
var raw_data: Variant = null
var parent_tool_use_id: Variant = null


func _init(
	value_kind: String = "",
	value_uuid: String = "",
	value_session_id: String = "",
	value_title: String = "",
	value_text: String = "",
	value_payload: Variant = null,
	value_raw_data: Variant = null,
	value_parent_tool_use_id: Variant = null
) -> void:
	kind = value_kind
	uuid = value_uuid
	session_id = value_session_id
	title = value_title
	text = value_text
	payload = value_payload
	raw_data = value_raw_data
	parent_tool_use_id = value_parent_tool_use_id
