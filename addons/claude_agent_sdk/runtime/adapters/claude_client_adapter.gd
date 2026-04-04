extends RefCounted
class_name ClaudeClientAdapter

signal session_ready(server_info: Dictionary)
signal turn_started(prompt: String, session_id: String)
signal message_received(message: Variant)
signal turn_message_received(message: Variant)
signal turn_finished(result_message: ClaudeResultMessage)
signal busy_changed(is_busy: bool)
signal error_occurred(message: String)
signal session_closed()

const ClaudeSDKClientScript := preload("res://addons/claude_agent_sdk/runtime/claude_sdk_client.gd")
const ClaudeSessionsScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_sessions.gd")

var _client = null
var _connected := false
var _busy := false
var _last_error := ""
var _session_ready_emitted := false
var _active_token := 0
var _closed_token := -1


func _init(initial_options = null, transport = null) -> void:
	_client = ClaudeSDKClientScript.new(initial_options, transport)
	_client.session_initialized.connect(_on_client_session_initialized)
	_client.error_occurred.connect(_on_client_error_occurred)


func connect_client() -> void:
	if _connected:
		return

	_last_error = ""
	_client.connect_client()
	var stream = _client.receive_messages()
	if not stream.get_error().is_empty():
		_client.disconnect_client()
		return

	_connected = true
	_session_ready_emitted = false
	_active_token += 1
	var token := _active_token
	Callable(self, "_run_message_drain").call_deferred(token, stream)


func disconnect_client() -> void:
	if not _connected:
		_client.disconnect_client()
		return

	var token := _active_token
	_active_token += 1
	_connected = false
	_client.disconnect_client()
	_set_busy(false)
	_emit_session_closed_once(token)


func query(prompt: String, session_id: String = "default") -> void:
	if not _connected or _busy:
		_client.query(prompt, session_id)
		return

	_client.query(prompt, session_id)
	_set_busy(true)
	turn_started.emit(prompt, session_id)


func interrupt() -> void:
	_client.interrupt()


func set_permission_mode(mode: String) -> void:
	_client.set_permission_mode(mode)


func set_model(model: String = "") -> void:
	_client.set_model(model)


func get_server_info() -> Dictionary:
	return _client.get_server_info()


func get_auth_status() -> Dictionary:
	var result: Dictionary = _client.get_auth_status()
	var error_message := str(result.get("error_message", ""))
	_last_error = error_message
	return result


func list_sessions(
	directory: String = "",
	limit: int = 0,
	offset: int = 0,
	include_worktrees: bool = true
) -> Array[ClaudeSessionInfo]:
	return ClaudeSessionsScript.list_sessions(directory, limit, offset, include_worktrees)


func get_session_info(session_id: String, directory: String = ""):
	return ClaudeSessionsScript.get_session_info(session_id, directory)


func get_session_messages(
	session_id: String,
	directory: String = "",
	limit: int = 0,
	offset: int = 0
) -> Array[ClaudeSessionMessage]:
	return ClaudeSessionsScript.get_session_messages(session_id, directory, limit, offset)


func rename_session(session_id: String, title: String, directory: String = "") -> int:
	return _handle_session_mutation_result(ClaudeSessionsScript.rename_session(session_id, title, directory))


func tag_session(session_id: String, tag: Variant = null, directory: String = "") -> int:
	return _handle_session_mutation_result(ClaudeSessionsScript.tag_session(session_id, tag, directory))


func delete_session(session_id: String, directory: String = "") -> int:
	return _handle_session_mutation_result(ClaudeSessionsScript.delete_session(session_id, directory))


func get_context_usage() -> Dictionary:
	return await _client.get_context_usage()


func get_mcp_status() -> Dictionary:
	return await _client.get_mcp_status()


func reconnect_mcp_server(server_name: String) -> void:
	await _client.reconnect_mcp_server(server_name)


func toggle_mcp_server(server_name: String, enabled: bool) -> void:
	await _client.toggle_mcp_server(server_name, enabled)


func get_last_error() -> String:
	if not _last_error.is_empty():
		return _last_error
	var client_error: String = _client.get_last_error()
	if not client_error.is_empty():
		return client_error
	return ""


func is_client_connected() -> bool:
	return _connected


func is_busy() -> bool:
	return _busy


func _run_message_drain(token: int, stream) -> void:
	if token != _active_token:
		return

	while token == _active_token:
		var message: Variant = await stream.next_message()
		if token != _active_token:
			return
		if message == null:
			break

		message_received.emit(message)
		if _busy:
			turn_message_received.emit(message)
			if message is ClaudeResultMessage:
				_set_busy(false)
				turn_finished.emit(message)

	if token != _active_token:
		return

	_connected = false
	_set_busy(false)
	_emit_session_closed_once(token)

func _set_busy(value: bool) -> void:
	if _busy == value:
		return
	_busy = value
	busy_changed.emit(_busy)


func _emit_session_closed_once(token: int) -> void:
	if _closed_token == token:
		return
	_closed_token = token
	session_closed.emit()


func _on_client_session_initialized(server_info: Dictionary) -> void:
	if not _connected or _session_ready_emitted:
		return
	_session_ready_emitted = true
	session_ready.emit(server_info.duplicate(true))


func _on_client_error_occurred(message: String) -> void:
	_emit_error(message)


func _emit_error(message: String) -> void:
	if message.is_empty():
		return
	_last_error = message
	error_occurred.emit(message)


func _handle_session_mutation_result(result: int) -> int:
	if result == OK:
		_last_error = ""
		return OK
	_emit_error(ClaudeSessionsScript.get_last_error())
	return result
