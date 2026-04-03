extends RefCounted
class_name ClaudePermissionResultAllow

var behavior: String = "allow"
var updated_input: Variant = null
var updated_permissions: Variant = null


func _init(value_updated_input: Variant = null, value_updated_permissions: Variant = null) -> void:
	updated_input = value_updated_input
	updated_permissions = value_updated_permissions
