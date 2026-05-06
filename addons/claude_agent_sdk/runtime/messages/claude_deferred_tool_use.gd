extends RefCounted
class_name ClaudeDeferredToolUse

var id: String = ""
var name: String = ""
var input: Dictionary = {}


func _init(value_id: String = "", value_name: String = "", value_input: Dictionary = {}) -> void:
	id = value_id
	name = value_name
	input = value_input.duplicate(true)
