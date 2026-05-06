extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeSubprocessCLITransportScript := preload("res://addons/claude_agent_sdk/runtime/transport/subprocess_cli_transport.gd")
const ClaudeMessageParserScript := preload("res://addons/claude_agent_sdk/runtime/parser/message_parser.gd")
const ClaudeHookEventMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_hook_event_message.gd")


func _init() -> void:
	var failures: Array[String] = []

	var enabled_options := ClaudeAgentOptionsScript.new({"include_hook_events": true})
	var enabled_transport := ClaudeSubprocessCLITransportScript.new(enabled_options)
	var enabled_args := enabled_transport.build_command_args()
	if enabled_args.find("--include-hook-events") < 0:
		failures.append("expected --include-hook-events when option is true")

	var disabled_transport := ClaudeSubprocessCLITransportScript.new(ClaudeAgentOptionsScript.new())
	var disabled_args := disabled_transport.build_command_args()
	if disabled_args.find("--include-hook-events") >= 0:
		failures.append("did not expect --include-hook-events when option is false")

	var hook_started: Variant = ClaudeMessageParserScript.parse_message({
		"type": "system",
		"subtype": "hook_started",
		"hook_event": "PreToolUse",
		"session_id": "session-probe",
		"uuid": "uuid-probe",
	})
	if not (hook_started is ClaudeHookEventMessageScript):
		failures.append("hook_started did not parse to ClaudeHookEventMessage")
	elif hook_started.hook_event_name != "PreToolUse":
		failures.append("hook_event_name not populated from hook_event field")

	if failures.is_empty():
		print("include_hook_events_probe: OK (3 cases)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
