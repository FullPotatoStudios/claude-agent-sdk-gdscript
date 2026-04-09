extends "res://addons/claude_agent_sdk/runtime/messages/claude_sdk_message.gd"
class_name ClaudeStreamEvent

var session_id: String = ""
var uuid: String = ""
var event: Variant = null
var parent_tool_use_id: String = ""


func _init(
	raw: Dictionary = {},
	value_session_id: String = "",
	value_uuid: String = "",
	value_event: Variant = null,
	value_parent_tool_use_id: String = ""
) -> void:
	super._init("stream_event", raw)
	session_id = value_session_id
	uuid = value_uuid
	if value_event is Dictionary or value_event is Array:
		event = value_event.duplicate(true)
	else:
		event = value_event
	parent_tool_use_id = value_parent_tool_use_id
