extends RefCounted
class_name ClaudeContextUsageResponse

const ClaudeContextUsageCategoryScript := preload("res://addons/claude_agent_sdk/runtime/claude_context_usage_category.gd")
const ClaudeContextUsageMemoryFileScript := preload("res://addons/claude_agent_sdk/runtime/claude_context_usage_memory_file.gd")
const ClaudeContextUsageMcpToolScript := preload("res://addons/claude_agent_sdk/runtime/claude_context_usage_mcp_tool.gd")
const ClaudeContextUsageAgentScript := preload("res://addons/claude_agent_sdk/runtime/claude_context_usage_agent.gd")

var categories: Array[ClaudeContextUsageCategory] = []
var total_tokens := 0
var max_tokens := 0
var raw_max_tokens := 0
var percentage := 0.0
var model := ""
var is_auto_compact_enabled := false
var memory_files: Array[ClaudeContextUsageMemoryFile] = []
var mcp_tools: Array[ClaudeContextUsageMcpTool] = []
var agents: Array[ClaudeContextUsageAgent] = []
var grid_rows: Array = []
var auto_compact_threshold: Variant = null
var deferred_builtin_tools: Array = []
var system_tools: Array = []
var system_prompt_sections: Array = []
var slash_commands: Variant = null
var skills: Variant = null
var message_breakdown: Variant = null
var api_usage: Variant = null
var raw_data: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	raw_data = config.duplicate(true)
	categories = _coerce_categories(config.get("categories", []))
	if config.has("total_tokens"):
		total_tokens = int(config["total_tokens"])
	elif config.has("totalTokens"):
		total_tokens = int(config["totalTokens"])
	if config.has("max_tokens"):
		max_tokens = int(config["max_tokens"])
	elif config.has("maxTokens"):
		max_tokens = int(config["maxTokens"])
	if config.has("raw_max_tokens"):
		raw_max_tokens = int(config["raw_max_tokens"])
	elif config.has("rawMaxTokens"):
		raw_max_tokens = int(config["rawMaxTokens"])
	if config.has("percentage"):
		percentage = float(config["percentage"])
	if config.has("model"):
		model = str(config["model"])
	if config.has("is_auto_compact_enabled"):
		is_auto_compact_enabled = bool(config["is_auto_compact_enabled"])
	elif config.has("isAutoCompactEnabled"):
		is_auto_compact_enabled = bool(config["isAutoCompactEnabled"])
	memory_files = _coerce_memory_files(config.get("memoryFiles", config.get("memory_files", [])))
	mcp_tools = _coerce_mcp_tools(config.get("mcpTools", config.get("mcp_tools", [])))
	agents = _coerce_agents(config.get("agents", []))
	grid_rows = _duplicate_array(config.get("gridRows", config.get("grid_rows", [])))
	if config.has("auto_compact_threshold"):
		auto_compact_threshold = config.get("auto_compact_threshold")
	elif config.has("autoCompactThreshold"):
		auto_compact_threshold = config.get("autoCompactThreshold")
	deferred_builtin_tools = _duplicate_array(
		config.get("deferredBuiltinTools", config.get("deferred_builtin_tools", []))
	)
	system_tools = _duplicate_array(config.get("systemTools", config.get("system_tools", [])))
	system_prompt_sections = _duplicate_array(
		config.get("systemPromptSections", config.get("system_prompt_sections", []))
	)
	if config.has("slash_commands"):
		slash_commands = _duplicate_variant(config.get("slash_commands"))
	elif config.has("slashCommands"):
		slash_commands = _duplicate_variant(config.get("slashCommands"))
	if config.has("skills"):
		skills = _duplicate_variant(config.get("skills"))
	if config.has("message_breakdown"):
		message_breakdown = _duplicate_variant(config.get("message_breakdown"))
	elif config.has("messageBreakdown"):
		message_breakdown = _duplicate_variant(config.get("messageBreakdown"))
	if config.has("api_usage"):
		api_usage = _duplicate_variant(config.get("api_usage"))
	elif config.has("apiUsage"):
		api_usage = _duplicate_variant(config.get("apiUsage"))
	return self


func is_empty() -> bool:
	return raw_data.is_empty() \
		and categories.is_empty() \
		and total_tokens == 0 \
		and max_tokens == 0 \
		and raw_max_tokens == 0 \
		and percentage == 0.0 \
		and model.is_empty() \
		and memory_files.is_empty() \
		and mcp_tools.is_empty() \
		and agents.is_empty() \
		and grid_rows.is_empty()


