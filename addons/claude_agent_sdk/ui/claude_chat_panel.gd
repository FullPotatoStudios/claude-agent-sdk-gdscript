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
const PANEL_VIEW_CHAT := 0
const PANEL_VIEW_SETTINGS := 1
const SYSTEM_PROMPT_MODE_VANILLA := 0
const SYSTEM_PROMPT_MODE_TEXT := 1
const SYSTEM_PROMPT_MODE_PRESET := 2
const SYSTEM_PROMPT_MODE_PRESET_APPEND := 3
const SYSTEM_PROMPT_MODE_FILE := 4
const MODEL_PRESETS := ["haiku", "sonnet", "opus"]
const EFFORT_PRESETS := ["low", "medium", "high", "max"]

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
var _selected_session_transcript: Array[ClaudeSessionTranscriptEntry] = []
var _delete_confirm_armed := false
var _live_session_target_id := "default"
var _authoritative_live_session_id := ""
var _clear_transcript_after_disconnect := false
var _last_cli_diagnostic_line := ""
var _forwarded_stderr_callback: Callable = Callable()
var _did_apply_initial_split := false
var _suppress_configuration_sync := false
var _built_in_tool_checks: Dictionary = {}
var _built_in_tool_group_buttons: Dictionary = {}
var _current_view := PANEL_VIEW_CHAT
var _transcript_entries: Array[Dictionary] = []
var _transcript_entry_views := {}
var _task_entry_ids := {}
var _tool_use_names := {}
var _next_transcript_entry_id := 1
var _current_assistant_entry_id := -1
var _current_thinking_entry_id := -1
var _pending_prompt_entry_id := -1
var _rewind_pending_entry_id := -1
var _live_context_usage: Dictionary = {}
var _live_context_usage_error := ""
var _context_usage_refresh_pending := false
var _live_mcp_status: Dictionary = {}
var _live_mcp_status_error := ""
var _mcp_status_refresh_pending := false
var _mcp_server_action_pending: Dictionary = {}

@onready var _shell: PanelContainer = $Shell
@onready var _status_badge: PanelContainer = $Shell/Margin/Body/Header/TopRow/StatusCluster/StatusBadge
@onready var _status_badge_label: Label = $Shell/Margin/Body/Header/TopRow/StatusCluster/StatusBadge/StatusBadgeLabel
@onready var _status_title: Label = $Shell/Margin/Body/Header/TopRow/StatusCluster/StatusText/StatusTitleLabel
@onready var _status_detail: Label = $Shell/Margin/Body/Header/TopRow/StatusCluster/StatusText/StatusDetailLabel
@onready var _refresh_auth_button: Button = $Shell/Margin/Body/Header/TopRow/ActionButtons/RefreshAuthButton
@onready var _connect_button: Button = $Shell/Margin/Body/Header/TopRow/ActionButtons/ConnectButton
@onready var _disconnect_button: Button = $Shell/Margin/Body/Header/TopRow/ActionButtons/DisconnectButton
@onready var _chat_view_button: Button = $Shell/Margin/Body/ViewNavigation/ChatViewButton
@onready var _settings_view_button: Button = $Shell/Margin/Body/ViewNavigation/SettingsViewButton
@onready var _settings_scroll: ScrollContainer = $Shell/Margin/Body/SettingsScroll
@onready var _live_session_section: VBoxContainer = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/LiveSessionSection
@onready var _refresh_context_usage_button: Button = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/LiveSessionSection/LiveContextCard/LiveContextMargin/LiveContextBody/LiveContextHeader/RefreshContextUsageButton
@onready var _live_context_summary_value: Label = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/LiveSessionSection/LiveContextCard/LiveContextMargin/LiveContextBody/LiveContextSummaryValue
@onready var _live_context_detail_value: Label = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/LiveSessionSection/LiveContextCard/LiveContextMargin/LiveContextBody/LiveContextDetailValue
@onready var _refresh_mcp_status_button: Button = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/LiveSessionSection/LiveMcpCard/LiveMcpMargin/LiveMcpBody/LiveMcpHeader/RefreshMcpStatusButton
@onready var _live_mcp_summary_value: Label = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/LiveSessionSection/LiveMcpCard/LiveMcpMargin/LiveMcpBody/LiveMcpSummaryValue
@onready var _live_mcp_server_list: VBoxContainer = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/LiveSessionSection/LiveMcpCard/LiveMcpMargin/LiveMcpBody/LiveMcpServerList
@onready var _system_prompt_section: VBoxContainer = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/SystemPromptSection
@onready var _tools_section: VBoxContainer = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/ToolsSection
@onready var _mcp_summary_section: VBoxContainer = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/McpSummarySection
@onready var _system_prompt_mode: OptionButton = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/SystemPromptSection/SystemPromptModeGroup/SystemPromptModeOption
@onready var _system_prompt_text_group: VBoxContainer = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/SystemPromptSection/SystemPromptTextGroup
@onready var _system_prompt_text_label: Label = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/SystemPromptSection/SystemPromptTextGroup/SystemPromptTextLabel
@onready var _system_prompt_text_input: TextEdit = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/SystemPromptSection/SystemPromptTextGroup/SystemPromptTextInput
@onready var _system_prompt_file_group: VBoxContainer = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/SystemPromptSection/SystemPromptFileGroup
@onready var _system_prompt_file_input: LineEdit = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/SystemPromptSection/SystemPromptFileGroup/SystemPromptFileInput
@onready var _built_in_tools_summary: Label = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/ToolsSection/BuiltInToolsGroup/BuiltInToolsSummaryValue
@onready var _built_in_tool_groups: GridContainer = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/ToolsSection/BuiltInToolsGroup/BuiltInToolsCard/BuiltInToolsMargin/BuiltInToolsBody/BuiltInToolGroups
@onready var _tool_rules_advanced_toggle: Button = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/ToolsSection/ToolRulesAdvancedGroup/ToolRulesAdvancedToggle
@onready var _tool_rules_advanced_body: VBoxContainer = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/ToolsSection/ToolRulesAdvancedGroup/ToolRulesAdvancedBody
@onready var _allowed_tools_input: LineEdit = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/ToolsSection/ToolRulesAdvancedGroup/ToolRulesAdvancedBody/ToolGovernanceGrid/AllowedToolsGroup/AllowedToolsInput
@onready var _disallowed_tools_input: LineEdit = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/ToolsSection/ToolRulesAdvancedGroup/ToolRulesAdvancedBody/ToolGovernanceGrid/DisallowedToolsGroup/DisallowedToolsInput
@onready var _rewind_support_toggle: CheckBox = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/RewindSection/RewindSupportToggle
@onready var _mcp_summary_value: Label = $Shell/Margin/Body/SettingsScroll/SettingsBody/ControlRow/ControlMargin/SettingsRow/McpSummarySection/McpSummaryGroup/McpSummaryValue
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
@onready var _fork_title_input: LineEdit = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/ForkTitleGroup/ForkTitleInput
@onready var _rename_session_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SessionActionGrid/RenameSessionButton
@onready var _apply_tag_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SessionActionGrid/ApplyTagButton
@onready var _clear_tag_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SessionActionGrid/ClearTagButton
@onready var _delete_session_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SessionActionGrid/DeleteSessionButton
@onready var _fork_session_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/SessionActionGrid/ForkSessionButton
@onready var _confirm_delete_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/DeleteConfirmRow/ConfirmDeleteButton
@onready var _cancel_delete_button: Button = $Shell/Margin/Body/SplitRow/SessionPane/SessionMargin/SessionBody/SelectedSessionCard/SelectedSessionMargin/SelectedSessionBody/DeleteConfirmRow/CancelDeleteButton
@onready var _thinking_toggle: CheckButton = $Shell/Margin/Body/SplitRow/ChatColumn/TranscriptCard/TranscriptMargin/TranscriptBody/TranscriptToolbar/ThinkingToggle
@onready var _tasks_toggle: CheckButton = $Shell/Margin/Body/SplitRow/ChatColumn/TranscriptCard/TranscriptMargin/TranscriptBody/TranscriptToolbar/TasksToggle
@onready var _tools_toggle: CheckButton = $Shell/Margin/Body/SplitRow/ChatColumn/TranscriptCard/TranscriptMargin/TranscriptBody/TranscriptToolbar/ToolsToggle
@onready var _results_toggle: CheckButton = $Shell/Margin/Body/SplitRow/ChatColumn/TranscriptCard/TranscriptMargin/TranscriptBody/TranscriptToolbar/ResultsToggle
@onready var _system_toggle: CheckButton = $Shell/Margin/Body/SplitRow/ChatColumn/TranscriptCard/TranscriptMargin/TranscriptBody/TranscriptToolbar/SystemToggle
@onready var _raw_toggle: CheckButton = $Shell/Margin/Body/SplitRow/ChatColumn/TranscriptCard/TranscriptMargin/TranscriptBody/TranscriptToolbar/RawToggle
@onready var _transcript_scroll: ScrollContainer = $Shell/Margin/Body/SplitRow/ChatColumn/TranscriptCard/TranscriptMargin/TranscriptBody/TranscriptScroll
@onready var _transcript_list: VBoxContainer = $Shell/Margin/Body/SplitRow/ChatColumn/TranscriptCard/TranscriptMargin/TranscriptBody/TranscriptScroll/TranscriptList
@onready var _composer_hint: Label = $Shell/Margin/Body/SplitRow/ChatColumn/ComposerCard/ComposerMargin/ComposerBody/ComposerFooter/ComposerHintLabel
@onready var _chat_model_option: OptionButton = $Shell/Margin/Body/SplitRow/ChatColumn/ComposerCard/ComposerMargin/ComposerBody/ComposerFooter/ComposerActions/QuickSettingsRow/ModelQuickGroup/ModelQuickOption
@onready var _chat_effort_option: OptionButton = $Shell/Margin/Body/SplitRow/ChatColumn/ComposerCard/ComposerMargin/ComposerBody/ComposerFooter/ComposerActions/QuickSettingsRow/EffortQuickGroup/EffortQuickOption
@onready var _chat_permission_mode: OptionButton = $Shell/Margin/Body/SplitRow/ChatColumn/ComposerCard/ComposerMargin/ComposerBody/ComposerFooter/ComposerActions/QuickSettingsRow/PermissionQuickGroup/PermissionQuickOption
@onready var _prompt_input: TextEdit = $Shell/Margin/Body/SplitRow/ChatColumn/ComposerCard/ComposerMargin/ComposerBody/PromptInput
@onready var _interrupt_button: Button = $Shell/Margin/Body/SplitRow/ChatColumn/ComposerCard/ComposerMargin/ComposerBody/ComposerFooter/ComposerActions/ActionButtons/InterruptButton
@onready var _send_button: Button = $Shell/Margin/Body/SplitRow/ChatColumn/ComposerCard/ComposerMargin/ComposerBody/ComposerFooter/ComposerActions/ActionButtons/SendButton


func _init() -> void:
	_configured_options = ClaudeAgentOptionsScript.new()
	_install_panel_stderr_callback()
	_capture_base_session_defaults()


func _ready() -> void:
	_apply_static_button_icons()
	_populate_quick_setting_choices()
	_populate_system_prompt_modes()
	_populate_built_in_tool_groups()
	_apply_initial_control_values()
	_set_current_view(PANEL_VIEW_CHAT)
	_ensure_client_node()
	_wire_ui()
	_apply_theme_overrides()
	_session_scope_directory = _resolve_session_scope_directory()
	_reload_sessions(false)
	_refresh_composer_state()
	_refresh_configuration_controls()
	refresh_auth_status()
	call_deferred("_apply_initial_split_layout")


func setup(options = null, transport = null) -> void:
	if _did_connect_once:
		_emit_error("setup() must be called before the first successful connect_client()")
		return
	_configured_options = options.duplicate_options() if options != null else ClaudeAgentOptionsScript.new()
	_configured_transport = transport
	_install_panel_stderr_callback()
	_capture_base_session_defaults()
	if is_node_ready():
		_apply_initial_control_values()
		_session_scope_directory = _resolve_session_scope_directory()
		_reload_sessions(false)
		_refresh_configuration_controls()
		_rebuild_client_node()


func connect_client() -> void:
	_start_connect()


