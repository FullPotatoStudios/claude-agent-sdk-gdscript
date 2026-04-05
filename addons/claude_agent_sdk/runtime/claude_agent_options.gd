extends RefCounted
class_name ClaudeAgentOptions

const ClaudeHookMatcherScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_matcher.gd")

var model: String = ""
var effort: String = ""
var cwd: String = ""
var cli_path: String = "claude"
var env: Dictionary = {}
var system_prompt: Variant = ""
var tools: Variant = null
var allowed_tools: Array[String] = []
var disallowed_tools: Array[String] = []
var permission_mode: String = ""
var max_turns: int = 0
var resume: String = ""
var session_id: String = ""
var hooks: Dictionary = {}
var can_use_tool: Callable = Callable()
var include_partial_messages: bool = false
var output_format: Dictionary = {}
var mcp_servers: Variant = {}


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	if config.has("model"):
		model = str(config["model"])
	if config.has("effort"):
		effort = str(config["effort"])
	if config.has("cwd"):
		cwd = str(config["cwd"])
	if config.has("cli_path"):
		cli_path = str(config["cli_path"])
	if config.has("env") and config["env"] is Dictionary:
		env = (config["env"] as Dictionary).duplicate(true)
	if config.has("system_prompt"):
		system_prompt = _normalize_system_prompt(config["system_prompt"])
	if config.has("tools"):
		tools = _normalize_tools(config["tools"])
	if config.has("allowed_tools") and config["allowed_tools"] is Array:
		allowed_tools = _to_string_array(config["allowed_tools"] as Array)
	if config.has("disallowed_tools") and config["disallowed_tools"] is Array:
		disallowed_tools = _to_string_array(config["disallowed_tools"] as Array)
	if config.has("permission_mode"):
		permission_mode = str(config["permission_mode"])
	if config.has("max_turns"):
		max_turns = int(config["max_turns"])
	if config.has("resume"):
		resume = str(config["resume"])
	if config.has("session_id"):
		session_id = str(config["session_id"])
	if config.has("hooks") and config["hooks"] is Dictionary:
		hooks = _normalize_hooks(config["hooks"] as Dictionary)
	if config.has("can_use_tool") and config["can_use_tool"] is Callable:
		can_use_tool = config["can_use_tool"]
	if config.has("include_partial_messages"):
		include_partial_messages = bool(config["include_partial_messages"])
	if config.has("output_format") and config["output_format"] is Dictionary:
		output_format = (config["output_format"] as Dictionary).duplicate(true)
	if config.has("mcp_servers"):
		if config["mcp_servers"] is Dictionary:
			mcp_servers = _duplicate_nested_variant(config["mcp_servers"])
		elif config["mcp_servers"] is String:
			mcp_servers = str(config["mcp_servers"])
	return self


func duplicate_options():
	return ClaudeAgentOptions.new({
		"model": model,
		"effort": effort,
		"cwd": cwd,
		"cli_path": cli_path,
		"env": env.duplicate(true),
		"system_prompt": _duplicate_system_prompt(system_prompt),
		"tools": _duplicate_tools(tools),
		"allowed_tools": allowed_tools.duplicate(),
		"disallowed_tools": disallowed_tools.duplicate(),
			"permission_mode": permission_mode,
			"max_turns": max_turns,
			"resume": resume,
			"session_id": session_id,
			"hooks": _duplicate_hooks(hooks),
			"can_use_tool": can_use_tool,
			"include_partial_messages": include_partial_messages,
			"output_format": output_format.duplicate(true),
			"mcp_servers": _duplicate_mcp_servers(mcp_servers),
		})


func get_effective_session_id(default_session_id: String = "default") -> String:
	if not session_id.is_empty():
		return session_id
	return default_session_id


static func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


static func _normalize_hooks(value: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for event_variant in value.keys():
		var event_name := str(event_variant)
		var matchers: Array = value[event_variant] if value[event_variant] is Array else []
		var normalized_matchers: Array = []
		for matcher_variant in matchers:
			if matcher_variant is ClaudeHookMatcher:
				normalized_matchers.append((matcher_variant as ClaudeHookMatcher).duplicate_matcher())
			elif matcher_variant is Dictionary:
				normalized_matchers.append(ClaudeHookMatcherScript.new(matcher_variant))
		normalized[event_name] = normalized_matchers
	return normalized


static func _duplicate_hooks(value: Dictionary) -> Dictionary:
	return _normalize_hooks(value)


static func _normalize_system_prompt(value: Variant) -> Variant:
	if value == null:
		return ""
	if value is Dictionary:
		var source := value as Dictionary
		var duplicated: Dictionary = {}
		var prompt_type := str(source.get("type", "")).strip_edges()
		if prompt_type.is_empty():
			return ""
		duplicated["type"] = prompt_type
		match prompt_type:
			"preset":
				duplicated["preset"] = str(source.get("preset", "")).strip_edges()
				var append_value := str(source.get("append", ""))
				if not append_value.is_empty():
					duplicated["append"] = append_value
			"file":
				duplicated["path"] = str(source.get("path", "")).strip_edges()
			_:
				return ""
		return duplicated
	return str(value)


static func _normalize_tools(value: Variant) -> Variant:
	if value == null:
		return null
	if value is Array:
		return _to_string_array(value as Array)
	if value is Dictionary:
		var source := value as Dictionary
		var duplicated: Dictionary = {}
		var tools_type := str(source.get("type", "")).strip_edges()
		if tools_type.is_empty():
			return null
		duplicated["type"] = tools_type
		if tools_type == "preset":
			duplicated["preset"] = "claude_code"
			return duplicated
		return null
	return null


static func _duplicate_system_prompt(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is String:
		return str(value)
	return ""


static func _duplicate_tools(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate()
	return null


static func _duplicate_mcp_servers(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return _duplicate_nested_variant(value)
	if value is String:
		return str(value)
	return {}


static func _duplicate_nested_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var duplicated: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			duplicated[key_variant] = _duplicate_nested_variant((value as Dictionary)[key_variant])
		return duplicated
	if value is Array:
		var duplicated: Array = []
		for item in value:
			duplicated.append(_duplicate_nested_variant(item))
		return duplicated
	return value
