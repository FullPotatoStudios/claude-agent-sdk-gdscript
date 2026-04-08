extends RefCounted
class_name ClaudeHookInput

var session_id: String = ""
var transcript_path: String = ""
var cwd: String = ""
var hook_event_name: String = ""
var permission_mode: Variant = null


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	if config.has("session_id") or config.has("sessionId"):
		session_id = str(_get_first(config, ["session_id", "sessionId"]))
	if config.has("transcript_path") or config.has("transcriptPath"):
		transcript_path = str(_get_first(config, ["transcript_path", "transcriptPath"]))
	if config.has("cwd"):
		cwd = str(config["cwd"])
	if config.has("hook_event_name") or config.has("hookEventName"):
		hook_event_name = str(_get_first(config, ["hook_event_name", "hookEventName"]))
	if config.has("permission_mode") or config.has("permissionMode"):
		permission_mode = _get_first(config, ["permission_mode", "permissionMode"])
	return self


func duplicate_input():
	return ClaudeHookInput.coerce_input(to_dict())


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	if not session_id.is_empty():
		result["session_id"] = session_id
	if not transcript_path.is_empty():
		result["transcript_path"] = transcript_path
	if not cwd.is_empty():
		result["cwd"] = cwd
	if not hook_event_name.is_empty():
		result["hook_event_name"] = hook_event_name
	if permission_mode != null:
		result["permission_mode"] = permission_mode
	return result


static func coerce_input(value: Variant, tool_use_id: Variant = null):
	if value is ClaudeHookInput:
		return (value as ClaudeHookInput).duplicate_input()
	if value is not Dictionary:
		return null
	var normalized := _normalize_input_dictionary(value as Dictionary, tool_use_id)
	var event_name := str(_get_first(normalized, ["hook_event_name", "hookEventName"]))
	var script_path := ""
	match event_name:
		"PreToolUse":
			script_path = "res://addons/claude_agent_sdk/runtime/claude_hook_input_pre_tool_use.gd"
		"PostToolUse":
			script_path = "res://addons/claude_agent_sdk/runtime/claude_hook_input_post_tool_use.gd"
		"PostToolUseFailure":
			script_path = "res://addons/claude_agent_sdk/runtime/claude_hook_input_post_tool_use_failure.gd"
		"UserPromptSubmit":
			script_path = "res://addons/claude_agent_sdk/runtime/claude_hook_input_user_prompt_submit.gd"
		"Stop":
			script_path = "res://addons/claude_agent_sdk/runtime/claude_hook_input_stop.gd"
		"SubagentStop":
			script_path = "res://addons/claude_agent_sdk/runtime/claude_hook_input_subagent_stop.gd"
		"PreCompact":
			script_path = "res://addons/claude_agent_sdk/runtime/claude_hook_input_pre_compact.gd"
		"Notification":
			script_path = "res://addons/claude_agent_sdk/runtime/claude_hook_input_notification.gd"
		"SubagentStart":
			script_path = "res://addons/claude_agent_sdk/runtime/claude_hook_input_subagent_start.gd"
		"PermissionRequest":
			script_path = "res://addons/claude_agent_sdk/runtime/claude_hook_input_permission_request.gd"
	if script_path.is_empty():
		return ClaudeHookInput.new(normalized)
	var script = load(script_path)
	if script == null:
		return ClaudeHookInput.new(normalized)
	return script.new(normalized)


static func _normalize_input_dictionary(value: Dictionary, tool_use_id: Variant = null) -> Dictionary:
	var normalized := _duplicate_variant(value) as Dictionary
	var event_name := str(_get_first(normalized, ["hook_event_name", "hookEventName"]))
	if event_name in ["PreToolUse", "PostToolUse", "PostToolUseFailure"] and tool_use_id != null:
		if not normalized.has("tool_use_id") and not normalized.has("toolUseId"):
			normalized["tool_use_id"] = tool_use_id
	return normalized


static func _get_first(config: Dictionary, keys: Array[String]) -> Variant:
	for key in keys:
		if config.has(key):
			return config[key]
	return null


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var duplicated: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			duplicated[key_variant] = _duplicate_variant((value as Dictionary)[key_variant])
		return duplicated
	if value is Array:
		var duplicated_array: Array = []
		for item in value as Array:
			duplicated_array.append(_duplicate_variant(item))
		return duplicated_array
	return value
