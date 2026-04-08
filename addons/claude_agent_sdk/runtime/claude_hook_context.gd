extends RefCounted
class_name ClaudeHookContext

var callback_signal: Variant = null


func _init(value_signal: Variant = null) -> void:
	callback_signal = value_signal


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
