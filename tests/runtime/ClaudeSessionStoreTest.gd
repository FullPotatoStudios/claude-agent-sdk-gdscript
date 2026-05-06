# GdUnit generated TestSuite
extends GdUnitTestSuite

const ClaudeSessionsScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_sessions.gd")
const ClaudeSessionStoreScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_session_store.gd")
const ClaudeInMemorySessionStoreScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_in_memory_session_store.gd")
const ClaudeOnDiskSessionStoreScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_on_disk_session_store.gd")
const ClaudeSessionKeyScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_session_key.gd")
const ClaudeSessionListSubkeysKeyScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_session_list_subkeys_key.gd")
const ClaudeSessionStoreListEntryScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_session_store_list_entry.gd")
const ClaudeSessionSummaryEntryScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_session_summary_entry.gd")

var _created_roots: Array[String] = []


func after_test() -> void:
	for root_path in _created_roots:
		_delete_tree(root_path)
	_created_roots.clear()
	OS.set_environment("CLAUDE_CONFIG_DIR", "")


func test_session_key_round_trip_and_canonical_string() -> void:
	var key := ClaudeSessionKeyScript.new("proj-a", "550e8400-e29b-41d4-a716-446655440000")
	assert_str(key.to_canonical_string()).is_equal("proj-a/550e8400-e29b-41d4-a716-446655440000")
	assert_dict(key.to_dictionary()).is_equal({
		"project_key": "proj-a",
		"session_id": "550e8400-e29b-41d4-a716-446655440000",
	})

	var key_with_subpath := ClaudeSessionKeyScript.new("proj-a", "session-1", "subagents/agent-x")
	assert_str(key_with_subpath.to_canonical_string()).is_equal("proj-a/session-1/subagents/agent-x")
	assert_dict(key_with_subpath.to_dictionary()).is_equal({
		"project_key": "proj-a",
		"session_id": "session-1",
		"subpath": "subagents/agent-x",
	})

	var rebuilt := ClaudeSessionKeyScript.from_dictionary(key_with_subpath.to_dictionary())
	assert_bool(rebuilt.equals(key_with_subpath)).is_true()
	assert_bool(rebuilt.equals(key)).is_false()


func test_abstract_base_clears_last_error_on_init_and_reports_capability_messages() -> void:
	var store := ClaudeSessionStoreScript.new()
	assert_str(store.get_last_error()).is_equal("")
	assert_int(store.capabilities()).is_equal(0)
	assert_bool(store.is_blocking_safe()).is_true()

	# Optional methods report capability_not_implemented and return the documented sentinels.
	var delete_result: int = store.delete(ClaudeSessionKeyScript.new("p", "s"))
	assert_int(delete_result).is_equal(ERR_UNAVAILABLE)
	assert_str(store.get_last_error()).contains("capability not implemented")

	var listed: Array = store.list_sessions("p")
	assert_array(listed).is_empty()
	assert_str(store.get_last_error()).contains("capability not implemented")

	var summaries: Array = store.list_session_summaries("p")
	assert_array(summaries).is_empty()
	assert_str(store.get_last_error()).contains("capability not implemented")

	var subkeys: Array = store.list_subkeys(ClaudeSessionListSubkeysKeyScript.new("p", "s"))
	assert_array(subkeys).is_empty()
	assert_str(store.get_last_error()).contains("capability not implemented")


func test_in_memory_store_reports_full_capability_surface() -> void:
	var store := ClaudeInMemorySessionStoreScript.new()
	var expected_caps := (
		ClaudeSessionStoreScript.CAP_LIST_SESSIONS
		| ClaudeSessionStoreScript.CAP_LIST_SUMMARIES
		| ClaudeSessionStoreScript.CAP_LIST_SUBKEYS
		| ClaudeSessionStoreScript.CAP_DELETE
	)
	assert_int(store.capabilities()).is_equal(expected_caps)
	assert_bool(store.is_blocking_safe()).is_true()


