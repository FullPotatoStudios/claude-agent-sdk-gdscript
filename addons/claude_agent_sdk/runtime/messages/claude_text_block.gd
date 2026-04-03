extends "res://addons/claude_agent_sdk/runtime/messages/claude_content_block.gd"
class_name ClaudeTextBlock

var text: String = ""


func _init(value: String = "", raw: Dictionary = {}) -> void:
	super._init("text", raw)
	text = value
