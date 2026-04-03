extends "res://addons/claude_agent_sdk/runtime/messages/claude_content_block.gd"
class_name ClaudeToolUseBlock

var id: String = ""
var name: String = ""
var input: Dictionary = {}


func _init(tool_id: String = "", tool_name: String = "", tool_input: Dictionary = {}, raw: Dictionary = {}) -> void:
	super._init("tool_use", raw)
	id = tool_id
	name = tool_name
	input = tool_input.duplicate(true)
