extends RefCounted
class_name ClaudeQuerySession

signal control_request_completed(request_id: String)

const ClaudeMessageStreamScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_message_stream.gd")
const ClaudeMessageParserScript := preload("res://addons/claude_agent_sdk/runtime/parser/message_parser.gd")
const ClaudeHookMatcherScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_matcher.gd")
const ClaudeHookContextScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_context.gd")
const ClaudeToolPermissionContextScript := preload("res://addons/claude_agent_sdk/runtime/claude_tool_permission_context.gd")
const ClaudePermissionResultAllowScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_allow.gd")
const ClaudePermissionResultDenyScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_deny.gd")

var _transport = null
var _options = null
var _server_info: Dictionary = {}
var _connected := false
var _closed := false
var _initialized := false
var _initialize_request_id := ""
var _request_counter := 0
var _pending_control_responses: Dictionary = {}
var _hook_callbacks: Dictionary = {}
var _next_hook_callback_id := 0
var _inflight_control_requests: Dictionary = {}
var _message_stream = ClaudeMessageStreamScript.new(false)
var _current_response_stream = null
var _last_response_stream = null
var _pending_prompt_payload := ""
var _last_error := ""


func _init(transport, options = null) -> void:
	_transport = transport
	_options = options
	_connect_transport_signals()


func open_session() -> void:
	if _connected:
		return
	if not _transport.open_transport():
		_set_last_error(_transport.get_last_error())
		_message_stream.fail(_last_error)
		return
	_connected = true
	_initialize_request_id = _send_control_request(_build_initialize_request())
	if _initialize_request_id.is_empty():
		_fail_session(_last_error if not _last_error.is_empty() else "Failed to initialize Claude session")


func close() -> void:
	if _closed:
		return
	_closed = true
	_connected = false
	_cancel_all_inflight_control_requests()
	_complete_pending_control_requests("Claude session closed")
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


func get_context_usage() -> Dictionary:
	return await _send_control_request_and_wait({"subtype": "get_context_usage"})


func get_mcp_status() -> Dictionary:
	return await _send_control_request_and_wait({"subtype": "mcp_status"})


func reconnect_mcp_server(server_name: String) -> void:
	await _send_control_request_and_wait({
		"subtype": "mcp_reconnect",
		"serverName": server_name,
	})


func toggle_mcp_server(server_name: String, enabled: bool) -> void:
	await _send_control_request_and_wait({
		"subtype": "mcp_toggle",
		"serverName": server_name,
		"enabled": enabled,
	})


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


