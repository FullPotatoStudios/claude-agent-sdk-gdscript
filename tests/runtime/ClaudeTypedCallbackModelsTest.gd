# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")
const ClaudeHookMatcherScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_matcher.gd")
const ClaudePermissionRuleValueScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_rule_value.gd")
const ClaudePermissionUpdateScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_update.gd")
const ClaudeHookInputScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input.gd")
const ClaudeHookInputPreToolUseScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input_pre_tool_use.gd")
const ClaudeHookInputPostToolUseScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input_post_tool_use.gd")
const ClaudeHookInputPostToolUseFailureScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input_post_tool_use_failure.gd")
const ClaudeHookInputUserPromptSubmitScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input_user_prompt_submit.gd")
const ClaudeHookInputStopScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input_stop.gd")
const ClaudeHookInputSubagentStopScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input_subagent_stop.gd")
const ClaudeHookInputPreCompactScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input_pre_compact.gd")
const ClaudeHookInputNotificationScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input_notification.gd")
const ClaudeHookInputSubagentStartScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input_subagent_start.gd")
const ClaudeHookInputPermissionRequestScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_input_permission_request.gd")
const ClaudeHookOutputScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_output.gd")
const ClaudeHookOutputPreToolUseScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_output_pre_tool_use.gd")
const ClaudeHookOutputNotificationScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_output_notification.gd")
const ClaudeHookOutputPermissionRequestScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_output_permission_request.gd")
const ClaudeHookOutputPostToolUseScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_output_post_tool_use.gd")
const ClaudeToolPermissionContextScript := preload("res://addons/claude_agent_sdk/runtime/claude_tool_permission_context.gd")
const ClaudeHookContextScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_context.gd")
const ClaudePermissionResultAllowScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_allow.gd")


func _typed_hook_callback(_input_data: Dictionary, _tool_use_id: String, _context) -> ClaudeHookOutput:
	return ClaudeHookOutputScript.new({
		"continue_after_hook": false,
		"system_message": "Typed hook output",
		"hook_specific_output": ClaudeHookOutputPreToolUseScript.new({
			"permission_decision": "allow",
			"permission_decision_reason": "Safe command",
			"additional_context": "Extra runtime context",
		}),
	})


func _alias_hook_callback(_input_data: Dictionary, _tool_use_id: String, _context) -> Dictionary:
	return {
		"continue_": false,
		"async_": true,
		"async_timeout": 1500,
		"hook_specific_output": ClaudeHookOutputNotificationScript.new({
			"additional_context": "Notification processed",
		}),
	}


func _nullable_hook_callback(_input_data: Dictionary, tool_use_id: Variant, _context) -> Dictionary:
	return {
		"reason": "tool_use_id=null" if tool_use_id == null else "tool_use_id=%s" % [str(tool_use_id)],
	}


func test_permission_update_serializes_rule_mode_and_directory_variants() -> void:
	var add_rules = ClaudePermissionUpdateScript.new({
		"type": "addRules",
		"rules": [
			ClaudePermissionRuleValueScript.new({
				"tool_name": "Bash",
				"rule_content": "ls:*",
			}),
		],
		"behavior": "allow",
		"destination": "session",
	})
	assert_dict(add_rules.to_dict()).is_equal({
		"type": "addRules",
		"destination": "session",
		"rules": [{"toolName": "Bash", "ruleContent": "ls:*"}],
		"behavior": "allow",
	})

	var set_mode = ClaudePermissionUpdateScript.new({
		"type": "setMode",
		"mode": "plan",
		"destination": "projectSettings",
	})
	assert_dict(set_mode.to_dict()).is_equal({
		"type": "setMode",
		"destination": "projectSettings",
		"mode": "plan",
	})

	var add_directories = ClaudePermissionUpdateScript.new({
		"type": "addDirectories",
		"directories": ["res://addons", "res://demo"],
	})
	assert_dict(add_directories.to_dict()).is_equal({
		"type": "addDirectories",
		"directories": ["res://addons", "res://demo"],
	})


