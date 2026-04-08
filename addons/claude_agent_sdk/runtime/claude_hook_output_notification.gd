extends ClaudeHookSpecificOutput
class_name ClaudeHookOutputNotification


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "Notification"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "Notification"
	return self
