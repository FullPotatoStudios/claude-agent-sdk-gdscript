extends "res://addons/claude_agent_sdk/runtime/messages/claude_system_message.gd"
class_name ClaudeTaskStartedMessage

var task_id: String = ""
var description: String = ""
var uuid: String = ""
var session_id: String = ""
var tool_use_id: String = ""
var task_type: String = ""


func _init(
	raw: Dictionary = {},
	value_task_id: String = "",
	value_description: String = "",
	value_uuid: String = "",
	value_session_id: String = "",
	value_tool_use_id: String = "",
	value_task_type: String = ""
) -> void:
	super._init("task_started", raw)
	task_id = value_task_id
	description = value_description
	uuid = value_uuid
	session_id = value_session_id
	tool_use_id = value_tool_use_id
	task_type = value_task_type
