extends RefCounted
class_name ClaudeSubprocessCLITransport

const POLL_INTERVAL_SEC := 0.02
const POLL_INTERVAL_MSEC := 20
const SDK_ENTRYPOINT := "sdk-gd"
const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeSDKVersionScript := preload("res://addons/claude_agent_sdk/runtime/claude_sdk_version.gd")

signal stdout_line(line: String)
signal stderr_line(line: String)
signal transport_closed
signal transport_error(message: String)

var _options = null
var _process: Dictionary = {}
var _stdio = null
var _stderr = null
var _pid := 0
var _connected := false
var _stop_requested := false
var _close_emitted := false
var _dispatch_running := false
var _stdout_done := false
var _stderr_done := false
var _io_mutex := Mutex.new()
var _queue_mutex := Mutex.new()
var _stdout_thread: Thread = null
var _stderr_thread: Thread = null
var _pending_stdout_lines: Array[String] = []
var _pending_stderr_lines: Array[String] = []
var _pending_errors: Array[String] = []
var _last_error := ""


func _init(options = null) -> void:
	_options = options if options != null else ClaudeAgentOptionsScript.new()


func build_command_args() -> PackedStringArray:
	if not _validate_supported_options():
		return PackedStringArray()
	var args := PackedStringArray([
		"--output-format", "stream-json",
		"--verbose",
	])
	_append_system_prompt_args(args)
	_append_tools_args(args)
	if not _options.allowed_tools.is_empty():
		args.append_array(["--allowedTools", ",".join(_options.allowed_tools)])
	if _options.max_turns > 0:
		args.append_array(["--max-turns", str(_options.max_turns)])
	if _options.max_budget_usd != null:
		args.append_array(["--max-budget-usd", str(_options.max_budget_usd)])
	if not _options.disallowed_tools.is_empty():
		args.append_array(["--disallowedTools", ",".join(_options.disallowed_tools)])
	if _options.task_budget is Dictionary and (_options.task_budget as Dictionary).has("total"):
		args.append_array(["--task-budget", str(int((_options.task_budget as Dictionary).get("total", 0)))])
	if not _options.model.is_empty():
		args.append_array(["--model", _options.model])
	if not _options.fallback_model.is_empty():
		args.append_array(["--fallback-model", _options.fallback_model])
	if not _options.betas.is_empty():
		args.append_array(["--betas", ",".join(_options.betas)])
	var permission_prompt_tool_name := _resolved_permission_prompt_tool_name()
	if not permission_prompt_tool_name.is_empty():
		args.append_array(["--permission-prompt-tool", permission_prompt_tool_name])
	if not _options.permission_mode.is_empty():
		args.append_array(["--permission-mode", _options.permission_mode])
	if _options.continue_conversation:
		args.append("--continue")
	if not _options.resume.is_empty():
		args.append_array(["--resume", _options.resume])
	if not _options.session_id.is_empty():
		args.append_array(["--session-id", _options.session_id])
	var settings_value := _build_settings_argument()
	if not settings_value.is_empty():
		args.append_array(["--settings", settings_value])
	if not _options.add_dirs.is_empty():
		for directory in _options.add_dirs:
			args.append_array(["--add-dir", directory])
	var json_schema := _build_json_schema_argument()
	if not json_schema.is_empty():
		args.append_array(["--json-schema", json_schema])
	var mcp_config := _build_mcp_config_argument()
	if not mcp_config.is_empty():
		args.append_array(["--mcp-config", mcp_config])
	if _options.include_partial_messages:
		args.append("--include-partial-messages")
	if _options.fork_session:
		args.append("--fork-session")
	if not _options.setting_sources.is_empty():
		args.append_array(["--setting-sources", ",".join(_options.setting_sources)])
	_append_plugin_args(args)
	_append_extra_args(args)
	var resolved_max_thinking_tokens := _resolved_max_thinking_tokens()
	if resolved_max_thinking_tokens != null:
		args.append_array(["--max-thinking-tokens", str(int(resolved_max_thinking_tokens))])
	if not _options.effort.is_empty():
		args.append_array(["--effort", _options.effort])
	args.append_array(["--input-format", "stream-json"])
	return args


