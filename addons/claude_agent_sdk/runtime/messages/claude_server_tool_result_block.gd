extends "res://addons/claude_agent_sdk/runtime/messages/claude_content_block.gd"
class_name ClaudeServerToolResultBlock

var tool_use_id: String = ""
var content: Variant = null


func _init(value_tool_use_id: String = "", value_content: Variant = null, raw: Dictionary = {}) -> void:
	super._init("advisor_tool_result", raw)
	tool_use_id = value_tool_use_id
	content = value_content
