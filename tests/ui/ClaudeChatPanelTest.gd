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


func test_panel_loads_chat_configuration_controls_from_options() -> void:
	var sdk_server := ClaudeMcp.create_sdk_server(
		"gameplay",
		"1.0.0",
		[]
	)
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"permission_mode": "plan",
		"system_prompt": {"type": "preset", "preset": "claude_code", "append": "Stay in-universe."},
		"tools": {"type": "preset", "preset": "claude_code"},
		"allowed_tools": ["Read", "Glob"],
		"disallowed_tools": ["Edit"],
		"mcp_servers": {
			"gameplay": sdk_server,
			"filesystem": {"command": "mcp-server", "args": ["stdio"]},
		},
	}), FakeTransportScript.new())

	get_tree().root.add_child(panel)
	await _await_frames(2)

	assert_bool(_button(panel, "ChatViewButton").button_pressed).is_true()
	assert_bool(_button(panel, "SettingsViewButton").button_pressed).is_false()
	assert_bool(_control(panel, "SettingsScroll").visible).is_false()
	assert_bool(_button(panel, "ThinkingToggle").button_pressed).is_false()
	assert_bool(_button(panel, "TasksToggle").button_pressed).is_false()
	assert_bool(_button(panel, "ToolsToggle").button_pressed).is_false()
	assert_bool(_button(panel, "ResultsToggle").button_pressed).is_true()
	assert_bool(_button(panel, "SystemToggle").button_pressed).is_false()
	assert_bool(_button(panel, "RawToggle").button_pressed).is_false()
	assert_str(_selected_option_text(panel, "ModelQuickOption")).is_equal("haiku")
	assert_str(_selected_option_text(panel, "EffortQuickOption")).is_equal("low")
	assert_str(_selected_option_text(panel, "PermissionQuickOption")).is_equal("plan")

	_show_settings_view(panel)
	await _await_frames(1)

	assert_str(_option_button(panel, "SystemPromptModeOption").get_item_text(_option_button(panel, "SystemPromptModeOption").selected)).is_equal("Preset + append")
	assert_str(_text_edit(panel, "SystemPromptTextInput").text).is_equal("Stay in-universe.")
	assert_str(_label(panel, "BuiltInToolsSummaryValue").text).is_equal("All default built-in tools enabled.")
	assert_int(_checked_built_in_tool_count(panel)).is_equal(ClaudeBuiltInToolCatalog.list_default_tools().size())
	assert_bool(_button(panel, "ToolRulesAdvancedToggle").button_pressed).is_true()
	assert_str(_line_edit(panel, "AllowedToolsInput").text).is_equal("Read,Glob")
	assert_str(_line_edit(panel, "DisallowedToolsInput").text).is_equal("Edit")
	assert_str(_label(panel, "McpSummaryValue").text).contains("gameplay")
	assert_str(_label(panel, "McpSummaryValue").text).contains("filesystem")

	await _cleanup_panel(panel)


