extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")


func _init() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	await process_frame
	var summary: Dictionary = await _run_smoke(args)
	print("SUMMARY %s" % JSON.stringify(summary))
	quit(0 if bool(summary.get("ok", false)) else 2)


func _run_smoke(args: Dictionary) -> Dictionary:
	var mode := str(args.get("mode", "baseline"))
	var options = ClaudeAgentOptionsScript.new({
		"cli_path": str(args.get("claude_path", "claude")),
		"model": "haiku",
		"effort": "low",
	})
	var prompt := ""

	match mode:
		"structured":
			options.max_turns = 2
			options.output_format = {
				"type": "json_schema",
				"schema": {
					"type": "object",
					"properties": {
						"answer": {"type": "string"},
					},
					"required": ["answer"],
					"additionalProperties": false,
				},
			}
			prompt = "Return a JSON object with a single answer field set to 4."
		"partial":
			options.max_turns = 1
			options.include_partial_messages = true
			prompt = "Count from 1 to 20 in a single comma-separated line."
		_:
			options.max_turns = 1
			prompt = "What is 2 + 2? Answer only with the number."

	var stream = ClaudeQueryScript.query(prompt, options)
	var message_types: Array[String] = []
	var saw_stream_event := false
	var result_message = null

	while true:
		var message: Variant = await stream.next_message()
		if message == null:
			break
		if message is Object:
			message_types.append(str(message.get("message_type")))
		if message is ClaudeStreamEvent:
			saw_stream_event = true
		if message is ClaudeResultMessage:
			result_message = message

	var summary := {
		"mode": mode,
		"message_types": message_types,
		"stream_error": stream.get_error(),
		"saw_stream_event": saw_stream_event,
		"result_present": result_message != null,
		"result_is_error": false,
		"result_subtype": "",
		"result_errors": [],
		"result_num_turns": 0,
		"structured_output_present": false,
		"structured_output": null,
		"result_text": "",
	}
	if result_message != null:
		summary["result_is_error"] = bool(result_message.is_error)
		summary["result_subtype"] = str(result_message.subtype)
		summary["result_errors"] = result_message.errors.duplicate(true)
		summary["result_num_turns"] = int(result_message.num_turns)
		summary["structured_output_present"] = result_message.structured_output != null
		summary["structured_output"] = result_message.structured_output
		summary["result_text"] = str(result_message.result)

	match mode:
		"structured":
			summary["ok"] = result_message != null and not bool(result_message.is_error) and result_message.structured_output != null
		"partial":
			summary["ok"] = result_message != null and not bool(result_message.is_error) and saw_stream_event
		_:
			summary["ok"] = result_message != null

	return summary


func _parse_args(cmdline_args: PackedStringArray) -> Dictionary:
	var parsed := {
		"mode": "baseline",
		"claude_path": "claude",
	}
	for arg in cmdline_args:
		if arg.begins_with("--mode="):
			parsed["mode"] = arg.trim_prefix("--mode=")
		elif arg.begins_with("--claude-path="):
			parsed["claude_path"] = arg.trim_prefix("--claude-path=")
	return parsed
