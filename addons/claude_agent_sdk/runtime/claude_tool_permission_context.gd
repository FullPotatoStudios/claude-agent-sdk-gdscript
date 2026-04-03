extends RefCounted
class_name ClaudeToolPermissionContext

var callback_signal: Variant = null
var suggestions: Array = []
var tool_use_id: String = ""
var agent_id: String = ""


func _init(
	value_signal: Variant = null,
	value_suggestions: Array = [],
	value_tool_use_id: String = "",
	value_agent_id: String = ""
) -> void:
	callback_signal = value_signal
	suggestions = value_suggestions.duplicate(true)
	tool_use_id = value_tool_use_id
	agent_id = value_agent_id
