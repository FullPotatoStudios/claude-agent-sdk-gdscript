extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeAgentDefinitionScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_definition.gd")
const ClaudeSDKClientScript := preload("res://addons/claude_agent_sdk/runtime/claude_sdk_client.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")

const DEFAULT_OUTPUT_STYLE := "local-test-style"
const FILESYSTEM_AGENT_NAME := "fs-test-agent"
const SDK_AGENT_NAME := "test-agent"


func _init() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	await process_frame
	var summary: Dictionary = await _run_smoke(args)
	print("SUMMARY %s" % JSON.stringify(summary))
	quit(0 if bool(summary.get("ok", false)) else 2)


func _run_smoke(args: Dictionary) -> Dictionary:
	var mode := str(args.get("mode", "baseline"))
	match mode:
		"baseline", "structured", "partial", "agents":
			return await _run_query_smoke(mode, args)
		"setting_sources_default":
			return await _run_setting_sources_default_smoke(args)
		"setting_sources_project_included":
			return await _run_setting_sources_project_included_smoke(args)
		"filesystem_agent_project":
			return await _run_filesystem_agent_project_smoke(args)
		_:
			var failed := _empty_summary(mode)
			failed["stream_error"] = "Unknown smoke mode"
			return failed


func _run_query_smoke(mode: String, args: Dictionary) -> Dictionary:
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
	})
	var prompt := ""

	match mode:
		"structured":
			options.max_turns = 2
			options.output_format = {
				"type": "json_schema",
				"schema": {
					"type": "object",
					"properties": {
						"answer": {"type": "string"},
					},
					"required": ["answer"],
					"additionalProperties": false,
				},
			}
			prompt = "Return a JSON object with a single answer field set to 4."
		"partial":
			options.max_turns = 1
			options.include_partial_messages = true
			prompt = "Count from 1 to 20 in a single comma-separated line."
		"agents":
			options.max_turns = 1
			options.agents = {
				SDK_AGENT_NAME: ClaudeAgentDefinitionScript.new({
					"description": "A test agent for validation",
					"prompt": "You are a test agent. Always respond with 'Test agent activated'.",
					"tools": ["Read"],
					"model": "sonnet",
				}),
			}
			prompt = "What is 2 + 2? Answer only with the number."
		_:
			options.max_turns = 1
			prompt = "What is 2 + 2? Answer only with the number."

	var summary := await _collect_stream_summary(mode, ClaudeQueryScript.query(prompt, options))
	match mode:
		"structured":
			summary["ok"] = _summary_succeeded(summary) and bool(summary.get("structured_output_present", false))
		"partial":
			summary["ok"] = _summary_succeeded(summary) and bool(summary.get("saw_stream_event", false))
		"agents":
			summary["ok"] = _summary_succeeded(summary) and _summary_has_agent(summary, SDK_AGENT_NAME)
		_:
			summary["ok"] = _summary_succeeded(summary)
	return summary


func _run_setting_sources_default_smoke(args: Dictionary) -> Dictionary:
	var project_dir := _create_temp_project_dir("setting-sources-default")
	if not _write_text_file(
		project_dir.path_join(".claude/settings.local.json"),
		"{\"outputStyle\": \"%s\"}" % DEFAULT_OUTPUT_STYLE
	):
		var failed := _empty_summary("setting_sources_default")
		failed["project_dir"] = project_dir
		failed["expected_output_style"] = DEFAULT_OUTPUT_STYLE
		failed["stream_error"] = "Could not write settings.local.json"
		return failed
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"cwd": project_dir,
		"max_turns": 1,
	})
	var summary := await _run_client_smoke("setting_sources_default", options, "What is 2 + 2? Answer only with the number.")
	summary["expected_output_style"] = DEFAULT_OUTPUT_STYLE
	summary["project_dir"] = project_dir
	summary["ok"] = _summary_succeeded(summary) and str(summary.get("init_output_style", "")) == DEFAULT_OUTPUT_STYLE
	return summary


func _run_setting_sources_project_included_smoke(args: Dictionary) -> Dictionary:
	var project_dir := _create_temp_project_dir("setting-sources-project")
	if not _write_text_file(
		project_dir.path_join(".claude/settings.local.json"),
		"{\"outputStyle\": \"%s\"}" % DEFAULT_OUTPUT_STYLE
	):
		var failed := _empty_summary("setting_sources_project_included")
		failed["project_dir"] = project_dir
		failed["expected_output_style"] = DEFAULT_OUTPUT_STYLE
		failed["stream_error"] = "Could not write settings.local.json"
		return failed
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"cwd": project_dir,
		"max_turns": 1,
		"setting_sources": ["user", "project", "local"],
	})
	var summary := await _run_client_smoke("setting_sources_project_included", options, "What is 2 + 2? Answer only with the number.")
	summary["expected_output_style"] = DEFAULT_OUTPUT_STYLE
	summary["project_dir"] = project_dir
	summary["ok"] = _summary_succeeded(summary) and str(summary.get("init_output_style", "")) == DEFAULT_OUTPUT_STYLE
	return summary