func duplicate_response() -> ClaudeContextUsageResponse:
	return ClaudeContextUsageResponse.new(to_dict())


func to_dict() -> Dictionary:
	var serialized := {
		"categories": _serialize_categories(categories),
		"totalTokens": total_tokens,
		"maxTokens": max_tokens,
		"rawMaxTokens": raw_max_tokens,
		"percentage": percentage,
		"model": model,
		"isAutoCompactEnabled": is_auto_compact_enabled,
		"memoryFiles": _serialize_memory_files(memory_files),
		"mcpTools": _serialize_mcp_tools(mcp_tools),
		"agents": _serialize_agents(agents),
		"gridRows": _duplicate_array(grid_rows),
	}
	if auto_compact_threshold != null:
		serialized["autoCompactThreshold"] = auto_compact_threshold
	if not deferred_builtin_tools.is_empty():
		serialized["deferredBuiltinTools"] = _duplicate_array(deferred_builtin_tools)
	if not system_tools.is_empty():
		serialized["systemTools"] = _duplicate_array(system_tools)
	if not system_prompt_sections.is_empty():
		serialized["systemPromptSections"] = _duplicate_array(system_prompt_sections)
	if slash_commands != null:
		serialized["slashCommands"] = _duplicate_variant(slash_commands)
	if skills != null:
		serialized["skills"] = _duplicate_variant(skills)
	if message_breakdown != null:
		serialized["messageBreakdown"] = _duplicate_variant(message_breakdown)
	if api_usage != null:
		serialized["apiUsage"] = _duplicate_variant(api_usage)
	return serialized


static func coerce(value: Variant):
	if value is ClaudeContextUsageResponse:
		return (value as ClaudeContextUsageResponse).duplicate_response()
	if value is Dictionary:
		return ClaudeContextUsageResponse.new(value as Dictionary)
	return null


static func _coerce_categories(values: Variant) -> Array[ClaudeContextUsageCategory]:
	var normalized: Array[ClaudeContextUsageCategory] = []
	if values is not Array:
		return normalized
	for value in values:
		var coerced = ClaudeContextUsageCategoryScript.coerce(value)
		if coerced != null:
			normalized.append(coerced)
	return normalized


static func _coerce_memory_files(values: Variant) -> Array[ClaudeContextUsageMemoryFile]:
	var normalized: Array[ClaudeContextUsageMemoryFile] = []
	if values is not Array:
		return normalized
	for value in values:
		var coerced = ClaudeContextUsageMemoryFileScript.coerce(value)
		if coerced != null:
			normalized.append(coerced)
	return normalized


static func _coerce_mcp_tools(values: Variant) -> Array[ClaudeContextUsageMcpTool]:
	var normalized: Array[ClaudeContextUsageMcpTool] = []
	if values is not Array:
		return normalized
	for value in values:
		var coerced = ClaudeContextUsageMcpToolScript.coerce(value)
		if coerced != null:
			normalized.append(coerced)
	return normalized


static func _coerce_agents(values: Variant) -> Array[ClaudeContextUsageAgent]:
	var normalized: Array[ClaudeContextUsageAgent] = []
	if values is not Array:
		return normalized
	for value in values:
		var coerced = ClaudeContextUsageAgentScript.coerce(value)
		if coerced != null:
			normalized.append(coerced)
	return normalized


static func _serialize_categories(values: Array[ClaudeContextUsageCategory]) -> Array:
	var serialized: Array = []
	for value in values:
		serialized.append(value.to_dict())
	return serialized


static func _serialize_memory_files(values: Array[ClaudeContextUsageMemoryFile]) -> Array:
	var serialized: Array = []
	for value in values:
		serialized.append(value.to_dict())
	return serialized


static func _serialize_mcp_tools(values: Array[ClaudeContextUsageMcpTool]) -> Array:
	var serialized: Array = []
	for value in values:
		serialized.append(value.to_dict())
	return serialized


static func _serialize_agents(values: Array[ClaudeContextUsageAgent]) -> Array:
	var serialized: Array = []
	for value in values:
		serialized.append(value.to_dict())
	return serialized


static func _duplicate_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
