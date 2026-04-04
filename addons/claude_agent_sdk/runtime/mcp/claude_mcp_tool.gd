extends RefCounted
class_name ClaudeMcpTool

var name := ""
var description := ""
var input_schema: Dictionary = {}
var handler: Callable = Callable()
var annotations: ClaudeMcpToolAnnotations = null


func _init(
	value_name: String = "",
	value_description: String = "",
	value_input_schema: Dictionary = {},
	value_handler: Callable = Callable(),
	value_annotations: ClaudeMcpToolAnnotations = null
) -> void:
	name = value_name
	description = value_description
	input_schema = value_input_schema.duplicate(true)
	handler = value_handler
	annotations = value_annotations