func _append_system_prompt_args(args: PackedStringArray) -> void:
	var system_prompt: Variant = _options.system_prompt
	if system_prompt == null:
		args.append_array(["--system-prompt", ""])
		return
	if system_prompt is Dictionary:
		var prompt_config := system_prompt as Dictionary
		var prompt_type := str(prompt_config.get("type", "")).strip_edges()
		match prompt_type:
			"preset":
				var append_text := str(prompt_config.get("append", ""))
				if not append_text.is_empty():
					args.append_array(["--append-system-prompt", append_text])
			"file":
				var prompt_path := _resolve_system_prompt_file_path(str(prompt_config.get("path", "")).strip_edges())
				if prompt_path.is_empty():
					args.append_array(["--system-prompt", ""])
				else:
					args.append_array(["--system-prompt-file", prompt_path])
			_:
				args.append_array(["--system-prompt", ""])
		return
	args.append_array(["--system-prompt", str(system_prompt)])


func _append_tools_args(args: PackedStringArray) -> void:
	var tools_config: Variant = _options.tools
	if tools_config == null:
		return
	if tools_config is Array:
		var tool_names: Array[String] = []
		for tool_name_variant in tools_config:
			tool_names.append(str(tool_name_variant))
		args.append_array(["--tools", "" if tool_names.is_empty() else ",".join(tool_names)])
		return
	if tools_config is Dictionary:
		var tool_config := tools_config as Dictionary
		if str(tool_config.get("type", "")) == "preset":
			args.append_array(["--tools", "default"])


func _resolve_system_prompt_file_path(path: String) -> String:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty():
		return ""
	return _resolve_project_path(normalized_path)


func _resolve_project_path(path: String) -> String:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty():
		return ""
	if normalized_path.begins_with("res://") or normalized_path.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized_path)
	return normalized_path


func build_process_spec() -> Dictionary:
	var logical_args := build_command_args()
	return _build_process_spec_for_args(logical_args)


func build_environment_overrides() -> Dictionary:
	var overrides := {
		"CLAUDE_CODE_ENTRYPOINT": SDK_ENTRYPOINT,
		"CLAUDE_AGENT_SDK_VERSION": ClaudeSDKVersionScript.get_version(),
	}
	if not _options.cwd.is_empty():
		overrides["PWD"] = _options.cwd
	for key_variant in _options.env.keys():
		overrides[str(key_variant)] = str(_options.env[key_variant])
	if _options.enable_file_checkpointing:
		overrides["CLAUDE_CODE_ENABLE_SDK_FILE_CHECKPOINTING"] = "true"
	return overrides


func filters_inherited_claudecode() -> bool:
	return not _options.env.has("CLAUDECODE")


