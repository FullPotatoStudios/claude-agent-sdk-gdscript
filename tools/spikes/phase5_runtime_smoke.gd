extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeAgentDefinitionScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_definition.gd")
const ClaudeHookMatcherScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_matcher.gd")
const ClaudePermissionResultAllowScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_allow.gd")
const ClaudePromptStreamScript := preload("res://addons/claude_agent_sdk/runtime/input/claude_prompt_stream.gd")
const ClaudeSDKClientScript := preload("res://addons/claude_agent_sdk/runtime/claude_sdk_client.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")

const DEFAULT_OUTPUT_STYLE := "local-test-style"
const FILESYSTEM_AGENT_NAME := "fs-test-agent"
const SDK_AGENT_NAME := "test-agent"
const SUPPORTED_MODES := [
	"baseline",
	"structured",
	"partial",
	"agents",
	"setting_sources_default",
	"setting_sources_project_included",
	"filesystem_agent_project",
	"stderr_debug",
	"hook_pre_tool_use",
	"tool_permission_bash_touch",
	"dynamic_permission_mode",
	"dynamic_model",
	"dynamic_interrupt",
]

var _stderr_lines: Array[String] = []
var _hook_invocations: Array[Dictionary] = []
var _permission_invocations: Array[Dictionary] = []


func _init() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	if bool(args.get("list_modes", false)):
		for mode in SUPPORTED_MODES:
			print("MODE %s" % mode)
		quit(0)
		return
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
		"stderr_debug":
			return await _run_stderr_debug_smoke(args)
		"hook_pre_tool_use":
			return await _run_hook_pre_tool_use_smoke(args)
		"tool_permission_bash_touch":
			return await _run_tool_permission_bash_touch_smoke(args)
		"dynamic_permission_mode":
			return await _run_dynamic_permission_mode_smoke(args)
		"dynamic_model":
			return await _run_dynamic_model_smoke(args)
		"dynamic_interrupt":
			return await _run_dynamic_interrupt_smoke(args)
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


func _run_stderr_debug_smoke(args: Dictionary) -> Dictionary:
	_stderr_lines.clear()
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"max_turns": 1,
		"stderr": Callable(self, "_on_stderr_line"),
		"extra_args": {"debug-to-stderr": null},
	})
	var summary := await _collect_stream_summary(
		"stderr_debug",
		ClaudeQueryScript.query("What is 2 + 2? Answer only with the number.", options)
	)
	summary["stderr_line_count"] = _stderr_lines.size()
	summary["stderr_debug_present"] = _lines_contain_substring(_stderr_lines, "[DEBUG]")
	summary["ok"] = _summary_succeeded(summary) \
		and int(summary.get("stderr_line_count", 0)) > 0 \
		and bool(summary.get("stderr_debug_present", false))
	return summary


func _run_hook_pre_tool_use_smoke(args: Dictionary) -> Dictionary:
	_hook_invocations.clear()
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"cwd": ProjectSettings.globalize_path("res://"),
		"max_turns": 2,
		"allowed_tools": ["Bash"],
		"permission_mode": "bypassPermissions",
		"hooks": {
			"PreToolUse": [
				ClaudeHookMatcherScript.new({
					"matcher": "Bash",
					"hooks": [Callable(self, "_smoke_pre_tool_use_hook")],
					"timeout_sec": 10.0,
				}),
			],
		},
	})
	var prompt := str(args.get(
		"prompt",
		"Use Bash to run: printf 'hook smoke\\n'. Then answer only with done."
	))
	var summary := await _collect_stream_summary(
		"hook_pre_tool_use",
		ClaudeQueryScript.query(prompt, options)
	)
	summary["hook_invocation_count"] = _hook_invocations.size()
	summary["hook_tools"] = _collect_string_field(_hook_invocations, "tool_name")
	summary["hook_tool_use_ids"] = _collect_string_field(_hook_invocations, "tool_use_id")
	summary["hook_bash_seen"] = _collect_string_field(_hook_invocations, "tool_name").has("Bash")
	summary["hook_tool_use_id_present"] = _any_non_empty_string(_collect_string_field(_hook_invocations, "tool_use_id"))
	summary["ok"] = _summary_succeeded(summary) \
		and int(summary.get("hook_invocation_count", 0)) > 0 \
		and bool(summary.get("hook_bash_seen", false)) \
		and bool(summary.get("hook_tool_use_id_present", false))
	return summary


