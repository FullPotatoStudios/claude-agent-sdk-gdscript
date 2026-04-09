extends RefCounted
class_name ClaudeSDKClient

signal session_initialized(server_info: Dictionary)
signal error_occurred(message: String)

const ClaudeMessageStreamScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_message_stream.gd")
const ClaudeQuerySessionScript := preload("res://addons/claude_agent_sdk/runtime/protocol/query_session.gd")
const ClaudeSubprocessCLITransportScript := preload("res://addons/claude_agent_sdk/runtime/transport/subprocess_cli_transport.gd")
const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeSdkMcpServerScript := preload("res://addons/claude_agent_sdk/runtime/mcp/claude_sdk_mcp_server.gd")
const ClaudePromptStreamScript := preload("res://addons/claude_agent_sdk/runtime/input/claude_prompt_stream.gd")
const ClaudeContextUsageResponseScript := preload("res://addons/claude_agent_sdk/runtime/claude_context_usage_response.gd")
const ClaudeMcpStatusResponseScript := preload("res://addons/claude_agent_sdk/runtime/claude_mcp_status_response.gd")

var options = null
var _custom_transport = null
var _transport = null
var _session = null
var _last_error := ""


func _init(initial_options = null, transport = null) -> void:
	options = initial_options if initial_options != null else ClaudeAgentOptionsScript.new()
	_custom_transport = transport
	_transport = _create_transport()


func connect_client(prompt = null) -> void:
	if not _validate_connect_request(prompt):
		return
	if _session != null:
		disconnect_client()
	_last_error = ""
	_transport = _create_transport()
	_session = ClaudeQuerySessionScript.new(_transport, options, _extract_sdk_mcp_servers())
	_session.session_initialized.connect(_on_session_initialized)
	_session.error_occurred.connect(_on_session_error_occurred)
	_session.open_session()
	if _session != null and prompt != null and _session.get_last_error().is_empty():
		if prompt is ClaudePromptStreamScript:
			_session.send_prompt_stream(prompt, "default", false)
		else:
			_session.send_user_prompt(str(prompt), "default")
	_last_error = _session.get_last_error()


func query(prompt, session_id: String = "default", backfill_session_id := true) -> void:
	if _session == null:
		_emit_error("Call connect_client() before query()")
		return
	if not (prompt is String or prompt is ClaudePromptStreamScript):
		_emit_error("prompt must be either a String or ClaudePromptStream")
		return
	if prompt is ClaudePromptStreamScript:
		_session.send_prompt_stream(prompt, session_id, backfill_session_id)
	else:
		_session.send_user_prompt(str(prompt), session_id)
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


func receive_response_for_session(session_id: String):
	if _session == null:
		var stream = ClaudeMessageStreamScript.new(true)
		stream.fail("Call connect_client() before receive_response_for_session()")
		return stream
	return _session.receive_response_for_session(session_id)


func disconnect_client() -> void:
	if _session == null:
		return
	if _session.session_initialized.is_connected(_on_session_initialized):
		_session.session_initialized.disconnect(_on_session_initialized)
	if _session.error_occurred.is_connected(_on_session_error_occurred):
		_session.error_occurred.disconnect(_on_session_error_occurred)
	_session.close()
	_session = null


func interrupt() -> void:
	if _session == null:
		_emit_error("Call connect_client() before interrupt()")
		return
	_session.interrupt()
	_last_error = _session.get_last_error()


func set_permission_mode(mode: String) -> void:
	if _session == null:
		_emit_error("Call connect_client() before set_permission_mode()")
		return
	_session.set_permission_mode(mode)
	_last_error = _session.get_last_error()


func set_model(model: String = "") -> void:
	if _session == null:
		_emit_error("Call connect_client() before set_model()")
		return
	_session.set_model(model)
	_last_error = _session.get_last_error()


func get_server_info() -> Dictionary:
	if _session == null:
		return {}
	return _session.get_server_info()


