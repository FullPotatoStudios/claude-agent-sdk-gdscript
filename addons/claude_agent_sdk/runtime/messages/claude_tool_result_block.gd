extends "res://addons/claude_agent_sdk/runtime/messages/claude_content_block.gd"
class_name ClaudeToolResultBlock

var tool_use_id: String = ""
var content: Variant = null
var is_error: bool = false


func _init(value_tool_use_id: String = "", value_content: Variant = null, value_is_error: bool = false, raw: Dictionary = {}) -> void:
	super._init("tool_result", raw)
	tool_use_id = value_tool_use_id
	content = value_content
	is_error = value_is_error
