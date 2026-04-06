extends "res://addons/claude_agent_sdk/runtime/messages/claude_sdk_message.gd"
class_name ClaudeUserMessage

var content: Variant = null
var uuid: String = ""
var parent_tool_use_id: String = ""
var tool_use_result: Variant = null


func _init(value_content: Variant = null, raw: Dictionary = {}, value_uuid: String = "", value_parent_tool_use_id: String = "", value_tool_use_result: Variant = null) -> void:
	super._init("user", raw)
	content = value_content
	uuid = value_uuid
	parent_tool_use_id = value_parent_tool_use_id
	tool_use_result = value_tool_use_result.duplicate(true) if value_tool_use_result is Dictionary or value_tool_use_result is Array else value_tool_use_result
