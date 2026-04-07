extends "res://addons/claude_agent_sdk/runtime/messages/claude_system_message.gd"
class_name ClaudeTaskProgressMessage

var task_id: String = ""
var description: String = ""
var usage: Dictionary = {}
var uuid: String = ""
var session_id: String = ""
var tool_use_id: String = ""
var last_tool_name: String = ""


func _init(
	raw: Dictionary = {},
	value_task_id: String = "",
	value_description: String = "",
	value_usage: Dictionary = {},
	value_uuid: String = "",
	value_session_id: String = "",
	value_tool_use_id: String = "",
	value_last_tool_name: String = ""
) -> void:
	super._init("task_progress", raw)
	task_id = value_task_id
	description = value_description
	usage = value_usage.duplicate(true)
	uuid = value_uuid
	session_id = value_session_id
	tool_use_id = value_tool_use_id
	last_tool_name = value_last_tool_name