func test_permission_context_keeps_raw_suggestions_and_exposes_typed_updates() -> void:
	var raw_suggestions := [{
		"type": "addRules",
		"rules": [{"toolName": "Write", "ruleContent": "tmp/*"}],
		"behavior": "allow",
		"destination": "session",
	}]
	var context = ClaudeToolPermissionContextScript.new("abort-signal", raw_suggestions, "tool-77", "agent-9")

	assert_that(context.signal).is_equal("abort-signal")
	assert_that(context.callback_signal).is_equal("abort-signal")
	assert_array(context.suggestions).is_equal(raw_suggestions)
	assert_int(context.typed_suggestions.size()).is_equal(1)
	var typed_update = context.typed_suggestions[0] as ClaudePermissionUpdate
	assert_object(typed_update).is_not_null()
	assert_str(typed_update.type).is_equal("addRules")
	assert_str((typed_update.rules[0] as ClaudePermissionRuleValue).tool_name).is_equal("Write")
	assert_that(context.tool_use_id).is_equal("tool-77")
	assert_that(context.agent_id).is_equal("agent-9")


func test_hook_context_exposes_signal_alias() -> void:
	var typed_input = ClaudeHookInputNotificationScript.new({
		"hook_event_name": "Notification",
		"message": "Ping",
		"notification_type": "info",
	})
	var context = ClaudeHookContextScript.new(
		"hook-signal",
		{"hook_event_name": "Notification", "message": "Ping"},
		typed_input
	)
	assert_that(context.signal).is_equal("hook-signal")
	assert_that(context.callback_signal).is_equal("hook-signal")
	assert_dict(context.raw_input).is_equal({"hook_event_name": "Notification", "message": "Ping"})
	assert_object(context.typed_input as ClaudeHookInputNotification).is_not_null()
	assert_object(context.hook_input as ClaudeHookInputNotification).is_not_null()
	assert_str((context.hook_input as ClaudeHookInputNotification).notification_type).is_equal("info")


func test_hook_input_coercion_covers_upstream_hook_event_taxonomy() -> void:
	var cases := [
		{
			"expected_path": "res://addons/claude_agent_sdk/runtime/claude_hook_input_pre_tool_use.gd",
			"config": {
				"session_id": "sess-1",
				"transcript_path": "/tmp/transcript",
				"cwd": "/repo",
				"hook_event_name": "PreToolUse",
				"tool_name": "Bash",
				"tool_input": {"command": "echo hi"},
				"tool_use_id": "tool-pre-1",
				"agent_id": "agent-42",
				"agent_type": "researcher",
			},
		},
		{
			"expected_path": "res://addons/claude_agent_sdk/runtime/claude_hook_input_post_tool_use.gd",
			"config": {
				"session_id": "sess-1",
				"transcript_path": "/tmp/transcript",
				"cwd": "/repo",
				"hook_event_name": "PostToolUse",
				"tool_name": "Bash",
				"tool_input": {"command": "echo hi"},
				"tool_response": {"content": [{"type": "text", "text": "hi"}]},
				"tool_use_id": "tool-post-1",
				"agent_id": "agent-42",
				"agent_type": "researcher",
			},
		},
		{
			"expected_path": "res://addons/claude_agent_sdk/runtime/claude_hook_input_post_tool_use_failure.gd",
			"config": {
				"session_id": "sess-1",
				"transcript_path": "/tmp/transcript",
				"cwd": "/repo",
				"hook_event_name": "PostToolUseFailure",
				"tool_name": "Bash",
				"tool_input": {"command": "echo hi"},
				"tool_use_id": "tool-failure-1",
				"error": "Permission denied",
				"is_interrupt": true,
				"agent_id": "agent-42",
				"agent_type": "researcher",
			},
		},
		{
			"expected_path": "res://addons/claude_agent_sdk/runtime/claude_hook_input_user_prompt_submit.gd",
			"config": {
				"session_id": "sess-1",
				"transcript_path": "/tmp/transcript",
				"cwd": "/repo",
				"hook_event_name": "UserPromptSubmit",
				"prompt": "Summarize the level.",
			},
		},
		{
			"expected_path": "res://addons/claude_agent_sdk/runtime/claude_hook_input_stop.gd",
			"config": {
				"session_id": "sess-1",
				"transcript_path": "/tmp/transcript",
				"cwd": "/repo",
				"hook_event_name": "Stop",
				"stop_hook_active": true,
			},
		},
		{
			"expected_path": "res://addons/claude_agent_sdk/runtime/claude_hook_input_subagent_stop.gd",
			"config": {
				"session_id": "sess-1",
				"transcript_path": "/tmp/transcript",
				"cwd": "/repo",
				"hook_event_name": "SubagentStop",
				"stop_hook_active": false,
				"agent_id": "agent-42",
				"agent_transcript_path": "/tmp/agent-transcript",
				"agent_type": "researcher",
			},
		},
		{
			"expected_path": "res://addons/claude_agent_sdk/runtime/claude_hook_input_pre_compact.gd",
			"config": {
				"session_id": "sess-1",
				"transcript_path": "/tmp/transcript",
				"cwd": "/repo",
				"hook_event_name": "PreCompact",
				"trigger": "manual",
				"custom_instructions": "Keep the TODO list.",
			},
		},
		{
			"expected_path": "res://addons/claude_agent_sdk/runtime/claude_hook_input_notification.gd",
			"config": {
				"session_id": "sess-1",
				"transcript_path": "/tmp/transcript",
				"cwd": "/repo",
				"hook_event_name": "Notification",
				"message": "Task completed",
				"title": "Success",
				"notification_type": "info",
			},
		},
		{
			"expected_path": "res://addons/claude_agent_sdk/runtime/claude_hook_input_subagent_start.gd",
			"config": {
				"session_id": "sess-1",
				"transcript_path": "/tmp/transcript",
				"cwd": "/repo",
				"hook_event_name": "SubagentStart",
				"agent_id": "agent-42",
				"agent_type": "researcher",
			},
		},
		{
			"expected_path": "res://addons/claude_agent_sdk/runtime/claude_hook_input_permission_request.gd",
			"config": {
				"session_id": "sess-1",
				"transcript_path": "/tmp/transcript",
				"cwd": "/repo",
				"hook_event_name": "PermissionRequest",
				"tool_name": "Bash",
				"tool_input": {"command": "ls"},
				"permission_suggestions": [{"type": "allow", "rule": "Bash(*)"}],
				"agent_id": "agent-42",
				"agent_type": "researcher",
			},
		},
	]

	for test_case in cases:
		var config: Dictionary = (test_case.get("config", {}) as Dictionary).duplicate(true)
		var coerced = ClaudeHookInputScript.coerce_input(config)
		assert_object(coerced).is_not_null()
		assert_str(str(coerced.get_script().resource_path)).is_equal(str(test_case["expected_path"]))
		assert_dict((coerced as ClaudeHookInput).to_dict()).contains_keys(config.keys())
		for key_variant in config.keys():
			var key := str(key_variant)
			assert_that((coerced as ClaudeHookInput).to_dict().get(key, null)).is_equal(config[key_variant])


