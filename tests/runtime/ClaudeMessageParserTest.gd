# GdUnit generated TestSuite
extends GdUnitTestSuite

const ClaudeMessageParserScript := preload("res://addons/claude_agent_sdk/runtime/parser/message_parser.gd")
const ClaudeAssistantMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_assistant_message.gd")
const ClaudeTextBlockScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_text_block.gd")
const ClaudeThinkingBlockScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_thinking_block.gd")
const ClaudeToolUseBlockScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_tool_use_block.gd")
const ClaudeToolResultBlockScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_tool_result_block.gd")
const ClaudeUserMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_user_message.gd")
const ClaudeSystemMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_system_message.gd")
const ClaudeTaskStartedMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_task_started_message.gd")
const ClaudeTaskProgressMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_task_progress_message.gd")
const ClaudeTaskNotificationMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_task_notification_message.gd")
const ClaudeRateLimitEventScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_rate_limit_event.gd")
const ClaudeRateLimitInfoScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_rate_limit_info.gd")
const ClaudeResultMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_result_message.gd")
const ClaudeStreamEventScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_stream_event.gd")


func test_parse_assistant_message_into_typed_blocks() -> void:
	var message: Variant = ClaudeMessageParserScript.parse_message({
		"type": "assistant",
		"session_id": "session-1",
		"message": {
			"model": "haiku",
			"content": [
				{"type": "text", "text": "Hello"},
				{"type": "thinking", "thinking": "Reasoning", "signature": "sig"},
				{"type": "tool_use", "id": "tool-1", "name": "Read", "input": {"path": "README.md"}},
				{"type": "tool_result", "tool_use_id": "tool-1", "content": "done", "is_error": false},
			],
			"usage": {"input_tokens": 10},
			"id": "assistant-1",
			"stop_reason": "end_turn",
		},
	})

	assert_object(message).is_instanceof(ClaudeAssistantMessageScript)
	assert_int(message.content.size()).is_equal(4)
	assert_object(message.content[0]).is_instanceof(ClaudeTextBlockScript)
	assert_object(message.content[1]).is_instanceof(ClaudeThinkingBlockScript)
	assert_object(message.content[2]).is_instanceof(ClaudeToolUseBlockScript)
	assert_object(message.content[3]).is_instanceof(ClaudeToolResultBlockScript)


func test_parse_user_system_and_result_messages() -> void:
	var user: Variant = ClaudeMessageParserScript.parse_message({
		"type": "user",
		"uuid": "user-1",
		"message": {"content": "Hi"},
	})
	var system: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "init",
		"commands": [],
	})
	var result: Variant = ClaudeMessageParserScript.parse_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "session-1",
		"result": "4",
	})

	assert_object(user).is_instanceof(ClaudeUserMessageScript)
	assert_object(system).is_instanceof(ClaudeSystemMessageScript)
	assert_object(result).is_instanceof(ClaudeResultMessageScript)
	assert_str(result.result).is_equal("4")
	assert_that(result.structured_output).is_null()


func test_parse_user_message_preserves_tool_result_blocks_and_tool_use_result_variant() -> void:
	var user: Variant = ClaudeMessageParserScript.parse_message({
		"type": "user",
		"uuid": "user-tool-1",
		"parent_tool_use_id": "toolu_123",
		"tool_use_result": ["structured", "metadata"],
		"message": {
			"role": "user",
			"content": [
				{"type": "tool_result", "tool_use_id": "toolu_123", "content": {"ok": true}, "is_error": false},
			],
		},
	})

	assert_object(user).is_instanceof(ClaudeUserMessageScript)
	assert_int((user.content as Array).size()).is_equal(1)
	assert_object((user.content as Array)[0]).is_instanceof(ClaudeToolResultBlockScript)
	assert_array(user.tool_use_result).is_equal(["structured", "metadata"])


func test_parse_result_extras_and_stream_event() -> void:
	var message: Variant = ClaudeMessageParserScript.parse_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "session-1",
		"result": "ok",
		"structured_output": {"ok": true},
		"modelUsage": {"haiku": {"inputTokens": 1}},
		"permission_denials": [{"tool": "Write"}],
		"errors": ["none"],
	})
	var stream_event: Variant = ClaudeMessageParserScript.parse_message({
		"type": "stream_event",
		"session_id": "session-1",
		"uuid": "stream-1",
		"parent_tool_use_id": "tool-1",
		"event": {"type": "content_block_delta"},
	})

	assert_object(message).is_instanceof(ClaudeResultMessageScript)
	assert_dict(message.structured_output).is_equal({"ok": true})
	assert_dict(message.model_usage).contains_keys(["haiku"])
	assert_array(message.permission_denials).is_equal([{"tool": "Write"}])
	assert_array(message.errors).is_equal(["none"])
	assert_object(stream_event).is_instanceof(ClaudeStreamEventScript)
	assert_str(stream_event.parent_tool_use_id).is_equal("tool-1")


