# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")
const ChatPanelScene := preload("res://addons/claude_agent_sdk/ui/claude_chat_panel.tscn")
const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeSessionsScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_sessions.gd")

var _created_roots: Array[String] = []


func after_test() -> void:
	for root_path in _created_roots:
		_delete_tree(root_path)
	_created_roots.clear()
	OS.set_environment("CLAUDE_CONFIG_DIR", "")


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

	await _cleanup_panel(panel)


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

	await _cleanup_panel(logged_out_panel)

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

	await _cleanup_panel(issue_panel)


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

	await _cleanup_panel(panel)


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

	await _cleanup_panel(panel)


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

	await _cleanup_panel(panel)


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

	await _cleanup_panel(panel)


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

	await _cleanup_panel(panel)


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

	await _cleanup_panel(panel)


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

	await _cleanup_panel(panel)


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

	await _cleanup_panel(panel)


func test_panel_loads_scoped_sessions_and_renders_selected_transcript_without_connecting() -> void:
	var session_id := _create_panel_session_fixture("panel-history")
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())

	get_tree().root.add_child(panel)
	await _await_frames(2)

	assert_int(_session_list(panel).select_mode).is_equal(ItemList.SELECT_SINGLE)
	assert_int(_session_list(panel).item_count).is_equal(1)
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)
	assert_bool(_prompt_input(panel).editable).is_false()
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Restored session")
	assert_str(_label(panel, "SelectedSessionMetaValue").text).contains("review")
	assert_str(_session_id_from_panel(panel)).is_equal(session_id)

	await _cleanup_panel(panel)


func test_panel_keyboard_activation_selects_saved_session() -> void:
	_create_panel_session_fixture("panel-keyboard")
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)

	_activate_session_with_keyboard_signal(panel, 0)
	await _await_frames(2)

	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Restored session")
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)

	await _cleanup_panel(panel)


func test_panel_resumes_selected_session_and_disables_mutations_while_connected() -> void:
	var session_id := _create_panel_session_fixture("panel-resume")
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	panel.connect_client()
	await _await_frames(1)

	var runtime_options = panel.get_client_node()._adapter._client.options
	assert_str(runtime_options.resume).is_equal(session_id)
	assert_str(runtime_options.session_id).is_equal(session_id)
	assert_bool(_button(panel, "RenameSessionButton").disabled).is_true()
	assert_bool(_button(panel, "DeleteSessionButton").disabled).is_true()

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

	assert_bool(_prompt_input(panel).editable).is_true()
	assert_bool(_button(panel, "RenameSessionButton").disabled).is_true()
	assert_bool(_button(panel, "DeleteSessionButton").disabled).is_true()

	panel.disconnect_client()
	await _await_frames(2)
	assert_bool(_prompt_input(panel).editable).is_false()
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)

	await _cleanup_panel(panel)


func test_panel_connected_idle_allows_live_session_switching_and_new_chat_reset() -> void:
	var config_root := _create_config_root("panel-live-switch")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)
	var project_path := ProjectSettings.globalize_path("res://")
	var project_dir := _make_project_dir(config_root, project_path)
	var first_session_id := "51515151-5151-4515-8515-515151515151"
	var second_session_id := "61616161-6161-4616-8616-616161616161"
	_write_panel_session(project_dir, project_path, first_session_id, "First saved session", "First prompt", "First answer", "alpha", 1712302200)
	_write_panel_session(project_dir, project_path, second_session_id, "Second saved session", "Second prompt", "Second answer", "beta", 1712302300)

	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)
	await _await_frames(2)

	assert_int(_session_list(panel).item_count).is_equal(2)
	assert_bool(_prompt_input(panel).editable).is_true()
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	assert_str(_session_id_from_panel(panel)).is_equal(second_session_id)
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Second saved session")
	assert_bool(_button(panel, "RenameSessionButton").disabled).is_true()
	assert_bool(_button(panel, "DeleteSessionButton").disabled).is_true()

	panel.submit_prompt("Switch to the selected history")
	await _await_frames(2)
	var first_live_write: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str(first_live_write.get("session_id", ""))).is_equal(second_session_id)

	_select_session_with_click_signal(panel, 1)
	await _await_frames(2)
	assert_str(_session_id_from_panel(panel)).is_equal(second_session_id)

	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 8,
		"is_error": false,
		"num_turns": 1,
		"session_id": second_session_id,
		"result": "Done",
	})
	await _await_frames(3)

	_activate_session_with_keyboard_signal(panel, 1)
	await _await_frames(2)
	assert_str(_session_id_from_panel(panel)).is_equal(first_session_id)

	_button(panel, "NewChatButton").pressed.emit()
	await _await_frames(2)
	assert_str(_session_id_from_panel(panel)).is_equal("")
	assert_int(_transcript_list(panel).get_child_count()).is_equal(0)

	panel.submit_prompt("Fresh turn after reset")
	await _await_frames(2)
	var reset_write: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str(reset_write.get("session_id", ""))).is_equal("default")

	await _cleanup_panel(panel)


