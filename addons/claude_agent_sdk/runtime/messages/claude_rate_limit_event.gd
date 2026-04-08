extends "res://addons/claude_agent_sdk/runtime/messages/claude_sdk_message.gd"
class_name ClaudeRateLimitEvent

var rate_limit_info: ClaudeRateLimitInfo = null
var uuid: String = ""
var session_id: String = ""


func _init(
	raw: Dictionary = {},
	value_rate_limit_info: ClaudeRateLimitInfo = null,
	value_uuid: String = "",
	value_session_id: String = ""
) -> void:
	super._init("rate_limit_event", raw)
	rate_limit_info = value_rate_limit_info
	uuid = value_uuid
	session_id = value_session_id
