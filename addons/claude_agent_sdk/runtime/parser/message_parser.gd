extends RefCounted
class_name ClaudeMessageParser


static func parse_message(data: Variant) -> Variant:
	var result := parse_message_result(data)
	var parse_error := str(result.get("error", ""))
	if not parse_error.is_empty():
		push_error(parse_error)
	return result.get("message", null)


static func parse_message_result(data: Variant) -> Dictionary:
	if not (data is Dictionary):
		return _error_result(
			"Invalid message data type (expected Dictionary, got %s)" % type_string(typeof(data)),
			data
		)

	var payload := data as Dictionary
	var message_type := str(payload.get("type", ""))
	if message_type.is_empty():
		return _error_result("Message missing 'type' field", payload)

	match message_type:
		"user":
			return _parse_user_message(payload)
		"assistant":
			return _parse_assistant_message(payload)
		"system":
			return _parse_system_message(payload)
		"result":
			if not _require_fields(payload, ["subtype", "duration_ms", "duration_api_ms", "is_error", "num_turns", "session_id"], [], "result message"):
				return _error_result(_build_missing_fields_error(payload, "result message"), payload)
			return _message_result(ClaudeResultMessage.new(
				str(payload.get("subtype", "")),
				payload,
				int(payload.get("duration_ms", 0)),
				int(payload.get("duration_api_ms", 0)),
				bool(payload.get("is_error", false)),
				int(payload.get("num_turns", 0)),
				str(payload.get("session_id", "")),
				str(payload.get("stop_reason", "")),
				float(payload.get("total_cost_usd", 0.0)),
				payload.get("usage", {}) if payload.get("usage", {}) is Dictionary else {},
				str(payload.get("result", "")),
				payload.get("structured_output"),
				payload.get("modelUsage", {}) if payload.get("modelUsage", {}) is Dictionary else {},
				payload.get("permission_denials", []) if payload.get("permission_denials", []) is Array else [],
				payload.get("errors", []) if payload.get("errors", []) is Array else [],
				str(payload.get("uuid", ""))
			))
		"stream_event":
			if not _require_fields(payload, ["uuid", "session_id", "event"], [], "stream_event message"):
				return _error_result(_build_missing_fields_error(payload, "stream_event message"), payload)
			return _message_result(ClaudeStreamEvent.new(
				payload,
				str(payload.get("session_id", "")),
				str(payload.get("uuid", "")),
				payload.get("event"),
				str(payload.get("parent_tool_use_id", ""))
			))
		"rate_limit_event":
			return _parse_rate_limit_event(payload)
		_:
			return _empty_result()


static func _parse_system_message(data: Dictionary) -> Dictionary:
	var subtype := str(data.get("subtype", ""))
	if subtype.is_empty():
		return _error_result("Missing required field in system message: subtype", data)
	match subtype:
		"task_started":
			if not _require_system_fields(data, ["task_id", "description", "uuid", "session_id"]):
				return _error_result(_build_missing_fields_error(data, "system message"), data)
			return _message_result(ClaudeTaskStartedMessage.new(
				data,
				str(data.get("task_id", "")),
				str(data.get("description", "")),
				str(data.get("uuid", "")),
				str(data.get("session_id", "")),
				str(data.get("tool_use_id", "")),
				str(data.get("task_type", ""))
			))
		"task_progress":
			if not _require_system_fields(data, ["task_id", "description", "uuid", "session_id", "usage"], ["usage"]):
				return _error_result(_build_missing_fields_error(data, "system message"), data)
			return _message_result(ClaudeTaskProgressMessage.new(
				data,
				str(data.get("task_id", "")),
				str(data.get("description", "")),
				data.get("usage", {}) if data.get("usage", {}) is Dictionary else {},
				str(data.get("uuid", "")),
				str(data.get("session_id", "")),
				str(data.get("tool_use_id", "")),
				str(data.get("last_tool_name", ""))
			))
		"task_notification":
			if not _require_system_fields(data, ["task_id", "status", "output_file", "summary", "uuid", "session_id"]):
				return _error_result(_build_missing_fields_error(data, "system message"), data)
			return _message_result(ClaudeTaskNotificationMessage.new(
				data,
				str(data.get("task_id", "")),
				str(data.get("status", "")),
				str(data.get("output_file", "")),
				str(data.get("summary", "")),
				str(data.get("uuid", "")),
				str(data.get("session_id", "")),
				str(data.get("tool_use_id", "")),
				data.get("usage", {}) if data.get("usage", {}) is Dictionary else {}
			))
		_:
			return _message_result(ClaudeSystemMessage.new(subtype, data))


