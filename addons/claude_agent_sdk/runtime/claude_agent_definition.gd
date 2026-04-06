extends RefCounted
class_name ClaudeAgentDefinition

var description: String = ""
var prompt: String = ""
var tools: Variant = null
var disallowed_tools: Variant = null
var model: String = ""
var skills: Variant = null
var memory: String = ""
var mcp_servers: Variant = null
var initial_prompt: String = ""
var max_turns: Variant = null
var background: Variant = null
var effort: Variant = null
var permission_mode: String = ""


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	if config.has("description"):
		description = str(config["description"])
	if config.has("prompt"):
		prompt = str(config["prompt"])
	if config.has("tools"):
		tools = _normalize_string_array_variant(config["tools"])
	if config.has("disallowed_tools") or config.has("disallowedTools"):
		disallowed_tools = _normalize_string_array_variant(_get_first(config, ["disallowed_tools", "disallowedTools"]))
	if config.has("model"):
		model = str(config["model"])
	if config.has("skills"):
		skills = _normalize_string_array_variant(config["skills"])
	if config.has("memory"):
		memory = str(config["memory"])
	if config.has("mcp_servers") or config.has("mcpServers"):
		mcp_servers = _normalize_array_variant(_get_first(config, ["mcp_servers", "mcpServers"]))
	if config.has("initial_prompt") or config.has("initialPrompt"):
		initial_prompt = str(_get_first(config, ["initial_prompt", "initialPrompt"]))
	if config.has("max_turns") or config.has("maxTurns"):
		var max_turns_value: Variant = _get_first(config, ["max_turns", "maxTurns"])
		max_turns = int(max_turns_value) if max_turns_value != null else null
	if config.has("background"):
		background = bool(config["background"]) if config["background"] != null else null
	if config.has("effort"):
		effort = _normalize_effort(config["effort"])
	if config.has("permission_mode") or config.has("permissionMode"):
		permission_mode = str(_get_first(config, ["permission_mode", "permissionMode"]))
	return self


func duplicate_definition():
	return ClaudeAgentDefinition.new({
		"description": description,
		"prompt": prompt,
		"tools": _duplicate_variant(tools),
		"disallowed_tools": _duplicate_variant(disallowed_tools),
		"model": model,
		"skills": _duplicate_variant(skills),
		"memory": memory,
		"mcp_servers": _duplicate_variant(mcp_servers),
		"initial_prompt": initial_prompt,
		"max_turns": max_turns,
		"background": background,
		"effort": effort,
		"permission_mode": permission_mode,
	})


func to_initialize_dict() -> Dictionary:
	var serialized := {
		"description": description,
		"prompt": prompt,
	}
	if tools is Array:
		serialized["tools"] = (tools as Array).duplicate()
	if disallowed_tools is Array:
		serialized["disallowedTools"] = (disallowed_tools as Array).duplicate()
	if not model.is_empty():
		serialized["model"] = model
	if skills is Array:
		serialized["skills"] = (skills as Array).duplicate()
	if not memory.is_empty():
		serialized["memory"] = memory
	if mcp_servers is Array:
		serialized["mcpServers"] = _duplicate_variant(mcp_servers)
	if not initial_prompt.is_empty():
		serialized["initialPrompt"] = initial_prompt
	if max_turns != null:
		serialized["maxTurns"] = int(max_turns)
	if background != null:
		serialized["background"] = background
	if effort != null:
		serialized["effort"] = effort
	if not permission_mode.is_empty():
		serialized["permissionMode"] = permission_mode
	return serialized


static func _normalize_string_array_variant(value: Variant) -> Variant:
	if value == null:
		return null
	if value is Array:
		var result: Array[String] = []
		for item in value:
			result.append(str(item))
		return result
	return null


static func _get_first(source: Dictionary, keys: Array[String]) -> Variant:
	for key in keys:
		if source.has(key):
			return source[key]
	return null


static func _normalize_array_variant(value: Variant) -> Variant:
	if value == null:
		return null
	if value is Array:
		return _duplicate_variant(value)
	return null


static func _normalize_effort(value: Variant) -> Variant:
	if value == null:
		return null
	if value is int:
		return int(value)
	return str(value)


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var duplicated: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			duplicated[key_variant] = _duplicate_variant((value as Dictionary)[key_variant])
		return duplicated
	if value is Array:
		var duplicated: Array = []
		for item in value:
			duplicated.append(_duplicate_variant(item))
		return duplicated
	return value
