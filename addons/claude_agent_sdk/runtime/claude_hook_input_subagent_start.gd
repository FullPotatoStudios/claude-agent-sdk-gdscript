extends ClaudeHookInput
class_name ClaudeHookInputSubagentStart

var agent_id: String = ""
var agent_type: String = ""


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "SubagentStart"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "SubagentStart"
	if config.has("agent_id") or config.has("agentId"):
		agent_id = str(_get_first(config, ["agent_id", "agentId"]))
	if config.has("agent_type") or config.has("agentType"):
		agent_type = str(_get_first(config, ["agent_type", "agentType"]))
	return self


func to_dict() -> Dictionary:
	var result := super.to_dict()
	if not agent_id.is_empty():
		result["agent_id"] = agent_id
	if not agent_type.is_empty():
		result["agent_type"] = agent_type
	return result
