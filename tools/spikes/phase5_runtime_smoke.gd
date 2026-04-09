extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeAgentDefinitionScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_definition.gd")
const ClaudeHookMatcherScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_matcher.gd")
const ClaudeMcpScript := preload("res://addons/claude_agent_sdk/runtime/mcp/claude_mcp.gd")
const ClaudePermissionResultAllowScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_allow.gd")
const ClaudeSessionsScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_sessions.gd")
const ClaudeSDKClientScript := preload("res://addons/claude_agent_sdk/runtime/claude_sdk_client.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")
const ClaudeSubprocessCLITransportScript := preload("res://addons/claude_agent_sdk/runtime/transport/subprocess_cli_transport.gd")

const DEFAULT_OUTPUT_STYLE := "local-test-style"
const EXTERNAL_MCP_FIXTURE_SCRIPT := "res://tools/examples/fixtures/mcp/external_echo_server.js"
const EXTERNAL_MCP_TOOL_NAME := "echo"
const FILESYSTEM_AGENT_NAME := "fs-test-agent"
const PLUGIN_COMMAND_NAME := "greet"
const PLUGIN_FIXTURE_NAME := "demo-plugin"
const SDK_AGENT_NAME := "test-agent"
const SUPPORTED_MODES := [
	"baseline",
	"structured",
	"partial",
	"agents",
	"plugins",
	"setting_sources_default",
	"setting_sources_project_included",
	"filesystem_agent_project",
	"stderr_debug",
	"hook_pre_tool_use",
	"tool_permission_bash_touch",
	"user_current_user_auth",
	"user_current_user_baseline",
	"dynamic_permission_mode",
	"dynamic_model",
	"dynamic_interrupt",
	"context_usage",
	"mcp_status",
	"fork_session_resume",
	"external_mcp_reconnect",
	"sdk_mcp_tool_execution",
	"sdk_mcp_permission_enforcement",
	"sdk_mcp_multiple_tools",
	"sdk_mcp_without_permissions",
]

var _stderr_lines: Array[String] = []
var _hook_invocations: Array[Dictionary] = []
var _permission_invocations: Array[Dictionary] = []
var _sdk_mcp_executions: Array[String] = []


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
		"baseline", "structured", "partial", "agents", "plugins":
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
		"user_current_user_auth":
			return await _run_user_current_user_auth_smoke(args)
		"user_current_user_baseline":
			return await _run_user_current_user_baseline_smoke(args)
		"dynamic_permission_mode":
			return await _run_dynamic_permission_mode_smoke(args)
		"dynamic_model":
			return await _run_dynamic_model_smoke(args)
		"dynamic_interrupt":
			return await _run_dynamic_interrupt_smoke(args)
		"context_usage":
			return await _run_context_usage_smoke(args)
		"mcp_status":
			return await _run_mcp_status_smoke(args)
		"fork_session_resume":
			return await _run_fork_session_resume_smoke(args)
		"external_mcp_reconnect":
			return await _run_external_mcp_reconnect_smoke(args)
		"sdk_mcp_tool_execution":
			return await _run_sdk_mcp_tool_execution_smoke(args)
		"sdk_mcp_permission_enforcement":
			return await _run_sdk_mcp_permission_enforcement_smoke(args)
		"sdk_mcp_multiple_tools":
			return await _run_sdk_mcp_multiple_tools_smoke(args)
		"sdk_mcp_without_permissions":
			return await _run_sdk_mcp_without_permissions_smoke(args)
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
		"plugins":
			options.max_turns = 1
			options.cwd = ProjectSettings.globalize_path("res://")
			options.plugins = [
				{
					"type": "local",
					"path": options.cwd.path_join("tools/examples/fixtures/plugins/%s" % PLUGIN_FIXTURE_NAME),
				},
			]
			prompt = "Hello from the live plugin parity smoke."
		_:
			options.max_turns = 1
			prompt = "What is 2 + 2? Answer only with the number."

	var summary := await _collect_stream_summary(mode, ClaudeQueryScript.query(prompt, options))
	if mode == "plugins":
		var init_command_names: Array[String] = summary.get("init_command_names", []) as Array[String]
		var init_plugins: Array[String] = summary.get("init_plugins", []) as Array[String]
		summary["plugin_fixture_path"] = str(options.plugins[0]["path"])
		summary["plugin_detected_via_commands"] = init_command_names.has(PLUGIN_COMMAND_NAME)
		summary["plugin_detected_via_plugins"] = init_plugins.has(PLUGIN_FIXTURE_NAME)
		summary["plugin_detected"] = bool(summary.get("plugin_detected_via_commands", false)) \
			or bool(summary.get("plugin_detected_via_plugins", false))
	match mode:
		"structured":
			summary["ok"] = _summary_succeeded(summary) and bool(summary.get("structured_output_present", false))
		"partial":
			summary["ok"] = _summary_succeeded(summary) and bool(summary.get("saw_stream_event", false))
		"agents":
			summary["ok"] = _summary_succeeded(summary) and _summary_has_agent(summary, SDK_AGENT_NAME)
		"plugins":
			summary["ok"] = _summary_succeeded(summary) and bool(summary.get("plugin_detected", false))
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
	var temp_root := OS.get_environment("TMPDIR").strip_edges()
	if temp_root.is_empty():
		temp_root = "/tmp"
	var touch_target := temp_root.path_join("permission-smoke-%d.txt" % Time.get_ticks_usec())
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"cwd": project_dir,
		"max_turns": 2,
		"can_use_tool": Callable(self, "_smoke_permission_callback"),
	})
	var client = ClaudeSDKClientScript.new(options)
	client.connect_client()
	var summary := await _wait_for_client_initialize("tool_permission_bash_touch", client)
	if not bool(summary.get("ok", false)):
		client.disconnect_client()
		return summary

	var turn_summary := await _run_connected_client_turn(
		client,
		"tool_permission_bash_touch_turn",
		"Run the command: touch %s" % _shell_single_quote(touch_target)
	)
	client.disconnect_client()

	_merge_turn_summary(summary, turn_summary)
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