func test_panel_session_mutation_controls_update_selected_session() -> void:
	_create_panel_session_fixture("panel-mutations")
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	var title_input := panel.find_child("SessionTitleInput", true, false) as LineEdit
	var tag_input := panel.find_child("SessionTagInput", true, false) as LineEdit
	title_input.text = "Renamed in panel"
	_button(panel, "RenameSessionButton").pressed.emit()
	await _await_frames(2)
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Renamed in panel")
	assert_str(_session_list(panel).get_item_text(0)).contains("Renamed in panel")

	tag_input.text = "focus"
	_button(panel, "ApplyTagButton").pressed.emit()
	await _await_frames(2)
	assert_str(_label(panel, "SelectedSessionMetaValue").text).contains("focus")

	_button(panel, "ClearTagButton").pressed.emit()
	await _await_frames(2)
	assert_bool(_label(panel, "SelectedSessionMetaValue").text.contains("focus")).is_false()

	_button(panel, "DeleteSessionButton").pressed.emit()
	await _await_frames(1)
	assert_bool(_button(panel, "ConfirmDeleteButton").visible).is_true()
	_button(panel, "ConfirmDeleteButton").pressed.emit()
	await _await_frames(2)
	assert_int(_session_list(panel).item_count).is_equal(0)
	assert_int(_transcript_list(panel).get_child_count()).is_equal(0)

	await _cleanup_panel(panel)


func test_panel_keeps_selected_worktree_session_identity_for_mutations() -> void:
	var fixture := _create_duplicate_worktree_session_fixture("panel-worktree-selection")
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"cwd": fixture["repo_root"],
	}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)

	assert_int(_session_list(panel).item_count).is_equal(1)
	assert_str(_session_list(panel).get_item_text(0)).contains("Worktree session")
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	assert_str(_label(panel, "SelectedSessionCwdValue").text).contains(str(fixture["worktree_root"]))
	var title_input := panel.find_child("SessionTitleInput", true, false) as LineEdit
	title_input.text = "Worktree renamed"
	_button(panel, "RenameSessionButton").pressed.emit()
	await _await_frames(2)

	assert_bool(FileAccess.get_file_as_string(str(fixture["repo_file"])).contains('"customTitle":"Worktree renamed"')).is_false()
	assert_bool(FileAccess.get_file_as_string(str(fixture["worktree_file"])).contains('"customTitle":"Worktree renamed"')).is_true()

	await _cleanup_panel(panel)


func test_panel_default_split_favors_chat_column() -> void:
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(3)

	var split_row := panel.find_child("SplitRow", true, false) as HSplitContainer
	var session_pane := panel.find_child("SessionPane", true, false) as Control
	var chat_column := panel.find_child("ChatColumn", true, false) as Control
	assert_object(split_row).is_not_null()
	assert_bool(session_pane.size.x < chat_column.size.x).is_true()
	var session_ratio := float(session_pane.size.x) / maxf(1.0, float(split_row.size.x))
	assert_bool(session_ratio > 0.30 and session_ratio < 0.48).is_true()

	await _cleanup_panel(panel)


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


func _cleanup_panel(panel) -> void:
	if panel == null:
		return
	panel.disconnect_client()
	await _await_frames(2)
	panel.queue_free()
	await _await_frames(2)


func _status_badge(panel) -> Label:
	return _label(panel, "StatusBadgeLabel")


func _button(panel, node_name: String) -> Button:
	return panel.find_child(node_name, true, false) as Button


func _label(panel, node_name: String) -> Label:
	return panel.find_child(node_name, true, false) as Label


func _prompt_input(panel) -> TextEdit:
	return panel.find_child("PromptInput", true, false) as TextEdit


func _session_list(panel) -> ItemList:
	return panel.find_child("SessionList", true, false) as ItemList


func _transcript_list(panel) -> VBoxContainer:
	return panel.find_child("TranscriptList", true, false) as VBoxContainer


func _select_session_with_click_signal(panel, index: int) -> void:
	var list := _session_list(panel)
	assert_int(list.select_mode).is_equal(ItemList.SELECT_SINGLE)
	list.select(index)
	list.item_selected.emit(index)


func _activate_session_with_keyboard_signal(panel, index: int) -> void:
	var list := _session_list(panel)
	assert_int(list.select_mode).is_equal(ItemList.SELECT_SINGLE)
	list.select(index)
	list.item_activated.emit(index)


func _session_id_from_panel(panel) -> String:
	return str(panel.get("_selected_session_id"))


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


func _create_panel_session_fixture(label: String) -> String:
	var config_root := _create_config_root(label)
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_path := ProjectSettings.globalize_path("res://")
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "41414141-4141-4414-8414-414141414141"
	_write_panel_session(project_dir, project_path, session_id, "Restored session", "Saved prompt", "Saved answer", "review", 1712302200)
	return session_id


