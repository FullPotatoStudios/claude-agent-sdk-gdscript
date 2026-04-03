extends Control
class_name ClaudeChatPanel

signal auth_status_changed(status: Dictionary)
signal prompt_submitted(prompt: String)
signal message_received(message: Variant)
signal turn_finished(result_message: ClaudeResultMessage)
signal error_occurred(message: String)

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const SendIcon := preload("res://addons/claude_agent_sdk/icons/send.svg")
const InterruptIcon := preload("res://addons/claude_agent_sdk/icons/interrupt.svg")
const RefreshIcon := preload("res://addons/claude_agent_sdk/icons/refresh.svg")

const COLOR_BG := Color("0f1726")
const COLOR_PANEL_ALT := Color("1d2940")
const COLOR_STROKE := Color("2d4267")
const COLOR_TEXT := Color("eff4ff")
const COLOR_MUTED := Color("99a9c6")
const COLOR_ACCENT := Color("64d6ff")
const COLOR_SUCCESS := Color("59d390")
const COLOR_WARNING := Color("ffbf69")
const COLOR_ERROR := Color("ff7b86")
const COLOR_USER := Color("ff9966")
const COLOR_ASSISTANT := Color("5db3ff")

var _configured_options = null
var _configured_transport = null
var _client_node = null
var _did_connect_once := false
var _session_live := false
var _is_connecting := false
var _last_auth_status: Dictionary = {}
var _streaming_assistant_entry: Control = null
var _streaming_assistant_body: RichTextLabel = null
var _streaming_assistant_buffer := ""
var _pending_prompt_echo := ""
var _needs_runtime_sync_after_connect := false
var _last_error := ""
var _status_issue_message := ""

@onready var _shell: PanelContainer = $Shell
@onready var _status_badge: PanelContainer = $Shell/Margin/Body/Header/TopRow/StatusCluster/StatusBadge
@onready var _status_badge_label: Label = $Shell/Margin/Body/Header/TopRow/StatusCluster/StatusBadge/StatusBadgeLabel
@onready var _status_title: Label = $Shell/Margin/Body/Header/TopRow/StatusCluster/StatusText/StatusTitleLabel
@onready var _status_detail: Label = $Shell/Margin/Body/Header/TopRow/StatusCluster/StatusText/StatusDetailLabel
@onready var _refresh_auth_button: Button = $Shell/Margin/Body/Header/TopRow/ActionButtons/RefreshAuthButton
@onready var _connect_button: Button = $Shell/Margin/Body/Header/TopRow/ActionButtons/ConnectButton
@onready var _disconnect_button: Button = $Shell/Margin/Body/Header/TopRow/ActionButtons/DisconnectButton
@onready var _model_input: LineEdit = $Shell/Margin/Body/Header/ControlRow/ControlMargin/SettingsRow/SettingsGrid/ModelGroup/ModelInput
@onready var _permission_mode: OptionButton = $Shell/Margin/Body/Header/ControlRow/ControlMargin/SettingsRow/SettingsGrid/PermissionGroup/PermissionModeOption
@onready var _transcript_scroll: ScrollContainer = $Shell/Margin/Body/TranscriptCard/TranscriptScroll
@onready var _transcript_list: VBoxContainer = $Shell/Margin/Body/TranscriptCard/TranscriptScroll/TranscriptList
@onready var _composer_hint: Label = $Shell/Margin/Body/ComposerCard/ComposerMargin/ComposerBody/ComposerActions/ComposerHintLabel
@onready var _prompt_input: TextEdit = $Shell/Margin/Body/ComposerCard/ComposerMargin/ComposerBody/PromptInput
@onready var _interrupt_button: Button = $Shell/Margin/Body/ComposerCard/ComposerMargin/ComposerBody/ComposerActions/InterruptButton
@onready var _send_button: Button = $Shell/Margin/Body/ComposerCard/ComposerMargin/ComposerBody/ComposerActions/SendButton


func _init() -> void:
	_configured_options = ClaudeAgentOptionsScript.new()


