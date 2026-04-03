extends RefCounted
class_name ClaudeHookContext

var callback_signal: Variant = null


func _init(value_signal: Variant = null) -> void:
	callback_signal = value_signal
