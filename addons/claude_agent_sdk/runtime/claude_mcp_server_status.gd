extends RefCounted
class_name ClaudeMcpServerStatus

const ClaudeMcpServerInfoScript := preload("res://addons/claude_agent_sdk/runtime/claude_mcp_server_info.gd")
const ClaudeMcpServerToolInfoScript := preload("res://addons/claude_agent_sdk/runtime/claude_mcp_server_tool_info.gd")

var name := ""
var status := ""
var server_info: ClaudeMcpServerInfo = null
var error_message := ""
var config: Dictionary = {}
var scope := ""
var tools: Array[ClaudeMcpServerToolInfo] = []
var raw_data: Dictionary = {}


func _init(config_data: Dictionary = {}) -> void:
	if not config_data.is_empty():
		apply(config_data)


func apply(config_data: Dictionary):
	raw_data = config_data.duplicate(true)
	if config_data.has("name"):
		name = str(config_data["name"])
	if config_data.has("status"):
		status = str(config_data["status"])
	server_info = ClaudeMcpServerInfoScript.coerce(
		config_data.get("serverInfo", config_data.get("server_info"))
	)
	if config_data.has("error_message"):
		error_message = str(config_data["error_message"])
	elif config_data.has("error"):
		error_message = str(config_data["error"])
	config = (config_data.get("config") as Dictionary).duplicate(true) if config_data.get("config") is Dictionary else {}
	if config_data.has("scope"):
		scope = str(config_data["scope"])
	tools = _coerce_tools(config_data.get("tools", []))
	return self


func duplicate_server_status() -> ClaudeMcpServerStatus:
	return ClaudeMcpServerStatus.new(to_dict())


func to_dict() -> Dictionary:
	var serialized := {
		"name": name,
		"status": status,
	}
	if server_info != null:
		serialized["serverInfo"] = server_info.to_dict()
	if not error_message.is_empty():
		serialized["error"] = error_message
	if not config.is_empty():
		serialized["config"] = config.duplicate(true)
	if not scope.is_empty():
		serialized["scope"] = scope
	if not tools.is_empty():
		serialized["tools"] = _serialize_tools(tools)
	return serialized


static func coerce(value: Variant):
	if value is ClaudeMcpServerStatus:
		return (value as ClaudeMcpServerStatus).duplicate_server_status()
	if value is Dictionary:
		return ClaudeMcpServerStatus.new(value as Dictionary)
	return null


static func _coerce_tools(values: Variant) -> Array[ClaudeMcpServerToolInfo]:
	var normalized: Array[ClaudeMcpServerToolInfo] = []
	if values is not Array:
		return normalized
	for value in values:
		var coerced = ClaudeMcpServerToolInfoScript.coerce(value)
		if coerced != null:
			normalized.append(coerced)
	return normalized


static func _serialize_tools(values: Array[ClaudeMcpServerToolInfo]) -> Array:
	var serialized: Array = []
	for value in values:
		serialized.append(value.to_dict())
	return serialized