func _ready() -> void:
	_apply_static_button_icons()
	_populate_permission_modes()
	_apply_initial_control_values()
	_ensure_client_node()
	_wire_ui()
	_apply_theme_overrides()
	_refresh_composer_state()
	refresh_auth_status()


func setup(options = null, transport = null) -> void:
	if _did_connect_once:
		_emit_error("setup() must be called before the first successful connect_client()")
		return
	_configured_options = options.duplicate_options() if options != null else ClaudeAgentOptionsScript.new()
	_configured_transport = transport
	if is_node_ready():
		_apply_initial_control_values()
		_rebuild_client_node()


func connect_client() -> void:
	if _session_live or _is_connecting:
		return
	_status_issue_message = ""
	if not _did_connect_once:
		_apply_preconnect_controls_to_options()
		_rebuild_client_node()
	else:
		_needs_runtime_sync_after_connect = true

	_is_connecting = true
	_update_status_from_state()
	_refresh_composer_state()
	_client_node.connect_client()

	if not _client_node.get_last_error().is_empty():
		_is_connecting = false
		_status_issue_message = _client_node.get_last_error()
		_emit_error(_client_node.get_last_error())
		_update_status_from_state()
		_refresh_composer_state()


func disconnect_client() -> void:
	if _client_node == null:
		return
	_client_node.disconnect_client()
	_is_connecting = false
	_session_live = false
	_status_issue_message = ""
	_streaming_assistant_entry = null
	_streaming_assistant_body = null
	_streaming_assistant_buffer = ""
	_update_status_from_state()
	_refresh_composer_state()


func submit_prompt(prompt: String) -> void:
	var trimmed := prompt.strip_edges()
	if trimmed.is_empty():
		return
	if not _session_live:
		_emit_error("Connect to Claude before sending a prompt")
		return
	if _client_node.is_busy():
		_emit_error("Wait for the current turn to finish before sending another prompt")
		return

	_append_message_bubble("user", trimmed, "You", true)
	_pending_prompt_echo = trimmed
	_streaming_assistant_entry = null
	_streaming_assistant_body = null
	_streaming_assistant_buffer = ""
	_prompt_input.text = ""
	_refresh_composer_state()
	prompt_submitted.emit(trimmed)
	_client_node.query(trimmed, _configured_options.get_effective_session_id("default"))

	if not _client_node.get_last_error().is_empty():
		_emit_error(_client_node.get_last_error())


func refresh_auth_status() -> void:
	if _client_node == null:
		return
	_last_auth_status = _client_node.get_auth_status()
	_last_error = str(_last_auth_status.get("error_message", ""))
	_status_issue_message = ""
	auth_status_changed.emit(_last_auth_status.duplicate(true))
	_update_status_from_state()
	_refresh_composer_state()


func clear_transcript() -> void:
	for child in _transcript_list.get_children():
		child.queue_free()
	_streaming_assistant_entry = null
	_streaming_assistant_body = null
	_streaming_assistant_buffer = ""


func get_client_node() -> ClaudeClientNode:
	return _client_node


func _wire_ui() -> void:
	if not _refresh_auth_button.pressed.is_connected(_on_refresh_auth_pressed):
		_refresh_auth_button.pressed.connect(_on_refresh_auth_pressed)
	if not _connect_button.pressed.is_connected(_on_connect_pressed):
		_connect_button.pressed.connect(_on_connect_pressed)
	if not _disconnect_button.pressed.is_connected(_on_disconnect_pressed):
		_disconnect_button.pressed.connect(_on_disconnect_pressed)
	if not _interrupt_button.pressed.is_connected(_on_interrupt_pressed):
		_interrupt_button.pressed.connect(_on_interrupt_pressed)
	if not _send_button.pressed.is_connected(_on_send_pressed):
		_send_button.pressed.connect(_on_send_pressed)
	if not _prompt_input.text_changed.is_connected(_on_prompt_text_changed):
		_prompt_input.text_changed.connect(_on_prompt_text_changed)
	if not _model_input.text_changed.is_connected(_on_model_text_changed):
		_model_input.text_changed.connect(_on_model_text_changed)
	if not _permission_mode.item_selected.is_connected(_on_permission_mode_selected):
		_permission_mode.item_selected.connect(_on_permission_mode_selected)


