extends ClaudeHookSpecificOutput
class_name ClaudeHookOutputSubagentStart


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "SubagentStart"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "SubagentStart"
	return self
