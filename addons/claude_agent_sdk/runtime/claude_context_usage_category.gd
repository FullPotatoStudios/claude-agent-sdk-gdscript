extends RefCounted
class_name ClaudeContextUsageCategory

var name := ""
var tokens := 0
var color := ""
var is_deferred: Variant = null
var raw_data: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	raw_data = config.duplicate(true)
	if config.has("name"):
		name = str(config["name"])
	if config.has("tokens"):
		tokens = int(config["tokens"])
	if config.has("color"):
		color = str(config["color"])
	if config.has("is_deferred"):
		is_deferred = bool(config["is_deferred"])
	elif config.has("isDeferred"):
		is_deferred = bool(config["isDeferred"])
	return self


func duplicate_category() -> ClaudeContextUsageCategory:
	return ClaudeContextUsageCategory.new(to_dict())


func to_dict() -> Dictionary:
	var serialized := {
		"name": name,
		"tokens": tokens,
		"color": color,
	}
	if is_deferred != null:
		serialized["isDeferred"] = bool(is_deferred)
	return serialized


static func coerce(value: Variant):
	if value is ClaudeContextUsageCategory:
		return (value as ClaudeContextUsageCategory).duplicate_category()
	if value is Dictionary:
		return ClaudeContextUsageCategory.new(value as Dictionary)
	return null
