# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")
const ClaudeHookMatcherScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_matcher.gd")
const ClaudePermissionResultAllowScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_allow.gd")
const ClaudePermissionResultDenyScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_deny.gd")


func _async_hook_callback(input_data: Dictionary, tool_use_id: String, _context) -> Dictionary:
	await get_tree().process_frame
	return {
		"continue": true,
		"echo": input_data,
		"toolUseId": tool_use_id,
	}


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


func test_initialize_includes_hook_matchers_with_generated_callback_ids() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(
		transport,
		ClaudeAgentOptions.new({
			"hooks": {
				"PreToolUse": [
					ClaudeHookMatcherScript.new({
						"matcher": "Bash",
						"hooks": [Callable(self, "_async_hook_callback")],
						"timeout_sec": 15.0,
					}),
				],
			},
		})
	)

	session.open_session()

	var initialize_request: Dictionary = JSON.parse_string(transport.writes[0])
	var hooks_config: Dictionary = (initialize_request.get("request", {}) as Dictionary).get("hooks", {})
	assert_dict(hooks_config).contains_keys(["PreToolUse"])
	var matchers: Array = hooks_config["PreToolUse"]
	assert_int(matchers.size()).is_equal(1)
	var matcher: Dictionary = matchers[0]
	assert_str(str(matcher.get("matcher", ""))).is_equal("Bash")
	assert_int((matcher.get("hookCallbackIds", []) as Array).size()).is_equal(1)
	assert_float(float(matcher.get("timeout", 0.0))).is_equal(15.0)


func test_initialize_error_fails_pending_streams() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(transport)
	session.open_session()
	session.send_user_prompt("Hi")
	var response_stream = session.receive_response()
	var initialize_request: Dictionary = JSON.parse_string(transport.writes[0])
	var request_id := str(initialize_request.get("request_id", ""))

	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "error",
			"request_id": request_id,
			"error": "initialize failed",
		},
	})

	assert_str(session.get_last_error()).contains("initialize failed")
	assert_str(response_stream.get_error()).contains("initialize failed")
	assert_that(await response_stream.next_message()).is_null()
	assert_bool(transport.connected).is_false()


func test_inbound_hook_callback_writes_success_response() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(
		transport,
		ClaudeAgentOptions.new({
			"hooks": {
				"PreToolUse": [
					ClaudeHookMatcherScript.new({
						"matcher": "Bash",
						"hooks": [Callable(self, "_async_hook_callback")],
					}),
				],
			},
		})
	)
	session.open_session()
	var initialize_request: Dictionary = JSON.parse_string(transport.writes[0])
	var hook_callback_id := str((((initialize_request.get("request", {}) as Dictionary).get("hooks", {}) as Dictionary).get("PreToolUse", []) as Array)[0].get("hookCallbackIds", [])[0])

	transport.emit_stdout_message({
		"type": "control_request",
		"request_id": "hook-1",
		"request": {
			"subtype": "hook_callback",
			"callback_id": hook_callback_id,
			"tool_use_id": "tool-1",
			"input": {"tool_name": "Bash"},
		},
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var response: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str(response.get("type", ""))).is_equal("control_response")
	assert_str(str((response.get("response", {}) as Dictionary).get("subtype", ""))).is_equal("success")
	assert_str(str((((response.get("response", {}) as Dictionary).get("response", {}) as Dictionary).get("toolUseId", "")))).is_equal("tool-1")


func test_inbound_permission_callback_supports_allow_and_deny_results() -> void:
	var allow_callback := func(tool_name: String, input_data: Dictionary, context):
		assert_str(tool_name).is_equal("Write")
		assert_str(context.tool_use_id).is_equal("tool-42")
		var updated_input = input_data.duplicate(true)
		updated_input["safe_mode"] = true
		return ClaudePermissionResultAllowScript.new(updated_input, [{"type": "allow", "tool_name": "Write"}])
	var deny_callback := func(_tool_name: String, _input_data: Dictionary, _context):
		return ClaudePermissionResultDenyScript.new("Denied", true)

	var allow_transport = FakeTransportScript.new()
	var allow_session = ClaudeQuerySession.new(allow_transport, ClaudeAgentOptions.new({"can_use_tool": allow_callback}))
	allow_session.open_session()
	allow_transport.emit_stdout_message({
		"type": "control_request",
		"request_id": "perm-allow",
		"request": {
			"subtype": "can_use_tool",
			"tool_name": "Write",
			"input": {"file_path": "foo.txt"},
			"permission_suggestions": [],
			"tool_use_id": "tool-42",
		},
	})
	await get_tree().process_frame
	var allow_response: Dictionary = JSON.parse_string(allow_transport.writes[-1])
	assert_str(str((((allow_response.get("response", {}) as Dictionary).get("response", {}) as Dictionary).get("behavior", "")))).is_equal("allow")
	assert_bool((((allow_response.get("response", {}) as Dictionary).get("response", {}) as Dictionary).get("updatedInput", {}) as Dictionary).get("safe_mode", false)).is_true()

	var deny_transport = FakeTransportScript.new()
	var deny_session = ClaudeQuerySession.new(deny_transport, ClaudeAgentOptions.new({"can_use_tool": deny_callback}))
	deny_session.open_session()
	deny_transport.emit_stdout_message({
		"type": "control_request",
		"request_id": "perm-deny",
		"request": {
			"subtype": "can_use_tool",
			"tool_name": "Bash",
			"input": {"command": "rm -rf /"},
			"permission_suggestions": [],
		},
	})
	await get_tree().process_frame
	var deny_response: Dictionary = JSON.parse_string(deny_transport.writes[-1])
	assert_str(str((((deny_response.get("response", {}) as Dictionary).get("response", {}) as Dictionary).get("behavior", "")))).is_equal("deny")
	assert_bool(bool((((deny_response.get("response", {}) as Dictionary).get("response", {}) as Dictionary).get("interrupt", false)))).is_true()


func test_unsupported_inbound_control_request_returns_error_response() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(transport)
	session.open_session()

	transport.emit_stdout_message({
		"type": "control_request",
		"request_id": "unknown-1",
		"request": {
			"subtype": "unsupported_control",
		},
	})
	await get_tree().process_frame

	var response: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((response.get("response", {}) as Dictionary).get("subtype", ""))).is_equal("error")
	assert_str(str((response.get("response", {}) as Dictionary).get("error", ""))).contains("Unsupported control request subtype")