func _run_user_current_user_auth_smoke(args: Dictionary) -> Dictionary:
	var prepared := _prepare_current_user_relaunch("user_current_user_auth")
	var summary: Dictionary = prepared.get("summary", _empty_summary("user_current_user_auth"))
	if not bool(prepared.get("ok", false)):
		return summary

	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"user": str(prepared.get("user_name", "")),
	})
	var transport = ClaudeSubprocessCLITransportScript.new(options)
	var auth_status := transport.probe_auth_status()
	summary["auth_status"] = _variant_to_dictionary(auth_status)
	summary["auth_status_logged_in"] = bool(auth_status.get("logged_in", false))
	summary["stream_error"] = str(auth_status.get("error_message", ""))
	summary["ok"] = bool(auth_status.get("ok", false)) \
		and bool(summary.get("user_relaunch_preflight_ok", false)) \
		and bool(summary.get("auth_status_logged_in", false)) \
		and str(summary.get("stream_error", "")).is_empty()
	return summary


func _run_user_current_user_baseline_smoke(args: Dictionary) -> Dictionary:
	var prepared := _prepare_current_user_relaunch("user_current_user_baseline")
	var summary: Dictionary = prepared.get("summary", _empty_summary("user_current_user_baseline"))
	if not bool(prepared.get("ok", false)):
		return summary

	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"user": str(prepared.get("user_name", "")),
		"model": "haiku",
		"effort": "low",
		"max_turns": 1,
	})
	var turn_summary := await _run_client_smoke(
		"user_current_user_baseline",
		options,
		"What is 2 + 2? Answer only with the number."
	)
	for key in turn_summary.keys():
		summary[key] = turn_summary[key]
	summary["user_resolved_name"] = str(prepared.get("user_name", ""))
	summary["user_resolution_source"] = str(prepared.get("user_resolution_source", ""))
	summary["user_relaunch_preflight_ok"] = bool(prepared.get("user_relaunch_preflight_ok", false))
	summary["user_relaunch_preflight_error"] = str(prepared.get("user_relaunch_preflight_error", ""))
	summary["ok"] = bool(summary.get("user_relaunch_preflight_ok", false)) and _summary_succeeded(summary)
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

	client.set_model(null)
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
	summary["model_reset_value"] = null
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
		and str(turn_summary.get("stream_error", "")).is_empty()
	return summary


func _run_context_usage_smoke(args: Dictionary) -> Dictionary:
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"max_turns": 1,
	})
	var client = ClaudeSDKClientScript.new(options)
	client.connect_client()
	var summary := await _wait_for_client_initialize("context_usage", client)
	if not bool(summary.get("ok", false)):
		client.disconnect_client()
		return summary

	var turn_summary := await _run_connected_client_turn(
		client,
		"context_usage_turn",
		"What is 2 + 2? Answer only with the number."
	)
	var usage = await client.get_context_usage()
	var control_errors: Array[String] = []
	_append_client_error(control_errors, client)
	client.disconnect_client()

	_merge_turn_summary(summary, turn_summary)
	summary["control_errors"] = control_errors
	summary["context_usage"] = _variant_to_dictionary(usage)
	summary["context_usage_typed"] = usage is ClaudeContextUsageResponse
	summary["context_usage_category_count"] = 0
	summary["context_usage_model"] = ""
	summary["context_usage_total_tokens"] = 0
	summary["context_usage_max_tokens"] = 0
	summary["context_usage_percentage"] = 0.0
	summary["context_usage_error"] = control_errors[0] if not control_errors.is_empty() else ""

	if usage is ClaudeContextUsageResponse:
		var typed_usage := usage as ClaudeContextUsageResponse
		summary["context_usage_category_count"] = typed_usage.categories.size()
		summary["context_usage_model"] = typed_usage.model
		summary["context_usage_total_tokens"] = typed_usage.total_tokens
		summary["context_usage_max_tokens"] = typed_usage.max_tokens
		summary["context_usage_percentage"] = typed_usage.percentage
		summary["ok"] = bool(summary.get("init_present", false)) \
			and _turn_summary_succeeded(turn_summary) \
			and control_errors.is_empty() \
			and not typed_usage.is_empty() \
			and typed_usage.categories.size() > 0 \
			and typed_usage.total_tokens >= 0 \
			and typed_usage.max_tokens >= 0
		usage = null
		client = null
		await process_frame
		return summary

	summary["ok"] = false
	usage = null
	client = null
	await process_frame
	return summary