func test_parse_stream_event_preserves_non_dictionary_event_payloads() -> void:
	var stream_event: Variant = ClaudeMessageParserScript.parse_message({
		"type": "stream_event",
		"session_id": "session-1",
		"uuid": "stream-2",
		"event": "raw-delta",
	})

	assert_object(stream_event).is_instanceof(ClaudeStreamEventScript)
	assert_that(stream_event.event).is_equal("raw-delta")


func test_parse_task_system_messages_into_typed_subclasses() -> void:
	var started: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "task_started",
		"task_id": "task-abc",
		"tool_use_id": "toolu_01",
		"description": "Reticulating splines",
		"task_type": "background",
		"uuid": "uuid-1",
		"session_id": "session-1",
	})
	var progress: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "task_progress",
		"task_id": "task-abc",
		"tool_use_id": "toolu_01",
		"description": "Halfway there",
		"usage": {
			"total_tokens": 1234,
			"tool_uses": 5,
			"duration_ms": 9876,
		},
		"last_tool_name": "Read",
		"uuid": "uuid-2",
		"session_id": "session-1",
	})
	var task_notification_message: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "task_notification",
		"task_id": "task-abc",
		"tool_use_id": "toolu_01",
		"status": "completed",
		"output_file": "/tmp/out.md",
		"summary": "All done",
		"usage": {
			"total_tokens": 2000,
			"tool_uses": 7,
			"duration_ms": 12345,
		},
		"uuid": "uuid-3",
		"session_id": "session-1",
	})

	assert_object(started).is_instanceof(ClaudeTaskStartedMessageScript)
	assert_str(started.task_id).is_equal("task-abc")
	assert_str(started.description).is_equal("Reticulating splines")
	assert_str(started.uuid).is_equal("uuid-1")
	assert_str(started.session_id).is_equal("session-1")
	assert_str(started.tool_use_id).is_equal("toolu_01")
	assert_str(started.task_type).is_equal("background")

	assert_object(progress).is_instanceof(ClaudeTaskProgressMessageScript)
	assert_str(progress.task_id).is_equal("task-abc")
	assert_str(progress.description).is_equal("Halfway there")
	assert_dict(progress.usage).is_equal({
		"total_tokens": 1234,
		"tool_uses": 5,
		"duration_ms": 9876,
	})
	assert_str(progress.last_tool_name).is_equal("Read")
	assert_str(progress.tool_use_id).is_equal("toolu_01")
	assert_str(progress.uuid).is_equal("uuid-2")
	assert_str(progress.session_id).is_equal("session-1")

	assert_object(task_notification_message).is_instanceof(ClaudeTaskNotificationMessageScript)
	assert_str(task_notification_message.task_id).is_equal("task-abc")
	assert_str(task_notification_message.status).is_equal("completed")
	assert_str(task_notification_message.output_file).is_equal("/tmp/out.md")
	assert_str(task_notification_message.summary).is_equal("All done")
	assert_dict(task_notification_message.usage).is_equal({
		"total_tokens": 2000,
		"tool_uses": 7,
		"duration_ms": 12345,
	})
	assert_str(task_notification_message.tool_use_id).is_equal("toolu_01")
	assert_str(task_notification_message.uuid).is_equal("uuid-3")
	assert_str(task_notification_message.session_id).is_equal("session-1")


func test_parse_task_system_messages_without_optional_fields() -> void:
	var started: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "task_started",
		"task_id": "task-abc",
		"description": "Working",
		"uuid": "uuid-1",
		"session_id": "session-1",
	})
	var progress: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "task_progress",
		"task_id": "task-abc",
		"description": "Working",
		"usage": {
			"total_tokens": 1,
			"tool_uses": 0,
			"duration_ms": 10,
		},
		"uuid": "uuid-2",
		"session_id": "session-1",
	})
	var task_notification_message: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "task_notification",
		"task_id": "task-abc",
		"status": "failed",
		"output_file": "/tmp/out.md",
		"summary": "Boom",
		"uuid": "uuid-3",
		"session_id": "session-1",
	})

	assert_object(started).is_instanceof(ClaudeTaskStartedMessageScript)
	assert_str(started.tool_use_id).is_empty()
	assert_str(started.task_type).is_empty()
	assert_object(progress).is_instanceof(ClaudeTaskProgressMessageScript)
	assert_str(progress.tool_use_id).is_empty()
	assert_str(progress.last_tool_name).is_empty()
	assert_object(task_notification_message).is_instanceof(ClaudeTaskNotificationMessageScript)
	assert_str(task_notification_message.tool_use_id).is_empty()
	assert_dict(task_notification_message.usage).is_empty()


