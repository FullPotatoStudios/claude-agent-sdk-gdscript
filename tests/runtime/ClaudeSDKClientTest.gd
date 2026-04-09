# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")
const ClaudeHookMatcherScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_matcher.gd")
const ClaudeStreamEventScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_stream_event.gd")
const ClaudePermissionResultAllowScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_allow.gd")
const ClaudeSubprocessCLITransportScript := preload("res://addons/claude_agent_sdk/runtime/transport/subprocess_cli_transport.gd")
const ClaudePromptStreamScript := preload("res://addons/claude_agent_sdk/runtime/input/claude_prompt_stream.gd")
const ClaudeContextUsageResponseScript := preload("res://addons/claude_agent_sdk/runtime/claude_context_usage_response.gd")
const ClaudeMcpStatusResponseScript := preload("res://addons/claude_agent_sdk/runtime/claude_mcp_status_response.gd")

var _async_completions: Array[String] = []


class TransportFactoryClient extends ClaudeSDKClient:
	var transports: Array = []

	func _init(initial_options = null, transports_to_create: Array = []) -> void:
		transports = transports_to_create.duplicate()
		super(initial_options, null)

	func _create_transport():
		if transports.is_empty():
			return null
		return transports.pop_front()


func after_test() -> void:
	_async_completions.clear()


func _client_hook_callback(input_data: Dictionary, _tool_use_id: String, _context) -> Dictionary:
	return {"continue": true, "echo": input_data}


func _complete_client_rewind(client: ClaudeSDKClient, user_message_id: String, label: String) -> void:
	await client.rewind_files(user_message_id)
	_async_completions.append(label)


func _complete_client_stop_task(client: ClaudeSDKClient, task_id: String, label: String) -> void:
	await client.stop_task(task_id)
	_async_completions.append(label)


func _complete_client_reconnect_mcp_server(client: ClaudeSDKClient, server_name: String, label: String) -> void:
	await client.reconnect_mcp_server(server_name)
	_async_completions.append(label)


func _complete_client_toggle_mcp_server(client: ClaudeSDKClient, server_name: String, enabled: bool, label: String) -> void:
	await client.toggle_mcp_server(server_name, enabled)
	_async_completions.append(label)


func _capture_client_context_usage(client: ClaudeSDKClient, sink: Array, label: String) -> void:
	sink.append(await client.get_context_usage())
	_async_completions.append(label)


func _capture_client_mcp_status(client: ClaudeSDKClient, sink: Array, label: String) -> void:
	sink.append(await client.get_mcp_status())
	_async_completions.append(label)


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
	client.disconnect_client()


func test_client_receive_response_yields_stream_events_in_order() -> void:
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

	client.query("Hi")
	var response_stream = client.receive_response()
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-1",
		"event": {"type": "content_block_delta"},
	})
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

	assert_object(await response_stream.next_message()).is_instanceof(ClaudeStreamEventScript)
	assert_object(await response_stream.next_message()).is_instanceof(ClaudeAssistantMessage)
	assert_object(await response_stream.next_message()).is_instanceof(ClaudeResultMessage)
	assert_that(await response_stream.next_message()).is_null()
	client.disconnect_client()


func test_client_receive_response_for_session_ignores_other_sessions() -> void:
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

	client.query("A", "session-a")
	client.query("B", "session-b")
	var response_stream = client.receive_response_for_session("session-a")
	transport.emit_stdout_message({
		"type": "assistant",
		"session_id": "session-b",
		"message": {"model": "haiku", "content": [{"type": "text", "text": "B"}]},
	})
	transport.emit_stdout_message({
		"type": "assistant",
		"session_id": "session-a",
		"message": {"model": "haiku", "content": [{"type": "text", "text": "A"}]},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "session-b",
		"result": "done-b",
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "session-a",
		"result": "done-a",
	})

	assert_object(await response_stream.next_message()).is_instanceof(ClaudeAssistantMessage)
	assert_object(await response_stream.next_message()).is_instanceof(ClaudeResultMessage)
	assert_that(await response_stream.next_message()).is_null()
	client.disconnect_client()


func test_client_allows_different_session_queries_to_overlap() -> void:
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

	client.query("First", "session-a")
	client.query("Second", "session-b")

	assert_str(client.get_last_error()).is_empty()
	assert_int(transport.writes.size()).is_equal(3)
	assert_str(str((JSON.parse_string(transport.writes[1]) as Dictionary).get("session_id", ""))).is_equal("session-a")
	assert_str(str((JSON.parse_string(transport.writes[2]) as Dictionary).get("session_id", ""))).is_equal("session-b")
	client.disconnect_client()


