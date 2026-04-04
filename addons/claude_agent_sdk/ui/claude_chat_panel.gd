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
var _last_error := ""
var _status_issue_message := ""
var _base_resume := ""
var _base_session_id := ""
var _session_scope_directory := ""
var _session_infos: Array[ClaudeSessionInfo] = []
var _selected_session_id := ""
var _selected_session_info: ClaudeSessionInfo = null
var _selected_session_messages: Array[ClaudeSessionMessage] = []
var _delete_confirm_armed := false
var _connected_session_id := "default"
var _did_apply_initial_split := false

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
@onready var _split_row: HSplitContainer = $Shell/Margin/Body/SplitRow
@onready var _session_refresh_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SessionHeader/SessionActions/SessionRefreshButton
@onready var _new_chat_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SessionHeader/SessionActions/NewChatButton
@onready var _session_list: ItemList = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SessionList
@onready var _selected_session_summary: Label = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SelectedSessionSummaryValue
@onready var _selected_session_meta: Label = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SelectedSessionMetaValue
@onready var _selected_session_branch: Label = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SelectedSessionBranchValue
@onready var _selected_session_cwd: Label = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SelectedSessionCwdValue
@onready var _session_title_input: LineEdit = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SessionTitleGroup/SessionTitleInput
@onready var _session_tag_input: LineEdit = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SessionTagGroup/SessionTagInput
@onready var _rename_session_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SessionActionGrid/RenameSessionButton
@onready var _apply_tag_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SessionActionGrid/ApplyTagButton
@onready var _clear_tag_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SessionActionGrid/ClearTagButton
@onready var _delete_session_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SessionActionGrid/DeleteSessionButton
@onready var _confirm_delete_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/DeleteConfirmRow/ConfirmDeleteButton
@onready var _cancel_delete_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/DeleteConfirmRow/CancelDeleteButton
@onready var _transcript_scroll: ScrollContainer = $Shell/Margin/Body/SplitRow/ChatColumn/TranscriptCard/TranscriptScroll
@onready var _transcript_list: VBoxContainer = $Shell/Margin/Body/SplitRow/ChatColumn/TranscriptCard/TranscriptScroll/TranscriptList
@onready var _composer_hint: Label = $Shell/Margin/Body/SplitRow/ChatColumn/ComposerCard/ComposerMargin/ComposerBody/ComposerActions/ComposerHintLabel
@onready var _prompt_input: TextEdit = $Shell/Margin/Body/SplitRow/ChatColumn/ComposerCard/ComposerMargin/ComposerBody/PromptInput
@onready var _interrupt_button: Button = $Shell/Margin/Body/SplitRow/ChatColumn/ComposerCard/ComposerMargin/ComposerBody/ComposerActions/InterruptButton
@onready var _send_button: Button = $Shell/Margin/Body/SplitRow/ChatColumn/ComposerCard/ComposerMargin/ComposerBody/ComposerActions/SendButton


func _init() -> void:
	_configured_options = ClaudeAgentOptionsScript.new()
	_capture_base_session_defaults()


func _ready() -> void:
	_apply_static_button_icons()
	_populate_permission_modes()
	_apply_initial_control_values()
	_ensure_client_node()
	_wire_ui()
	_apply_theme_overrides()
	_session_scope_directory = _resolve_session_scope_directory()
	_reload_sessions(false)
	_refresh_composer_state()
	refresh_auth_status()
	call_deferred("_apply_initial_split_layout")


func setup(options = null, transport = null) -> void:
	if _did_connect_once:
		_emit_error("setup() must be called before the first successful connect_client()")
		return
	_configured_options = options.duplicate_options() if options != null else ClaudeAgentOptionsScript.new()
	_configured_transport = transport
	_capture_base_session_defaults()
	if is_node_ready():
		_apply_initial_control_values()
		_session_scope_directory = _resolve_session_scope_directory()
		_reload_sessions(false)
		_rebuild_client_node()