func test_task_system_messages_preserve_backward_compatible_base_fields() -> void:
	var raw := {
		"type": "system",
		"subtype": "task_started",
		"task_id": "task-abc",
		"description": "Working",
		"uuid": "uuid-1",
		"session_id": "session-1",
	}
	var message: Variant = ClaudeMessageParserScript.parse_message(raw)

	assert_object(message).is_instanceof(ClaudeTaskStartedMessageScript)
	assert_object(message).is_instanceof(ClaudeSystemMessageScript)
	assert_str(message.subtype).is_equal("task_started")
	assert_dict(message.raw_data).is_equal(raw)


func test_unknown_system_subtypes_still_fall_back_to_generic_system_message() -> void:
	var message: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "some_future_subtype",
		"foo": "bar",
	})

	assert_object(message).is_instanceof(ClaudeSystemMessageScript)
	assert_object(message).is_not_instanceof(ClaudeTaskStartedMessageScript)
	assert_object(message).is_not_instanceof(ClaudeTaskProgressMessageScript)
	assert_object(message).is_not_instanceof(ClaudeTaskNotificationMessageScript)
	assert_str(message.subtype).is_equal("some_future_subtype")
	assert_dict(message.raw_data).is_equal({
		"type": "system",
		"subtype": "some_future_subtype",
		"foo": "bar",
	})


func test_task_system_messages_require_upstream_mandatory_fields() -> void:
	var missing_task_id: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "task_started",
		"description": "Working",
		"uuid": "uuid-1",
		"session_id": "session-1",
	})
	var missing_usage: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "task_progress",
		"task_id": "task-abc",
		"description": "Working",
		"uuid": "uuid-2",
		"session_id": "session-1",
	})
	var invalid_usage_type: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "task_progress",
		"task_id": "task-abc",
		"description": "Working",
		"usage": "not-a-dictionary",
		"uuid": "uuid-2",
		"session_id": "session-1",
	})
	var missing_summary: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "task_notification",
		"task_id": "task-abc",
		"status": "failed",
		"output_file": "/tmp/out.md",
		"uuid": "uuid-3",
		"session_id": "session-1",
	})

	assert_that(missing_task_id).is_null()
	assert_that(missing_usage).is_null()
	assert_that(invalid_usage_type).is_null()
	assert_that(missing_summary).is_null()


func test_parse_message_result_exposes_errors_for_malformed_known_messages() -> void:
	var invalid_input := ClaudeMessageParserScript.parse_message_result("not-a-dictionary")
	var missing_type := ClaudeMessageParserScript.parse_message_result({
		"message": {"content": []},
	})
	var missing_user_content := ClaudeMessageParserScript.parse_message_result({
		"type": "user",
		"message": {},
	})
	var missing_assistant_model := ClaudeMessageParserScript.parse_message_result({
		"type": "assistant",
		"message": {
			"content": [],
		},
	})
	var malformed_assistant_block := ClaudeMessageParserScript.parse_message_result({
		"type": "assistant",
		"message": {
			"model": "haiku",
			"content": [
				{"type": "tool_use", "name": "Read", "input": {"path": "README.md"}},
			],
		},
	})
	var missing_result_fields := ClaudeMessageParserScript.parse_message_result({
		"type": "result",
		"subtype": "success",
	})
	var missing_stream_event_fields := ClaudeMessageParserScript.parse_message_result({
		"type": "stream_event",
		"uuid": "stream-1",
	})
	var missing_system_subtype := ClaudeMessageParserScript.parse_message_result({
		"type": "system",
	})
	var missing_rate_limit_status := ClaudeMessageParserScript.parse_message_result({
		"type": "rate_limit_event",
		"rate_limit_info": {},
		"uuid": "rate-limit-1",
		"session_id": "session-1",
	})
	var unknown_type := ClaudeMessageParserScript.parse_message_result({
		"type": "future_sdk_event",
		"event": {},
	})

	assert_that(invalid_input.get("message", null)).is_null()
	assert_str(str(invalid_input.get("error", ""))).contains("Invalid message data type")
	assert_str(str(missing_type.get("error", ""))).contains("Message missing 'type' field")
	assert_str(str(missing_user_content.get("error", ""))).contains("Missing required field in user message: content")
	assert_str(str(missing_assistant_model.get("error", ""))).contains("Missing required field in assistant message: model")
	assert_str(str(malformed_assistant_block.get("error", ""))).contains("Missing required field in assistant message block: id")
	assert_str(str(missing_result_fields.get("error", ""))).contains("Missing required field in result message")
	assert_str(str(missing_stream_event_fields.get("error", ""))).contains("Missing required field in stream_event message")
	assert_str(str(missing_system_subtype.get("error", ""))).contains("Missing required field in system message: subtype")
	assert_str(str(missing_rate_limit_status.get("error", ""))).contains("rate_limit_info.status")
	assert_that(unknown_type.get("message", null)).is_null()
	assert_str(str(unknown_type.get("error", ""))).is_empty()