func test_panel_disconnected_chat_configuration_controls_update_options_and_lock_when_connected() -> void:
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	_option_button(panel, "ModelQuickOption").select(1)
	_option_button(panel, "ModelQuickOption").item_selected.emit(1)
	_option_button(panel, "EffortQuickOption").select(2)
	_option_button(panel, "EffortQuickOption").item_selected.emit(2)
	_option_button(panel, "PermissionQuickOption").select(1)
	_option_button(panel, "PermissionQuickOption").item_selected.emit(1)
	_show_settings_view(panel)
	await _await_frames(1)

	_option_button(panel, "SystemPromptModeOption").select(4)
	_option_button(panel, "SystemPromptModeOption").item_selected.emit(4)
	_line_edit(panel, "SystemPromptFileInput").text = "res://prompts/game-assistant.md"
	_line_edit(panel, "SystemPromptFileInput").text_changed.emit("res://prompts/game-assistant.md")
	_button(panel, "BuiltInToolGroupReadNoneButton").pressed.emit()
	_button(panel, "BuiltInToolGroupWriteNoneButton").pressed.emit()
	_button(panel, "BuiltInToolGroupAutomationNoneButton").pressed.emit()
	_button(panel, "BuiltInToolGroupWebNoneButton").pressed.emit()
	_built_in_tool_checkbox(panel, "Read").button_pressed = true
	_built_in_tool_checkbox(panel, "Read").toggled.emit(true)
	_built_in_tool_checkbox(panel, "Glob").button_pressed = true
	_built_in_tool_checkbox(panel, "Glob").toggled.emit(true)
	_built_in_tool_checkbox(panel, "Grep").button_pressed = true
	_built_in_tool_checkbox(panel, "Grep").toggled.emit(true)
	_button(panel, "ToolRulesAdvancedToggle").button_pressed = true
	_button(panel, "ToolRulesAdvancedToggle").toggled.emit(true)
	_line_edit(panel, "AllowedToolsInput").text = "Read,Glob"
	_line_edit(panel, "AllowedToolsInput").text_changed.emit("Read,Glob")
	_line_edit(panel, "DisallowedToolsInput").text = "Edit"
	_line_edit(panel, "DisallowedToolsInput").text_changed.emit("Edit")
	await _await_frames(2)

	var configured_options = panel.get("_configured_options") as ClaudeAgentOptions
	assert_str(configured_options.model).is_equal("sonnet")
	assert_str(configured_options.effort).is_equal("high")
	assert_str(configured_options.permission_mode).is_equal("plan")
	assert_dict(configured_options.system_prompt).is_equal({
		"type": "file",
		"path": "res://prompts/game-assistant.md",
	})
	assert_array(configured_options.tools).is_equal(["Read", "Glob", "Grep"])
	assert_array(configured_options.allowed_tools).is_equal(["Read", "Glob"])
	assert_array(configured_options.disallowed_tools).is_equal(["Edit"])
	assert_str(_label(panel, "BuiltInToolsSummaryValue").text).contains("3 of")
	assert_str(_selected_option_text(panel, "ModelQuickOption")).is_equal("sonnet")
	assert_str(_selected_option_text(panel, "EffortQuickOption")).is_equal("high")
	assert_str(_selected_option_text(panel, "PermissionQuickOption")).is_equal("plan")

	panel.connect_client()
	await _await_frames(1)

	var runtime_options = panel.get_client_node()._adapter._client.options
	assert_dict(runtime_options.system_prompt).is_equal({
		"type": "file",
		"path": "res://prompts/game-assistant.md",
	})
	assert_array(runtime_options.tools).is_equal(["Read", "Glob", "Grep"])
	assert_str(runtime_options.effort).is_equal("high")
	assert_bool(_option_button(panel, "SystemPromptModeOption").disabled).is_true()
	assert_bool(_built_in_tool_checkbox(panel, "Read").disabled).is_true()
	assert_bool(_line_edit(panel, "AllowedToolsInput").editable).is_false()

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

	assert_bool(_option_button(panel, "ModelQuickOption").disabled).is_false()
	assert_bool(_option_button(panel, "EffortQuickOption").disabled).is_true()
	assert_bool(_option_button(panel, "PermissionQuickOption").disabled).is_false()

	_option_button(panel, "ModelQuickOption").select(2)
	_option_button(panel, "ModelQuickOption").item_selected.emit(2)
	var live_model_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((live_model_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("set_model")

	_option_button(panel, "PermissionQuickOption").select(3)
	_option_button(panel, "PermissionQuickOption").item_selected.emit(3)
	var live_permission_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((live_permission_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("set_permission_mode")
	assert_str(configured_options.model).is_equal("opus")
	assert_str(configured_options.permission_mode).is_equal("bypassPermissions")

	await _cleanup_panel(panel)


func test_panel_live_session_diagnostics_fetch_and_render_context_and_mcp_status() -> void:
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	panel.connect_client()
	var init_request := _last_control_request_by_subtype(transport, "initialize")
	_emit_success_control_response(transport, init_request, {"commands": [{"name": "/help"}]})
	await _await_frames(2)

	var context_request := _last_control_request_by_subtype(transport, "get_context_usage")
	assert_dict(context_request).is_not_empty()
	_emit_success_control_response(transport, context_request, {
		"categories": [
			{"name": "System prompt", "tokens": 3200, "color": "#abc"},
			{"name": "Messages", "tokens": 61400, "color": "#def"},
		],
		"totalTokens": 98200,
		"maxTokens": 155000,
		"rawMaxTokens": 200000,
		"percentage": 49.1,
		"model": "claude-sonnet-4-5",
		"isAutoCompactEnabled": true,
		"memoryFiles": [{"path": "CLAUDE.md", "type": "project", "tokens": 512}],
		"mcpTools": [{"name": "search", "serverName": "ref", "tokens": 164, "isLoaded": true}],
		"agents": [{"agentType": "coder", "source": "sdk", "tokens": 299}],
		"gridRows": [],
	})
	await _await_frames(2)

	var mcp_status_request := _last_control_request_by_subtype(transport, "mcp_status")
	assert_dict(mcp_status_request).is_not_empty()
	_emit_success_control_response(transport, mcp_status_request, {
		"mcpServers": [
			{
				"name": "my-http-server",
				"status": "connected",
				"serverInfo": {"name": "my-http-server", "version": "1.0.0"},
				"config": {"type": "http", "url": "https://example.com/mcp"},
				"scope": "project",
				"tools": [{"name": "greet"}, {"name": "reset"}],
			},
			{
				"name": "failed-server",
				"status": "failed",
				"error": "Connection refused",
			},
			{
				"name": "proxy-server",
				"status": "needs-auth",
				"config": {"type": "claudeai-proxy", "id": "proxy-123"},
			},
		],
	})
	await _await_frames(2)
	_show_settings_view(panel)
	await _await_frames(1)

	assert_bool(_control(panel, "LiveSessionSection").visible).is_true()
	assert_str(_label(panel, "LiveContextSummaryValue").text).contains("49.1")
	assert_str(_label(panel, "LiveContextSummaryValue").text).contains("98200")
	assert_str(_label(panel, "LiveContextDetailValue").text).contains("System prompt 3200")
	assert_str(_label(panel, "LiveMcpSummaryValue").text).contains("3 servers")
	assert_object(panel.find_child("McpServerRow_my_http_server", true, false)).is_not_null()
	assert_str(_label(panel, "McpServerDetail_failed_server").text).contains("Connection refused")
	assert_bool(_button(panel, "McpReconnectButton_failed_server").visible).is_true()
	assert_str(_button(panel, "McpToggleButton_my_http_server").text).is_equal("Disable")

	await _cleanup_panel(panel)


func test_panel_mcp_server_actions_send_control_requests_and_refresh_rendered_status() -> void:
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	panel.connect_client()
	var init_request := _last_control_request_by_subtype(transport, "initialize")
	_emit_success_control_response(transport, init_request, {"commands": [{"name": "/help"}]})
	await _await_frames(2)

	var context_request := _last_control_request_by_subtype(transport, "get_context_usage")
	_emit_success_control_response(transport, context_request, {
		"categories": [],
		"totalTokens": 100,
		"maxTokens": 1000,
		"rawMaxTokens": 1000,
		"percentage": 10.0,
		"model": "haiku",
		"isAutoCompactEnabled": true,
		"memoryFiles": [],
		"mcpTools": [],
		"agents": [],
		"gridRows": [],
	})
	await _await_frames(2)

	var initial_mcp_request := _last_control_request_by_subtype(transport, "mcp_status")
	_emit_success_control_response(transport, initial_mcp_request, {
		"mcpServers": [
			{"name": "failed-server", "status": "failed", "error": "Connection refused"},
			{"name": "connected-server", "status": "connected", "tools": [{"name": "read"}]},
		],
	})
	await _await_frames(2)
	_show_settings_view(panel)
	await _await_frames(1)

	_button(panel, "McpReconnectButton_failed_server").pressed.emit()
	await _await_frames(1)
	var reconnect_request := _last_control_request_by_subtype(transport, "mcp_reconnect")
	assert_str(str((reconnect_request.get("request", {}) as Dictionary).get("serverName", ""))).is_equal("failed-server")
	_emit_success_control_response(transport, reconnect_request, {})
	await _await_frames(1)

	var refresh_after_reconnect := _last_control_request_by_subtype(transport, "mcp_status")
	assert_str(str(refresh_after_reconnect.get("request_id", ""))).is_not_equal(str(initial_mcp_request.get("request_id", "")))
	_emit_success_control_response(transport, refresh_after_reconnect, {
		"mcpServers": [
			{"name": "failed-server", "status": "connected", "tools": [{"name": "repair"}]},
			{"name": "connected-server", "status": "connected", "tools": [{"name": "read"}]},
		],
	})
	await _await_frames(2)
	assert_bool(_button(panel, "McpReconnectButton_failed_server").visible).is_false()

	_button(panel, "McpToggleButton_connected_server").pressed.emit()
	await _await_frames(1)
	var toggle_request := _last_control_request_by_subtype(transport, "mcp_toggle")
	assert_str(str((toggle_request.get("request", {}) as Dictionary).get("serverName", ""))).is_equal("connected-server")
	assert_bool(bool((toggle_request.get("request", {}) as Dictionary).get("enabled", true))).is_false()
	_emit_success_control_response(transport, toggle_request, {})
	await _await_frames(1)

	var refresh_after_toggle := _last_control_request_by_subtype(transport, "mcp_status")
	assert_str(str(refresh_after_toggle.get("request_id", ""))).is_not_equal(str(refresh_after_reconnect.get("request_id", "")))
	_emit_success_control_response(transport, refresh_after_toggle, {
		"mcpServers": [
			{"name": "failed-server", "status": "connected", "tools": [{"name": "repair"}]},
			{"name": "connected-server", "status": "disabled"},
		],
	})
	await _await_frames(2)
	assert_str(_button(panel, "McpToggleButton_connected_server").text).is_equal("Enable")

	await _cleanup_panel(panel)


func test_panel_rewind_support_toggle_loads_and_preserves_unrelated_extra_args() -> void:
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"enable_file_checkpointing": true,
		"extra_args": {
			"replay-user-messages": null,
			"debug-to-stderr": null,
		},
	}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)
	_show_settings_view(panel)
	await _await_frames(1)

	var rewind_toggle := _check_box(panel, "RewindSupportToggle")
	assert_bool(rewind_toggle.button_pressed).is_true()

	rewind_toggle.button_pressed = false
	rewind_toggle.toggled.emit(false)
	await _await_frames(1)

	var configured_options = panel.get("_configured_options") as ClaudeAgentOptions
	assert_bool(configured_options.enable_file_checkpointing).is_false()
	assert_bool(configured_options.extra_args.has("replay-user-messages")).is_false()
	assert_bool(configured_options.extra_args.has("debug-to-stderr")).is_true()

	rewind_toggle.button_pressed = true
	rewind_toggle.toggled.emit(true)
	await _await_frames(1)

	assert_bool(configured_options.enable_file_checkpointing).is_true()
	assert_bool(configured_options.extra_args.has("replay-user-messages")).is_true()
	assert_bool(configured_options.extra_args.has("debug-to-stderr")).is_true()

	await _cleanup_panel(panel)


func test_panel_built_in_tool_picker_maps_all_none_and_partial_selection() -> void:
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)
	_show_settings_view(panel)
	await _await_frames(1)

	var configured_options = panel.get("_configured_options") as ClaudeAgentOptions
	assert_that(configured_options.tools).is_null()
	assert_str(_label(panel, "BuiltInToolsSummaryValue").text).is_equal("All default built-in tools enabled.")

	_button(panel, "BuiltInToolGroupReadNoneButton").pressed.emit()
	_button(panel, "BuiltInToolGroupWriteNoneButton").pressed.emit()
	_button(panel, "BuiltInToolGroupAutomationNoneButton").pressed.emit()
	_button(panel, "BuiltInToolGroupWebNoneButton").pressed.emit()
	await _await_frames(1)
	assert_array(configured_options.tools).is_empty()
	assert_str(_label(panel, "BuiltInToolsSummaryValue").text).is_equal("No built-in tools enabled.")

	_built_in_tool_checkbox(panel, "Read").button_pressed = true
	_built_in_tool_checkbox(panel, "Read").toggled.emit(true)
	_built_in_tool_checkbox(panel, "WebSearch").button_pressed = true
	_built_in_tool_checkbox(panel, "WebSearch").toggled.emit(true)
	await _await_frames(1)
	assert_array(configured_options.tools).is_equal(["Read", "WebSearch"])

	_button(panel, "BuiltInToolGroupReadAllButton").pressed.emit()
	_button(panel, "BuiltInToolGroupWriteAllButton").pressed.emit()
	_button(panel, "BuiltInToolGroupAutomationAllButton").pressed.emit()
	_button(panel, "BuiltInToolGroupWebAllButton").pressed.emit()
	await _await_frames(1)
	assert_dict(configured_options.tools).is_equal({"type": "preset", "preset": "claude_code"})
	assert_str(_label(panel, "BuiltInToolsSummaryValue").text).is_equal("All default built-in tools enabled.")

	await _cleanup_panel(panel)


func test_panel_saved_session_rewind_action_appears_after_connect() -> void:
	var session_id := _create_panel_session_fixture("rewind-session")
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"enable_file_checkpointing": true,
		"extra_args": {"replay-user-messages": null},
	}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	assert_str(_session_id_from_panel(panel)).is_empty()
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)
	assert_str(_session_id_from_panel(panel)).is_equal(session_id)

	var disconnected_button := _last_entry(panel, "user_bubble").find_child("RewindButton", true, false) as Button
	assert_object(disconnected_button).is_not_null()
	assert_bool(disconnected_button.is_visible_in_tree()).is_false()

	panel.connect_client()
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(2)

	var connected_button := _last_entry(panel, "user_bubble").find_child("RewindButton", true, false) as Button
	assert_object(connected_button).is_not_null()
	assert_bool(connected_button.is_visible_in_tree()).is_true()

	await _cleanup_panel(panel)


