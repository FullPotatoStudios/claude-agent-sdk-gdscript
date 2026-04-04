extends Node
class_name ClaudeClientNode

signal session_ready(server_info: Dictionary)
signal turn_started(prompt: String, session_id: String)
signal message_received(message: Variant)
signal turn_message_received(message: Variant)
signal turn_finished(result_message: ClaudeResultMessage)
signal busy_changed(is_busy: bool)
signal error_occurred(message: String)
signal session_closed()

const ClaudeClientAdapterScript := preload("res://addons/claude_agent_sdk/runtime/adapters/claude_client_adapter.gd")

var auto_connect_on_ready := false
var auto_disconnect_on_exit := true

var _adapter = null
var _adapter_bound := false


func _init(initial_options = null, transport = null) -> void:
	_adapter = ClaudeClientAdapterScript.new(initial_options, transport)
	_bind_adapter_signals()


func _ready() -> void:
	if auto_connect_on_ready:
		connect_client()


func _exit_tree() -> void:
	if auto_disconnect_on_exit:
		disconnect_client()


func connect_client() -> void:
	_adapter.connect_client()


func disconnect_client() -> void:
	_adapter.disconnect_client()


func query(prompt: String, session_id: String = "default") -> void:
	_adapter.query(prompt, session_id)


func interrupt() -> void:
	_adapter.interrupt()


func set_permission_mode(mode: String) -> void:
	_adapter.set_permission_mode(mode)


func set_model(model: String = "") -> void:
	_adapter.set_model(model)


func get_server_info() -> Dictionary:
	return _adapter.get_server_info()


func get_auth_status() -> Dictionary:
	return _adapter.get_auth_status()


func list_sessions(
	directory: String = "",
	limit: int = 0,
	offset: int = 0,
	include_worktrees: bool = true
) -> Array[ClaudeSessionInfo]:
	return _adapter.list_sessions(directory, limit, offset, include_worktrees)


func get_session_info(session_id: String, directory: String = ""):
	return _adapter.get_session_info(session_id, directory)


func get_session_messages(
	session_id: String,
	directory: String = "",
	limit: int = 0,
	offset: int = 0
) -> Array[ClaudeSessionMessage]:
	return _adapter.get_session_messages(session_id, directory, limit, offset)


func rename_session(session_id: String, title: String, directory: String = "") -> int:
	return _adapter.rename_session(session_id, title, directory)


func tag_session(session_id: String, tag: Variant = null, directory: String = "") -> int:
	return _adapter.tag_session(session_id, tag, directory)


func delete_session(session_id: String, directory: String = "") -> int:
	return _adapter.delete_session(session_id, directory)


func get_context_usage() -> Dictionary:
	return await _adapter.get_context_usage()


func get_mcp_status() -> Dictionary:
	return await _adapter.get_mcp_status()


func reconnect_mcp_server(server_name: String) -> void:
	await _adapter.reconnect_mcp_server(server_name)


func toggle_mcp_server(server_name: String, enabled: bool) -> void:
	await _adapter.toggle_mcp_server(server_name, enabled)


func get_last_error() -> String:
	return _adapter.get_last_error()


func is_client_connected() -> bool:
	return _adapter.is_client_connected()


func is_busy() -> bool:
	return _adapter.is_busy()


func _bind_adapter_signals() -> void:
	if _adapter_bound or _adapter == null:
		return
	_adapter_bound = true
	_adapter.session_ready.connect(_on_adapter_session_ready)
	_adapter.turn_started.connect(_on_adapter_turn_started)
	_adapter.message_received.connect(_on_adapter_message_received)
	_adapter.turn_message_received.connect(_on_adapter_turn_message_received)
	_adapter.turn_finished.connect(_on_adapter_turn_finished)
	_adapter.busy_changed.connect(_on_adapter_busy_changed)
	_adapter.error_occurred.connect(_on_adapter_error_occurred)
	_adapter.session_closed.connect(_on_adapter_session_closed)


func _on_adapter_session_ready(server_info: Dictionary) -> void:
	session_ready.emit(server_info)


func _on_adapter_turn_started(prompt: String, session_id: String) -> void:
	turn_started.emit(prompt, session_id)


func _on_adapter_message_received(message: Variant) -> void:
	message_received.emit(message)


func _on_adapter_turn_message_received(message: Variant) -> void:
	turn_message_received.emit(message)


func _on_adapter_turn_finished(result_message: ClaudeResultMessage) -> void:
	turn_finished.emit(result_message)


func _on_adapter_busy_changed(is_busy: bool) -> void:
	busy_changed.emit(is_busy)


func _on_adapter_error_occurred(message: String) -> void:
	error_occurred.emit(message)


func _on_adapter_session_closed() -> void:
	session_closed.emit()
