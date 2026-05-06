extends RefCounted
class_name ClaudeToolPermissionContext

const ClaudePermissionUpdateScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_update.gd")

var callback_signal: Variant = null
# `suggestions` holds typed ClaudePermissionUpdate instances so a callback can
# echo them back in ClaudePermissionResultAllow.updated_permissions without
# re-coercing — matching upstream Python `ToolPermissionContext.suggestions`.
var suggestions: Array = []
var tool_use_id: Variant = null
var agent_id: Variant = null


func _init(
	value_signal: Variant = null,
	value_suggestions: Array = [],
	value_tool_use_id: Variant = null,
	value_agent_id: Variant = null
) -> void:
	callback_signal = value_signal
	suggestions = ClaudePermissionUpdateScript.coerce_updates(value_suggestions)
	tool_use_id = value_tool_use_id
	agent_id = value_agent_id


# Backward-compat alias for callers that read the typed array under its old name.
var typed_suggestions: Array:
	get:
		return suggestions


func _get(property):
	if property == "signal":
		return callback_signal
	return null


func _set(property, value) -> bool:
	if property == "signal":
		callback_signal = value
		return true
	return false


func _get_property_list() -> Array:
	return [{
		"name": "signal",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SCRIPT_VARIABLE,
	}]
