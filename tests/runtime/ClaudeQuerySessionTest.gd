# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")


func test_initialize_caches_server_info_and_sends_control_request() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(transport)

	session.open_session()

	assert_int(transport.writes.size()).is_equal(1)
	var initialize_request: Dictionary = JSON.parse_string(transport.writes[0])
	assert_str(str(initialize_request.get("type", ""))).is_equal("control_request")
	assert_str(str((initialize_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("initialize")

	var request_id := str(initialize_request.get("request_id", ""))
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": request_id,
			"response": {
				"commands": [{"name": "/help"}],
				"output_style": "default",
			},
		},
	})

	assert_dict(session.get_server_info()).contains_keys(["commands", "output_style"])


func test_receive_response_finishes_on_first_result_but_message_stream_keeps_history() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(transport)
	session.open_session()
	var init_id := str((JSON.parse_string(transport.writes[0]) as Dictionary).get("request_id", ""))
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": init_id,
			"response": {"output_style": "default"},
		},
	})

	session.send_user_prompt("What is 2 + 2?")
	var response_stream = session.receive_response()
	var message_stream = session.receive_messages()

	transport.emit_stdout_message({
		"type": "assistant",
		"message": {
			"model": "haiku",
			"content": [{"type": "text", "text": "4"}],
		},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 20,
		"duration_api_ms": 10,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "4",
	})

	var assistant: Variant = await response_stream.next_message()
	var result: Variant = await response_stream.next_message()
	var response_end: Variant = await response_stream.next_message()
	transport.close()
	var all_messages: Array = await message_stream.collect()

	assert_object(assistant).is_instanceof(ClaudeAssistantMessage)
	assert_object(result).is_instanceof(ClaudeResultMessage)
	assert_that(response_end).is_null()
	assert_int(all_messages.size()).is_equal(2)


func test_dynamic_controls_send_expected_control_requests() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(transport)
	session.open_session()
	var init_id := str((JSON.parse_string(transport.writes[0]) as Dictionary).get("request_id", ""))
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": init_id,
			"response": {},
		},
	})

	session.interrupt()
	var interrupt_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((interrupt_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("interrupt")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(interrupt_request.get("request_id", "")),
			"response": {},
		},
	})

	session.set_permission_mode("plan")
	var permission_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((permission_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("set_permission_mode")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(permission_request.get("request_id", "")),
			"response": {},
		},
	})

	session.set_model("haiku")
	var model_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((model_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("set_model")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(model_request.get("request_id", "")),
			"response": {},
		},
	})
