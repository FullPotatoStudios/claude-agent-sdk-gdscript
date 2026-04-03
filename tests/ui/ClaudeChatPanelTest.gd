# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")
const ChatPanelScene := preload("res://addons/claude_agent_sdk/ui/claude_chat_panel.tscn")
const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")


func test_panel_setup_creates_internal_client_and_shows_ready_auth_state() -> void:
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku", "effort": "low"}), transport)

	get_tree().root.add_child(panel)
	await _await_frames(2)

	assert_object(panel.get_client_node()).is_not_null()
	assert_str(_status_badge(panel).text).is_equal("Ready")
	assert_bool(_button(panel, "ConnectButton").disabled).is_false()
	assert_bool(_button(panel, "SendButton").disabled).is_true()

	panel.queue_free()
	await get_tree().process_frame


func test_panel_auth_states_cover_logged_out_and_transport_issue() -> void:
	var logged_out_transport = FakeTransportScript.new()
	logged_out_transport.auth_status_result = {
		"ok": false,
		"logged_in": false,
		"error_code": "",
		"error_message": "",
	}
	var logged_out_panel = ChatPanelScene.instantiate()
	logged_out_panel.setup(ClaudeAgentOptionsScript.new(), logged_out_transport)
	get_tree().root.add_child(logged_out_panel)
	await _await_frames(2)

	assert_str(_status_badge(logged_out_panel).text).is_equal("Logged out")
	assert_bool(_button(logged_out_panel, "ConnectButton").disabled).is_true()

	logged_out_panel.queue_free()
	await get_tree().process_frame

	var issue_transport = FakeTransportScript.new()
	issue_transport.auth_status_result = {
		"ok": false,
		"logged_in": false,
		"error_code": "transport_error",
		"error_message": "Claude binary not found",
	}
	var issue_panel = ChatPanelScene.instantiate()
	issue_panel.setup(ClaudeAgentOptionsScript.new(), issue_transport)
	get_tree().root.add_child(issue_panel)
	await _await_frames(2)

	assert_str(_status_badge(issue_panel).text).is_equal("Issue")
	assert_str(_label(issue_panel, "StatusDetailLabel").text).contains("Claude binary not found")

	issue_panel.queue_free()
	await get_tree().process_frame


func test_panel_shows_connection_failure_in_header_even_when_auth_is_ready() -> void:
	var transport = FakeTransportScript.new()
	transport.open_error_message = "transport unavailable"
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	panel.connect_client()
	await _await_frames(2)

	assert_str(_status_badge(panel).text).is_equal("Issue")
	assert_str(_label(panel, "StatusTitleLabel").text).is_equal("Claude session failed to start")
	assert_str(_label(panel, "StatusDetailLabel").text).contains("transport unavailable")
	assert_bool(_button(panel, "ConnectButton").disabled).is_false()

	panel.queue_free()
	await get_tree().process_frame


func test_panel_connects_and_enables_composer_after_initialize_without_system_init() -> void:
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	panel.connect_client()
	await _await_frames(1)

	transport.emit_stdout_message({
		"type": "system",
		"subtype": "hook_started",
		"hook_event": "SessionStart",
	})
	transport.emit_stdout_message({
		"type": "system",
		"subtype": "hook_response",
		"hook_event": "SessionStart",
	})
	await _await_frames(2)

	assert_str(_status_badge(panel).text).is_equal("Connecting")
	assert_bool(_prompt_input(panel).editable).is_false()

	var init_request: Dictionary = JSON.parse_string(transport.writes[-1])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/help"}]},
		},
	})
	await _await_frames(2)

	assert_str(_status_badge(panel).text).is_equal("Connected")
	assert_bool(_prompt_input(panel).editable).is_true()
	assert_bool(_button(panel, "ConnectButton").disabled).is_true()
	assert_int(_count_entries(panel, "system_card")).is_equal(2)

	panel.queue_free()
	await get_tree().process_frame


func test_panel_shows_issue_and_keeps_composer_disabled_when_initialize_fails() -> void:
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	panel.connect_client()
	var init_request: Dictionary = JSON.parse_string(transport.writes[-1])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "error",
			"request_id": str(init_request.get("request_id", "")),
			"error": "initialize failed",
		},
	})
	await _await_frames(2)

	assert_str(_status_badge(panel).text).is_equal("Issue")
	assert_str(_label(panel, "StatusDetailLabel").text).contains("initialize failed")
	assert_bool(_prompt_input(panel).editable).is_false()
	assert_bool(_button(panel, "ConnectButton").disabled).is_false()

	panel.queue_free()
	await get_tree().process_frame


