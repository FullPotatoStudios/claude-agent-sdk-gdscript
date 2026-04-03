extends Node

const ClaudeClientAdapterScript := preload("res://addons/claude_agent_sdk/runtime/adapters/claude_client_adapter.gd")

var _adapter = ClaudeClientAdapterScript.new(
	ClaudeAgentOptions.new({
		"model": "haiku",
		"effort": "low",
	})
)


func _ready() -> void:
	_adapter.session_ready.connect(_on_session_ready)
	_adapter.turn_message_received.connect(_on_turn_message_received)
	_adapter.turn_finished.connect(_on_turn_finished)
	_adapter.error_occurred.connect(_on_error_occurred)
	_adapter.connect_client()


func _on_session_ready(_server_info: Dictionary) -> void:
	_adapter.query("Say hello in one short sentence.")


func _on_turn_message_received(message: Variant) -> void:
	print("Turn message: ", message)


func _on_turn_finished(message: ClaudeResultMessage) -> void:
	print("Turn finished: ", message.result)
	_adapter.disconnect_client()


func _on_error_occurred(message: String) -> void:
	push_error(message)
