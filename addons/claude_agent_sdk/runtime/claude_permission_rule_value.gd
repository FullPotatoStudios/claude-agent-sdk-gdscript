extends RefCounted
class_name ClaudePermissionRuleValue

var tool_name: String = ""
var rule_content: Variant = null


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	if config.has("tool_name") or config.has("toolName"):
		tool_name = str(_get_first(config, ["tool_name", "toolName"]))
	if config.has("rule_content") or config.has("ruleContent"):
		rule_content = _get_first(config, ["rule_content", "ruleContent"])
	return self


func duplicate_rule_value() -> ClaudePermissionRuleValue:
	return ClaudePermissionRuleValue.new({
		"tool_name": tool_name,
		"rule_content": rule_content,
	})


func to_dict() -> Dictionary:
	return {
		"toolName": tool_name,
		"ruleContent": rule_content,
	}


static func coerce_rule_values(values: Array) -> Array:
	var normalized: Array = []
	for value in values:
		if value is ClaudePermissionRuleValue:
			normalized.append((value as ClaudePermissionRuleValue).duplicate_rule_value())
		elif value is Dictionary:
			normalized.append(ClaudePermissionRuleValue.new(value as Dictionary))
	return normalized


static func _get_first(config: Dictionary, keys: Array[String]) -> Variant:
	for key in keys:
		if config.has(key):
			return config[key]
	return null
