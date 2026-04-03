extends RefCounted
class_name FakeClaudeTransport

signal stdout_line(line: String)
signal stderr_line(line: String)
signal transport_closed
signal transport_error(message: String)

var connected := false
var writes: Array[String] = []
var _last_error := ""


func open_transport() -> bool:
	connected = true
	return true


func write(payload: String) -> bool:
	if not connected:
		_set_last_error("FakeClaudeTransport is not connected")
		return false
	writes.append(payload)
	return true


func close() -> void:
	connected = false
	transport_closed.emit()


func transport_is_connected() -> bool:
	return connected


func get_last_error() -> String:
	return _last_error


func emit_stdout_message(payload: Dictionary) -> void:
	stdout_line.emit(JSON.stringify(payload))


func emit_stderr_message(line: String) -> void:
	stderr_line.emit(line)


func emit_transport_failure(message: String) -> void:
	_set_last_error(message)


func _set_last_error(message: String) -> void:
	_last_error = message
	push_error(message)
	transport_error.emit(message)