func test_parse_message_pushes_error_for_malformed_known_messages() -> void:
	assert_error(func() -> void:
		var message: Variant = ClaudeMessageParserScript.parse_message({
			"type": "assistant",
			"message": {
				"content": [],
			},
		})
		assert_that(message).is_null()
	).is_push_error("Missing required field in assistant message: model")


func test_parse_rate_limit_event_into_typed_message() -> void:
	var message: Variant = ClaudeMessageParserScript.parse_message({
		"type": "rate_limit_event",
		"rate_limit_info": {
			"status": "allowed_warning",
			"resetsAt": 1700000000,
			"rateLimitType": "five_hour",
			"utilization": 0.91,
		},
		"uuid": "abc-123",
		"session_id": "session_xyz",
	})

	assert_object(message).is_instanceof(ClaudeRateLimitEventScript)
	assert_str(message.uuid).is_equal("abc-123")
	assert_str(message.session_id).is_equal("session_xyz")
	assert_object(message.rate_limit_info).is_instanceof(ClaudeRateLimitInfoScript)
	assert_str(message.rate_limit_info.status).is_equal("allowed_warning")
	assert_that(message.rate_limit_info.resets_at).is_equal(1700000000)
	assert_that(message.rate_limit_info.rate_limit_type).is_equal("five_hour")
	assert_that(message.rate_limit_info.utilization).is_equal(0.91)
	assert_dict(message.rate_limit_info.raw_data).is_equal({
		"status": "allowed_warning",
		"resetsAt": 1700000000,
		"rateLimitType": "five_hour",
		"utilization": 0.91,
	})


func test_parse_rate_limit_event_preserves_optional_overage_fields() -> void:
	var message: Variant = ClaudeMessageParserScript.parse_message({
		"type": "rate_limit_event",
		"rate_limit_info": {
			"status": "rejected",
			"overageStatus": "rejected",
			"overageResetsAt": 1700000300,
			"overageDisabledReason": "budget_exhausted",
		},
		"uuid": "abc-456",
		"session_id": "session_overage",
	})

	assert_object(message).is_instanceof(ClaudeRateLimitEventScript)
	assert_that(message.rate_limit_info.overage_status).is_equal("rejected")
	assert_that(message.rate_limit_info.overage_resets_at).is_equal(1700000300)
	assert_that(message.rate_limit_info.overage_disabled_reason).is_equal("budget_exhausted")


func test_rate_limit_event_requires_expected_fields() -> void:
	var missing_info: Variant = ClaudeMessageParserScript.parse_message({
		"type": "rate_limit_event",
		"uuid": "abc-789",
		"session_id": "session_missing_info",
	})
	var invalid_info_type: Variant = ClaudeMessageParserScript.parse_message({
		"type": "rate_limit_event",
		"rate_limit_info": "not-a-dictionary",
		"uuid": "abc-789",
		"session_id": "session_invalid_info",
	})
	var missing_status: Variant = ClaudeMessageParserScript.parse_message({
		"type": "rate_limit_event",
		"rate_limit_info": {
			"resetsAt": 1700000000,
		},
		"uuid": "abc-789",
		"session_id": "session_missing_status",
	})
	var missing_uuid: Variant = ClaudeMessageParserScript.parse_message({
		"type": "rate_limit_event",
		"rate_limit_info": {
			"status": "allowed",
		},
		"session_id": "session_missing_uuid",
	})
	var missing_session_id: Variant = ClaudeMessageParserScript.parse_message({
		"type": "rate_limit_event",
		"rate_limit_info": {
			"status": "allowed",
		},
		"uuid": "abc-789",
	})

	assert_that(missing_info).is_null()
	assert_that(invalid_info_type).is_null()
	assert_that(missing_status).is_null()
	assert_that(missing_uuid).is_null()
	assert_that(missing_session_id).is_null()


func test_skip_unknown_top_level_message_types() -> void:
	var message: Variant = ClaudeMessageParserScript.parse_message({
		"type": "future_sdk_event",
		"event": {},
	})

	assert_that(message).is_null()
