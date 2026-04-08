extends ClaudeHookInput
class_name ClaudeHookInputPreToolUse

var tool_name: String = ""
var tool_input: Dictionary = {}
var tool_use_id: Variant = null
var agent_id: Variant = null
var agent_type: Variant = null


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "PreToolUse"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "PreToolUse"
	if config.has("tool_name") or config.has("toolName"):
		tool_name = str(_get_first(config, ["tool_name", "toolName"]))
	if config.has("tool_input") or config.has("toolInput"):
		var value = _get_first(config, ["tool_input", "toolInput"])
		tool_input = ClaudeHookInput._duplicate_variant(value) if value is Dictionary else {}
	if config.has("tool_use_id") or config.has("toolUseId"):
		tool_use_id = _get_first(config, ["tool_use_id", "toolUseId"])
	if config.has("agent_id") or config.has("agentId"):
		agent_id = _get_first(config, ["agent_id", "agentId"])
	if config.has("agent_type") or config.has("agentType"):
		agent_type = _get_first(config, ["agent_type", "agentType"])
	return self


func to_dict() -> Dictionary:
	var result := super.to_dict()
	if not tool_name.is_empty():
		result["tool_name"] = tool_name
	result["tool_input"] = ClaudeHookInput._duplicate_variant(tool_input)
	if tool_use_id != null:
		result["tool_use_id"] = tool_use_id
	if agent_id != null:
		result["agent_id"] = agent_id
	if agent_type != null:
		result["agent_type"] = agent_type
	return result
