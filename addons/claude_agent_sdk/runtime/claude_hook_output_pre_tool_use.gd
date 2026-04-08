extends ClaudeHookSpecificOutput
class_name ClaudeHookOutputPreToolUse

var permission_decision: String = ""
var permission_decision_reason: String = ""
var updated_input: Variant = null


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "PreToolUse"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "PreToolUse"
	if config.has("permission_decision") or config.has("permissionDecision"):
		permission_decision = str(_get_first(config, ["permission_decision", "permissionDecision"]))
	if config.has("permission_decision_reason") or config.has("permissionDecisionReason"):
		permission_decision_reason = str(_get_first(config, ["permission_decision_reason", "permissionDecisionReason"]))
	if config.has("updated_input") or config.has("updatedInput"):
		updated_input = _get_first(config, ["updated_input", "updatedInput"])
	return self


func to_dict() -> Dictionary:
	var result := super.to_dict()
	if not permission_decision.is_empty():
		result["permissionDecision"] = permission_decision
	if not permission_decision_reason.is_empty():
		result["permissionDecisionReason"] = permission_decision_reason
	if updated_input != null:
		result["updatedInput"] = updated_input
	return result