func test_client_rejects_second_query_for_same_session_while_response_is_active() -> void:
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

	client.query("First", "session-a")
	client.query("Second", "session-a")

	assert_str(client.get_last_error()).contains("session 'session-a'")
	client.disconnect_client()


func test_client_rejects_second_query_for_same_session_while_prompt_stream_is_still_active() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)
	var prompt_stream = ClaudePromptStreamScript.new()
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

	client.query(prompt_stream, "session-a")
	client.query("Second", "session-a")

	assert_str(client.get_last_error()).contains("session 'session-a'")
	client.disconnect_client()


func test_client_emits_error_signal_for_query_before_connect() -> void:
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), FakeTransportScript.new())
	var errors: Array[String] = []
	client.error_occurred.connect(func(message: String): errors.append(message))

	client.query("Hi")

	assert_array(errors).contains(["Call connect_client() before query()"])
	assert_str(client.get_last_error()).contains("Call connect_client() before query()")


func test_client_disconnect_releases_transport_signal_listeners_before_reconnect() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)

	client.connect_client()
	assert_int(transport.stdout_listener_count()).is_equal(1)
	assert_int(transport.stderr_listener_count()).is_equal(1)
	assert_int(transport.closed_listener_count()).is_equal(1)
	assert_int(transport.error_listener_count()).is_equal(1)
	client.disconnect_client()
	assert_int(transport.stdout_listener_count()).is_equal(0)
	assert_int(transport.stderr_listener_count()).is_equal(0)
	assert_int(transport.closed_listener_count()).is_equal(0)
	assert_int(transport.error_listener_count()).is_equal(0)


func test_client_connect_with_string_prompt_queues_default_user_message_after_initialize() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)

	client.connect_client("Hello Claude")
	var response_stream = client.receive_response()
	assert_int(transport.writes.size()).is_equal(1)

	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	assert_int(transport.writes.size()).is_equal(2)
	var prompt_payload: Dictionary = JSON.parse_string(transport.writes[1])
	assert_str(str(prompt_payload.get("type", ""))).is_equal("user")
	assert_str(str(prompt_payload.get("session_id", ""))).is_equal("default")
	assert_str(str((prompt_payload.get("message", {}) as Dictionary).get("content", ""))).is_equal("Hello Claude")

	transport.emit_stdout_message({
		"type": "assistant",
		"session_id": "default",
		"message": {"model": "haiku", "content": [{"type": "text", "text": "Hi"}]},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "done",
	})

	assert_object(await response_stream.next_message()).is_instanceof(ClaudeAssistantMessage)
	assert_object(await response_stream.next_message()).is_instanceof(ClaudeResultMessage)
	assert_that(await response_stream.next_message()).is_null()
	client.disconnect_client()


func test_client_receive_response_can_start_after_connect_before_query() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)

	client.connect_client()
	var response_stream = client.receive_response()
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
		"session_id": "foreign-session",
		"message": {"model": "haiku", "content": [{"type": "text", "text": "Hi"}]},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "foreign-session",
		"result": "done",
	})

	assert_object(await response_stream.next_message()).is_instanceof(ClaudeAssistantMessage)
	assert_object(await response_stream.next_message()).is_instanceof(ClaudeResultMessage)
	assert_that(await response_stream.next_message()).is_null()
	client.disconnect_client()


func test_client_connect_with_string_prompt_keeps_default_user_payload_session_id_when_options_session_id_is_configured() -> void:
	var transport = FakeTransportScript.new()
	var options = ClaudeAgentOptions.new({"session_id": "resume-from-options"})
	var client = ClaudeSDKClient.new(options, transport)

	client.connect_client("Resume with prompt")
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})

	var prompt_payload: Dictionary = JSON.parse_string(transport.writes[1])
	assert_str(str(prompt_payload.get("session_id", ""))).is_equal("default")
	client.disconnect_client()


func test_client_connect_with_prompt_stream_preserves_messages_without_backfilling_session_id() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)
	var prompt_stream = ClaudePromptStreamScript.new()

	client.connect_client(prompt_stream)
	assert_int(transport.writes.size()).is_equal(1)
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
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
	prompt_stream.push_message({
		"type": "user",
		"session_id": "explicit-session",
		"message": {"role": "user", "content": "Second"},
		"parent_tool_use_id": null,
	})
	prompt_stream.finish()
	await get_tree().process_frame

	assert_int(transport.writes.size()).is_equal(3)
	var first_prompt: Dictionary = JSON.parse_string(transport.writes[1])
	var second_prompt: Dictionary = JSON.parse_string(transport.writes[2])
	assert_bool(first_prompt.has("session_id")).is_false()
	assert_str(str(second_prompt.get("session_id", ""))).is_equal("explicit-session")
	client.disconnect_client()


