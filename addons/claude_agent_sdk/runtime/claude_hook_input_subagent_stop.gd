extends ClaudeHookInput
class_name ClaudeHookInputSubagentStop

var stop_hook_active: Variant = null
var agent_id: String = ""
var agent_transcript_path: String = ""
var agent_type: String = ""


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "SubagentStop"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "SubagentStop"
	if config.has("stop_hook_active") or config.has("stopHookActive"):
		stop_hook_active = _get_first(config, ["stop_hook_active", "stopHookActive"])
	if config.has("agent_id") or config.has("agentId"):
		agent_id = str(_get_first(config, ["agent_id", "agentId"]))
	if config.has("agent_transcript_path") or config.has("agentTranscriptPath"):
		agent_transcript_path = str(_get_first(config, ["agent_transcript_path", "agentTranscriptPath"]))
	if config.has("agent_type") or config.has("agentType"):
		agent_type = str(_get_first(config, ["agent_type", "agentType"]))
	return self


func to_dict() -> Dictionary:
	var result := super.to_dict()
	if stop_hook_active != null:
		result["stop_hook_active"] = bool(stop_hook_active)
	if not agent_id.is_empty():
		result["agent_id"] = agent_id
	if not agent_transcript_path.is_empty():
		result["agent_transcript_path"] = agent_transcript_path
	if not agent_type.is_empty():
		result["agent_type"] = agent_type
	return result
