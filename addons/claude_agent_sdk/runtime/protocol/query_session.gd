extends RefCounted
class_name ClaudeQuerySession

signal control_request_completed(request_id: String)
signal session_initialized(server_info: Dictionary)
signal error_occurred(message: String)

const ClaudeMessageStreamScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_message_stream.gd")
const ClaudeMessageParserScript := preload("res://addons/claude_agent_sdk/runtime/parser/message_parser.gd")
const ClaudeHookMatcherScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_matcher.gd")
const ClaudeHookContextScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_context.gd")
const ClaudeHookInputScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input.gd")
const ClaudeHookOutputScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_output.gd")
const ClaudeHookSpecificOutputScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_specific_output.gd")
const ClaudeToolPermissionContextScript := preload("res://addons/claude_agent_sdk/runtime/claude_tool_permission_context.gd")
const ClaudePermissionResultAllowScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_allow.gd")
const ClaudePermissionResultDenyScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_deny.gd")
const ClaudeSdkMcpServerScript := preload("res://addons/claude_agent_sdk/runtime/mcp/claude_sdk_mcp_server.gd")
const ClaudeAgentDefinitionScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_definition.gd")
const ClaudePromptStreamScript := preload("res://addons/claude_agent_sdk/runtime/input/claude_prompt_stream.gd")
const DEFAULT_INITIALIZE_TIMEOUT_SEC := 60.0

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
var _pending_prompt_payloads: Array[String] = []
var _pending_prompt_stream = null
var _pending_prompt_stream_session_id := "default"
var _pending_prompt_stream_backfills_session_id := false
var _active_prompt_drain_token := 0
var _last_error := ""
var _sdk_mcp_servers: Dictionary = {}
var _initialize_timeout_sec := DEFAULT_INITIALIZE_TIMEOUT_SEC
var _initialize_timeout_token := 0
var _initialize_timeout_error := ""


func _init(transport, options = null, sdk_mcp_servers: Dictionary = {}) -> void:
	_transport = transport
	_options = options
	_sdk_mcp_servers = sdk_mcp_servers.duplicate()
	_initialize_timeout_sec = _resolve_initialize_timeout_seconds()
	_connect_transport_signals()


func open_session() -> void:
	if _connected:
		return
	if not _initialize_timeout_error.is_empty():
		_emit_error(_initialize_timeout_error)
		_message_stream.fail(_initialize_timeout_error)
		return
	if not _transport.open_transport():
		var transport_error: String = _transport.get_last_error()
		if _last_error != transport_error:
			_emit_error(transport_error)
		else:
			_set_last_error(transport_error)
		_message_stream.fail(_last_error)
		return
	_connected = true
	_initialize_request_id = _send_control_request(_build_initialize_request())
	if _initialize_request_id.is_empty():
		_fail_session(_last_error if not _last_error.is_empty() else "Failed to initialize Claude session")
		return
	_arm_initialize_timeout()


func close() -> void:
	if _closed:
		return
	_closed = true
	_connected = false
	_initialize_timeout_token += 1
	_active_prompt_drain_token += 1
	_cancel_all_inflight_control_requests()
	_complete_pending_control_requests("Claude session closed")
	_finish_streams()
	_disconnect_transport_signals()
	_transport.close()


func send_user_prompt(prompt: String, session_id: String = "default") -> void:
	send_prompt(prompt, session_id, true)


func send_prompt_stream(prompt_stream, session_id: String = "default", backfill_session_id := true) -> void:
	send_prompt(prompt_stream, session_id, backfill_session_id)


func send_prompt(prompt, session_id: String = "default", backfill_session_id := true) -> void:
	if not _connected:
		_emit_error("Cannot query before connect() completes")
		return
	if _current_response_stream != null and not _current_response_stream.is_finished():
		_emit_error("Cannot start a new query while another response is still in flight")
		return

	_set_last_error("")
	_current_response_stream = ClaudeMessageStreamScript.new(true)
	_last_response_stream = _current_response_stream
	_pending_prompt_payloads.clear()
	_pending_prompt_stream = null
	_pending_prompt_stream_session_id = session_id
	_pending_prompt_stream_backfills_session_id = backfill_session_id
	_active_prompt_drain_token += 1

	if prompt is ClaudePromptStreamScript:
		_pending_prompt_stream = prompt
	else:
		_pending_prompt_payloads.append(_build_user_prompt_payload(str(prompt), session_id))

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


