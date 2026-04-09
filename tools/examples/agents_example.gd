extends SceneTree

const ClaudeAgentDefinitionScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_definition.gd")
const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")
const ExampleSupportScript := preload("res://tools/examples/example_support.gd")

const PRIMARY_AGENT := "code-reviewer"


func _init() -> void:
	var args := ExampleSupportScript.parse_args(OS.get_cmdline_user_args())
	await process_frame
	var exit_code := await _run_example(args)
	quit(exit_code)


func _run_example(args: Dictionary) -> int:
	var options = ClaudeAgentOptionsScript.new({
		"cwd": ExampleSupportScript.repo_root(),
		"max_turns": 1,
		"agents": {
			PRIMARY_AGENT: ClaudeAgentDefinitionScript.new({
				"description": "Reviews GDScript runtime code for strengths and risks.",
				"prompt": "You are a careful code reviewer. Call out one strength and one risk briefly.",
				"tools": ["Read", "Grep"],
				"model": "sonnet",
			}),
			"doc-writer": ClaudeAgentDefinitionScript.new({
				"description": "Writes concise addon documentation.",
				"prompt": "You write short, precise developer-facing docs.",
				"tools": ["Read"],
			}),
		},
	})
	var prompt := str(args.get(
		"prompt",
		"Use the code-reviewer agent to review addons/claude_agent_sdk/runtime/claude_agent_options.gd. Start your reply with 'code-reviewer:' and mention one strength."
	))

	print("Running agents example from: %s" % options.cwd)
	var summary := await ExampleSupportScript.collect_stream_summary(
		ClaudeQueryScript.query(prompt, options)
	)
	ExampleSupportScript.print_summary("Agents example", summary)

	var assistant_text := "\n".join(summary.get("assistant_texts", []) as Array).to_lower()
	var ok := ExampleSupportScript.summary_ok(summary) \
		and not assistant_text.is_empty() \
		and assistant_text.contains("code-reviewer:")
	if not ok:
		print("Expected the assistant reply to acknowledge the requested %s agent." % PRIMARY_AGENT)
	return 0 if ok else 2
