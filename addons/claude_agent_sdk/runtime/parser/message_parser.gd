extends RefCounted
class_name ClaudeMessageParser


static func parse_message(data: Dictionary) -> Variant:
	var message_type := str(data.get("type", ""))
	match message_type:
		"user":
			return _parse_user_message(data)
		"assistant":
			return _parse_assistant_message(data)
		"system":
			return _parse_system_message(data)
		"result":
			return ClaudeResultMessage.new(
				str(data.get("subtype", "")),
				data,
				int(data.get("duration_ms", 0)),
				int(data.get("duration_api_ms", 0)),
				bool(data.get("is_error", false)),
				int(data.get("num_turns", 0)),
				str(data.get("session_id", "")),
				str(data.get("stop_reason", "")),
				float(data.get("total_cost_usd", 0.0)),
				data.get("usage", {}) if data.get("usage", {}) is Dictionary else {},
				str(data.get("result", "")),
				data.get("structured_output"),
				data.get("modelUsage", {}) if data.get("modelUsage", {}) is Dictionary else {},
				data.get("permission_denials", []) if data.get("permission_denials", []) is Array else [],
				data.get("errors", []) if data.get("errors", []) is Array else [],
				str(data.get("uuid", ""))
			)
		"stream_event":
			return ClaudeStreamEvent.new(
				data,
				str(data.get("session_id", "")),
				str(data.get("uuid", "")),
				data.get("event", {}) if data.get("event", {}) is Dictionary else {},
				str(data.get("parent_tool_use_id", ""))
			)
		_:
			return null


static func _parse_system_message(data: Dictionary) -> Variant:
	var subtype := str(data.get("subtype", ""))
	match subtype:
		"task_started":
			if not _require_system_fields(data, ["task_id", "description", "uuid", "session_id"]):
				return null
			return ClaudeTaskStartedMessage.new(
				data,
				str(data.get("task_id", "")),
				str(data.get("description", "")),
				str(data.get("uuid", "")),
				str(data.get("session_id", "")),
				str(data.get("tool_use_id", "")),
				str(data.get("task_type", ""))
			)
		"task_progress":
			if not _require_system_fields(data, ["task_id", "description", "uuid", "session_id", "usage"], ["usage"]):
				return null
			return ClaudeTaskProgressMessage.new(
				data,
				str(data.get("task_id", "")),
				str(data.get("description", "")),
				data.get("usage", {}) if data.get("usage", {}) is Dictionary else {},
				str(data.get("uuid", "")),
				str(data.get("session_id", "")),
				str(data.get("tool_use_id", "")),
				str(data.get("last_tool_name", ""))
			)
		"task_notification":
			if not _require_system_fields(data, ["task_id", "status", "output_file", "summary", "uuid", "session_id"]):
				return null
			return ClaudeTaskNotificationMessage.new(
				data,
				str(data.get("task_id", "")),
				str(data.get("status", "")),
				str(data.get("output_file", "")),
				str(data.get("summary", "")),
				str(data.get("uuid", "")),
				str(data.get("session_id", "")),
				str(data.get("tool_use_id", "")),
				data.get("usage", {}) if data.get("usage", {}) is Dictionary else {}
			)
		_:
			return ClaudeSystemMessage.new(subtype, data)


static func _require_system_fields(data: Dictionary, required_fields: Array[String], dictionary_fields: Array[String] = []) -> bool:
	for field_name in required_fields:
		if not data.has(field_name):
			push_error("Missing required field in system message: %s" % field_name)
			return false
		if dictionary_fields.has(field_name) and data[field_name] is not Dictionary:
			push_error("Invalid required dictionary field in system message: %s" % field_name)
			return false
	return true


static func _parse_user_message(data: Dictionary) -> ClaudeUserMessage:
	var message: Dictionary = data.get("message", {}) if data.get("message", {}) is Dictionary else {}
	var content: Variant = message.get("content")
	if content is Array:
		content = _parse_blocks(content as Array)
	return ClaudeUserMessage.new(
		content,
		data,
		str(data.get("uuid", "")),
		str(data.get("parent_tool_use_id", "")),
		data.get("tool_use_result")
	)


static func _parse_assistant_message(data: Dictionary) -> ClaudeAssistantMessage:
	var message: Dictionary = data.get("message", {}) if data.get("message", {}) is Dictionary else {}
	var content: Array = _parse_blocks(message.get("content", []) if message.get("content", []) is Array else [])
	return ClaudeAssistantMessage.new(
		content,
		str(message.get("model", "")),
		data,
		str(data.get("parent_tool_use_id", "")),
		str(data.get("error", "")),
		message.get("usage", {}) if message.get("usage", {}) is Dictionary else {},
		str(message.get("id", "")),
		str(message.get("stop_reason", "")),
		str(data.get("session_id", "")),
		str(data.get("uuid", ""))
	)


static func _parse_blocks(blocks: Array) -> Array:
	var parsed: Array = []
	for block_variant in blocks:
		if block_variant is not Dictionary:
			continue
		var block := block_variant as Dictionary
		var block_type := str(block.get("type", ""))
		match block_type:
			"text":
				parsed.append(ClaudeTextBlock.new(str(block.get("text", "")), block))
			"thinking":
				parsed.append(ClaudeThinkingBlock.new(str(block.get("thinking", "")), str(block.get("signature", "")), block))
			"tool_use":
				parsed.append(ClaudeToolUseBlock.new(
					str(block.get("id", "")),
					str(block.get("name", "")),
					block.get("input", {}) if block.get("input", {}) is Dictionary else {},
					block
				))
			"tool_result":
				parsed.append(ClaudeToolResultBlock.new(
					str(block.get("tool_use_id", "")),
					block.get("content"),
					bool(block.get("is_error", false)),
					block
				))
			_:
				continue
	return parsed