func rewind_files(user_message_id: String) -> void:
	await _send_control_request_and_wait({
		"subtype": "rewind_files",
		"user_message_id": user_message_id,
	})


func stop_task(task_id: String) -> void:
	await _send_control_request_and_wait({
		"subtype": "stop_task",
		"task_id": task_id,
	})


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
		_emit_error("Cannot send control request before the session is connected")
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
		_emit_error(_transport.get_last_error())
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
	for payload in _pending_prompt_payloads:
		if not _transport.write(payload):
			_fail_active_prompt_write(_transport.get_last_error())
			return
	_pending_prompt_payloads.clear()

	if _pending_prompt_stream == null:
		return
	var token := _active_prompt_drain_token
	var prompt_stream = _pending_prompt_stream
	var stream_session_id := _pending_prompt_stream_session_id
	var should_backfill := _pending_prompt_stream_backfills_session_id
	_pending_prompt_stream = null
	Callable(self, "_drain_prompt_stream").call_deferred(prompt_stream, stream_session_id, should_backfill, token)


func _drain_prompt_stream(prompt_stream, session_id: String, backfill_session_id: bool, token: int) -> void:
	var wrote_any_message := false
	while token == _active_prompt_drain_token and not _closed:
		var next_message: Variant = await prompt_stream.next_message()
		if token != _active_prompt_drain_token or _closed:
			return
		if next_message == null:
			var prompt_error := str(prompt_stream.get_error())
			if not prompt_error.is_empty():
				_fail_active_prompt_write(prompt_error)
			elif not wrote_any_message:
				_fail_active_prompt_write("ClaudePromptStream finished without emitting any prompt items")
			return
		if next_message is not Dictionary:
			_fail_active_prompt_write("ClaudePromptStream must emit Dictionary items")
			return

		var payload := _prepare_prompt_stream_payload(next_message as Dictionary, session_id, backfill_session_id)
		if not _transport.write(JSON.stringify(payload)):
			_fail_active_prompt_write(_transport.get_last_error())
			return
		wrote_any_message = true


func _prepare_prompt_stream_payload(message: Dictionary, session_id: String, backfill_session_id: bool) -> Dictionary:
	var payload := message.duplicate(true)
	if backfill_session_id and not payload.has("session_id"):
		payload["session_id"] = session_id
	return payload


func _build_user_prompt_payload(prompt: String, session_id: String) -> String:
	return JSON.stringify({
		"type": "user",
		"session_id": session_id,
		"message": {
			"role": "user",
			"content": prompt,
		},
		"parent_tool_use_id": null,
	})


func _fail_active_prompt_write(message: String) -> void:
	_emit_error(message)
	_active_prompt_drain_token += 1
	_pending_prompt_payloads.clear()
	_pending_prompt_stream = null
	if _current_response_stream != null:
		_current_response_stream.fail(_last_error)


func _on_transport_stdout_line(line: String) -> void:
	if _closed:
		return
	var parsed: Variant = JSON.parse_string(line)
	if parsed is not Dictionary:
		var parse_error := "Failed to parse Claude CLI stdout as JSON: %s" % line
		push_error(parse_error)
		_emit_error(parse_error)
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
			_active_prompt_drain_token += 1
			_pending_prompt_stream = null
			_current_response_stream = null


func _on_transport_stderr_line(_line: String) -> void:
	pass


func _on_transport_closed() -> void:
	_closed = true
	_connected = false
	_initialize_timeout_token += 1
	_active_prompt_drain_token += 1
	_cancel_all_inflight_control_requests()
	_complete_pending_control_requests("Claude transport closed")
	_disconnect_transport_signals()
	_finish_streams()


func _on_transport_error(message: String) -> void:
	_emit_error(message)
	_active_prompt_drain_token += 1
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
		_emit_error(error_message)
		if await_response:
			pending_request["completed"] = true
			pending_request["error"] = error_message
			_pending_control_responses[request_id] = pending_request
			control_request_completed.emit(request_id)
		else:
			_pending_control_responses.erase(request_id)
		if request_subtype == "initialize":
			_fail_session(error_message)
		return

	if request_id == _initialize_request_id:
		_server_info = response_payload
		_initialized = true
		_initialize_timeout_token += 1
		_initialize_request_id = ""
		session_initialized.emit(_server_info.duplicate(true))
		_flush_pending_prompt()

	_set_last_error("")

	if await_response:
		pending_request["completed"] = true
		pending_request["response"] = response_payload
		_pending_control_responses[request_id] = pending_request
		control_request_completed.emit(request_id)
	else:
		_pending_control_responses.erase(request_id)