func test_client_connect_rejects_string_prompt_when_can_use_tool_is_configured_before_opening_session() -> void:
	var transport = FakeTransportScript.new()
	var permission_callback := func(_tool_name: String, _input_data: Dictionary, _context): return ClaudePermissionResultAllowScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new({
		"can_use_tool": permission_callback,
	}), transport)
	var errors: Array[String] = []
	client.error_occurred.connect(func(message: String): errors.append(message))

	client.connect_client("Hi")

	assert_array(errors).contains([
		"can_use_tool callback requires streamed prompt input. Please provide prompt as a ClaudePromptStream instead of a String."
	])
	assert_bool(transport.connected).is_false()
	assert_int(transport.writes.size()).is_equal(0)


func test_client_reconnect_reuses_custom_transport_without_leaking_old_streams() -> void:
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
	var old_stream = client.receive_messages()
	await get_tree().process_frame

	client.connect_client("Follow-up")
	assert_that(await old_stream.next_message()).is_null()
	assert_int(transport.writes.size()).is_equal(2)
	assert_int(transport.stdout_listener_count()).is_equal(1)
	assert_int(transport.stderr_listener_count()).is_equal(1)
	assert_int(transport.closed_listener_count()).is_equal(1)
	assert_int(transport.error_listener_count()).is_equal(1)

	init_request = JSON.parse_string(transport.writes[1])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await get_tree().process_frame

	assert_int(transport.writes.size()).is_equal(3)
	var prompt_payload: Dictionary = JSON.parse_string(transport.writes[2])
	assert_str(str(prompt_payload.get("session_id", ""))).is_equal("default")
	assert_str(str((prompt_payload.get("message", {}) as Dictionary).get("content", ""))).is_equal("Follow-up")

	client.disconnect_client()
	assert_int(transport.stdout_listener_count()).is_equal(0)
	assert_int(transport.stderr_listener_count()).is_equal(0)
	assert_int(transport.closed_listener_count()).is_equal(0)
	assert_int(transport.error_listener_count()).is_equal(0)

	client.connect_client()
	assert_int(transport.stdout_listener_count()).is_equal(1)
	assert_int(transport.stderr_listener_count()).is_equal(1)
	assert_int(transport.closed_listener_count()).is_equal(1)
	assert_int(transport.error_listener_count()).is_equal(1)
	client.disconnect_client()
	assert_int(transport.stdout_listener_count()).is_equal(0)
	assert_int(transport.stderr_listener_count()).is_equal(0)
	assert_int(transport.closed_listener_count()).is_equal(0)
	assert_int(transport.error_listener_count()).is_equal(0)


func test_client_reconnect_recreates_default_transport_when_no_custom_transport_is_injected() -> void:
	var first_transport = FakeTransportScript.new()
	var second_transport = FakeTransportScript.new()
	var client = TransportFactoryClient.new(ClaudeAgentOptions.new(), [
		FakeTransportScript.new(),
		first_transport,
		second_transport,
	])

	client.connect_client()
	assert_bool(first_transport.connected).is_true()
	assert_int(first_transport.writes.size()).is_equal(1)
	var first_init_request: Dictionary = JSON.parse_string(first_transport.writes[0])
	first_transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(first_init_request.get("request_id", "")),
			"response": {},
		},
	})
	await get_tree().process_frame

	client.connect_client("Fresh session")
	assert_bool(first_transport.connected).is_false()
	assert_int(first_transport.stdout_listener_count()).is_equal(0)
	assert_int(first_transport.stderr_listener_count()).is_equal(0)
	assert_int(first_transport.closed_listener_count()).is_equal(0)
	assert_int(first_transport.error_listener_count()).is_equal(0)
	assert_bool(second_transport.connected).is_true()
	assert_int(second_transport.writes.size()).is_equal(1)

	var second_init_request: Dictionary = JSON.parse_string(second_transport.writes[0])
	second_transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(second_init_request.get("request_id", "")),
			"response": {},
		},
	})
	await get_tree().process_frame

	assert_int(second_transport.writes.size()).is_equal(2)
	var prompt_payload: Dictionary = JSON.parse_string(second_transport.writes[1])
	assert_str(str(prompt_payload.get("session_id", ""))).is_equal("default")
	assert_str(str((prompt_payload.get("message", {}) as Dictionary).get("content", ""))).is_equal("Fresh session")
	assert_bool(client.get("_transport") == second_transport).is_true()
	client.disconnect_client()


