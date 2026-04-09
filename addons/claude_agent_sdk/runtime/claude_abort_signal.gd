extends RefCounted
class_name ClaudeAbortSignal

signal canceled(reason: String)

var _canceled := false
var _reason := ""


func cancel(reason: String = "canceled") -> void:
	if _canceled:
		return
	_canceled = true
	_reason = reason
	canceled.emit(_reason)


func is_canceled() -> bool:
	return _canceled


func get_reason() -> String:
	return _reason
