extends "res://addons/claude_agent_sdk/runtime/messages/claude_sdk_message.gd"
class_name ClaudeSystemMessage

var subtype: String = ""


func _init(value_subtype: String = "", raw: Dictionary = {}) -> void:
	super._init("system", raw)
	subtype = value_subtype
