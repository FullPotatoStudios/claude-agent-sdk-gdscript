extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeHookMatcherScript := preload("res://addons/claude_agent_sdk/runtime/claude_hook_matcher.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")
const ExampleSupportScript := preload("res://tools/examples/example_support.gd")

var _blocked_commands: Array[String] = []


func _init() -> void:
	var args := ExampleSupportScript.parse_args(OS.get_cmdline_user_args())
	await process_frame
	var exit_code := await _run_example(args)
	quit(exit_code)


func _run_example(args: Dictionary) -> int:
	_blocked_commands.clear()
	var options = ClaudeAgentOptionsScript.new({
		"cwd": ExampleSupportScript.repo_root(),
		"max_turns": 1,
		"allowed_tools": ["Bash"],
		"permission_mode": "bypassPermissions",
		"hooks": {
			"PreToolUse": [
				ClaudeHookMatcherScript.new({
					"matcher": "Bash",
					"hooks": [Callable(self, "_pre_tool_use_hook")],
					"timeout_sec": 5.0,
				}),
			],
		},
	})
	var prompt := str(args.get(
		"prompt",
		"Run the bash command ./foo.sh --help, then explain what happened."
	))

	var summary := await ExampleSupportScript.collect_stream_summary(
		ClaudeQueryScript.query(prompt, options)
	)
	ExampleSupportScript.print_summary("Hooks example", summary)
	print("Blocked commands: %s" % str(_blocked_commands))
	return 0 if ExampleSupportScript.summary_ok(summary) else 2


func _pre_tool_use_hook(input_data: Dictionary, _tool_use_id: Variant, context) -> Dictionary:
	var tool_name := str(input_data.get("tool_name", ""))
	var tool_input: Dictionary = input_data.get("tool_input", {}) if input_data.get("tool_input", {}) is Dictionary else {}
	if context != null and context.typed_input != null:
		print("Typed hook input class: %s" % str(context.typed_input.get_script()))
	if tool_name != "Bash":
		return {}
	var command := str(tool_input.get("command", ""))
	if command.contains("foo.sh"):
		_blocked_commands.append(command)
		return {
			"systemMessage": "Blocked a bash command from the hooks example.",
			"hookSpecificOutput": {
				"hookEventName": "PreToolUse",
				"permissionDecision": "deny",
				"permissionDecisionReason": "Commands containing foo.sh are blocked by the example hook.",
			},
		}
	return {}