func get_auth_status() -> Dictionary:
	if _transport != null and _transport.has_method("probe_auth_status"):
		var result: Dictionary = _transport.probe_auth_status()
		_last_error = str(result.get("error_message", ""))
		return result
	_emit_error("Current transport does not support auth status probing")
	return {}


func get_context_usage():
	if _session == null:
		_emit_error("Call connect_client() before get_context_usage()")
		return ClaudeContextUsageResponseScript.new()
	var result: Dictionary = await _session.get_context_usage()
	_last_error = _session.get_last_error()
	return ClaudeContextUsageResponseScript.coerce(result)


func get_mcp_status():
	if _session == null:
		_emit_error("Call connect_client() before get_mcp_status()")
		return ClaudeMcpStatusResponseScript.new()
	var result: Dictionary = await _session.get_mcp_status()
	_last_error = _session.get_last_error()
	return ClaudeMcpStatusResponseScript.coerce(result)


func rewind_files(user_message_id: String) -> void:
	if _session == null:
		_emit_error("Call connect_client() before rewind_files()")
		return
	await _session.rewind_files(user_message_id)
	_last_error = _session.get_last_error()


func stop_task(task_id: String) -> void:
	if _session == null:
		_emit_error("Call connect_client() before stop_task()")
		return
	await _session.stop_task(task_id)
	_last_error = _session.get_last_error()


func reconnect_mcp_server(server_name: String) -> void:
	if _session == null:
		_emit_error("Call connect_client() before reconnect_mcp_server()")
		return
	await _session.reconnect_mcp_server(server_name)
	_last_error = _session.get_last_error()


func toggle_mcp_server(server_name: String, enabled: bool) -> void:
	if _session == null:
		_emit_error("Call connect_client() before toggle_mcp_server()")
		return
	await _session.toggle_mcp_server(server_name, enabled)
	_last_error = _session.get_last_error()


func get_last_error() -> String:
	if _session != null and not _session.get_last_error().is_empty():
		return _session.get_last_error()
	return _last_error


func _set_last_error(message: String) -> void:
	_last_error = message


func _emit_error(message: String) -> void:
	_set_last_error(message)
	error_occurred.emit(message)


func _on_session_initialized(server_info: Dictionary) -> void:
	session_initialized.emit(server_info.duplicate(true))


func _on_session_error_occurred(message: String) -> void:
	_last_error = message
	error_occurred.emit(message)


func _extract_sdk_mcp_servers() -> Dictionary:
	var extracted: Dictionary = {}
	if options == null or not (options.mcp_servers is Dictionary):
		return extracted
	for server_name_variant in (options.mcp_servers as Dictionary).keys():
		var config_variant: Variant = (options.mcp_servers as Dictionary)[server_name_variant]
		if not (config_variant is Dictionary):
			continue
		var config := config_variant as Dictionary
		if str(config.get("type", "")) != "sdk":
			continue
		var instance: Variant = config.get("instance")
		if instance is ClaudeSdkMcpServer:
			extracted[str(server_name_variant)] = instance
	return extracted


func _validate_connect_request(prompt) -> bool:
	if not _validate_options():
		return false
	if prompt == null:
		return true
	if not (prompt is String or prompt is ClaudePromptStreamScript):
		_emit_error("prompt must be null, a String, or ClaudePromptStream")
		return false
	if options != null and options.can_use_tool.is_valid() and prompt is String:
		_emit_error(
			"can_use_tool callback requires streamed prompt input. " +
			"Please provide prompt as a ClaudePromptStream instead of a String."
		)
		return false
	return true


func _validate_options() -> bool:
	if options != null and options.can_use_tool.is_valid() and not options.permission_prompt_tool_name.is_empty():
		_emit_error("can_use_tool callback cannot be used with permission_prompt_tool_name. Please use one or the other.")
		return false
	return true


func _create_transport():
	if _custom_transport != null:
		return _custom_transport
	return ClaudeSubprocessCLITransportScript.new(options)
