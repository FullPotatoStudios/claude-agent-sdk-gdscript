extends ClaudeHookInput
class_name ClaudeHookInputPreCompact

var trigger: String = ""
var custom_instructions: Variant = null


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "PreCompact"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "PreCompact"
	if config.has("trigger"):
		trigger = str(config["trigger"])
	if config.has("custom_instructions") or config.has("customInstructions"):
		custom_instructions = _get_first(config, ["custom_instructions", "customInstructions"])
	return self


func to_dict() -> Dictionary:
	var result := super.to_dict()
	if not trigger.is_empty():
		result["trigger"] = trigger
	if custom_instructions != null:
		result["custom_instructions"] = custom_instructions
	return result
