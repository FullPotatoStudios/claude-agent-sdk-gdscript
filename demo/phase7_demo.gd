extends Control

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeMcpScript := preload("res://addons/claude_agent_sdk/runtime/mcp/claude_mcp.gd")

@onready var _chat_panel: ClaudeChatPanel = $Layout/Shell/Body/PanelWrap/ClaudeChatPanel


func _describe_player_state_tool(_tool_args: Dictionary) -> Dictionary:
	return {
		"content": [
			{
				"type": "text",
				"text": "Player HP: 82\nAmmo: 14\nCurrent biome: Crystal Caverns",
			},
		],
	}


func _ready() -> void:
	var gameplay_server := ClaudeMcpScript.create_sdk_server(
		"gameplay",
		"1.0.0",
		[
			ClaudeMcpScript.tool(
				"describe_player_state",
				"Summarize the current player state for design feedback",
				ClaudeMcpScript.schema_object({}, []),
				Callable(self, "_describe_player_state_tool")
			),
		]
	)
	_chat_panel.setup(ClaudeAgentOptionsScript.new({
		"model": "haiku",
		"effort": "low",
		"system_prompt": {
			"type": "preset",
			"preset": "claude_code",
			"append": "Act like a collaborative game design copilot and keep suggestions grounded in Godot workflows.",
		},
		"mcp_servers": {
			"gameplay": gameplay_server,
		},
	}))
