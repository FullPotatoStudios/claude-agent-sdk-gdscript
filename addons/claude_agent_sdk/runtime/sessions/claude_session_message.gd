extends RefCounted
class_name ClaudeSessionMessage

var type: String = ""
var uuid: String = ""
var session_id: String = ""
var message: Variant = null
var parent_tool_use_id: Variant = null


func _init(
	value_type: String = "",
	value_uuid: String = "",
	value_session_id: String = "",
	value_message: Variant = null,
	value_parent_tool_use_id: Variant = null
) -> void:
	type = value_type
	uuid = value_uuid
	session_id = value_session_id
	message = value_message
	parent_tool_use_id = value_parent_tool_use_id