extends ClaudeHookSpecificOutput
class_name ClaudeHookOutputUserPromptSubmit


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "UserPromptSubmit"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "UserPromptSubmit"
	return self
