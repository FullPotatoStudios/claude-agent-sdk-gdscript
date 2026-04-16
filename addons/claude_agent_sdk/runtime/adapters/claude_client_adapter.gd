extends RefCounted
class_name ClaudeClientAdapter

signal session_ready(server_info: Dictionary)
signal turn_started(prompt: String, session_id: String)
signal message_received(message: Variant)
signal turn_message_received(message: Variant)
signal turn_message_received_for_session(message: Variant, session_id: String)
signal turn_finished(result_message: ClaudeResultMessage)
signal busy_changed(is_busy: bool)
signal error_occurred(message: String)
signal session_closed()

const ClaudeSDKClientScript := preload("res://addons/claude_agent_sdk/runtime/claude_sdk_client.gd")
const ClaudeSessionsScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_sessions.gd")

var _client = null
var _connected := false
var _busy := false
var _last_error := ""
var _session_ready_emitted := false
var _active_token := 0
var _closed_token := -1
var _turn_watch_counter := 0
var _active_turns_by_session: Dictionary = {}


func _init(initial_options = null, transport = null) -> void:
	_client = ClaudeSDKClientScript.new(initial_options, transport)
	_client.session_initialized.connect(_on_client_session_initialized)
	_client.error_occurred.connect(_on_client_error_occurred)


func connect_client(prompt = null) -> void:
	if _connected:
		disconnect_client()

	_last_error = ""
	_client.connect_client(prompt)
	var stream = _client.receive_messages()
	if not stream.get_error().is_empty():
		_client.disconnect_client()
		return

	_connected = true
	_session_ready_emitted = false
	_active_token += 1
	var token := _active_token
	Callable(self, "_run_message_drain").call_deferred(token, stream)
	if prompt != null and _client.get_last_error().is_empty():
		_begin_turn_watch(prompt, "default")


func disconnect_client() -> void:
	if not _connected:
		_client.disconnect_client()
		return

	var token := _active_token
	_active_token += 1
	_connected = false
	_client.disconnect_client()
	_active_turns_by_session.clear()
	_refresh_busy()
	_emit_session_closed_once(token)


func query(prompt, session_id: String = "default") -> void:
	_client.query(prompt, session_id)
	if not _client.get_last_error().is_empty():
		return
	_begin_turn_watch(prompt, session_id)


func interrupt() -> void:
	_client.interrupt()


func set_permission_mode(mode: String) -> void:
	_client.set_permission_mode(mode)


func set_model(model = null) -> void:
	_client.set_model(model)


func get_server_info() -> Dictionary:
	return _client.get_server_info()


func get_auth_status() -> Dictionary:
	var result: Dictionary = _client.get_auth_status()
	var error_message := str(result.get("error_message", ""))
	_last_error = error_message
	return result


func list_sessions(
	directory: String = "",
	limit: int = 0,
	offset: int = 0,
	include_worktrees: bool = true
) -> Array[ClaudeSessionInfo]:
	return ClaudeSessionsScript.list_sessions(directory, limit, offset, include_worktrees)


func get_session_info(session_id: String, directory: String = ""):
	return ClaudeSessionsScript.get_session_info(session_id, directory)


func get_session_messages(
	session_id: String,
	directory: String = "",
	limit: int = 0,
	offset: int = 0
) -> Array[ClaudeSessionMessage]:
	return ClaudeSessionsScript.get_session_messages(session_id, directory, limit, offset)


func list_subagents(session_id: String, directory: String = "") -> Array[String]:
	return ClaudeSessionsScript.list_subagents(session_id, directory)


func get_subagent_messages(
	session_id: String,
	agent_id: String,
	directory: String = "",
	limit: int = 0,
	offset: int = 0
) -> Array[ClaudeSessionMessage]:
	return ClaudeSessionsScript.get_subagent_messages(session_id, agent_id, directory, limit, offset)


func get_session_transcript(
	session_id: String,
	directory: String = "",
	limit: int = 0,
	offset: int = 0
) -> Array[ClaudeSessionTranscriptEntry]:
	return ClaudeSessionsScript.get_session_transcript(session_id, directory, limit, offset)


func rename_session(session_id: String, title: String, directory: String = "") -> int:
	return _handle_session_mutation_result(ClaudeSessionsScript.rename_session(session_id, title, directory))


func tag_session(session_id: String, tag: Variant = null, directory: String = "") -> int:
	return _handle_session_mutation_result(ClaudeSessionsScript.tag_session(session_id, tag, directory))


