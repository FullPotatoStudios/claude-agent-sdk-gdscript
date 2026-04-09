extends RefCounted
class_name ClaudeContextUsageMemoryFile

var path := ""
var type := ""
var tokens := 0
var raw_data: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	raw_data = config.duplicate(true)
	if config.has("path"):
		path = str(config["path"])
	if config.has("type"):
		type = str(config["type"])
	if config.has("tokens"):
		tokens = int(config["tokens"])
	return self


func duplicate_memory_file() -> ClaudeContextUsageMemoryFile:
	return ClaudeContextUsageMemoryFile.new(to_dict())


func to_dict() -> Dictionary:
	return {
		"path": path,
		"type": type,
		"tokens": tokens,
	}


static func coerce(value: Variant):
	if value is ClaudeContextUsageMemoryFile:
		return (value as ClaudeContextUsageMemoryFile).duplicate_memory_file()
	if value is Dictionary:
		return ClaudeContextUsageMemoryFile.new(value as Dictionary)
	return null