func _start_connect(prompt = null) -> bool:
	if _session_live or _is_connecting:
		return false
	_status_issue_message = ""
	_last_cli_diagnostic_line = ""
	_apply_preconnect_controls_to_options()
	_apply_session_target_to_options()
	_rebuild_client_node()
	_authoritative_live_session_id = ""
	_live_session_target_id = _effective_connect_session_target_id()
	_clear_transcript_after_disconnect = false
	_is_connecting = true
	_clear_live_session_diagnostics()
	_update_status_from_state()
	_refresh_composer_state()
	_refresh_session_controls()
	_client_node.connect_client(prompt)

	if not _client_node.get_last_error().is_empty():
		_is_connecting = false
		_status_issue_message = _client_node.get_last_error()
		_clear_live_session_diagnostics()
		_emit_error(_client_node.get_last_error())
		_update_status_from_state()
		_refresh_composer_state()
		_refresh_session_controls()
		return false
	return true


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
		if _is_connecting:
			_emit_error("Wait for Claude to finish connecting before sending another prompt")
			return
		if not bool(_last_auth_status.get("logged_in", false)):
			_emit_error("Claude CLI must be authenticated before sending a prompt")
			return
		_begin_new_live_turn()
		_append_pending_user_prompt(trimmed)
		prompt_submitted.emit(trimmed)
		if _start_connect(trimmed):
			_prompt_input.text = ""
			_refresh_composer_state()
		else:
			_discard_pending_prompt_echo_entry()
		return
	if _client_node.is_busy():
		_emit_error("Wait for the current turn to finish before sending another prompt")
		return

	_begin_new_live_turn()
	_append_pending_user_prompt(trimmed)
	_prompt_input.text = ""
	_refresh_composer_state()
	prompt_submitted.emit(trimmed)
	_client_node.query(trimmed, _current_live_query_session_id())

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
	_transcript_entries.clear()
	_task_entry_ids.clear()
	_tool_use_names.clear()
	_pending_prompt_echo = ""
	_pending_prompt_entry_id = -1
	_rewind_pending_entry_id = -1
	_clear_transcript_views()
	_begin_new_live_turn()


func get_client_node() -> ClaudeClientNode:
	return _client_node


func _wire_ui() -> void:
	if not _refresh_auth_button.pressed.is_connected(_on_refresh_auth_pressed):
		_refresh_auth_button.pressed.connect(_on_refresh_auth_pressed)
	if not _connect_button.pressed.is_connected(_on_connect_pressed):
		_connect_button.pressed.connect(_on_connect_pressed)
	if not _disconnect_button.pressed.is_connected(_on_disconnect_pressed):
		_disconnect_button.pressed.connect(_on_disconnect_pressed)
	if not _chat_view_button.pressed.is_connected(_on_chat_view_pressed):
		_chat_view_button.pressed.connect(_on_chat_view_pressed)
	if not _settings_view_button.pressed.is_connected(_on_settings_view_pressed):
		_settings_view_button.pressed.connect(_on_settings_view_pressed)
	if not _refresh_context_usage_button.pressed.is_connected(_on_refresh_context_usage_pressed):
		_refresh_context_usage_button.pressed.connect(_on_refresh_context_usage_pressed)
	if not _refresh_mcp_status_button.pressed.is_connected(_on_refresh_mcp_status_pressed):
		_refresh_mcp_status_button.pressed.connect(_on_refresh_mcp_status_pressed)
	if not _interrupt_button.pressed.is_connected(_on_interrupt_pressed):
		_interrupt_button.pressed.connect(_on_interrupt_pressed)
	if not _send_button.pressed.is_connected(_on_send_pressed):
		_send_button.pressed.connect(_on_send_pressed)
	if not _thinking_toggle.toggled.is_connected(_on_transcript_filter_toggled):
		_thinking_toggle.toggled.connect(_on_transcript_filter_toggled)
	if not _tasks_toggle.toggled.is_connected(_on_transcript_filter_toggled):
		_tasks_toggle.toggled.connect(_on_transcript_filter_toggled)
	if not _tools_toggle.toggled.is_connected(_on_transcript_filter_toggled):
		_tools_toggle.toggled.connect(_on_transcript_filter_toggled)
	if not _results_toggle.toggled.is_connected(_on_transcript_filter_toggled):
		_results_toggle.toggled.connect(_on_transcript_filter_toggled)
	if not _system_toggle.toggled.is_connected(_on_transcript_filter_toggled):
		_system_toggle.toggled.connect(_on_transcript_filter_toggled)
	if not _raw_toggle.toggled.is_connected(_on_transcript_filter_toggled):
		_raw_toggle.toggled.connect(_on_transcript_filter_toggled)
	if not _prompt_input.text_changed.is_connected(_on_prompt_text_changed):
		_prompt_input.text_changed.connect(_on_prompt_text_changed)
	if not _chat_model_option.item_selected.is_connected(_on_model_option_selected):
		_chat_model_option.item_selected.connect(_on_model_option_selected)
	if not _chat_effort_option.item_selected.is_connected(_on_effort_option_selected):
		_chat_effort_option.item_selected.connect(_on_effort_option_selected)
	if not _chat_permission_mode.item_selected.is_connected(_on_permission_mode_selected):
		_chat_permission_mode.item_selected.connect(_on_permission_mode_selected)
	if not _system_prompt_mode.item_selected.is_connected(_on_system_prompt_mode_selected):
		_system_prompt_mode.item_selected.connect(_on_system_prompt_mode_selected)
	if not _system_prompt_text_input.text_changed.is_connected(_on_system_prompt_text_changed):
		_system_prompt_text_input.text_changed.connect(_on_system_prompt_text_changed)
	if not _system_prompt_file_input.text_changed.is_connected(_on_system_prompt_file_text_changed):
		_system_prompt_file_input.text_changed.connect(_on_system_prompt_file_text_changed)
	if not _tool_rules_advanced_toggle.toggled.is_connected(_on_tool_rules_advanced_toggled):
		_tool_rules_advanced_toggle.toggled.connect(_on_tool_rules_advanced_toggled)
	if not _allowed_tools_input.text_changed.is_connected(_on_allowed_tools_text_changed):
		_allowed_tools_input.text_changed.connect(_on_allowed_tools_text_changed)
	if not _disallowed_tools_input.text_changed.is_connected(_on_disallowed_tools_text_changed):
		_disallowed_tools_input.text_changed.connect(_on_disallowed_tools_text_changed)
	if not _rewind_support_toggle.toggled.is_connected(_on_rewind_support_toggled):
		_rewind_support_toggle.toggled.connect(_on_rewind_support_toggled)
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
	if not _fork_session_button.pressed.is_connected(_on_fork_session_pressed):
		_fork_session_button.pressed.connect(_on_fork_session_pressed)
	if not _confirm_delete_button.pressed.is_connected(_on_confirm_delete_pressed):
		_confirm_delete_button.pressed.connect(_on_confirm_delete_pressed)
	if not _cancel_delete_button.pressed.is_connected(_on_cancel_delete_pressed):
		_cancel_delete_button.pressed.connect(_on_cancel_delete_pressed)
	if not _session_title_input.text_changed.is_connected(_on_session_title_text_changed):
		_session_title_input.text_changed.connect(_on_session_title_text_changed)
	if not _session_tag_input.text_changed.is_connected(_on_session_tag_text_changed):
		_session_tag_input.text_changed.connect(_on_session_tag_text_changed)
	if not _fork_title_input.text_changed.is_connected(_on_fork_title_text_changed):
		_fork_title_input.text_changed.connect(_on_fork_title_text_changed)


func _apply_static_button_icons() -> void:
	_refresh_auth_button.icon = RefreshIcon
	_session_refresh_button.icon = RefreshIcon
	_refresh_context_usage_button.icon = RefreshIcon
	_refresh_mcp_status_button.icon = RefreshIcon
	_send_button.icon = SendIcon
	_interrupt_button.icon = InterruptIcon


func _populate_quick_setting_choices() -> void:
	if _chat_model_option.item_count == 0:
		for model_name in MODEL_PRESETS:
			_chat_model_option.add_item(model_name)
	if _chat_effort_option.item_count == 0:
		for effort_name in EFFORT_PRESETS:
			_chat_effort_option.add_item(effort_name)
	if _chat_permission_mode.item_count > 0:
		return
	for mode in ["default", "plan", "acceptEdits", "bypassPermissions"]:
		_chat_permission_mode.add_item(mode)


func _populate_system_prompt_modes() -> void:
	if _system_prompt_mode.item_count > 0:
		return
	_system_prompt_mode.add_item("Vanilla Claude")
	_system_prompt_mode.add_item("Custom text")
	_system_prompt_mode.add_item("Claude Code preset")
	_system_prompt_mode.add_item("Preset + append")
	_system_prompt_mode.add_item("Prompt file")