func test_panel_saved_session_cutoff_fork_action_only_appears_on_disconnected_selected_user_entries() -> void:
	_create_panel_session_fixture("cutoff-fork-visibility")
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	var user_entry := _entry_at(panel, "user_bubble", 0)
	var disconnected_fork_button := user_entry.find_child("ForkFromHereButton", true, false) as Button
	assert_object(disconnected_fork_button).is_not_null()
	assert_bool(disconnected_fork_button.is_visible_in_tree()).is_true()
	var assistant_entry := _entry_at(panel, "assistant_bubble", 0)
	assert_object(assistant_entry.find_child("ForkFromHereButton", true, false)).is_null()

	panel.connect_client()
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(2)

	var connected_fork_button := _entry_at(panel, "user_bubble", 0).find_child("ForkFromHereButton", true, false) as Button
	assert_object(connected_fork_button).is_not_null()
	assert_bool(connected_fork_button.is_visible_in_tree()).is_false()

	await _cleanup_panel(panel)


func test_panel_defaults_to_chat_view_and_switches_to_settings_view() -> void:
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)

	assert_bool(_button(panel, "ChatViewButton").button_pressed).is_true()
	assert_bool(_control(panel, "SplitRow").visible).is_true()
	assert_bool(_control(panel, "SettingsScroll").visible).is_false()
	assert_object(_control(panel, "ChatSummaryCard")).is_null()

	_show_settings_view(panel)
	await _await_frames(1)

	assert_bool(_button(panel, "SettingsViewButton").button_pressed).is_true()
	assert_bool(_control(panel, "SplitRow").visible).is_false()
	assert_bool(_control(panel, "SettingsScroll").visible).is_true()

	_button(panel, "ChatViewButton").pressed.emit()
	await _await_frames(1)
	assert_bool(_control(panel, "SplitRow").visible).is_true()
	assert_bool(_control(panel, "SettingsScroll").visible).is_false()

	await _cleanup_panel(panel)


func test_panel_rewind_button_uses_echoed_user_uuid_and_sends_control_request() -> void:
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"enable_file_checkpointing": true,
		"extra_args": {"replay-user-messages": null},
	}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	panel.connect_client()
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(2)

	panel.submit_prompt("Please refactor files")
	await _await_frames(1)
	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)

	transport.emit_stdout_message({
		"type": "user",
		"uuid": "live-user-1",
		"session_id": "default",
		"message": {
			"role": "user",
			"content": "Please refactor files",
		},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 120,
		"duration_api_ms": 80,
		"num_turns": 1,
		"session_id": "default",
		"result": "Done",
		"uuid": "result-live-1",
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)
	var rewind_button := _last_entry(panel, "user_bubble").find_child("RewindButton", true, false) as Button
	assert_object(rewind_button).is_not_null()
	assert_bool(rewind_button.is_visible_in_tree()).is_true()

	rewind_button.pressed.emit()
	await _await_frames(1)

	var rewind_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((rewind_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("rewind_files")
	assert_str(str((rewind_request.get("request", {}) as Dictionary).get("user_message_id", ""))).is_equal("live-user-1")
	assert_str(rewind_button.text).is_equal("Rewinding...")

	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(rewind_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(2)

	assert_str(rewind_button.text).is_equal("Rewind files here")
	assert_int(_count_entries(panel, "system_card")).is_equal(0)

	await _cleanup_panel(panel)


func test_panel_selected_session_connect_and_send_keeps_rewind_visible_for_default_wire_session_id() -> void:
	var session_id := _create_panel_session_fixture("rewind-connect-send")
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"enable_file_checkpointing": true,
		"extra_args": {"replay-user-messages": null},
	}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	_prompt_input(panel).text = "Continue selected"
	_prompt_input(panel).text_changed.emit()
	_button(panel, "SendButton").pressed.emit()
	await _await_frames(1)

	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	transport.emit_stdout_message({
		"type": "user",
		"uuid": "resume-user-1",
		"session_id": "default",
		"message": {
			"role": "user",
			"content": "Continue selected",
		},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 120,
		"duration_api_ms": 80,
		"num_turns": 1,
		"session_id": session_id,
		"result": "Resumed",
		"uuid": "resume-result-1",
	})
	await _await_frames(2)

	var rewind_button := _last_entry(panel, "user_bubble").find_child("RewindButton", true, false) as Button
	assert_object(rewind_button).is_not_null()
	assert_bool(rewind_button.is_visible_in_tree()).is_true()

	await _cleanup_panel(panel)


func test_panel_rewind_failure_emits_single_error_and_keeps_connected_status() -> void:
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"enable_file_checkpointing": true,
		"extra_args": {"replay-user-messages": null},
	}), transport)
	var errors: Array[String] = []
	panel.error_occurred.connect(func(message: String): errors.append(message))
	get_tree().root.add_child(panel)
	await _await_frames(2)

	panel.connect_client()
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(2)

	panel.submit_prompt("Please refactor files")
	await _await_frames(1)
	transport.emit_stdout_message({
		"type": "user",
		"uuid": "live-user-error-1",
		"session_id": "default",
		"message": {
			"role": "user",
			"content": "Please refactor files",
		},
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 120,
		"duration_api_ms": 80,
		"num_turns": 1,
		"session_id": "default",
		"result": "Done",
		"uuid": "result-live-error-1",
	})
	await _await_frames(2)

	var rewind_button := _last_entry(panel, "user_bubble").find_child("RewindButton", true, false) as Button
	assert_object(rewind_button).is_not_null()
	rewind_button.pressed.emit()
	await _await_frames(1)

	var rewind_request: Dictionary = JSON.parse_string(transport.writes[-1])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "error",
			"request_id": str(rewind_request.get("request_id", "")),
			"error": "rewind denied",
		},
	})
	await _await_frames(2)

	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("rewind denied")
	assert_str(_label(panel, "StatusTitleLabel").text).is_equal("Connected to Claude")

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
	assert_int(_count_entries(panel, "system_card")).is_equal(0)
	_button(panel, "SystemToggle").button_pressed = true
	_button(panel, "SystemToggle").toggled.emit(true)
	await _await_frames(2)
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
	assert_bool(_prompt_input(panel).editable).is_true()
	assert_bool(_button(panel, "ConnectButton").disabled).is_false()

	await _cleanup_panel(panel)


func test_panel_disconnected_send_connects_with_prompt_and_restores_composer_after_result() -> void:
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	_prompt_input(panel).text = "Hello from disconnected"
	_prompt_input(panel).text_changed.emit()
	await _await_frames(1)

	assert_bool(_button(panel, "SendButton").disabled).is_false()
	_button(panel, "SendButton").pressed.emit()
	await _await_frames(1)

	assert_str(_status_badge(panel).text).is_equal("Connecting")
	assert_bool(_prompt_input(panel).editable).is_false()
	assert_bool(_button(panel, "SendButton").disabled).is_true()
	assert_str(_prompt_input(panel).text).is_equal("")
	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)
	var disconnected_user_body := _last_entry(panel, "user_bubble").find_child("BubbleBody", true, false) as RichTextLabel
	assert_object(disconnected_user_body).is_not_null()
	assert_str(disconnected_user_body.text).contains("Hello from disconnected")

	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/help"}]},
		},
	})
	await _await_frames(1)

	var prompt_payload: Dictionary = JSON.parse_string(transport.writes[1])
	assert_str(str(prompt_payload.get("session_id", ""))).is_equal("default")
	assert_str(str((prompt_payload.get("message", {}) as Dictionary).get("content", ""))).is_equal("Hello from disconnected")

	transport.emit_stdout_message({
		"type": "user",
		"session_id": "default",
		"message": {"role": "user", "content": "Hello from disconnected"},
		"parent_tool_use_id": null,
	})
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 8,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "Connected",
	})
	await _await_frames(3)

	assert_bool(_prompt_input(panel).editable).is_true()
	assert_bool(_button(panel, "SendButton").disabled).is_true()
	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)

	await _cleanup_panel(panel)


func test_panel_disconnected_send_discards_optimistic_user_bubble_when_connect_fails() -> void:
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	panel.submit_prompt("Fail to connect")
	await _await_frames(1)

	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
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
	assert_int(_count_entries(panel, "user_bubble")).is_equal(0)

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
	assert_int(_count_entries(panel, "result_card")).is_equal(0)
	assert_bool(_button(panel, "InterruptButton").disabled).is_true()

	await _cleanup_panel(panel)