func test_panel_submit_prompt_renders_user_assistant_and_result_entries() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)
	var prompt_events: Array[String] = []
	var turn_finished_events: Array[int] = []

	panel.prompt_submitted.connect(func(prompt: String): prompt_events.append(prompt))
	panel.turn_finished.connect(func(_message: ClaudeResultMessage): turn_finished_events.append(1))

	panel.submit_prompt("Hello from the panel")
	transport.emit_stdout_message({
		"type": "assistant",
		"session_id": "default",
		"message": {"model": "haiku", "content": [{"type": "text", "text": "Hello back"}]},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 14,
		"duration_api_ms": 11,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "Hello back",
	})
	await _await_frames(3)

	assert_array(prompt_events).is_equal(["Hello from the panel"])
	assert_int(turn_finished_events.size()).is_equal(1)
	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)
	assert_int(_count_entries(panel, "result_card")).is_equal(1)
	assert_bool(_button(panel, "InterruptButton").disabled).is_true()

	panel.queue_free()
	await get_tree().process_frame


func test_panel_coalesces_partial_stream_events_into_single_assistant_bubble() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport, ClaudeAgentOptionsScript.new({
		"include_partial_messages": true,
	}))

	panel.submit_prompt("Count")
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-1",
		"event": {"delta": {"text": "1, 2, "}},
	})
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-2",
		"event": {"delta": {"text": "3, 4"}},
	})
	transport.emit_stdout_message({
		"type": "assistant",
		"session_id": "default",
		"message": {"model": "haiku", "content": [{"type": "text", "text": "1, 2, 3, 4"}]},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 14,
		"duration_api_ms": 11,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "1, 2, 3, 4",
	})
	await _await_frames(3)

	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)
	assert_str(_last_assistant_text(panel)).contains("1, 2, 3, 4")

	panel.queue_free()
	await get_tree().process_frame


func test_panel_ignores_non_text_stream_event_payloads_in_assistant_bubble() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport, ClaudeAgentOptionsScript.new({
		"include_partial_messages": true,
	}))

	panel.submit_prompt("Return structured data")
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-json",
		"event": {"delta": {"partial_json": "{\"answer\":\"4\"}"}},
	})
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-thinking",
		"event": {"delta": {"thinking": "working"}},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(0)

	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-text",
		"event": {"delta": {"text": "Plain text only"}},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)
	assert_str(_last_assistant_text(panel)).is_equal("Plain text only")

	panel.queue_free()
	await get_tree().process_frame


func test_panel_renders_result_errors_and_structured_output() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)

	panel.submit_prompt("Return json")
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 22,
		"duration_api_ms": 17,
		"is_error": false,
		"num_turns": 2,
		"session_id": "default",
		"result": "Done",
		"structured_output": {"answer": "4"},
		"errors": ["soft warning"],
	})
	await _await_frames(3)

	var result_card := _last_entry(panel, "result_card")
	var structured_output_label: RichTextLabel = result_card.find_child("StructuredOutputLabel", true, false) as RichTextLabel
	var result_errors_label: RichTextLabel = result_card.find_child("ResultErrorsLabel", true, false) as RichTextLabel
	assert_object(structured_output_label).is_not_null()
	assert_object(result_errors_label).is_not_null()
	assert_str(str(structured_output_label.text)).contains("\"answer\": \"4\"")
	assert_str(str(result_errors_label.text)).contains("soft warning")

	panel.queue_free()
	await get_tree().process_frame


func test_panel_interrupt_button_tracks_busy_state() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)

	panel.submit_prompt("Wait")
	await _await_frames(2)
	assert_bool(_button(panel, "InterruptButton").disabled).is_false()
	assert_bool(_button(panel, "SendButton").disabled).is_true()

	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 8,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "Done",
	})
	await _await_frames(3)

	assert_bool(_button(panel, "InterruptButton").disabled).is_true()

	panel.queue_free()
	await get_tree().process_frame


func _connected_panel(transport, options = null):
	var panel = ChatPanelScene.instantiate()
	panel.setup(options if options != null else ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)
	panel.connect_client()
	var init_request: Dictionary = JSON.parse_string(transport.writes[-1])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/help"}]},
		},
	})
	await _await_frames(3)
	return panel


func _status_badge(panel) -> Label:
	return _label(panel, "StatusBadgeLabel")


func _button(panel, node_name: String) -> Button:
	return panel.find_child(node_name, true, false) as Button


func _label(panel, node_name: String) -> Label:
	return panel.find_child(node_name, true, false) as Label


func _prompt_input(panel) -> TextEdit:
	return panel.find_child("PromptInput", true, false) as TextEdit


func _transcript_list(panel) -> VBoxContainer:
	return panel.find_child("TranscriptList", true, false) as VBoxContainer


func _count_entries(panel, kind: String) -> int:
	var count := 0
	for child in _transcript_list(panel).get_children():
		if str(child.get_meta("entry_kind", "")) == kind:
			count += 1
	return count


func _last_entry(panel, kind: String) -> Node:
	var found: Node = null
	for child in _transcript_list(panel).get_children():
		if str(child.get_meta("entry_kind", "")) == kind:
			found = child
	return found


func _last_assistant_text(panel) -> String:
	var entry := _last_entry(panel, "assistant_bubble")
	var bubble_body: RichTextLabel = entry.find_child("BubbleBody", true, false) as RichTextLabel
	return bubble_body.text


func _await_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