func _apply_static_button_icons() -> void:
	_refresh_auth_button.icon = RefreshIcon
	_send_button.icon = SendIcon
	_interrupt_button.icon = InterruptIcon


func _populate_permission_modes() -> void:
	if _permission_mode.item_count > 0:
		return
	for mode in ["default", "plan", "acceptEdits", "bypassPermissions"]:
		_permission_mode.add_item(mode)


func _apply_initial_control_values() -> void:
	if _configured_options == null:
		_configured_options = ClaudeAgentOptionsScript.new()
	_model_input.text = _configured_options.model
	var target_mode: String = _configured_options.permission_mode if not _configured_options.permission_mode.is_empty() else "default"
	for index in range(_permission_mode.item_count):
		if _permission_mode.get_item_text(index) == target_mode:
			_permission_mode.select(index)
			break


func _ensure_client_node() -> void:
	if _client_node != null:
		if _client_node.get_parent() != self:
			add_child(_client_node)
		return
	_rebuild_client_node()


func _rebuild_client_node() -> void:
	var was_inside_tree := is_inside_tree()
	if _client_node != null:
		_disconnect_client_signals(_client_node)
		if _client_node.get_parent() == self:
			remove_child(_client_node)
		_client_node.queue_free()

	_client_node = ClaudeClientNode.new(_configured_options, _configured_transport)
	_client_node.name = "ClientNode"
	_client_node.auto_connect_on_ready = false
	_client_node.auto_disconnect_on_exit = true
	_connect_client_signals(_client_node)
	if was_inside_tree:
		add_child(_client_node)


func _connect_client_signals(client_node: ClaudeClientNode) -> void:
	client_node.session_ready.connect(_on_client_session_ready)
	client_node.busy_changed.connect(_on_client_busy_changed)
	client_node.message_received.connect(_on_client_message_received)
	client_node.turn_finished.connect(_on_client_turn_finished)
	client_node.error_occurred.connect(_on_client_error_occurred)
	client_node.session_closed.connect(_on_client_session_closed)


func _disconnect_client_signals(client_node: ClaudeClientNode) -> void:
	if client_node.session_ready.is_connected(_on_client_session_ready):
		client_node.session_ready.disconnect(_on_client_session_ready)
	if client_node.busy_changed.is_connected(_on_client_busy_changed):
		client_node.busy_changed.disconnect(_on_client_busy_changed)
	if client_node.message_received.is_connected(_on_client_message_received):
		client_node.message_received.disconnect(_on_client_message_received)
	if client_node.turn_finished.is_connected(_on_client_turn_finished):
		client_node.turn_finished.disconnect(_on_client_turn_finished)
	if client_node.error_occurred.is_connected(_on_client_error_occurred):
		client_node.error_occurred.disconnect(_on_client_error_occurred)
	if client_node.session_closed.is_connected(_on_client_session_closed):
		client_node.session_closed.disconnect(_on_client_session_closed)


func _apply_preconnect_controls_to_options() -> void:
	_configured_options.model = _model_input.text.strip_edges()
	_configured_options.permission_mode = _current_permission_mode()


func _on_client_session_ready(server_info: Dictionary) -> void:
	_did_connect_once = true
	_session_live = true
	_is_connecting = false
	_status_issue_message = ""
	if _needs_runtime_sync_after_connect:
		_needs_runtime_sync_after_connect = false
		if not _model_input.text.strip_edges().is_empty():
			_client_node.set_model(_model_input.text.strip_edges())
		_client_node.set_permission_mode(_current_permission_mode())
	_update_status_from_state(server_info)
	_refresh_composer_state()


func _on_client_busy_changed(_is_busy: bool) -> void:
	_update_status_from_state()
	_refresh_composer_state()


