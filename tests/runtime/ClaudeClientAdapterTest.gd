# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")
const ClaudeClientAdapterScript := preload("res://addons/claude_agent_sdk/runtime/adapters/claude_client_adapter.gd")
const ClaudeSystemMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_system_message.gd")
const ClaudeAssistantMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_assistant_message.gd")
const ClaudeResultMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_result_message.gd")


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


func _await_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


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