func _populate_built_in_tool_groups() -> void:
	if _built_in_tool_groups.get_child_count() > 0:
		return
	_built_in_tool_checks.clear()
	_built_in_tool_group_buttons.clear()
	for group in ClaudeBuiltInToolCatalog.list_groups():
		var group_id := str(group.get("id", ""))
		var group_id_pascal := group_id.capitalize()
		var panel := PanelContainer.new()
		panel.name = "BuiltInToolGroup%s" % group_id_pascal
		panel.size_flags_horizontal = SIZE_EXPAND_FILL

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		panel.add_child(margin)

		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 8)
		margin.add_child(body)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 6)
		body.add_child(header)

		var title := Label.new()
		title.text = str(group.get("label", ""))
		title.size_flags_horizontal = SIZE_EXPAND_FILL
		header.add_child(title)

		var enable_button := Button.new()
		enable_button.name = "BuiltInToolGroup%sAllButton" % group_id_pascal
		enable_button.text = "All"
		enable_button.pressed.connect(_on_tool_group_enable_all_pressed.bind(group_id))
		header.add_child(enable_button)

		var disable_button := Button.new()
		disable_button.name = "BuiltInToolGroup%sNoneButton" % group_id_pascal
		disable_button.text = "None"
		disable_button.pressed.connect(_on_tool_group_disable_all_pressed.bind(group_id))
		header.add_child(disable_button)
		_built_in_tool_group_buttons[group_id] = {
			"all": enable_button,
			"none": disable_button,
		}

		var description := Label.new()
		description.text = str(group.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.modulate = COLOR_MUTED
		body.add_child(description)

		for tool_name_variant in (group.get("tools", []) as Array):
			var tool_name := str(tool_name_variant)
			var metadata := (ClaudeBuiltInToolCatalog.list_tool_metadata()).get(tool_name, {})
			var checkbox := CheckBox.new()
			checkbox.name = "BuiltInToolCheck_%s" % tool_name
			checkbox.text = str(metadata.get("label", tool_name))
			checkbox.tooltip_text = str(metadata.get("description", ""))
			checkbox.toggled.connect(_on_built_in_tool_toggled.bind(tool_name))
			body.add_child(checkbox)
			_built_in_tool_checks[tool_name] = checkbox

		_built_in_tool_groups.add_child(panel)


func _apply_initial_control_values() -> void:
	if _configured_options == null:
		_configured_options = ClaudeAgentOptionsScript.new()
		_install_panel_stderr_callback()
	if _configured_options.model.is_empty():
		_configured_options.model = MODEL_PRESETS[0]
	if _configured_options.effort.is_empty():
		_configured_options.effort = EFFORT_PRESETS[0]
	_capture_base_session_defaults()
	_suppress_configuration_sync = true
	_select_chat_model_value(_configured_options.model)
	_select_chat_effort_value(_configured_options.effort)
	_select_permission_mode(_configured_options.permission_mode if not _configured_options.permission_mode.is_empty() else "default")
	_apply_system_prompt_controls_from_options()
	_apply_built_in_tool_controls_from_options()
	_allowed_tools_input.text = ",".join(_configured_options.allowed_tools)
	_disallowed_tools_input.text = ",".join(_configured_options.disallowed_tools)
	_rewind_support_toggle.set_pressed_no_signal(_panel_rewind_support_enabled())
	var has_advanced_rules: bool = not _configured_options.allowed_tools.is_empty() or not _configured_options.disallowed_tools.is_empty()
	_tool_rules_advanced_toggle.set_pressed_no_signal(has_advanced_rules)
	_refresh_mcp_summary()
	_refresh_configuration_field_visibility()
	_refresh_live_session_diagnostics()
	_suppress_configuration_sync = false


func _apply_system_prompt_controls_from_options() -> void:
	var system_prompt: Variant = _configured_options.system_prompt
	_system_prompt_text_input.text = ""
	_system_prompt_file_input.text = ""
	if system_prompt is Dictionary:
		var prompt_config := system_prompt as Dictionary
		var prompt_type := str(prompt_config.get("type", ""))
		if prompt_type == "preset":
			var append_text := str(prompt_config.get("append", ""))
			if append_text.is_empty():
				_system_prompt_mode.select(SYSTEM_PROMPT_MODE_PRESET)
			else:
				_system_prompt_mode.select(SYSTEM_PROMPT_MODE_PRESET_APPEND)
				_system_prompt_text_input.text = append_text
			return
		if prompt_type == "file":
			_system_prompt_mode.select(SYSTEM_PROMPT_MODE_FILE)
			_system_prompt_file_input.text = str(prompt_config.get("path", ""))
			return
	_system_prompt_mode.select(
		SYSTEM_PROMPT_MODE_VANILLA if str(system_prompt).is_empty() else SYSTEM_PROMPT_MODE_TEXT
	)
	if not str(system_prompt).is_empty():
		_system_prompt_text_input.text = str(system_prompt)


func _apply_built_in_tool_controls_from_options() -> void:
	var selected_tools := ClaudeBuiltInToolCatalog.selection_from_tools_config(_configured_options.tools)
	var selected_lookup := {}
	for tool_name in selected_tools:
		selected_lookup[tool_name] = true
	for tool_name in _built_in_tool_checks.keys():
		var checkbox := _built_in_tool_checks[tool_name] as CheckBox
		checkbox.set_pressed_no_signal(selected_lookup.has(tool_name))
	_refresh_built_in_tools_summary()
	_refresh_built_in_tool_group_buttons()


func _capture_base_session_defaults() -> void:
	_base_resume = _configured_options.resume if _configured_options != null else ""
	_base_session_id = _configured_options.session_id if _configured_options != null else ""
	_live_session_target_id = _effective_connect_session_target_id()


func _install_panel_stderr_callback() -> void:
	if _configured_options == null:
		return
	_forwarded_stderr_callback = _configured_options.stderr
	_configured_options.stderr = Callable(self, "_handle_cli_stderr_line")


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
	_configured_options.system_prompt = _system_prompt_from_controls()
	_configured_options.tools = _built_in_tools_from_controls()
	_configured_options.allowed_tools = _parse_tool_csv(_allowed_tools_input.text)
	_configured_options.disallowed_tools = _parse_tool_csv(_disallowed_tools_input.text)
	_sync_rewind_support_to_options()


func _apply_session_target_to_options() -> void:
	if _has_selected_session():
		_configured_options.resume = _selected_session_id
		_configured_options.session_id = _base_session_id
	else:
		_configured_options.resume = _base_resume
		_configured_options.session_id = _base_session_id


func _effective_connect_session_target_id() -> String:
	if _has_selected_session():
		return _selected_session_id
	if not _base_resume.is_empty():
		return _base_resume
	if not _base_session_id.is_empty():
		return _base_session_id
	return "default"


func _current_live_query_session_id() -> String:
	if not _authoritative_live_session_id.is_empty():
		return _authoritative_live_session_id
	if not _live_session_target_id.is_empty():
		return _live_session_target_id
	return "default"


func _active_session_reference_id() -> String:
	var current_session_id := _current_live_query_session_id()
	if current_session_id != "default":
		return current_session_id
	if not _live_session_target_id.is_empty() and _live_session_target_id != "default":
		return _live_session_target_id
	return current_session_id


func _resolve_session_scope_directory() -> String:
	if _configured_options != null and not _configured_options.cwd.is_empty():
		return _configured_options.cwd
	return ProjectSettings.globalize_path("res://")


func _set_current_view(view: int) -> void:
	_current_view = view
	_chat_view_button.set_pressed_no_signal(view == PANEL_VIEW_CHAT)
	_settings_view_button.set_pressed_no_signal(view == PANEL_VIEW_SETTINGS)
	_split_row.visible = view == PANEL_VIEW_CHAT
	_settings_scroll.visible = view == PANEL_VIEW_SETTINGS


func _refresh_configuration_controls() -> void:
	var configuration_locked := _session_live or _is_connecting
	_chat_model_option.disabled = _is_connecting
	_chat_permission_mode.disabled = _is_connecting
	_chat_effort_option.disabled = configuration_locked
	_chat_effort_option.tooltip_text = "Reasoning effort applies on the next reconnect." if configuration_locked else ""
	_system_prompt_mode.disabled = configuration_locked
	_system_prompt_text_input.editable = not configuration_locked and _system_prompt_text_group.visible
	_system_prompt_file_input.editable = not configuration_locked and _system_prompt_file_group.visible
	_tool_rules_advanced_toggle.disabled = configuration_locked
	_allowed_tools_input.editable = not configuration_locked and _tool_rules_advanced_body.visible
	_disallowed_tools_input.editable = not configuration_locked and _tool_rules_advanced_body.visible
	_rewind_support_toggle.disabled = configuration_locked
	_refresh_built_in_tool_picker_state()
	_refresh_live_session_diagnostics()


func _refresh_configuration_field_visibility() -> void:
	var prompt_mode := _system_prompt_mode.selected
	_system_prompt_text_group.visible = prompt_mode == SYSTEM_PROMPT_MODE_TEXT or prompt_mode == SYSTEM_PROMPT_MODE_PRESET_APPEND
	_system_prompt_file_group.visible = prompt_mode == SYSTEM_PROMPT_MODE_FILE
	if prompt_mode == SYSTEM_PROMPT_MODE_PRESET_APPEND:
		_system_prompt_text_label.text = "Preset append text"
		_system_prompt_text_input.placeholder_text = "Always speak like a ship AI."
	else:
		_system_prompt_text_label.text = "Prompt text"
		_system_prompt_text_input.placeholder_text = "You are a level-design assistant."
	_tool_rules_advanced_body.visible = _tool_rules_advanced_toggle.button_pressed
	_tool_rules_advanced_toggle.text = "Hide advanced tool rules" if _tool_rules_advanced_toggle.button_pressed else "Advanced tool rules"
	_refresh_configuration_controls()


func _refresh_mcp_summary() -> void:
	var summary := "No MCP servers configured."
	if _configured_options != null:
		if _configured_options.mcp_servers is Dictionary and not (_configured_options.mcp_servers as Dictionary).is_empty():
			var server_names: Array[String] = []
			for server_name_variant in (_configured_options.mcp_servers as Dictionary).keys():
				server_names.append(str(server_name_variant))
			server_names.sort()
			summary = "%d configured: %s" % [server_names.size(), ", ".join(server_names)]
		elif _configured_options.mcp_servers is String and not str(_configured_options.mcp_servers).strip_edges().is_empty():
			summary = "External MCP config: %s" % str(_configured_options.mcp_servers).strip_edges()
	_mcp_summary_value.text = summary


func _refresh_live_session_diagnostics() -> void:
	_live_session_section.visible = _session_live or _is_connecting
	var context_refresh_locked := (not _session_live) or _context_usage_refresh_pending
	_refresh_context_usage_button.disabled = context_refresh_locked
	_refresh_context_usage_button.text = "Refreshing" if _context_usage_refresh_pending else "Refresh"
	if not _session_live:
		_live_context_summary_value.text = "Waiting for a connected session." if _is_connecting else "Connect to inspect live context usage."
		_live_context_detail_value.text = ""
	elif _live_context_usage.is_empty():
		_live_context_summary_value.text = _live_context_usage_error if not _live_context_usage_error.is_empty() else "Refresh to inspect live context usage."
		_live_context_detail_value.text = ""
	else:
		_live_context_summary_value.text = _context_usage_summary_text(_live_context_usage)
		_live_context_detail_value.text = _context_usage_detail_text(_live_context_usage)

	var mcp_refresh_locked := (not _session_live) or _mcp_status_refresh_pending
	_refresh_mcp_status_button.disabled = mcp_refresh_locked
	_refresh_mcp_status_button.text = "Refreshing" if _mcp_status_refresh_pending else "Refresh"
	if not _session_live:
		_live_mcp_summary_value.text = "Waiting for a connected session." if _is_connecting else "Connect to inspect live MCP server status."
	else:
		_live_mcp_summary_value.text = _mcp_status_summary_text(_live_mcp_status, _live_mcp_status_error)
	_rebuild_live_mcp_server_rows()


func _clear_live_session_diagnostics() -> void:
	_live_context_usage.clear()
	_live_context_usage_error = ""
	_context_usage_refresh_pending = false
	_live_mcp_status.clear()
	_live_mcp_status_error = ""
	_mcp_status_refresh_pending = false
	_mcp_server_action_pending.clear()
	_refresh_live_session_diagnostics()


func _context_usage_summary_text(usage: Dictionary) -> String:
	if usage.is_empty():
		return "Refresh to inspect live context usage."
	var percentage := str(usage.get("percentage", ""))
	var total_tokens := str(usage.get("totalTokens", ""))
	var max_tokens := str(usage.get("maxTokens", ""))
	var model := str(usage.get("model", "")).strip_edges()
	var parts: Array[String] = []
	if not percentage.is_empty():
		parts.append("%s%% used" % percentage)
	if not total_tokens.is_empty() and not max_tokens.is_empty():
		parts.append("%s / %s tokens" % [total_tokens, max_tokens])
	elif not total_tokens.is_empty():
		parts.append("%s tokens" % total_tokens)
	if not model.is_empty():
		parts.append(model)
	return " · ".join(parts)


func _context_usage_detail_text(usage: Dictionary) -> String:
	var parts: Array[String] = []
	var categories := usage.get("categories", []) as Array
	if not categories.is_empty():
		var category_parts: Array[String] = []
		for category_variant in categories:
			if not (category_variant is Dictionary):
				continue
			var category := category_variant as Dictionary
			category_parts.append("%s %s" % [str(category.get("name", "")), str(category.get("tokens", ""))])
			if category_parts.size() >= 3:
				break
		if not category_parts.is_empty():
			parts.append("Top categories: %s" % " · ".join(category_parts))
	var memory_files := usage.get("memoryFiles", []) as Array
	if not memory_files.is_empty():
		parts.append("%d memory file%s" % [memory_files.size(), "" if memory_files.size() == 1 else "s"])
	var mcp_tools := usage.get("mcpTools", []) as Array
	if not mcp_tools.is_empty():
		parts.append("%d MCP tool%s loaded" % [mcp_tools.size(), "" if mcp_tools.size() == 1 else "s"])
	var agents := usage.get("agents", []) as Array
	if not agents.is_empty():
		parts.append("%d agent definition%s" % [agents.size(), "" if agents.size() == 1 else "s"])
	return " · ".join(parts)


func _mcp_status_summary_text(status: Dictionary, error_message: String = "") -> String:
	if not error_message.is_empty():
		return error_message
	var servers := status.get("mcpServers", []) as Array
	if servers.is_empty():
		return "No live MCP servers reported for this session."
	var counts: Dictionary = {}
	for server_variant in servers:
		if not (server_variant is Dictionary):
			continue
		var state := str((server_variant as Dictionary).get("status", "unknown"))
		counts[state] = int(counts.get(state, 0)) + 1
	var parts: Array[String] = ["%d server%s" % [servers.size(), "" if servers.size() == 1 else "s"]]
	for state in ["connected", "failed", "needs-auth", "pending", "disabled"]:
		if int(counts.get(state, 0)) > 0:
			parts.append("%d %s" % [int(counts.get(state, 0)), state])
	return " · ".join(parts)


func _rebuild_live_mcp_server_rows() -> void:
	for child in _live_mcp_server_list.get_children():
		child.queue_free()
	if not _session_live:
		return
	var servers := _live_mcp_status.get("mcpServers", []) as Array
	if servers.is_empty():
		return
	for server_variant in servers:
		if not (server_variant is Dictionary):
			continue
		var server := server_variant as Dictionary
		var server_name := str(server.get("name", "")).strip_edges()
		if server_name.is_empty():
			continue
		var row := _build_mcp_server_row(server_name, server)
		_live_mcp_server_list.add_child(row)


func _build_mcp_server_row(server_name: String, server: Dictionary) -> Control:
	var row_name := _mcp_server_node_name(server_name)
	var card := PanelContainer.new()
	card.name = "McpServerRow_%s" % row_name
	card.size_flags_horizontal = SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)

	var title := Label.new()
	title.name = "McpServerTitle_%s" % row_name
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.text = "%s · %s" % [server_name, str(server.get("status", "unknown")).capitalize()]
	header.add_child(title)

	var reconnect_button := Button.new()
	reconnect_button.name = "McpReconnectButton_%s" % row_name
	reconnect_button.text = _mcp_server_action_text(server_name, "reconnect")
	reconnect_button.visible = _should_show_mcp_reconnect_button(server)
	reconnect_button.disabled = reconnect_button.text != "Reconnect"
	reconnect_button.pressed.connect(_on_mcp_server_reconnect_pressed.bind(server_name))
	header.add_child(reconnect_button)

	var toggle_button := Button.new()
	toggle_button.name = "McpToggleButton_%s" % row_name
	var toggle_target_enabled := _mcp_server_toggle_target(server)
	toggle_button.text = _mcp_server_action_text(server_name, "toggle", toggle_target_enabled)
	toggle_button.disabled = not _session_live or toggle_button.text == "Working"
	toggle_button.pressed.connect(_on_mcp_server_toggle_pressed.bind(server_name, toggle_target_enabled))
	header.add_child(toggle_button)

	var detail := Label.new()
	detail.name = "McpServerDetail_%s" % row_name
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.modulate = COLOR_MUTED
	detail.text = _mcp_server_detail_text(server)
	body.add_child(detail)

	return card


