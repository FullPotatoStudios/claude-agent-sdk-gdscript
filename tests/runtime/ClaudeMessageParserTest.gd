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


func test_skip_unknown_top_level_message_types() -> void:
	var message: Variant = ClaudeMessageParserScript.parse_message({
		"type": "rate_limit_event",
		"event": {},
	})

	assert_that(message).is_null()