func test_client_reconnect_clears_last_error_before_opening_new_default_transport() -> void:
	var failing_transport = FakeTransportScript.new()
	failing_transport.open_error_message = "transport unavailable"
	var recovery_transport = FakeTransportScript.new()
	var client = TransportFactoryClient.new(ClaudeAgentOptions.new(), [
		FakeTransportScript.new(),
		failing_transport,
		recovery_transport,
	])

	client.connect_client()
	assert_str(client.get_last_error()).contains("transport unavailable")

	client.connect_client()
	assert_str(client.get_last_error()).is_empty()
	assert_bool(recovery_transport.connected).is_true()
	assert_int(recovery_transport.writes.size()).is_equal(1)
	client.disconnect_client()


func test_client_disconnect_finishes_active_streams() -> void:
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

	client.query("Hi")
	var stream = client.receive_response()
	client.disconnect_client()

	assert_that(await stream.next_message()).is_null()
	assert_bool(stream.is_finished()).is_true()


func test_client_emits_error_signal_for_async_control_response_failure_after_model_reset_request() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)
	var errors: Array[String] = []
	client.error_occurred.connect(func(message: String): errors.append(message))
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

	client.set_model(null)
	var model_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((model_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("set_model")
	assert_that((model_request.get("request", {}) as Dictionary).get("model", "missing")).is_equal(null)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "error",
			"request_id": str(model_request.get("request_id", "")),
			"error": "model denied",
		},
	})
	await get_tree().process_frame

	assert_array(errors).contains(["model denied"])
	assert_str(client.get_last_error()).contains("model denied")
	client.disconnect_client()


func test_client_set_model_without_argument_serializes_null_reset() -> void:
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

	client.set_model()
	var model_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((model_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("set_model")
	assert_that((model_request.get("request", {}) as Dictionary).get("model", "missing")).is_equal(null)
	client.disconnect_client()


func test_client_set_model_rejects_non_string_non_null_value() -> void:
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
	await get_tree().process_frame

	client.set_model(123)

	assert_str(client.get_last_error()).contains("model must be null or a String")
	assert_int(transport.writes.size()).is_equal(1)
	client.disconnect_client()


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
	assert_that(await stream.next_message()).is_null()
	await get_tree().process_frame


func test_one_shot_query_with_prompt_stream_writes_items_without_backfilling_session_id() -> void:
	var transport = FakeTransportScript.new()
	var prompt_stream = ClaudePromptStreamScript.new()
	var stream = ClaudeQuery.query(prompt_stream, ClaudeAgentOptions.new(), transport)
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
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
	prompt_stream.push_message({
		"type": "user",
		"session_id": "explicit-session",
		"message": {"role": "user", "content": "Second"},
		"parent_tool_use_id": null,
	})
	prompt_stream.finish()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_int(transport.writes.size()).is_equal(3)
	var first_prompt: Dictionary = JSON.parse_string(transport.writes[1])
	var second_prompt: Dictionary = JSON.parse_string(transport.writes[2])
	assert_bool(first_prompt.has("session_id")).is_false()
	assert_str(str(second_prompt.get("session_id", ""))).is_equal("explicit-session")

	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "done",
	})

	assert_object(await stream.next_message()).is_instanceof(ClaudeResultMessage)
	assert_that(await stream.next_message()).is_null()
	await get_tree().process_frame


func test_one_shot_query_supports_hook_configuration_for_string_prompts() -> void:
	var transport = FakeTransportScript.new()
	var options = ClaudeAgentOptions.new({
		"hooks": {
			"PreToolUse": [
				ClaudeHookMatcherScript.new({
					"matcher": "Bash",
					"hooks": [Callable(self, "_client_hook_callback")],
				}),
			],
		},
	})
	var stream = ClaudeQuery.query("Hi", options, transport)
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	var hooks_config: Dictionary = (init_request.get("request", {}) as Dictionary).get("hooks", {})
	var hook_callback_id := str(((hooks_config.get("PreToolUse", []) as Array)[0] as Dictionary).get("hookCallbackIds", [])[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	transport.emit_stdout_message({
		"type": "control_request",
		"request_id": "hook-1",
		"request": {
			"subtype": "hook_callback",
			"callback_id": hook_callback_id,
			"input": {"tool_name": "Bash"},
		},
	})
	await get_tree().process_frame
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "ok",
	})

	assert_str(str((JSON.parse_string(transport.writes[-1]) as Dictionary).get("type", ""))).is_equal("control_response")
	assert_object(await stream.next_message()).is_instanceof(ClaudeResultMessage)
	assert_that(await stream.next_message()).is_null()
	await get_tree().process_frame


