extends RefCounted
class_name ClaudeMcpServerToolAnnotations

var read_only: Variant = null
var destructive: Variant = null
var open_world: Variant = null
var raw_data: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	raw_data = config.duplicate(true)
	if config.has("read_only"):
		read_only = bool(config["read_only"])
	elif config.has("readOnly"):
		read_only = bool(config["readOnly"])
	if config.has("destructive"):
		destructive = bool(config["destructive"])
	if config.has("open_world"):
		open_world = bool(config["open_world"])
	elif config.has("openWorld"):
		open_world = bool(config["openWorld"])
	return self


func duplicate_annotations() -> ClaudeMcpServerToolAnnotations:
	return ClaudeMcpServerToolAnnotations.new(to_dict())


func to_dict() -> Dictionary:
	var serialized: Dictionary = {}
	if read_only != null:
		serialized["readOnly"] = bool(read_only)
	if destructive != null:
		serialized["destructive"] = bool(destructive)
	if open_world != null:
		serialized["openWorld"] = bool(open_world)
	return serialized


static func coerce(value: Variant):
	if value is ClaudeMcpServerToolAnnotations:
		return (value as ClaudeMcpServerToolAnnotations).duplicate_annotations()
	if value is Dictionary:
		return ClaudeMcpServerToolAnnotations.new(value as Dictionary)
	return null