func _mcp_server_detail_text(server: Dictionary) -> String:
	var parts: Array[String] = []
	var scope := str(server.get("scope", "")).strip_edges()
	if not scope.is_empty():
		parts.append("Scope: %s" % scope)
	var tools := server.get("tools", []) as Array
	if not tools.is_empty():
		parts.append("%d tool%s" % [tools.size(), "" if tools.size() == 1 else "s"])
	var config := server.get("config", {}) as Dictionary
	var config_type := str(config.get("type", "")).strip_edges()
	if not config_type.is_empty():
		parts.append("Type: %s" % config_type)
	var error_text := str(server.get("error", "")).strip_edges()
	if not error_text.is_empty():
		parts.append(error_text)
	return " · ".join(parts)


func _mcp_server_toggle_target(server: Dictionary) -> bool:
	return str(server.get("status", "")).strip_edges().to_lower() == "disabled"


func _should_show_mcp_reconnect_button(server: Dictionary) -> bool:
	var status := str(server.get("status", "")).strip_edges().to_lower()
	return status == "failed" or status == "needs-auth" or status == "pending"


func _mcp_server_action_text(server_name: String, action: String, enable_target := false) -> String:
	if str(_mcp_server_action_pending.get(server_name, "")) == action:
		return "Working"
	if action == "toggle":
		return "Enable" if enable_target else "Disable"
	return "Reconnect"


func _mcp_server_node_name(server_name: String) -> String:
	var normalized := server_name.strip_edges()
	var result := ""
	for index in range(normalized.length()):
		var letter := normalized.substr(index, 1)
		var code := letter.unicode_at(0)
		var is_letter := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var is_digit := code >= 48 and code <= 57
		result += letter if is_letter or is_digit else "_"
	return result if not result.is_empty() else "server"


func _panel_rewind_support_enabled() -> bool:
	if _configured_options == null:
		return false
	return _configured_options.enable_file_checkpointing or _configured_options.extra_args.has("replay-user-messages")


func _sync_rewind_support_to_options() -> void:
	if _configured_options == null:
		return
	var enabled := _rewind_support_toggle.button_pressed
	_configured_options.enable_file_checkpointing = enabled
	var extra_args: Dictionary = _configured_options.extra_args.duplicate(true)
	if enabled:
		extra_args["replay-user-messages"] = null
	else:
		extra_args.erase("replay-user-messages")
	_configured_options.extra_args = extra_args


func _system_prompt_summary(system_prompt: Variant) -> String:
	if system_prompt is Dictionary:
		var prompt_config := system_prompt as Dictionary
		match str(prompt_config.get("type", "")):
			"preset":
				return "Claude Code preset + append" if not str(prompt_config.get("append", "")).is_empty() else "Claude Code preset"
			"file":
				var path := str(prompt_config.get("path", ""))
				return "Prompt file · %s" % path if not path.is_empty() else "Prompt file"
	if not str(system_prompt).is_empty():
		return "Custom text"
	return "Vanilla Claude"


func _sync_configuration_from_controls() -> void:
	if _suppress_configuration_sync or _configured_options == null:
		return
	_apply_preconnect_controls_to_options()
	_capture_base_session_defaults()
	_refresh_built_in_tools_summary()
	_refresh_built_in_tool_group_buttons()
	_refresh_configuration_field_visibility()
	_refresh_mcp_summary()


func _system_prompt_from_controls() -> Variant:
	match _system_prompt_mode.selected:
		SYSTEM_PROMPT_MODE_TEXT:
			return _system_prompt_text_input.text
		SYSTEM_PROMPT_MODE_PRESET:
			return {"type": "preset", "preset": "claude_code"}
		SYSTEM_PROMPT_MODE_PRESET_APPEND:
			var append_text := _system_prompt_text_input.text
			if append_text.strip_edges().is_empty():
				return {"type": "preset", "preset": "claude_code"}
			return {"type": "preset", "preset": "claude_code", "append": append_text}
		SYSTEM_PROMPT_MODE_FILE:
			var path := _system_prompt_file_input.text.strip_edges()
			return "" if path.is_empty() else {"type": "file", "path": path}
		_:
			return ""


func _built_in_tools_from_controls() -> Variant:
	return ClaudeBuiltInToolCatalog.tools_config_from_selection(_selected_built_in_tools())


func _parse_tool_csv(value: String) -> Array[String]:
	var results: Array[String] = []
	for part in value.split(","):
		var normalized := part.strip_edges()
		if not normalized.is_empty():
			results.append(normalized)
	return results


func _selected_built_in_tools() -> Array[String]:
	var selected: Array[String] = []
	for tool_name in ClaudeBuiltInToolCatalog.list_default_tools():
		var checkbox := _built_in_tool_checks.get(tool_name, null) as CheckBox
		if checkbox != null and checkbox.button_pressed:
			selected.append(tool_name)
	return selected


func _refresh_built_in_tools_summary() -> void:
	var selected_count := _selected_built_in_tools().size()
	var total_count := ClaudeBuiltInToolCatalog.list_default_tools().size()
	if selected_count == 0:
		_built_in_tools_summary.text = "No built-in tools enabled."
	elif selected_count == total_count:
		_built_in_tools_summary.text = "All default built-in tools enabled."
	else:
		_built_in_tools_summary.text = "%d of %d built-in tools enabled." % [selected_count, total_count]


func _refresh_built_in_tool_group_buttons() -> void:
	var locked := _session_live or _is_connecting
	var selected_lookup := {}
	for tool_name in _selected_built_in_tools():
		selected_lookup[tool_name] = true
	for group in ClaudeBuiltInToolCatalog.list_groups():
		var group_id := str(group.get("id", ""))
		var buttons := _built_in_tool_group_buttons.get(group_id, {}) as Dictionary
		var all_button := buttons.get("all", null) as Button
		var none_button := buttons.get("none", null) as Button
		var group_tools: Array = group.get("tools", [])
		var enabled_count := 0
		for tool_name_variant in group_tools:
			if selected_lookup.has(str(tool_name_variant)):
				enabled_count += 1
		if all_button != null:
			all_button.disabled = locked or enabled_count == group_tools.size()
		if none_button != null:
			none_button.disabled = locked or enabled_count == 0


func _refresh_built_in_tool_picker_state() -> void:
	var locked := _session_live or _is_connecting
	for checkbox_variant in _built_in_tool_checks.values():
		var checkbox := checkbox_variant as CheckBox
		checkbox.disabled = locked
	_refresh_built_in_tool_group_buttons()


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
	var was_live := _session_live
	var prior_selected_id := _selected_session_id
	_selected_session_id = info.session_id
	_selected_session_info = info
	_delete_confirm_armed = false
	_session_list.select(index)
	_refresh_selected_session_fields()
	if was_live:
		var active_session_id := _active_session_reference_id()
		if prior_selected_id == info.session_id and active_session_id == info.session_id:
			_refresh_selected_session_metadata()
			_refresh_session_controls()
			_update_status_from_state()
			_refresh_composer_state()
			_refresh_transcript_entry_views_visibility()
			return
		_client_node.disconnect_client()
		return
	if _can_switch_sessions():
		_reload_selected_session_transcript()
	else:
		_refresh_selected_session_metadata()
	_refresh_session_controls()
	_update_status_from_state()
	_refresh_composer_state()
	_refresh_transcript_entry_views_visibility()


func _clear_selected_session(clear_transcript_too: bool) -> void:
	_selected_session_id = ""
	_selected_session_info = null
	_selected_session_messages.clear()
	_selected_session_transcript.clear()
	_delete_confirm_armed = false
	_live_session_target_id = _effective_connect_session_target_id()
	_session_list.deselect_all()
	_refresh_selected_session_fields()
	if clear_transcript_too:
		clear_transcript()
	_refresh_selected_session_metadata()
	_refresh_session_controls()
	_update_status_from_state()
	_refresh_composer_state()
	_refresh_transcript_entry_views_visibility()


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
	_selected_session_transcript = _client_node.get_session_transcript(_selected_session_id, _selected_session_directory())
	_render_selected_session_transcript()
	_refresh_selected_session_metadata()


func _render_selected_session_transcript() -> void:
	clear_transcript()
	for entry in _selected_session_transcript:
		_append_saved_transcript_entry(entry)


func _session_list_label(info: ClaudeSessionInfo) -> String:
	var label := info.summary
	if info.tag != null and not str(info.tag).is_empty():
		label += "  #%s" % str(info.tag)
	return "%s\n%s" % [label, _format_timestamp(info.last_modified)]


func _refresh_selected_session_fields() -> void:
	if _selected_session_info == null:
		_session_title_input.text = ""
		_session_tag_input.text = ""
		_fork_title_input.text = ""
		return
	_session_title_input.text = str(
		_selected_session_info.custom_title if _selected_session_info.custom_title != null else _selected_session_info.summary
	)
	_session_tag_input.text = str(_selected_session_info.tag) if _selected_session_info.tag != null else ""
	_fork_title_input.text = ""


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
	_fork_title_input.editable = has_selection and not mutations_locked
	_rename_session_button.disabled = not has_selection or mutations_locked or _session_title_input.text.strip_edges().is_empty()
	_apply_tag_button.disabled = not has_selection or mutations_locked or _session_tag_input.text.strip_edges().is_empty()
	_clear_tag_button.disabled = not has_selection or mutations_locked or _selected_session_info == null or _selected_session_info.tag == null or str(_selected_session_info.tag).is_empty()
	_delete_session_button.disabled = not has_selection or mutations_locked
	_fork_session_button.disabled = not has_selection or mutations_locked
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
	_authoritative_live_session_id = ""
	_live_session_target_id = _effective_connect_session_target_id()
	_pending_prompt_echo = ""
	_pending_prompt_entry_id = -1
	_rewind_pending_entry_id = -1
	_clear_live_session_diagnostics()
	_begin_new_live_turn()
	if _has_selected_session():
		_reload_selected_session_transcript()
	elif _clear_transcript_after_disconnect:
		clear_transcript()
	_clear_transcript_after_disconnect = false
	_update_status_from_state()
	_refresh_composer_state()
	_refresh_session_controls()
	_refresh_transcript_entry_views_visibility()


func _on_client_session_ready(server_info: Dictionary) -> void:
	_did_connect_once = true
	_session_live = true
	_is_connecting = false
	_status_issue_message = ""
	_update_status_from_state(server_info)
	_refresh_composer_state()
	_refresh_session_controls()
	_refresh_transcript_entry_views_visibility()
	Callable(self, "_refresh_live_session_diagnostics_after_connect").call_deferred()


func _on_client_busy_changed(_is_busy: bool) -> void:
	_update_status_from_state()
	_refresh_composer_state()
	_refresh_session_controls()
	_refresh_transcript_entry_views_visibility()


func _on_client_message_received(message: Variant) -> void:
	_note_runtime_session_id(_message_session_id(message))
	message_received.emit(message)
	if message is ClaudeRateLimitEvent:
		_handle_rate_limit_event(message)
		return
	if message is ClaudeTaskStartedMessage:
		_handle_task_started_message(message)
		return
	if message is ClaudeTaskProgressMessage:
		_handle_task_progress_message(message)
		return
	if message is ClaudeTaskNotificationMessage:
		_handle_task_notification_message(message)
		return
	if message is ClaudeSystemMessage:
		if message.subtype != "init":
			_append_transcript_entry("system", {
				"title": "System · %s" % message.subtype.capitalize(),
				"text": _json_pretty(message.raw_data),
				"raw_data": message.raw_data,
				"collapsed": false,
			})
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
	_note_runtime_session_id(result_message.session_id)
	_begin_new_live_turn()
	Callable(self, "_refresh_context_usage_async").call_deferred()
	turn_finished.emit(result_message)


