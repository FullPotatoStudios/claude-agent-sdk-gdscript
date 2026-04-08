# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")
const ClaudeClientAdapterScript := preload("res://addons/claude_agent_sdk/runtime/adapters/claude_client_adapter.gd")
const ClaudeSessionsScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_sessions.gd")
const ClaudeSystemMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_system_message.gd")
const ClaudeAssistantMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_assistant_message.gd")
const ClaudeRateLimitEventScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_rate_limit_event.gd")
const ClaudeResultMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_result_message.gd")
const ClaudePromptStreamScript := preload("res://addons/claude_agent_sdk/runtime/input/claude_prompt_stream.gd")

var _created_roots: Array[String] = []
var _async_completions: Array[String] = []


func after_test() -> void:
	for root_path in _created_roots:
		_delete_tree(root_path)
	_created_roots.clear()
	_async_completions.clear()
	OS.set_environment("CLAUDE_CONFIG_DIR", "")


func test_adapter_emits_session_and_turn_signals_from_initialize_and_continuous_stream() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var busy_events: Array[bool] = []
	var all_messages: Array = []
	var turn_messages: Array = []
	var turn_results: Array = []
	var ready_payloads: Array = []
	var turn_starts: Array = []

	adapter.busy_changed.connect(func(is_busy: bool): busy_events.append(is_busy))
	adapter.message_received.connect(func(message): all_messages.append(message))
	adapter.turn_message_received.connect(func(message): turn_messages.append(message))
	adapter.turn_finished.connect(func(message): turn_results.append(message))
	adapter.session_ready.connect(func(server_info: Dictionary): ready_payloads.append(server_info))
	adapter.turn_started.connect(func(prompt: String, session_id: String): turn_starts.append({"prompt": prompt, "session_id": session_id}))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {
				"output_style": "default",
				"commands": [{"name": "/help"}],
			},
		},
	})
	await _await_frames(2)

	adapter.query("Hi", "session-1")
	transport.emit_stdout_message({
		"type": "assistant",
		"session_id": "session-1",
		"message": {"model": "haiku", "content": [{"type": "text", "text": "Hello"}]},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "session-1",
		"result": "Hello",
	})
	await _await_frames(2)

	assert_array(busy_events).is_equal([true, false])
	assert_array(ready_payloads).has_size(1)
	assert_dict(ready_payloads[0]).contains_keys(["commands", "output_style"])
	assert_array(turn_starts).is_equal([{"prompt": "Hi", "session_id": "session-1"}])
	assert_int(all_messages.size()).is_equal(2)
	assert_object(all_messages[0]).is_instanceof(ClaudeAssistantMessageScript)
	assert_object(all_messages[1]).is_instanceof(ClaudeResultMessageScript)
	assert_int(turn_messages.size()).is_equal(2)
	assert_object(turn_messages[0]).is_instanceof(ClaudeAssistantMessageScript)
	assert_object(turn_messages[1]).is_instanceof(ClaudeResultMessageScript)
	assert_int(turn_results.size()).is_equal(1)
	assert_object(turn_results[0]).is_instanceof(ClaudeResultMessageScript)
	assert_bool(adapter.is_busy()).is_false()
	await _cleanup_adapter(adapter)


func test_adapter_emits_session_ready_once_even_if_system_init_arrives_after_initialize() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var ready_payloads: Array = []

	adapter.session_ready.connect(func(server_info: Dictionary): ready_payloads.append(server_info))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "system",
		"subtype": "hook_started",
		"hook_event": "SessionStart",
	})
	await _await_frames(1)
	assert_array(ready_payloads).is_empty()

	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/help"}]},
		},
	})
	await _await_frames(1)
	assert_array(ready_payloads).has_size(1)
	await _cleanup_adapter(adapter)


func test_adapter_does_not_emit_session_ready_when_initialize_fails() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var ready_payloads: Array = []
	var errors: Array[String] = []

	adapter.session_ready.connect(func(server_info: Dictionary): ready_payloads.append(server_info))
	adapter.error_occurred.connect(func(message: String): errors.append(message))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "error",
			"request_id": str(init_request.get("request_id", "")),
			"error": "initialize failed",
		},
	})
	await _await_frames(2)

	assert_array(ready_payloads).is_empty()
	assert_bool(adapter.is_client_connected()).is_false()
	assert_str(errors[-1]).contains("initialize failed")

	transport.emit_stdout_message({
		"type": "system",
		"subtype": "init",
		"commands": [{"name": "/help"}],
	})
	await _await_frames(1)

	assert_array(ready_payloads).is_empty()
	await _cleanup_adapter(adapter)


