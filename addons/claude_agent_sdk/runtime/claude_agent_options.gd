extends RefCounted
class_name ClaudeAgentOptions

const ClaudeHookMatcherScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_matcher.gd")
const ClaudeAgentDefinitionScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_definition.gd")

var model: String = ""
var effort: String = ""
var cwd: String = ""
var cli_path: String = "claude"
var env: Dictionary = {}
var system_prompt: Variant = ""
var tools: Variant = null
var allowed_tools: Array[String] = []
var disallowed_tools: Array[String] = []
var continue_conversation: bool = false
var permission_mode: String = ""
var max_turns: int = 0
var max_budget_usd: Variant = null
var task_budget: Variant = null
var resume: String = ""
var session_id: String = ""
var fallback_model: String = ""
var betas: Array[String] = []
var permission_prompt_tool_name: String = ""
var settings: String = ""
var extra_args: Dictionary = {}
var add_dirs: Array[String] = []
var plugins: Array = []
var hooks: Dictionary = {}
var can_use_tool: Callable = Callable()
var stderr: Callable = Callable()
var max_thinking_tokens: Variant = null
var thinking: Variant = null
var include_partial_messages: bool = false
var enable_file_checkpointing: bool = false
var user: String = ""
var fork_session: bool = false
var output_format: Dictionary = {}
var mcp_servers: Variant = {}
var agents: Dictionary = {}
var setting_sources: Array[String] = []
var sandbox: Variant = null


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
	if config.has("continue_conversation"):
		continue_conversation = bool(config["continue_conversation"])
	if config.has("permission_mode"):
		permission_mode = str(config["permission_mode"])
	if config.has("max_turns"):
		max_turns = int(config["max_turns"])
	if config.has("max_budget_usd"):
		max_budget_usd = _normalize_float_variant(config["max_budget_usd"])
	if config.has("task_budget"):
		task_budget = _normalize_task_budget(config["task_budget"])
	if config.has("resume"):
		resume = str(config["resume"])
	if config.has("session_id"):
		session_id = str(config["session_id"])
	if config.has("fallback_model"):
		fallback_model = str(config["fallback_model"])
	if config.has("betas") and config["betas"] is Array:
		betas = _to_string_array(config["betas"] as Array)
	if config.has("permission_prompt_tool_name"):
		permission_prompt_tool_name = str(config["permission_prompt_tool_name"])
	if config.has("settings"):
		settings = str(config["settings"])
	if config.has("extra_args") and config["extra_args"] is Dictionary:
		extra_args = _duplicate_nested_variant(config["extra_args"])
	if config.has("add_dirs") and config["add_dirs"] is Array:
		add_dirs = _to_string_array(config["add_dirs"] as Array)
	if config.has("plugins") and config["plugins"] is Array:
		plugins = _normalize_plugins(config["plugins"] as Array)
	if config.has("hooks") and config["hooks"] is Dictionary:
		hooks = _normalize_hooks(config["hooks"] as Dictionary)
	if config.has("can_use_tool") and config["can_use_tool"] is Callable:
		can_use_tool = config["can_use_tool"]
	if config.has("stderr") and config["stderr"] is Callable:
		stderr = config["stderr"]
	if config.has("max_thinking_tokens"):
		max_thinking_tokens = _normalize_int_variant(config["max_thinking_tokens"])
	if config.has("thinking"):
		thinking = _normalize_thinking(config["thinking"])
	if config.has("include_partial_messages"):
		include_partial_messages = bool(config["include_partial_messages"])
	if config.has("enable_file_checkpointing"):
		enable_file_checkpointing = bool(config["enable_file_checkpointing"])
	if config.has("user"):
		user = str(config["user"])
	if config.has("fork_session"):
		fork_session = bool(config["fork_session"])
	if config.has("output_format") and config["output_format"] is Dictionary:
		output_format = (config["output_format"] as Dictionary).duplicate(true)
	if config.has("mcp_servers"):
		if config["mcp_servers"] is Dictionary:
			mcp_servers = _duplicate_nested_variant(config["mcp_servers"])
		elif config["mcp_servers"] is String:
			mcp_servers = str(config["mcp_servers"])
	if config.has("agents") and config["agents"] is Dictionary:
		agents = _normalize_agents(config["agents"] as Dictionary)
	if config.has("setting_sources") and config["setting_sources"] is Array:
		setting_sources = _to_string_array(config["setting_sources"] as Array)
	if config.has("sandbox"):
		sandbox = _normalize_sandbox(config["sandbox"])
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
			"continue_conversation": continue_conversation,
			"permission_mode": permission_mode,
			"max_turns": max_turns,
			"max_budget_usd": max_budget_usd,
			"task_budget": _duplicate_variant(task_budget),
			"resume": resume,
			"session_id": session_id,
			"fallback_model": fallback_model,
			"betas": betas.duplicate(),
			"permission_prompt_tool_name": permission_prompt_tool_name,
			"settings": settings,
			"extra_args": _duplicate_nested_variant(extra_args),
			"add_dirs": add_dirs.duplicate(),
			"plugins": _duplicate_plugins(plugins),
			"hooks": _duplicate_hooks(hooks),
			"can_use_tool": can_use_tool,
			"stderr": stderr,
			"max_thinking_tokens": max_thinking_tokens,
				"thinking": _duplicate_variant(thinking),
				"include_partial_messages": include_partial_messages,
				"enable_file_checkpointing": enable_file_checkpointing,
				"user": user,
				"fork_session": fork_session,
				"output_format": output_format.duplicate(true),
			"mcp_servers": _duplicate_mcp_servers(mcp_servers),
			"agents": _duplicate_agents(agents),
			"setting_sources": setting_sources.duplicate(),
			"sandbox": _duplicate_variant(sandbox),
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


