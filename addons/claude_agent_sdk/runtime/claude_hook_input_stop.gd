extends ClaudeHookInput
class_name ClaudeHookInputStop

var stop_hook_active: Variant = null


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "Stop"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "Stop"
	if config.has("stop_hook_active") or config.has("stopHookActive"):
		stop_hook_active = _get_first(config, ["stop_hook_active", "stopHookActive"])
	return self


func to_dict() -> Dictionary:
	var result := super.to_dict()
	if stop_hook_active != null:
		result["stop_hook_active"] = bool(stop_hook_active)
	return result
