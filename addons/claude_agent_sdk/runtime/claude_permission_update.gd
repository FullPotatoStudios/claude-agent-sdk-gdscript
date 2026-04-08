extends RefCounted
class_name ClaudePermissionUpdate

const ClaudePermissionRuleValueScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_rule_value.gd")

var type: String = ""
var rules: Array = []
var behavior: String = ""
var mode: String = ""
var directories: Array[String] = []
var destination: String = ""
var _rules_set: bool = false
var _directories_set: bool = false


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	if config.has("type"):
		type = str(config["type"])
	if config.has("_rules_set"):
		_rules_set = bool(config["_rules_set"])
	if config.has("rules") and config["rules"] is Array:
		_rules_set = true
		rules = ClaudePermissionRuleValueScript.coerce_rule_values(config["rules"] as Array)
	if config.has("behavior"):
		behavior = str(config["behavior"])
	if config.has("mode"):
		mode = str(config["mode"])
	if config.has("_directories_set"):
		_directories_set = bool(config["_directories_set"])
	if config.has("directories") and config["directories"] is Array:
		_directories_set = true
		directories = _to_string_array(config["directories"] as Array)
	if config.has("destination"):
		destination = str(config["destination"])
	return self


func duplicate_update() -> ClaudePermissionUpdate:
	return ClaudePermissionUpdate.new({
		"type": type,
		"rules": _duplicate_rules(rules),
		"behavior": behavior,
		"mode": mode,
		"directories": directories.duplicate(),
		"destination": destination,
		"_rules_set": _rules_set,
		"_directories_set": _directories_set,
	})


func to_dict() -> Dictionary:
	var result := {
		"type": type,
	}
	if not destination.is_empty():
		result["destination"] = destination
	if type in ["addRules", "replaceRules", "removeRules"]:
		if _rules_set:
			result["rules"] = _serialize_rules(rules)
		if not behavior.is_empty():
			result["behavior"] = behavior
	elif type == "setMode":
		if not mode.is_empty():
			result["mode"] = mode
	elif type in ["addDirectories", "removeDirectories"]:
		if _directories_set:
			result["directories"] = directories.duplicate()
	return result


static func coerce_updates(values: Array) -> Array:
	var normalized: Array = []
	for value in values:
		if value is ClaudePermissionUpdate:
			normalized.append((value as ClaudePermissionUpdate).duplicate_update())
		elif value is Dictionary:
			normalized.append(ClaudePermissionUpdate.new(value as Dictionary))
	return normalized


static func serialize_updates(values: Variant) -> Array:
	if values is not Array:
		return []
	var serialized: Array = []
	for value in values:
		if value is ClaudePermissionUpdate:
			serialized.append((value as ClaudePermissionUpdate).to_dict())
		elif value is Dictionary:
			serialized.append((value as Dictionary).duplicate(true))
	return serialized


static func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


static func _duplicate_rules(values: Array) -> Array:
	return ClaudePermissionRuleValueScript.coerce_rule_values(values)


static func _serialize_rules(values: Array) -> Array:
	var serialized_rules: Array = []
	for rule in values:
		serialized_rules.append((rule as ClaudePermissionRuleValue).to_dict())
	return serialized_rules
