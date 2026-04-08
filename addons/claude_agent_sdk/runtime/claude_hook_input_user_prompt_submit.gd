extends ClaudeHookInput
class_name ClaudeHookInputUserPromptSubmit

var prompt: String = ""


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "UserPromptSubmit"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "UserPromptSubmit"
	if config.has("prompt"):
		prompt = str(config["prompt"])
	return self


func to_dict() -> Dictionary:
	var result := super.to_dict()
	if not prompt.is_empty():
		result["prompt"] = prompt
	return result