func _on_client_error_occurred(message: String) -> void:
	_is_connecting = false
	if not _session_live:
		_discard_pending_prompt_echo_entry()
	else:
		_pending_prompt_echo = ""
		_pending_prompt_entry_id = -1
	_rewind_pending_entry_id = -1
	_last_error = message
	if not _session_live:
		_clear_live_session_diagnostics()
	if not _session_live:
		_status_issue_message = message
	_update_status_from_state()
	_refresh_composer_state()
	_refresh_session_controls()
	_refresh_transcript_entry_views_visibility()
	error_occurred.emit(message)


func _on_client_session_closed() -> void:
	_restore_disconnected_view()


func _handle_user_message(message: ClaudeUserMessage) -> void:
	var is_tool_linked := not message.parent_tool_use_id.is_empty()
	var has_recognized_blocks := false
	var content_text := ""
	var session_id := _normalize_transcript_session_id(str(message.raw_data.get("session_id", "")))
	if message.content is String:
		content_text = str(message.content).strip_edges()
	elif message.content is Array:
		content_text = _user_message_text(message.content)
		for block in message.content:
			if block is ClaudeTextBlock:
				has_recognized_blocks = true
				continue
			if block is ClaudeToolUseBlock or block is ClaudeToolResultBlock:
				has_recognized_blocks = true
				_render_user_detail_block(block, message.raw_data)

	var suppressed_echo := false
	if not is_tool_linked and not _pending_prompt_echo.is_empty() and content_text == _pending_prompt_echo:
		_pending_prompt_echo = ""
		_attach_user_message_metadata_to_echo(message.content, content_text, message.uuid, session_id, message.raw_data)
		suppressed_echo = true

	if suppressed_echo:
		return

	if not content_text.is_empty() and not suppressed_echo and not is_tool_linked:
		_append_transcript_entry("user", {
			"title": "You",
			"text": content_text,
			"align_right": true,
			"payload": message.content,
			"raw_data": message.raw_data,
			"uuid": message.uuid,
			"session_id": session_id,
		})
		return

	if not content_text.is_empty() and is_tool_linked:
		_append_transcript_entry("tool_prompt", {
			"title": _tool_prompt_title(message.parent_tool_use_id),
			"text": content_text,
			"payload": message.content,
			"raw_data": message.raw_data,
			"parent_tool_use_id": message.parent_tool_use_id,
		})
		if has_recognized_blocks:
			return
		return

	if has_recognized_blocks:
		return

	var fallback_text := _json_pretty(message.raw_data)
	_append_transcript_entry("user", {
		"title": "You",
		"text": fallback_text,
		"align_right": true,
		"payload": message.content,
		"raw_data": message.raw_data,
		"uuid": message.uuid,
		"session_id": session_id,
	})


func _attach_user_message_metadata_to_echo(payload: Variant, text: String, uuid: String, session_id: String, raw_data: Variant) -> void:
	var entry_id := _pending_prompt_entry_id
	if entry_id < 0:
		entry_id = _find_latest_echoed_user_entry(text)
	if entry_id < 0:
		return
	var entry := _get_transcript_entry(entry_id)
	if entry.is_empty():
		return
	entry["uuid"] = uuid
	entry["session_id"] = session_id
	entry["payload"] = payload
	entry["raw_data"] = raw_data
	_pending_prompt_entry_id = -1
	_set_transcript_entry(entry_id, entry)


func _find_latest_echoed_user_entry(text: String) -> int:
	for index in range(_transcript_entries.size() - 1, -1, -1):
		var entry := _transcript_entries[index]
		if str(entry.get("kind", "")) != "user":
			continue
		if not str(entry.get("uuid", "")).is_empty():
			continue
		if str(entry.get("text", "")) != text:
			continue
		return int(entry.get("id", -1))
	return -1


func _handle_assistant_message(message: ClaudeAssistantMessage) -> void:
	var assistant_text := _assistant_text(message)
	if not assistant_text.is_empty():
		_upsert_live_assistant_entry(assistant_text, message.raw_data)
	for block in message.content:
		if block is ClaudeTextBlock:
			continue
		_render_assistant_detail_block(block, message.raw_data)


func _handle_stream_event(message: ClaudeStreamEvent) -> void:
	var text_delta := _extract_stream_text(message.event)
	if not text_delta.is_empty():
		_append_live_assistant_delta(text_delta, message.raw_data)
	var thinking_delta := _extract_stream_thinking(message.event)
	if not thinking_delta.is_empty():
		_append_or_merge_thinking_entry(thinking_delta, message.raw_data)
	if text_delta.is_empty() and thinking_delta.is_empty():
		return


func _handle_result_message(message: ClaudeResultMessage) -> void:
	_note_runtime_session_id(message.session_id)
	_append_transcript_entry("result", {
		"title": "Result · %s" % ("Error" if message.is_error else "Success"),
		"text": message.result,
		"payload": message,
		"raw_data": message.raw_data,
		"show_result": _should_render_result_card(message),
		"show_result_text": _should_render_result_text(message),
	})
	_update_status_from_state()
	_refresh_composer_state()


func _handle_rate_limit_event(message: ClaudeRateLimitEvent) -> void:
	_append_transcript_entry("system", {
		"title": "System · Rate limit",
		"text": _rate_limit_event_text(message),
		"raw_data": message.raw_data,
	})


func _handle_task_started_message(message: ClaudeTaskStartedMessage) -> void:
	_upsert_task_entry(message.task_id, {
		"text": message.description,
		"task_status": "running",
		"task_type": message.task_type,
		"task_active": true,
		"stop_pending": false,
		"output_file": "",
		"last_tool_name": "",
		"task_usage": {},
		"tool_use_id": message.tool_use_id,
		"raw_data": message.raw_data,
	})


func _handle_task_progress_message(message: ClaudeTaskProgressMessage) -> void:
	var existing := _get_task_entry_by_task_id(message.task_id)
	var description := message.description if not message.description.strip_edges().is_empty() else str(existing.get("text", ""))
	_upsert_task_entry(message.task_id, {
		"text": description,
		"task_status": "running",
		"task_active": true,
		"stop_pending": bool(existing.get("stop_pending", false)),
		"last_tool_name": message.last_tool_name,
		"task_usage": message.usage,
		"tool_use_id": message.tool_use_id if not message.tool_use_id.is_empty() else str(existing.get("tool_use_id", "")),
		"raw_data": message.raw_data,
	})


func _handle_task_notification_message(message: ClaudeTaskNotificationMessage) -> void:
	var existing := _get_task_entry_by_task_id(message.task_id)
	var summary := message.summary if not message.summary.strip_edges().is_empty() else str(existing.get("text", ""))
	var status := message.status.strip_edges().to_lower()
	_upsert_task_entry(message.task_id, {
		"text": summary,
		"task_status": status,
		"task_active": not _is_terminal_task_status(status),
		"stop_pending": false,
		"output_file": message.output_file,
		"task_usage": message.usage,
		"tool_use_id": message.tool_use_id if not message.tool_use_id.is_empty() else str(existing.get("tool_use_id", "")),
		"raw_data": message.raw_data,
	})


func _render_assistant_detail_block(block: Variant, raw_data: Variant = null) -> void:
	if block is ClaudeThinkingBlock:
		_append_or_merge_thinking_entry(str(block.thinking), block.raw_data if block.raw_data != null else raw_data)
	elif block is ClaudeToolUseBlock:
		_append_tool_use_entry(block, raw_data)
	elif block is ClaudeToolResultBlock:
		_append_tool_result_entry(block, raw_data)


func _render_user_detail_block(block: Variant, raw_data: Variant = null) -> void:
	if block is ClaudeToolUseBlock:
		_append_tool_use_entry(block, raw_data)
	elif block is ClaudeToolResultBlock:
		_append_tool_result_entry(block, raw_data)


func _append_tool_use_entry(block: ClaudeToolUseBlock, raw_data: Variant = null) -> void:
	_tool_use_names[block.id] = block.name
	_append_transcript_entry("tool_use", {
		"title": "Tool use · %s" % block.name,
		"text": _json_pretty(block.input),
		"payload": block.input,
		"raw_data": block.raw_data if block.raw_data != null else raw_data,
		"tool_use_id": block.id,
	})


func _append_tool_result_entry(block: ClaudeToolResultBlock, raw_data: Variant = null) -> void:
	var title := "Tool result"
	if block.is_error:
		title += " · error"
	_append_transcript_entry("tool_result", {
		"title": title,
		"text": _json_pretty(block.content),
		"payload": block.content,
		"raw_data": block.raw_data if block.raw_data != null else raw_data,
	})


func _append_saved_transcript_entry(entry: ClaudeSessionTranscriptEntry) -> void:
	match entry.kind:
		"user":
			_append_transcript_entry("user", {
				"title": entry.title if not entry.title.is_empty() else "You",
				"text": entry.text,
				"align_right": true,
				"payload": entry.payload,
				"raw_data": entry.raw_data,
				"uuid": entry.uuid,
				"session_id": entry.session_id,
			})
		"assistant":
			_append_transcript_entry("assistant", {
				"title": entry.title if not entry.title.is_empty() else "Claude",
				"text": entry.text,
				"align_right": false,
				"payload": entry.payload,
				"raw_data": entry.raw_data,
				"uuid": entry.uuid,
				"session_id": entry.session_id,
			})
		"thinking", "tool_use", "tool_result", "system", "progress", "attachment", "result":
			_append_transcript_entry(entry.kind, {
				"title": entry.title,
				"text": entry.text,
				"payload": entry.payload,
				"raw_data": entry.raw_data,
				"uuid": entry.uuid,
				"session_id": entry.session_id,
			})


func _get_task_entry_by_task_id(task_id: String) -> Dictionary:
	var entry_id := int(_task_entry_ids.get(task_id, -1))
	if entry_id < 0:
		return {}
	return _get_transcript_entry(entry_id)


func _upsert_task_entry(task_id: String, updates: Dictionary) -> void:
	if task_id.strip_edges().is_empty():
		return
	var entry := _get_task_entry_by_task_id(task_id).duplicate(true)
	if entry.is_empty():
		entry = {
			"title": "Task",
			"text": "",
			"task_id": task_id,
			"task_status": "running",
			"task_type": "",
			"task_active": true,
			"stop_pending": false,
			"output_file": "",
			"last_tool_name": "",
			"task_usage": {},
			"tool_use_id": "",
			"raw_data": null,
		}
	for key in updates.keys():
		entry[key] = updates[key]
	entry["title"] = _task_entry_title(str(entry.get("task_status", "")))
	entry["metadata_text"] = _task_metadata_text(entry)
	var entry_id := int(entry.get("id", -1))
	if entry_id < 0:
		entry_id = _append_transcript_entry("task", entry)
	_task_entry_ids[task_id] = entry_id
	if int(entry.get("id", -1)) >= 0:
		_set_transcript_entry(entry_id, entry)


func _task_entry_title(status: String) -> String:
	var normalized := status.strip_edges().to_lower()
	if normalized.is_empty():
		return "Task"
	return "Task · %s" % normalized.capitalize()


func _task_metadata_text(entry: Dictionary) -> String:
	var parts: Array[String] = []
	var task_id := str(entry.get("task_id", "")).strip_edges()
	if not task_id.is_empty():
		parts.append("ID: %s" % task_id)
	var status := str(entry.get("task_status", "")).strip_edges()
	if not status.is_empty():
		parts.append("Status: %s" % status)
	var task_type := str(entry.get("task_type", "")).strip_edges()
	if not task_type.is_empty():
		parts.append("Type: %s" % task_type)
	var last_tool_name := str(entry.get("last_tool_name", "")).strip_edges()
	if not last_tool_name.is_empty():
		parts.append("Last tool: %s" % last_tool_name)
	var output_file := str(entry.get("output_file", "")).strip_edges()
	if not output_file.is_empty():
		parts.append("Output: %s" % output_file)
	var usage_text := _task_usage_summary(entry.get("task_usage", {}))
	if not usage_text.is_empty():
		parts.append("Usage: %s" % usage_text)
	return " · ".join(parts)