func test_one_shot_query_initializes_with_agents_before_writing_prompt() -> void:
	var transport = FakeTransportScript.new()
	var options = ClaudeAgentOptions.new({
		"agents": {
			"test-agent": {
				"description": "A test agent",
				"prompt": "Always mention that you are the test agent.",
				"tools": ["Read"],
				"model": "sonnet",
			},
		},
	})

	var stream = ClaudeQuery.query("Hi", options, transport)
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	var init_payload: Dictionary = init_request.get("request", {}) if init_request.get("request", {}) is Dictionary else {}
	assert_dict(init_payload).contains_keys(["agents"])
	assert_dict(init_payload["agents"]).contains_keys(["test-agent"])
	assert_int(transport.writes.size()).is_equal(1)

	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"agents": ["test-agent"]},
		},
	})

	assert_int(transport.writes.size()).is_equal(2)
	var prompt_payload: Dictionary = JSON.parse_string(transport.writes[1])
	assert_str(str(prompt_payload.get("type", ""))).is_equal("user")
	assert_str(str(prompt_payload.get("session_id", "<missing>"))).is_equal("")
	assert_str(str(((prompt_payload.get("message", {}) as Dictionary).get("content", "")))).is_equal("Hi")

	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "Done",
	})

	assert_object(await stream.next_message()).is_instanceof(ClaudeResultMessage)
	assert_that(await stream.next_message()).is_null()
	await get_tree().process_frame


func test_client_query_with_prompt_stream_backfills_missing_session_id() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)
	var prompt_stream = ClaudePromptStreamScript.new()
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

	client.query(prompt_stream, "session-42")
	var response_stream = client.receive_response()
	prompt_stream.push_message({
		"type": "user",
		"message": {"role": "user", "content": "First"},
		"parent_tool_use_id": null,
	})
	prompt_stream.push_message({
		"type": "user",
		"session_id": "explicit-session",
		"message": {"role": "user", "content": "Second"},
		"parent_tool_use_id": null,
	})
	prompt_stream.finish()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_int(transport.writes.size()).is_equal(3)
	var first_prompt: Dictionary = JSON.parse_string(transport.writes[1])
	var second_prompt: Dictionary = JSON.parse_string(transport.writes[2])
	assert_str(str(first_prompt.get("session_id", ""))).is_equal("session-42")
	assert_str(str(second_prompt.get("session_id", ""))).is_equal("explicit-session")

	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "session-42",
		"result": "done",
	})

	assert_object(await response_stream.next_message()).is_instanceof(ClaudeResultMessage)
	assert_that(await response_stream.next_message()).is_null()


func test_client_query_accepts_string_prompt_when_can_use_tool_is_configured() -> void:
	var permission_callback := func(_tool_name: String, _input_data: Dictionary, _context):
		return ClaudePermissionResultAllowScript.new()
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new({
		"can_use_tool": permission_callback,
	}), transport)

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
	client.query("Hi")

	assert_str(client.get_last_error()).is_empty()
	assert_int(transport.writes.size()).is_equal(2)
	var prompt_payload: Dictionary = JSON.parse_string(transport.writes[1])
	assert_str(str(prompt_payload.get("type", ""))).is_equal("user")
	assert_str(str(prompt_payload.get("session_id", ""))).is_equal("default")
	assert_str(str(((prompt_payload.get("message", {}) as Dictionary).get("content", "")))).is_equal("Hi")


func test_one_shot_query_fails_when_initialize_fails() -> void:
	var transport = FakeTransportScript.new()
	var stream = ClaudeQuery.query("Hi", ClaudeAgentOptions.new(), transport)
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "error",
			"request_id": str(init_request.get("request_id", "")),
			"error": "init denied",
		},
	})

	assert_str(stream.get_error()).contains("init denied")
	assert_that(await stream.next_message()).is_null()


func test_client_exposes_context_usage_and_mcp_control_methods() -> void:
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), FakeTransportScript.new())

	assert_bool(Callable(client, "get_context_usage").is_valid()).is_true()
	assert_bool(Callable(client, "get_mcp_status").is_valid()).is_true()
	assert_bool(Callable(client, "rewind_files").is_valid()).is_true()
	assert_bool(Callable(client, "stop_task").is_valid()).is_true()
	assert_bool(Callable(client, "reconnect_mcp_server").is_valid()).is_true()
	assert_bool(Callable(client, "toggle_mcp_server").is_valid()).is_true()


