extends RefCounted
class_name ClaudeSdkMcpServer

var name := ""
var version := "1.0.0"
var tools: Array[ClaudeMcpTool] = []
var _tool_definitions: Array[Dictionary] = []
var _tools_by_name: Dictionary = {}


func _init(value_name: String = "", value_version: String = "1.0.0", value_tools: Array = []) -> void:
	name = value_name
	version = value_version if not value_version.is_empty() else "1.0.0"
	for tool_variant in value_tools:
		if tool_variant is ClaudeMcpTool:
			var tool := tool_variant as ClaudeMcpTool
			tools.append(tool)
			_tools_by_name[tool.name] = tool
			var definition := {
				"name": tool.name,
				"description": tool.description,
				"inputSchema": tool.input_schema.duplicate(true),
			}
			if tool.annotations != null:
				var annotations := tool.annotations.to_mcp_dictionary()
				if not annotations.is_empty():
					definition["annotations"] = annotations
			_tool_definitions.append(definition)


func list_tools() -> Array[Dictionary]:
	var duplicated: Array[Dictionary] = []
	for definition in _tool_definitions:
		duplicated.append(definition.duplicate(true))
	return duplicated


func get_tool(tool_name: String):
	return _tools_by_name.get(tool_name, null)
