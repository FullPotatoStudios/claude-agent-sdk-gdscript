extends RefCounted
class_name ClaudeQuerySession

const ClaudeMessageStreamScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_message_stream.gd")
const ClaudeMessageParserScript := preload("res://addons/claude_agent_sdk/runtime/parser/message_parser.gd")
var _transport = null
var _server_info: Dictionary = {}
var _connected := false
var _closed := false
var _initialized := false
var _initialize_request_id := ""
var _request_counter := 0
var _pending_control_responses: Dictionary = {}
var _message_stream = ClaudeMessageStreamScript.new(false)
var _current_response_stream = null
var _last_response_stream = null
var _pending_prompt_payload := ""
var _last_error := ""


func _init(transport) -> void:
	_transport = transport
	_connect_transport_signals()


func open_session() -> void:
	if _connected:
		return
	if not _transport.open_transport():
		_set_last_error(_transport.get_last_error())
		_message_stream.fail(_last_error)
		return
	_connected = true
	_initialize_request_id = _send_control_request({
		"subtype": "initialize",
		"hooks": null,
	})
	if _initialize_request_id.is_empty():
		_fail_session(_last_error if not _last_error.is_empty() else "Failed to initialize Claude session")


func close() -> void:
	if _closed:
		return
	_closed = true
	_connected = false
	_finish_streams()
	_disconnect_transport_signals()
	_transport.close()


func send_user_prompt(prompt: String, session_id: String = "default") -> void:
	if not _connected:
		_set_last_error("Cannot query before connect() completes")
		return
	if _current_response_stream != null and not _current_response_stream.is_finished():
		_set_last_error("Cannot start a new query while another response is still in flight")
		return

	_current_response_stream = ClaudeMessageStreamScript.new(true)
	_last_response_stream = _current_response_stream
	_pending_prompt_payload = JSON.stringify({
		"type": "user",
		"session_id": session_id,
		"message": {
			"role": "user",
			"content": prompt,
		},
		"parent_tool_use_id": null,
	})

	if _initialized:
		_flush_pending_prompt()


func receive_messages():
	return _message_stream


func receive_response():
	if _last_response_stream == null:
		var stream = ClaudeMessageStreamScript.new(true)
		stream.fail("No response stream is available before query() is called")
		return stream
	return _last_response_stream


func interrupt() -> void:
	_send_control_request({"subtype": "interrupt"})


func set_permission_mode(mode: String) -> void:
	_send_control_request({
		"subtype": "set_permission_mode",
		"mode": mode,
	})


func set_model(model: String = "") -> void:
	_send_control_request({
		"subtype": "set_model",
		"model": model,
	})


func get_server_info() -> Dictionary:
	return _server_info.duplicate(true)


func get_last_error() -> String:
	return _last_error


func _send_control_request(request: Dictionary) -> String:
	if not _connected:
		_set_last_error("Cannot send control request before the session is connected")
		return ""

	_request_counter += 1
	var request_id := "req_%d" % _request_counter
	_pending_control_responses[request_id] = {
		"request": request.duplicate(true),
	}
	var payload := JSON.stringify({
		"type": "control_request",
		"request_id": request_id,
		"request": request,
	})
	if not _transport.write(payload):
		_set_last_error(_transport.get_last_error())
		_pending_control_responses.erase(request_id)
		return ""
	return request_id


func _flush_pending_prompt() -> void:
	if _pending_prompt_payload.is_empty():
		return
	if not _transport.write(_pending_prompt_payload):
		_set_last_error(_transport.get_last_error())
		if _current_response_stream != null:
			_current_response_stream.fail(_last_error)
		return
	_pending_prompt_payload = ""


func _on_transport_stdout_line(line: String) -> void:
	var parsed: Variant = JSON.parse_string(line)
	if parsed is not Dictionary:
		_set_last_error("Failed to parse Claude CLI stdout as JSON: %s" % line)
		_message_stream.fail(_last_error)
		if _current_response_stream != null:
			_current_response_stream.fail(_last_error)
		return

	var data: Dictionary = parsed
	var message_type := str(data.get("type", ""))
	if message_type == "control_response":
		_handle_control_response(data)
		return

	var message: Variant = ClaudeMessageParserScript.parse_message(data)
	if message == null:
		return

	_message_stream.push_message(message)
	if _current_response_stream != null:
		_current_response_stream.push_message(message)
		if message is Object and str(message.get("message_type")) == "result":
			_current_response_stream = null


func _on_transport_stderr_line(_line: String) -> void:
	pass


func _on_transport_closed() -> void:
	_closed = true
	_connected = false
	_disconnect_transport_signals()
	_finish_streams()


func _on_transport_error(message: String) -> void:
	_set_last_error(message)
	_message_stream.fail(message)
	if _current_response_stream != null:
		_current_response_stream.fail(message)


func _handle_control_response(data: Dictionary) -> void:
	var response: Dictionary = data.get("response", {}) if data.get("response", {}) is Dictionary else {}
	var request_id := str(response.get("request_id", ""))
	if request_id.is_empty():
		return

	var pending_request: Dictionary = _pending_control_responses.get(request_id, {}) if _pending_control_responses.get(request_id, {}) is Dictionary else {}
	if pending_request.is_empty():
		return
	_pending_control_responses.erase(request_id)
	var request: Dictionary = pending_request.get("request", {}) if pending_request.get("request", {}) is Dictionary else {}
	var request_subtype := str(request.get("subtype", ""))

	if str(response.get("subtype", "")) == "error":
		var error_message := str(response.get("error", "Unknown control error"))
		_set_last_error(error_message)
		if request_subtype == "initialize":
			_fail_session(error_message)
		return

	if request_id == _initialize_request_id:
		_server_info = response.get("response", {}) if response.get("response", {}) is Dictionary else {}
		_initialized = true
		_initialize_request_id = ""
		_flush_pending_prompt()


func _set_last_error(message: String) -> void:
	_last_error = message
	push_error(message)


func _fail_session(message: String) -> void:
	if _last_error != message:
		_set_last_error(message)
	_message_stream.fail(message)
	if _current_response_stream != null:
		_current_response_stream.fail(message)
	_current_response_stream = null
	_connected = false
	close()


func _connect_transport_signals() -> void:
	if _transport == null:
		return
	if not _transport.stdout_line.is_connected(_on_transport_stdout_line):
		_transport.stdout_line.connect(_on_transport_stdout_line)
	if not _transport.stderr_line.is_connected(_on_transport_stderr_line):
		_transport.stderr_line.connect(_on_transport_stderr_line)
	if not _transport.transport_closed.is_connected(_on_transport_closed):
		_transport.transport_closed.connect(_on_transport_closed)
	if not _transport.transport_error.is_connected(_on_transport_error):
		_transport.transport_error.connect(_on_transport_error)


func _disconnect_transport_signals() -> void:
	if _transport == null:
		return
	if _transport.stdout_line.is_connected(_on_transport_stdout_line):
		_transport.stdout_line.disconnect(_on_transport_stdout_line)
	if _transport.stderr_line.is_connected(_on_transport_stderr_line):
		_transport.stderr_line.disconnect(_on_transport_stderr_line)
	if _transport.transport_closed.is_connected(_on_transport_closed):
		_transport.transport_closed.disconnect(_on_transport_closed)
	if _transport.transport_error.is_connected(_on_transport_error):
		_transport.transport_error.disconnect(_on_transport_error)


func _finish_streams() -> void:
	_message_stream.finish()
	if _current_response_stream != null:
		_current_response_stream.finish()
		_current_response_stream = null
