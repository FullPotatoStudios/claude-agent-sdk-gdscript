extends RefCounted
class_name ClaudeSDKMessage

var message_type: String = ""
var raw_data: Dictionary = {}


func _init(type_name: String = "", raw: Dictionary = {}) -> void:
	message_type = type_name
	raw_data = raw.duplicate(true)
