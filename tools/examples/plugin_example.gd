extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")
const ExampleSupportScript := preload("res://tools/examples/example_support.gd")


func _init() -> void:
	var args := ExampleSupportScript.parse_args(OS.get_cmdline_user_args())
	await process_frame
	var exit_code := await _run_example(args)
	quit(exit_code)


func _run_example(args: Dictionary) -> int:
	var plugin_path := ExampleSupportScript.fixture_path("plugins/demo-plugin")
	var options = ClaudeAgentOptionsScript.new({
		"cwd": ExampleSupportScript.repo_root(),
		"max_turns": 1,
		"plugins": [
			{
				"type": "local",
				"path": plugin_path,
			},
		],
	})
	var prompt := str(args.get("prompt", "Hello from the local plugin example."))

	print("Plugin fixture: %s" % plugin_path)
	var summary := await ExampleSupportScript.collect_stream_summary(
		ClaudeQueryScript.query(prompt, options)
	)
	ExampleSupportScript.print_summary("Plugin example", summary)

	if ExampleSupportScript.summary_has_command(summary, "greet"):
		print("Detected the demo plugin command in the init payload.")
	else:
		print("The CLI may omit plugin metadata from init, so the configured path is the primary proof in this example.")
	return 0 if ExampleSupportScript.summary_ok(summary) else 2