func _on_client_message_received(message: Variant) -> void:
	message_received.emit(message)
	if message is ClaudeSystemMessage:
		if message.subtype != "init":
			_append_detail_card("system", "System · %s" % message.subtype.capitalize(), _json_pretty(message.raw_data), false)
		return

	if message is ClaudeUserMessage:
		_handle_user_message(message)
		return

	if message is ClaudeAssistantMessage:
		_handle_assistant_message(message)
		return

	if message is ClaudeStreamEvent:
		_handle_stream_event(message)
		return

	if message is ClaudeResultMessage:
		_handle_result_message(message)


func _on_client_turn_finished(result_message: ClaudeResultMessage) -> void:
	_streaming_assistant_entry = null
	_streaming_assistant_body = null
	_streaming_assistant_buffer = ""
	turn_finished.emit(result_message)


func _on_client_error_occurred(message: String) -> void:
	_is_connecting = false
	_last_error = message
	_status_issue_message = message
	_update_status_from_state()
	_refresh_composer_state()
	error_occurred.emit(message)


func _on_client_session_closed() -> void:
	_is_connecting = false
	_session_live = false
	_streaming_assistant_entry = null
	_streaming_assistant_body = null
	_streaming_assistant_buffer = ""
	_update_status_from_state()
	_refresh_composer_state()


func _handle_user_message(message: ClaudeUserMessage) -> void:
	var content_text := _user_message_text(message.content)
	if not _pending_prompt_echo.is_empty() and content_text == _pending_prompt_echo:
		_pending_prompt_echo = ""
		return
	if content_text.is_empty():
		content_text = _json_pretty(message.raw_data)
	_append_message_bubble("user", content_text, "User", false)


func _handle_assistant_message(message: ClaudeAssistantMessage) -> void:
	var assistant_text := _assistant_text(message)
	if assistant_text.is_empty():
		for block in message.content:
			_render_assistant_detail_block(block)
		return

	var bubble_label := _ensure_streaming_assistant_bubble()
	_streaming_assistant_buffer = assistant_text
	bubble_label.text = assistant_text
	for block in message.content:
		if block is ClaudeTextBlock:
			continue
		_render_assistant_detail_block(block)
	_scroll_to_bottom_deferred()


func _handle_stream_event(message: ClaudeStreamEvent) -> void:
	var text_delta := _extract_stream_text(message.event)
	if text_delta.is_empty():
		return
	var bubble_label := _ensure_streaming_assistant_bubble()
	_streaming_assistant_buffer += text_delta
	bubble_label.text = _streaming_assistant_buffer
	_scroll_to_bottom_deferred()


func _handle_result_message(message: ClaudeResultMessage) -> void:
	_append_result_card(message)
	_update_status_from_state()
	_refresh_composer_state()


func _render_assistant_detail_block(block: Variant) -> void:
	if block is ClaudeThinkingBlock:
		_append_detail_card("thinking", "Thinking", str(block.thinking), true)
	elif block is ClaudeToolUseBlock:
		_append_detail_card("tool_use", "Tool use · %s" % block.name, _json_pretty(block.input), true)
	elif block is ClaudeToolResultBlock:
		var title := "Tool result"
		if block.is_error:
			title += " · error"
		_append_detail_card("tool_result", title, _json_pretty(block.content), true)


func _ensure_streaming_assistant_bubble() -> RichTextLabel:
	if _streaming_assistant_body != null and is_instance_valid(_streaming_assistant_body):
		return _streaming_assistant_body
	_streaming_assistant_entry = _append_message_bubble("assistant", "", "Claude", false)
	_streaming_assistant_body = _streaming_assistant_entry.find_child("BubbleBody", true, false) as RichTextLabel
	return _streaming_assistant_body


