extends ClaudeHookSpecificOutput
class_name ClaudeHookOutputPostToolUseFailure


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "PostToolUseFailure"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "PostToolUseFailure"
	return self
