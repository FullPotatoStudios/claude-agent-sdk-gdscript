extends RefCounted
class_name ClaudeMcp

const ClaudeMcpToolScript := preload("res://addons/claude_agent_sdk/runtime/mcp/claude_mcp_tool.gd")
const ClaudeMcpToolAnnotationsScript := preload("res://addons/claude_agent_sdk/runtime/mcp/claude_mcp_tool_annotations.gd")
const ClaudeSdkMcpServerScript := preload("res://addons/claude_agent_sdk/runtime/mcp/claude_sdk_mcp_server.gd")

const SUPPORTED_SCALAR_TYPES := {
	"string": true,
	"integer": true,
	"number": true,
	"boolean": true,
}


static func tool(
	name: String,
	description: String,
	input_schema: Dictionary,
	handler: Callable,
	annotations: ClaudeMcpToolAnnotations = null
):
	var normalized_name := name.strip_edges()
	if normalized_name.is_empty():
		push_error("ClaudeMcp.tool requires a non-empty name")
		return null

	var normalized_description := description.strip_edges()
	if normalized_description.is_empty():
		push_error("ClaudeMcp.tool requires a non-empty description")
		return null

	if not handler.is_valid():
		push_error("ClaudeMcp.tool requires a valid handler Callable")
		return null

	var normalized_schema := _normalize_input_schema(input_schema)
	if normalized_schema.is_empty():
		push_error("ClaudeMcp.tool requires a non-empty object-shaped input_schema")
		return null

	return ClaudeMcpToolScript.new(
		normalized_name,
		normalized_description,
		normalized_schema,
		handler,
		annotations
	)


static func create_sdk_server(name: String, version := "1.0.0", tools := []) -> Dictionary:
	var normalized_name := name.strip_edges()
	if normalized_name.is_empty():
		push_error("ClaudeMcp.create_sdk_server requires a non-empty name")
		return {}

	var normalized_version := str(version).strip_edges()
	if normalized_version.is_empty():
		normalized_version = "1.0.0"

	return {
		"type": "sdk",
		"name": normalized_name,
		"instance": ClaudeSdkMcpServerScript.new(normalized_name, normalized_version, tools),
	}


static func schema_object(properties: Dictionary, required: Variant = PackedStringArray()) -> Dictionary:
	var schema := {
		"type": "object",
		"properties": properties.duplicate(true),
	}
	var required_names: Array[String] = []
	if required is PackedStringArray:
		for value in required:
			required_names.append(str(value))
	elif required is Array:
		for value in required:
			required_names.append(str(value))
	if not required_names.is_empty():
		schema["required"] = required_names
	return schema


static func schema_array(items: Dictionary, description := "") -> Dictionary:
	var schema := {
		"type": "array",
		"items": items.duplicate(true),
	}
	var normalized_description := str(description).strip_edges()
	if not normalized_description.is_empty():
		schema["description"] = normalized_description
	return schema


static func schema_scalar(type_name: String, description := "") -> Dictionary:
	var normalized_type := type_name.strip_edges()
	if not SUPPORTED_SCALAR_TYPES.has(normalized_type):
		push_error("Unsupported ClaudeMcp scalar type: %s" % normalized_type)
		return {}
	var schema := {
		"type": normalized_type,
	}
	var normalized_description := str(description).strip_edges()
	if not normalized_description.is_empty():
		schema["description"] = normalized_description
	return schema


static func schema_optional(inner: Dictionary) -> Dictionary:
	if inner.is_empty():
		push_error("ClaudeMcp.schema_optional requires a non-empty schema")
		return {}
	# Upstream optional tool parameters are represented by omitting the field
	# from the parent object's required list, not by accepting explicit null.
	return inner.duplicate(true)


static func _normalize_input_schema(value: Dictionary) -> Dictionary:
	if value.is_empty():
		return {}
	var normalized := value.duplicate(true)
	if not normalized.has("type") and normalized.has("properties"):
		normalized["type"] = "object"
	if str(normalized.get("type", "")) != "object":
		return {}
	return normalized