func test_adapter_can_run_second_turn_after_first_result() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var turn_results: Array[String] = []

	adapter.turn_finished.connect(func(message: ClaudeResultMessage): turn_results.append(message.result))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	adapter.query("First")
	transport.emit_stdout_message(_result_payload("first"))
	await _await_frames(2)

	adapter.query("Second")
	transport.emit_stdout_message(_result_payload("second"))
	await _await_frames(2)

	assert_array(turn_results).is_equal(["first", "second"])
	assert_bool(adapter.is_busy()).is_false()
	await _cleanup_adapter(adapter)


func test_adapter_streamed_query_sets_busy_without_emitting_turn_started() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var prompt_stream = ClaudePromptStreamScript.new()
	var busy_events: Array[bool] = []
	var turn_starts: Array = []

	adapter.busy_changed.connect(func(is_busy: bool): busy_events.append(is_busy))
	adapter.turn_started.connect(func(prompt: String, session_id: String): turn_starts.append({"prompt": prompt, "session_id": session_id}))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	adapter.query(prompt_stream, "stream-session")
	prompt_stream.push_message({
		"type": "user",
		"message": {"role": "user", "content": "First"},
		"parent_tool_use_id": null,
	})
	prompt_stream.push_message({
		"type": "user",
		"message": {"role": "user", "content": "Second"},
		"parent_tool_use_id": null,
	})
	prompt_stream.finish()
	await _await_frames(2)

	assert_bool(adapter.is_busy()).is_true()
	assert_array(busy_events).is_equal([true])
	assert_array(turn_starts).is_empty()
	assert_int(transport.writes.size()).is_equal(3)

	transport.emit_stdout_message(_result_payload("done"))
	await _await_frames(2)

	assert_bool(adapter.is_busy()).is_false()
	assert_array(busy_events).is_equal([true, false])
	await _cleanup_adapter(adapter)


func test_adapter_string_connect_prompt_sets_busy_and_emits_turn_started() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var busy_events: Array[bool] = []
	var turn_starts: Array = []
	var turn_results: Array = []

	adapter.busy_changed.connect(func(is_busy: bool): busy_events.append(is_busy))
	adapter.turn_started.connect(func(prompt: String, session_id: String): turn_starts.append({"prompt": prompt, "session_id": session_id}))
	adapter.turn_finished.connect(func(message): turn_results.append(message))

	adapter.connect_client("Open with prompt")
	assert_bool(adapter.is_busy()).is_true()
	assert_array(busy_events).is_equal([true])
	assert_array(turn_starts).is_equal([{"prompt": "Open with prompt", "session_id": "default"}])
	assert_int(transport.writes.size()).is_equal(1)

	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	assert_int(transport.writes.size()).is_equal(2)
	var prompt_payload: Dictionary = JSON.parse_string(transport.writes[1])
	assert_str(str(prompt_payload.get("session_id", ""))).is_equal("default")

	transport.emit_stdout_message(_result_payload("done"))
	await _await_frames(2)

	assert_bool(adapter.is_busy()).is_false()
	assert_array(busy_events).is_equal([true, false])
	assert_int(turn_results.size()).is_equal(1)
	await _cleanup_adapter(adapter)


func test_adapter_streamed_connect_prompt_sets_busy_without_emitting_turn_started() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var prompt_stream = ClaudePromptStreamScript.new()
	var busy_events: Array[bool] = []
	var turn_starts: Array = []

	adapter.busy_changed.connect(func(is_busy: bool): busy_events.append(is_busy))
	adapter.turn_started.connect(func(prompt: String, session_id: String): turn_starts.append({"prompt": prompt, "session_id": session_id}))

	adapter.connect_client(prompt_stream)
	assert_bool(adapter.is_busy()).is_true()
	assert_array(busy_events).is_equal([true])
	assert_array(turn_starts).is_empty()

	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	prompt_stream.push_message({
		"type": "user",
		"message": {"role": "user", "content": "First"},
		"parent_tool_use_id": null,
	})
	prompt_stream.finish()
	await _await_frames(2)

	assert_int(transport.writes.size()).is_equal(2)
	var prompt_payload: Dictionary = JSON.parse_string(transport.writes[1])
	assert_bool(prompt_payload.has("session_id")).is_false()

	transport.emit_stdout_message(_result_payload("done"))
	await _await_frames(2)

	assert_bool(adapter.is_busy()).is_false()
	assert_array(busy_events).is_equal([true, false])
	await _cleanup_adapter(adapter)


