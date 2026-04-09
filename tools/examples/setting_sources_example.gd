extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")
const ExampleSupportScript := preload("res://tools/examples/example_support.gd")

const EXPECTED_OUTPUT_STYLE := "example-local-style"


func _init() -> void:
	var args := ExampleSupportScript.parse_args(OS.get_cmdline_user_args())
	await process_frame
	var exit_code := await _run_example(args)
	quit(exit_code)


func _run_example(args: Dictionary) -> int:
	var mode := str(args.get("mode", "default"))
	var workspace := ExampleSupportScript.create_temp_workspace_from_fixture(
		"setting_sources_workspace",
		"setting-sources"
	)
	if workspace.is_empty():
		push_error("Could not create temporary workspace fixture.")
		return 2

	var options = ClaudeAgentOptionsScript.new({
		"cwd": workspace,
		"max_turns": 1,
	})
	var guaranteed_mode := true

	match mode:
		"default":
			pass
		"all_sources":
			options.setting_sources = ["user", "project", "local"]
		"user":
			options.setting_sources = ["user"]
			guaranteed_mode = false
		_:
			push_error("Unknown mode: %s" % mode)
			return 2

	print("Workspace: %s" % workspace)
	print("Mode: %s" % mode)
	if not guaranteed_mode:
		print("User-only mode is host-dependent and does not make deterministic assertions.")

	var summary := await ExampleSupportScript.collect_stream_summary(
		ClaudeQueryScript.query("What is 2 + 2? Answer only with the number.", options)
	)
	ExampleSupportScript.print_summary("Setting sources example", summary)

	if not ExampleSupportScript.summary_ok(summary):
		return 2

	if not guaranteed_mode:
		return 0

	var ok := str(summary.get("init_output_style", "")) == EXPECTED_OUTPUT_STYLE
	if not ok:
		print("Expected init output style %s for mode %s." % [EXPECTED_OUTPUT_STYLE, mode])
		print("Observed output style: %s" % str(summary.get("init_output_style", "")))
	return 0 if ok else 2
