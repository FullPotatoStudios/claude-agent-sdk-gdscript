extends RefCounted
class_name ClaudeHookContext

const ClaudeHookInputScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input.gd")

var callback_signal: Variant = null
var raw_input: Dictionary = {}
var typed_input: Variant = null


func _init(value_signal: Variant = null, value_raw_input: Dictionary = {}, value_typed_input: Variant = null) -> void:
	callback_signal = value_signal
	raw_input = value_raw_input.duplicate(true)
	typed_input = ClaudeHookInputScript.coerce_input(
		value_typed_input if value_typed_input != null else raw_input
	)


func _get(property):
	if property == "signal":
		return callback_signal
	if property == "hook_input":
		return typed_input
	return null


func _set(property, value) -> bool:
	if property == "signal":
		callback_signal = value
		return true
	if property == "hook_input":
		typed_input = ClaudeHookInputScript.coerce_input(value)
		return true
	return false


func _get_property_list() -> Array:
	return [
		{
			"name": "signal",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			"name": "hook_input",
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
	]
