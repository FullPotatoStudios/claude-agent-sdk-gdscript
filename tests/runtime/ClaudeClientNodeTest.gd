# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")
const ClaudeClientNodeScript := preload("res://addons/claude_agent_sdk/runtime/adapters/claude_client_node.gd")
const ClaudeSessionsScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_sessions.gd")
const ClaudeResultMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_result_message.gd")

var _created_roots: Array[String] = []
var _async_completions: Array[String] = []


func after_test() -> void:
	for root_path in _created_roots:
		_delete_tree(root_path)
	_created_roots.clear()
	_async_completions.clear()
	OS.set_environment("CLAUDE_CONFIG_DIR", "")


func test_node_defaults_auto_connect_off_and_reemits_adapter_signals() -> void:
	var transport = FakeTransportScript.new()
	var node = ClaudeClientNodeScript.new(ClaudeAgentOptions.new(), transport)
	var ready_events: Array[int] = []
	var turn_finished_messages: Array = []

	node.session_ready.connect(func(_server_info): ready_events.append(1))
	node.turn_finished.connect(func(message): turn_finished_messages.append(message))

	get_tree().root.add_child(node)
	await get_tree().process_frame
	assert_bool(transport.connected).is_false()

	node.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"output_style": "default"},
		},
	})
	await _await_frames(2)

	node.query("Hi")
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "ok",
	})
	await _await_frames(2)

	assert_int(ready_events.size()).is_equal(1)
	assert_int(turn_finished_messages.size()).is_equal(1)
	assert_object(turn_finished_messages[0]).is_instanceof(ClaudeResultMessageScript)

	node.disconnect_client()
	await _await_frames(2)
	get_tree().root.remove_child(node)
	node.queue_free()
	await _await_frames(2)


func test_node_connect_with_prompt_reemits_adapter_turn_signals() -> void:
	var transport = FakeTransportScript.new()
	var node = ClaudeClientNodeScript.new(ClaudeAgentOptions.new(), transport)
	var busy_events: Array[bool] = []
	var turn_starts: Array = []
	var turn_finished_messages: Array = []

	node.busy_changed.connect(func(is_busy: bool): busy_events.append(is_busy))
	node.turn_started.connect(func(prompt: String, session_id: String): turn_starts.append({"prompt": prompt, "session_id": session_id}))
	node.turn_finished.connect(func(message): turn_finished_messages.append(message))

	get_tree().root.add_child(node)
	await get_tree().process_frame

	node.connect_client("Node prompt")
	assert_bool(node.is_busy()).is_true()
	assert_array(busy_events).is_equal([true])
	assert_array(turn_starts).is_equal([{"prompt": "Node prompt", "session_id": "default"}])

	var init_request := _read_last_write(transport)
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
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "ok",
	})
	await _await_frames(2)

	assert_bool(node.is_busy()).is_false()
	assert_array(busy_events).is_equal([true, false])
	assert_int(turn_finished_messages.size()).is_equal(1)

	node.disconnect_client()
	await _await_frames(2)
	get_tree().root.remove_child(node)
	node.queue_free()
	await _await_frames(2)


func test_node_exposes_session_busy_passthrough_for_overlapping_turns() -> void:
	var transport = FakeTransportScript.new()
	var node = ClaudeClientNodeScript.new(ClaudeAgentOptions.new(), transport)

	get_tree().root.add_child(node)
	await get_tree().process_frame

	node.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	node.query("A", "session-a")
	node.query("B", "session-b")
	await _await_frames(1)

	assert_bool(node.is_busy()).is_true()
	assert_bool(node.is_session_busy("session-a")).is_true()
	assert_bool(node.is_session_busy("session-b")).is_true()

	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "session-a",
		"result": "done-a",
	})
	await _await_frames(2)

	assert_bool(node.is_busy()).is_true()
	assert_bool(node.is_session_busy("session-a")).is_false()
	assert_bool(node.is_session_busy("session-b")).is_true()

	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "session-b",
		"result": "done-b",
	})
	await _await_frames(2)

	assert_bool(node.is_busy()).is_false()
	assert_bool(node.is_session_busy("session-b")).is_false()

	node.disconnect_client()
	await _await_frames(2)
	get_tree().root.remove_child(node)
	node.queue_free()
	await _await_frames(2)


func test_node_reconnect_reemits_ready_and_prompt_turn_signals() -> void:
	var transport = FakeTransportScript.new()
	var node = ClaudeClientNodeScript.new(ClaudeAgentOptions.new(), transport)
	var ready_events: Array[Dictionary] = []
	var closed_events: Array[int] = []
	var busy_events: Array[bool] = []
	var turn_starts: Array = []

	node.session_ready.connect(func(server_info: Dictionary): ready_events.append(server_info))
	node.session_closed.connect(func(): closed_events.append(1))
	node.busy_changed.connect(func(is_busy: bool): busy_events.append(is_busy))
	node.turn_started.connect(func(prompt: String, session_id: String): turn_starts.append({"prompt": prompt, "session_id": session_id}))

	get_tree().root.add_child(node)
	await get_tree().process_frame

	node.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/help"}]},
		},
	})
	await _await_frames(2)

	node.connect_client("Reconnect prompt")
	assert_int(closed_events.size()).is_equal(1)
	init_request = _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/retry"}]},
		},
	})
	await _await_frames(1)
	transport.emit_stdout_message({
		"type": "result",
		"subtype": "success",
		"duration_ms": 10,
		"duration_api_ms": 5,
		"is_error": false,
		"num_turns": 1,
		"session_id": "default",
		"result": "done",
	})
	await _await_frames(2)

	assert_int(ready_events.size()).is_equal(2)
	assert_array(turn_starts).is_equal([{"prompt": "Reconnect prompt", "session_id": "default"}])
	assert_array(busy_events).is_equal([true, false])

	node.disconnect_client()
	await _await_frames(2)
	get_tree().root.remove_child(node)
	node.queue_free()
	await _await_frames(2)