func test_panel_rate_limit_events_render_under_system_toggle_without_affecting_turn_completion() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)
	var turn_finished_events: Array[int] = []

	panel.turn_finished.connect(func(_message: ClaudeResultMessage): turn_finished_events.append(1))
	panel.submit_prompt("Hello from the panel")
	transport.emit_stdout_message({
		"type": "rate_limit_event",
		"rate_limit_info": {
			"status": "allowed_warning",
			"resetsAt": 1700000000,
			"rateLimitType": "five_hour",
			"utilization": 0.91,
		},
		"uuid": "rate-panel-1",
		"session_id": "default",
	})
	await _await_frames(2)

	assert_int(turn_finished_events.size()).is_equal(0)
	assert_int(_count_entries(panel, "system_card")).is_equal(0)
	assert_bool(_button(panel, "InterruptButton").disabled).is_false()

	_button(panel, "SystemToggle").button_pressed = true
	_button(panel, "SystemToggle").toggled.emit(true)
	await _await_frames(2)

	assert_int(_count_entries(panel, "system_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "system_card")).contains("Status: Allowed Warning")
	assert_str(_last_card_body_text(panel, "system_card")).contains("Utilization: 91%")
	assert_str(_last_card_body_text(panel, "system_card")).contains("\"rateLimitType\": \"five_hour\"")

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
	await _await_frames(2)

	assert_int(turn_finished_events.size()).is_equal(1)
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
		"event": {"type": "content_block_delta", "delta": {"type": "text_delta", "text": "1, 2, "}},
	})
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-2",
		"event": {"type": "content_block_delta", "delta": {"type": "text_delta", "text": "3, 4"}},
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
		"event": {"type": "content_block_delta", "delta": {"type": "input_json_delta", "partial_json": "{\"answer\":\"4\"}"}},
	})
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-thinking",
		"event": {"type": "content_block_delta", "delta": {"type": "thinking_delta", "thinking": "working"}},
	})
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-top-level",
		"event": {"text": "Top-level fallback should stay hidden"},
	})
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-top-level-thinking",
		"event": {"thinking": "Top-level thinking should stay hidden"},
	})
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-non-chat",
		"event": {"type": "message_start", "message": {"id": "msg_1"}},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(0)

	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-text",
		"event": {"type": "content_block_delta", "delta": {"type": "text_delta", "text": "Plain text only"}},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)
	assert_str(_last_assistant_text(panel)).is_equal("Plain text only")

	await _cleanup_panel(panel)