func _run_sdk_mcp_tool_execution_smoke(args: Dictionary) -> Dictionary:
	var server_name := "sdktest"
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"max_turns": 2,
		"mcp_servers": {
			server_name: _create_sdk_mcp_server(server_name, true, false),
		},
		"allowed_tools": ["mcp__%s__echo" % server_name],
	})
	var prompt := "Use the mcp__%s__echo tool exactly once with text 'parity'. Then answer only with done." % server_name
	var summary := await _run_sdk_mcp_client_smoke("sdk_mcp_tool_execution", options, prompt)
	var executions := _variant_to_string_array(summary.get("sdk_mcp_executions", []))
	summary["sdk_mcp_server_name"] = server_name
	summary["sdk_mcp_expected_executed"] = ["echo"]
	summary["ok"] = bool(summary.get("init_present", false)) \
		and _turn_summary_succeeded(summary.get("turn_summary", {})) \
		and executions.has("echo")
	return summary


func _run_sdk_mcp_permission_enforcement_smoke(args: Dictionary) -> Dictionary:
	var server_name := "sdkperm"
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"max_turns": 3,
		"mcp_servers": {
			server_name: _create_sdk_mcp_server(server_name, true, true),
		},
		"allowed_tools": ["mcp__%s__greet" % server_name],
		"disallowed_tools": ["mcp__%s__echo" % server_name],
	})
	var prompt := "First use the mcp__%s__greet tool to greet Alice. After that completes, try to use the mcp__%s__echo tool with text 'test'. Do these one at a time, not in parallel." % [server_name, server_name]
	var summary := await _run_sdk_mcp_client_smoke("sdk_mcp_permission_enforcement", options, prompt)
	var executions := _variant_to_string_array(summary.get("sdk_mcp_executions", []))
	summary["sdk_mcp_server_name"] = server_name
	summary["sdk_mcp_expected_executed"] = ["greet"]
	summary["sdk_mcp_expected_not_executed"] = ["echo"]
	summary["ok"] = bool(summary.get("init_present", false)) \
		and _turn_summary_succeeded(summary.get("turn_summary", {})) \
		and executions.has("greet") \
		and not executions.has("echo")
	return summary


func _run_sdk_mcp_multiple_tools_smoke(args: Dictionary) -> Dictionary:
	var server_name := "sdkmulti"
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"max_turns": 3,
		"mcp_servers": {
			server_name: _create_sdk_mcp_server(server_name, true, true),
		},
		"allowed_tools": [
			"mcp__%s__echo" % server_name,
			"mcp__%s__greet" % server_name,
		],
	})
	var prompt := "Use the mcp__%s__echo tool with text 'test' and the mcp__%s__greet tool with name 'Bob'. Do them one at a time, not in parallel. Then answer only with done." % [server_name, server_name]
	var summary := await _run_sdk_mcp_client_smoke("sdk_mcp_multiple_tools", options, prompt)
	var executions := _variant_to_string_array(summary.get("sdk_mcp_executions", []))
	summary["sdk_mcp_server_name"] = server_name
	summary["sdk_mcp_expected_executed"] = ["echo", "greet"]
	summary["ok"] = bool(summary.get("init_present", false)) \
		and _turn_summary_succeeded(summary.get("turn_summary", {})) \
		and executions.has("echo") \
		and executions.has("greet")
	return summary


func _run_sdk_mcp_without_permissions_smoke(args: Dictionary) -> Dictionary:
	var server_name := "sdknoperm"
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"max_turns": 2,
		"mcp_servers": {
			server_name: _create_sdk_mcp_server(server_name, true, false),
		},
	})
	var prompt := "Call the mcp__%s__echo tool with text 'parity'." % server_name
	var summary := await _run_sdk_mcp_client_smoke("sdk_mcp_without_permissions", options, prompt)
	var executions := _variant_to_string_array(summary.get("sdk_mcp_executions", []))
	summary["sdk_mcp_server_name"] = server_name
	summary["sdk_mcp_expected_not_executed"] = ["echo"]
	summary["ok"] = bool(summary.get("init_present", false)) \
		and str((summary.get("turn_summary", {}) as Dictionary).get("query_error", "")).is_empty() \
		and str((summary.get("turn_summary", {}) as Dictionary).get("stream_error", "")).is_empty() \
		and not executions.has("echo")
	return summary


func _run_mcp_status_smoke(args: Dictionary) -> Dictionary:
	var server_name := "sdkstatus"
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"mcp_servers": {
			server_name: _create_sdk_mcp_server(server_name, true, false),
		},
	})
	var client = ClaudeSDKClientScript.new(options)
	client.connect_client()
	var summary := await _wait_for_client_initialize("mcp_status", client)
	if not bool(summary.get("ok", false)):
		client.disconnect_client()
		return summary

	var control_errors: Array[String] = []
	var status = await _poll_mcp_status(client, server_name)
	_append_client_error(control_errors, client)
	client.disconnect_client()

	var server_status := _find_mcp_server_status(status, server_name)
	var tool_names: Array[String] = []
	var observed_status := ""
	if not server_status.is_empty():
		tool_names = _dictionary_string_array(server_status.get("tools", []))
		observed_status = str(server_status.get("status", ""))

	summary["control_errors"] = control_errors
	summary["mcp_status"] = _variant_to_dictionary(status)
	summary["mcp_status_typed"] = status is ClaudeMcpStatusResponse
	summary["mcp_status_error"] = control_errors[0] if not control_errors.is_empty() else ""
	summary["sdk_mcp_server_name"] = server_name
	summary["mcp_status_observed_status"] = observed_status
	summary["mcp_status_tool_names"] = tool_names
	summary["ok"] = bool(summary.get("init_present", false)) \
		and control_errors.is_empty() \
		and bool(summary.get("mcp_status_typed", false)) \
		and not server_status.is_empty() \
		and not observed_status.is_empty() \
		and tool_names.has("echo")
	status = null
	client = null
	await process_frame
	return summary