func connect_client() -> void:
	if _session_live or _is_connecting:
		return
	_status_issue_message = ""
	_apply_preconnect_controls_to_options()
	_apply_session_target_to_options()
	_rebuild_client_node()
	_connected_session_id = _effective_connect_session_id()
	_is_connecting = true
	_update_status_from_state()
	_refresh_composer_state()
	_refresh_session_controls()
	_client_node.connect_client()

	if not _client_node.get_last_error().is_empty():
		_is_connecting = false
		_status_issue_message = _client_node.get_last_error()
		_emit_error(_client_node.get_last_error())
		_update_status_from_state()
		_refresh_composer_state()
		_refresh_session_controls()


func disconnect_client() -> void:
	if _client_node == null:
		return
	_client_node.disconnect_client()
	if not _session_live and not _is_connecting:
		_restore_disconnected_view()


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
	_connected_session_id = _effective_connect_session_id()
	_client_node.query(trimmed, _connected_session_id)

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
	_refresh_session_controls()


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
	if not _session_refresh_button.pressed.is_connected(_on_session_refresh_pressed):
		_session_refresh_button.pressed.connect(_on_session_refresh_pressed)
	if not _new_chat_button.pressed.is_connected(_on_new_chat_pressed):
		_new_chat_button.pressed.connect(_on_new_chat_pressed)
	if not _session_list.item_selected.is_connected(_on_session_list_item_selected):
		_session_list.item_selected.connect(_on_session_list_item_selected)
	if not _session_list.item_activated.is_connected(_on_session_list_item_activated):
		_session_list.item_activated.connect(_on_session_list_item_activated)
	if not _rename_session_button.pressed.is_connected(_on_rename_session_pressed):
		_rename_session_button.pressed.connect(_on_rename_session_pressed)
	if not _apply_tag_button.pressed.is_connected(_on_apply_tag_pressed):
		_apply_tag_button.pressed.connect(_on_apply_tag_pressed)
	if not _clear_tag_button.pressed.is_connected(_on_clear_tag_pressed):
		_clear_tag_button.pressed.connect(_on_clear_tag_pressed)
	if not _delete_session_button.pressed.is_connected(_on_delete_session_pressed):
		_delete_session_button.pressed.connect(_on_delete_session_pressed)
	if not _confirm_delete_button.pressed.is_connected(_on_confirm_delete_pressed):
		_confirm_delete_button.pressed.connect(_on_confirm_delete_pressed)
	if not _cancel_delete_button.pressed.is_connected(_on_cancel_delete_pressed):
		_cancel_delete_button.pressed.connect(_on_cancel_delete_pressed)
	if not _session_title_input.text_changed.is_connected(_on_session_title_text_changed):
		_session_title_input.text_changed.connect(_on_session_title_text_changed)
	if not _session_tag_input.text_changed.is_connected(_on_session_tag_text_changed):
		_session_tag_input.text_changed.connect(_on_session_tag_text_changed)


func _apply_static_button_icons() -> void:
	_refresh_auth_button.icon = RefreshIcon
	_session_refresh_button.icon = RefreshIcon
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
	_capture_base_session_defaults()
	_model_input.text = _configured_options.model
	var target_mode: String = _configured_options.permission_mode if not _configured_options.permission_mode.is_empty() else "default"
	for index in range(_permission_mode.item_count):
		if _permission_mode.get_item_text(index) == target_mode:
			_permission_mode.select(index)
			break


func _capture_base_session_defaults() -> void:
	_base_resume = _configured_options.resume if _configured_options != null else ""
	_base_session_id = _configured_options.session_id if _configured_options != null else ""
	_connected_session_id = _effective_connect_session_id()


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


func _apply_session_target_to_options() -> void:
	if _has_selected_session():
		_configured_options.resume = _selected_session_id
		_configured_options.session_id = _selected_session_id
	else:
		_configured_options.resume = _base_resume
		_configured_options.session_id = _base_session_id


func _effective_connect_session_id() -> String:
	if _has_selected_session():
		return _selected_session_id
	if not _base_session_id.is_empty():
		return _base_session_id
	return "default"


func _resolve_session_scope_directory() -> String:
	if _configured_options != null and not _configured_options.cwd.is_empty():
		return _configured_options.cwd
	return ProjectSettings.globalize_path("res://")