static func _require_system_fields(data: Dictionary, required_fields: Array[String], dictionary_fields: Array[String] = []) -> bool:
	return _require_fields(data, required_fields, dictionary_fields, "system message")


static func _require_fields(data: Dictionary, required_fields: Array[String], dictionary_fields: Array[String], context: String) -> bool:
	for field_name in required_fields:
		if not data.has(field_name):
			return false
		if dictionary_fields.has(field_name) and data[field_name] is not Dictionary:
			return false
	return true


static func _parse_rate_limit_event(data: Dictionary) -> Dictionary:
	if not _require_fields(data, ["rate_limit_info", "uuid", "session_id"], ["rate_limit_info"], "rate_limit_event message"):
		return _error_result(_build_missing_fields_error(data, "rate_limit_event message"), data)
	var info := data.get("rate_limit_info", {})
	if info is not Dictionary:
		return _error_result("Invalid required dictionary field in rate_limit_event message: rate_limit_info", data)
	var info_dict := info as Dictionary
	if not info_dict.has("status"):
		return _error_result("Missing required field in rate_limit_event message: rate_limit_info.status", data)
	return _message_result(ClaudeRateLimitEvent.new(
		data,
		ClaudeRateLimitInfo.new(
			str(info_dict.get("status", "")),
			_optional_int(info_dict, "resetsAt"),
			_optional_string(info_dict, "rateLimitType"),
			_optional_float(info_dict, "utilization"),
			_optional_string(info_dict, "overageStatus"),
			_optional_int(info_dict, "overageResetsAt"),
			_optional_string(info_dict, "overageDisabledReason"),
			info_dict
		),
		str(data.get("uuid", "")),
		str(data.get("session_id", ""))
	))


static func _optional_int(data: Dictionary, key: String) -> Variant:
	if not data.has(key):
		return null
	var value: Variant = data.get(key)
	if value is int or value is float:
		return int(value)
	return null


static func _optional_float(data: Dictionary, key: String) -> Variant:
	if not data.has(key):
		return null
	var value: Variant = data.get(key)
	if value is int or value is float:
		return float(value)
	return null


static func _optional_string(data: Dictionary, key: String) -> Variant:
	if not data.has(key):
		return null
	var value: Variant = data.get(key)
	if value == null:
		return null
	return str(value)


static func _parse_user_message(data: Dictionary) -> Dictionary:
	if not _has_nested_dictionary(data, "message"):
		return _error_result("Missing required field in user message: message", data)
	var message := data.get("message", {}) as Dictionary
	if not message.has("content"):
		return _error_result("Missing required field in user message: content", data)
	var content: Variant = message.get("content")
	if content is Array:
		var block_result := _parse_blocks_result(
			content as Array,
			data,
			"user message",
			["text", "tool_use", "tool_result"]
		)
		if not str(block_result.get("error", "")).is_empty():
			return block_result
		content = block_result.get("blocks", [])
	return _message_result(ClaudeUserMessage.new(
		content,
		data,
		str(data.get("uuid", "")),
		str(data.get("parent_tool_use_id", "")),
		data.get("tool_use_result")
	))


static func _parse_assistant_message(data: Dictionary) -> Dictionary:
	if not _has_nested_dictionary(data, "message"):
		return _error_result("Missing required field in assistant message: message", data)
	var message := data.get("message", {}) as Dictionary
	if not message.has("content"):
		return _error_result("Missing required field in assistant message: content", data)
	if not message.has("model"):
		return _error_result("Missing required field in assistant message: model", data)
	if not (message.get("content") is Array):
		return _error_result("Invalid required array field in assistant message: content", data)
	var block_result := _parse_blocks_result(
		message.get("content", []) if message.get("content", []) is Array else [],
		data,
		"assistant message",
		["text", "thinking", "tool_use", "tool_result"]
	)
	if not str(block_result.get("error", "")).is_empty():
		return block_result
	var content: Array = block_result.get("blocks", []) if block_result.get("blocks", []) is Array else []
	return _message_result(ClaudeAssistantMessage.new(
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
	))