func test_control_cancel_request_suppresses_late_response() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(
		transport,
		ClaudeAgentOptions.new({
			"hooks": {
				"PreToolUse": [
					ClaudeHookMatcherScript.new({
						"matcher": "Bash",
						"hooks": [Callable(self, "_async_hook_callback")],
					}),
				],
			},
		})
	)
	session.open_session()
	var initialize_request: Dictionary = JSON.parse_string(transport.writes[0])
	var hook_callback_id := str((((initialize_request.get("request", {}) as Dictionary).get("hooks", {}) as Dictionary).get("PreToolUse", []) as Array)[0].get("hookCallbackIds", [])[0])
	var writes_before: int = transport.writes.size()

	transport.emit_stdout_message({
		"type": "control_request",
		"request_id": "hook-cancel",
		"request": {
			"subtype": "hook_callback",
			"callback_id": hook_callback_id,
			"input": {"tool_name": "Bash"},
		},
	})
	transport.emit_stdout_message({
		"type": "control_cancel_request",
		"request_id": "hook-cancel",
	})
	await get_tree().process_frame
	await get_tree().process_frame

	assert_int(transport.writes.size()).is_equal(writes_before)


func test_context_usage_and_mcp_controls_send_expected_control_requests() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(transport)
	session.open_session()
	var initialize_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(initialize_request.get("request_id", "")),
			"response": {},
		},
	})

	session._send_control_request({"subtype": "get_context_usage"}, true)
	var usage_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((usage_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("get_context_usage")

	session._send_control_request({"subtype": "mcp_status"}, true)
	var status_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((status_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("mcp_status")

	session._send_control_request({
		"subtype": "mcp_reconnect",
		"serverName": "filesystem",
	}, true)
	var reconnect_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((reconnect_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("mcp_reconnect")
	assert_str(str((reconnect_request.get("request", {}) as Dictionary).get("serverName", ""))).is_equal("filesystem")

	session._send_control_request({
		"subtype": "mcp_toggle",
		"serverName": "filesystem",
		"enabled": false,
	}, true)
	var toggle_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((toggle_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("mcp_toggle")
	assert_bool(bool((toggle_request.get("request", {}) as Dictionary).get("enabled", true))).is_false()


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


func test_non_initialize_control_response_does_not_complete_initialization() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(transport)
	session.open_session()
	session.send_user_prompt("Hi")

	assert_int(transport.writes.size()).is_equal(1)
	session.interrupt()
	assert_int(transport.writes.size()).is_equal(2)

	var initialize_request: Dictionary = JSON.parse_string(transport.writes[0])
	var interrupt_request: Dictionary = JSON.parse_string(transport.writes[1])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(interrupt_request.get("request_id", "")),
			"response": {},
		},
	})

	assert_dict(session.get_server_info()).is_empty()
	assert_int(transport.writes.size()).is_equal(2)

	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(initialize_request.get("request_id", "")),
			"response": {"output_style": "default"},
		},
	})

	assert_dict(session.get_server_info()).contains_keys(["output_style"])
	assert_int(transport.writes.size()).is_equal(3)
	var prompt_payload: Dictionary = JSON.parse_string(transport.writes[2])
	assert_str(str(prompt_payload.get("type", ""))).is_equal("user")


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
