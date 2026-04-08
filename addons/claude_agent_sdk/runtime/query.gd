extends RefCounted
class_name ClaudeQuery

const ClaudeMessageStreamScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_message_stream.gd")
const ClaudeSDKClientScript := preload("res://addons/claude_agent_sdk/runtime/claude_sdk_client.gd")
const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudePromptStreamScript := preload("res://addons/claude_agent_sdk/runtime/input/claude_prompt_stream.gd")

static func query(prompt, options = null, transport = null):
	var resolved_options = options if options != null else ClaudeAgentOptionsScript.new()
	if not (prompt is String or prompt is ClaudePromptStreamScript):
		var invalid_stream = ClaudeMessageStreamScript.new(true)
		invalid_stream.fail("prompt must be either a String or ClaudePromptStream")
		return invalid_stream
	if resolved_options.can_use_tool.is_valid() and prompt is String:
		var failed_stream = ClaudeMessageStreamScript.new(true)
		failed_stream.fail(
			"can_use_tool callback requires streamed prompt input. " +
			"Please provide prompt as a ClaudePromptStream instead of a String."
		)
		return failed_stream
	var client = ClaudeSDKClientScript.new(resolved_options, transport)
	client.connect_client()
	if not client.get_last_error().is_empty():
		var failed_stream = ClaudeMessageStreamScript.new(true)
		failed_stream.fail(client.get_last_error())
		return failed_stream
	if prompt is ClaudePromptStreamScript:
		client.query(prompt, "default", false)
	else:
		client.query(prompt, resolved_options.get_effective_session_id(""))
	var stream = client.receive_response()
	stream.retain(client)
	stream.set_finish_callback(client.disconnect_client)
	return stream


static func get_auth_status(options = null, transport = null) -> Dictionary:
	var resolved_options = options if options != null else ClaudeAgentOptionsScript.new()
	var client = ClaudeSDKClientScript.new(resolved_options, transport)
	return client.get_auth_status()