static func _parse_blocks_result(
	blocks: Array,
	raw_data: Dictionary,
	context: String,
	validated_types: Array[String]
) -> Dictionary:
	var parsed: Array = []
	for block_variant in blocks:
		if block_variant is not Dictionary:
			continue
		var block := block_variant as Dictionary
		if not block.has("type"):
			return _error_result("Missing required field in %s block: type" % context, raw_data)
		var block_type := str(block.get("type", ""))
		if not validated_types.has(block_type):
			continue
		match block_type:
			"text":
				if not block.has("text"):
					return _error_result("Missing required field in %s block: text" % context, raw_data)
				parsed.append(ClaudeTextBlock.new(str(block.get("text", "")), block))
			"thinking":
				if not block.has("thinking"):
					return _error_result("Missing required field in %s block: thinking" % context, raw_data)
				if not block.has("signature"):
					return _error_result("Missing required field in %s block: signature" % context, raw_data)
				parsed.append(ClaudeThinkingBlock.new(str(block.get("thinking", "")), str(block.get("signature", "")), block))
			"tool_use":
				if not block.has("id"):
					return _error_result("Missing required field in %s block: id" % context, raw_data)
				if not block.has("name"):
					return _error_result("Missing required field in %s block: name" % context, raw_data)
				if not block.has("input"):
					return _error_result("Missing required field in %s block: input" % context, raw_data)
				parsed.append(ClaudeToolUseBlock.new(
					str(block.get("id", "")),
					str(block.get("name", "")),
					block.get("input", {}) if block.get("input", {}) is Dictionary else {},
					block
				))
			"tool_result":
				if not block.has("tool_use_id"):
					return _error_result("Missing required field in %s block: tool_use_id" % context, raw_data)
				parsed.append(ClaudeToolResultBlock.new(
					str(block.get("tool_use_id", "")),
					block.get("content"),
					bool(block.get("is_error", false)),
					block
				))
			_:
				continue
	return {
		"blocks": parsed,
		"error": "",
	}


static func _message_result(message: Variant) -> Dictionary:
	return {
		"message": message,
		"error": "",
	}


static func _error_result(message: String, _data: Variant = null) -> Dictionary:
	return {
		"message": null,
		"error": message,
	}


static func _empty_result() -> Dictionary:
	return {
		"message": null,
		"error": "",
	}


static func _has_nested_dictionary(data: Dictionary, field_name: String) -> bool:
	return data.has(field_name) and data[field_name] is Dictionary


static func _build_missing_fields_error(data: Dictionary, context: String) -> String:
	if context == "rate_limit_event message":
		if not data.has("rate_limit_info"):
			return "Missing required field in %s: rate_limit_info" % context
		if data.has("rate_limit_info") and not (data.get("rate_limit_info") is Dictionary):
			return "Invalid required dictionary field in %s: rate_limit_info" % context
		if not data.has("uuid"):
			return "Missing required field in %s: uuid" % context
		if not data.has("session_id"):
			return "Missing required field in %s: session_id" % context
		return "Missing required field in %s: rate_limit_info.status" % context
	if context == "system message":
		if not data.has("task_id"):
			return "Missing required field in %s: task_id" % context
		if not data.has("description") and str(data.get("subtype", "")) != "task_notification":
			return "Missing required field in %s: description" % context
		if not data.has("status") and str(data.get("subtype", "")) == "task_notification":
			return "Missing required field in %s: status" % context
		if not data.has("output_file") and str(data.get("subtype", "")) == "task_notification":
			return "Missing required field in %s: output_file" % context
		if not data.has("summary") and str(data.get("subtype", "")) == "task_notification":
			return "Missing required field in %s: summary" % context
		if not data.has("usage") and str(data.get("subtype", "")) == "task_progress":
			return "Missing required field in %s: usage" % context
		if data.has("usage") and not (data.get("usage") is Dictionary) and str(data.get("subtype", "")) == "task_progress":
			return "Invalid required dictionary field in %s: usage" % context
		if not data.has("uuid"):
			return "Missing required field in %s: uuid" % context
		if not data.has("session_id"):
			return "Missing required field in %s: session_id" % context
		return "Missing required field in %s" % context
	if context == "result message":
		for field_name in ["subtype", "duration_ms", "duration_api_ms", "is_error", "num_turns", "session_id"]:
			if not data.has(field_name):
				return "Missing required field in %s: %s" % [context, field_name]
		return "Missing required field in %s" % context
	if context == "stream_event message":
		for field_name in ["uuid", "session_id", "event"]:
			if not data.has(field_name):
				return "Missing required field in %s: %s" % [context, field_name]
		return "Missing required field in %s" % context
	return "Missing required field in %s" % context
