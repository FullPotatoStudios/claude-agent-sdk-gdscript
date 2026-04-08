extends RefCounted
class_name ClaudeRateLimitInfo

var status: String = ""
var resets_at: Variant = null
var rate_limit_type: Variant = null
var utilization: Variant = null
var overage_status: Variant = null
var overage_resets_at: Variant = null
var overage_disabled_reason: Variant = null
var raw_data: Dictionary = {}


func _init(
	value_status: String = "",
	value_resets_at: Variant = null,
	value_rate_limit_type: Variant = null,
	value_utilization: Variant = null,
	value_overage_status: Variant = null,
	value_overage_resets_at: Variant = null,
	value_overage_disabled_reason: Variant = null,
	raw: Dictionary = {}
) -> void:
	status = value_status
	resets_at = value_resets_at
	rate_limit_type = value_rate_limit_type
	utilization = value_utilization
	overage_status = value_overage_status
	overage_resets_at = value_overage_resets_at
	overage_disabled_reason = value_overage_disabled_reason
	raw_data = raw.duplicate(true)