func probe_auth_status() -> Dictionary:
	if not _validate_supported_options():
		return _build_auth_status_error_result("command_failed", _last_error, -1, "", "")

	var spec := _build_process_spec_for_args(PackedStringArray(["auth", "status"]))
	var process := OS.execute_with_pipe(str(spec.get("path", "")), spec.get("args", PackedStringArray()), false)
	if process.is_empty():
		return _build_auth_status_error_result("command_failed", "Failed to launch Claude auth status command", -1, "", "")

	var stdio: FileAccess = process.get("stdio")
	var stderr: FileAccess = process.get("stderr")
	var pid := int(process.get("pid", 0))
	if stdio != null:
		stdio.flush()

	while pid > 0 and OS.is_process_running(pid):
		OS.delay_msec(POLL_INTERVAL_MSEC)

	var stdout_text := _read_pipe_text(stdio)
	var stderr_text := _read_pipe_text(stderr)
	var exit_code := OS.get_process_exit_code(pid) if pid > 0 else 0
	var parser := JSON.new()
	var parse_error := ERR_PARSE_ERROR
	var parsed: Variant = null
	var trimmed_stdout := stdout_text.strip_edges()
	if not trimmed_stdout.is_empty() and trimmed_stdout.begins_with("{"):
		parse_error = parser.parse(stdout_text)
		if parse_error == OK:
			parsed = parser.data
	if parsed is Dictionary and (parsed as Dictionary).has("loggedIn"):
		var payload: Dictionary = parsed
		var logged_in := bool(payload.get("loggedIn", false))
		var result := {
			"ok": logged_in,
			"error_code": "" if logged_in else "logged_out",
			"error_message": "" if logged_in else "Claude CLI is not logged in",
			"exit_code": exit_code,
			"logged_in": logged_in,
			"auth_method": str(payload.get("authMethod", "")),
			"api_provider": str(payload.get("apiProvider", "")),
			"email": str(payload.get("email", "")),
			"org_id": str(payload.get("orgId", "")),
			"org_name": str(payload.get("orgName", "")),
			"subscription_type": str(payload.get("subscriptionType", "")),
			"raw": payload.duplicate(true),
			"stdout": stdout_text,
			"stderr": stderr_text,
		}
		return result

	if exit_code != 0:
		return _build_auth_status_error_result(
			_classify_auth_probe_failure(exit_code, stdout_text, stderr_text),
			_build_command_failure_message(exit_code, stderr_text, stdout_text),
			exit_code,
			stdout_text,
			stderr_text
		)

	if trimmed_stdout.is_empty() or not trimmed_stdout.begins_with("{"):
		return _build_auth_status_error_result(
			"json_parse_failed",
			"Failed to parse Claude auth status JSON output",
			exit_code,
			stdout_text,
			stderr_text
		)

	if parsed is not Dictionary:
		return _build_auth_status_error_result(
			"json_parse_failed",
			"Failed to parse Claude auth status JSON output%s" % (
				": %s" % parser.get_error_message() if parse_error != OK and not parser.get_error_message().is_empty() else ""
			),
			exit_code,
			stdout_text,
			stderr_text
		)
	return _build_auth_status_error_result(
		"json_parse_failed",
		"Claude auth status output did not contain a loggedIn field",
		exit_code,
		stdout_text,
		stderr_text
	)


func _build_process_spec_for_args(logical_args: PackedStringArray) -> Dictionary:
	if OS.get_name() == "Windows":
		return {
			"path": "cmd.exe",
			"args": PackedStringArray(["/C", _build_windows_shell_script(logical_args)]),
			"logical_path": _options.cli_path,
			"logical_args": logical_args,
		}
	var shell_script := _build_posix_shell_script(logical_args)
	var requested_user := _requested_user()
	if not requested_user.is_empty():
		return {
			"path": "sudo",
			"args": PackedStringArray(["-n", "-u", requested_user, "--", "/bin/sh", "-lc", shell_script]),
			"logical_path": _options.cli_path,
			"logical_args": logical_args,
		}
	return {
		"path": "/bin/sh",
		"args": PackedStringArray(["-lc", shell_script]),
		"logical_path": _options.cli_path,
		"logical_args": logical_args,
	}


func open_transport() -> bool:
	if _connected:
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_report_transport_error("ClaudeSubprocessCLITransport requires an active SceneTree", true, false)
		return false
	if not _validate_supported_options():
		return false

	_stop_requested = false
	_close_emitted = false
	_stdout_done = false
	_stderr_done = false
	_pending_stdout_lines.clear()
	_pending_stderr_lines.clear()
	_pending_errors.clear()

	var spec := build_process_spec()
	_process = OS.execute_with_pipe(str(spec.get("path", "")), spec.get("args", PackedStringArray()), false)
	if _process.is_empty():
		_report_transport_error("Failed to launch Claude CLI process", true, false)
		return false

	_stdio = _process["stdio"]
	_stderr = _process["stderr"]
	_pid = int(_process.get("pid", 0))
	_connected = true
	_start_reader_threads()
	_run_dispatch_loop(tree)
	return true