func _create_duplicate_worktree_session_fixture(label: String) -> Dictionary:
	var config_root := _create_config_root(label)
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var repo_root := _create_temp_root("panel-worktree-repo")
	var worktree_parent := _create_temp_root("panel-worktree-parent")
	var worktree_root := worktree_parent.path_join("feature-panel")
	_init_git_repo(repo_root)
	_create_git_worktree(repo_root, worktree_root, "feature/panel")

	var session_id := "42424242-4242-4424-8424-424242424242"
	var repo_project_dir := _make_project_dir(config_root, repo_root)
	var worktree_project_dir := _make_project_dir(config_root, worktree_root)
	var repo_file := repo_project_dir.path_join("%s.jsonl" % session_id)
	var worktree_file := worktree_project_dir.path_join("%s.jsonl" % session_id)
	_write_session_file(repo_project_dir, session_id, [
		{
			"type": "user",
			"uuid": "dup-u-1",
			"sessionId": session_id,
			"timestamp": "2026-04-05T14:00:00",
			"cwd": repo_root,
			"message": {"role": "user", "content": "Repo prompt"},
		},
		{"type": "summary", "customTitle": "Repo session"},
	], 1712302500)
	_write_session_file(worktree_project_dir, session_id, [
		{
			"type": "user",
			"uuid": "dup-u-2",
			"sessionId": session_id,
			"timestamp": "2026-04-05T14:10:00",
			"cwd": worktree_root,
			"message": {"role": "user", "content": "Worktree prompt"},
		},
		{"type": "summary", "customTitle": "Worktree session"},
	], 1712302600)

	return {
		"repo_root": repo_root,
		"worktree_root": worktree_root,
		"repo_file": repo_file,
		"worktree_file": worktree_file,
	}


func _create_config_root(label: String) -> String:
	var root_path := _create_temp_root("panel-config-%s" % label)
	DirAccess.make_dir_recursive_absolute(root_path.path_join("projects"))
	return root_path


func _create_temp_root(label: String) -> String:
	var root_path := ClaudeSessionsScript._resolve_absolute_path(
		ProjectSettings.globalize_path("user://%s-%s" % [label, Time.get_ticks_usec()])
	)
	DirAccess.make_dir_recursive_absolute(root_path)
	_created_roots.append(root_path)
	return root_path


func _make_project_dir(config_root: String, project_path: String) -> String:
	var sanitized := ClaudeSessionsScript._sanitize_path(
		ClaudeSessionsScript._resolve_absolute_path(project_path)
	)
	var project_dir := config_root.path_join("projects").path_join(sanitized)
	DirAccess.make_dir_recursive_absolute(project_dir)
	return project_dir


func _write_session_file(project_dir: String, session_id: String, entries: Array, mtime: int) -> void:
	var file := FileAccess.open(project_dir.path_join("%s.jsonl" % session_id), FileAccess.WRITE)
	for entry in entries:
		file.store_line(JSON.stringify(entry))
	file.close()
	var output: Array = []
	OS.execute("python3", [
		"-c",
		"import os, sys; ts=int(sys.argv[2]); os.utime(sys.argv[1], (ts, ts))",
		project_dir.path_join("%s.jsonl" % session_id),
		str(mtime),
	], output, true)


func _write_panel_session(
	project_dir: String,
	project_path: String,
	session_id: String,
	title: String,
	prompt: String,
	answer: String,
	tag: String,
	mtime: int
) -> void:
	_write_session_file(project_dir, session_id, [
		{
			"type": "user",
			"uuid": "%s-u-1" % session_id,
			"sessionId": session_id,
			"timestamp": "2026-04-05T13:00:00",
			"cwd": project_path,
			"message": {"role": "user", "content": prompt},
		},
		{
			"type": "assistant",
			"uuid": "%s-a-1" % session_id,
			"parentUuid": "%s-u-1" % session_id,
			"sessionId": session_id,
			"message": {"role": "assistant", "content": answer},
		},
		{"type": "summary", "customTitle": title},
		{"type": "tag", "tag": tag},
	], mtime)


func _delete_tree(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return
	var access := DirAccess.open(path)
	if access == null:
		return
	for directory_name in access.get_directories():
		_delete_tree(path.path_join(directory_name))
	for file_name in access.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


func _init_git_repo(repo_root: String) -> void:
	var output: Array = []
	OS.execute("git", ["init", repo_root], output, true)
	OS.execute("git", ["-C", repo_root, "config", "user.email", "sdk@example.com"], output, true)
	OS.execute("git", ["-C", repo_root, "config", "user.name", "Claude SDK"], output, true)
	var readme := FileAccess.open(repo_root.path_join("README.txt"), FileAccess.WRITE)
	readme.store_string("repo\n")
	readme.close()
	OS.execute("git", ["-C", repo_root, "add", "README.txt"], output, true)
	OS.execute("git", ["-C", repo_root, "commit", "-m", "init"], output, true)


func _create_git_worktree(repo_root: String, worktree_root: String, branch_name: String) -> void:
	var output: Array = []
	OS.execute("git", ["-C", repo_root, "worktree", "add", worktree_root, "-b", branch_name], output, true)