func _send_control_request(request: Dictionary, await_response: bool = false) -> String:
	if not _connected:
		_set_last_error("Cannot send control request before the session is connected")
		return ""

	_request_counter += 1
	var request_id := "req_%d" % _request_counter
	_pending_control_responses[request_id] = {
		"request": request.duplicate(true),
		"await_response": await_response,
		"completed": false,
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


func _send_control_request_and_wait(request: Dictionary) -> Dictionary:
	var request_id := _send_control_request(request, true)
	if request_id.is_empty():
		return {}

	while true:
		var pending: Dictionary = _pending_control_responses.get(request_id, {}) if _pending_control_responses.get(request_id, {}) is Dictionary else {}
		if pending.is_empty():
			return {}
		if bool(pending.get("completed", false)):
			_pending_control_responses.erase(request_id)
			var error_message := str(pending.get("error", ""))
			if not error_message.is_empty():
				if _last_error != error_message:
					_set_last_error(error_message)
				return {}
			return pending.get("response", {}) if pending.get("response", {}) is Dictionary else {}

			var completed_request_id: String = await control_request_completed
			if completed_request_id == request_id:
				continue
	return {}


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
	if _closed:
		return
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
	if message_type == "control_request":
		_start_inbound_control_request(data)
		return
	if message_type == "control_cancel_request":
		_cancel_inflight_control_request(str(data.get("request_id", "")))
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
	_cancel_all_inflight_control_requests()
	_complete_pending_control_requests("Claude transport closed")
	_disconnect_transport_signals()
	_finish_streams()


func _on_transport_error(message: String) -> void:
	_set_last_error(message)
	_cancel_all_inflight_control_requests()
	_complete_pending_control_requests(message)
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
	var request: Dictionary = pending_request.get("request", {}) if pending_request.get("request", {}) is Dictionary else {}
	var request_subtype := str(request.get("subtype", ""))
	var await_response := bool(pending_request.get("await_response", false))
	var response_payload: Dictionary = response.get("response", {}) if response.get("response", {}) is Dictionary else {}

	if str(response.get("subtype", "")) == "error":
		var error_message := str(response.get("error", "Unknown control error"))
		if await_response:
			pending_request["completed"] = true
			pending_request["error"] = error_message
			_pending_control_responses[request_id] = pending_request
			control_request_completed.emit(request_id)
		else:
			_pending_control_responses.erase(request_id)
			_set_last_error(error_message)
		if request_subtype == "initialize":
			_fail_session(error_message)
		return

	if request_id == _initialize_request_id:
		_server_info = response_payload
		_initialized = true
		_initialize_request_id = ""
		_flush_pending_prompt()

	if await_response:
		pending_request["completed"] = true
		pending_request["response"] = response_payload
		_pending_control_responses[request_id] = pending_request
		control_request_completed.emit(request_id)
	else:
		_pending_control_responses.erase(request_id)


func _set_last_error(message: String) -> void:
	_last_error = message
	push_error(message)


func _fail_session(message: String) -> void:
	if _last_error != message:
		_set_last_error(message)
	_complete_pending_control_requests(message)
	_cancel_all_inflight_control_requests()
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


func _build_initialize_request() -> Dictionary:
	return {
		"subtype": "initialize",
		"hooks": _build_hooks_configuration(),
	}


func _build_hooks_configuration() -> Variant:
	_hook_callbacks.clear()
	_next_hook_callback_id = 0
	if _options == null or _options.hooks.is_empty():
		return null

	var hooks_config: Dictionary = {}
	for event_variant in _options.hooks.keys():
		var event_name := str(event_variant)
		var matcher_variants: Array = _options.hooks[event_variant] if _options.hooks[event_variant] is Array else []
		var serialized_matchers: Array = []
		for matcher_variant in matcher_variants:
			var matcher = _coerce_hook_matcher(matcher_variant)
			if matcher == null:
				continue
			var callback_ids: Array[String] = []
			for callback in matcher.hooks:
				if not callback.is_valid():
					continue
				var callback_id := "hook_%d" % _next_hook_callback_id
				_next_hook_callback_id += 1
				_hook_callbacks[callback_id] = callback
				callback_ids.append(callback_id)

			if callback_ids.is_empty():
				continue
			var matcher_config: Dictionary = {
				"matcher": null if matcher.matcher.is_empty() else matcher.matcher,
				"hookCallbackIds": callback_ids,
			}
			if matcher.timeout_sec > 0.0:
				matcher_config["timeout"] = matcher.timeout_sec
			serialized_matchers.append(matcher_config)

		if not serialized_matchers.is_empty():
			hooks_config[event_name] = serialized_matchers

	return hooks_config if not hooks_config.is_empty() else null


func _coerce_hook_matcher(value: Variant):
	if value is ClaudeHookMatcher:
		return value
	if value is Dictionary:
		return ClaudeHookMatcherScript.new(value)
	return null


func _start_inbound_control_request(data: Dictionary) -> void:
	var request_id := str(data.get("request_id", ""))
	if request_id.is_empty() or _inflight_control_requests.has(request_id):
		return
	var metadata := {
		"canceled": false,
	}
	_inflight_control_requests[request_id] = metadata
	Callable(self, "_run_inbound_control_request").call_deferred(request_id, data)


func _cancel_inflight_control_request(request_id: String) -> void:
	if request_id.is_empty() or not _inflight_control_requests.has(request_id):
		return
	var metadata: Dictionary = _inflight_control_requests[request_id]
	metadata["canceled"] = true
	_inflight_control_requests[request_id] = metadata


func _cancel_all_inflight_control_requests() -> void:
	for request_id_variant in _inflight_control_requests.keys():
		var request_id := str(request_id_variant)
		_cancel_inflight_control_request(request_id)


func _run_inbound_control_request(request_id: String, data: Dictionary) -> void:
	var request_data: Dictionary = data.get("request", {}) if data.get("request", {}) is Dictionary else {}
	var subtype := str(request_data.get("subtype", ""))
	var response_payload: Dictionary = {}
	var error_message := ""

	if subtype.is_empty():
		error_message = "Missing control request subtype"
	else:
		match subtype:
			"hook_callback":
				response_payload = await _handle_hook_callback_request(request_data)
			"can_use_tool":
				response_payload = await _handle_permission_control_request(request_data)
			_:
				error_message = "Unsupported control request subtype: %s" % subtype

	if error_message.is_empty() and response_payload.has("__control_error__"):
		error_message = str(response_payload.get("__control_error__", "Unknown control request error"))
		response_payload = {}

	if not _is_inflight_control_request_canceled(request_id) and not _closed:
		if error_message.is_empty():
			_write_inbound_control_response(request_id, "success", response_payload)
		else:
			_write_inbound_control_response(request_id, "error", {}, error_message)

	_inflight_control_requests.erase(request_id)


func _handle_hook_callback_request(request_data: Dictionary) -> Dictionary:
	var callback_id := str(request_data.get("callback_id", ""))
	var callback: Callable = _hook_callbacks.get(callback_id, Callable())
	if not callback.is_valid():
		push_error("No hook callback found for ID: %s" % callback_id)
		return _raise_control_request_error("No hook callback found for ID: %s" % callback_id)

	var input_data: Dictionary = request_data.get("input", {}) if request_data.get("input", {}) is Dictionary else {}
	var tool_use_id := str(request_data.get("tool_use_id", ""))
	var hook_context = ClaudeHookContextScript.new()
	var result: Variant = await callback.callv([input_data, tool_use_id, hook_context])
	if result == null:
		return {}
	if result is Dictionary:
		return (result as Dictionary).duplicate(true)
	return _raise_control_request_error("Hook callback must return a Dictionary")


func _handle_permission_control_request(request_data: Dictionary) -> Dictionary:
	if _options == null or not _options.can_use_tool.is_valid():
		return _raise_control_request_error("can_use_tool callback is not provided")

	var tool_name := str(request_data.get("tool_name", ""))
	var input_data: Dictionary = request_data.get("input", {}) if request_data.get("input", {}) is Dictionary else {}
	var suggestions: Array = request_data.get("permission_suggestions", []) if request_data.get("permission_suggestions", []) is Array else []
	var context = ClaudeToolPermissionContextScript.new(
		null,
		suggestions,
		str(request_data.get("tool_use_id", "")),
		str(request_data.get("agent_id", "")),
	)
	var result: Variant = await _options.can_use_tool.callv([tool_name, input_data, context])
	if result is ClaudePermissionResultAllow:
		var allow_result = result as ClaudePermissionResultAllow
		var response_payload := {
			"behavior": "allow",
			"updatedInput": allow_result.updated_input if allow_result.updated_input != null else input_data,
		}
		if allow_result.updated_permissions != null:
			response_payload["updatedPermissions"] = allow_result.updated_permissions
		return response_payload
	if result is ClaudePermissionResultDeny:
		var deny_result = result as ClaudePermissionResultDeny
		var response_payload := {
			"behavior": "deny",
			"message": deny_result.message,
		}
		if deny_result.interrupt:
			response_payload["interrupt"] = true
		return response_payload
	return _raise_control_request_error("Tool permission callback must return ClaudePermissionResultAllow or ClaudePermissionResultDeny")


func _write_inbound_control_response(
	request_id: String,
	subtype: String,
	response_payload: Dictionary = {},
	error_message: String = ""
) -> void:
	var response: Dictionary = {
		"type": "control_response",
		"response": {
			"subtype": subtype,
			"request_id": request_id,
		},
	}
	if subtype == "success":
		response["response"]["response"] = response_payload
	else:
		response["response"]["error"] = error_message
	_transport.write(JSON.stringify(response))


func _is_inflight_control_request_canceled(request_id: String) -> bool:
	if not _inflight_control_requests.has(request_id):
		return false
	var metadata: Dictionary = _inflight_control_requests[request_id]
	return bool(metadata.get("canceled", false))


func _complete_pending_control_requests(message: String) -> void:
	for request_id_variant in _pending_control_responses.keys():
		var request_id := str(request_id_variant)
		var pending: Dictionary = _pending_control_responses[request_id]
		if bool(pending.get("await_response", false)) and not bool(pending.get("completed", false)):
			pending["completed"] = true
			pending["error"] = message
			_pending_control_responses[request_id] = pending
			control_request_completed.emit(request_id)


func _raise_control_request_error(message: String) -> Dictionary:
	push_error(message)
	return {"__control_error__": message}
