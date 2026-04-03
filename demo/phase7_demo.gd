extends Control

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")

@onready var _chat_panel: ClaudeChatPanel = $Layout/Shell/Body/PanelWrap/ClaudeChatPanel


func _ready() -> void:
	_chat_panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"effort": "low",
	}))