func _reload_sessions(preserve_selection: bool = true) -> void:
	_session_scope_directory = _resolve_session_scope_directory()
	var prior_selected_id := _selected_session_id if preserve_selection else ""
	_session_infos = _client_node.list_sessions(_session_scope_directory, 0, 0, true)
	_populate_session_list()

	if not prior_selected_id.is_empty():
		var selected_index := _find_session_index(prior_selected_id)
		if selected_index >= 0:
			_select_session_by_index(selected_index)
		elif not _session_live and not _is_connecting:
			_clear_selected_session(true)
	else:
		_refresh_selected_session_metadata()
	_refresh_session_controls()
	_refresh_composer_state()


func _populate_session_list() -> void:
	_session_list.clear()
	for index in range(_session_infos.size()):
		var info := _session_infos[index]
		_session_list.add_item(_session_list_label(info))
		_session_list.set_item_metadata(index, info.session_id)
		if info.session_id == _selected_session_id:
			_session_list.select(index)


func _find_session_index(session_id: String) -> int:
	for index in range(_session_infos.size()):
		if _session_infos[index].session_id == session_id:
			return index
	return -1


func _select_session_by_index(index: int) -> void:
	if index < 0 or index >= _session_infos.size():
		return
	var info := _session_infos[index]
	_selected_session_id = info.session_id
	_selected_session_info = info
	_delete_confirm_armed = false
	_connected_session_id = _effective_connect_session_id()
	_session_list.select(index)
	_refresh_selected_session_fields()
	if _can_switch_sessions():
		_reload_selected_session_transcript()
	else:
		_refresh_selected_session_metadata()
	_refresh_session_controls()
	_update_status_from_state()
	_refresh_composer_state()


func _clear_selected_session(clear_transcript_too: bool) -> void:
	_selected_session_id = ""
	_selected_session_info = null
	_selected_session_messages.clear()
	_delete_confirm_armed = false
	_connected_session_id = _effective_connect_session_id()
	_session_list.deselect_all()
	_refresh_selected_session_fields()
	if clear_transcript_too:
		clear_transcript()
	_refresh_selected_session_metadata()
	_refresh_session_controls()
	_update_status_from_state()
	_refresh_composer_state()


func _reload_selected_session_transcript() -> void:
	if not _has_selected_session():
		return
	var session_info = _client_node.get_session_info(_selected_session_id, _selected_session_directory())
	if session_info == null:
		_clear_selected_session(true)
		_reload_sessions(false)
		return
	_selected_session_info = session_info
	_selected_session_messages = _client_node.get_session_messages(_selected_session_id, _selected_session_directory())
	_render_selected_session_transcript()
	_refresh_selected_session_metadata()


func _render_selected_session_transcript() -> void:
	clear_transcript()
	for message in _selected_session_messages:
		var text := _historical_message_text(message.message)
		if text.is_empty():
			text = _json_pretty(message.message)
		if message.type == "user":
			_append_message_bubble("user", text, "You", true)
		elif message.type == "assistant":
			_append_message_bubble("assistant", text, "Claude", false)


func _historical_message_text(payload: Variant) -> String:
	if payload is String:
		return str(payload)
	if not (payload is Dictionary):
		return ""
	var content: Variant = payload.get("content")
	if content is String:
		return str(content)
	if content is Array:
		var parts: Array[String] = []
		for block in content:
			if block is Dictionary and str(block.get("type", "")) == "text":
				parts.append(str(block.get("text", "")))
		return "\n\n".join(parts)
	return ""


func _session_list_label(info: ClaudeSessionInfo) -> String:
	var label := info.summary
	if info.tag != null and not str(info.tag).is_empty():
		label += "  #%s" % str(info.tag)
	return "%s\n%s" % [label, _format_timestamp(info.last_modified)]


func _refresh_selected_session_fields() -> void:
	if _selected_session_info == null:
		_session_title_input.text = ""
		_session_tag_input.text = ""
		return
	_session_title_input.text = str(
		_selected_session_info.custom_title if _selected_session_info.custom_title != null else _selected_session_info.summary
	)
	_session_tag_input.text = str(_selected_session_info.tag) if _selected_session_info.tag != null else ""


