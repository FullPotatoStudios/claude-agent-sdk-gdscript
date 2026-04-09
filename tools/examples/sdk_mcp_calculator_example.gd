extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeMcpScript := preload("res://addons/claude_agent_sdk/runtime/mcp/claude_mcp.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")
const ExampleSupportScript := preload("res://tools/examples/example_support.gd")


func _init() -> void:
	var args := ExampleSupportScript.parse_args(OS.get_cmdline_user_args())
	await process_frame
	var exit_code := await _run_example(args)
	quit(exit_code)


func _run_example(args: Dictionary) -> int:
	var add_tool = ClaudeMcpScript.tool(
		"add_numbers",
		"Add two numeric values together.",
		ClaudeMcpScript.schema_object({
			"a": ClaudeMcpScript.schema_scalar("number", "First operand"),
			"b": ClaudeMcpScript.schema_scalar("number", "Second operand"),
		}, ["a", "b"]),
		Callable(self, "_add_numbers")
	)
	var server_config = ClaudeMcpScript.create_sdk_server("calculator", "1.0.0", [add_tool])
	var options = ClaudeAgentOptionsScript.new({
		"cwd": ExampleSupportScript.repo_root(),
		"max_turns": 1,
		"mcp_servers": {"calculator": server_config},
	})
	var prompt := str(args.get(
		"prompt",
		"Use the calculator tool to add 2 and 3. Return only the final number."
	))
	var summary := await ExampleSupportScript.collect_stream_summary(
		ClaudeQueryScript.query(prompt, options)
	)
	ExampleSupportScript.print_summary("SDK MCP calculator example", summary)
	return 0 if ExampleSupportScript.summary_ok(summary) else 2


func _add_numbers(arguments: Dictionary) -> Dictionary:
	var a := float(arguments.get("a", 0.0))
	var b := float(arguments.get("b", 0.0))
	return {
		"content": [
			{
				"type": "text",
				"text": str(a + b),
			},
		],
	}