func delete_session(session_id: String, directory: String = "") -> int:
	return _handle_session_mutation_result(ClaudeSessionsScript.delete_session(session_id, directory))


func fork_session(
	session_id: String,
	directory: String = "",
	up_to_message_id: String = "",
	title: String = ""
):
	var result = ClaudeSessionsScript.fork_session(session_id, directory, up_to_message_id, title)
	if result != null:
		_last_error = ""
		return result
	_emit_error(ClaudeSessionsScript.get_last_error())
	return null


func get_context_usage():
	return await _client.get_context_usage()


func get_mcp_status():
	return await _client.get_mcp_status()


func rewind_files(user_message_id: String) -> void:
	await _client.rewind_files(user_message_id)


func stop_task(task_id: String) -> void:
	await _client.stop_task(task_id)


func reconnect_mcp_server(server_name: String) -> void:
	await _client.reconnect_mcp_server(server_name)


func toggle_mcp_server(server_name: String, enabled: bool) -> void:
	await _client.toggle_mcp_server(server_name, enabled)


func get_last_error() -> String:
	if not _last_error.is_empty():
		return _last_error
	var client_error: String = _client.get_last_error()
	if not client_error.is_empty():
		return client_error
	return ""


func is_client_connected() -> bool:
	return _connected


func is_busy() -> bool:
	return _busy


func is_session_busy(session_id: String) -> bool:
	return not _active_turn_queue(session_id).is_empty()


func _run_message_drain(token: int, stream) -> void:
	if token != _active_token:
		return

	while token == _active_token:
		var message: Variant = await stream.next_message()
		if token != _active_token:
			return
		if message == null:
			break

		message_received.emit(message)
		var active_turn_session_id := _active_turn_session_key_for_message(message)
		if not active_turn_session_id.is_empty():
			turn_message_received.emit(message)
			if _message_session_id(message).is_empty():
				turn_message_received_for_session.emit(
					message,
					_session_reference_id_for_routed_message(active_turn_session_id, message)
				)
			if message is ClaudeResultMessage:
				_clear_active_turn(active_turn_session_id)
				turn_finished.emit(message)

	if token != _active_token:
		return

	_connected = false
	_active_turns_by_session.clear()
	_refresh_busy()
	_emit_session_closed_once(token)


func _watch_turn_response(connection_token: int, session_id: String, turn_token: int, response_stream) -> void:
	var saw_result := false
	while (
		connection_token == _active_token
		and _has_matching_turn_token(session_id, turn_token)
	):
		var message: Variant = await response_stream.next_message()
		if connection_token != _active_token or not _has_matching_turn_token(session_id, turn_token):
			return
		if message == null:
			if not saw_result:
				_clear_active_turn(session_id, turn_token)
			return
		if message is ClaudeResultMessage:
			saw_result = true


func _begin_turn_watch(prompt, session_id: String) -> void:
	_turn_watch_counter += 1
	var turn_token := _turn_watch_counter
	var queue := _active_turn_queue(session_id)
	queue.append({
		"turn_token": turn_token,
		"promoted_session_id": "",
	})
	_active_turns_by_session[session_id] = queue
	_refresh_busy()
	if prompt is String:
		turn_started.emit(str(prompt), session_id)
	var response_stream = _client.receive_response_for_session(session_id)
	Callable(self, "_watch_turn_response").call_deferred(_active_token, session_id, turn_token, response_stream)


func _emit_session_closed_once(token: int) -> void:
	if _closed_token == token:
		return
	_closed_token = token
	session_closed.emit()


func _on_client_session_initialized(server_info: Dictionary) -> void:
	if not _connected or _session_ready_emitted:
		return
	_session_ready_emitted = true
	session_ready.emit(server_info.duplicate(true))


func _on_client_error_occurred(message: String) -> void:
	_emit_error(message)


func _emit_error(message: String) -> void:
	if message.is_empty():
		return
	_last_error = message
	error_occurred.emit(message)


func _handle_session_mutation_result(result: int) -> int:
	if result == OK:
		_last_error = ""
		return OK
	_emit_error(ClaudeSessionsScript.get_last_error())
	return result


func _refresh_busy() -> void:
	var next_busy := false
	for session_id_variant in _active_turns_by_session.keys():
		if not _active_turn_queue(str(session_id_variant)).is_empty():
			next_busy = true
			break
	if _busy == next_busy:
		return
	_busy = next_busy
	busy_changed.emit(_busy)


func _has_matching_turn_token(session_id: String, turn_token: int) -> bool:
	for turn_state_variant in _active_turn_queue(session_id):
		if turn_state_variant is not Dictionary:
			continue
		var turn_state := turn_state_variant as Dictionary
		if int(turn_state.get("turn_token", -1)) == turn_token:
			return true
	return false


