extends RefCounted
class_name ClaudeBuiltInToolCatalog

const _DEFAULT_PRESET := {
	"type": "preset",
	"preset": "claude_code",
}

const _TOOL_METADATA := {
	"Read": {"label": "Read", "description": "Read file contents", "group_id": "read"},
	"Glob": {"label": "Glob", "description": "Match files by pattern", "group_id": "read"},
	"Grep": {"label": "Grep", "description": "Search file contents", "group_id": "read"},
	"LS": {"label": "LS", "description": "List files and directories", "group_id": "read"},
	"NotebookRead": {"label": "NotebookRead", "description": "Read notebook cells", "group_id": "read"},
	"Write": {"label": "Write", "description": "Write files from scratch", "group_id": "write"},
	"Edit": {"label": "Edit", "description": "Edit existing files", "group_id": "write"},
	"MultiEdit": {"label": "MultiEdit", "description": "Apply coordinated edits", "group_id": "write"},
	"NotebookEdit": {"label": "NotebookEdit", "description": "Edit notebook cells", "group_id": "write"},
	"Bash": {"label": "Bash", "description": "Run shell commands", "group_id": "automation"},
	"Task": {"label": "Task", "description": "Delegate sub-tasks", "group_id": "automation"},
	"TodoWrite": {"label": "TodoWrite", "description": "Manage Claude task lists", "group_id": "automation"},
	"WebFetch": {"label": "WebFetch", "description": "Fetch web pages directly", "group_id": "web"},
	"WebSearch": {"label": "WebSearch", "description": "Search the web", "group_id": "web"},
}

const _GROUPS := [
	{
		"id": "read",
		"label": "Read & search",
		"description": "Inspect files and notebook content without editing.",
		"tools": ["Read", "Glob", "Grep", "LS", "NotebookRead"],
	},
	{
		"id": "write",
		"label": "Write & edit",
		"description": "Create or modify files and notebooks.",
		"tools": ["Write", "Edit", "MultiEdit", "NotebookEdit"],
	},
	{
		"id": "automation",
		"label": "Automation & tasks",
		"description": "Run shell commands, manage todos, and delegate tasks.",
		"tools": ["Bash", "Task", "TodoWrite"],
	},
	{
		"id": "web",
		"label": "Web",
		"description": "Search and fetch web content.",
		"tools": ["WebFetch", "WebSearch"],
	},
]


static func default_preset() -> Dictionary:
	return _DEFAULT_PRESET.duplicate(true)


static func list_default_tools() -> Array[String]:
	var results: Array[String] = []
	for group in _GROUPS:
		for tool_name_variant in (group.get("tools", []) as Array):
			results.append(str(tool_name_variant))
	return results


static func list_tool_metadata() -> Dictionary:
	return _TOOL_METADATA.duplicate(true)


static func list_groups() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for group in _GROUPS:
		groups.append((group as Dictionary).duplicate(true))
	return groups


static func selection_from_tools_config(tools_config: Variant) -> Array[String]:
	if tools_config == null:
		return list_default_tools()
	if tools_config is Dictionary:
		var tool_config := tools_config as Dictionary
		if str(tool_config.get("type", "")).strip_edges() == "preset":
			return list_default_tools()
		return list_default_tools()
	if tools_config is Array:
		return normalize_selection(_to_string_array(tools_config as Array))
	return list_default_tools()


static func tools_config_from_selection(selected_tool_names: Array[String]) -> Variant:
	var normalized := normalize_selection(selected_tool_names)
	if normalized.is_empty():
		return []
	if normalized == list_default_tools():
		return default_preset()
	return normalized


static func normalize_selection(tool_names: Array[String]) -> Array[String]:
	var known_lookup := {}
	for tool_name in list_default_tools():
		known_lookup[tool_name] = true

	var deduped_lookup := {}
	for tool_name in tool_names:
		if known_lookup.has(tool_name):
			deduped_lookup[tool_name] = true

	var ordered: Array[String] = []
	for tool_name in list_default_tools():
		if deduped_lookup.has(tool_name):
			ordered.append(tool_name)
	return ordered


static func is_known_tool(tool_name: String) -> bool:
	return _TOOL_METADATA.has(tool_name)


static func _to_string_array(values: Array) -> Array[String]:
	var results: Array[String] = []
	for value in values:
		results.append(str(value))
	return results
