extends RefCounted
class_name ClaudeMcpStatusResponse

const ClaudeMcpServerStatusScript := preload("res://addons/claude_agent_sdk/runtime/claude_mcp_server_status.gd")

var mcp_servers: Array[ClaudeMcpServerStatus] = []
var raw_data: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	raw_data = config.duplicate(true)
	mcp_servers = _coerce_servers(config.get("mcpServers", config.get("mcp_servers", [])))
	return self


func is_empty() -> bool:
	return raw_data.is_empty() and mcp_servers.is_empty()


func duplicate_response() -> ClaudeMcpStatusResponse:
	return ClaudeMcpStatusResponse.new(to_dict())


func to_dict() -> Dictionary:
	return {
		"mcpServers": _serialize_servers(mcp_servers),
	}


static func coerce(value: Variant):
	if value is ClaudeMcpStatusResponse:
		return (value as ClaudeMcpStatusResponse).duplicate_response()
	if value is Dictionary:
		return ClaudeMcpStatusResponse.new(value as Dictionary)
	return null


static func _coerce_servers(values: Variant) -> Array[ClaudeMcpServerStatus]:
	var normalized: Array[ClaudeMcpServerStatus] = []
	if values is not Array:
		return normalized
	for value in values:
		var coerced = ClaudeMcpServerStatusScript.coerce(value)
		if coerced != null:
			normalized.append(coerced)
	return normalized


static func _serialize_servers(values: Array[ClaudeMcpServerStatus]) -> Array:
	var serialized: Array = []
	for value in values:
		serialized.append(value.to_dict())
	return serialized