func _clear_active_turn(session_id: String, turn_token: int = -1) -> void:
	if session_id.is_empty():
		return
	var queue := _active_turn_queue(session_id)
	if queue.is_empty():
		return
	if turn_token == -1:
		queue.pop_front()
	else:
		var removed := false
		for index in range(queue.size()):
			if queue[index] is not Dictionary:
				continue
			var turn_state := queue[index] as Dictionary
			if int(turn_state.get("turn_token", -1)) != turn_token:
				continue
			queue.remove_at(index)
			removed = true
			break
		if not removed:
			return
	if queue.is_empty():
		_active_turns_by_session.erase(session_id)
	else:
		_active_turns_by_session[session_id] = queue
	_refresh_busy()


func _message_session_id(message: Variant) -> String:
	if message == null:
		return ""
	if message is Object:
		var raw_data: Variant = message.get("raw_data")
		if raw_data is Dictionary and (raw_data as Dictionary).has("session_id"):
			return str((raw_data as Dictionary).get("session_id", ""))
		var session_id: Variant = message.get("session_id")
		if session_id != null:
			return str(session_id)
	return ""


func _is_message_for_active_turn(message: Variant) -> bool:
	return not _active_turn_session_key_for_message(message).is_empty()


func _active_turn_session_key_for_message(message: Variant) -> String:
	var session_id := _message_session_id(message)
	if session_id.is_empty():
		return _fallback_active_turn_session_key_for_unlabeled_message()
	if not _active_turn_queue(session_id).is_empty():
		return session_id
	if session_id != "default":
		var default_turn_state := _head_turn_state("default")
		if not default_turn_state.is_empty():
			var promoted_session_id := str(default_turn_state.get("promoted_session_id", ""))
			if promoted_session_id == session_id:
				return "default"
			if promoted_session_id.is_empty() and _can_promote_default_turn_to_session(session_id):
				default_turn_state["promoted_session_id"] = session_id
				_replace_head_turn_state("default", default_turn_state)
				return "default"
	return ""


func _fallback_active_turn_session_key_for_unlabeled_message() -> String:
	var active_session_count := 0
	var active_session_id := ""
	for session_id_variant in _active_turns_by_session.keys():
		var session_id := str(session_id_variant)
		if _active_turn_queue(session_id).is_empty():
			continue
		active_session_count += 1
		active_session_id = session_id
	if active_session_count != 1:
		return ""
	return active_session_id


func _session_reference_id_for_routed_message(active_turn_session_id: String, message: Variant) -> String:
	if active_turn_session_id != "default":
		return active_turn_session_id
	var message_session_id := _message_session_id(message)
	if not message_session_id.is_empty() and message_session_id != "default":
		return message_session_id
	var default_turn_state := _head_turn_state("default")
	var promoted_session_id := str(default_turn_state.get("promoted_session_id", ""))
	if not promoted_session_id.is_empty():
		return promoted_session_id
	return active_turn_session_id


func _can_promote_default_turn_to_session(session_id: String) -> bool:
	if session_id.is_empty() or session_id == "default":
		return false
	if _head_turn_state("default").is_empty():
		return false
	return not _is_session_claimed_by_non_default_turn(session_id)


func _is_session_claimed_by_non_default_turn(session_id: String) -> bool:
	for active_session_id_variant in _active_turns_by_session.keys():
		var active_session_id := str(active_session_id_variant)
		if active_session_id == "default":
			continue
		if active_session_id == session_id:
			return true
		for active_turn_state_variant in _active_turn_queue(active_session_id):
			if active_turn_state_variant is not Dictionary:
				continue
			var active_turn_state := active_turn_state_variant as Dictionary
			if str(active_turn_state.get("promoted_session_id", "")) == session_id:
				return true
	return false


func _active_turn_queue(session_id: String) -> Array:
	return _active_turns_by_session.get(session_id, []) if _active_turns_by_session.get(session_id, []) is Array else []


func _head_turn_state(session_id: String) -> Dictionary:
	var queue := _active_turn_queue(session_id)
	if queue.is_empty():
		return {}
	return queue[0] as Dictionary if queue[0] is Dictionary else {}


func _replace_head_turn_state(session_id: String, turn_state: Dictionary) -> void:
	var queue := _active_turn_queue(session_id)
	if queue.is_empty():
		return
	queue[0] = turn_state
	_active_turns_by_session[session_id] = queue
