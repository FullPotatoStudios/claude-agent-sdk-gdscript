extends RefCounted
class_name ClaudeContentBlock

var block_type: String = ""
var raw_data: Dictionary = {}


func _init(type_name: String = "", raw: Dictionary = {}) -> void:
	block_type = type_name
	raw_data = raw.duplicate(true)
