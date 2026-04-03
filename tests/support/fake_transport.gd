extends RefCounted
class_name FakeClaudeTransport

signal stdout_line(line: String)
signal stderr_line(line: String)
signal transport_closed
signal transport_error(message: String)

var connected := false
var writes: Array[String] = []
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
	push_error(message)
	transport_error.emit(message)