func test_adapter_clears_busy_when_prompt_stream_fails_before_result() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var prompt_stream = ClaudePromptStreamScript.new()
	var busy_events: Array[bool] = []
	var errors: Array[String] = []

	adapter.busy_changed.connect(func(is_busy: bool): busy_events.append(is_busy))
	adapter.error_occurred.connect(func(message: String): errors.append(message))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	adapter.query(prompt_stream, "stream-session")
	prompt_stream.fail("prompt stream canceled")
	await _await_frames(2)

	assert_bool(adapter.is_busy()).is_false()
	assert_array(busy_events).is_equal([true, false])
	assert_array(errors).contains(["prompt stream canceled"])
	await _cleanup_adapter(adapter)


func test_adapter_clears_busy_when_initialize_fails_during_connect_prompt() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var busy_events: Array[bool] = []
	var errors: Array[String] = []
	var turn_results: Array = []

	adapter.busy_changed.connect(func(is_busy: bool): busy_events.append(is_busy))
	adapter.error_occurred.connect(func(message: String): errors.append(message))
	adapter.turn_finished.connect(func(message): turn_results.append(message))

	adapter.connect_client("Prompt before init")
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "error",
			"request_id": str(init_request.get("request_id", "")),
			"error": "initialize failed",
		},
	})
	await _await_frames(2)

	assert_bool(adapter.is_busy()).is_false()
	assert_bool(adapter.is_client_connected()).is_false()
	assert_array(busy_events).is_equal([true, false])
	assert_array(errors).contains(["initialize failed"])
	assert_array(turn_results).is_empty()
	await _cleanup_adapter(adapter)


func test_adapter_reconnect_emits_session_closed_and_reemits_session_ready() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var ready_payloads: Array = []
	var closed_events: Array[int] = []

	adapter.session_ready.connect(func(server_info: Dictionary): ready_payloads.append(server_info))
	adapter.session_closed.connect(func(): closed_events.append(1))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/help"}]},
		},
	})
	await _await_frames(2)

	adapter.connect_client()
	assert_int(closed_events.size()).is_equal(1)
	init_request = _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/retry"}]},
		},
	})
	await _await_frames(2)

	assert_int(ready_payloads.size()).is_equal(2)
	assert_dict(ready_payloads[0]).contains_keys(["commands"])
	assert_dict(ready_payloads[1]).contains_keys(["commands"])
	await _cleanup_adapter(adapter)


func test_adapter_reconnect_while_busy_resets_busy_and_starts_new_connect_prompt_turn() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var busy_events: Array[bool] = []
	var turn_starts: Array = []
	var turn_results: Array = []
	var closed_events: Array[int] = []

	adapter.busy_changed.connect(func(is_busy: bool): busy_events.append(is_busy))
	adapter.turn_started.connect(func(prompt: String, session_id: String): turn_starts.append({"prompt": prompt, "session_id": session_id}))
	adapter.turn_finished.connect(func(message): turn_results.append(message))
	adapter.session_closed.connect(func(): closed_events.append(1))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	adapter.query("Old turn")
	await _await_frames(1)

	adapter.connect_client("New prompt")
	assert_int(closed_events.size()).is_equal(1)
	assert_array(turn_starts).is_equal([
		{"prompt": "Old turn", "session_id": "default"},
		{"prompt": "New prompt", "session_id": "default"},
	])

	init_request = _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)
	transport.emit_stdout_message(_result_payload("reconnected"))
	await _await_frames(2)

	assert_array(busy_events).is_equal([true, false, true, false])
	assert_int(turn_results.size()).is_equal(1)
	await _cleanup_adapter(adapter)