func write(payload: String) -> bool:
	if not _connected or _stdio == null:
		_report_transport_error("Cannot write to Claude CLI before transport is connected", true, false)
		return false
	_io_mutex.lock()
	_stdio.store_line(payload)
	_stdio.flush()
	var write_error: int = _stdio.get_error()
	_io_mutex.unlock()
	if write_error != OK:
		_report_transport_error("Failed to write to Claude CLI stdin: %s" % error_string(write_error), true, false)
		return false
	return true


func close() -> void:
	_stop_requested = true
	_close_pipes()
	_wait_for_reader_threads()
	_wait_for_process_exit()
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_wait_for_reader_threads()
	_connected = false
	_emit_closed_once()


func transport_is_connected() -> bool:
	return _connected


func get_pid() -> int:
	return _pid


func get_last_error() -> String:
	return _last_error


func _build_posix_shell_script(logical_args: PackedStringArray) -> String:
	var parts: Array[String] = []
	if not _options.cwd.is_empty():
		parts.append("cd %s &&" % _quote_posix(_options.cwd))
	var env_overrides := build_environment_overrides()
	parts.append("exec")
	if filters_inherited_claudecode() or not env_overrides.is_empty():
		parts.append("env")
		if filters_inherited_claudecode():
			parts.append("-u")
			parts.append("CLAUDECODE")
		for key_variant in env_overrides.keys():
			var key := str(key_variant)
			parts.append("%s=%s" % [key, _quote_posix(str(env_overrides[key_variant]))])
	parts.append(_quote_posix(_options.cli_path))
	for argument in logical_args:
		parts.append(_quote_posix(argument))
	return " ".join(parts)


func _build_windows_shell_script(logical_args: PackedStringArray) -> String:
	var commands: Array[String] = []
	if not _options.cwd.is_empty():
		commands.append("cd /d %s" % _quote_windows(_options.cwd))
	if filters_inherited_claudecode():
		commands.append("set CLAUDECODE=")
	var env_overrides := build_environment_overrides()
	for key_variant in env_overrides.keys():
		var key := str(key_variant)
		commands.append("set %s=%s" % [_quote_windows_assignment(key), _quote_windows_assignment(str(env_overrides[key_variant]))])
	var command_parts: Array[String] = [_quote_windows(_options.cli_path)]
	for argument in logical_args:
		command_parts.append(_quote_windows(argument))
	commands.append(" ".join(command_parts))
	return " && ".join(commands)


func _quote_posix(value: String) -> String:
	return "'" + value.replace("'", "'\"'\"'") + "'"


func _quote_windows(value: String) -> String:
	return "\"" + value.replace("\"", "\"\"") + "\""


func _quote_windows_assignment(value: String) -> String:
	return value.replace("^", "^^").replace("&", "^&").replace("|", "^|").replace("<", "^<").replace(">", "^>")


func _validate_supported_options() -> bool:
	if _options.can_use_tool.is_valid() and not _options.permission_prompt_tool_name.is_empty():
		_set_last_error("can_use_tool callback cannot be used with permission_prompt_tool_name. Please use one or the other.")
		return false
	if OS.get_name() == "Windows" and not _requested_user().is_empty():
		_set_last_error("ClaudeAgentOptions.user is currently supported only on POSIX shell-backed transports.")
		return false
	for plugin_config_variant in _options.plugins:
		if plugin_config_variant is not Dictionary:
			_set_last_error("plugins entries must be dictionaries with type and path keys.")
			return false
		var plugin_config := plugin_config_variant as Dictionary
		if str(plugin_config.get("type", "")).strip_edges() != "local":
			_set_last_error("Only local plugin configs are supported in this slice.")
			return false
		if str(plugin_config.get("path", "")).strip_edges().is_empty():
			_set_last_error("Plugin configs must include a non-empty path.")
			return false
	_set_last_error("")
	return true


func _resolved_permission_prompt_tool_name() -> String:
	if _options.can_use_tool.is_valid():
		return "stdio"
	return _options.permission_prompt_tool_name


func _requested_user() -> String:
	return _options.user.strip_edges()