func test_panel_accepts_content_block_delta_without_explicit_delta_type() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport, ClaudeAgentOptionsScript.new({
		"include_partial_messages": true,
	}))

	panel.submit_prompt("Count")
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-text-legacy",
		"event": {"type": "content_block_delta", "delta": {"text": "Legacy text delta"}},
	})
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-thinking-legacy",
		"event": {"type": "content_block_delta", "delta": {"thinking": "Legacy thinking delta"}},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)
	assert_str(_last_assistant_text(panel)).is_equal("Legacy text delta")
	assert_int(_count_entries(panel, "thinking_card")).is_equal(0)

	_button(panel, "ThinkingToggle").button_pressed = true
	_button(panel, "ThinkingToggle").toggled.emit(true)
	await _await_frames(2)

	assert_int(_count_entries(panel, "thinking_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "thinking_card")).contains("Legacy thinking delta")

	await _cleanup_panel(panel)


func test_panel_transcript_toggles_reveal_live_thinking_tools_and_raw_trace() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport, ClaudeAgentOptionsScript.new({
		"include_partial_messages": true,
	}))

	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-thinking-1",
		"event": {"type": "content_block_delta", "delta": {"type": "thinking_delta", "thinking": "Inspecting the request."}},
	})
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "stream-thinking-2",
		"event": {"type": "content_block_delta", "delta": {"type": "thinking_delta", "thinking": "Preparing a tool call."}},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "thinking_card")).is_equal(0)
	_button(panel, "ThinkingToggle").button_pressed = true
	_button(panel, "ThinkingToggle").toggled.emit(true)
	await _await_frames(2)
	assert_int(_count_entries(panel, "thinking_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "thinking_card")).contains("Inspecting the request.")
	assert_str(_last_card_body_text(panel, "thinking_card")).contains("Preparing a tool call.")

	transport.emit_stdout_message({
		"type": "assistant",
		"session_id": "default",
		"message": {
			"model": "haiku",
			"content": [
				{"type": "text", "text": "Done."},
				{"type": "thinking", "thinking": "Final answer ready."},
				{"type": "tool_use", "id": "tool-1", "name": "Read", "input": {"path": "README.md"}},
				{"type": "tool_result", "tool_use_id": "tool-1", "content": {"ok": true}, "is_error": false},
			],
		},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)
	assert_int(_count_entries(panel, "thinking_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "thinking_card")).contains("Final answer ready.")
	assert_int(_count_entries(panel, "tool_use_card")).is_equal(0)
	assert_int(_count_entries(panel, "tool_result_card")).is_equal(0)

	_button(panel, "ToolsToggle").button_pressed = true
	_button(panel, "ToolsToggle").toggled.emit(true)
	await _await_frames(2)
	assert_int(_count_entries(panel, "tool_use_card")).is_equal(1)
	assert_int(_count_entries(panel, "tool_result_card")).is_equal(1)

	_button(panel, "RawToggle").button_pressed = true
	_button(panel, "RawToggle").toggled.emit(true)
	await _await_frames(2)
	assert_int(_count_entries(panel, "raw_card")).is_greater_equal(3)

	await _cleanup_panel(panel)


func test_panel_task_cards_stay_hidden_until_tasks_toggle_is_enabled_and_system_cards_stay_separate() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)

	transport.emit_stdout_message({
		"type": "system",
		"subtype": "task_started",
		"task_id": "task-hidden-1",
		"description": "Draft a release summary",
		"uuid": "task-hidden-uuid",
		"session_id": "default",
		"task_type": "background",
	})
	transport.emit_stdout_message({
		"type": "system",
		"subtype": "hook_started",
		"hook_event": "SessionStart",
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "task_card")).is_equal(0)
	assert_int(_count_entries(panel, "system_card")).is_equal(0)

	_button(panel, "SystemToggle").button_pressed = true
	_button(panel, "SystemToggle").toggled.emit(true)
	await _await_frames(2)
	assert_int(_count_entries(panel, "system_card")).is_equal(1)
	assert_int(_count_entries(panel, "task_card")).is_equal(0)

	_button(panel, "TasksToggle").button_pressed = true
	_button(panel, "TasksToggle").toggled.emit(true)
	await _await_frames(2)
	assert_int(_count_entries(panel, "task_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "task_card")).contains("Draft a release summary")

	await _cleanup_panel(panel)


func test_panel_multiple_task_ids_render_separate_cards_and_reuse_existing_task_entries() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)

	transport.emit_stdout_message({
		"type": "system",
		"subtype": "task_started",
		"task_id": "task-alpha",
		"description": "Summarize README",
		"uuid": "task-alpha-1",
		"session_id": "default",
	})
	transport.emit_stdout_message({
		"type": "system",
		"subtype": "task_started",
		"task_id": "task-beta",
		"description": "Review docs",
		"uuid": "task-beta-1",
		"session_id": "default",
		"task_type": "background",
	})
	await _await_frames(2)

	_button(panel, "TasksToggle").button_pressed = true
	_button(panel, "TasksToggle").toggled.emit(true)
	await _await_frames(2)

	assert_int(_count_entries(panel, "task_card")).is_equal(2)
	assert_array(_entry_body_texts(panel, "task_card")).contains("Summarize README")
	assert_array(_entry_body_texts(panel, "task_card")).contains("Review docs")

	var task_ids_before := _entry_instance_ids(panel, "task_card")
	transport.emit_stdout_message({
		"type": "system",
		"subtype": "task_progress",
		"task_id": "task-alpha",
		"description": "Summarizing README and changelog",
		"usage": {"input_tokens": 12, "output_tokens": 3},
		"last_tool_name": "Read",
		"uuid": "task-alpha-2",
		"session_id": "default",
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "task_card")).is_equal(2)
	assert_array(_entry_instance_ids(panel, "task_card")).is_equal(task_ids_before)
	assert_array(_entry_body_texts(panel, "task_card")).contains("Summarizing README and changelog")

	await _cleanup_panel(panel)


func test_panel_task_card_stop_action_sends_stop_task_and_terminal_notification_keeps_single_card() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)

	transport.emit_stdout_message({
		"type": "system",
		"subtype": "task_started",
		"task_id": "task-stop-1",
		"description": "Assemble release notes",
		"uuid": "task-stop-start",
		"session_id": "default",
		"task_type": "background",
	})
	transport.emit_stdout_message({
		"type": "system",
		"subtype": "task_progress",
		"task_id": "task-stop-1",
		"description": "Checking changelog entries",
		"usage": {"input_tokens": 21, "output_tokens": 4},
		"last_tool_name": "Read",
		"uuid": "task-stop-progress",
		"session_id": "default",
	})
	await _await_frames(2)

	_button(panel, "TasksToggle").button_pressed = true
	_button(panel, "TasksToggle").toggled.emit(true)
	await _await_frames(2)

	assert_int(_count_entries(panel, "task_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "task_card")).contains("Checking changelog entries")

	var task_entry := _last_entry(panel, "task_card")
	var stop_button := task_entry.find_child("TaskStopButton", true, false) as Button
	assert_object(stop_button).is_not_null()
	assert_bool(stop_button.visible).is_true()
	assert_bool(stop_button.disabled).is_false()

	stop_button.pressed.emit()
	await _await_frames(1)

	var stop_request: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str((stop_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("stop_task")
	assert_str(str((stop_request.get("request", {}) as Dictionary).get("task_id", ""))).is_equal("task-stop-1")

	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(stop_request.get("request_id", "")),
			"response": {},
		},
	})
	transport.emit_stdout_message({
		"type": "system",
		"subtype": "task_notification",
		"task_id": "task-stop-1",
		"status": "stopped",
		"output_file": "/tmp/release-notes.md",
		"summary": "Stopped after review",
		"usage": {"input_tokens": 21, "output_tokens": 4},
		"uuid": "task-stop-notification",
		"session_id": "default",
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "task_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "task_card")).contains("Stopped after review")
	var updated_task_entry := _last_entry(panel, "task_card")
	var updated_stop_button := updated_task_entry.find_child("TaskStopButton", true, false) as Button
	assert_object(updated_stop_button).is_not_null()
	assert_bool(not updated_stop_button.visible or updated_stop_button.disabled).is_true()

	await _cleanup_panel(panel)


func test_panel_hides_user_side_tool_result_until_tools_toggle_is_enabled() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)

	transport.emit_stdout_message({
		"type": "user",
		"uuid": "user-tool-result-1",
		"message": {
			"role": "user",
			"content": [
				{"type": "tool_result", "tool_use_id": "toolu_1", "content": {"ok": true}, "is_error": false},
			],
		},
		"tool_use_result": ["metadata"],
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "user_bubble")).is_equal(0)
	assert_int(_count_entries(panel, "tool_result_card")).is_equal(0)

	_button(panel, "ToolsToggle").button_pressed = true
	_button(panel, "ToolsToggle").toggled.emit(true)
	await _await_frames(2)

	assert_int(_count_entries(panel, "tool_result_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "tool_result_card")).contains("\"ok\": true")

	_button(panel, "RawToggle").button_pressed = true
	_button(panel, "RawToggle").toggled.emit(true)
	await _await_frames(2)
	assert_int(_count_entries(panel, "raw_card")).is_greater_equal(1)

	await _cleanup_panel(panel)


func test_panel_echo_suppression_keeps_user_side_tool_result_entries() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)

	panel.submit_prompt("Search the repo")
	transport.emit_stdout_message({
		"type": "user",
		"uuid": "user-tool-result-echo",
		"message": {
			"role": "user",
			"content": [
				{"type": "text", "text": "Search the repo"},
				{"type": "tool_result", "tool_use_id": "toolu_echo", "content": {"indexed": 4}, "is_error": false},
			],
		},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)
	var user_body := _last_entry(panel, "user_bubble").find_child("BubbleBody", true, false) as RichTextLabel
	assert_object(user_body).is_not_null()
	assert_str(str(user_body.text)).is_equal("Search the repo")
	assert_int(_count_entries(panel, "tool_result_card")).is_equal(0)

	_button(panel, "ToolsToggle").button_pressed = true
	_button(panel, "ToolsToggle").toggled.emit(true)
	await _await_frames(2)

	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)
	assert_int(_count_entries(panel, "tool_result_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "tool_result_card")).contains("\"indexed\": 4")

	await _cleanup_panel(panel)


func test_panel_hides_tool_linked_user_prompt_until_tools_toggle_is_enabled() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)

	transport.emit_stdout_message({
		"type": "user",
		"uuid": "user-tool-prompt-1",
		"parent_tool_use_id": "toolu_prompt_1",
		"message": {
			"role": "user",
			"content": "Explore the project structure thoroughly.",
		},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "user_bubble")).is_equal(0)
	assert_int(_count_entries(panel, "tool_prompt_card")).is_equal(0)

	_button(panel, "ToolsToggle").button_pressed = true
	_button(panel, "ToolsToggle").toggled.emit(true)
	await _await_frames(2)

	assert_int(_count_entries(panel, "tool_prompt_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "tool_prompt_card")).contains("Explore the project structure thoroughly.")

	_button(panel, "RawToggle").button_pressed = true
	_button(panel, "RawToggle").toggled.emit(true)
	await _await_frames(2)

	assert_int(_count_entries(panel, "raw_card")).is_greater_equal(1)

	await _cleanup_panel(panel)


func test_panel_tool_linked_prompt_uses_known_tool_name_in_title() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)

	transport.emit_stdout_message({
		"type": "assistant",
		"session_id": "default",
		"message": {
			"model": "haiku",
			"content": [
				{"type": "tool_use", "id": "toolu_agent_1", "name": "agent", "input": {"prompt": "Explore"}},
			],
		},
	})
	await _await_frames(2)

	transport.emit_stdout_message({
		"type": "user",
		"uuid": "user-tool-prompt-2",
		"parent_tool_use_id": "toolu_agent_1",
		"message": {
			"role": "user",
			"content": "Explore the UI layer and summarize it.",
		},
	})
	await _await_frames(2)

	_button(panel, "ToolsToggle").button_pressed = true
	_button(panel, "ToolsToggle").toggled.emit(true)
	await _await_frames(2)

	var tool_prompt := _last_entry(panel, "tool_prompt_card")
	assert_object(tool_prompt).is_not_null()
	var toggle := tool_prompt.find_child("CardToggle", true, false) as Button
	assert_object(toggle).is_not_null()
	assert_str(str(toggle.text)).contains("Tool prompt · agent")

	await _cleanup_panel(panel)


func test_panel_tool_linked_prompt_does_not_consume_pending_prompt_echo() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)

	panel.submit_prompt("Summarize the UI layer")

	transport.emit_stdout_message({
		"type": "user",
		"uuid": "user-tool-prompt-pending-echo",
		"parent_tool_use_id": "toolu_pending_echo",
		"message": {
			"role": "user",
			"content": "Summarize the UI layer",
		},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)

	transport.emit_stdout_message({
		"type": "user",
		"uuid": "user-echo-after-tool-prompt",
		"message": {
			"role": "user",
			"content": "Summarize the UI layer",
		},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)
	assert_int(_count_entries(panel, "tool_prompt_card")).is_equal(0)

	_button(panel, "ToolsToggle").button_pressed = true
	_button(panel, "ToolsToggle").toggled.emit(true)
	await _await_frames(2)

	assert_int(_count_entries(panel, "tool_prompt_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "tool_prompt_card")).contains("Summarize the UI layer")

	await _cleanup_panel(panel)


func test_panel_tool_linked_user_message_keeps_text_and_nested_tool_result_under_tools() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport)

	transport.emit_stdout_message({
		"type": "user",
		"uuid": "user-tool-prompt-mixed",
		"parent_tool_use_id": "toolu_mixed",
		"message": {
			"role": "user",
			"content": [
				{"type": "text", "text": "Search the repository and summarize findings."},
				{"type": "tool_result", "tool_use_id": "toolu_mixed", "content": {"indexed": 3}, "is_error": false},
			],
		},
	})
	await _await_frames(2)

	assert_int(_count_entries(panel, "user_bubble")).is_equal(0)
	assert_int(_count_entries(panel, "tool_prompt_card")).is_equal(0)
	assert_int(_count_entries(panel, "tool_result_card")).is_equal(0)

	_button(panel, "ToolsToggle").button_pressed = true
	_button(panel, "ToolsToggle").toggled.emit(true)
	await _await_frames(2)

	assert_int(_count_entries(panel, "tool_prompt_card")).is_equal(1)
	assert_int(_count_entries(panel, "tool_result_card")).is_equal(1)
	assert_str(_last_card_body_text(panel, "tool_prompt_card")).contains("Search the repository and summarize findings.")
	assert_str(_last_card_body_text(panel, "tool_result_card")).contains("\"indexed\": 3")

	await _cleanup_panel(panel)


func test_panel_live_assistant_bubble_reuses_same_node_across_stream_deltas() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport, ClaudeAgentOptionsScript.new({
		"include_partial_messages": true,
	}))

	panel.submit_prompt("Stream")
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "reuse-stream-1",
		"event": {"type": "content_block_delta", "delta": {"type": "text_delta", "text": "Hello"}},
	})
	await _await_frames(2)

	var bubble_ids := _entry_instance_ids(panel, "assistant_bubble")
	var wrapper_count := _transcript_list(panel).get_child_count()
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "reuse-stream-2",
		"event": {"type": "content_block_delta", "delta": {"type": "text_delta", "text": " world"}},
	})
	await _await_frames(2)

	assert_array(_entry_instance_ids(panel, "assistant_bubble")).is_equal(bubble_ids)
	assert_int(_transcript_list(panel).get_child_count()).is_equal(wrapper_count)
	assert_str(_last_assistant_text(panel)).is_equal("Hello world")

	await _cleanup_panel(panel)


func test_panel_live_filter_toggles_reuse_existing_detail_nodes() -> void:
	var transport = FakeTransportScript.new()
	var panel = await _connected_panel(transport, ClaudeAgentOptionsScript.new({
		"include_partial_messages": true,
	}))

	panel.submit_prompt("Inspect")
	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "toggle-thinking-1",
		"event": {"type": "content_block_delta", "delta": {"type": "thinking_delta", "thinking": "Inspecting the request."}},
	})
	await _await_frames(2)

	_button(panel, "ThinkingToggle").button_pressed = true
	_button(panel, "ThinkingToggle").toggled.emit(true)
	await _await_frames(2)
	var thinking_ids := _entry_instance_ids(panel, "thinking_card")
	var wrapper_count := _transcript_list(panel).get_child_count()

	transport.emit_stdout_message({
		"type": "stream_event",
		"session_id": "default",
		"uuid": "toggle-thinking-2",
		"event": {"type": "content_block_delta", "delta": {"type": "thinking_delta", "thinking": "Preparing a response."}},
	})
	await _await_frames(2)
	assert_array(_entry_instance_ids(panel, "thinking_card")).is_equal(thinking_ids)

	_button(panel, "ThinkingToggle").button_pressed = false
	_button(panel, "ThinkingToggle").toggled.emit(false)
	await _await_frames(2)
	_button(panel, "ThinkingToggle").button_pressed = true
	_button(panel, "ThinkingToggle").toggled.emit(true)
	await _await_frames(2)
	assert_array(_entry_instance_ids(panel, "thinking_card")).is_equal(thinking_ids)
	assert_int(_transcript_list(panel).get_child_count()).is_equal(wrapper_count)

	transport.emit_stdout_message({
		"type": "assistant",
		"session_id": "default",
		"message": {
			"model": "haiku",
			"content": [
				{"type": "text", "text": "Done."},
				{"type": "tool_use", "id": "tool-1", "name": "Read", "input": {"path": "README.md"}},
				{"type": "tool_result", "tool_use_id": "tool-1", "content": {"ok": true}, "is_error": false},
			],
		},
	})
	await _await_frames(2)

	_button(panel, "ToolsToggle").button_pressed = true
	_button(panel, "ToolsToggle").toggled.emit(true)
	await _await_frames(2)
	var tool_use_ids := _entry_instance_ids(panel, "tool_use_card")
	var tool_result_ids := _entry_instance_ids(panel, "tool_result_card")

	_button(panel, "ToolsToggle").button_pressed = false
	_button(panel, "ToolsToggle").toggled.emit(false)
	await _await_frames(2)
	_button(panel, "ToolsToggle").button_pressed = true
	_button(panel, "ToolsToggle").toggled.emit(true)
	await _await_frames(2)

	assert_array(_entry_instance_ids(panel, "tool_use_card")).is_equal(tool_use_ids)
	assert_array(_entry_instance_ids(panel, "tool_result_card")).is_equal(tool_result_ids)

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

	_button(panel, "ResultsToggle").button_pressed = false
	_button(panel, "ResultsToggle").toggled.emit(false)
	await _await_frames(2)
	assert_int(_count_entries(panel, "result_card")).is_equal(0)

	_button(panel, "ResultsToggle").button_pressed = true
	_button(panel, "ResultsToggle").toggled.emit(true)
	await _await_frames(2)
	assert_int(_count_entries(panel, "result_card")).is_equal(1)

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
	assert_bool(_prompt_input(panel).editable).is_true()
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Restored session")
	assert_str(_label(panel, "SelectedSessionMetaValue").text).contains("review")
	assert_str(_session_id_from_panel(panel)).is_equal(session_id)

	await _cleanup_panel(panel)


func test_panel_saved_transcript_toggles_reveal_session_detail_entries() -> void:
	var session_id := _create_panel_detail_session_fixture("panel-history-detail")
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())

	get_tree().root.add_child(panel)
	await _await_frames(2)

	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	assert_str(_session_id_from_panel(panel)).is_equal(session_id)
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)
	assert_int(_count_entries(panel, "thinking_card")).is_equal(0)
	assert_int(_count_entries(panel, "progress_card")).is_equal(0)
	assert_int(_count_entries(panel, "tool_use_card")).is_equal(0)
	assert_int(_count_entries(panel, "tool_result_card")).is_equal(0)

	_button(panel, "ThinkingToggle").button_pressed = true
	_button(panel, "ThinkingToggle").toggled.emit(true)
	_button(panel, "TasksToggle").button_pressed = true
	_button(panel, "TasksToggle").toggled.emit(true)
	_button(panel, "ToolsToggle").button_pressed = true
	_button(panel, "ToolsToggle").toggled.emit(true)
	_button(panel, "RawToggle").button_pressed = true
	_button(panel, "RawToggle").toggled.emit(true)
	await _await_frames(2)

	assert_int(_count_entries(panel, "thinking_card")).is_equal(1)
	assert_int(_count_entries(panel, "progress_card")).is_equal(1)
	assert_int(_count_entries(panel, "tool_use_card")).is_equal(1)
	assert_int(_count_entries(panel, "tool_result_card")).is_equal(1)
	assert_int(_count_entries(panel, "raw_card")).is_greater_equal(3)
	assert_str(_last_card_body_text(panel, "thinking_card")).contains("Thinking about the scene")
	assert_str(_last_card_body_text(panel, "progress_card")).contains("Background task is still running")

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
	assert_str(runtime_options.session_id).is_empty()
	assert_bool(_button(panel, "RenameSessionButton").disabled).is_true()
	assert_bool(_button(panel, "DeleteSessionButton").disabled).is_true()
	assert_bool(_button(panel, "ForkSessionButton").disabled).is_true()
	assert_bool(_line_edit(panel, "ForkTitleInput").editable).is_false()

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
	assert_bool(_button(panel, "ForkSessionButton").disabled).is_true()
	assert_bool(_line_edit(panel, "ForkTitleInput").editable).is_false()

	panel.disconnect_client()
	await _await_frames(2)
	assert_bool(_prompt_input(panel).editable).is_true()
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)

	await _cleanup_panel(panel)


