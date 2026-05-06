extends "res://addons/claude_agent_sdk/runtime/messages/claude_system_message.gd"
class_name ClaudeHookEventMessage

var hook_event_name: String = ""
var session_id: String = ""
var uuid: String = ""


func _init(
	value_subtype: String = "",
	value_hook_event_name: String = "",
	value_session_id: String = "",
	value_uuid: String = "",
	raw: Dictionary = {}
) -> void:
	super._init(value_subtype, raw)
	hook_event_name = value_hook_event_name
	session_id = value_session_id
	uuid = value_uuid