func test_adapter_passes_rate_limit_events_through_turn_stream_without_finishing_turn() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var busy_events: Array[bool] = []
	var all_messages: Array = []
	var turn_messages: Array = []
	var turn_results: Array = []

	adapter.busy_changed.connect(func(is_busy: bool): busy_events.append(is_busy))
	adapter.message_received.connect(func(message): all_messages.append(message))
	adapter.turn_message_received.connect(func(message): turn_messages.append(message))
	adapter.turn_finished.connect(func(message): turn_results.append(message))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	adapter.query("Hi")
	transport.emit_stdout_message({
		"type": "rate_limit_event",
		"rate_limit_info": {
			"status": "allowed_warning",
			"resetsAt": 1700000000,
			"rateLimitType": "five_hour",
			"utilization": 0.91,
		},
		"uuid": "rate-1",
		"session_id": "default",
	})
	await _await_frames(2)

	assert_bool(adapter.is_busy()).is_true()
	assert_array(busy_events).is_equal([true])
	assert_int(turn_results.size()).is_equal(0)
	assert_int(all_messages.size()).is_equal(1)
	assert_object(all_messages[0]).is_instanceof(ClaudeRateLimitEventScript)
	assert_int(turn_messages.size()).is_equal(1)
	assert_object(turn_messages[0]).is_instanceof(ClaudeRateLimitEventScript)

	transport.emit_stdout_message(_result_payload("done"))
	await _await_frames(2)

	assert_bool(adapter.is_busy()).is_false()
	assert_array(busy_events).is_equal([true, false])
	assert_int(turn_results.size()).is_equal(1)
	await _cleanup_adapter(adapter)


func test_adapter_emits_error_for_query_while_busy_without_interrupting_current_turn() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var errors: Array[String] = []
	var busy_events: Array[bool] = []
	var turn_results: Array[int] = []

	adapter.error_occurred.connect(func(message: String): errors.append(message))
	adapter.busy_changed.connect(func(is_busy: bool): busy_events.append(is_busy))
	adapter.turn_finished.connect(func(_message): turn_results.append(1))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	adapter.query("First")
	adapter.query("Second")
	transport.emit_stdout_message(_result_payload("done"))
	await _await_frames(2)

	assert_bool(adapter.is_busy()).is_false()
	assert_array(busy_events).is_equal([true, false])
	assert_int(turn_results.size()).is_equal(1)
	assert_str(errors[-1]).contains("still in flight")
	await _cleanup_adapter(adapter)


func test_adapter_emits_connection_error_and_supports_auth_probe_before_connect() -> void:
	var transport = FakeTransportScript.new()
	transport.open_error_message = "transport unavailable"
	transport.auth_status_result = {
		"ok": false,
		"logged_in": false,
		"error_code": "logged_out",
		"error_message": "Not logged in",
	}
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var errors: Array[String] = []

	adapter.error_occurred.connect(func(message: String): errors.append(message))

	var auth_status := adapter.get_auth_status()
	assert_bool(bool(auth_status.get("logged_in", true))).is_false()
	assert_str(str(auth_status.get("error_code", ""))).is_equal("logged_out")

	adapter.connect_client()
	await _await_frames(1)

	assert_bool(adapter.is_client_connected()).is_false()
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("transport unavailable")
	await _cleanup_adapter(adapter)


func test_adapter_can_retry_connect_after_initial_transport_failure() -> void:
	var transport = FakeTransportScript.new()
	transport.open_error_message = "transport unavailable"
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var errors: Array[String] = []

	adapter.error_occurred.connect(func(message: String): errors.append(message))

	adapter.connect_client()
	await _await_frames(1)
	assert_bool(adapter.is_client_connected()).is_false()
	assert_str(errors[-1]).contains("transport unavailable")
	assert_int(transport.stdout_listener_count()).is_equal(0)
	assert_int(transport.stderr_listener_count()).is_equal(0)
	assert_int(transport.closed_listener_count()).is_equal(0)
	assert_int(transport.error_listener_count()).is_equal(0)

	transport.open_error_message = ""
	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	assert_bool(adapter.is_client_connected()).is_true()
	assert_int(transport.stdout_listener_count()).is_equal(1)
	assert_int(transport.stderr_listener_count()).is_equal(1)
	assert_int(transport.closed_listener_count()).is_equal(1)
	assert_int(transport.error_listener_count()).is_equal(1)
	await _cleanup_adapter(adapter)