func _run_fork_session_resume_smoke(args: Dictionary) -> Dictionary:
	var project_dir := _create_temp_project_dir("fork_session_resume")
	var summary := _empty_summary("fork_session_resume")
	summary["project_dir"] = project_dir

	var source_options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"cwd": project_dir,
		"max_turns": 1,
		"effort": "low",
	})
	var source_prompt := "Reply with exactly: source fork ready"
	var source_summary := await _collect_stream_summary(
		"fork_session_resume_source",
		ClaudeQueryScript.query(source_prompt, source_options)
	)
	var source_session_id := str(source_summary.get("result_session_id", ""))
	var source_session_file := _session_storage_file_for_project(project_dir, source_session_id)

	var fork_options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"cwd": project_dir,
		"resume": source_session_id,
		"fork_session": true,
		"max_turns": 1,
		"effort": "low",
	})
	var fork_prompt := "Reply with exactly: fork parity ok"
	var fork_summary := _empty_summary("fork_session_resume_turn")
	if _summary_succeeded(source_summary) and not source_session_id.is_empty() and FileAccess.file_exists(source_session_file):
		fork_summary = await _collect_stream_summary(
			"fork_session_resume_turn",
			ClaudeQueryScript.query(fork_prompt, fork_options)
		)
	else:
		fork_summary["stream_error"] = "Could not create a real source session before running fork-session resume."

	var fork_session_id := str(fork_summary.get("result_session_id", ""))
	var fork_session_file := _session_storage_file_for_project(project_dir, fork_session_id)
	var source_exists := FileAccess.file_exists(source_session_file)
	var fork_exists := FileAccess.file_exists(fork_session_file)
	var source_contents := FileAccess.get_file_as_string(source_session_file) if source_exists else ""
	var fork_contents := FileAccess.get_file_as_string(fork_session_file) if fork_exists else ""

	_merge_turn_summary(summary, fork_summary)
	summary["source_session_id"] = source_session_id
	summary["source_session_file"] = source_session_file
	summary["source_session_file_exists"] = source_exists
	summary["fork_session_source_summary"] = source_summary
	summary["fork_session_id"] = fork_session_id
	summary["fork_session_file"] = fork_session_file
	summary["fork_session_file_exists"] = fork_exists
	summary["fork_session_new_id"] = not fork_session_id.is_empty() and fork_session_id != source_session_id
	summary["fork_session_source_preserved"] = source_exists
	summary["fork_session_file_contains_new_id"] = fork_exists and fork_contents.contains('"sessionId":"%s"' % fork_session_id)
	summary["fork_session_file_differs_from_source"] = source_exists and fork_exists and fork_contents != source_contents
	summary["fork_session_file_contains_prompt"] = fork_exists and fork_contents.contains(fork_prompt)
	summary["fork_session_file_contains_result_text"] = fork_exists and fork_contents.contains("fork parity ok")
	summary["turn_summaries"] = [source_summary, fork_summary]
	summary["ok"] = _summary_succeeded(source_summary) \
		and _summary_succeeded(fork_summary) \
		and bool(summary.get("fork_session_new_id", false)) \
		and bool(summary.get("fork_session_source_preserved", false)) \
		and bool(summary.get("fork_session_file_exists", false)) \
		and bool(summary.get("fork_session_file_contains_new_id", false)) \
		and bool(summary.get("fork_session_file_differs_from_source", false))
	return summary


