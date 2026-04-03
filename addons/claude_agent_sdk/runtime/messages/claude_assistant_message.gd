extends "res://addons/claude_agent_sdk/runtime/messages/claude_sdk_message.gd"
class_name ClaudeAssistantMessage

var content: Array = []
var model: String = ""
var parent_tool_use_id: String = ""
var error: String = ""
var usage: Dictionary = {}
var message_id: String = ""
var stop_reason: String = ""
var session_id: String = ""
var uuid: String = ""


func _init(
	value_content: Array = [],
	value_model: String = "",
	raw: Dictionary = {},
	value_parent_tool_use_id: String = "",
	value_error: String = "",
	value_usage: Dictionary = {},
	value_message_id: String = "",
	value_stop_reason: String = "",
	value_session_id: String = "",
	value_uuid: String = ""
) -> void:
	super._init("assistant", raw)
	content = value_content.duplicate()
	model = value_model
	parent_tool_use_id = value_parent_tool_use_id
	error = value_error
	usage = value_usage.duplicate(true)
	message_id = value_message_id
	stop_reason = value_stop_reason
	session_id = value_session_id
	uuid = value_uuid
