extends RefCounted
class_name ClaudeHookSpecificOutput

var hook_event_name: String = ""
var additional_context: String = ""


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	if config.has("hook_event_name") or config.has("hookEventName"):
		hook_event_name = str(_get_first(config, ["hook_event_name", "hookEventName"]))
	if config.has("additional_context") or config.has("additionalContext"):
		additional_context = str(_get_first(config, ["additional_context", "additionalContext"]))
	return self


func to_dict() -> Dictionary:
	var result := {
		"hookEventName": hook_event_name,
	}
	if not additional_context.is_empty():
		result["additionalContext"] = additional_context
	return result


static func _get_first(config: Dictionary, keys: Array[String]) -> Variant:
	for key in keys:
		if config.has(key):
			return config[key]
	return null
