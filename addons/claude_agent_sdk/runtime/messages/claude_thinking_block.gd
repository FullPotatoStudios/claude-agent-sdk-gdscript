extends "res://addons/claude_agent_sdk/runtime/messages/claude_content_block.gd"
class_name ClaudeThinkingBlock

var thinking: String = ""
var signature: String = ""


func _init(value: String = "", value_signature: String = "", raw: Dictionary = {}) -> void:
	super._init("thinking", raw)
	thinking = value
	signature = value_signature