func _append_message_bubble(role: String, text: String, label_text: String, align_right: bool) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	row.set_meta("entry_kind", "%s_bubble" % role)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bubble := _build_card_container(_bubble_color(role), 24, 18)
	bubble.name = "BubbleContainer"
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.custom_minimum_size = Vector2(0, 56)
	bubble.size_flags_stretch_ratio = 0.8
	var bubble_body := VBoxContainer.new()
	bubble_body.name = "BubbleContent"
	bubble_body.add_theme_constant_override("separation", 8)
	bubble.add_child(bubble_body)

	var bubble_label := Label.new()
	bubble_label.text = label_text
	bubble_label.add_theme_color_override("font_color", COLOR_MUTED)
	bubble_label.add_theme_font_size_override("font_size", 12)
	bubble_body.add_child(bubble_label)

	var bubble_text := RichTextLabel.new()
	bubble_text.name = "BubbleBody"
	bubble_text.bbcode_enabled = false
	bubble_text.fit_content = true
	bubble_text.scroll_active = false
	bubble_text.selection_enabled = true
	bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_text.text = text
	bubble_text.add_theme_color_override("default_color", COLOR_TEXT)
	bubble_text.add_theme_font_size_override("normal_font_size", 15)
	bubble_body.add_child(bubble_text)

	if align_right:
		row.add_child(spacer)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(spacer)

	_transcript_list.add_child(row)
	_scroll_to_bottom_deferred()
	return row