func _task_usage_summary(usage: Variant) -> String:
	if usage is not Dictionary or (usage as Dictionary).is_empty():
		return ""
	var usage_dict := usage as Dictionary
	var preferred_order := [
		["input_tokens", "in"],
		["output_tokens", "out"],
		["cache_creation_input_tokens", "cache write"],
		["cache_read_input_tokens", "cache read"],
		["total", "total"],
	]
	var parts: Array[String] = []
	for item in preferred_order:
		var key := str(item[0])
		if usage_dict.has(key):
			parts.append("%s=%s" % [str(item[1]), str(usage_dict.get(key))])
	var remaining_keys: Array[String] = []
	for key_variant in usage_dict.keys():
		var key := str(key_variant)
		var is_preferred := false
		for item in preferred_order:
			if key == str(item[0]):
				is_preferred = true
				break
		if is_preferred:
			continue
		var value := usage_dict.get(key_variant)
		if value is String or value is int or value is float or value is bool:
			remaining_keys.append(key)
	remaining_keys.sort()
	for key in remaining_keys:
		parts.append("%s=%s" % [key, str(usage_dict.get(key))])
	return ", ".join(parts)


func _is_terminal_task_status(status: String) -> bool:
	var normalized := status.strip_edges().to_lower()
	return normalized == "completed" or normalized == "failed" or normalized == "stopped"


func _rate_limit_event_text(message: ClaudeRateLimitEvent) -> String:
	var info := message.rate_limit_info
	var lines: Array[String] = []
	lines.append("Status: %s" % _humanize_label(info.status))
	if info.rate_limit_type != null and not str(info.rate_limit_type).is_empty():
		lines.append("Window: %s" % _humanize_label(str(info.rate_limit_type)))
	if info.utilization != null:
		lines.append("Utilization: %.0f%%" % (float(info.utilization) * 100.0))
	if info.resets_at != null:
		lines.append("Resets: %s" % Time.get_datetime_string_from_unix_time(int(info.resets_at), true))
	if info.overage_status != null and not str(info.overage_status).is_empty():
		lines.append("Overage: %s" % _humanize_label(str(info.overage_status)))
	if info.overage_resets_at != null:
		lines.append("Overage resets: %s" % Time.get_datetime_string_from_unix_time(int(info.overage_resets_at), true))
	if info.overage_disabled_reason != null and not str(info.overage_disabled_reason).is_empty():
		lines.append("Overage reason: %s" % str(info.overage_disabled_reason))
	return "%s\n\n%s" % ["\n".join(lines), _json_pretty(message.raw_data)]


func _humanize_label(value: String) -> String:
	var tokens := value.strip_edges().replace("-", "_").split("_", false)
	var formatted: Array[String] = []
	for token in tokens:
		formatted.append(token.capitalize())
	return " ".join(formatted)


func _begin_new_live_turn() -> void:
	_current_assistant_entry_id = -1
	_current_thinking_entry_id = -1
	_streaming_assistant_entry = null
	_streaming_assistant_body = null
	_streaming_assistant_buffer = ""


func _append_live_assistant_delta(text_delta: String, raw_data: Variant = null) -> void:
	if _current_assistant_entry_id < 0:
		_current_assistant_entry_id = _append_transcript_entry("assistant", {
			"title": "Claude",
			"text": text_delta,
			"align_right": false,
			"raw_data": raw_data,
			"payload": {"partial": true},
		})
		return
	var entry := _get_transcript_entry(_current_assistant_entry_id)
	if entry.is_empty():
		return
	entry["text"] = str(entry.get("text", "")) + text_delta
	if raw_data != null:
		entry["raw_data"] = raw_data
	_set_transcript_entry(_current_assistant_entry_id, entry)


func _upsert_live_assistant_entry(text: String, raw_data: Variant = null) -> void:
	if _current_assistant_entry_id < 0:
		_current_assistant_entry_id = _append_transcript_entry("assistant", {
			"title": "Claude",
			"text": text,
			"align_right": false,
			"raw_data": raw_data,
		})
		return
	var entry := _get_transcript_entry(_current_assistant_entry_id)
	if entry.is_empty():
		return
	entry["text"] = text
	if raw_data != null:
		entry["raw_data"] = raw_data
	_set_transcript_entry(_current_assistant_entry_id, entry)


func _append_or_merge_thinking_entry(text: String, raw_data: Variant = null) -> void:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return
	if _current_thinking_entry_id < 0:
		_current_thinking_entry_id = _append_transcript_entry("thinking", {
			"title": "Thinking",
			"text": normalized,
			"raw_data": raw_data,
		})
		return
	var entry := _get_transcript_entry(_current_thinking_entry_id)
	if entry.is_empty():
		return
	var existing := str(entry.get("text", ""))
	if existing.is_empty():
		entry["text"] = normalized
	elif existing == normalized or existing.ends_with(normalized):
		pass
	elif normalized.begins_with(existing):
		entry["text"] = normalized
	else:
		entry["text"] = "%s\n\n%s" % [existing, normalized]
	if raw_data != null:
		entry["raw_data"] = raw_data
	_set_transcript_entry(_current_thinking_entry_id, entry)


func _append_transcript_entry(kind: String, data: Dictionary) -> int:
	var entry := data.duplicate(true)
	entry["id"] = _next_transcript_entry_id
	entry["kind"] = kind
	_next_transcript_entry_id += 1
	_transcript_entries.append(entry)
	_ensure_transcript_entry_view(entry)
	return int(entry.get("id", -1))


func _append_pending_user_prompt(text: String) -> void:
	_pending_prompt_entry_id = _append_transcript_entry("user", {
		"title": "You",
		"text": text,
		"align_right": true,
	})
	_pending_prompt_echo = text


func _get_transcript_entry(entry_id: int) -> Dictionary:
	for entry in _transcript_entries:
		if int(entry.get("id", -1)) == entry_id:
			return entry
	return {}


func _set_transcript_entry(entry_id: int, updated_entry: Dictionary) -> void:
	for index in range(_transcript_entries.size()):
		if int(_transcript_entries[index].get("id", -1)) == entry_id:
			_transcript_entries[index] = updated_entry
			_update_transcript_entry_view(updated_entry)
			return


func _discard_pending_prompt_echo_entry() -> void:
	var entry_id := _pending_prompt_entry_id
	_pending_prompt_echo = ""
	_pending_prompt_entry_id = -1
	if entry_id < 0:
		return
	for index in range(_transcript_entries.size()):
		if int(_transcript_entries[index].get("id", -1)) != entry_id:
			continue
		_transcript_entries.remove_at(index)
		break
	var view: Dictionary = _transcript_entry_views.get(entry_id, {})
	if not view.is_empty():
		var container := view.get("container") as Control
		if container != null:
			container.queue_free()
		_transcript_entry_views.erase(entry_id)


func _render_transcript_entries() -> void:
	_clear_transcript_views()
	for entry in _transcript_entries:
		_ensure_transcript_entry_view(entry)


func _render_transcript_entry(entry: Dictionary) -> void:
	_ensure_transcript_entry_view(entry)


func _ensure_transcript_entry_view(entry: Dictionary) -> void:
	var entry_id := int(entry.get("id", -1))
	if entry_id < 0:
		return
	if _transcript_entry_views.has(entry_id):
		_refresh_transcript_entry_view(entry)
		return
	var container := VBoxContainer.new()
	container.name = "TranscriptEntry_%d" % entry_id
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 8)
	container.set_meta("transcript_entry_id", entry_id)
	_transcript_list.add_child(container)
	var primary := _create_transcript_primary_view(entry)
	if primary == null:
		container.queue_free()
		return
	container.add_child(primary)
	_transcript_entry_views[entry_id] = {
		"container": container,
		"primary": primary,
		"raw": null,
	}
	_refresh_transcript_entry_view(entry)
	_scroll_to_bottom_deferred()


func _refresh_transcript_entry_view(entry: Dictionary) -> void:
	var entry_id := int(entry.get("id", -1))
	var view: Dictionary = _transcript_entry_views.get(entry_id, {})
	if view.is_empty():
		return
	var primary := view.get("primary") as Control
	if primary != null:
		_update_transcript_primary_view(primary, entry)
		primary.visible = _is_transcript_entry_primary_visible(entry)
	if _should_show_raw_entry(entry):
		var raw_view := view.get("raw") as Control
		if raw_view == null:
			raw_view = _create_raw_entry_view(entry)
			if raw_view != null:
				(view.get("container") as VBoxContainer).add_child(raw_view)
				view["raw"] = raw_view
				_transcript_entry_views[entry_id] = view
		elif raw_view != null:
			_update_detail_card(raw_view, "Raw · %s" % _transcript_entry_title_kind(entry), _json_pretty(entry.get("raw_data")), true)
	if view.get("raw") is Control:
		(view.get("raw") as Control).visible = _raw_toggle.button_pressed
	var container := view.get("container") as VBoxContainer
	if container != null:
		var primary_visible := primary != null and primary.visible
		var raw_visible := view.get("raw") is Control and (view.get("raw") as Control).visible
		container.visible = primary_visible or raw_visible


func _update_transcript_entry_view(entry: Dictionary) -> void:
	var entry_id := int(entry.get("id", -1))
	if entry_id < 0:
		return
	if not _transcript_entry_views.has(entry_id):
		_ensure_transcript_entry_view(entry)
		return
	_refresh_transcript_entry_view(entry)
	_scroll_to_bottom_deferred()


func _refresh_transcript_entry_views_visibility() -> void:
	for entry in _transcript_entries:
		_refresh_transcript_entry_view(entry)


func _create_transcript_primary_view(entry: Dictionary) -> Control:
	var kind := str(entry.get("kind", ""))
	match kind:
		"user":
			return _create_message_bubble("user", entry)
		"assistant":
			return _create_message_bubble("assistant", entry)
		"task":
			return _create_task_card(entry)
		"thinking":
			return _create_detail_card("thinking", str(entry.get("title", "Thinking")), str(entry.get("text", "")), false)
		"tool_prompt":
			return _create_detail_card("tool_prompt", str(entry.get("title", "Tool prompt")), str(entry.get("text", "")), false)
		"tool_use":
			return _create_detail_card("tool_use", str(entry.get("title", "Tool use")), str(entry.get("text", "")), false)
		"tool_result":
			return _create_detail_card("tool_result", str(entry.get("title", "Tool result")), str(entry.get("text", "")), false)
		"system":
			return _create_detail_card("system", str(entry.get("title", "System")), str(entry.get("text", "")), false)
		"progress":
			return _create_detail_card("progress", str(entry.get("title", "Progress")), str(entry.get("text", "")), false)
		"attachment":
			return _create_detail_card("attachment", str(entry.get("title", "Attachment")), str(entry.get("text", "")), false)
		"result":
			return _create_result_card(entry)
	return null


func _update_transcript_primary_view(primary: Control, entry: Dictionary) -> void:
	var kind := str(entry.get("kind", ""))
	match kind:
		"user", "assistant":
			_update_message_bubble(primary, kind, entry)
		"task":
			_update_task_card(primary, entry)
		"thinking", "tool_prompt", "tool_use", "tool_result", "system", "progress", "attachment":
			_update_detail_card(primary, str(entry.get("title", "")), str(entry.get("text", "")), false)
		"result":
			_update_result_card(primary, entry)


func _is_transcript_entry_primary_visible(entry: Dictionary) -> bool:
	match str(entry.get("kind", "")):
		"thinking":
			return _thinking_toggle.button_pressed
		"task", "progress":
			return _tasks_toggle.button_pressed
		"tool_prompt", "tool_use", "tool_result":
			return _tools_toggle.button_pressed
		"system", "attachment":
			return _system_toggle.button_pressed
		"result":
			return _results_toggle.button_pressed and bool(entry.get("show_result", true))
		_:
			return true


func _should_show_raw_entry(entry: Dictionary) -> bool:
	var kind := str(entry.get("kind", ""))
	return kind != "user" and kind != "assistant" and entry.get("raw_data") != null


func _should_show_rewind_action(entry: Dictionary) -> bool:
	if str(entry.get("kind", "")) != "user":
		return false
	if not _rewind_support_ready():
		return false
	if str(entry.get("uuid", "")).strip_edges().is_empty():
		return false
	return _entry_matches_active_session(entry)


func _should_show_saved_fork_action(entry: Dictionary) -> bool:
	var kind := str(entry.get("kind", ""))
	if kind != "user" and kind != "assistant":
		return false
	if _session_live or _is_connecting:
		return false
	if not _has_selected_session():
		return false
	if str(entry.get("uuid", "")).strip_edges().is_empty():
		return false
	return _normalize_transcript_session_id(str(entry.get("session_id", ""))) == _selected_session_id


func _rewind_support_ready() -> bool:
	return (
		_session_live and
		not _is_connecting and
		_configured_options != null and
		_configured_options.enable_file_checkpointing and
		_configured_options.extra_args.has("replay-user-messages")
	)


