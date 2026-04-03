extends RefCounted
class_name ClaudeAgentOptions

var model: String = ""
var effort: String = ""
var cwd: String = ""
var cli_path: String = "claude"
var env: Dictionary = {}
var system_prompt: String = ""
var allowed_tools: Array[String] = []
var disallowed_tools: Array[String] = []
var permission_mode: String = ""
var max_turns: int = 0
var resume: String = ""
var session_id: String = ""


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
		system_prompt = str(config["system_prompt"])
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
	return self


func duplicate_options():
	return ClaudeAgentOptions.new({
		"model": model,
		"effort": effort,
		"cwd": cwd,
		"cli_path": cli_path,
		"env": env.duplicate(true),
		"system_prompt": system_prompt,
		"allowed_tools": allowed_tools.duplicate(),
		"disallowed_tools": disallowed_tools.duplicate(),
		"permission_mode": permission_mode,
		"max_turns": max_turns,
		"resume": resume,
		"session_id": session_id,
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