func test_client_get_context_usage_returns_typed_response() -> void:
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

	var responses: Array = []
	Callable(self, "_capture_client_context_usage").call_deferred(client, responses, "client-context-usage")
	await get_tree().process_frame
	var usage_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((usage_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("get_context_usage")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(usage_request.get("request_id", "")),
			"response": {
				"categories": [
					{"name": "System prompt", "tokens": 3200, "color": "#abc"},
					{"name": "Messages", "tokens": 61400, "color": "#def", "isDeferred": true},
				],
				"totalTokens": 98200,
				"maxTokens": 155000,
				"rawMaxTokens": 200000,
				"percentage": 49.1,
				"model": "claude-sonnet-4-5",
				"isAutoCompactEnabled": true,
				"memoryFiles": [{"path": "CLAUDE.md", "type": "project", "tokens": 512}],
				"mcpTools": [{"name": "search", "serverName": "ref", "tokens": 164, "isLoaded": true}],
				"agents": [{"agentType": "coder", "source": "sdk", "tokens": 299}],
				"gridRows": [],
				"apiUsage": null,
			},
		},
	})
	await get_tree().process_frame

	assert_array(_async_completions).contains(["client-context-usage"])
	assert_int(responses.size()).is_equal(1)
	assert_object(responses[0]).is_instanceof(ClaudeContextUsageResponseScript)
	var usage = responses[0] as ClaudeContextUsageResponse
	assert_object(usage).is_not_null()
	if usage == null:
		return
	assert_int(usage.total_tokens).is_equal(98200)
	assert_int(usage.categories.size()).is_equal(2)
	assert_str(usage.categories[0].name).is_equal("System prompt")
	assert_bool(bool(usage.categories[1].is_deferred)).is_true()
	assert_str(usage.mcp_tools[0].server_name).is_equal("ref")
	client.disconnect_client()
	responses.clear()


func test_client_get_mcp_status_returns_typed_response() -> void:
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

	var responses: Array = []
	Callable(self, "_capture_client_mcp_status").call_deferred(client, responses, "client-mcp-status")
	await get_tree().process_frame
	var status_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((status_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("mcp_status")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(status_request.get("request_id", "")),
			"response": {
				"mcpServers": [
					{
						"name": "my-http-server",
						"status": "connected",
						"serverInfo": {"name": "my-http-server", "version": "1.0.0"},
						"config": {"type": "http", "url": "https://example.com/mcp"},
						"scope": "project",
						"tools": [
							{"name": "greet", "description": "Greet a user", "annotations": {"readOnly": true}},
							{"name": "reset"},
						],
					},
					{
						"name": "failed-server",
						"status": "failed",
						"error": "Connection refused",
					},
				],
			},
		},
	})
	await get_tree().process_frame

	assert_array(_async_completions).contains(["client-mcp-status"])
	assert_int(responses.size()).is_equal(1)
	assert_object(responses[0]).is_instanceof(ClaudeMcpStatusResponseScript)
	var status = responses[0] as ClaudeMcpStatusResponse
	assert_object(status).is_not_null()
	if status == null:
		return
	assert_int(status.mcp_servers.size()).is_equal(2)
	assert_str(status.mcp_servers[0].server_info.version).is_equal("1.0.0")
	assert_str(str(status.mcp_servers[0].config.get("type", ""))).is_equal("http")
	assert_bool(bool(status.mcp_servers[0].tools[0].annotations.read_only)).is_true()
	assert_str(status.mcp_servers[1].error_message).is_equal("Connection refused")
	client.disconnect_client()
	responses.clear()


func test_client_rewind_files_requires_active_connection() -> void:
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), FakeTransportScript.new())
	var errors: Array[String] = []
	client.error_occurred.connect(func(message: String): errors.append(message))

	await client.rewind_files("user-123")

	assert_array(errors).contains(["Call connect_client() before rewind_files()"])
	assert_str(client.get_last_error()).contains("Call connect_client() before rewind_files()")


func test_client_stop_task_requires_active_connection() -> void:
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), FakeTransportScript.new())
	var errors: Array[String] = []
	client.error_occurred.connect(func(message: String): errors.append(message))

	await client.stop_task("task-abc123")

	assert_array(errors).contains(["Call connect_client() before stop_task()"])
	assert_str(client.get_last_error()).contains("Call connect_client() before stop_task()")


func test_client_reconnect_mcp_server_requires_active_connection() -> void:
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), FakeTransportScript.new())
	var errors: Array[String] = []
	client.error_occurred.connect(func(message: String): errors.append(message))

	await client.reconnect_mcp_server("filesystem")

	assert_array(errors).contains(["Call connect_client() before reconnect_mcp_server()"])
	assert_str(client.get_last_error()).contains("Call connect_client() before reconnect_mcp_server()")


