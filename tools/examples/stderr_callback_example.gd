extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")
const ExampleSupportScript := preload("res://tools/examples/example_support.gd")

var _stderr_lines: Array[String] = []


func _init() -> void:
	var args := ExampleSupportScript.parse_args(OS.get_cmdline_user_args())
	await process_frame
	var exit_code := await _run_example(args)
	quit(exit_code)


func _run_example(args: Dictionary) -> int:
	_stderr_lines.clear()
	var options = ClaudeAgentOptionsScript.new({
		"cwd": ExampleSupportScript.repo_root(),
		"max_turns": 1,
		"stderr": Callable(self, "_on_stderr"),
		"extra_args": {"debug-to-stderr": null},
	})
	var prompt := str(args.get("prompt", "What is 2 + 2? Answer only with the number."))
	var summary := await ExampleSupportScript.collect_stream_summary(
		ClaudeQueryScript.query(prompt, options)
	)
	ExampleSupportScript.print_summary("stderr callback example", summary)
	print("Captured stderr lines: %d" % _stderr_lines.size())
	if not _stderr_lines.is_empty():
		print("First stderr line: %s" % _stderr_lines[0])
	else:
		print("No stderr lines were emitted for this run.")
	return 0 if ExampleSupportScript.summary_ok(summary) else 2


func _on_stderr(message: String) -> void:
	_stderr_lines.append(message)