func _set_last_error(message: String) -> void:
	_last_error = message


func _emit_error(message: String) -> void:
	_set_last_error(message)
	error_occurred.emit(message)


func _fail_session(message: String) -> void:
	if _last_error != message:
		_set_last_error(message)
	_initialize_timeout_token += 1
	_active_prompt_drain_token += 1
	_pending_prompt_payloads.clear()
	_pending_prompt_stream = null
	_complete_pending_control_requests(message)
	_cancel_all_inflight_control_requests()
	_message_stream.fail(message)
	if _current_response_stream != null:
		_current_response_stream.fail(message)
	_current_response_stream = null
	_connected = false
	close()


func _arm_initialize_timeout() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_initialize_timeout_token += 1
	var token := _initialize_timeout_token
	Callable(self, "_watch_initialize_timeout").call_deferred(tree, token)


func _watch_initialize_timeout(tree: SceneTree, token: int) -> void:
	if _initialize_request_id.is_empty() or _initialized or _closed:
		return
	await tree.create_timer(_initialize_timeout_sec).timeout
	if token != _initialize_timeout_token:
		return
	if _initialize_request_id.is_empty() or _initialized or _closed:
		return
	_fail_session(
		"Claude session initialize timed out after %.1f seconds" % _initialize_timeout_sec
	)


func _resolve_initialize_timeout_seconds() -> float:
	var raw_timeout := OS.get_environment("CLAUDE_CODE_STREAM_CLOSE_TIMEOUT").strip_edges()
	_initialize_timeout_error = ""
	if raw_timeout.is_empty():
		return DEFAULT_INITIALIZE_TIMEOUT_SEC
	if not raw_timeout.is_valid_int():
		_initialize_timeout_error = (
			"Invalid CLAUDE_CODE_STREAM_CLOSE_TIMEOUT: expected integer milliseconds, got '%s'"
			% raw_timeout
		)
		return DEFAULT_INITIALIZE_TIMEOUT_SEC
	return max(float(int(raw_timeout)) / 1000.0, DEFAULT_INITIALIZE_TIMEOUT_SEC)


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
	_pending_prompt_payloads.clear()
	_pending_prompt_stream = null
	_message_stream.finish()
	if _current_response_stream != null:
		_current_response_stream.finish()
		_current_response_stream = null


func _build_initialize_request() -> Dictionary:
	var request := {
		"subtype": "initialize",
		"hooks": _build_hooks_configuration(),
	}
	var agents_config := _build_agents_configuration()
	if agents_config != null:
		request["agents"] = agents_config
	return request


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


func _build_agents_configuration() -> Variant:
	if _options == null or _options.agents.is_empty():
		return null

	var agents_config: Dictionary = {}
	for agent_name_variant in _options.agents.keys():
		var agent_name := str(agent_name_variant)
		var agent_value: Variant = _options.agents[agent_name_variant]
		var definition = _coerce_agent_definition(agent_value)
		if definition == null:
			continue
		agents_config[agent_name] = definition.to_initialize_dict()
	return agents_config if not agents_config.is_empty() else null


func _coerce_agent_definition(value: Variant):
	if value is ClaudeAgentDefinition:
		return value
	if value is Dictionary:
		return ClaudeAgentDefinitionScript.new(value as Dictionary)
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
			"mcp_message":
				response_payload = await _handle_mcp_message_request(request_data)
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

	var tool_use_id: Variant = request_data.get("tool_use_id", null)
	var input_data: Dictionary = (
		request_data.get("input", {}) if request_data.get("input", {}) is Dictionary else {}
	).duplicate(true)
	var typed_input = ClaudeHookInputScript.coerce_input(input_data, tool_use_id)
	var hook_context = ClaudeHookContextScript.new(null, input_data, typed_input)
	var result: Variant = await callback.callv([input_data, tool_use_id, hook_context])
	if result == null:
		return {}
	return _normalize_hook_callback_result(result)


