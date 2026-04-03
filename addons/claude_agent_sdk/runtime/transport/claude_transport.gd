extends RefCounted
class_name ClaudeTransport

signal stdout_line(line: String)
signal stderr_line(line: String)
signal transport_closed
signal transport_error(message: String)

var _last_error := ""


func open_transport() -> bool:
	_set_last_error("ClaudeTransport.open_transport() is abstract")
	return false


func write(_payload: String) -> bool:
	_set_last_error("ClaudeTransport.write() is abstract")
	return false


func close() -> void:
	pass


func transport_is_connected() -> bool:
	return false


func get_pid() -> int:
	return 0


func get_last_error() -> String:
	return _last_error


func _set_last_error(message: String) -> void:
	_last_error = message
	push_error(message)
	transport_error.emit(message)