func test_panel_disconnected_send_uses_selected_session_resume_target() -> void:
	var session_id := _create_panel_session_fixture("panel-resume-send")
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	_prompt_input(panel).text = "Continue selected"
	_prompt_input(panel).text_changed.emit()
	_button(panel, "SendButton").pressed.emit()
	await _await_frames(1)

	var runtime_options = panel.get_client_node()._adapter._client.options
	assert_str(runtime_options.resume).is_equal(session_id)
	assert_str(runtime_options.session_id).is_empty()

	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/help"}]},
		},
	})
	await _await_frames(1)

	var prompt_payload: Dictionary = JSON.parse_string(transport.writes[1])
	assert_str(str(prompt_payload.get("session_id", ""))).is_equal("default")
	assert_str(str((prompt_payload.get("message", {}) as Dictionary).get("content", ""))).is_equal("Continue selected")

	await _cleanup_panel(panel)


func test_panel_connected_idle_selection_disconnects_into_saved_preview_and_new_chat_disconnects_to_draft() -> void:
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
	assert_str(_status_badge(panel).text).is_equal("Saved")
	assert_bool(_button(panel, "RenameSessionButton").disabled).is_false()
	assert_bool(_button(panel, "DeleteSessionButton").disabled).is_false()
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)

	_prompt_input(panel).text = "Switch to the selected history"
	_prompt_input(panel).text_changed.emit()
	var write_count_before_resume: int = transport.writes.size()
	_button(panel, "SendButton").pressed.emit()
	await _await_frames(1)

	var runtime_options = panel.get_client_node()._adapter._client.options
	assert_str(runtime_options.resume).is_equal(second_session_id)
	assert_str(runtime_options.session_id).is_empty()
	var init_request: Dictionary = JSON.parse_string(transport.writes[write_count_before_resume])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)
	var resumed_prompt: Dictionary = JSON.parse_string(transport.writes[write_count_before_resume + 1])
	assert_bool(str(resumed_prompt.get("session_id", "")) == "default").is_true()
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
	assert_str(str(panel.get("_authoritative_live_session_id"))).is_equal(second_session_id)

	_activate_session_with_keyboard_signal(panel, 1)
	await _await_frames(2)
	assert_str(_session_id_from_panel(panel)).is_equal(first_session_id)
	assert_str(_status_badge(panel).text).is_equal("Saved")

	_button(panel, "NewChatButton").pressed.emit()
	await _await_frames(2)
	assert_str(_session_id_from_panel(panel)).is_equal("")
	assert_int(_transcript_list(panel).get_child_count()).is_equal(0)
	assert_str(_status_badge(panel).text).is_equal("Ready")

	var write_count_before_reset: int = transport.writes.size()
	panel.submit_prompt("Fresh turn after reset")
	await _await_frames(1)
	var reset_init_request: Dictionary = JSON.parse_string(transport.writes[write_count_before_reset])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(reset_init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)
	var reset_write: Dictionary = JSON.parse_string(transport.writes[write_count_before_reset + 1])
	assert_bool(str(reset_write.get("session_id", "")) == "default").is_true()

	await _cleanup_panel(panel)