func _run_filesystem_agent_project_smoke(args: Dictionary) -> Dictionary:
	var project_dir := _create_temp_project_dir("filesystem-agent-project")
	if not _write_text_file(
		project_dir.path_join(".claude/agents/%s.md" % FILESYSTEM_AGENT_NAME),
		"""---
name: fs-test-agent
description: A filesystem test agent for SDK testing
tools: Read
---

# Filesystem Test Agent

You are a simple test agent. When asked a question, provide a brief, helpful answer.
"""
	):
		var failed := _empty_summary("filesystem_agent_project")
		failed["project_dir"] = project_dir
		failed["expected_agent"] = FILESYSTEM_AGENT_NAME
		failed["stream_error"] = "Could not write filesystem agent definition"
		return failed
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"cwd": project_dir,
		"max_turns": 1,
		"setting_sources": ["project"],
	})
	var summary := await _run_client_smoke("filesystem_agent_project", options, "Say hello in exactly 3 words.")
	summary["expected_agent"] = FILESYSTEM_AGENT_NAME
	summary["project_dir"] = project_dir
	summary["ok"] = _summary_succeeded(summary) and _summary_has_agent(summary, FILESYSTEM_AGENT_NAME)
	return summary


func _run_client_smoke(mode: String, options: ClaudeAgentOptions, prompt: String) -> Dictionary:
	var client = ClaudeSDKClientScript.new(options)
	client.connect_client()
	if not client.get_last_error().is_empty():
		var failed := _empty_summary(mode)
		failed["stream_error"] = client.get_last_error()
		client.disconnect_client()
		return failed
	client.query(prompt)
	if not client.get_last_error().is_empty():
		var failed := _empty_summary(mode)
		failed["stream_error"] = client.get_last_error()
		client.disconnect_client()
		return failed
	var summary := await _collect_stream_summary(mode, client.receive_response())
	client.disconnect_client()
	return summary


func _collect_stream_summary(mode: String, stream) -> Dictionary:
	var message_types: Array[String] = []
	var init_agents: Array[String] = []
	var saw_stream_event := false
	var assistant_present := false
	var init_present := false
	var init_output_style := ""
	var result_message = null

	while true:
		var message: Variant = await stream.next_message()
		if message == null:
			break
		if message is Object:
			message_types.append(str(message.get("message_type")))
		if message is ClaudeSystemMessage and str(message.subtype) == "init":
			var init_payload: Dictionary = message.raw_data if message.raw_data is Dictionary else {}
			init_present = true
			init_output_style = str(init_payload.get("output_style", ""))
			init_agents = _variant_to_string_array(init_payload.get("agents", []))
		if message is ClaudeAssistantMessage:
			assistant_present = true
		if message is ClaudeStreamEvent:
			saw_stream_event = true
		if message is ClaudeResultMessage:
			result_message = message

	var summary := {
		"mode": mode,
		"message_types": message_types,
		"stream_error": stream.get_error(),
		"saw_stream_event": saw_stream_event,
		"init_present": init_present,
		"init_agents": init_agents,
		"init_output_style": init_output_style,
		"assistant_present": assistant_present,
		"result_present": result_message != null,
		"result_is_error": false,
		"result_subtype": "",
		"result_errors": [],
		"result_num_turns": 0,
		"structured_output_present": false,
		"structured_output": null,
		"result_text": "",
	}
	if result_message != null:
		summary["result_is_error"] = bool(result_message.is_error)
		summary["result_subtype"] = str(result_message.subtype)
		summary["result_errors"] = result_message.errors.duplicate(true)
		summary["result_num_turns"] = int(result_message.num_turns)
		summary["structured_output_present"] = result_message.structured_output != null
		summary["structured_output"] = result_message.structured_output
		summary["result_text"] = str(result_message.result)
	return summary


func _summary_succeeded(summary: Dictionary) -> bool:
	return bool(summary.get("init_present", false)) \
		and bool(summary.get("assistant_present", false)) \
		and bool(summary.get("result_present", false)) \
		and not bool(summary.get("result_is_error", true)) \
		and str(summary.get("stream_error", "")).is_empty()


func _summary_has_agent(summary: Dictionary, agent_name: String) -> bool:
	if not (summary.get("init_agents", []) is Array):
		return false
	var agents: Array = summary.get("init_agents", [])
	return agents.has(agent_name)


func _empty_summary(mode: String) -> Dictionary:
	return {
		"mode": mode,
		"ok": false,
		"message_types": [],
		"stream_error": "",
		"saw_stream_event": false,
		"init_present": false,
		"init_agents": [],
		"init_output_style": "",
		"assistant_present": false,
		"result_present": false,
		"result_is_error": false,
		"result_subtype": "",
		"result_errors": [],
		"result_num_turns": 0,
		"structured_output_present": false,
		"structured_output": null,
		"result_text": "",
	}


func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is not Array:
		return result
	for item in value:
		result.append(str(item))
	return result


func _create_temp_project_dir(label: String) -> String:
	var project_dir := ProjectSettings.globalize_path("res://.artifacts/live-cli/projects/%s-%s" % [label, Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(project_dir)
	return project_dir


func _write_text_file(path: String, contents: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open file for write: %s" % path)
		return false
	file.store_string(contents)
	file.close()
	return true


func _parse_args(cmdline_args: PackedStringArray) -> Dictionary:
	var parsed := {
		"mode": "baseline",
		"claude_path": "claude",
	}
	for arg in cmdline_args:
		if arg.begins_with("--mode="):
			parsed["mode"] = arg.trim_prefix("--mode=")
		elif arg.begins_with("--claude-path="):
			parsed["claude_path"] = arg.trim_prefix("--claude-path=")
	return parsed