func _handle_permission_control_request(request_data: Dictionary) -> Dictionary:
	if _options == null or not _options.can_use_tool.is_valid():
		return _raise_control_request_error("can_use_tool callback is not provided")

	var tool_name := str(request_data.get("tool_name", ""))
	var input_data: Dictionary = request_data.get("input", {}) if request_data.get("input", {}) is Dictionary else {}
	var suggestions: Array = request_data.get("permission_suggestions", []) if request_data.get("permission_suggestions", []) is Array else []
	var context = ClaudeToolPermissionContextScript.new(
		null,
		suggestions,
		request_data.get("tool_use_id", null),
		request_data.get("agent_id", null),
	)
	var result: Variant = await _options.can_use_tool.callv([tool_name, input_data, context])
	if result is ClaudePermissionResultAllow:
		var allow_result = result as ClaudePermissionResultAllow
		return allow_result.to_dict(input_data)
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


func _normalize_hook_callback_result(result: Variant) -> Dictionary:
	if result is ClaudeHookOutput:
		return (result as ClaudeHookOutput).to_dict()
	if result is ClaudeHookSpecificOutput:
		return {
			"hookSpecificOutput": (result as ClaudeHookSpecificOutput).to_dict(),
		}
	if result is Dictionary:
		return _normalize_hook_output_dictionary(result as Dictionary)
	return _raise_control_request_error("Hook callback must return a Dictionary or ClaudeHookOutput")