func _run_tool_permission_bash_touch_smoke(args: Dictionary) -> Dictionary:
	_permission_invocations.clear()
	var project_dir := _create_temp_project_dir("tool-permission-bash-touch")
	var touch_target := project_dir.path_join("permission-smoke-%d.txt" % Time.get_ticks_usec())
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"cwd": project_dir,
		"max_turns": 2,
		"allowed_tools": ["Bash"],
		"can_use_tool": Callable(self, "_smoke_permission_callback"),
	})
	var prompt_stream = ClaudePromptStreamScript.new()
	prompt_stream.push_message({
		"type": "user",
		"message": {
			"role": "user",
			"content": "Use Bash to run: touch %s. Then answer only with done." % _shell_single_quote(touch_target),
		},
		"parent_tool_use_id": null,
	})
	prompt_stream.finish()
	var summary := await _collect_stream_summary(
		"tool_permission_bash_touch",
		ClaudeQueryScript.query(prompt_stream, options)
	)
	summary["permission_invocation_count"] = _permission_invocations.size()
	summary["permission_tools"] = _collect_string_field(_permission_invocations, "tool_name")
	summary["permission_tool_use_ids"] = _collect_string_field(_permission_invocations, "tool_use_id")
	summary["permission_bash_seen"] = _collect_string_field(_permission_invocations, "tool_name").has("Bash")
	summary["permission_tool_use_id_present"] = _any_non_empty_string(_collect_string_field(_permission_invocations, "tool_use_id"))
	summary["touched_file"] = touch_target
	summary["touched_file_exists"] = FileAccess.file_exists(touch_target)
	summary["ok"] = _summary_succeeded(summary) \
		and int(summary.get("permission_invocation_count", 0)) > 0 \
		and bool(summary.get("permission_bash_seen", false)) \
		and bool(summary.get("permission_tool_use_id_present", false)) \
		and bool(summary.get("touched_file_exists", false))
	return summary


func _run_dynamic_permission_mode_smoke(args: Dictionary) -> Dictionary:
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"permission_mode": "default",
	})
	var client = ClaudeSDKClientScript.new(options)
	client.connect_client()
	var summary := await _wait_for_client_initialize("dynamic_permission_mode", client)
	if not bool(summary.get("ok", false)):
		client.disconnect_client()
		return summary

	var control_errors: Array[String] = []
	client.set_permission_mode("acceptEdits")
	await process_frame
	_append_client_error(control_errors, client)
	var accept_edits_turn := await _run_connected_client_turn(
		client,
		"permission_mode_accept_edits",
		"What is 2 + 2? Just respond with the number."
	)

	client.set_permission_mode("default")
	await process_frame
	_append_client_error(control_errors, client)
	var default_turn := await _run_connected_client_turn(
		client,
		"permission_mode_default",
		"What is 3 + 3? Just respond with the number."
	)
	client.disconnect_client()

	summary["control_errors"] = control_errors
	summary["turn_summaries"] = [accept_edits_turn, default_turn]
	summary["ok"] = bool(summary.get("init_present", false)) \
		and control_errors.is_empty() \
		and _turn_summary_succeeded(accept_edits_turn) \
		and _turn_summary_succeeded(default_turn)
	return summary


func _run_dynamic_model_smoke(args: Dictionary) -> Dictionary:
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"effort": "low",
	})
	var client = ClaudeSDKClientScript.new(options)
	client.connect_client()
	var summary := await _wait_for_client_initialize("dynamic_model", client)
	if not bool(summary.get("ok", false)):
		client.disconnect_client()
		return summary

	var control_errors: Array[String] = []
	var default_turn := await _run_connected_client_turn(
		client,
		"model_default",
		"What is 1 + 1? Just respond with the number."
	)

	client.set_model("haiku")
	await process_frame
	_append_client_error(control_errors, client)
	var switched_turn := await _run_connected_client_turn(
		client,
		"model_haiku",
		"What is 2 + 2? Just respond with the number."
	)

	client.set_model("")
	await process_frame
	_append_client_error(control_errors, client)
	var reset_turn := await _run_connected_client_turn(
		client,
		"model_default_reset",
		"What is 3 + 3? Just respond with the number."
	)
	client.disconnect_client()

	summary["control_errors"] = control_errors
	summary["model_switch_value"] = "haiku"
	summary["model_reset_value"] = ""
	summary["turn_summaries"] = [default_turn, switched_turn, reset_turn]
	summary["ok"] = bool(summary.get("init_present", false)) \
		and control_errors.is_empty() \
		and _turn_summary_succeeded(default_turn) \
		and _turn_summary_succeeded(switched_turn) \
		and _turn_summary_succeeded(reset_turn)
	return summary


func _run_dynamic_interrupt_smoke(args: Dictionary) -> Dictionary:
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
	})
	var client = ClaudeSDKClientScript.new(options)
	client.connect_client()
	var summary := await _wait_for_client_initialize("dynamic_interrupt", client)
	if not bool(summary.get("ok", false)):
		client.disconnect_client()
		return summary

	client.query("Count from 1 to 100 slowly, one number per line.")
	var query_error := client.get_last_error()
	var response_stream = client.receive_response()
	await create_timer(0.25).timeout
	client.interrupt()
	await process_frame
	var interrupt_error := client.get_last_error()
	var turn_summary := await _collect_stream_summary("interrupt_response", response_stream)
	client.disconnect_client()

	summary["query_error"] = query_error
	summary["interrupt_error"] = interrupt_error
	summary["interrupt_stream_summary"] = turn_summary
	summary["ok"] = bool(summary.get("init_present", false)) \
		and query_error.is_empty() \
		and interrupt_error.is_empty() \
		and str(turn_summary.get("stream_error", "")).is_empty() \
		and (
			bool(turn_summary.get("assistant_present", false)) \
			or bool(turn_summary.get("result_present", false)) \
			or not (turn_summary.get("message_types", []) as Array).is_empty()
		)
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