func test_in_memory_store_append_and_load_round_trip() -> void:
	var store := ClaudeInMemorySessionStoreScript.new()
	var key := ClaudeSessionKeyScript.new("proj-a", "session-1")
	var entry_a: Dictionary = {"type": "user", "session_id": "session-1", "message": {"content": "hello"}}
	var entry_b: Dictionary = {"type": "assistant", "session_id": "session-1", "message": {"content": "hi"}}

	assert_int(store.append(key, [entry_a])).is_equal(OK)
	assert_int(store.append(key, [entry_b])).is_equal(OK)

	var loaded: Array = store.load(key)
	assert_int(loaded.size()).is_equal(2)
	assert_dict(loaded[0]).is_equal(entry_a)
	assert_dict(loaded[1]).is_equal(entry_b)

	# load returns defensive copies — mutating the result must not affect the store.
	(loaded[0] as Dictionary)["mutated"] = true
	var loaded_again: Array = store.load(key)
	assert_bool((loaded_again[0] as Dictionary).has("mutated")).is_false()


func test_in_memory_store_isolates_keys_and_lists_only_matching_project() -> void:
	var store := ClaudeInMemorySessionStoreScript.new()
	var key_a := ClaudeSessionKeyScript.new("proj-a", "session-1")
	var key_b := ClaudeSessionKeyScript.new("proj-b", "session-2")

	store.append(key_a, [{"type": "user", "data": "a"}])
	store.append(key_b, [{"type": "user", "data": "b"}])

	assert_int((store.load(key_a) as Array).size()).is_equal(1)
	assert_int((store.load(key_b) as Array).size()).is_equal(1)

	var listed_a: Array = store.list_sessions("proj-a")
	assert_int(listed_a.size()).is_equal(1)
	assert_str((listed_a[0] as ClaudeSessionStoreListEntry).session_id).is_equal("session-1")

	var listed_b: Array = store.list_sessions("proj-b")
	assert_int(listed_b.size()).is_equal(1)
	assert_str((listed_b[0] as ClaudeSessionStoreListEntry).session_id).is_equal("session-2")

	var listed_missing: Array = store.list_sessions("proj-missing")
	assert_array(listed_missing).is_empty()


func test_in_memory_store_mtime_is_strictly_monotonic() -> void:
	var store := ClaudeInMemorySessionStoreScript.new()
	var key_a := ClaudeSessionKeyScript.new("proj-a", "session-a")
	var key_b := ClaudeSessionKeyScript.new("proj-a", "session-b")
	for i in range(5):
		store.append(key_a, [{"type": "user", "i": i}])
		store.append(key_b, [{"type": "user", "i": i}])

	var summaries: Array = store.list_session_summaries("proj-a")
	assert_int(summaries.size()).is_equal(2)
	assert_int((summaries[0] as ClaudeSessionSummaryEntry).mtime).is_greater((summaries[1] as ClaudeSessionSummaryEntry).mtime)


func test_in_memory_store_delete_removes_entries_and_subkeys() -> void:
	var store := ClaudeInMemorySessionStoreScript.new()
	var key := ClaudeSessionKeyScript.new("proj-a", "session-1")
	var subkey := ClaudeSessionKeyScript.new("proj-a", "session-1", "subagents/agent-x")
	store.append(key, [{"type": "user", "data": "main"}])
	store.append(subkey, [{"type": "user", "data": "sub"}])

	var subkeys: Array = store.list_subkeys(ClaudeSessionListSubkeysKeyScript.new("proj-a", "session-1"))
	assert_array(subkeys).contains_exactly(["subagents/agent-x"])

	assert_int(store.delete(key)).is_equal(OK)
	assert_array(store.load(key)).is_empty()
	assert_array(store.load(subkey)).is_empty()
	assert_array(store.list_sessions("proj-a")).is_empty()


func test_in_memory_store_delete_subkey_only_removes_subkey() -> void:
	var store := ClaudeInMemorySessionStoreScript.new()
	var key := ClaudeSessionKeyScript.new("proj-a", "session-1")
	var subkey := ClaudeSessionKeyScript.new("proj-a", "session-1", "subagents/agent-x")
	store.append(key, [{"type": "user", "data": "main"}])
	store.append(subkey, [{"type": "user", "data": "sub"}])

	assert_int(store.delete(subkey)).is_equal(OK)
	assert_int((store.load(key) as Array).size()).is_equal(1)
	assert_array(store.load(subkey)).is_empty()


