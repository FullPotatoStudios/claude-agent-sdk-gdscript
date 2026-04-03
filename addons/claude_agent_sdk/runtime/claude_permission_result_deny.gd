extends RefCounted
class_name ClaudePermissionResultDeny

var behavior: String = "deny"
var message: String = ""
var interrupt: bool = false


func _init(value_message: String = "", value_interrupt: bool = false) -> void:
	message = value_message
	interrupt = value_interrupt