func test_panel_tracks_authoritative_live_session_id_from_runtime_results() -> void:
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	panel.connect_client()
	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(2)

	panel.submit_prompt("Track the active session")
	await _await_frames(1)
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 8,
		"is_error": false,
		"num_turns": 1,
		"session_id": "tracked-session-id",
		"result": "Tracked",
	})
	await _await_frames(2)

	assert_str(str(panel.get("_authoritative_live_session_id"))).is_equal("tracked-session-id")
	panel.submit_prompt("Use the tracked session")
	await _await_frames(1)
	var follow_up_write: Dictionary = JSON.parse_string(transport.writes[-1])
	assert_str(str(follow_up_write.get("session_id", ""))).is_equal("tracked-session-id")

	await _cleanup_panel(panel)


func test_panel_connect_failure_surfaces_cli_diagnostics_and_preserves_existing_stderr_callback() -> void:
	var stderr_lines: Array[String] = []
	var transport = FakeTransportScript.new()
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"stderr": func(line: String) -> void:
			stderr_lines.append(line),
	}), transport)
	get_tree().root.add_child(panel)
	await _await_frames(2)

	panel.connect_client()
	await _await_frames(1)
	var runtime_options = panel.get_client_node()._adapter._client.options
	runtime_options.stderr.call("CLI diagnostic line")
	await _await_frames(2)
	assert_array(stderr_lines).is_equal(["CLI diagnostic line"])
	assert_str(_label(panel, "StatusDetailLabel").text).contains("CLI diagnostic line")

	var init_request: Dictionary = JSON.parse_string(transport.writes[0])
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
	assert_str(_label(panel, "StatusDetailLabel").text).contains("CLI diagnostic line")

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


func test_panel_session_fork_control_creates_and_selects_new_saved_session() -> void:
	var session_id := _create_panel_session_fixture("panel-fork-success")
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	_line_edit(panel, "ForkTitleInput").text = "Branch A"
	_button(panel, "ForkSessionButton").pressed.emit()
	await _await_frames(2)

	assert_int(_session_list(panel).item_count).is_equal(2)
	assert_str(_session_id_from_panel(panel)).is_not_equal(session_id)
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Branch A")
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)
	assert_str(_last_assistant_text(panel)).contains("Saved answer")
	assert_str(_line_edit(panel, "ForkTitleInput").text).is_equal("")

	await _cleanup_panel(panel)


func test_panel_saved_session_cutoff_fork_creates_and_selects_truncated_saved_session() -> void:
	var session_id := _create_panel_cutoff_session_fixture("panel-fork-cutoff-success")
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	assert_int(_count_entries(panel, "user_bubble")).is_equal(2)
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(2)
	_line_edit(panel, "ForkTitleInput").text = "Branch from first prompt"
	var fork_button := _entry_at(panel, "user_bubble", 0).find_child("ForkFromHereButton", true, false) as Button
	fork_button.pressed.emit()
	await _await_frames(2)

	assert_int(_session_list(panel).item_count).is_equal(2)
	assert_str(_session_id_from_panel(panel)).is_not_equal(session_id)
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Branch from first prompt")
	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(0)
	assert_str(_line_edit(panel, "ForkTitleInput").text).is_equal("")

	await _cleanup_panel(panel)


func test_panel_saved_session_cutoff_fork_uses_runtime_default_title_when_blank() -> void:
	_create_panel_cutoff_session_fixture("panel-fork-cutoff-default-title")
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	var fork_button := _entry_at(panel, "user_bubble", 0).find_child("ForkFromHereButton", true, false) as Button
	fork_button.pressed.emit()
	await _await_frames(2)

	assert_int(_session_list(panel).item_count).is_equal(2)
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Cutoff session (fork)")
	assert_int(_count_entries(panel, "user_bubble")).is_equal(1)
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(0)

	await _cleanup_panel(panel)


func test_panel_session_fork_control_uses_runtime_default_title_when_blank() -> void:
	_create_panel_session_fixture("panel-fork-default-title")
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	assert_str(_line_edit(panel, "ForkTitleInput").text).is_equal("")
	_button(panel, "ForkSessionButton").pressed.emit()
	await _await_frames(2)

	assert_int(_session_list(panel).item_count).is_equal(2)
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Restored session (fork)")
	assert_str(_line_edit(panel, "ForkTitleInput").text).is_equal("")
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)
	assert_str(_last_assistant_text(panel)).contains("Saved answer")

	await _cleanup_panel(panel)


func test_panel_failed_saved_session_cutoff_fork_keeps_selection_and_transcript_intact() -> void:
	var session_id := _create_panel_cutoff_session_fixture("panel-fork-cutoff-failure")
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	var config_root := OS.get_environment("CLAUDE_CONFIG_DIR")
	var project_dir := _make_project_dir(config_root, ProjectSettings.globalize_path("res://"))
	assert_int(DirAccess.remove_absolute(project_dir.path_join("%s.jsonl" % session_id))).is_equal(OK)

	var fork_button := _entry_at(panel, "user_bubble", 0).find_child("ForkFromHereButton", true, false) as Button
	fork_button.pressed.emit()
	await _await_frames(2)

	assert_int(_session_list(panel).item_count).is_equal(1)
	assert_str(_session_id_from_panel(panel)).is_equal(session_id)
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Cutoff session")
	assert_int(_count_entries(panel, "user_bubble")).is_equal(2)
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(2)
	assert_str(_label(panel, "StatusDetailLabel").text).contains("not found")

	await _cleanup_panel(panel)


func test_panel_failed_session_fork_keeps_selection_and_transcript_intact() -> void:
	var session_id := _create_panel_session_fixture("panel-fork-failure")
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({"model": "haiku"}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)
	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)

	var config_root := OS.get_environment("CLAUDE_CONFIG_DIR")
	var project_dir := _make_project_dir(config_root, ProjectSettings.globalize_path("res://"))
	assert_int(DirAccess.remove_absolute(project_dir.path_join("%s.jsonl" % session_id))).is_equal(OK)

	_line_edit(panel, "ForkTitleInput").text = "Should fail"
	_button(panel, "ForkSessionButton").pressed.emit()
	await _await_frames(2)

	assert_int(_session_list(panel).item_count).is_equal(1)
	assert_str(_session_id_from_panel(panel)).is_equal(session_id)
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Restored session")
	assert_int(_count_entries(panel, "assistant_bubble")).is_equal(1)
	assert_str(_label(panel, "StatusDetailLabel").text).contains("not found")

	await _cleanup_panel(panel)


func test_panel_saved_session_cutoff_fork_uses_selected_worktree_session_directory() -> void:
	var fixture := _create_duplicate_worktree_session_fixture("panel-worktree-cutoff-fork")
	var original_session_id := "42424242-4242-4424-8424-424242424242"
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"cwd": fixture["repo_root"],
	}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)

	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)
	_line_edit(panel, "ForkTitleInput").text = "Worktree cutoff fork"
	var fork_button := _entry_at(panel, "user_bubble", 0).find_child("ForkFromHereButton", true, false) as Button
	fork_button.pressed.emit()
	await _await_frames(2)

	var forked_session_id := _session_id_from_panel(panel)
	var repo_project_dir := str(fixture["repo_file"]).get_base_dir()
	var worktree_project_dir := str(fixture["worktree_file"]).get_base_dir()
	assert_str(forked_session_id).is_not_equal(original_session_id)
	assert_bool(FileAccess.file_exists(worktree_project_dir.path_join("%s.jsonl" % forked_session_id))).is_true()
	assert_bool(FileAccess.file_exists(repo_project_dir.path_join("%s.jsonl" % forked_session_id))).is_false()
	assert_str(_label(panel, "SelectedSessionCwdValue").text).contains(str(fixture["worktree_root"]))
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Worktree cutoff fork")

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