func _entry_matches_active_session(entry: Dictionary) -> bool:
	var entry_session_id := _normalize_transcript_session_id(str(entry.get("session_id", "")))
	if entry_session_id.is_empty():
		return true
	return entry_session_id == _active_session_reference_id()


func _normalize_transcript_session_id(session_id: String) -> String:
	var normalized := session_id.strip_edges()
	var active_session_id := _active_session_reference_id()
	if normalized == "default" and active_session_id != "default":
		return active_session_id
	return normalized


func _message_session_id(message: Variant) -> String:
	if message is ClaudeAssistantMessage:
		return message.session_id
	if message is ClaudeResultMessage:
		return message.session_id
	if message is ClaudeStreamEvent:
		return message.session_id
	if message is ClaudeRateLimitEvent:
		return message.session_id
	if message is ClaudeTaskStartedMessage:
		return message.session_id
	if message is ClaudeTaskProgressMessage:
		return message.session_id
	if message is ClaudeTaskNotificationMessage:
		return message.session_id
	if message is ClaudeUserMessage:
		return str(message.raw_data.get("session_id", ""))
	return ""


func _note_runtime_session_id(session_id: String) -> void:
	var normalized := session_id.strip_edges()
	if normalized.is_empty():
		return
	if normalized != "default":
		_authoritative_live_session_id = normalized
		_live_session_target_id = normalized
		return
	if _authoritative_live_session_id.is_empty() and _live_session_target_id == "default":
		_authoritative_live_session_id = normalized


func _handle_cli_stderr_line(line: String) -> void:
	if _forwarded_stderr_callback.is_valid():
		_forwarded_stderr_callback.call_deferred(line)
	var trimmed := line.strip_edges()
	if trimmed.is_empty():
		return
	_last_cli_diagnostic_line = trimmed
	if _is_connecting or (not _session_live and not _status_issue_message.is_empty()):
		call_deferred("_update_status_from_state")


func _tool_prompt_title(tool_use_id: String) -> String:
	var tool_name := str(_tool_use_names.get(tool_use_id, "")).strip_edges()
	if tool_name.is_empty():
		return "Tool prompt"
	return "Tool prompt · %s" % tool_name


func _transcript_entry_title_kind(entry: Dictionary) -> String:
	return str(entry.get("kind", "")).capitalize().replace("_", " ")


func _should_render_result_card(message: ClaudeResultMessage) -> bool:
	if message.is_error:
		return true
	if message.structured_output != null:
		return true
	if not message.errors.is_empty():
		return true
	if message.subtype != "success":
		return true
	return _should_render_result_text(message)


func _should_render_result_text(message: ClaudeResultMessage) -> bool:
	var result_text := message.result.strip_edges()
	if result_text.is_empty():
		return false
	var assistant_text := _current_assistant_text()
	if assistant_text.is_empty():
		return true
	return result_text != assistant_text


func _current_assistant_text() -> String:
	if _current_assistant_entry_id < 0:
		return ""
	return str(_get_transcript_entry(_current_assistant_entry_id).get("text", "")).strip_edges()


func _clear_transcript_list_children() -> void:
	for child in _transcript_list.get_children():
		_transcript_list.remove_child(child)
		child.queue_free()


func _clear_transcript_views() -> void:
	_transcript_entry_views.clear()
	_clear_transcript_list_children()


func _create_message_bubble(role: String, entry: Dictionary) -> Control:
	var text := str(entry.get("text", ""))
	var label_text := str(entry.get("title", "You" if role == "user" else "Claude"))
	var align_right := bool(entry.get("align_right", role == "user"))
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
	bubble_label.name = "BubbleLabel"
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

	if role == "user" or role == "assistant":
		var actions := HBoxContainer.new()
		actions.name = "BubbleActions"
		actions.alignment = BoxContainer.ALIGNMENT_END
		bubble_body.add_child(actions)

		var fork_button := Button.new()
		fork_button.name = "ForkFromHereButton"
		fork_button.text = "Fork from here"
		fork_button.focus_mode = Control.FOCUS_NONE
		fork_button.pressed.connect(_on_saved_transcript_fork_pressed.bind(int(entry.get("id", -1))))
		actions.add_child(fork_button)

		if role == "user":
			var rewind_button := Button.new()
			rewind_button.name = "RewindButton"
			rewind_button.text = "Rewind files here"
			rewind_button.focus_mode = Control.FOCUS_NONE
			rewind_button.pressed.connect(_on_rewind_button_pressed.bind(int(entry.get("id", -1))))
			actions.add_child(rewind_button)

	if align_right:
		row.add_child(spacer)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(spacer)

	return row


func _update_message_bubble(row: Control, role: String, entry: Dictionary) -> void:
	var label_text := str(entry.get("title", "You" if role == "user" else "Claude"))
	var body_text := str(entry.get("text", ""))
	var bubble_label := row.find_child("BubbleLabel", true, false) as Label
	if bubble_label != null:
		bubble_label.text = label_text
	var bubble_body := row.find_child("BubbleBody", true, false) as RichTextLabel
	if bubble_body != null:
		bubble_body.text = body_text
	var fork_button := row.find_child("ForkFromHereButton", true, false) as Button
	var actions := row.find_child("BubbleActions", true, false) as HBoxContainer
	if fork_button == null or actions == null:
		return
	var can_fork := _should_show_saved_fork_action(entry)
	if role == "assistant":
		actions.visible = can_fork
		fork_button.visible = can_fork
		fork_button.disabled = not can_fork
		return
	var rewind_button := row.find_child("RewindButton", true, false) as Button
	if role != "user" or rewind_button == null:
		return
	var can_rewind := _should_show_rewind_action(entry)
	var is_pending := int(entry.get("id", -1)) == _rewind_pending_entry_id
	actions.visible = can_fork or can_rewind
	fork_button.visible = can_fork
	fork_button.disabled = not can_fork
	rewind_button.visible = can_rewind
	rewind_button.disabled = not can_rewind or _client_node == null or _client_node.is_busy() or _rewind_pending_entry_id >= 0
	rewind_button.text = "Rewinding..." if is_pending else "Rewind files here"


func _create_detail_card(kind: String, title: String, body_text: String, collapsed: bool) -> Control:
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
	toggle.name = "CardToggle"
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

	return row


func _update_detail_card(card: Control, title: String, body_text: String, collapsed: bool) -> void:
	var toggle := card.find_child("CardToggle", true, false) as Button
	var content := card.find_child("CardBody", true, false) as RichTextLabel
	if toggle == null or content == null:
		return
	var should_collapse := collapsed if content.text.is_empty() else not content.visible
	content.text = body_text
	content.visible = not should_collapse
	toggle.text = _card_title(title, should_collapse)