func _run_external_mcp_reconnect_smoke(args: Dictionary) -> Dictionary:
	var server_name := "externalreconnect"
	var prepared := _prepare_external_mcp_fixture("external_mcp_reconnect", server_name, true)
	var summary: Dictionary = prepared.get("summary", _empty_summary("external_mcp_reconnect"))
	if not bool(prepared.get("ok", false)):
		return summary

	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
		"cwd": str(prepared.get("project_dir", "")),
		"max_turns": 2,
		"mcp_servers": {
			server_name: prepared.get("server_config", {}),
		},
		"allowed_tools": ["mcp__%s__%s" % [server_name, EXTERNAL_MCP_TOOL_NAME]],
	})
	var client = ClaudeSDKClientScript.new(options)
	client.connect_client()
	summary = await _wait_for_client_initialize("external_mcp_reconnect", client)
	_merge_external_mcp_prepared_summary(summary, prepared)
	if not bool(summary.get("ok", false)):
		client.disconnect_client()
		return summary

	var control_errors: Array[String] = []
	var pre_reconnect_status := await _poll_mcp_tool_availability(client, server_name, false, true)
	_append_client_error(control_errors, client)
	var sentinel_path := str(prepared.get("fail_sentinel_path", ""))
	if not sentinel_path.is_empty() and FileAccess.file_exists(sentinel_path):
		DirAccess.remove_absolute(sentinel_path)
	await process_frame

	client.reconnect_mcp_server(server_name)
	await process_frame
	_append_client_error(control_errors, client)
	var post_reconnect_status := await _poll_mcp_tool_availability(client, server_name, true)
	_append_client_error(control_errors, client)
	var reconnect_log_count_before := _read_external_mcp_invocations(str(prepared.get("log_path", ""))).size()
	var reconnect_turn := await _run_connected_client_turn(
		client,
		"external_mcp_reconnect_turn",
		"If the mcp__%s__%s tool is available, use it exactly once with text 'reconnect-success'. Otherwise answer only with unavailable." % [server_name, EXTERNAL_MCP_TOOL_NAME]
	)
	var reconnect_log_count_after := _read_external_mcp_invocations(str(prepared.get("log_path", ""))).size()
	client.disconnect_client()

	summary["control_errors"] = control_errors
	summary["turn_summaries"] = [reconnect_turn]
	summary["external_mcp_pre_reconnect_status"] = pre_reconnect_status
	summary["external_mcp_post_reconnect_status"] = post_reconnect_status
	summary["external_mcp_reconnect_log_count_before"] = reconnect_log_count_before
	summary["external_mcp_reconnect_log_count_after"] = reconnect_log_count_after
	summary["external_mcp_fail_sentinel_removed"] = not FileAccess.file_exists(sentinel_path)
	summary["ok"] = bool(summary.get("init_present", false)) \
		and control_errors.is_empty() \
		and not bool(pre_reconnect_status.get("tool_available", true)) \
		and bool(post_reconnect_status.get("tool_available", false)) \
		and bool(summary.get("external_mcp_fail_sentinel_removed", false)) \
		and _turn_summary_succeeded(reconnect_turn) \
		and reconnect_log_count_after > reconnect_log_count_before
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


func _run_sdk_mcp_client_smoke(mode: String, options: ClaudeAgentOptions, prompt: String) -> Dictionary:
	_sdk_mcp_executions.clear()
	var client = ClaudeSDKClientScript.new(options)
	client.connect_client()
	var summary := await _wait_for_client_initialize(mode, client)
	if not bool(summary.get("ok", false)):
		client.disconnect_client()
		summary["sdk_mcp_executions"] = _sdk_mcp_executions.duplicate()
		return summary

	var turn_summary := await _run_connected_client_turn(client, mode, prompt)
	client.disconnect_client()

	for key in [
		"message_types",
		"saw_stream_event",
		"assistant_present",
		"result_present",
		"result_is_error",
		"result_subtype",
		"result_errors",
		"result_num_turns",
		"result_session_id",
		"structured_output_present",
		"structured_output",
		"result_text",
		"query_error",
		"stream_error",
	]:
		summary[key] = turn_summary.get(key, summary.get(key))
	summary["control_errors"] = []
	summary["sdk_mcp_executions"] = _sdk_mcp_executions.duplicate()
	summary["turn_summary"] = turn_summary
	summary["turn_summaries"] = [turn_summary]
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


func _poll_mcp_status(client: ClaudeSDKClient, server_name: String, timeout_sec := 5.0):
	var timeout_at_usec := Time.get_ticks_usec() + int(timeout_sec * 1000000.0)
	var latest = null
	while Time.get_ticks_usec() < timeout_at_usec:
		latest = await client.get_mcp_status()
		var server_status := _find_mcp_server_status(latest, server_name)
		if not server_status.is_empty() and _dictionary_string_array(server_status.get("tools", [])).has("echo"):
			return latest
		if not client.get_last_error().is_empty():
			return latest
		await create_timer(0.2).timeout
	return latest


func _run_connected_client_turn(client: ClaudeSDKClient, label: String, prompt: String) -> Dictionary:
	client.query(prompt)
	var query_error := client.get_last_error()
	var summary := await _collect_stream_summary(label, client.receive_response())
	summary["query_error"] = query_error
	summary["ok"] = query_error.is_empty() and _turn_summary_succeeded(summary)
	return summary


func _merge_turn_summary(summary: Dictionary, turn_summary: Dictionary) -> void:
	for key in [
		"message_types",
		"saw_stream_event",
		"assistant_present",
		"result_present",
		"result_is_error",
		"result_subtype",
		"result_errors",
		"result_num_turns",
		"result_session_id",
		"structured_output_present",
		"structured_output",
		"result_text",
		"query_error",
		"stream_error",
	]:
		summary[key] = turn_summary.get(key, summary.get(key))
	summary["turn_summary"] = turn_summary
	summary["turn_summaries"] = [turn_summary]


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
	var init_commands: Array[String] = []
	var init_command_names: Array[String] = []
	var init_plugins: Array[String] = []
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
			init_commands = _extract_command_names(init_payload.get("commands", []))
			init_command_names = _normalize_command_names(init_commands)
			init_plugins = _extract_plugin_names(init_payload.get("plugins", []))
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
		"init_commands": init_commands,
		"init_command_names": init_command_names,
		"init_plugins": init_plugins,
		"init_agents": init_agents,
		"init_output_style": init_output_style,
		"assistant_present": assistant_present,
		"result_present": result_message != null,
		"result_is_error": false,
		"result_subtype": "",
		"result_errors": [],
		"result_num_turns": 0,
		"result_session_id": "",
		"structured_output_present": false,
		"structured_output": null,
		"result_text": "",
	}
	if result_message != null:
		summary["result_is_error"] = bool(result_message.is_error)
		summary["result_subtype"] = str(result_message.subtype)
		summary["result_errors"] = result_message.errors.duplicate(true)
		summary["result_num_turns"] = int(result_message.num_turns)
		summary["result_session_id"] = str(result_message.session_id)
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


