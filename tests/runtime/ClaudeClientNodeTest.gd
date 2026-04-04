# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")
const ClaudeClientNodeScript := preload("res://addons/claude_agent_sdk/runtime/adapters/claude_client_node.gd")
const ClaudeSessionsScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_sessions.gd")
const ClaudeResultMessageScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_result_message.gd")

var _created_roots: Array[String] = []


func after_test() -> void:
	for root_path in _created_roots:
		_delete_tree(root_path)
	_created_roots.clear()
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
		{"type": "user", "cwd": project_path, "message": {"content": "Node prompt"}},
		{"type": "summary", "summary": "Node summary"},
	], 1712302100)

	var node = ClaudeClientNodeScript.new(ClaudeAgentOptions.new(), FakeTransportScript.new())
	get_tree().root.add_child(node)
	await get_tree().process_frame

	var sessions := node.list_sessions(project_path, 0, 0, false)
	assert_int(sessions.size()).is_equal(1)
	assert_int(node.rename_session(session_id, "Node renamed", project_path)).is_equal(OK)

	var info = node.get_session_info(session_id, project_path)
	assert_object(info).is_not_null()
	if info != null:
		assert_str(info.summary).is_equal("Node renamed")

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
