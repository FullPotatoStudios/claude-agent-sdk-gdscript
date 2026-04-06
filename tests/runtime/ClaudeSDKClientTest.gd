# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")
const ClaudeHookMatcherScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_matcher.gd")
const ClaudeStreamEventScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_stream_event.gd")
const ClaudePermissionResultAllowScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_allow.gd")
const ClaudeSubprocessCLITransportScript := preload("res://addons/claude_agent_sdk/runtime/transport/subprocess_cli_transport.gd")


func _client_hook_callback(input_data: Dictionary, _tool_use_id: String, _context) -> Dictionary:
	return {"continue": true, "echo": input_data}


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


func test_client_emits_error_signal_for_async_control_response_failure() -> void:
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
	assert_bool(Callable(client, "reconnect_mcp_server").is_valid()).is_true()
	assert_bool(Callable(client, "toggle_mcp_server").is_valid()).is_true()


func test_client_options_force_stdio_permission_prompt_when_can_use_tool_is_configured() -> void:
	var permission_callback := func(_tool_name: String, _input_data: Dictionary, _context):
		return ClaudePermissionResultAllowScript.new()
	var options = ClaudeAgentOptions.new({"can_use_tool": permission_callback})
	var transport = ClaudeSubprocessCLITransportScript.new(options)
	var args = transport.build_command_args()

	assert_bool(args.has("--permission-prompt-tool")).is_true()
	assert_bool(args.has("stdio")).is_true()


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
