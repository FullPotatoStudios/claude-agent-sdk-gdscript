extends RefCounted
class_name ClaudeMcpServerToolInfo

const ClaudeMcpServerToolAnnotationsScript := preload("res://addons/claude_agent_sdk/runtime/claude_mcp_server_tool_annotations.gd")

var name := ""
var description := ""
var annotations: ClaudeMcpServerToolAnnotations = null
var raw_data: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	raw_data = config.duplicate(true)
	if config.has("name"):
		name = str(config["name"])
	if config.has("description"):
		description = str(config["description"])
	annotations = ClaudeMcpServerToolAnnotationsScript.coerce(config.get("annotations"))
	return self


func duplicate_tool_info() -> ClaudeMcpServerToolInfo:
	return ClaudeMcpServerToolInfo.new(to_dict())


func to_dict() -> Dictionary:
	var serialized := {
		"name": name,
	}
	if not description.is_empty():
		serialized["description"] = description
	if annotations != null:
		var annotation_dict := annotations.to_dict()
		if not annotation_dict.is_empty():
			serialized["annotations"] = annotation_dict
	return serialized


static func coerce(value: Variant):
	if value is ClaudeMcpServerToolInfo:
		return (value as ClaudeMcpServerToolInfo).duplicate_tool_info()
	if value is Dictionary:
		return ClaudeMcpServerToolInfo.new(value as Dictionary)
	return null