func test_in_memory_store_size_clear_and_get_entries_helpers() -> void:
	var store := ClaudeInMemorySessionStoreScript.new()
	var key := ClaudeSessionKeyScript.new("proj-a", "session-1")
	store.append(key, [{"type": "user"}, {"type": "assistant"}])
	assert_int(store.size()).is_equal(2)
	assert_int((store.get_entries(key) as Array).size()).is_equal(2)
	store.clear()
	assert_int(store.size()).is_equal(0)
	assert_array(store.list_sessions("proj-a")).is_empty()


func test_on_disk_store_append_and_load_round_trip() -> void:
	var config_root := _create_config_root("on-disk-roundtrip")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)
	var project_path := "/tmp/on-disk-roundtrip"
	_make_project_dir(config_root, project_path)
	var project_key := ClaudeSessionsScript.project_key_for_directory(project_path)
	assert_bool(project_key.is_empty()).is_false()

	var store := ClaudeOnDiskSessionStoreScript.new()
	var session_id := "11111111-1111-4111-8111-111111111111"
	var key := ClaudeSessionKeyScript.new(project_key, session_id)
	var entry: Dictionary = {"type": "user", "sessionId": session_id, "message": {"content": "hello"}}

	assert_int(store.append(key, [entry])).is_equal(OK)
	var loaded: Array = store.load(key)
	assert_int(loaded.size()).is_equal(1)
	assert_dict(loaded[0]).is_equal(entry)


func test_on_disk_store_lists_sessions_filtered_by_project() -> void:
	var config_root := _create_config_root("on-disk-list")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)
	var project_a := "/tmp/on-disk-list-a"
	var project_b := "/tmp/on-disk-list-b"
	_make_project_dir(config_root, project_a)
	_make_project_dir(config_root, project_b)
	var key_a := ClaudeSessionsScript.project_key_for_directory(project_a)
	var key_b := ClaudeSessionsScript.project_key_for_directory(project_b)
	var store := ClaudeOnDiskSessionStoreScript.new()
	store.append(ClaudeSessionKeyScript.new(key_a, "22222222-2222-4222-8222-222222222222"), [{"type": "user"}])
	store.append(ClaudeSessionKeyScript.new(key_b, "33333333-3333-4333-8333-333333333333"), [{"type": "user"}])

	var listed_a: Array = store.list_sessions(key_a)
	assert_int(listed_a.size()).is_equal(1)
	assert_str((listed_a[0] as ClaudeSessionStoreListEntry).session_id).is_equal("22222222-2222-4222-8222-222222222222")

	var listed_b: Array = store.list_sessions(key_b)
	assert_int(listed_b.size()).is_equal(1)
	assert_str((listed_b[0] as ClaudeSessionStoreListEntry).session_id).is_equal("33333333-3333-4333-8333-333333333333")


func test_on_disk_store_summaries_have_empty_data() -> void:
	var config_root := _create_config_root("on-disk-summaries")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)
	var project_path := "/tmp/on-disk-summaries"
	_make_project_dir(config_root, project_path)
	var project_key := ClaudeSessionsScript.project_key_for_directory(project_path)
	var store := ClaudeOnDiskSessionStoreScript.new()
	store.append(ClaudeSessionKeyScript.new(project_key, "44444444-4444-4444-8444-444444444444"), [{"type": "user"}])

	var summaries: Array = store.list_session_summaries(project_key)
	assert_int(summaries.size()).is_equal(1)
	var summary: ClaudeSessionSummaryEntry = summaries[0]
	assert_str(summary.session_id).is_equal("44444444-4444-4444-8444-444444444444")
	assert_dict(summary.data).is_empty()


