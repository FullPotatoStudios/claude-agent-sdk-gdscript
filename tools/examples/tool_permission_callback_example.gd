extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudePermissionResultAllowScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_allow.gd")
const ClaudePermissionResultDenyScript := preload("res://addons/claude_agent_sdk/runtime/claude_permission_result_deny.gd")
const ClaudePromptStreamScript := preload("res://addons/claude_agent_sdk/runtime/input/claude_prompt_stream.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")
const ExampleSupportScript := preload("res://tools/examples/example_support.gd")

var _tool_usage_log: Array = []


func _init() -> void:
	var args := ExampleSupportScript.parse_args(OS.get_cmdline_user_args())
	await process_frame
	var exit_code := await _run_example(args)
	quit(exit_code)


func _run_example(args: Dictionary) -> int:
	_tool_usage_log.clear()
	var workspace := ProjectSettings.globalize_path("user://tool-permission-example")
	DirAccess.make_dir_recursive_absolute(workspace)

	var options = ClaudeAgentOptionsScript.new({
		"cwd": workspace,
		"permission_mode": "default",
		"can_use_tool": Callable(self, "_permission_callback"),
	})
	var prompt_stream = ClaudePromptStreamScript.new()
	prompt_stream.push_message({
		"type": "user",
		"message": {
			"role": "user",
			"content": str(args.get(
				"prompt",
				"List the files in the current directory, create hello.txt with the text hello from the permission example, and run printf done."
			)),
		},
		"parent_tool_use_id": null,
	})
	prompt_stream.finish()

	var summary := await ExampleSupportScript.collect_stream_summary(
		ClaudeQueryScript.query(prompt_stream, options)
	)
	ExampleSupportScript.print_summary("Tool permission callback example", summary)
	print("Tool usage log: %s" % JSON.stringify(_tool_usage_log))
	return 0 if ExampleSupportScript.summary_ok(summary) else 2


func _permission_callback(tool_name: String, input_data: Dictionary, context) -> Variant:
	_tool_usage_log.append({
		"tool": tool_name,
		"input": input_data.duplicate(true),
		"suggestions": context.suggestions if context != null else [],
	})
	if tool_name in ["Read", "Glob", "Grep", "LS"]:
		return ClaudePermissionResultAllowScript.new()
	if tool_name in ["Write", "Edit", "MultiEdit"]:
		var file_path := str(input_data.get("file_path", ""))
		if not file_path.is_empty() and not file_path.begins_with("./safe_output/"):
			var updated_input := input_data.duplicate(true)
			updated_input["file_path"] = "./safe_output/%s" % file_path.get_file()
			print("Redirecting write to %s" % str(updated_input.get("file_path", "")))
			return ClaudePermissionResultAllowScript.new(updated_input)
		return ClaudePermissionResultAllowScript.new()
	if tool_name == "Bash":
		var command := str(input_data.get("command", ""))
		if command.contains("rm -rf") or command.contains("sudo"):
			return ClaudePermissionResultDenyScript.new("Dangerous bash pattern detected.")
		return ClaudePermissionResultAllowScript.new()
	return ClaudePermissionResultDenyScript.new("Example callback denied the %s tool." % tool_name)
