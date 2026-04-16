extends RefCounted
class_name FakeClaudeTransport

signal stdout_line(line: String)
signal stderr_line(line: String)
signal transport_closed
signal transport_error(message: String)

var connected := false
var input_ended := false
var end_input_supported := true
var end_input_success := true
var writes: Array[String] = []
var transport_events: Array[String] = []
var end_input_calls := 0
var open_error_message := ""
var auth_status_result: Dictionary = {
	"ok": true,
	"logged_in": true,
	"auth_method": "claude.ai",
	"api_provider": "firstParty",
	"email": "tester@example.com",
	"org_id": "org-test",
	"org_name": "Test Org",
	"subscription_type": "max",
	"raw": {"loggedIn": true},
	"stdout": "",
	"stderr": "",
	"error_code": "",
	"error_message": "",
	"exit_code": 0,
}
var _last_error := ""


func open_transport() -> bool:
	if not open_error_message.is_empty():
		_set_last_error(open_error_message)
		return false
	connected = true
	input_ended = false
	transport_events.append("open")
	return true


func write(payload: String) -> bool:
	if not connected:
		_set_last_error("FakeClaudeTransport is not connected")
		return false
	writes.append(payload)
	transport_events.append("write")
	return true


func supports_end_input() -> bool:
	return end_input_supported


func end_input() -> bool:
	if not end_input_supported:
		return false
	if not connected:
		_set_last_error("FakeClaudeTransport is not connected")
		return false
	if not end_input_success:
		return false
	input_ended = true
	end_input_calls += 1
	transport_events.append("end_input")
	return true


func close() -> void:
	connected = false
	transport_events.append("close")
	transport_closed.emit()


func transport_is_connected() -> bool:
	return connected


func get_last_error() -> String:
	return _last_error


func probe_auth_status() -> Dictionary:
	return auth_status_result.duplicate(true)


func emit_stdout_message(payload: Dictionary) -> void:
	stdout_line.emit(JSON.stringify(payload))


func emit_stdout_line(line: String) -> void:
	stdout_line.emit(line)


func emit_stderr_message(line: String) -> void:
	stderr_line.emit(line)


func emit_transport_failure(message: String) -> void:
	_set_last_error(message)


func stdout_listener_count() -> int:
	return stdout_line.get_connections().size()


func stderr_listener_count() -> int:
	return stderr_line.get_connections().size()


func closed_listener_count() -> int:
	return transport_closed.get_connections().size()


func error_listener_count() -> int:
	return transport_error.get_connections().size()


func _set_last_error(message: String) -> void:
	_last_error = message
	transport_error.emit(message)
