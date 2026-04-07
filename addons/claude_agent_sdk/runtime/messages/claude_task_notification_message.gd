extends "res://addons/claude_agent_sdk/runtime/messages/claude_system_message.gd"
class_name ClaudeTaskNotificationMessage

var task_id: String = ""
var status: String = ""
var output_file: String = ""
var summary: String = ""
var uuid: String = ""
var session_id: String = ""
var tool_use_id: String = ""
var usage: Dictionary = {}


func _init(
	raw: Dictionary = {},
	value_task_id: String = "",
	value_status: String = "",
	value_output_file: String = "",
	value_summary: String = "",
	value_uuid: String = "",
	value_session_id: String = "",
	value_tool_use_id: String = "",
	value_usage: Dictionary = {}
) -> void:
	super._init("task_notification", raw)
	task_id = value_task_id
	status = value_status
	output_file = value_output_file
	summary = value_summary
	uuid = value_uuid
	session_id = value_session_id
	tool_use_id = value_tool_use_id
	usage = value_usage.duplicate(true)