func test_panel_fork_uses_selected_worktree_session_directory() -> void:
	var fixture := _create_duplicate_worktree_session_fixture("panel-worktree-fork")
	var original_session_id := "42424242-4242-4424-8424-424242424242"
	var panel = ChatPanelScene.instantiate()
	panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"cwd": fixture["repo_root"],
	}), FakeTransportScript.new())
	get_tree().root.add_child(panel)
	await _await_frames(2)

	_select_session_with_click_signal(panel, 0)
	await _await_frames(2)
	_line_edit(panel, "ForkTitleInput").text = "Worktree fork"
	_button(panel, "ForkSessionButton").pressed.emit()
	await _await_frames(2)

	var forked_session_id := _session_id_from_panel(panel)
	var repo_project_dir := str(fixture["repo_file"]).get_base_dir()
	var worktree_project_dir := str(fixture["worktree_file"]).get_base_dir()
	assert_str(forked_session_id).is_not_equal(original_session_id)
	assert_bool(FileAccess.file_exists(worktree_project_dir.path_join("%s.jsonl" % forked_session_id))).is_true()
	assert_bool(FileAccess.file_exists(repo_project_dir.path_join("%s.jsonl" % forked_session_id))).is_false()
	assert_str(_label(panel, "SelectedSessionCwdValue").text).contains(str(fixture["worktree_root"]))
	assert_str(_label(panel, "SelectedSessionSummaryValue").text).is_equal("Worktree fork")

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
	assert_object(session_pane).is_not_null()
	assert_object(chat_column).is_not_null()
	var split_ratio := float(split_row.split_offset) / maxf(1.0, float(split_row.size.x))
	assert_bool(split_ratio > 0.34 and split_ratio < 0.46).is_true()

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


func _check_box(panel, node_name: String) -> CheckBox:
	return panel.find_child(node_name, true, false) as CheckBox


func _control(panel, node_name: String) -> Control:
	return panel.find_child(node_name, true, false) as Control


func _label(panel, node_name: String) -> Label:
	return panel.find_child(node_name, true, false) as Label


func _line_edit(panel, node_name: String) -> LineEdit:
	return panel.find_child(node_name, true, false) as LineEdit


func _text_edit(panel, node_name: String) -> TextEdit:
	return panel.find_child(node_name, true, false) as TextEdit


func _option_button(panel, node_name: String) -> OptionButton:
	return panel.find_child(node_name, true, false) as OptionButton


func _selected_option_text(panel, node_name: String) -> String:
	var option := _option_button(panel, node_name)
	return option.get_item_text(option.selected)


func _built_in_tool_checkbox(panel, tool_name: String) -> CheckBox:
	return _check_box(panel, "BuiltInToolCheck_%s" % tool_name)


func _checked_built_in_tool_count(panel) -> int:
	var count := 0
	for tool_name in ClaudeBuiltInToolCatalog.list_default_tools():
		var checkbox := _built_in_tool_checkbox(panel, tool_name)
		if checkbox != null and checkbox.button_pressed:
			count += 1
	return count


func _prompt_input(panel) -> TextEdit:
	return panel.find_child("PromptInput", true, false) as TextEdit


func _last_control_request_by_subtype(transport, subtype: String) -> Dictionary:
	for index in range(transport.writes.size() - 1, -1, -1):
		var payload: Variant = JSON.parse_string(transport.writes[index])
		if not (payload is Dictionary):
			continue
		var request := (payload as Dictionary).get("request", {}) as Dictionary
		if str(request.get("subtype", "")) == subtype:
			return payload as Dictionary
	return {}


func _emit_success_control_response(transport, request_payload: Dictionary, response: Dictionary) -> void:
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(request_payload.get("request_id", "")),
			"response": response,
		},
	})


func _session_list(panel) -> ItemList:
	return panel.find_child("SessionList", true, false) as ItemList


func _show_settings_view(panel) -> void:
	_button(panel, "SettingsViewButton").pressed.emit()


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
	return _collect_entries_by_kind(_transcript_list(panel), kind).size()


func _last_entry(panel, kind: String) -> Node:
	var entries := _collect_entries_by_kind(_transcript_list(panel), kind)
	return entries[-1] if not entries.is_empty() else null


func _entry_at(panel, kind: String, index: int) -> Node:
	var entries := _collect_entries_by_kind(_transcript_list(panel), kind)
	if index < 0 or index >= entries.size():
		return null
	return entries[index]


func _entry_instance_ids(panel, kind: String) -> Array[int]:
	var ids: Array[int] = []
	for entry in _collect_entries_by_kind(_transcript_list(panel), kind):
		ids.append(entry.get_instance_id())
	return ids


func _entry_body_texts(panel, kind: String) -> Array[String]:
	var texts: Array[String] = []
	for entry in _collect_entries_by_kind(_transcript_list(panel), kind):
		var body := entry.find_child("CardBody", true, false) as RichTextLabel
		if body != null:
			texts.append(body.text)
	return texts


func _collect_entries_by_kind(root: Node, kind: String) -> Array[Node]:
	var entries: Array[Node] = []
	_collect_entries_recursive(root, kind, entries)
	return entries


func _collect_entries_recursive(node: Node, kind: String, entries: Array[Node]) -> void:
	var visible := true
	if node is CanvasItem:
		visible = (node as CanvasItem).is_visible_in_tree()
	if str(node.get_meta("entry_kind", "")) == kind and visible:
		entries.append(node)
	for child in node.get_children():
		_collect_entries_recursive(child, kind, entries)


func _last_assistant_text(panel) -> String:
	var entry := _last_entry(panel, "assistant_bubble")
	if entry == null:
		return ""
	var bubble_body: RichTextLabel = entry.find_child("BubbleBody", true, false) as RichTextLabel
	if bubble_body == null:
		return ""
	return bubble_body.text


func _last_card_body_text(panel, kind: String) -> String:
	var entry := _last_entry(panel, kind)
	if entry == null:
		return ""
	var body: RichTextLabel = entry.find_child("CardBody", true, false) as RichTextLabel
	if body == null:
		return ""
	return body.text


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


func _create_panel_cutoff_session_fixture(label: String) -> String:
	var config_root := _create_config_root(label)
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_path := ProjectSettings.globalize_path("res://")
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "51515151-5151-4515-8515-515151515151"
	_write_session_file(project_dir, session_id, [
		{
			"type": "user",
			"uuid": "61616161-6161-4616-8616-616161616161",
			"sessionId": session_id,
			"timestamp": "2026-04-05T13:00:00",
			"cwd": project_path,
			"message": {"role": "user", "content": "First saved prompt"},
		},
		{
			"type": "assistant",
			"uuid": "62626262-6262-4626-8626-626262626262",
			"parentUuid": "61616161-6161-4616-8616-616161616161",
			"sessionId": session_id,
			"message": {"role": "assistant", "content": "First saved answer"},
		},
		{
			"type": "user",
			"uuid": "63636363-6363-4636-8636-636363636363",
			"parentUuid": "62626262-6262-4626-8626-626262626262",
			"sessionId": session_id,
			"timestamp": "2026-04-05T13:05:00",
			"cwd": project_path,
			"message": {"role": "user", "content": "Second saved prompt"},
		},
		{
			"type": "assistant",
			"uuid": "64646464-6464-4646-8646-646464646464",
			"parentUuid": "63636363-6363-4636-8636-636363636363",
			"sessionId": session_id,
			"message": {"role": "assistant", "content": "Second saved answer"},
		},
		{"type": "summary", "customTitle": "Cutoff session"},
		{"type": "tag", "tag": "branch"},
	], 1712302220)
	return session_id


func _create_panel_detail_session_fixture(label: String) -> String:
	var config_root := _create_config_root(label)
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_path := ProjectSettings.globalize_path("res://")
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "43434343-4343-4434-8434-434343434343"
	_write_session_file(project_dir, session_id, [
		{
			"type": "user",
			"uuid": "detail-u-1",
			"sessionId": session_id,
			"timestamp": "2026-04-05T13:00:00",
			"cwd": project_path,
			"message": {"role": "user", "content": "Saved prompt"},
		},
		{
			"type": "progress",
			"uuid": "detail-p-1",
			"parentUuid": "detail-u-1",
			"sessionId": session_id,
			"message": {"summary": "Background task is still running", "status": "running"},
		},
		{
			"type": "assistant",
			"uuid": "detail-a-1",
			"parentUuid": "detail-p-1",
			"sessionId": session_id,
			"message": {
				"role": "assistant",
				"content": [
					{"type": "text", "text": "Saved answer"},
					{"type": "thinking", "thinking": "Thinking about the scene."},
					{"type": "tool_use", "id": "tool-1", "name": "Read", "input": {"path": "scene.tscn"}},
					{"type": "tool_result", "tool_use_id": "tool-1", "content": {"ok": true}, "is_error": false},
				],
			},
		},
		{"type": "summary", "customTitle": "Detailed restored session"},
		{"type": "tag", "tag": "review"},
	], 1712302210)
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
			"uuid": "72727272-7272-4727-8727-727272727272",
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
			"uuid": "73737373-7373-4737-8737-737373737373",
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