func test_query_session_hook_context_exposes_typed_hook_input_without_mutating_raw_payload() -> void:
	var callback_state := {
		"raw_input": {},
		"context_raw_input": {},
		"typed_input": null,
		"hook_input": null,
	}
	var callback := func(input_data: Dictionary, _tool_use_id: Variant, context):
		callback_state["raw_input"] = input_data.duplicate(true)
		callback_state["context_raw_input"] = context.raw_input.duplicate(true)
		callback_state["typed_input"] = context.typed_input
		callback_state["hook_input"] = context.hook_input
		return {"reason": "captured"}

	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(
		transport,
		ClaudeAgentOptions.new({
			"hooks": {
				"PreToolUse": [
					ClaudeHookMatcherScript.new({
						"matcher": "Bash",
						"hooks": [callback],
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
		"request_id": "typed-hook-input",
		"request": {
			"subtype": "hook_callback",
			"callback_id": hook_callback_id,
			"tool_use_id": "tool-pre-backfill-1",
			"input": {
				"hook_event_name": "PreToolUse",
				"tool_name": "Bash",
				"tool_input": {"command": "ls"},
			},
		},
	})
	await get_tree().process_frame
	await get_tree().process_frame

	assert_dict(callback_state["raw_input"] as Dictionary).is_equal({
		"hook_event_name": "PreToolUse",
		"tool_name": "Bash",
		"tool_input": {"command": "ls"},
	})
	assert_dict(callback_state["context_raw_input"] as Dictionary).is_equal(callback_state["raw_input"] as Dictionary)

	var typed_input = callback_state["typed_input"] as ClaudeHookInputPreToolUse
	assert_object(typed_input).is_not_null()
	assert_object(callback_state["hook_input"] as ClaudeHookInputPreToolUse).is_not_null()
	assert_str(typed_input.tool_name).is_equal("Bash")
	assert_that(typed_input.tool_use_id).is_equal("tool-pre-backfill-1")
	assert_that((typed_input.to_dict()).get("tool_use_id", null)).is_equal("tool-pre-backfill-1")


func test_query_session_hook_callback_accepts_typed_hook_output() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(
		transport,
		ClaudeAgentOptions.new({
			"hooks": {
				"PreToolUse": [
					ClaudeHookMatcherScript.new({
						"matcher": "Bash",
						"hooks": [Callable(self, "_typed_hook_callback")],
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
		"request_id": "typed-hook",
		"request": {
			"subtype": "hook_callback",
			"callback_id": hook_callback_id,
			"tool_use_id": "tool-typed-1",
			"input": {"hook_event_name": "PreToolUse", "tool_name": "Bash"},
		},
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var response: Dictionary = JSON.parse_string(transport.writes[-1])
	var payload: Dictionary = ((response.get("response", {}) as Dictionary).get("response", {}) as Dictionary)
	assert_bool(bool(payload.get("continue", true))).is_false()
	assert_str(str(payload.get("systemMessage", ""))).is_equal("Typed hook output")
	assert_dict(payload.get("hookSpecificOutput", {}) as Dictionary).is_equal({
		"hookEventName": "PreToolUse",
		"permissionDecision": "allow",
		"permissionDecisionReason": "Safe command",
		"additionalContext": "Extra runtime context",
	})


func test_query_session_hook_callback_converts_legacy_alias_keys() -> void:
	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(
		transport,
		ClaudeAgentOptions.new({
			"hooks": {
				"Notification": [
					ClaudeHookMatcherScript.new({
						"hooks": [Callable(self, "_alias_hook_callback")],
					}),
				],
			},
		})
	)
	session.open_session()
	var initialize_request: Dictionary = JSON.parse_string(transport.writes[0])
	var hook_callback_id := str((((initialize_request.get("request", {}) as Dictionary).get("hooks", {}) as Dictionary).get("Notification", []) as Array)[0].get("hookCallbackIds", [])[0])

	transport.emit_stdout_message({
		"type": "control_request",
		"request_id": "alias-hook",
		"request": {
			"subtype": "hook_callback",
			"callback_id": hook_callback_id,
			"tool_use_id": "tool-alias-1",
			"input": {"hook_event_name": "Notification", "message": "Hello"},
		},
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var response: Dictionary = JSON.parse_string(transport.writes[-1])
	var payload: Dictionary = ((response.get("response", {}) as Dictionary).get("response", {}) as Dictionary)
	assert_bool(bool(payload.get("continue", true))).is_false()
	assert_bool(bool(payload.get("async", false))).is_true()
	assert_int(int(payload.get("asyncTimeout", 0))).is_equal(1500)
	assert_dict(payload.get("hookSpecificOutput", {}) as Dictionary).is_equal({
		"hookEventName": "Notification",
		"additionalContext": "Notification processed",
	})


func test_hook_output_normalizes_nested_raw_hook_specific_output_keys() -> void:
	var output = ClaudeHookOutputScript.new({
		"continue_": false,
		"hook_specific_output": {
			"hook_event_name": "Notification",
			"additional_context": "Normalized in helper",
		},
	})

	assert_dict(output.to_dict()).is_equal({
		"continue": false,
		"hookSpecificOutput": {
			"hookEventName": "Notification",
			"additionalContext": "Normalized in helper",
		},
	})


func test_hook_specific_output_helpers_cover_permission_request_and_post_tool_use() -> void:
	var permission_request = ClaudeHookOutputPermissionRequestScript.new({
		"decision": {
			"behavior": "allow",
			"updatedInput": {"safe_mode": true},
		},
	})
	assert_dict(permission_request.to_dict()).is_equal({
		"hookEventName": "PermissionRequest",
		"decision": {
			"behavior": "allow",
			"updatedInput": {"safe_mode": true},
		},
	})

	var post_tool_use = ClaudeHookOutputPostToolUseScript.new({
		"updated_mcp_tool_output": {"ok": true},
		"additional_context": "Tool output updated",
	})
	assert_dict(post_tool_use.to_dict()).is_equal({
		"hookEventName": "PostToolUse",
		"additionalContext": "Tool output updated",
		"updatedMCPToolOutput": {"ok": true},
	})


func test_query_session_permission_callback_accepts_typed_permission_updates() -> void:
	var callback_state := {
		"raw_suggestions": [],
		"typed_count": 0,
	}
	var callback := func(_tool_name: String, input_data: Dictionary, context):
		callback_state["raw_suggestions"] = context.suggestions.duplicate(true)
		callback_state["typed_count"] = context.typed_suggestions.size()
		var updated_input := input_data.duplicate(true)
		updated_input["safe_mode"] = true
		return ClaudePermissionResultAllowScript.new(updated_input, [
			ClaudePermissionUpdateScript.new({
				"type": "addRules",
				"rules": [{"toolName": "Write", "ruleContent": "tmp/*"}],
				"behavior": "allow",
				"destination": "session",
			}),
		])

	var transport = FakeTransportScript.new()
	var session = ClaudeQuerySession.new(
		transport,
		ClaudeAgentOptions.new({"can_use_tool": callback})
	)
	session.open_session()

	var suggestions := [{
		"type": "addRules",
		"rules": [{"toolName": "Write", "ruleContent": "project/*"}],
		"behavior": "ask",
		"destination": "session",
	}]
	transport.emit_stdout_message({
		"type": "control_request",
		"request_id": "typed-permissions",
		"request": {
			"subtype": "can_use_tool",
			"tool_name": "Write",
			"input": {"file_path": "notes.txt"},
			"permission_suggestions": suggestions,
			"tool_use_id": "tool-typed-2",
		},
	})
	await get_tree().process_frame

	assert_array(callback_state["raw_suggestions"] as Array).is_equal(suggestions)
	assert_int(int(callback_state["typed_count"])).is_equal(1)

	var response: Dictionary = JSON.parse_string(transport.writes[-1])
	var payload: Dictionary = ((response.get("response", {}) as Dictionary).get("response", {}) as Dictionary)
	assert_str(str(payload.get("behavior", ""))).is_equal("allow")
	assert_bool(bool((payload.get("updatedInput", {}) as Dictionary).get("safe_mode", false))).is_true()
	assert_array(payload.get("updatedPermissions", []) as Array).is_equal([{
		"type": "addRules",
		"destination": "session",
		"rules": [{"toolName": "Write", "ruleContent": "tmp/*"}],
		"behavior": "allow",
	}])


func test_permission_update_and_allow_result_preserve_explicit_empty_lists() -> void:
	var empty_rules_update = ClaudePermissionUpdateScript.new({
		"type": "addRules",
		"rules": [],
		"behavior": "allow",
		"destination": "session",
	})
	assert_dict(empty_rules_update.to_dict()).is_equal({
		"type": "addRules",
		"destination": "session",
		"rules": [],
		"behavior": "allow",
	})

	var empty_directories_update = ClaudePermissionUpdateScript.new({
		"type": "addDirectories",
		"directories": [],
	})
	assert_dict(empty_directories_update.to_dict()).is_equal({
		"type": "addDirectories",
		"directories": [],
	})

	var allow_result = ClaudePermissionResultAllowScript.new({"ok": true}, [])
	assert_dict(allow_result.to_dict({"fallback": true})).is_equal({
		"behavior": "allow",
		"updatedInput": {"ok": true},
		"updatedPermissions": [],
	})


func test_query_session_keeps_missing_callback_ids_nullable() -> void:
	var transport = FakeTransportScript.new()
	var permission_callback = func(_tool_name: String, _input_data: Dictionary, context):
		return ClaudePermissionResultAllowScript.new({
			"tool_use_id": context.tool_use_id,
			"agent_id": context.agent_id,
		})
	var session = ClaudeQuerySession.new(
		transport,
		ClaudeAgentOptions.new({
			"hooks": {
				"Notification": [
					ClaudeHookMatcherScript.new({
						"hooks": [Callable(self, "_nullable_hook_callback")],
					}),
					],
				},
				"can_use_tool": permission_callback,
			})
	)
	session.open_session()
	var initialize_request: Dictionary = JSON.parse_string(transport.writes[0])
	var hook_callback_id := str((((initialize_request.get("request", {}) as Dictionary).get("hooks", {}) as Dictionary).get("Notification", []) as Array)[0].get("hookCallbackIds", [])[0])

	transport.emit_stdout_message({
		"type": "control_request",
		"request_id": "nullable-hook",
		"request": {
			"subtype": "hook_callback",
			"callback_id": hook_callback_id,
			"input": {"hook_event_name": "Notification", "message": "Hello"},
		},
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var hook_response: Dictionary = JSON.parse_string(transport.writes[-1])
	var hook_payload: Dictionary = ((hook_response.get("response", {}) as Dictionary).get("response", {}) as Dictionary)
	assert_str(str(hook_payload.get("reason", ""))).is_equal("tool_use_id=null")

	transport.emit_stdout_message({
		"type": "control_request",
		"request_id": "nullable-permission",
		"request": {
			"subtype": "can_use_tool",
			"tool_name": "Write",
			"input": {"file_path": "notes.txt"},
		},
	})
	await get_tree().process_frame

	var permission_response: Dictionary = JSON.parse_string(transport.writes[-1])
	var permission_payload: Dictionary = ((permission_response.get("response", {}) as Dictionary).get("response", {}) as Dictionary)
	assert_that((permission_payload.get("updatedInput", {}) as Dictionary).get("tool_use_id", "missing")).is_equal(null)
	assert_that((permission_payload.get("updatedInput", {}) as Dictionary).get("agent_id", "missing")).is_equal(null)
