extends RefCounted
class_name ClaudeHookOutput

var continue_after_hook: Variant = null
var suppress_output: Variant = null
var stop_reason: String = ""
var decision: String = ""
var system_message: String = ""
var reason: String = ""
var hook_specific_output: Variant = null
var defer_callback: bool = false
var async_timeout: Variant = null


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	if config.has("continue_after_hook") or config.has("continue") or config.has("continue_"):
		continue_after_hook = _get_first(config, ["continue_after_hook", "continue", "continue_"])
	if config.has("suppress_output") or config.has("suppressOutput"):
		suppress_output = _get_first(config, ["suppress_output", "suppressOutput"])
	if config.has("stop_reason") or config.has("stopReason"):
		stop_reason = str(_get_first(config, ["stop_reason", "stopReason"]))
	if config.has("decision"):
		decision = str(config["decision"])
	if config.has("system_message") or config.has("systemMessage"):
		system_message = str(_get_first(config, ["system_message", "systemMessage"]))
	if config.has("reason"):
		reason = str(config["reason"])
	if config.has("hook_specific_output") or config.has("hookSpecificOutput"):
		hook_specific_output = _get_first(config, ["hook_specific_output", "hookSpecificOutput"])
	if config.has("defer_callback") or config.has("async") or config.has("async_"):
		defer_callback = bool(_get_first(config, ["defer_callback", "async", "async_"]))
	if config.has("async_timeout") or config.has("asyncTimeout"):
		async_timeout = _get_first(config, ["async_timeout", "asyncTimeout"])
	return self


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	if continue_after_hook != null:
		result["continue"] = bool(continue_after_hook)
	if suppress_output != null:
		result["suppressOutput"] = bool(suppress_output)
	if not stop_reason.is_empty():
		result["stopReason"] = stop_reason
	if not decision.is_empty():
		result["decision"] = decision
	if not system_message.is_empty():
		result["systemMessage"] = system_message
	if not reason.is_empty():
		result["reason"] = reason
	var serialized_hook_output := _serialize_hook_specific_output(hook_specific_output)
	if serialized_hook_output != null:
		result["hookSpecificOutput"] = serialized_hook_output
	if defer_callback:
		result["async"] = true
		if async_timeout != null:
			result["asyncTimeout"] = async_timeout
	return result


static func _serialize_hook_specific_output(value: Variant) -> Variant:
	if value == null:
		return null
	if value is ClaudeHookSpecificOutput:
		return (value as ClaudeHookSpecificOutput).to_dict()
	if value is Dictionary:
		return _normalize_hook_specific_output_dictionary(value as Dictionary)
	return null


static func _get_first(config: Dictionary, keys: Array[String]) -> Variant:
	for key in keys:
		if config.has(key):
			return config[key]
	return null


static func _normalize_hook_specific_output_dictionary(value: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key_variant in value.keys():
		var key := str(key_variant)
		normalized[_normalize_hook_specific_output_key(key)] = value[key_variant]
	return normalized


static func _normalize_hook_specific_output_key(key: String) -> String:
	match key:
		"hook_event_name":
			return "hookEventName"
		"permission_decision":
			return "permissionDecision"
		"permission_decision_reason":
			return "permissionDecisionReason"
		"updated_input":
			return "updatedInput"
		"additional_context":
			return "additionalContext"
		"updated_mcp_tool_output":
			return "updatedMCPToolOutput"
		_:
			return key