func test_client_toggle_mcp_server_requires_active_connection() -> void:
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), FakeTransportScript.new())
	var errors: Array[String] = []
	client.error_occurred.connect(func(message: String): errors.append(message))

	await client.toggle_mcp_server("filesystem", false)

	assert_array(errors).contains(["Call connect_client() before toggle_mcp_server()"])
	assert_str(client.get_last_error()).contains("Call connect_client() before toggle_mcp_server()")


func test_client_rewind_files_updates_last_error_from_control_response() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)
	var errors: Array[String] = []
	client.error_occurred.connect(func(message: String): errors.append(message))
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

	Callable(self, "_complete_client_rewind").call_deferred(client, "user-123", "client-rewind")
	await get_tree().process_frame
	var rewind_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((rewind_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("rewind_files")
	assert_str(str((rewind_request.get("request", {}) as Dictionary).get("user_message_id", ""))).is_equal("user-123")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "error",
			"request_id": str(rewind_request.get("request_id", "")),
			"error": "rewind denied",
		},
	})
	await get_tree().process_frame

	assert_array(_async_completions).contains(["client-rewind"])
	assert_array(errors).contains(["rewind denied"])
	assert_str(client.get_last_error()).contains("rewind denied")
	client.disconnect_client()


func test_client_stop_task_updates_last_error_from_control_response() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)
	var errors: Array[String] = []
	client.error_occurred.connect(func(message: String): errors.append(message))
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

	Callable(self, "_complete_client_stop_task").call_deferred(client, "task-abc123", "client-stop-task")
	await get_tree().process_frame
	var stop_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((stop_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("stop_task")
	assert_str(str((stop_request.get("request", {}) as Dictionary).get("task_id", ""))).is_equal("task-abc123")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "error",
			"request_id": str(stop_request.get("request_id", "")),
			"error": "stop denied",
		},
	})
	await get_tree().process_frame

	assert_array(_async_completions).contains(["client-stop-task"])
	assert_array(errors).contains(["stop denied"])
	assert_str(client.get_last_error()).contains("stop denied")
	client.disconnect_client()


func test_client_stop_task_success_clears_previous_control_error() -> void:
	var transport = FakeTransportScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)
	var errors: Array[String] = []
	client.error_occurred.connect(func(message: String): errors.append(message))
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
	await get_tree().process_frame

	client.set_model("sonnet")
	var model_request: Dictionary = JSON.parse_string(transport.writes[-1])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "error",
			"request_id": str(model_request.get("request_id", "")),
			"error": "model denied",
		},
	})
	await get_tree().process_frame

	assert_array(errors).contains(["model denied"])
	assert_str(client.get_last_error()).contains("model denied")

	Callable(self, "_complete_client_stop_task").call_deferred(client, "task-abc123", "client-stop-task-success")
	await get_tree().process_frame
	var stop_request: Dictionary = JSON.parse_string(transport.writes[-1])
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
	await get_tree().process_frame

	assert_array(_async_completions).contains(["client-stop-task-success"])
	assert_int(errors.size()).is_equal(1)
	assert_str(client.get_last_error()).is_empty()
	client.disconnect_client()


func test_client_reconnect_mcp_server_sends_expected_control_request() -> void:
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

	Callable(self, "_complete_client_reconnect_mcp_server").call_deferred(client, "filesystem", "client-mcp-reconnect")
	await get_tree().process_frame
	var reconnect_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((reconnect_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("mcp_reconnect")
	assert_str(str((reconnect_request.get("request", {}) as Dictionary).get("serverName", ""))).is_equal("filesystem")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(reconnect_request.get("request_id", "")),
			"response": {},
		},
	})
	await get_tree().process_frame

	assert_array(_async_completions).contains(["client-mcp-reconnect"])
	assert_str(client.get_last_error()).is_empty()
	client.disconnect_client()


func test_client_toggle_mcp_server_sends_expected_control_request_for_disabled_state() -> void:
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

	Callable(self, "_complete_client_toggle_mcp_server").call_deferred(client, "filesystem", false, "client-mcp-toggle-false")
	await get_tree().process_frame
	var toggle_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((toggle_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("mcp_toggle")
	assert_str(str((toggle_request.get("request", {}) as Dictionary).get("serverName", ""))).is_equal("filesystem")
	assert_bool(bool((toggle_request.get("request", {}) as Dictionary).get("enabled", true))).is_false()
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(toggle_request.get("request_id", "")),
			"response": {},
		},
	})
	await get_tree().process_frame

	assert_array(_async_completions).contains(["client-mcp-toggle-false"])
	assert_str(client.get_last_error()).is_empty()
	client.disconnect_client()