func test_adapter_auth_probe_clears_stale_error_on_success() -> void:
	var transport = FakeTransportScript.new()
	transport.auth_status_result = {
		"ok": false,
		"logged_in": false,
		"error_code": "logged_out",
		"error_message": "Not logged in",
	}
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)

	var logged_out_status := adapter.get_auth_status()
	assert_bool(bool(logged_out_status.get("logged_in", true))).is_false()
	assert_str(adapter.get_last_error()).contains("Not logged in")

	transport.auth_status_result = {
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

	var logged_in_status := adapter.get_auth_status()
	assert_bool(bool(logged_in_status.get("logged_in", false))).is_true()
	assert_str(adapter.get_last_error()).is_empty()


func test_adapter_emits_error_for_async_transport_failure() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var errors: Array[String] = []
	var closed_events: Array[int] = []

	adapter.error_occurred.connect(func(message: String): errors.append(message))
	adapter.session_closed.connect(func(): closed_events.append(1))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	transport.emit_transport_failure("pipe died")
	await _await_frames(2)

	assert_array(errors).contains(["pipe died"])
	assert_str(adapter.get_last_error()).contains("pipe died")
	assert_int(closed_events.size()).is_equal(1)
	await _cleanup_adapter(adapter)


func test_adapter_emits_session_closed_once_per_connection() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)
	var closed_events: Array[int] = []

	adapter.session_closed.connect(func(): closed_events.append(1))

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	transport.close()
	await _await_frames(2)
	assert_int(closed_events.size()).is_equal(1)

	adapter.connect_client()
	init_request = _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	adapter.disconnect_client()
	await _await_frames(2)
	assert_int(closed_events.size()).is_equal(2)


func test_adapter_session_passthrough_reads_and_mutates_sessions() -> void:
	var config_root := _create_config_root("adapter-sessions")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_path := "/tmp/adapter-session-project"
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "31313131-3131-4313-8313-313131313131"
	_write_session_file(project_dir, session_id, [
		{
			"type": "user",
			"uuid": "adapter-u-1",
			"sessionId": session_id,
			"cwd": project_path,
			"message": {"role": "user", "content": "Saved prompt"},
		},
		{
			"type": "assistant",
			"uuid": "adapter-a-1",
			"parentUuid": "adapter-u-1",
			"sessionId": session_id,
			"message": {"role": "assistant", "content": "Saved answer"},
		},
		{"type": "summary", "summary": "Saved summary"},
	], 1712302000)

	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), FakeTransportScript.new())
	var sessions := adapter.list_sessions(project_path, 0, 0, false)
	assert_int(sessions.size()).is_equal(1)
	assert_str(sessions[0].session_id).is_equal(session_id)

	assert_int(adapter.rename_session(session_id, "Adapter renamed", project_path)).is_equal(OK)
	assert_int(adapter.tag_session(session_id, "review", project_path)).is_equal(OK)

	var info = adapter.get_session_info(session_id, project_path)
	assert_object(info).is_not_null()
	if info == null:
		return
	assert_str(info.summary).is_equal("Adapter renamed")
	assert_str(str(info.tag)).is_equal("review")
	var transcript := adapter.get_session_transcript(session_id, project_path)
	assert_int(transcript.size()).is_equal(2)
	assert_str(transcript[0].kind).is_equal("user")
	assert_str(transcript[1].kind).is_equal("assistant")
	var fork_result = adapter.fork_session(session_id, project_path, "", "Adapter fork")
	assert_object(fork_result).is_not_null()
	if fork_result != null:
		var fork_info = adapter.get_session_info(fork_result.session_id, project_path)
		assert_object(fork_info).is_not_null()
		if fork_info != null:
			assert_str(fork_info.custom_title).is_equal("Adapter fork")
	assert_str(adapter.get_last_error()).is_empty()


