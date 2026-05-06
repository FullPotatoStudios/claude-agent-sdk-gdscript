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
		client.query(prompt, "default", false, true)
	else:
		client.query(prompt, resolved_options.get_effective_session_id(""), true, true)
	var stream = client.receive_response()
	stream.retain(client)
	stream.add_finish_callback(
		Callable(ClaudeQuery, "_disconnect_client").bind(
			client,
			_disconnect_frame_delay(resolved_options, transport, client)
		)
	)
	return stream


static func get_auth_status(options = null, transport = null) -> Dictionary:
	var resolved_options = options if options != null else ClaudeAgentOptionsScript.new()
	var client = ClaudeSDKClientScript.new(resolved_options, transport)
	return client.get_auth_status()


static func _disconnect_client(client, frame_delay: int = 1) -> void:
	if client == null:
		return
	_disconnect_client_after_frames(client, frame_delay)


static func _disconnect_client_after_frames(client, remaining_frames: int) -> void:
	if client == null:
		return
	if remaining_frames <= 0:
		client.disconnect_client()
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		client.disconnect_client()
		return
	tree.process_frame.connect(
		Callable(ClaudeQuery, "_disconnect_client_after_frames").bind(client, remaining_frames - 1),
		CONNECT_ONE_SHOT
	)


static func _disconnect_frame_delay(resolved_options, transport, _client = null) -> int:
	if transport != null and transport.has_method("supports_end_input") and not transport.supports_end_input():
		return 1
	if resolved_options != null and resolved_options.mcp_servers is Dictionary:
		for server_name_variant in (resolved_options.mcp_servers as Dictionary).keys():
			var config_variant: Variant = (resolved_options.mcp_servers as Dictionary)[server_name_variant]
			if config_variant is Dictionary and str((config_variant as Dictionary).get("type", "")) == "sdk":
				return 2
	if resolved_options != null and resolved_options.hooks is Dictionary and not (resolved_options.hooks as Dictionary).is_empty():
		return 2
	return 1