func _append_detail_card(kind: String, title: String, body_text: String, collapsed: bool) -> Control:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("entry_kind", "%s_card" % kind)

	var card := _build_card_container(COLOR_PANEL_ALT, 18, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.name = "CardContainer"
	row.add_child(card)

	var card_body := VBoxContainer.new()
	card_body.add_theme_constant_override("separation", 10)
	card.add_child(card_body)

	var toggle := Button.new()
	toggle.text = _card_title(title, collapsed)
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.flat = true
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_theme_color_override("font_color", COLOR_TEXT)
	toggle.add_theme_font_size_override("font_size", 13)
	card_body.add_child(toggle)

	var content := RichTextLabel.new()
	content.name = "CardBody"
	content.bbcode_enabled = false
	content.fit_content = true
	content.scroll_active = false
	content.selection_enabled = true
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.text = body_text
	content.visible = not collapsed
	content.add_theme_color_override("default_color", COLOR_MUTED)
	content.add_theme_font_size_override("normal_font_size", 14)
	card_body.add_child(content)

	toggle.pressed.connect(func():
		content.visible = not content.visible
		toggle.text = _card_title(title, not content.visible)
		_scroll_to_bottom_deferred()
	)

	_transcript_list.add_child(row)
	_scroll_to_bottom_deferred()
	return row


func _append_result_card(message: ClaudeResultMessage) -> void:
	var card := _build_card_container(COLOR_PANEL_ALT, 20, 16)
	card.set_meta("entry_kind", "result_card")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	card.add_child(body)

	var headline := Label.new()
	headline.name = "ResultHeadlineLabel"
	headline.text = "Result · %s" % ("Error" if message.is_error else "Success")
	headline.add_theme_color_override("font_color", COLOR_ERROR if message.is_error else COLOR_SUCCESS)
	headline.add_theme_font_size_override("font_size", 14)
	body.add_child(headline)

	var summary := Label.new()
	summary.name = "ResultSummaryLabel"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = "Turns: %d   Duration: %s   Subtype: %s" % [
		message.num_turns,
		_format_duration(message.duration_ms),
		message.subtype,
	]
	summary.add_theme_color_override("font_color", COLOR_MUTED)
	body.add_child(summary)

	if not message.result.is_empty():
		var result_body := RichTextLabel.new()
		result_body.name = "ResultBodyLabel"
		result_body.fit_content = true
		result_body.scroll_active = false
		result_body.selection_enabled = true
		result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result_body.text = message.result
		result_body.add_theme_color_override("default_color", COLOR_TEXT)
		body.add_child(result_body)

	if message.structured_output != null:
		var structured_title := Label.new()
		structured_title.text = "Structured output"
		structured_title.add_theme_color_override("font_color", COLOR_ACCENT)
		body.add_child(structured_title)

		var structured := RichTextLabel.new()
		structured.name = "StructuredOutputLabel"
		structured.fit_content = true
		structured.scroll_active = false
		structured.selection_enabled = true
		structured.autowrap_mode = TextServer.AUTOWRAP_OFF
		structured.text = _json_pretty(message.structured_output)
		structured.add_theme_color_override("default_color", COLOR_TEXT)
		body.add_child(structured)

	if not message.errors.is_empty():
		var errors_title := Label.new()
		errors_title.text = "Reported errors"
		errors_title.add_theme_color_override("font_color", COLOR_WARNING)
		body.add_child(errors_title)

		var errors := RichTextLabel.new()
		errors.name = "ResultErrorsLabel"
		errors.fit_content = true
		errors.scroll_active = false
		errors.selection_enabled = true
		errors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		errors.text = "\n".join(message.errors)
		errors.add_theme_color_override("default_color", COLOR_MUTED)
		body.add_child(errors)

	_transcript_list.add_child(card)
	_scroll_to_bottom_deferred()


func _build_card_container(background: Color, radius: int, padding: int) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = COLOR_STROKE
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.content_margin_bottom = padding
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	card.add_theme_stylebox_override("panel", style)
	return card


func _bubble_color(role: String) -> Color:
	match role:
		"user":
			return Color(COLOR_USER.r, COLOR_USER.g, COLOR_USER.b, 0.20)
		"assistant":
			return Color(COLOR_ASSISTANT.r, COLOR_ASSISTANT.g, COLOR_ASSISTANT.b, 0.18)
		_:
			return COLOR_PANEL_ALT


func _update_status_from_state(server_info: Dictionary = {}) -> void:
	if _session_live:
		var command_count := (server_info.get("commands", []) as Array).size() if server_info.has("commands") else 0
		_set_status_badge("Connected", COLOR_SUCCESS)
		_status_title.text = "Connected to Claude"
		_status_detail.text = "Live session ready%s" % (" · %d commands advertised" % command_count if command_count > 0 else "")
	elif _is_connecting:
		_set_status_badge("Connecting", COLOR_ACCENT)
		_status_title.text = "Connecting to Claude"
		_status_detail.text = "Waiting for the streaming session to initialize."
	else:
		var logged_in := bool(_last_auth_status.get("logged_in", false))
		var error_message := str(_last_auth_status.get("error_message", ""))
		if not _status_issue_message.is_empty():
			_set_status_badge("Issue", COLOR_ERROR)
			_status_title.text = "Claude session failed to start"
			_status_detail.text = _status_issue_message
		elif logged_in:
			_set_status_badge("Ready", COLOR_SUCCESS)
			_status_title.text = "Claude CLI is authenticated"
			_status_detail.text = _auth_detail_text()
		elif not error_message.is_empty():
			_set_status_badge("Issue", COLOR_ERROR)
			_status_title.text = "Claude CLI needs attention"
			_status_detail.text = error_message
		else:
			_set_status_badge("Logged out", COLOR_WARNING)
			_status_title.text = "Claude CLI is not logged in"
			_status_detail.text = "Run claude auth login in a terminal, then refresh auth."

	_connect_button.disabled = _is_connecting or _session_live or not bool(_last_auth_status.get("logged_in", false))
	_disconnect_button.disabled = not _session_live and not _is_connecting
	_refresh_auth_button.disabled = _is_connecting


func _refresh_composer_state() -> void:
	var can_send: bool = _session_live and not _client_node.is_busy() and not _prompt_input.text.strip_edges().is_empty()
	_prompt_input.editable = _session_live and not _client_node.is_busy()
	_send_button.disabled = not can_send
	_interrupt_button.disabled = not _session_live or not _client_node.is_busy()
	_composer_hint.text = _composer_hint_text()


func _composer_hint_text() -> String:
	if not _session_live:
		return "Connect the authenticated Claude CLI to start chatting."
	if _client_node.is_busy():
		return "Claude is responding. You can interrupt the active turn if needed."
	if _prompt_input.text.strip_edges().is_empty():
		return "Draft a prompt here. The panel renders typed runtime messages and partial output."
	return "Send the prompt to Claude."


func _set_status_badge(text: String, color: Color) -> void:
	_status_badge_label.text = text
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(color.r, color.g, color.b, 0.22)
	badge_style.border_color = color
	badge_style.border_width_bottom = 1
	badge_style.border_width_left = 1
	badge_style.border_width_right = 1
	badge_style.border_width_top = 1
	badge_style.corner_radius_bottom_left = 12
	badge_style.corner_radius_bottom_right = 12
	badge_style.corner_radius_top_left = 12
	badge_style.corner_radius_top_right = 12
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.content_margin_top = 6
	badge_style.content_margin_bottom = 6
	_status_badge.add_theme_stylebox_override("panel", badge_style)
	_status_badge_label.add_theme_color_override("font_color", color.lightened(0.35))


func _apply_theme_overrides() -> void:
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color(COLOR_BG.r, COLOR_BG.g, COLOR_BG.b, 0.94)
	shell_style.border_color = COLOR_STROKE
	shell_style.border_width_bottom = 1
	shell_style.border_width_left = 1
	shell_style.border_width_right = 1
	shell_style.border_width_top = 1
	shell_style.corner_radius_bottom_left = 28
	shell_style.corner_radius_bottom_right = 28
	shell_style.corner_radius_top_left = 28
	shell_style.corner_radius_top_right = 28
	_shell.add_theme_stylebox_override("panel", shell_style)


func _auth_detail_text() -> String:
	var parts: Array[String] = []
	var email := str(_last_auth_status.get("email", ""))
	var org_name := str(_last_auth_status.get("org_name", ""))
	var subscription := str(_last_auth_status.get("subscription_type", ""))
	if not email.is_empty():
		parts.append(email)
	if not org_name.is_empty():
		parts.append(org_name)
	if not subscription.is_empty():
		parts.append(subscription)
	return " · ".join(parts)


func _current_permission_mode() -> String:
	if _permission_mode.item_count == 0:
		return "default"
	return _permission_mode.get_item_text(_permission_mode.get_selected_id())


func _assistant_text(message: ClaudeAssistantMessage) -> String:
	var parts: Array[String] = []
	for block in message.content:
		if block is ClaudeTextBlock:
			parts.append(str(block.text))
	return "\n\n".join(parts)


func _user_message_text(content: Variant) -> String:
	if content is String:
		return str(content)
	if content is Array:
		var parts: Array[String] = []
		for block in content:
			if block is ClaudeTextBlock:
				parts.append(str(block.text))
		return "\n\n".join(parts)
	return ""


func _extract_stream_text(event: Dictionary) -> String:
	if event.has("delta") and event["delta"] is Dictionary:
		var delta: Dictionary = event["delta"]
		if delta.has("text") and delta["text"] is String:
			return str(delta["text"])
	if event.has("text") and event["text"] is String:
		return str(event["text"])
	return ""


func _json_pretty(value: Variant) -> String:
	if value == null:
		return "null"
	if value is Dictionary or value is Array:
		return JSON.stringify(value, "  ")
	return str(value)


func _format_duration(duration_ms: int) -> String:
	if duration_ms < 1000:
		return "%d ms" % duration_ms
	return "%.2f s" % (float(duration_ms) / 1000.0)


func _card_title(title: String, collapsed: bool) -> String:
	return "%s %s" % ["▸" if collapsed else "▾", title]


func _scroll_to_bottom_deferred() -> void:
	Callable(self, "_scroll_to_bottom").call_deferred()


func _scroll_to_bottom() -> void:
	_transcript_scroll.scroll_vertical = int(_transcript_scroll.get_v_scroll_bar().max_value)


func _emit_error(message: String) -> void:
	_last_error = message
	error_occurred.emit(message)


func _on_refresh_auth_pressed() -> void:
	refresh_auth_status()


func _on_connect_pressed() -> void:
	connect_client()


func _on_disconnect_pressed() -> void:
	disconnect_client()


func _on_interrupt_pressed() -> void:
	if _client_node != null:
		_client_node.interrupt()


func _on_send_pressed() -> void:
	submit_prompt(_prompt_input.text)


func _on_prompt_text_changed() -> void:
	_refresh_composer_state()


func _on_model_text_changed(new_text: String) -> void:
	if _session_live and not new_text.strip_edges().is_empty():
		_client_node.set_model(new_text.strip_edges())


func _on_permission_mode_selected(_index: int) -> void:
	if _session_live:
		_client_node.set_permission_mode(_current_permission_mode())