func _prepare_current_user_relaunch(mode: String) -> Dictionary:
	var summary := _empty_summary(mode)
	if OS.get_name() == "Windows":
		summary["stream_error"] = "ClaudeAgentOptions.user live validation is unsupported on Windows; this smoke only validates the local POSIX sudo -n -u relaunch path."
		summary["user_resolution_source"] = "windows_unsupported"
		return {
			"ok": false,
			"summary": summary,
		}

	var resolved_user := _resolve_current_user_name()
	summary["user_resolved_name"] = str(resolved_user.get("user_name", ""))
	summary["user_resolution_source"] = str(resolved_user.get("source", ""))
	if not bool(resolved_user.get("ok", false)):
		summary["stream_error"] = str(resolved_user.get("error", "Could not resolve current user name"))
		return {
			"ok": false,
			"summary": summary,
		}

	var preflight := _preflight_same_user_relaunch(str(resolved_user.get("user_name", "")))
	summary["user_relaunch_preflight_ok"] = bool(preflight.get("ok", false))
	summary["user_relaunch_preflight_error"] = str(preflight.get("error", ""))
	if not bool(preflight.get("ok", false)):
		summary["stream_error"] = str(preflight.get("error", "Same-user sudo relaunch is unavailable"))
		return {
			"ok": false,
			"summary": summary,
		}

	return {
		"ok": true,
		"summary": summary,
		"user_name": str(resolved_user.get("user_name", "")),
		"user_resolution_source": str(resolved_user.get("source", "")),
		"user_relaunch_preflight_ok": true,
		"user_relaunch_preflight_error": "",
	}


func _resolve_current_user_name() -> Dictionary:
	if OS.get_name() == "Windows":
		return {
			"ok": false,
			"user_name": "",
			"source": "windows_unsupported",
			"error": "Current-user resolution for ClaudeAgentOptions.user live validation is unsupported on Windows.",
		}

	var command_sources := [
		{
			"path": "id",
			"args": PackedStringArray(["-un"]),
			"source": "id_un",
		},
		{
			"path": "whoami",
			"args": PackedStringArray(),
			"source": "whoami",
		},
	]
	for command_source in command_sources:
		var command_result := _run_command_capture(
			str(command_source.get("path", "")),
			command_source.get("args", PackedStringArray()) as PackedStringArray
		)
		var output := str(command_result.get("output", "")).strip_edges()
		if int(command_result.get("exit_code", -1)) == 0 and not output.is_empty():
			return {
				"ok": true,
				"user_name": output,
				"source": str(command_source.get("source", "")),
				"error": "",
			}

	for env_name in ["USER", "LOGNAME", "USERNAME"]:
		if OS.has_environment(env_name):
			var env_value := OS.get_environment(env_name).strip_edges()
			if not env_value.is_empty():
				return {
					"ok": true,
					"user_name": env_value,
					"source": "env_%s" % env_name.to_lower(),
					"error": "",
				}
	return {
		"ok": false,
		"user_name": "",
		"source": "unresolved",
		"error": "Could not resolve the current user name with id -un, whoami, or USER/LOGNAME/USERNAME.",
	}


func _preflight_same_user_relaunch(user_name: String) -> Dictionary:
	if user_name.is_empty():
		return {
			"ok": false,
			"error": "Cannot preflight same-user sudo relaunch without a resolved user name.",
		}
	var command_result := _run_command_capture(
		"sudo",
		PackedStringArray(["-n", "-u", user_name, "--", "/usr/bin/true"])
	)
	if int(command_result.get("exit_code", -1)) == 0:
		return {
			"ok": true,
			"error": "",
		}
	var output := str(command_result.get("output", "")).strip_edges()
	var detail := ": %s" % output if not output.is_empty() else ""
	return {
		"ok": false,
		"error": "Local same-user sudo -n -u relaunch is unavailable for `%s`%s" % [user_name, detail],
	}


func _run_command_capture(path: String, args: PackedStringArray) -> Dictionary:
	var output: Array[String] = []
	var exit_code := OS.execute(path, args, output, true)
	return {
		"exit_code": exit_code,
		"output": "\n".join(output).strip_edges(),
	}


func _resolve_node_command() -> Dictionary:
	for candidate in ["node"]:
		var result := _run_command_capture(candidate, PackedStringArray(["--version"]))
		if int(result.get("exit_code", -1)) == 0:
			return {
				"ok": true,
				"command": candidate,
				"error": "",
			}
	return {
		"ok": false,
		"command": "",
		"error": "Could not resolve a Node.js runtime with `node --version`.",
	}