func _refresh_selected_session_metadata() -> void:
	if _selected_session_info == null:
		_selected_session_summary.text = "No saved session selected."
		_selected_session_meta.text = "Choose a saved transcript to inspect it, or start a new chat."
		_selected_session_branch.text = ""
		_selected_session_cwd.text = ""
		return

	var visible_title := str(
		_selected_session_info.custom_title if _selected_session_info.custom_title != null else _selected_session_info.summary
	)
	_selected_session_summary.text = visible_title
	var meta_parts: Array[String] = ["Updated %s" % _format_timestamp(_selected_session_info.last_modified)]
	if _selected_session_info.tag != null and not str(_selected_session_info.tag).is_empty():
		meta_parts.append("Tag: %s" % str(_selected_session_info.tag))
	_selected_session_meta.text = " · ".join(meta_parts)
	_selected_session_branch.text = "Branch: %s" % str(_selected_session_info.git_branch) if _selected_session_info.git_branch != null and not str(_selected_session_info.git_branch).is_empty() else ""
	_selected_session_cwd.text = "Directory: %s" % str(_selected_session_info.cwd) if _selected_session_info.cwd != null and not str(_selected_session_info.cwd).is_empty() else ""


func _refresh_session_controls() -> void:
	var has_selection := _has_selected_session()
	var switching_locked := not _can_switch_sessions()
	var mutations_locked := _session_live or _is_connecting
	_session_refresh_button.disabled = switching_locked
	_new_chat_button.disabled = switching_locked or (not has_selection and _transcript_list.get_child_count() == 0)
	_session_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if switching_locked else Control.MOUSE_FILTER_STOP
	_session_list.focus_mode = Control.FOCUS_NONE if switching_locked else Control.FOCUS_ALL
	_session_title_input.editable = has_selection and not mutations_locked
	_session_tag_input.editable = has_selection and not mutations_locked
	_rename_session_button.disabled = not has_selection or mutations_locked or _session_title_input.text.strip_edges().is_empty()
	_apply_tag_button.disabled = not has_selection or mutations_locked or _session_tag_input.text.strip_edges().is_empty()
	_clear_tag_button.disabled = not has_selection or mutations_locked or _selected_session_info == null or _selected_session_info.tag == null or str(_selected_session_info.tag).is_empty()
	_delete_session_button.disabled = not has_selection or mutations_locked
	_confirm_delete_button.visible = has_selection and not mutations_locked and _delete_confirm_armed
	_cancel_delete_button.visible = has_selection and not mutations_locked and _delete_confirm_armed


func _has_selected_session() -> bool:
	return not _selected_session_id.is_empty()


func _selected_session_directory() -> String:
	if _selected_session_info != null and _selected_session_info.cwd != null and not str(_selected_session_info.cwd).is_empty():
		return str(_selected_session_info.cwd)
	return _session_scope_directory


func _can_switch_sessions() -> bool:
	if _is_connecting:
		return false
	if not _session_live:
		return true
	return _client_node != null and not _client_node.is_busy()


func _restore_disconnected_view() -> void:
	_is_connecting = false
	_session_live = false
	_streaming_assistant_entry = null
	_streaming_assistant_body = null
	_streaming_assistant_buffer = ""
	if _has_selected_session():
		_reload_selected_session_transcript()
	_update_status_from_state()
	_refresh_composer_state()
	_refresh_session_controls()


func _on_client_session_ready(server_info: Dictionary) -> void:
	_did_connect_once = true
	_session_live = true
	_is_connecting = false
	_status_issue_message = ""
	_update_status_from_state(server_info)
	_refresh_composer_state()
	_refresh_session_controls()


func _on_client_busy_changed(_is_busy: bool) -> void:
	_update_status_from_state()
	_refresh_composer_state()
	_refresh_session_controls()


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
	_refresh_session_controls()
	error_occurred.emit(message)


