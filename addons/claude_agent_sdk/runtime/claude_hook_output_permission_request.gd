extends ClaudeHookSpecificOutput
class_name ClaudeHookOutputPermissionRequest

var decision: Variant = null


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "PermissionRequest"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "PermissionRequest"
	if config.has("decision"):
		decision = config["decision"]
	return self


func to_dict() -> Dictionary:
	var result := super.to_dict()
	if decision != null:
		result["decision"] = decision
	return result