func _wait_for_client_initialize(mode: String, client: ClaudeSDKClient, timeout_sec := 30.0) -> Dictionary:
	var summary := _empty_summary(mode)
	var timeout_at_usec := Time.get_ticks_usec() + int(timeout_sec * 1000000.0)
	while Time.get_ticks_usec() < timeout_at_usec:
		var server_info := client.get_server_info()
		if not server_info.is_empty():
			summary["init_present"] = true
			summary["init_agents"] = _variant_to_string_array(server_info.get("agents", []))
			summary["init_output_style"] = str(server_info.get("output_style", ""))
			summary["ok"] = true
			return summary
		var error_message := client.get_last_error()
		if not error_message.is_empty():
			summary["stream_error"] = error_message
			return summary
		await process_frame
	summary["stream_error"] = "Timed out waiting for client initialization"
	return summary


func _run_connected_client_turn(client: ClaudeSDKClient, label: String, prompt: String) -> Dictionary:
	client.query(prompt)
	var query_error := client.get_last_error()
	var summary := await _collect_stream_summary(label, client.receive_response())
	summary["query_error"] = query_error
	summary["ok"] = query_error.is_empty() and _turn_summary_succeeded(summary)
	return summary


func _turn_summary_succeeded(summary: Dictionary) -> bool:
	return bool(summary.get("assistant_present", false)) \
		and bool(summary.get("result_present", false)) \
		and not bool(summary.get("result_is_error", true)) \
		and str(summary.get("stream_error", "")).is_empty() \
		and str(summary.get("query_error", "")).is_empty()


func _append_client_error(errors: Array[String], client: ClaudeSDKClient) -> void:
	var message := client.get_last_error()
	if not message.is_empty():
		errors.append(message)


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
		"stderr_line_count": 0,
		"stderr_debug_present": false,
		"hook_invocation_count": 0,
		"hook_tools": [],
		"hook_tool_use_ids": [],
		"hook_bash_seen": false,
		"hook_tool_use_id_present": false,
		"permission_invocation_count": 0,
		"permission_tools": [],
		"permission_tool_use_ids": [],
		"permission_bash_seen": false,
		"permission_tool_use_id_present": false,
		"touched_file": "",
		"touched_file_exists": false,
		"control_errors": [],
		"turn_summaries": [],
		"query_error": "",
		"interrupt_error": "",
		"interrupt_stream_summary": {},
		"model_switch_value": "",
		"model_reset_value": "",
	}


func _on_stderr_line(line: String) -> void:
	_stderr_lines.append(line)


func _smoke_pre_tool_use_hook(input_data: Dictionary, tool_use_id: Variant, _context) -> Dictionary:
	_hook_invocations.append({
		"tool_name": str(input_data.get("tool_name", "")),
		"tool_use_id": str(tool_use_id),
		"input": input_data.duplicate(true),
	})
	return {
		"reason": "Live validation approved the Bash invocation.",
		"hookSpecificOutput": {
			"hookEventName": "PreToolUse",
			"permissionDecision": "allow",
			"permissionDecisionReason": "Smoke validation recorded the callback and allowed Bash to continue.",
		},
	}


func _smoke_permission_callback(tool_name: String, input_data: Dictionary, context) -> Variant:
	_permission_invocations.append({
		"tool_name": tool_name,
		"tool_use_id": str(context.tool_use_id) if context != null else "",
		"input": input_data.duplicate(true),
	})
	return ClaudePermissionResultAllowScript.new()


func _collect_string_field(entries: Array[Dictionary], key: String) -> Array[String]:
	var values: Array[String] = []
	for entry in entries:
		values.append(str(entry.get(key, "")))
	return values


func _any_non_empty_string(values: Array[String]) -> bool:
	for value in values:
		if not value.is_empty():
			return true
	return false


func _lines_contain_substring(lines: Array[String], needle: String) -> bool:
	for line in lines:
		if line.contains(needle):
			return true
	return false


func _shell_single_quote(value: String) -> String:
	return "'%s'" % value.replace("'", "'\"'\"'")


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
		if arg == "--list-modes":
			parsed["list_modes"] = true
		elif arg.begins_with("--mode="):
			parsed["mode"] = arg.trim_prefix("--mode=")
		elif arg.begins_with("--claude-path="):
			parsed["claude_path"] = arg.trim_prefix("--claude-path=")
	return parsed
