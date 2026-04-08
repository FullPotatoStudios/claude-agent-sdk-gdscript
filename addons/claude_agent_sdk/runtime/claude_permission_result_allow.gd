extends RefCounted
class_name ClaudePermissionResultAllow

const ClaudePermissionUpdateScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_update.gd")

var behavior: String = "allow"
var updated_input: Variant = null
var updated_permissions: Variant = null


func _init(value_updated_input: Variant = null, value_updated_permissions: Variant = null) -> void:
	updated_input = value_updated_input
	updated_permissions = value_updated_permissions


func to_dict(original_input: Dictionary) -> Dictionary:
	var response_payload := {
		"behavior": behavior,
		"updatedInput": updated_input if updated_input != null else original_input,
	}
	if updated_permissions is Array:
		response_payload["updatedPermissions"] = ClaudePermissionUpdateScript.serialize_updates(updated_permissions)
	return response_payload