func _create_task_card(entry: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("entry_kind", "task_card")

	var card := _build_card_container(COLOR_PANEL_ALT, 18, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	card.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)

	var title := Label.new()
	title.name = "TaskTitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var stop_button := Button.new()
	stop_button.name = "TaskStopButton"
	stop_button.text = "Stop task"
	stop_button.pressed.connect(_on_task_stop_pressed.bind(str(entry.get("task_id", ""))))
	header.add_child(stop_button)

	var meta := Label.new()
	meta.name = "TaskMetaLabel"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_color_override("font_color", COLOR_MUTED)
	meta.add_theme_font_size_override("font_size", 12)
	body.add_child(meta)

	var content := RichTextLabel.new()
	content.name = "CardBody"
	content.bbcode_enabled = false
	content.fit_content = true
	content.scroll_active = false
	content.selection_enabled = true
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_color_override("default_color", COLOR_TEXT)
	content.add_theme_font_size_override("normal_font_size", 14)
	body.add_child(content)

	_update_task_card(row, entry)
	return row


func _update_task_card(card: Control, entry: Dictionary) -> void:
	var title := card.find_child("TaskTitleLabel", true, false) as Label
	var meta := card.find_child("TaskMetaLabel", true, false) as Label
	var content := card.find_child("CardBody", true, false) as RichTextLabel
	var stop_button := card.find_child("TaskStopButton", true, false) as Button
	if title == null or meta == null or content == null or stop_button == null:
		return
	var status := str(entry.get("task_status", "")).to_lower()
	title.text = str(entry.get("title", "Task"))
	title.add_theme_color_override("font_color", _task_status_color(status))
	meta.text = str(entry.get("metadata_text", ""))
	content.text = str(entry.get("text", ""))
	var is_active := bool(entry.get("task_active", false))
	var stop_pending := bool(entry.get("stop_pending", false))
	stop_button.visible = is_active or stop_pending
	stop_button.disabled = (not is_active) or stop_pending or _client_node == null or not _session_live
	stop_button.text = "Stopping..." if stop_pending else "Stop task"


func _task_status_color(status: String) -> Color:
	match status:
		"completed":
			return COLOR_SUCCESS
		"failed":
			return COLOR_ERROR
		"stopped":
			return COLOR_WARNING
		_:
			return COLOR_ACCENT


func _create_raw_entry_view(entry: Dictionary) -> Control:
	return _create_detail_card(
		"raw",
		"Raw · %s" % _transcript_entry_title_kind(entry),
		_json_pretty(entry.get("raw_data")),
		true
	)


func _create_result_card(entry: Dictionary) -> Control:
	var message = entry.get("payload") as ClaudeResultMessage
	if message == null:
		return null
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

	if bool(entry.get("show_result_text", true)) and not message.result.is_empty():
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

	return card


func _update_result_card(card: Control, entry: Dictionary) -> void:
	var message = entry.get("payload") as ClaudeResultMessage
	if message == null:
		return
	var existing_body := card.get_child(0) as VBoxContainer
	if existing_body != null:
		card.remove_child(existing_body)
		existing_body.queue_free()
	var rebuilt := _create_result_card(entry)
	if rebuilt == null:
		return
	var rebuilt_body := rebuilt.get_child(0) as VBoxContainer
	if rebuilt_body == null:
		rebuilt.queue_free()
		return
	rebuilt.remove_child(rebuilt_body)
	card.add_child(rebuilt_body)
	rebuilt.queue_free()


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
		_status_detail.text = "Live session ready%s" % [
			" · %d commands advertised" % command_count if command_count > 0 else "",
		]
	elif _is_connecting:
		_set_status_badge("Connecting", COLOR_ACCENT)
		_status_title.text = "Connecting to Claude"
		_status_detail.text = _status_detail_with_diagnostic("Waiting for the streaming session to initialize.")
	else:
		var logged_in := bool(_last_auth_status.get("logged_in", false))
		var error_message := str(_last_auth_status.get("error_message", ""))
		if not _status_issue_message.is_empty():
			_set_status_badge("Issue", COLOR_ERROR)
			_status_title.text = "Claude session failed to start"
			_status_detail.text = _status_detail_with_diagnostic(_status_issue_message)
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
	_refresh_configuration_controls()


func _refresh_composer_state() -> void:
	var logged_in := bool(_last_auth_status.get("logged_in", false))
	var can_draft: bool = not _is_connecting and logged_in and not _client_node.is_busy()
	var can_send: bool = can_draft and not _prompt_input.text.strip_edges().is_empty()
	_prompt_input.editable = can_draft
	_send_button.disabled = not can_send
	_interrupt_button.disabled = not _session_live or not _client_node.is_busy()
	_composer_hint.text = _composer_hint_text()


func _composer_hint_text() -> String:
	if _is_connecting:
		return _status_detail_with_diagnostic("Claude is connecting. The initial prompt will send as soon as the session is ready.")
	if not bool(_last_auth_status.get("logged_in", false)):
		return "Connect the authenticated Claude CLI to start chatting."
	if not _session_live:
		if _has_selected_session():
			if _prompt_input.text.strip_edges().is_empty():
				return "Draft a prompt here to reconnect and continue the selected saved session."
			return "Send the prompt to reconnect and continue the selected saved session."
		if _prompt_input.text.strip_edges().is_empty():
			return "Draft a prompt here, or use Connect to open an empty session."
		return "Send the prompt to connect and start a new chat."
	if _client_node.is_busy():
		return "Claude is responding. You can interrupt the active turn if needed."
	if _has_selected_session():
		return "You are connected. Select a saved session to reconnect into it after this live session closes."
	if _prompt_input.text.strip_edges().is_empty():
		return "Draft a prompt here. The panel renders typed runtime messages and partial output."
	return "Send the prompt to Claude."


func _status_detail_with_diagnostic(base_text: String) -> String:
	var diagnostic := _last_cli_diagnostic_line.strip_edges()
	if diagnostic.is_empty():
		return base_text
	if base_text.is_empty():
		return "Latest CLI diagnostic: %s" % diagnostic
	return "%s\n\nLatest CLI diagnostic: %s" % [base_text, diagnostic]


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
	_split_row.split_offset = int(round(target_left_width))
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
	if _chat_permission_mode.item_count == 0:
		return "default"
	return _chat_permission_mode.get_item_text(_chat_permission_mode.get_selected_id())


func _select_chat_model_value(model_value: String) -> void:
	_select_option_by_value(_chat_model_option, _infer_model_preset(model_value), MODEL_PRESETS[0])
	var effective_value := model_value.strip_edges()
	if effective_value.is_empty():
		effective_value = MODEL_PRESETS[_chat_model_option.selected]
	_chat_model_option.tooltip_text = effective_value


func _select_chat_effort_value(effort_value: String) -> void:
	_select_option_by_value(_chat_effort_option, _infer_effort_preset(effort_value), EFFORT_PRESETS[0])
	var effective_value := effort_value.strip_edges()
	if effective_value.is_empty():
		effective_value = EFFORT_PRESETS[_chat_effort_option.selected]
	_chat_effort_option.tooltip_text = effective_value


func _select_permission_mode(mode_value: String) -> void:
	_select_option_by_value(_chat_permission_mode, mode_value, "default")


func _select_option_by_value(option: OptionButton, value: String, fallback: String) -> void:
	var target := value.strip_edges()
	if target.is_empty():
		target = fallback
	for index in range(option.item_count):
		if option.get_item_text(index) == target:
			option.select(index)
			return
	for index in range(option.item_count):
		if option.get_item_text(index) == fallback:
			option.select(index)
			return
	if option.item_count > 0:
		option.select(0)


func _infer_model_preset(model_value: String) -> String:
	var normalized := model_value.strip_edges().to_lower()
	for model_name in MODEL_PRESETS:
		if normalized == model_name:
			return model_name
	for model_name in MODEL_PRESETS:
		if normalized.contains(model_name):
			return model_name
	return ""


func _infer_effort_preset(effort_value: String) -> String:
	var normalized := effort_value.strip_edges().to_lower()
	for effort_name in EFFORT_PRESETS:
		if normalized == effort_name:
			return effort_name
	return ""


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
	return _extract_stream_delta_string(event, "text", "text_delta")


func _extract_stream_thinking(event: Dictionary) -> String:
	return _extract_stream_delta_string(event, "thinking", "thinking_delta")


func _extract_stream_delta_string(event: Dictionary, field_name: String, expected_delta_type: String) -> String:
	if str(event.get("type", "")) != "content_block_delta":
		return ""
	if not event.has("delta") or not event["delta"] is Dictionary:
		return ""
	var delta: Dictionary = event["delta"]
	if not delta.has(field_name) or not delta[field_name] is String:
		return ""
	var delta_type := str(delta.get("type", ""))
	if not delta_type.is_empty() and delta_type != expected_delta_type:
		return ""
	return str(delta[field_name])


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


func _on_chat_view_pressed() -> void:
	_set_current_view(PANEL_VIEW_CHAT)


func _on_settings_view_pressed() -> void:
	_set_current_view(PANEL_VIEW_SETTINGS)
	_settings_scroll.scroll_vertical = 0


func _refresh_live_session_diagnostics_after_connect() -> void:
	await _refresh_context_usage_async()
	await _refresh_mcp_status_async()


func _refresh_context_usage_async() -> void:
	if _client_node == null or not _session_live or _context_usage_refresh_pending:
		return
	_context_usage_refresh_pending = true
	_live_context_usage_error = ""
	_refresh_live_session_diagnostics()
	var usage: Dictionary = await _client_node.get_context_usage()
	if not _session_live:
		return
	_live_context_usage = usage.duplicate(true)
	_live_context_usage_error = _client_node.get_last_error()
	_context_usage_refresh_pending = false
	_refresh_live_session_diagnostics()
	if not _live_context_usage_error.is_empty():
		_emit_error(_live_context_usage_error)


func _refresh_mcp_status_async() -> void:
	if _client_node == null or not _session_live or _mcp_status_refresh_pending:
		return
	_mcp_status_refresh_pending = true
	_live_mcp_status_error = ""
	_refresh_live_session_diagnostics()
	var status: Dictionary = await _client_node.get_mcp_status()
	if not _session_live:
		return
	_live_mcp_status = status.duplicate(true)
	_live_mcp_status_error = _client_node.get_last_error()
	_mcp_status_refresh_pending = false
	_refresh_live_session_diagnostics()
	if not _live_mcp_status_error.is_empty():
		_emit_error(_live_mcp_status_error)


func _on_interrupt_pressed() -> void:
	if _client_node != null:
		_client_node.interrupt()


func _on_refresh_context_usage_pressed() -> void:
	Callable(self, "_refresh_context_usage_async").call_deferred()


func _on_refresh_mcp_status_pressed() -> void:
	Callable(self, "_refresh_mcp_status_async").call_deferred()


func _on_mcp_server_reconnect_pressed(server_name: String) -> void:
	if _client_node == null or not _session_live:
		return
	_mcp_server_action_pending[server_name] = "reconnect"
	_refresh_live_session_diagnostics()
	await _client_node.reconnect_mcp_server(server_name)
	_mcp_server_action_pending.erase(server_name)
	if not _client_node.get_last_error().is_empty():
		_live_mcp_status_error = _client_node.get_last_error()
		_refresh_live_session_diagnostics()
		_emit_error(_client_node.get_last_error())
		return
	await _refresh_mcp_status_async()


func _on_mcp_server_toggle_pressed(server_name: String, enabled: bool) -> void:
	if _client_node == null or not _session_live:
		return
	_mcp_server_action_pending[server_name] = "toggle"
	_refresh_live_session_diagnostics()
	await _client_node.toggle_mcp_server(server_name, enabled)
	_mcp_server_action_pending.erase(server_name)
	if not _client_node.get_last_error().is_empty():
		_live_mcp_status_error = _client_node.get_last_error()
		_refresh_live_session_diagnostics()
		_emit_error(_client_node.get_last_error())
		return
	await _refresh_mcp_status_async()


func _on_task_stop_pressed(task_id: String) -> void:
	if _client_node == null:
		return
	var entry := _get_task_entry_by_task_id(task_id)
	if entry.is_empty() or not bool(entry.get("task_active", false)):
		return
	entry["stop_pending"] = true
	_set_transcript_entry(int(entry.get("id", -1)), entry)
	await _client_node.stop_task(task_id)
	if not _client_node.get_last_error().is_empty():
		var updated_entry := _get_task_entry_by_task_id(task_id)
		if not updated_entry.is_empty():
			updated_entry["stop_pending"] = false
			_set_transcript_entry(int(updated_entry.get("id", -1)), updated_entry)
		_emit_error(_client_node.get_last_error())


func _on_send_pressed() -> void:
	submit_prompt(_prompt_input.text)


func _on_prompt_text_changed() -> void:
	_refresh_composer_state()


func _on_transcript_filter_toggled(_pressed: bool) -> void:
	_refresh_transcript_entry_views_visibility()


func _on_rewind_support_toggled(_pressed: bool) -> void:
	_sync_configuration_from_controls()
	_refresh_transcript_entry_views_visibility()


func _on_model_option_selected(index: int) -> void:
	var selected_model := _chat_model_option.get_item_text(index)
	_configured_options.model = selected_model
	_chat_model_option.tooltip_text = selected_model
	if _session_live:
		_client_node.set_model(selected_model)
		return
	_capture_base_session_defaults()


func _on_effort_option_selected(index: int) -> void:
	var selected_effort := _chat_effort_option.get_item_text(index)
	_configured_options.effort = selected_effort
	_chat_effort_option.tooltip_text = selected_effort


func _on_permission_mode_selected(_index: int) -> void:
	_configured_options.permission_mode = _current_permission_mode()
	if _session_live:
		_client_node.set_permission_mode(_current_permission_mode())
		return
	_capture_base_session_defaults()


func _on_system_prompt_mode_selected(_index: int) -> void:
	_refresh_configuration_field_visibility()
	_sync_configuration_from_controls()


func _on_system_prompt_text_changed() -> void:
	_sync_configuration_from_controls()


func _on_system_prompt_file_text_changed(_new_text: String) -> void:
	_sync_configuration_from_controls()


func _on_built_in_tool_toggled(_pressed: bool, _tool_name: String) -> void:
	_sync_configuration_from_controls()


func _on_tool_group_enable_all_pressed(group_id: String) -> void:
	_set_group_tool_state(group_id, true)
	_sync_configuration_from_controls()


func _on_tool_group_disable_all_pressed(group_id: String) -> void:
	_set_group_tool_state(group_id, false)
	_sync_configuration_from_controls()


func _on_rewind_button_pressed(entry_id: int) -> void:
	if _client_node == null or _rewind_pending_entry_id >= 0:
		return
	var entry := _get_transcript_entry(entry_id)
	if entry.is_empty() or not _should_show_rewind_action(entry):
		return
	var user_message_id := str(entry.get("uuid", "")).strip_edges()
	if user_message_id.is_empty():
		return
	_rewind_pending_entry_id = entry_id
	_refresh_transcript_entry_views_visibility()
	await _client_node.rewind_files(user_message_id)
	_rewind_pending_entry_id = -1
	_refresh_transcript_entry_views_visibility()


func _on_tool_rules_advanced_toggled(_pressed: bool) -> void:
	_refresh_configuration_field_visibility()
	_sync_configuration_from_controls()


func _set_group_tool_state(group_id: String, enabled: bool) -> void:
	for group in ClaudeBuiltInToolCatalog.list_groups():
		if str(group.get("id", "")) != group_id:
			continue
		for tool_name_variant in (group.get("tools", []) as Array):
			var checkbox := _built_in_tool_checks.get(str(tool_name_variant), null) as CheckBox
			if checkbox != null:
				checkbox.set_pressed_no_signal(enabled)
		return


func _on_allowed_tools_text_changed(_new_text: String) -> void:
	_sync_configuration_from_controls()


func _on_disallowed_tools_text_changed(_new_text: String) -> void:
	_sync_configuration_from_controls()


func _on_session_refresh_pressed() -> void:
	if not _can_switch_sessions():
		return
	_reload_sessions(true)


func _on_new_chat_pressed() -> void:
	if not _can_switch_sessions():
		return
	if _session_live:
		_selected_session_id = ""
		_selected_session_info = null
		_selected_session_messages.clear()
		_selected_session_transcript.clear()
		_delete_confirm_armed = false
		_live_session_target_id = _effective_connect_session_target_id()
		_session_list.deselect_all()
		_refresh_selected_session_fields()
		_refresh_selected_session_metadata()
		_clear_transcript_after_disconnect = true
		_client_node.disconnect_client()
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


func _on_fork_session_pressed() -> void:
	_fork_selected_session()


func _on_saved_transcript_fork_pressed(entry_id: int) -> void:
	if not _has_selected_session():
		return
	var entry := _get_transcript_entry(entry_id)
	if entry.is_empty() or not _should_show_saved_fork_action(entry):
		return
	var cutoff_message_id := str(entry.get("uuid", "")).strip_edges()
	if cutoff_message_id.is_empty():
		return
	_fork_selected_session(cutoff_message_id)


func _fork_selected_session(up_to_message_id: String = "") -> void:
	if not _has_selected_session():
		return
	var fork_result: Variant = _client_node.fork_session(
		_selected_session_id,
		_selected_session_directory(),
		up_to_message_id,
		_fork_title_input.text
	)
	if fork_result == null:
		_status_issue_message = _client_node.get_last_error()
		_update_status_from_state()
		_refresh_session_controls()
		return
	_status_issue_message = ""
	var forked_session_id: String = fork_result.session_id
	_reload_sessions(false)
	var forked_index := _find_session_index(forked_session_id)
	if forked_index >= 0:
		_select_session_by_index(forked_index)
	else:
		_update_status_from_state()
		_refresh_session_controls()


func _on_cancel_delete_pressed() -> void:
	_delete_confirm_armed = false
	_refresh_session_controls()


func _on_session_title_text_changed(_new_text: String) -> void:
	_refresh_session_controls()


func _on_session_tag_text_changed(_new_text: String) -> void:
	_refresh_session_controls()


func _on_fork_title_text_changed(_new_text: String) -> void:
	_refresh_session_controls()