func _resolved_max_thinking_tokens() -> Variant:
	var resolved: Variant = _options.max_thinking_tokens
	if _options.thinking is Dictionary:
		var thinking_config := _options.thinking as Dictionary
		match str(thinking_config.get("type", "")):
			"adaptive":
				if resolved == null:
					resolved = 32000
			"enabled":
				resolved = int(thinking_config.get("budget_tokens", 0))
			"disabled":
				resolved = 0
	return resolved


func _build_settings_argument() -> String:
	var has_settings: bool = not str(_options.settings).is_empty()
	var has_sandbox: bool = _options.sandbox is Dictionary
	if not has_settings and not has_sandbox:
		return ""
	if has_settings and not has_sandbox:
		if _looks_like_json_object(str(_options.settings)):
			return str(_options.settings)
		return _resolve_project_path(str(_options.settings))

	var merged_settings: Dictionary = {}
	if has_settings:
		var raw_settings := str(_options.settings)
		if _looks_like_json_object(raw_settings):
			var parsed_settings := _parse_json_dictionary(raw_settings)
			if parsed_settings is Dictionary:
				merged_settings = (parsed_settings as Dictionary).duplicate(true)
		else:
			var settings_path := _resolve_project_path(raw_settings)
			var file_settings := _load_settings_dictionary_from_path(settings_path)
			if file_settings is Dictionary:
				merged_settings = (file_settings as Dictionary).duplicate(true)
	if has_sandbox:
		merged_settings["sandbox"] = _serialize_sandbox_config(_options.sandbox as Dictionary)
	return JSON.stringify(merged_settings)


func _looks_like_json_object(value: String) -> bool:
	var trimmed := value.strip_edges()
	return not trimmed.is_empty() and trimmed.begins_with("{") and trimmed.ends_with("}")


