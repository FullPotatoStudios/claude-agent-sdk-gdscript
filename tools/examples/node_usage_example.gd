extends Node

const ClaudeClientNodeScript := preload("res://addons/claude_agent_sdk/runtime/adapters/claude_client_node.gd")

var _client_node := ClaudeClientNodeScript.new(ClaudeAgentOptions.new({
	"model": "haiku",
	"effort": "low",
}))


func _ready() -> void:
	add_child(_client_node)
	_client_node.session_ready.connect(_on_session_ready)
	_client_node.turn_message_received.connect(_on_turn_message_received)
	_client_node.turn_finished.connect(_on_turn_finished)
	_client_node.error_occurred.connect(_on_error_occurred)
	_client_node.connect_client()


func _on_session_ready(_server_info: Dictionary) -> void:
	_client_node.query("Say hello in one short sentence.")


func _on_turn_message_received(message: Variant) -> void:
	print("Turn message: ", message)


func _on_turn_finished(message: ClaudeResultMessage) -> void:
	print("Turn finished: ", message.result)
	_client_node.disconnect_client()


func _on_error_occurred(message: String) -> void:
	push_error(message)