func test_client_toggle_mcp_server_sends_expected_control_request_for_enabled_state() -> void:
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

	Callable(self, "_complete_client_toggle_mcp_server").call_deferred(client, "filesystem", true, "client-mcp-toggle-true")
	await get_tree().process_frame
	var toggle_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((toggle_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("mcp_toggle")
	assert_str(str((toggle_request.get("request", {}) as Dictionary).get("serverName", ""))).is_equal("filesystem")
	assert_bool(bool((toggle_request.get("request", {}) as Dictionary).get("enabled", false))).is_true()
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(toggle_request.get("request_id", "")),
			"response": {},
		},
	})
	await get_tree().process_frame

	assert_array(_async_completions).contains(["client-mcp-toggle-true"])
	assert_str(client.get_last_error()).is_empty()
	client.disconnect_client()


func test_client_options_force_stdio_permission_prompt_when_can_use_tool_is_configured() -> void:
	var permission_callback := func(_tool_name: String, _input_data: Dictionary, _context):
		return ClaudePermissionResultAllowScript.new()
	var options = ClaudeAgentOptions.new({"can_use_tool": permission_callback})
	var transport = ClaudeSubprocessCLITransportScript.new(options)
	var args = transport.build_command_args()

	assert_bool(args.has("--permission-prompt-tool")).is_true()
	assert_bool(args.has("stdio")).is_true()


func test_client_connect_rejects_explicit_permission_prompt_conflict_with_can_use_tool() -> void:
	var permission_callback := func(_tool_name: String, _input_data: Dictionary, _context):
		return ClaudePermissionResultAllowScript.new()
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new({
		"can_use_tool": permission_callback,
		"permission_prompt_tool_name": "custom-permission",
	}), FakeTransportScript.new())

	client.connect_client()

	assert_str(client.get_last_error()).contains("cannot be used with permission_prompt_tool_name")


func test_one_shot_query_fails_when_permission_prompt_conflicts_with_can_use_tool() -> void:
	var permission_callback := func(_tool_name: String, _input_data: Dictionary, _context):
		return ClaudePermissionResultAllowScript.new()
	var transport = FakeTransportScript.new()
	var stream = ClaudeQuery.query(ClaudePromptStreamScript.new(), ClaudeAgentOptions.new({
		"can_use_tool": permission_callback,
		"permission_prompt_tool_name": "custom-permission",
	}), transport)

	assert_str(stream.get_error()).contains("cannot be used with permission_prompt_tool_name")
	assert_that(await stream.next_message()).is_null()


func test_one_shot_query_rejects_string_prompt_when_can_use_tool_is_configured() -> void:
	var permission_callback := func(_tool_name: String, _input_data: Dictionary, _context):
		return ClaudePermissionResultAllowScript.new()
	var stream = ClaudeQuery.query("Hi", ClaudeAgentOptions.new({
		"can_use_tool": permission_callback,
	}), FakeTransportScript.new())

	assert_str(stream.get_error()).contains("requires streamed prompt input")
	assert_that(await stream.next_message()).is_null()


func test_client_extracts_sdk_mcp_servers_for_inbound_control_requests() -> void:
	var transport = FakeTransportScript.new()
	var options = ClaudeAgentOptions.new({
		"mcp_servers": {
			"sdk": ClaudeMcp.create_sdk_server(
				"runtime-tools",
				"1.0.0",
				[
					ClaudeMcp.tool(
						"echo",
						"Echo input",
						ClaudeMcp.schema_object({"name": ClaudeMcp.schema_scalar("string")}, ["name"]),
						func(args: Dictionary): return {"content": [{"type": "text", "text": "Hello %s" % str(args.get("name", ""))}]}
					),
				]
			),
			"filesystem": {"command": "mcp-server", "args": ["stdio"]},
		},
	})
	var client = ClaudeSDKClient.new(options, transport)
	client.connect_client()

	transport.emit_stdout_message({
		"type": "control_request",
		"request_id": "mcp-list",
		"request": {
			"subtype": "mcp_message",
			"server_name": "sdk",
			"message": {"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}},
		},
	})
	await get_tree().process_frame

	var response: Dictionary = JSON.parse_string(transport.writes[-1])
	var tools: Array = ((((response.get("response", {}) as Dictionary).get("response", {}) as Dictionary).get("mcp_response", {}) as Dictionary).get("result", {}) as Dictionary).get("tools", [])
	assert_int(tools.size()).is_equal(1)
	assert_str(str((tools[0] as Dictionary).get("name", ""))).is_equal("echo")
	client.disconnect_client()
