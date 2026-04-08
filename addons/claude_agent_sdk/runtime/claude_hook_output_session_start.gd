extends ClaudeHookSpecificOutput
class_name ClaudeHookOutputSessionStart


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "SessionStart"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "SessionStart"
	return self