func test_node_auto_disconnects_on_exit_when_enabled() -> void:
	var transport = FakeTransportScript.new()
	var node = ClaudeClientNodeScript.new(ClaudeAgentOptions.new(), transport)
	node.auto_connect_on_ready = true

	get_tree().root.add_child(node)
	await get_tree().process_frame
	assert_bool(transport.connected).is_true()

	get_tree().root.remove_child(node)
	await get_tree().process_frame

	assert_bool(transport.connected).is_false()
	node.queue_free()
	await _await_frames(2)


func test_node_exposes_session_passthrough_methods() -> void:
	var config_root := _create_config_root("node-sessions")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_path := "/tmp/node-session-project"
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "32323232-3232-4323-8323-323232323232"
	_write_session_file(project_dir, session_id, [
		{
			"type": "user",
			"uuid": "node-u-1",
			"sessionId": session_id,
			"cwd": project_path,
			"message": {"role": "user", "content": "Node prompt"},
		},
		{"type": "summary", "summary": "Node summary"},
	], 1712302100)

	var node = ClaudeClientNodeScript.new(ClaudeAgentOptions.new(), FakeTransportScript.new())
	get_tree().root.add_child(node)
	await get_tree().process_frame

	var sessions := node.list_sessions(project_path, 0, 0, false)
	assert_int(sessions.size()).is_equal(1)
	assert_int(node.rename_session(session_id, "Node renamed", project_path)).is_equal(OK)
	var transcript := node.get_session_transcript(session_id, project_path)
	assert_int(transcript.size()).is_equal(1)
	assert_str(transcript[0].kind).is_equal("user")
	var fork_result = node.fork_session(session_id, project_path, "", "Node fork")
	assert_object(fork_result).is_not_null()
	if fork_result != null:
		var fork_info = node.get_session_info(fork_result.session_id, project_path)
		assert_object(fork_info).is_not_null()
		if fork_info != null:
			assert_str(fork_info.custom_title).is_equal("Node fork")

	var info = node.get_session_info(session_id, project_path)
	assert_object(info).is_not_null()
	if info != null:
		assert_str(info.summary).is_equal("Node renamed")

	get_tree().root.remove_child(node)
	node.queue_free()
	await _await_frames(2)


func _complete_node_rewind(node: ClaudeClientNode, user_message_id: String, label: String) -> void:
	await node.rewind_files(user_message_id)
	_async_completions.append(label)


func _complete_node_stop_task(node: ClaudeClientNode, task_id: String, label: String) -> void:
	await node.stop_task(task_id)
	_async_completions.append(label)


func test_node_rewind_files_passthroughs_to_runtime_client() -> void:
	var transport = FakeTransportScript.new()
	var node = ClaudeClientNodeScript.new(ClaudeAgentOptions.new(), transport)
	get_tree().root.add_child(node)
	await get_tree().process_frame

	node.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	Callable(self, "_complete_node_rewind").call_deferred(node, "node-user-1", "node-rewind")
	await _await_frames(1)
	var rewind_request := _read_last_write(transport)
	assert_str(str((rewind_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("rewind_files")
	assert_str(str((rewind_request.get("request", {}) as Dictionary).get("user_message_id", ""))).is_equal("node-user-1")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(rewind_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	assert_array(_async_completions).contains(["node-rewind"])
	node.disconnect_client()
	await _await_frames(2)
	get_tree().root.remove_child(node)
	node.queue_free()
	await _await_frames(2)


func test_node_stop_task_passthroughs_to_runtime_client() -> void:
	var transport = FakeTransportScript.new()
	var node = ClaudeClientNodeScript.new(ClaudeAgentOptions.new(), transport)
	get_tree().root.add_child(node)
	await get_tree().process_frame

	node.connect_client()
	var init_request := _read_last_write(transport)
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(init_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	Callable(self, "_complete_node_stop_task").call_deferred(node, "task-abc123", "node-stop-task")
	await _await_frames(1)
	var stop_request := _read_last_write(transport)
	assert_str(str((stop_request.get("request", {}) as Dictionary).get("subtype", ""))).is_equal("stop_task")
	assert_str(str((stop_request.get("request", {}) as Dictionary).get("task_id", ""))).is_equal("task-abc123")
	transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(stop_request.get("request_id", "")),
			"response": {},
		},
	})
	await _await_frames(1)

	assert_array(_async_completions).contains(["node-stop-task"])
	node.disconnect_client()
	await _await_frames(2)
	get_tree().root.remove_child(node)
	node.queue_free()
	await _await_frames(2)


func _await_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _read_last_write(transport) -> Dictionary:
	return JSON.parse_string(transport.writes[-1])


func _create_config_root(label: String) -> String:
	var root_path := _create_temp_root("node-config-%s" % label)
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