func _parse_json_dictionary(value: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(value) != OK:
		return null
	if parser.data is Dictionary:
		return parser.data
	return null


func _load_settings_dictionary_from_path(path: String) -> Variant:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var contents := file.get_as_text()
	return _parse_json_dictionary(contents)


func _serialize_sandbox_config(config: Dictionary) -> Dictionary:
	var serialized: Dictionary = {}
	if config.has("enabled"):
		serialized["enabled"] = bool(config["enabled"])
	if config.has("auto_allow_bash_if_sandboxed"):
		serialized["autoAllowBashIfSandboxed"] = bool(config["auto_allow_bash_if_sandboxed"])
	if config.has("excluded_commands"):
		serialized["excludedCommands"] = (config["excluded_commands"] as Array).duplicate()
	if config.has("allow_unsandboxed_commands"):
		serialized["allowUnsandboxedCommands"] = bool(config["allow_unsandboxed_commands"])
	if config.has("network") and config["network"] is Dictionary:
		serialized["network"] = _serialize_sandbox_network(config["network"] as Dictionary)
	if config.has("ignore_violations") and config["ignore_violations"] is Dictionary:
		serialized["ignoreViolations"] = _serialize_sandbox_ignore_violations(config["ignore_violations"] as Dictionary)
	if config.has("enable_weaker_nested_sandbox"):
		serialized["enableWeakerNestedSandbox"] = bool(config["enable_weaker_nested_sandbox"])
	return serialized


func _serialize_sandbox_network(config: Dictionary) -> Dictionary:
	var serialized: Dictionary = {}
	if config.has("allow_unix_sockets"):
		serialized["allowUnixSockets"] = (config["allow_unix_sockets"] as Array).duplicate()
	if config.has("allow_all_unix_sockets"):
		serialized["allowAllUnixSockets"] = bool(config["allow_all_unix_sockets"])
	if config.has("allow_local_binding"):
		serialized["allowLocalBinding"] = bool(config["allow_local_binding"])
	if config.has("http_proxy_port"):
		serialized["httpProxyPort"] = int(config["http_proxy_port"])
	if config.has("socks_proxy_port"):
		serialized["socksProxyPort"] = int(config["socks_proxy_port"])
	return serialized


func _serialize_sandbox_ignore_violations(config: Dictionary) -> Dictionary:
	var serialized: Dictionary = {}
	if config.has("file"):
		serialized["file"] = (config["file"] as Array).duplicate()
	if config.has("network"):
		serialized["network"] = (config["network"] as Array).duplicate()
	return serialized


func _build_json_schema_argument() -> String:
	if _options.output_format.is_empty():
		return ""
	if str(_options.output_format.get("type", "")) != "json_schema":
		return ""
	var schema: Variant = _options.output_format.get("schema")
	if schema == null:
		return ""
	return JSON.stringify(schema)


func _build_mcp_config_argument() -> String:
	if _options.mcp_servers is Dictionary and not _options.mcp_servers.is_empty():
		var external_servers: Dictionary = {}
		for server_name_variant in (_options.mcp_servers as Dictionary).keys():
			var server_config: Variant = (_options.mcp_servers as Dictionary)[server_name_variant]
			if server_config is Dictionary and str((server_config as Dictionary).get("type", "")) == "sdk":
				continue
			external_servers[str(server_name_variant)] = server_config
		if external_servers.is_empty():
			return ""
		return JSON.stringify({
			"mcpServers": external_servers,
		})
	if _options.mcp_servers is String and not str(_options.mcp_servers).is_empty():
		return str(_options.mcp_servers)
	return ""


func _append_plugin_args(args: PackedStringArray) -> void:
	if _options.plugins.is_empty():
		return
	for plugin_config_variant in _options.plugins:
		var plugin_config := plugin_config_variant as Dictionary
		var plugin_path := _resolve_project_path(str(plugin_config.get("path", "")).strip_edges())
		if plugin_path.is_empty():
			continue
		args.append_array(["--plugin-dir", plugin_path])


func _append_extra_args(args: PackedStringArray) -> void:
	if not (_options.extra_args is Dictionary) or (_options.extra_args as Dictionary).is_empty():
		return
	for key_variant in (_options.extra_args as Dictionary).keys():
		var flag_name := str(key_variant).strip_edges()
		if flag_name.is_empty():
			continue
		args.append("--%s" % flag_name)
		var value: Variant = (_options.extra_args as Dictionary)[key_variant]
		if value != null:
			args.append(str(value))


func _start_reader_threads() -> void:
	_stdout_thread = Thread.new()
	_stdout_thread.start(_read_pipe.bind("stdout"))
	_stderr_thread = Thread.new()
	_stderr_thread.start(_read_pipe.bind("stderr"))


func _should_consume_stderr() -> bool:
	if _options.stderr.is_valid():
		return true
	if _options.extra_args is Dictionary:
		return (_options.extra_args as Dictionary).has("debug-to-stderr")
	return false


func _read_pipe(stream_name: String) -> void:
	var pipe: FileAccess = _stdio if stream_name == "stdout" else _stderr
	if pipe == null:
		_queue_error("Missing %s pipe for Claude CLI transport" % stream_name)
		_mark_pipe_done(stream_name)
		return

	while not _stop_requested:
		_io_mutex.lock()
		var line: String = pipe.get_line()
		var read_error: int = pipe.get_error()
		_io_mutex.unlock()

		if read_error == OK:
			if not line.is_empty():
				if stream_name == "stderr" and not _should_consume_stderr():
					continue
				_queue_line(stream_name, line)
				continue
		elif read_error == ERR_FILE_EOF:
			break

		OS.delay_msec(POLL_INTERVAL_MSEC)

	_mark_pipe_done(stream_name)


func _queue_line(stream_name: String, line: String) -> void:
	_queue_mutex.lock()
	if stream_name == "stdout":
		_pending_stdout_lines.append(line)
	else:
		_pending_stderr_lines.append(line)
	_queue_mutex.unlock()


func _queue_error(message: String) -> void:
	_queue_mutex.lock()
	_pending_errors.append(message)
	_queue_mutex.unlock()


func _mark_pipe_done(stream_name: String) -> void:
	_queue_mutex.lock()
	if stream_name == "stdout":
		_stdout_done = true
	else:
		_stderr_done = true
	_queue_mutex.unlock()


func _run_dispatch_loop(tree: SceneTree) -> void:
	if _dispatch_running:
		return
	_dispatch_running = true
	while true:
		_drain_pending_events()
		if _should_finish_dispatch_loop():
			break
		await tree.create_timer(POLL_INTERVAL_SEC).timeout
	_drain_pending_events()
	_dispatch_running = false
	_connected = false
	_emit_closed_once()


func _drain_pending_events() -> void:
	var stdout_lines: Array[String] = []
	var stderr_lines: Array[String] = []
	var errors: Array[String] = []

	_queue_mutex.lock()
	stdout_lines = _pending_stdout_lines.duplicate()
	stderr_lines = _pending_stderr_lines.duplicate()
	errors = _pending_errors.duplicate()
	_pending_stdout_lines.clear()
	_pending_stderr_lines.clear()
	_pending_errors.clear()
	_queue_mutex.unlock()

	for line in stdout_lines:
		stdout_line.emit(line)
	for line in stderr_lines:
		stderr_line.emit(line)
		if _options.stderr.is_valid() and not line.is_empty():
			_options.stderr.call_deferred(line)
	for message in errors:
		_report_transport_error(message, true, true)


func _should_finish_dispatch_loop() -> bool:
	_queue_mutex.lock()
	var finished := _stop_requested or (
		_stdout_done
		and _stderr_done
		and _pending_stdout_lines.is_empty()
		and _pending_stderr_lines.is_empty()
		and _pending_errors.is_empty()
	)
	_queue_mutex.unlock()
	return finished


func _emit_closed_once() -> void:
	if _close_emitted:
		return
	_close_emitted = true
	transport_closed.emit()


func _set_last_error(message: String) -> void:
	_last_error = message


func _report_transport_error(message: String, log_engine_error: bool, emit_signal: bool) -> void:
	_set_last_error(message)
	if log_engine_error:
		push_error(message)
	if emit_signal:
		transport_error.emit(message)


func _read_pipe_text(pipe: FileAccess) -> String:
	if pipe == null:
		return ""
	var text := pipe.get_as_text()
	pipe.close()
	return text.strip_edges()


func _classify_auth_probe_failure(exit_code: int, stdout_text: String, stderr_text: String) -> String:
	var combined := "%s\n%s" % [stdout_text.to_lower(), stderr_text.to_lower()]
	if exit_code == 127 or combined.contains("not found") or combined.contains("is not recognized"):
		return "binary_not_found"
	return "command_failed"


func _build_command_failure_message(exit_code: int, stderr_text: String, stdout_text: String) -> String:
	var detail := stderr_text if not stderr_text.is_empty() else stdout_text
	if detail.is_empty():
		return "Claude auth status command failed with exit code %d" % exit_code
	return "Claude auth status command failed with exit code %d: %s" % [exit_code, detail]


func _build_auth_status_error_result(error_code: String, error_message: String, exit_code: int, stdout_text: String, stderr_text: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"error_message": error_message,
		"exit_code": exit_code,
		"logged_in": false,
		"auth_method": "",
		"api_provider": "",
		"email": "",
		"org_id": "",
		"org_name": "",
		"subscription_type": "",
		"raw": {},
		"stdout": stdout_text,
		"stderr": stderr_text,
	}


func _close_pipes() -> void:
	_io_mutex.lock()
	if _stdio != null:
		_stdio.close()
		_stdio = null
	if _stderr != null:
		_stderr.close()
		_stderr = null
	_io_mutex.unlock()


func _wait_for_reader_threads() -> void:
	if _stdout_thread != null:
		_stdout_thread.wait_to_finish()
		_stdout_thread = null
	if _stderr_thread != null:
		_stderr_thread.wait_to_finish()
		_stderr_thread = null


func _wait_for_process_exit() -> void:
	if _pid <= 0:
		return
	var attempts := 0
	while attempts < 10 and OS.is_process_running(_pid):
		OS.delay_msec(POLL_INTERVAL_MSEC)
		attempts += 1
