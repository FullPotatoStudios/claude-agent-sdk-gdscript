extends RefCounted
class_name ClaudeQuery

const ClaudeMessageStreamScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_message_stream.gd")
const ClaudeSDKClientScript := preload("res://addons/claude_agent_sdk/runtime/claude_sdk_client.gd")
const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")

static func query(prompt: String, options = null, transport = null):
	var resolved_options = options if options != null else ClaudeAgentOptionsScript.new()
	var client = ClaudeSDKClientScript.new(resolved_options, transport)
	client.connect_client()
	if not client.get_last_error().is_empty():
		var failed_stream = ClaudeMessageStreamScript.new(true)
		failed_stream.fail(client.get_last_error())
		return failed_stream
	client.query(prompt, resolved_options.get_effective_session_id(""))
	var stream = client.receive_response()
	stream.retain(client)
	stream.set_finish_callback(client.disconnect_client)
	return stream


static func get_auth_status(options = null, transport = null) -> Dictionary:
	var resolved_options = options if options != null else ClaudeAgentOptionsScript.new()
	var client = ClaudeSDKClientScript.new(resolved_options, transport)
	return client.get_auth_status()
