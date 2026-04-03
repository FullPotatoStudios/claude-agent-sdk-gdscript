extends RefCounted
class_name ClaudeQuerySession

const ClaudeMessageStreamScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_message_stream.gd")
const ClaudeMessageParserScript := preload("res://addons/claude_agent_sdk/runtime/parser/message_parser.gd")
var _transport = null
var _server_info: Dictionary = {}
var _connected := false
var _closed := false
var _initialized := false
var _request_counter := 0
var _pending_control_responses: Dictionary = {}
var _message_stream = ClaudeMessageStreamScript.new(false)
var _current_response_stream = null
var _last_response_stream = null
var _pending_prompt_payload := ""
var _last_error := ""


func _init(transport) -> void:
	_transport = transport
	_transport.stdout_line.connect(_on_transport_stdout_line)
	_transport.stderr_line.connect(_on_transport_stderr_line)
	_transport.transport_closed.connect(_on_transport_closed)
	_transport.transport_error.connect(_on_transport_error)


func open_session() -> void:
	if _connected:
		return
	if not _transport.open_transport():
		_set_last_error(_transport.get_last_error())
		_message_stream.fail(_last_error)
		return
	_connected = true
	_send_control_request({
		"subtype": "initialize",
		"hooks": null,
	})


func close() -> void:
	if _closed:
		return
	_closed = true
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
	_message_stream.finish()
	if _current_response_stream != null:
		_current_response_stream.finish()


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

	if _pending_control_responses.has(request_id):
		_pending_control_responses.erase(request_id)

	if str(response.get("subtype", "")) == "error":
		_set_last_error(str(response.get("error", "Unknown control error")))
		return

	if not _initialized:
		_server_info = response.get("response", {}) if response.get("response", {}) is Dictionary else {}
		_initialized = true
		_flush_pending_prompt()


func _set_last_error(message: String) -> void:
	_last_error = message
	push_error(message)
