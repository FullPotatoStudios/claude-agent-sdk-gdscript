extends "res://addons/claude_agent_sdk/runtime/messages/claude_sdk_message.gd"
class_name ClaudeResultMessage

var subtype: String = ""
var duration_ms: int = 0
var duration_api_ms: int = 0
var is_error: bool = false
var num_turns: int = 0
var session_id: String = ""
var stop_reason: String = ""
var total_cost_usd: float = 0.0
var usage: Dictionary = {}
var result: String = ""
var uuid: String = ""


func _init(
	value_subtype: String = "",
	raw: Dictionary = {},
	value_duration_ms: int = 0,
	value_duration_api_ms: int = 0,
	value_is_error: bool = false,
	value_num_turns: int = 0,
	value_session_id: String = "",
	value_stop_reason: String = "",
	value_total_cost_usd: float = 0.0,
	value_usage: Dictionary = {},
	value_result: String = "",
	value_uuid: String = ""
) -> void:
	super._init("result", raw)
	subtype = value_subtype
	duration_ms = value_duration_ms
	duration_api_ms = value_duration_api_ms
	is_error = value_is_error
	num_turns = value_num_turns
	session_id = value_session_id
	stop_reason = value_stop_reason
	total_cost_usd = value_total_cost_usd
	usage = value_usage.duplicate(true)
	result = value_result
	uuid = value_uuid
