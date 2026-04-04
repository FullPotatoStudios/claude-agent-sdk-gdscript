# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")
const ClaudeClientNodeScript := preload("res://addons/claude_agent_sdk/runtime/adapters/claude_client_node.gd")
const ClaudeResultMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_result_message.gd")


func test_node_defaults_auto_connect_off_and_reemits_adapter_signals() -> void:
	var transport = FakeTransportScript.new()
	var node = ClaudeClientNodeScript.new(ClaudeAgentOptions.new(), transport)
	var ready_events: Array[int] = []
	var turn_finished_messages: Array = []

	node.session_ready.connect(func(_server_info): ready_events.append(1))
	node.turn_finished.connect(func(message): turn_finished_messages.append(message))

	get_tree().root.add_child(node)
	await get_tree().process_frame
	assert_bool(transport.connected).is_false()

	node.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"output_style": "default"},
		},
	})
	await _await_frames(2)

	node.query("Hi")
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "ok",
	})
	await _await_frames(2)

	assert_int(ready_events.size()).is_equal(1)
	assert_int(turn_finished_messages.size()).is_equal(1)
	assert_object(turn_finished_messages[0]).is_instanceof(ClaudeResultMessageScript)

	node.disconnect_client()
	await _await_frames(2)
	get_tree().root.remove_child(node)
	node.queue_free()
	await _await_frames(2)


func test_node_auto_disconnects_on_exit_when_enabled() -> void:
	var transport = FakeTransportScript.new()
	var node = ClaudeClientNodeScript.new(ClaudeAgentOptions.new(), transport)
	node.auto_connect_on_ready = true

	get_tree().root.add_child(node)
	await get_tree().process_frame
	assert_bool(transport.connected).is_true()

	get_tree().root.remove_child(node)
	await get_tree().process_frame

	assert_bool(transport.connected).is_false()
	node.queue_free()
	await _await_frames(2)


func _await_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _read_last_write(transport) -> Dictionary:
	return JSON.parse_string(transport.writes[-1])