func _prepare_external_mcp_fixture(mode: String, server_name: String, fail_at_startup: bool) -> Dictionary:
	var summary := _empty_summary(mode)
	var fixture_path := ProjectSettings.globalize_path(EXTERNAL_MCP_FIXTURE_SCRIPT)
	summary["external_mcp_fixture_path"] = fixture_path
	summary["sdk_mcp_server_name"] = server_name
	if not FileAccess.file_exists(fixture_path):
		summary["stream_error"] = "External MCP fixture script not found at %s" % fixture_path
		return {
			"ok": false,
			"summary": summary,
		}

	var node_command := _resolve_node_command()
	summary["external_mcp_command"] = str(node_command.get("command", ""))
	if not bool(node_command.get("ok", false)):
		summary["stream_error"] = str(node_command.get("error", ""))
		return {
			"ok": false,
			"summary": summary,
		}

	var project_dir := _create_temp_project_dir(mode)
	var log_path := project_dir.path_join("%s-invocations.jsonl" % server_name)
	var trace_path := project_dir.path_join("%s-trace.jsonl" % server_name)
	var fail_sentinel_path := project_dir.path_join("%s.fail" % server_name)
	if fail_at_startup:
		if not _write_text_file(fail_sentinel_path, "fail"):
			summary["stream_error"] = "Could not create external MCP fail sentinel"
			return {
				"ok": false,
				"summary": summary,
			}
	elif FileAccess.file_exists(fail_sentinel_path):
		DirAccess.remove_absolute(fail_sentinel_path)

	summary["external_mcp_log_path"] = log_path
	summary["external_mcp_trace_path"] = trace_path
	summary["external_mcp_fail_sentinel_path"] = fail_sentinel_path
	summary["external_mcp_fail_sentinel_present"] = FileAccess.file_exists(fail_sentinel_path)
	return {
		"ok": true,
		"summary": summary,
		"project_dir": project_dir,
		"log_path": log_path,
		"fail_sentinel_path": fail_sentinel_path,
		"server_config": {
			"type": "stdio",
			"command": str(node_command.get("command", "")),
			"args": [
				fixture_path,
				"--log-file",
				log_path,
				"--trace-file",
				trace_path,
				"--server-name",
				server_name,
				"--fail-sentinel",
				fail_sentinel_path,
			],
			"env": {
				"NODE_NO_WARNINGS": "1",
			},
		},
	}


func _merge_external_mcp_prepared_summary(summary: Dictionary, prepared: Dictionary) -> void:
	var prepared_summary: Dictionary = prepared.get("summary", {})
	for key in [
		"external_mcp_fixture_path",
		"external_mcp_log_path",
		"external_mcp_trace_path",
		"external_mcp_fail_sentinel_path",
		"external_mcp_fail_sentinel_present",
		"external_mcp_command",
	]:
		summary[key] = prepared_summary.get(key, summary.get(key))


func _poll_mcp_tool_availability(client: ClaudeSDKClient, server_name: String, expect_available: bool, require_server_seen := false, timeout_sec := 8.0) -> Dictionary:
	var timeout_at_usec := Time.get_ticks_usec() + int(timeout_sec * 1000000.0)
	var latest: Variant = null
	var latest_status := {}
	while Time.get_ticks_usec() < timeout_at_usec:
		latest = await client.get_mcp_status()
		latest_status = _find_mcp_server_status(latest, server_name)
		var tool_names := _dictionary_string_array(latest_status.get("tools", []))
		var tool_available := tool_names.has(EXTERNAL_MCP_TOOL_NAME)
		var server_seen := not latest_status.is_empty()
		if expect_available and server_seen and tool_available:
			return {
				"status_response": _variant_to_dictionary(latest),
				"server_status": latest_status,
				"server_seen": true,
				"tool_available": true,
				"tool_names": tool_names,
			}
		if not expect_available and server_seen == require_server_seen and not tool_available:
			return {
				"status_response": _variant_to_dictionary(latest),
				"server_status": latest_status,
				"server_seen": server_seen,
				"tool_available": tool_available,
				"tool_names": tool_names,
			}
		if not client.get_last_error().is_empty():
			break
		await create_timer(0.2).timeout

	var fallback_tool_names := _dictionary_string_array(latest_status.get("tools", []))
	return {
		"status_response": _variant_to_dictionary(latest),
		"server_status": latest_status,
		"server_seen": not latest_status.is_empty(),
		"tool_available": fallback_tool_names.has(EXTERNAL_MCP_TOOL_NAME),
		"tool_names": fallback_tool_names,
	}