static func _normalize_plugins(value: Array) -> Array:
	var normalized: Array = []
	for plugin_value in value:
		if plugin_value is not Dictionary:
			continue
		var source := plugin_value as Dictionary
		var duplicated: Dictionary = source.duplicate(true)
		if duplicated.has("type"):
			duplicated["type"] = str(duplicated["type"])
		if duplicated.has("path"):
			duplicated["path"] = str(duplicated["path"])
		normalized.append(duplicated)
	return normalized


static func _duplicate_plugins(value: Array) -> Array:
	return _normalize_plugins(value)


static func _normalize_agents(value: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for agent_name_variant in value.keys():
		var agent_name := str(agent_name_variant)
		var agent_value: Variant = value[agent_name_variant]
		if agent_value is ClaudeAgentDefinition:
			normalized[agent_name] = (agent_value as ClaudeAgentDefinition).duplicate_definition()
		elif agent_value is Dictionary:
			normalized[agent_name] = ClaudeAgentDefinitionScript.new(agent_value as Dictionary)
	return normalized


static func _duplicate_agents(value: Dictionary) -> Dictionary:
	return _normalize_agents(value)


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


static func _normalize_float_variant(value: Variant) -> Variant:
	if value == null:
		return null
	return float(value)


static func _normalize_int_variant(value: Variant) -> Variant:
	if value == null:
		return null
	return int(value)


static func _normalize_task_budget(value: Variant) -> Variant:
	if value == null:
		return null
	if not (value is Dictionary):
		return null
	var source := value as Dictionary
	if not source.has("total"):
		return null
	return {
		"total": int(source["total"]),
	}


static func _normalize_thinking(value: Variant) -> Variant:
	if value == null:
		return null
	if not (value is Dictionary):
		return null
	var source := value as Dictionary
	var thinking_type := str(source.get("type", "")).strip_edges()
	if thinking_type.is_empty():
		return null
	match thinking_type:
		"adaptive":
			return {"type": "adaptive"}
		"enabled":
			if not source.has("budget_tokens"):
				return null
			return {
				"type": "enabled",
				"budget_tokens": int(source["budget_tokens"]),
			}
		"disabled":
			return {"type": "disabled"}
		_:
			return null


static func _normalize_sandbox(value: Variant) -> Variant:
	if value == null:
		return null
	if not (value is Dictionary):
		return null
	var source := value as Dictionary
	var normalized: Dictionary = {}
	if source.has("enabled"):
		normalized["enabled"] = bool(source["enabled"])
	if source.has("auto_allow_bash_if_sandboxed") or source.has("autoAllowBashIfSandboxed"):
		normalized["auto_allow_bash_if_sandboxed"] = bool(source.get("auto_allow_bash_if_sandboxed", source.get("autoAllowBashIfSandboxed", false)))
	if source.has("excluded_commands") or source.has("excludedCommands"):
		var excluded_value: Variant = source.get("excluded_commands", source.get("excludedCommands", []))
		if excluded_value is Array:
			normalized["excluded_commands"] = _to_string_array(excluded_value as Array)
	if source.has("allow_unsandboxed_commands") or source.has("allowUnsandboxedCommands"):
		normalized["allow_unsandboxed_commands"] = bool(source.get("allow_unsandboxed_commands", source.get("allowUnsandboxedCommands", false)))
	if source.has("network") and source["network"] is Dictionary:
		normalized["network"] = _normalize_sandbox_network(source["network"] as Dictionary)
	if source.has("ignore_violations") or source.has("ignoreViolations"):
		var ignore_value: Variant = source.get("ignore_violations", source.get("ignoreViolations", null))
		if ignore_value is Dictionary:
			normalized["ignore_violations"] = _normalize_sandbox_ignore_violations(ignore_value as Dictionary)
	if source.has("enable_weaker_nested_sandbox") or source.has("enableWeakerNestedSandbox"):
		normalized["enable_weaker_nested_sandbox"] = bool(source.get("enable_weaker_nested_sandbox", source.get("enableWeakerNestedSandbox", false)))
	return normalized


static func _normalize_sandbox_network(value: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	if value.has("allow_unix_sockets") or value.has("allowUnixSockets"):
		var allow_sockets: Variant = value.get("allow_unix_sockets", value.get("allowUnixSockets", []))
		if allow_sockets is Array:
			normalized["allow_unix_sockets"] = _to_string_array(allow_sockets as Array)
	if value.has("allow_all_unix_sockets") or value.has("allowAllUnixSockets"):
		normalized["allow_all_unix_sockets"] = bool(value.get("allow_all_unix_sockets", value.get("allowAllUnixSockets", false)))
	if value.has("allow_local_binding") or value.has("allowLocalBinding"):
		normalized["allow_local_binding"] = bool(value.get("allow_local_binding", value.get("allowLocalBinding", false)))
	if value.has("http_proxy_port") or value.has("httpProxyPort"):
		normalized["http_proxy_port"] = int(value.get("http_proxy_port", value.get("httpProxyPort", 0)))
	if value.has("socks_proxy_port") or value.has("socksProxyPort"):
		normalized["socks_proxy_port"] = int(value.get("socks_proxy_port", value.get("socksProxyPort", 0)))
	return normalized


static func _normalize_sandbox_ignore_violations(value: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	if value.has("file") and value["file"] is Array:
		normalized["file"] = _to_string_array(value["file"] as Array)
	if value.has("network") and value["network"] is Array:
		normalized["network"] = _to_string_array(value["network"] as Array)
	return normalized


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return _duplicate_nested_variant(value)
	return value


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
