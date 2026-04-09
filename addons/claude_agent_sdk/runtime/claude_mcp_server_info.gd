extends RefCounted
class_name ClaudeMcpServerInfo

var name := ""
var version := ""
var raw_data: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	raw_data = config.duplicate(true)
	if config.has("name"):
		name = str(config["name"])
	if config.has("version"):
		version = str(config["version"])
	return self


func duplicate_server_info() -> ClaudeMcpServerInfo:
	return ClaudeMcpServerInfo.new(to_dict())


func to_dict() -> Dictionary:
	return {
		"name": name,
		"version": version,
	}


static func coerce(value: Variant):
	if value is ClaudeMcpServerInfo:
		return (value as ClaudeMcpServerInfo).duplicate_server_info()
	if value is Dictionary:
		return ClaudeMcpServerInfo.new(value as Dictionary)
	return null