func test_on_disk_store_delete_removes_session_and_subagents() -> void:
	var config_root := _create_config_root("on-disk-delete")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)
	var project_path := "/tmp/on-disk-delete"
	_make_project_dir(config_root, project_path)
	var project_key := ClaudeSessionsScript.project_key_for_directory(project_path)
	var store := ClaudeOnDiskSessionStoreScript.new()
	var session_id := "55555555-5555-4555-8555-555555555555"
	var key := ClaudeSessionKeyScript.new(project_key, session_id)
	var subkey := ClaudeSessionKeyScript.new(project_key, session_id, "subagents/agent-1")
	store.append(key, [{"type": "user"}])
	store.append(subkey, [{"type": "user"}])

	var subkeys: Array = store.list_subkeys(ClaudeSessionListSubkeysKeyScript.new(project_key, session_id))
	assert_array(subkeys).contains(["subagents/agent-1"])

	assert_int(store.delete(key)).is_equal(OK)
	assert_array(store.load(key)).is_empty()
	assert_array(store.load(subkey)).is_empty()


func test_on_disk_store_delete_returns_does_not_exist_for_missing_session() -> void:
	var config_root := _create_config_root("on-disk-delete-missing")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)
	var project_path := "/tmp/on-disk-delete-missing"
	_make_project_dir(config_root, project_path)
	var project_key := ClaudeSessionsScript.project_key_for_directory(project_path)
	var store := ClaudeOnDiskSessionStoreScript.new()
	var key := ClaudeSessionKeyScript.new(project_key, "66666666-6666-4666-8666-666666666666")
	assert_int(store.delete(key)).is_equal(ERR_DOES_NOT_EXIST)
	assert_str(store.get_last_error()).contains("does not exist")


func test_on_disk_store_rejects_path_traversal_in_project_key() -> void:
	var config_root := _create_config_root("on-disk-traversal-project")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)
	var store := ClaudeOnDiskSessionStoreScript.new()
	var session_id := "77777777-7777-4777-8777-777777777777"
	var malicious := ClaudeSessionKeyScript.new("../escape", session_id)
	assert_int(store.append(malicious, [{"type": "user"}])).is_equal(ERR_INVALID_PARAMETER)
	assert_str(store.get_last_error()).contains("project_key")
	assert_int(store.delete(malicious)).is_equal(ERR_INVALID_PARAMETER)


func test_on_disk_store_rejects_path_separators_in_project_key() -> void:
	var store := ClaudeOnDiskSessionStoreScript.new()
	var session_id := "88888888-8888-4888-8888-888888888888"
	var with_slash := ClaudeSessionKeyScript.new("project/escape", session_id)
	assert_int(store.append(with_slash, [{"type": "user"}])).is_equal(ERR_INVALID_PARAMETER)
	assert_array(store.list_sessions("project/escape")).is_empty()


func test_on_disk_store_rejects_invalid_session_id() -> void:
	var config_root := _create_config_root("on-disk-bad-session-id")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)
	var project_path := "/tmp/on-disk-bad-session-id"
	_make_project_dir(config_root, project_path)
	var project_key := ClaudeSessionsScript.project_key_for_directory(project_path)
	var store := ClaudeOnDiskSessionStoreScript.new()
	var key := ClaudeSessionKeyScript.new(project_key, "../etc/passwd")
	assert_int(store.append(key, [{"type": "user"}])).is_equal(ERR_INVALID_PARAMETER)
	assert_str(store.get_last_error()).contains("session_id")


func test_on_disk_store_rejects_path_traversal_in_subpath() -> void:
	var config_root := _create_config_root("on-disk-traversal-subpath")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)
	var project_path := "/tmp/on-disk-traversal-subpath"
	_make_project_dir(config_root, project_path)
	var project_key := ClaudeSessionsScript.project_key_for_directory(project_path)
	var store := ClaudeOnDiskSessionStoreScript.new()
	var session_id := "99999999-9999-4999-8999-999999999999"
	var key := ClaudeSessionKeyScript.new(project_key, session_id, "subagents/../../escape")
	assert_int(store.append(key, [{"type": "user"}])).is_equal(ERR_INVALID_PARAMETER)
	assert_str(store.get_last_error()).contains("subpath")


# --- Helpers (mirrors ClaudeSessionsTest.gd conventions) ---

func _create_config_root(label: String) -> String:
	var root_path := _create_temp_root("claude-config-%s" % label)
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
