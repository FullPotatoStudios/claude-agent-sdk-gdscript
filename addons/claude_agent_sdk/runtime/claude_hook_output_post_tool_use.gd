extends ClaudeHookSpecificOutput
class_name ClaudeHookOutputPostToolUse

var updated_mcp_tool_output: Variant = null


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "PostToolUse"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "PostToolUse"
	if config.has("updated_mcp_tool_output") or config.has("updatedMCPToolOutput"):
		updated_mcp_tool_output = _get_first(config, ["updated_mcp_tool_output", "updatedMCPToolOutput"])
	return self


func to_dict() -> Dictionary:
	var result := super.to_dict()
	if updated_mcp_tool_output != null:
		result["updatedMCPToolOutput"] = updated_mcp_tool_output
	return result
