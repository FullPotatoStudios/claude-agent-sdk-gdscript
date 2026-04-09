@tool
extends MarginContainer

const PANEL_SCENE_PATH := "res://addons/claude_agent_sdk/ui/claude_chat_panel.tscn"
const OPTIONS_SCRIPT_PATH := "res://addons/claude_agent_sdk/runtime/claude_agent_options.gd"
const STATUS_READY := "Development-only dock example. Claude is scoped to the current project root."
const STATUS_MISSING_ADDON := "Install res://addons/claude_agent_sdk before enabling this example plugin."

@onready var _status_label: Label = $DockMargin/DockBody/StatusLabel
@onready var _panel_host: VBoxContainer = $DockMargin/DockBody/PanelHost

var _chat_panel: Control = null


func _ready() -> void:
	_mount_chat_panel()


func get_chat_panel() -> Control:
	return _chat_panel


func get_status_message() -> String:
	return _status_label.text if is_instance_valid(_status_label) else ""


func _mount_chat_panel() -> void:
	if _chat_panel != null and is_instance_valid(_chat_panel):
		return
	var panel_scene := load(PANEL_SCENE_PATH) as PackedScene
	var options_script = load(OPTIONS_SCRIPT_PATH)
	if panel_scene == null or options_script == null:
		_status_label.text = STATUS_MISSING_ADDON
		return
	var panel = panel_scene.instantiate()
	if panel == null:
		_status_label.text = "ClaudeChatPanel could not be instantiated."
		return
	var options = options_script.new({
		"cwd": ProjectSettings.globalize_path("res://"),
		"model": "haiku",
		"effort": "low",
		"permission_mode": "plan",
		"system_prompt": {
			"type": "preset",
			"preset": "claude_code",
			"append": "You are helping from a Godot editor dock for the currently open project.",
		},
	})
	if panel.has_method("setup"):
		panel.call("setup", options)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_host.add_child(panel)
	_chat_panel = panel
	_status_label.text = STATUS_READY
