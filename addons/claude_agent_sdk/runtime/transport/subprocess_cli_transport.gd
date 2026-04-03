extends RefCounted
class_name ClaudeSubprocessCLITransport

const POLL_INTERVAL_SEC := 0.02
const POLL_INTERVAL_MSEC := 20
const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")

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
	var args := PackedStringArray([
		"--output-format", "stream-json",
		"--verbose",
		"--system-prompt", _options.system_prompt,
	])
	if not _options.allowed_tools.is_empty():
		args.append_array(["--allowedTools", ",".join(_options.allowed_tools)])
	if _options.max_turns > 0:
		args.append_array(["--max-turns", str(_options.max_turns)])
	if not _options.disallowed_tools.is_empty():
		args.append_array(["--disallowedTools", ",".join(_options.disallowed_tools)])
	if not _options.model.is_empty():
		args.append_array(["--model", _options.model])
	if not _options.permission_mode.is_empty():
		args.append_array(["--permission-mode", _options.permission_mode])
	if not _options.resume.is_empty():
		args.append_array(["--resume", _options.resume])
	if not _options.session_id.is_empty():
		args.append_array(["--session-id", _options.session_id])
	if not _options.effort.is_empty():
		args.append_array(["--effort", _options.effort])
	args.append_array(["--input-format", "stream-json"])
	return args


func build_process_spec() -> Dictionary:
	var logical_args := build_command_args()
	if OS.get_name() == "Windows":
		return {
			"path": "cmd.exe",
			"args": PackedStringArray(["/C", _build_windows_shell_script(logical_args)]),
			"logical_path": _options.cli_path,
			"logical_args": logical_args,
		}
	return {
		"path": "/bin/sh",
		"args": PackedStringArray(["-lc", _build_posix_shell_script(logical_args)]),
		"logical_path": _options.cli_path,
		"logical_args": logical_args,
	}


func open_transport() -> bool:
	if _connected:
		return true
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_set_last_error("ClaudeSubprocessCLITransport requires an active SceneTree")
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
		_set_last_error("Failed to launch Claude CLI process")
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
		_set_last_error("Cannot write to Claude CLI before transport is connected")
		return false
	_io_mutex.lock()
	_stdio.store_line(payload)
	_stdio.flush()
	var write_error: int = _stdio.get_error()
	_io_mutex.unlock()
	if write_error != OK:
		_set_last_error("Failed to write to Claude CLI stdin: %s" % error_string(write_error))
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
	if not _options.env.is_empty():
		parts.append("env")
		for key_variant in _options.env.keys():
			var key := str(key_variant)
			parts.append("%s=%s" % [key, _quote_posix(str(_options.env[key_variant]))])
	parts.append("exec")
	parts.append(_quote_posix(_options.cli_path))
	for argument in logical_args:
		parts.append(_quote_posix(argument))
	return " ".join(parts)


func _build_windows_shell_script(logical_args: PackedStringArray) -> String:
	var commands: Array[String] = []
	if not _options.cwd.is_empty():
		commands.append("cd /d %s" % _quote_windows(_options.cwd))
	for key_variant in _options.env.keys():
		var key := str(key_variant)
		commands.append("set %s=%s" % [_quote_windows_assignment(key), _quote_windows_assignment(str(_options.env[key_variant]))])
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


func _start_reader_threads() -> void:
	_stdout_thread = Thread.new()
	_stdout_thread.start(_read_pipe.bind("stdout"))
	_stderr_thread = Thread.new()
	_stderr_thread.start(_read_pipe.bind("stderr"))


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
	for message in errors:
		_set_last_error(message)


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
	push_error(message)
	transport_error.emit(message)


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
