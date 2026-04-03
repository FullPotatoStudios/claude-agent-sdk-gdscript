# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")


func test_client_receive_messages_runs_until_disconnect() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)

	client.connect_client()
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"output_style": "default"},
		},
	})

	client.query("Hi")
	var response_stream = client.receive_response()
	var all_stream = client.receive_messages()

	transport.emit_stdout_message({
		"type": "assistant",
		"message": {"model": "haiku", "content": [{"type": "text", "text": "Hello"}]},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "Hello",
	})

	assert_object(await response_stream.next_message()).is_instanceof(ClaudeAssistantMessage)
	assert_object(await response_stream.next_message()).is_instanceof(ClaudeResultMessage)
	assert_that(await response_stream.next_message()).is_null()

	transport.close()
	var all_messages: Array = await all_stream.collect()
	assert_int(all_messages.size()).is_equal(2)


func test_client_rejects_second_query_while_response_is_active() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)
	client.connect_client()
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})

	client.query("First")
	client.query("Second")

	assert_str(client.get_last_error()).contains("still in flight")


func test_one_shot_query_returns_pull_stream() -> void:
	var transport = FakeTransportScript.new()
	var stream = ClaudeQuery.query("Hi", ClaudeAgentOptions.new(), transport)
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	transport.emit_stdout_message({
		"type": "assistant",
		"message": {"model": "haiku", "content": [{"type": "text", "text": "4"}]},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "4",
	})

	assert_object(await stream.next_message()).is_instanceof(ClaudeAssistantMessage)
	assert_object(await stream.next_message()).is_instanceof(ClaudeResultMessage)