func test_adapter_session_mutation_failure_updates_last_error_and_emits_signal() -> void:
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), FakeTransportScript.new())
	var errors: Array[String] = []
	adapter.error_occurred.connect(func(message: String): errors.append(message))

	assert_int(adapter.rename_session("not-a-uuid", "Bad")).is_equal(ERR_INVALID_PARAMETER)
	assert_str(adapter.get_last_error()).contains("Invalid session_id")
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("Invalid session_id")
	assert_that(adapter.fork_session("not-a-uuid")).is_null()
	assert_str(adapter.get_last_error()).contains("Invalid session_id")


func _complete_adapter_rewind(adapter: ClaudeClientAdapter, user_message_id: String, label: String) -> void:
	await adapter.rewind_files(user_message_id)
	_async_completions.append(label)


func _complete_adapter_stop_task(adapter: ClaudeClientAdapter, task_id: String, label: String) -> void:
	await adapter.stop_task(task_id)
	_async_completions.append(label)


func test_adapter_rewind_files_passthroughs_to_runtime_client() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	Callable(self, "_complete_adapter_rewind").call_deferred(adapter, "adapter-user-1", "adapter-rewind")
	await _await_frames(1)
	var rewind_request := _read_last_write(transport)
	assert_str(str((rewind_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("rewind_files")
	assert_str(str((rewind_request.get("request", {}) as Dictionary).get("user_message_id", ""))).is_equal("adapter-user-1")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(rewind_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	assert_array(_async_completions).contains(["adapter-rewind"])
	assert_str(adapter.get_last_error()).is_empty()
	await _cleanup_adapter(adapter)


func test_adapter_stop_task_passthroughs_to_runtime_client() -> void:
	var transport = FakeTransportScript.new()
	var adapter = ClaudeClientAdapterScript.new(ClaudeAgentOptions.new(), transport)

	adapter.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	Callable(self, "_complete_adapter_stop_task").call_deferred(adapter, "task-abc123", "adapter-stop-task")
	await _await_frames(1)
	var stop_request := _read_last_write(transport)
	assert_str(str((stop_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("stop_task")
	assert_str(str((stop_request.get("request", {}) as Dictionary).get("task_id", ""))).is_equal("task-abc123")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(stop_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	assert_array(_async_completions).contains(["adapter-stop-task"])
	assert_str(adapter.get_last_error()).is_empty()
	await _cleanup_adapter(adapter)


func _await_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _cleanup_adapter(adapter) -> void:
	if adapter == null:
		return
	adapter.disconnect_client()
	await _await_frames(2)


func _read_last_write(transport) -> Dictionary:
	return JSON.parse_string(transport.writes[-1])


func _result_payload(result_text: String) -> Dictionary:
	return {
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": result_text,
	}


func _create_config_root(label: String) -> String:
	var root_path := _create_temp_root("adapter-config-%s" % label)
	DirAccess.make_dir_recursive_absolute(root_path.path_join("projects"))
	return root_path


func _create_temp_root(label: String) -> String:
	var root_path := ClaudeSessionsScript._resolve_absolute_path(
		ProjectSettings.globalize_path("user://%s-%s" % [label, Time.get_ticks_usec()])
	)
	DirAccess.make_dir_recursive_absolute(root_path)
	_created_roots.append(root_path)
	return root_path


func _make_project_dir(config_root: String, project_path: String) -> String:
	var sanitized := ClaudeSessionsScript._sanitize_path(
		ClaudeSessionsScript._resolve_absolute_path(project_path)
	)
	var project_dir := config_root.path_join("projects").path_join(sanitized)
	DirAccess.make_dir_recursive_absolute(project_dir)
	return project_dir


func _write_session_file(project_dir: String, session_id: String, entries: Array, mtime: int) -> void:
	var file := FileAccess.open(project_dir.path_join("%s.jsonl" % session_id), FileAccess.WRITE)
	for entry in entries:
		file.store_line(JSON.stringify(entry))
	file.close()
	var output: Array = []
	OS.execute("python3", [
		"-c",
		"import os, sys; ts=int(sys.argv[2]); os.utime(sys.argv[1], (ts, ts))",
		project_dir.path_join("%s.jsonl" % session_id),
		str(mtime),
	], output, true)


func _delete_tree(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return
	var access := DirAccess.open(path)
	if access == null:
		return
	for directory_name in access.get_directories():
		_delete_tree(path.path_join(directory_name))
	for file_name in access.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