func _on_client_session_closed() -> void:
	_restore_disconnected_view()


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
		_status_detail.text = "Live session ready%s%s" % [
			" · selected saved session is active for the next turns" if _has_selected_session() else "",
			" · %d commands advertised" % command_count if command_count > 0 else "",
		]
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
		elif not logged_in and not error_message.is_empty():
			_set_status_badge("Issue", COLOR_ERROR)
			_status_title.text = "Claude CLI needs attention"
			_status_detail.text = error_message
		elif not logged_in:
			_set_status_badge("Logged out", COLOR_WARNING)
			_status_title.text = "Claude CLI is not logged in"
			_status_detail.text = "Run claude auth login in a terminal, then refresh auth."
		elif _has_selected_session():
			_set_status_badge("Saved", COLOR_ACCENT)
			_status_title.text = "Saved session selected"
			_status_detail.text = "Connect to resume this saved transcript, or start a new chat."
		else:
			_set_status_badge("Ready", COLOR_SUCCESS)
			_status_title.text = "Claude CLI is authenticated"
			_status_detail.text = _auth_detail_text()

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
		if _has_selected_session():
			return "This saved transcript is read-only until you connect to resume it."
		return "Connect the authenticated Claude CLI to start chatting."
	if _client_node.is_busy():
		return "Claude is responding. You can interrupt the active turn if needed."
	if _has_selected_session():
		return "You are continuing the selected saved session."
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


func _apply_initial_split_layout() -> void:
	if _did_apply_initial_split:
		return
	var available_width := _split_row.size.x
	if available_width <= 0.0:
		call_deferred("_apply_initial_split_layout")
		return
	var target_left_width := clampf(available_width * 0.4, 290.0, maxf(290.0, available_width - 420.0))
	var center := available_width * 0.5
	_split_row.split_offset = int(round(target_left_width - center))
	_did_apply_initial_split = true


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


func _format_timestamp(timestamp_ms: int) -> String:
	var unix_time := int(timestamp_ms / 1000)
	return Time.get_datetime_string_from_unix_time(unix_time, true)


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


func _on_session_refresh_pressed() -> void:
	if not _can_switch_sessions():
		return
	_reload_sessions(true)


func _on_new_chat_pressed() -> void:
	if not _can_switch_sessions():
		return
	_clear_selected_session(true)


func _on_session_list_item_selected(index: int) -> void:
	if not _can_switch_sessions():
		return
	_select_session_by_index(index)


func _on_session_list_item_activated(index: int) -> void:
	if not _can_switch_sessions():
		return
	_select_session_by_index(index)


func _on_rename_session_pressed() -> void:
	if not _has_selected_session():
		return
	var result: int = _client_node.rename_session(_selected_session_id, _session_title_input.text, _selected_session_directory())
	if result != OK:
		_status_issue_message = _client_node.get_last_error()
		_update_status_from_state()
		return
	_status_issue_message = ""
	_reload_sessions(true)


func _on_apply_tag_pressed() -> void:
	if not _has_selected_session():
		return
	var result: int = _client_node.tag_session(_selected_session_id, _session_tag_input.text, _selected_session_directory())
	if result != OK:
		_status_issue_message = _client_node.get_last_error()
		_update_status_from_state()
		return
	_status_issue_message = ""
	_reload_sessions(true)


func _on_clear_tag_pressed() -> void:
	if not _has_selected_session():
		return
	var result: int = _client_node.tag_session(_selected_session_id, null, _selected_session_directory())
	if result != OK:
		_status_issue_message = _client_node.get_last_error()
		_update_status_from_state()
		return
	_status_issue_message = ""
	_reload_sessions(true)


func _on_delete_session_pressed() -> void:
	if not _has_selected_session():
		return
	_delete_confirm_armed = true
	_refresh_session_controls()


func _on_confirm_delete_pressed() -> void:
	if not _has_selected_session():
		return
	var deleted_session_id := _selected_session_id
	var result: int = _client_node.delete_session(deleted_session_id, _selected_session_directory())
	if result != OK:
		_status_issue_message = _client_node.get_last_error()
		_delete_confirm_armed = false
		_update_status_from_state()
		_refresh_session_controls()
		return
	_status_issue_message = ""
	_clear_selected_session(true)
	_reload_sessions(false)


func _on_cancel_delete_pressed() -> void:
	_delete_confirm_armed = false
	_refresh_session_controls()


func _on_session_title_text_changed(_new_text: String) -> void:
	_refresh_session_controls()


func _on_session_tag_text_changed(_new_text: String) -> void:
	_refresh_session_controls()