func _read_external_mcp_invocations(path: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if path.is_empty() or not FileAccess.file_exists(path):
		return entries
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return entries
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			entries.append((parsed as Dictionary).duplicate(true))
	file.close()
	return entries


func _session_storage_file_for_project(project_path: String, session_id: String) -> String:
	if project_path.is_empty() or session_id.is_empty():
		return ""
	var resolved_project := ClaudeSessionsScript._resolve_absolute_path(project_path)
	var projects_dir := ClaudeSessionsScript._get_projects_dir()
	if resolved_project.is_empty() or projects_dir.is_empty():
		return ""
	return projects_dir.path_join(ClaudeSessionsScript._sanitize_path(resolved_project)).path_join("%s.jsonl" % session_id)


func _empty_summary(mode: String) -> Dictionary:
	return {
		"mode": mode,
		"ok": false,
		"message_types": [],
		"stream_error": "",
		"saw_stream_event": false,
		"init_present": false,
		"init_commands": [],
		"init_command_names": [],
		"init_plugins": [],
		"init_agents": [],
		"init_output_style": "",
		"assistant_present": false,
		"result_present": false,
		"result_is_error": false,
		"result_subtype": "",
		"result_errors": [],
		"result_num_turns": 0,
		"result_session_id": "",
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
		"model_reset_value": null,
		"sdk_mcp_executions": [],
		"sdk_mcp_server_name": "",
		"sdk_mcp_expected_executed": [],
		"sdk_mcp_expected_not_executed": [],
		"context_usage": {},
		"context_usage_typed": false,
		"context_usage_category_count": 0,
		"context_usage_model": "",
		"context_usage_total_tokens": 0,
		"context_usage_max_tokens": 0,
		"context_usage_percentage": 0.0,
		"context_usage_error": "",
		"mcp_status": {},
		"mcp_status_typed": false,
		"mcp_status_error": "",
		"mcp_status_observed_status": "",
		"mcp_status_tool_names": [],
		"external_mcp_fixture_path": "",
		"external_mcp_log_path": "",
		"external_mcp_trace_path": "",
		"external_mcp_fail_sentinel_path": "",
		"external_mcp_fail_sentinel_present": false,
		"external_mcp_command": "",
		"external_mcp_pre_reconnect_status": {},
		"external_mcp_post_reconnect_status": {},
		"external_mcp_reconnect_log_count_before": 0,
		"external_mcp_reconnect_log_count_after": 0,
		"external_mcp_fail_sentinel_removed": false,
		"plugin_fixture_path": "",
		"plugin_detected": false,
		"plugin_detected_via_commands": false,
		"plugin_detected_via_plugins": false,
		"user_resolved_name": "",
		"user_resolution_source": "",
		"user_relaunch_preflight_ok": false,
		"user_relaunch_preflight_error": "",
		"auth_status": {},
		"auth_status_logged_in": false,
		"turn_summary": {},
		"source_session_id": "",
		"source_session_file": "",
		"source_session_file_exists": false,
		"fork_session_source_summary": {},
		"fork_session_id": "",
		"fork_session_file": "",
		"fork_session_file_exists": false,
		"fork_session_new_id": false,
		"fork_session_source_preserved": false,
		"fork_session_file_contains_new_id": false,
		"fork_session_file_differs_from_source": false,
		"fork_session_file_contains_prompt": false,
		"fork_session_file_contains_result_text": false,
	}


func _extract_command_names(value: Variant) -> Array[String]:
	var names: Array[String] = []
	if value is not Array:
		return names
	for entry in value:
		if entry is Dictionary:
			names.append(str((entry as Dictionary).get("name", "")))
	return names


func _normalize_command_names(value: Variant) -> Array[String]:
	var names: Array[String] = []
	if value is not Array:
		return names
	for entry in value:
		names.append(str(entry).strip_edges().trim_prefix("/"))
	return names


func _extract_plugin_names(value: Variant) -> Array[String]:
	var names: Array[String] = []
	if value is not Array:
		return names
	for entry in value:
		if entry is Dictionary:
			names.append(str((entry as Dictionary).get("name", "")))
	return names


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


func _create_sdk_mcp_server(server_name: String, include_echo: bool, include_greet: bool):
	var tools: Array = []
	if include_echo:
		tools.append(ClaudeMcpScript.tool(
			"echo",
			"Echo back the input text.",
			ClaudeMcpScript.schema_object({
				"text": ClaudeMcpScript.schema_scalar("string", "Text to echo"),
			}, ["text"]),
			Callable(self, "_sdk_mcp_echo_tool")
		))
	if include_greet:
		tools.append(ClaudeMcpScript.tool(
			"greet",
			"Greet a person by name.",
			ClaudeMcpScript.schema_object({
				"name": ClaudeMcpScript.schema_scalar("string", "Name to greet"),
			}, ["name"]),
			Callable(self, "_sdk_mcp_greet_tool")
		))
	return ClaudeMcpScript.create_sdk_server(server_name, "1.0.0", tools)


func _sdk_mcp_echo_tool(arguments: Dictionary) -> Dictionary:
	_sdk_mcp_executions.append("echo")
	return {
		"content": [
			{
				"type": "text",
				"text": "Echo: %s" % str(arguments.get("text", "")),
			},
		],
	}


func _sdk_mcp_greet_tool(arguments: Dictionary) -> Dictionary:
	_sdk_mcp_executions.append("greet")
	return {
		"content": [
			{
				"type": "text",
				"text": "Hello, %s!" % str(arguments.get("name", "")),
			},
		],
	}


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


func _variant_to_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Object and value.has_method("to_dict"):
		var serialized: Variant = value.call("to_dict")
		if serialized is Dictionary:
			return (serialized as Dictionary).duplicate(true)
	return {}


func _find_mcp_server_status(status_response: Variant, server_name: String) -> Dictionary:
	var response_dict := _variant_to_dictionary(status_response)
	var servers: Variant = response_dict.get("mcpServers", response_dict.get("mcp_servers", []))
	if servers is not Array:
		return {}
	for server in servers:
		if server is not Dictionary:
			continue
		var server_dict := server as Dictionary
		if str(server_dict.get("name", "")) == server_name:
			return server_dict.duplicate(true)
	return {}


func _dictionary_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is not Array:
		return result
	for value in values:
		if value is Dictionary:
			result.append(str((value as Dictionary).get("name", "")))
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
