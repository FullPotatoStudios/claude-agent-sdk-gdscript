extends RefCounted
class_name ClaudeContextUsageMcpTool

var name := ""
var server_name := ""
var tokens := 0
var is_loaded := false
var raw_data: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	raw_data = config.duplicate(true)
	if config.has("name"):
		name = str(config["name"])
	if config.has("server_name"):
		server_name = str(config["server_name"])
	elif config.has("serverName"):
		server_name = str(config["serverName"])
	if config.has("tokens"):
		tokens = int(config["tokens"])
	if config.has("is_loaded"):
		is_loaded = bool(config["is_loaded"])
	elif config.has("isLoaded"):
		is_loaded = bool(config["isLoaded"])
	return self


func duplicate_mcp_tool() -> ClaudeContextUsageMcpTool:
	return ClaudeContextUsageMcpTool.new(to_dict())


func to_dict() -> Dictionary:
	return {
		"name": name,
		"serverName": server_name,
		"tokens": tokens,
		"isLoaded": is_loaded,
	}


static func coerce(value: Variant):
	if value is ClaudeContextUsageMcpTool:
		return (value as ClaudeContextUsageMcpTool).duplicate_mcp_tool()
	if value is Dictionary:
		return ClaudeContextUsageMcpTool.new(value as Dictionary)
	return null