func _normalize_hook_output_dictionary(value: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key_variant in value.keys():
		var key := str(key_variant)
		var normalized_key := _normalize_hook_output_key(key)
		var item: Variant = value[key_variant]
		if normalized_key == "hookSpecificOutput":
			normalized[normalized_key] = _normalize_hook_specific_output_variant(item)
		else:
			normalized[normalized_key] = item
	return normalized


func _normalize_hook_specific_output_variant(value: Variant) -> Variant:
	if value == null:
		return null
	if value is ClaudeHookSpecificOutput:
		return (value as ClaudeHookSpecificOutput).to_dict()
	if value is Dictionary:
		var source := value as Dictionary
		var normalized: Dictionary = {}
		for key_variant in source.keys():
			var key := str(key_variant)
			normalized[_normalize_hook_specific_output_key(key)] = source[key_variant]
		return normalized
	return value


func _normalize_hook_output_key(key: String) -> String:
	match key:
		"continue_":
			return "continue"
		"async_":
			return "async"
		"suppress_output":
			return "suppressOutput"
		"stop_reason":
			return "stopReason"
		"system_message":
			return "systemMessage"
		"hook_specific_output":
			return "hookSpecificOutput"
		"async_timeout":
			return "asyncTimeout"
		_:
			return key


func _normalize_hook_specific_output_key(key: String) -> String:
	match key:
		"hook_event_name":
			return "hookEventName"
		"permission_decision":
			return "permissionDecision"
		"permission_decision_reason":
			return "permissionDecisionReason"
		"updated_input":
			return "updatedInput"
		"additional_context":
			return "additionalContext"
		"updated_mcp_tool_output":
			return "updatedMCPToolOutput"
		_:
			return key


func _handle_mcp_message_request(request_data: Dictionary) -> Dictionary:
	var server_name := str(request_data.get("server_name", ""))
	if server_name.is_empty():
		return _raise_control_request_error("Missing server_name for MCP request")
	var message := request_data.get("message")
	if not (message is Dictionary):
		return _raise_control_request_error("Missing message for MCP request")
	return {
		"mcp_response": await _handle_sdk_mcp_request(server_name, message as Dictionary),
	}


func _handle_sdk_mcp_request(server_name: String, message: Dictionary) -> Dictionary:
	var request_id: Variant = message.get("id", null)
	if not _sdk_mcp_servers.has(server_name):
		return _build_jsonrpc_error_response(request_id, -32601, "Server '%s' not found" % server_name)

	var server_variant: Variant = _sdk_mcp_servers[server_name]
	if not (server_variant is ClaudeSdkMcpServer):
		return _build_jsonrpc_error_response(request_id, -32601, "Server '%s' not found" % server_name)
	var server := server_variant as ClaudeSdkMcpServer
	var method := str(message.get("method", ""))
	var params: Dictionary = message.get("params", {}) if message.get("params", {}) is Dictionary else {}

	match method:
		"initialize":
			return {
				"jsonrpc": "2.0",
				"id": request_id,
				"result": {
					"protocolVersion": "2024-11-05",
					"capabilities": {
						"tools": {},
					},
					"serverInfo": {
						"name": server.name,
						"version": server.version,
					},
				},
			}
		"notifications/initialized":
			return {
				"jsonrpc": "2.0",
				"result": {},
			}
		"tools/list":
			return {
				"jsonrpc": "2.0",
				"id": request_id,
				"result": {
					"tools": server.list_tools(),
				},
			}
		"tools/call":
			return await _handle_sdk_mcp_tool_call(server, request_id, params)
		_:
			return _build_jsonrpc_error_response(request_id, -32601, "Method '%s' not found" % method)


func _handle_sdk_mcp_tool_call(server: ClaudeSdkMcpServer, request_id: Variant, params: Dictionary) -> Dictionary:
	var tool_name := str(params.get("name", ""))
	var tool_variant = server.get_tool(tool_name)
	if not (tool_variant is ClaudeMcpTool):
		return _build_jsonrpc_error_response(request_id, -32601, "Tool '%s' not found" % tool_name)
	var tool := tool_variant as ClaudeMcpTool
	var arguments: Dictionary = params.get("arguments", {}) if params.get("arguments", {}) is Dictionary else {}
	if not tool.handler.is_valid():
		return _build_jsonrpc_error_response(request_id, -32603, "MCP tool handler is not callable")

	# Upstream's Python SDK can convert handler exceptions into MCP error
	# results inside its server runtime. In GDScript we only receive a Callable,
	# and arbitrary runtime faults inside that Callable are not catchable here.
	# Tool-level failures should therefore be reported by returning a Dictionary
	# payload with is_error = true. The bridge still maps containable handler
	# contract failures, such as invalid Callables or invalid return payloads,
	# into -32603.
	var result: Variant = await tool.handler.callv([arguments])
	if not (result is Dictionary):
		return _build_jsonrpc_error_response(
			request_id,
			-32603,
			"MCP tool handler must return a Dictionary result; use is_error for tool-level failures"
		)
	var result_dict := result as Dictionary
	var response_payload := {
		"content": _convert_mcp_tool_result_content(result_dict.get("content", [])),
	}
	if bool(result_dict.get("is_error", false)):
		response_payload["isError"] = true
	return {
		"jsonrpc": "2.0",
		"id": request_id,
		"result": response_payload,
	}


func _convert_mcp_tool_result_content(content_variant: Variant) -> Array:
	var converted: Array = []
	if not (content_variant is Array):
		return converted
	for item_variant in content_variant:
		if not (item_variant is Dictionary):
			push_warning("Unsupported MCP tool content item; expected Dictionary")
			continue
		var item := item_variant as Dictionary
		var item_type := str(item.get("type", ""))
		match item_type:
			"text":
				converted.append({
					"type": "text",
					"text": str(item.get("text", "")),
				})
			"image":
				converted.append({
					"type": "image",
					"data": str(item.get("data", "")),
					"mimeType": str(item.get("mimeType", "")),
				})
			"resource_link":
				converted.append({
					"type": "text",
					"text": _resource_link_to_text(item),
				})
			"resource":
				var text_payload := _embedded_resource_to_text(item)
				if not text_payload.is_empty():
					converted.append({
						"type": "text",
						"text": text_payload,
					})
			_:
				push_warning("Unsupported content type '%s' in MCP tool result; skipping" % item_type)
	return converted


func _resource_link_to_text(item: Dictionary) -> String:
	var parts: Array[String] = []
	var name := str(item.get("name", ""))
	var uri := str(item.get("uri", ""))
	var description := str(item.get("description", ""))
	if not name.is_empty():
		parts.append(name)
	if not uri.is_empty():
		parts.append(uri)
	if not description.is_empty():
		parts.append(description)
	if parts.is_empty():
		return "Resource link"
	return "\n".join(parts)


func _embedded_resource_to_text(item: Dictionary) -> String:
	var resource := item.get("resource")
	if not (resource is Dictionary):
		push_warning("Unsupported embedded resource in MCP tool result; skipping")
		return ""
	var resource_dict := resource as Dictionary
	var text := str(resource_dict.get("text", ""))
	if not text.is_empty():
		return text
	push_warning("Binary embedded resource cannot be converted to text; skipping")
	return ""


func _build_jsonrpc_error_response(request_id: Variant, code: int, message: String) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"id": request_id,
		"error": {
			"code": code,
			"message": message,
		},
	}


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
