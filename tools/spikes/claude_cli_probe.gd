extends RefCounted

const DEFAULT_CLAUDE_PATH := "claude"
const TIMEOUT_MS := 15000
const POLL_INTERVAL_SEC := 0.05


func build_command_args() -> PackedStringArray:
    return PackedStringArray([
        "--output-format", "stream-json",
        "--verbose",
        "--system-prompt", "",
        "--tools", "",
        "--model", "haiku",
        "--effort", "low",
        "--max-turns", "1",
        "--input-format", "stream-json",
    ])


func resolve_claude_path(cmdline_args: PackedStringArray) -> String:
    var env_path := OS.get_environment("CLAUDE_PATH")
    if not env_path.is_empty():
        return env_path

    for arg in cmdline_args:
        if arg.begins_with("--claude-path="):
            return arg.trim_prefix("--claude-path=")

    return DEFAULT_CLAUDE_PATH


func build_initialize_message() -> String:
    return JSON.stringify({
        "type": "control_request",
        "request_id": "req_probe_initialize",
        "request": {
            "subtype": "initialize",
            "hooks": null,
        },
    })


func build_user_message() -> String:
    return JSON.stringify({
        "type": "user",
        "session_id": "",
        "message": {
            "role": "user",
            "content": "What is 2 + 2? Answer only with the number.",
        },
        "parent_tool_use_id": null,
    })


func run(tree: MainLoop, cmdline_args: PackedStringArray) -> Dictionary:
    var stdout_lines: Array[String] = []
    var stderr_lines: Array[String] = []
    var parsed_messages: Array[Dictionary] = []

    var claude_path := resolve_claude_path(cmdline_args)
    var process := OS.execute_with_pipe(claude_path, build_command_args(), false)
    if process.is_empty():
        push_error("Failed to create Claude process with redirected IO for path: %s" % claude_path)
        return {
            "launched": false,
            "claude_path": claude_path,
            "error": "process_create_failed",
        }

    var stdio: FileAccess = process["stdio"]
    var stderr: FileAccess = process["stderr"]
    var pid: int = process["pid"]

    print("Probe: launched Claude with pid=%d path=%s" % [pid, claude_path])

    stdio.store_line(build_initialize_message())
    stdio.store_line(build_user_message())
    stdio.flush()

    var started_ms := Time.get_ticks_msec()
    var saw_control_response := false
    var saw_init := false
    var saw_assistant := false
    var saw_result := false

    while Time.get_ticks_msec() - started_ms < TIMEOUT_MS:
        var stdout_batch := _drain_available_lines(stdio)
        var stderr_batch := _drain_available_lines(stderr)

        for line in stdout_batch:
            stdout_lines.append(line)
            print("STDOUT %s" % line)

            var message := _try_parse_json(line)
            if not message.is_empty():
                parsed_messages.append(message)

                var message_type := str(message.get("type", ""))
                var subtype := str(message.get("subtype", ""))
                if message_type == "control_response":
                    saw_control_response = true
                elif message_type == "system" and subtype == "init":
                    saw_init = true
                elif message_type == "assistant":
                    saw_assistant = true
                elif message_type == "result":
                    saw_result = true

        for line in stderr_batch:
            stderr_lines.append(line)
            print("STDERR %s" % line)

        if saw_result:
            break

        await tree.create_timer(POLL_INTERVAL_SEC).timeout

    var duration_ms := Time.get_ticks_msec() - started_ms
    var summary := {
        "launched": true,
        "claude_path": claude_path,
        "pid": pid,
        "duration_ms": duration_ms,
        "saw_control_response": saw_control_response,
        "saw_init": saw_init,
        "saw_assistant": saw_assistant,
        "saw_result": saw_result,
        "stdout_line_count": stdout_lines.size(),
        "stderr_line_count": stderr_lines.size(),
    }

    print("SUMMARY %s" % JSON.stringify(summary))

    if pid > 0:
        var kill_result := OS.kill(pid)
        print("Probe: kill(%d) -> %d" % [pid, kill_result])
        summary["kill_result"] = kill_result

    summary["ok"] = saw_control_response and saw_init and saw_result
    return summary


func _drain_available_lines(pipe: FileAccess) -> Array[String]:
    var lines: Array[String] = []

    while true:
        var line := pipe.get_line()
        var read_error := pipe.get_error()

        if read_error != OK:
            break

        if line.is_empty():
            break

        lines.append(line)

    return lines


func _try_parse_json(text: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(text)
    if parsed is Dictionary:
        return parsed
    return {}
