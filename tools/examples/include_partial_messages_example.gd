extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeSDKClientScript := preload("res://addons/claude_agent_sdk/runtime/claude_sdk_client.gd")
const ExampleSupportScript := preload("res://tools/examples/example_support.gd")


func _init() -> void:
	var args := ExampleSupportScript.parse_args(OS.get_cmdline_user_args())
	await process_frame
	var exit_code := await _run_example(args)
	quit(exit_code)


func _run_example(args: Dictionary) -> int:
	var options = ClaudeAgentOptionsScript.new({
		"cwd": ExampleSupportScript.repo_root(),
		"include_partial_messages": true,
		"max_turns": 1,
		"model": "haiku",
	})
	var client = ClaudeSDKClientScript.new(options)
	client.connect_client()
	if not client.get_last_error().is_empty():
		push_error(client.get_last_error())
		return 2

	var prompt := str(args.get("prompt", "Count from 1 to 20 in one comma-separated line."))
	client.query(prompt)
	if not client.get_last_error().is_empty():
		push_error(client.get_last_error())
		client.disconnect_client()
		return 2

	var summary := await ExampleSupportScript.collect_stream_summary(client.receive_response())
	client.disconnect_client()
	ExampleSupportScript.print_summary("Partial messages example", summary)
	if int(summary.get("stream_event_count", 0)) == 0:
		print("No partial stream events were emitted for this prompt. This example still demonstrates the option wiring.")
	return 0 if ExampleSupportScript.summary_ok(summary) else 2
