extends RefCounted
class_name ClaudeSDKClient

const ClaudeMessageStreamScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_message_stream.gd")
const ClaudeQuerySessionScript := preload("res://addons/claude_agent_sdk/runtime/protocol/query_session.gd")
const ClaudeSubprocessCLITransportScript := preload("res://addons/claude_agent_sdk/runtime/transport/subprocess_cli_transport.gd")
const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")

var options = null
var _transport = null
var _session = null
var _last_error := ""


func _init(initial_options = null, transport = null) -> void:
	options = initial_options if initial_options != null else ClaudeAgentOptionsScript.new()
	_transport = transport if transport != null else ClaudeSubprocessCLITransportScript.new(options)


func connect_client() -> void:
	if _session != null:
		return
	_session = ClaudeQuerySessionScript.new(_transport)
	_session.open_session()
	_last_error = _session.get_last_error()


func query(prompt: String, session_id: String = "default") -> void:
	if _session == null:
		_set_last_error("Call connect_client() before query()")
		return
	_session.send_user_prompt(prompt, session_id)
	_last_error = _session.get_last_error()


func receive_messages():
	if _session == null:
		var stream = ClaudeMessageStreamScript.new(false)
		stream.fail("Call connect_client() before receive_messages()")
		return stream
	return _session.receive_messages()


func receive_response():
	if _session == null:
		var stream = ClaudeMessageStreamScript.new(true)
		stream.fail("Call connect_client() before receive_response()")
		return stream
	return _session.receive_response()


func disconnect_client() -> void:
	if _session == null:
		return
	_session.close()
	_session = null


func interrupt() -> void:
	if _session == null:
		_set_last_error("Call connect_client() before interrupt()")
		return
	_session.interrupt()
	_last_error = _session.get_last_error()


func set_permission_mode(mode: String) -> void:
	if _session == null:
		_set_last_error("Call connect_client() before set_permission_mode()")
		return
	_session.set_permission_mode(mode)
	_last_error = _session.get_last_error()


func set_model(model: String = "") -> void:
	if _session == null:
		_set_last_error("Call connect_client() before set_model()")
		return
	_session.set_model(model)
	_last_error = _session.get_last_error()


func get_server_info() -> Dictionary:
	if _session == null:
		return {}
	return _session.get_server_info()


func get_last_error() -> String:
	if _session != null and not _session.get_last_error().is_empty():
		return _session.get_last_error()
	return _last_error


func _set_last_error(message: String) -> void:
	_last_error = message
	push_error(message)
