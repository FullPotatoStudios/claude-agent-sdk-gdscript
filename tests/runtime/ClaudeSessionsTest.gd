# GdUnit generated TestSuite
extends GdUnitTestSuite

const ClaudeSessionsScript := preload("res://addons/claude_agent_sdk/runtime/sessions/claude_sessions.gd")

var _created_roots: Array[String] = []


func after_test() -> void:
	for root_path in _created_roots:
		_delete_tree(root_path)
	_created_roots.clear()
	OS.set_environment("CLAUDE_CONFIG_DIR", "")


func test_helpers_validate_uuid_sanitize_path_and_config_root_override() -> void:
	var config_root := _create_config_root("helpers")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	assert_bool(ClaudeSessionsScript._is_valid_uuid("550e8400-e29b-41d4-a716-446655440000")).is_true()
	assert_bool(ClaudeSessionsScript._is_valid_uuid("not-a-uuid")).is_false()
	assert_str(ClaudeSessionsScript._sanitize_path("/Users/foo/my-project")).is_equal("-Users-foo-my-project")
	assert_str(ClaudeSessionsScript._get_claude_config_home_dir()).is_equal(
		ClaudeSessionsScript._resolve_absolute_path(config_root)
	)

	var long_path := ""
	for _i in 150:
		long_path += "/x"
	var sanitized := ClaudeSessionsScript._sanitize_path(long_path)
	assert_bool(sanitized.length() > 200).is_true()
	assert_bool(sanitized.contains("-")).is_true()


func test_list_sessions_returns_empty_for_missing_or_invalid_directories() -> void:
	var config_root := _create_config_root("empty")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	assert_array(ClaudeSessions.list_sessions()).is_empty()
	assert_array(ClaudeSessions.list_sessions("relative/path")).is_empty()


func test_list_sessions_reads_all_projects_and_sorts_descending() -> void:
	var config_root := _create_config_root("list-all")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_a := "/tmp/project-a"
	var project_b := "/tmp/project-b"
	var project_a_dir := _make_project_dir(config_root, project_a)
	var project_b_dir := _make_project_dir(config_root, project_b)

	var old_session := "11111111-1111-4111-8111-111111111111"
	var new_session := "22222222-2222-4222-8222-222222222222"
	_write_session_file(project_a_dir, old_session, [
		{"type": "user", "timestamp": "2026-04-05T10:00:00", "cwd": project_a, "message": {"content": "Old prompt"}},
		{"type": "summary", "summary": "Old summary"},
	], 1712300000)
	_write_session_file(project_b_dir, new_session, [
		{"type": "user", "timestamp": "2026-04-05T11:00:00", "cwd": project_b, "message": {"content": "New prompt"}, "gitBranch": "main"},
		{"type": "summary", "summary": "New summary", "gitBranch": "main"},
	], 1712300100)

	var sessions := ClaudeSessions.list_sessions()

	assert_int(sessions.size()).is_equal(2)
	if sessions.size() < 2:
		return
	assert_str(sessions[0].session_id).is_equal(new_session)
	assert_str(sessions[1].session_id).is_equal(old_session)
	assert_str(str(sessions[0].git_branch)).is_equal("main")
	assert_int(int(sessions[0].created_at)).is_greater(0)


func test_list_sessions_supports_project_scoping_pagination_and_deduplication() -> void:
	var config_root := _create_config_root("project-scope")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_path := "/tmp/project-scope"
	var project_dir := _make_project_dir(config_root, project_path)
	var first_id := "33333333-3333-4333-8333-333333333333"
	var second_id := "44444444-4444-4444-8444-444444444444"

	_write_session_file(project_dir, first_id, [
		{"type": "user", "cwd": project_path, "message": {"content": "First prompt"}},
		{"type": "summary", "summary": "First summary"},
	], 1712300200)
	_write_session_file(project_dir, second_id, [
		{"type": "user", "cwd": project_path, "message": {"content": "Second prompt"}},
		{"type": "summary", "summary": "Second summary"},
	], 1712300300)

	var duplicate_project_path := "/tmp/another-project"
	var duplicate_project_dir := _make_project_dir(config_root, duplicate_project_path)
	_write_session_file(duplicate_project_dir, second_id, [
		{"type": "user", "cwd": duplicate_project_path, "message": {"content": "Duplicate prompt"}},
		{"type": "summary", "summary": "Duplicate summary"},
	], 1712300400)

	var scoped_sessions := ClaudeSessions.list_sessions(project_path, 0, 0, false)
	assert_int(scoped_sessions.size()).is_equal(2)

	var paged_sessions := ClaudeSessions.list_sessions("", 1, 1)
	assert_int(paged_sessions.size()).is_equal(1)
	if paged_sessions.is_empty():
		return
	assert_str(paged_sessions[0].session_id).is_equal(first_id)

	var all_sessions := ClaudeSessions.list_sessions()
	assert_int(all_sessions.size()).is_equal(2)
	if all_sessions.is_empty():
		return
	assert_str(all_sessions[0].summary).is_equal("Duplicate summary")


func test_list_sessions_excludes_sidechain_and_metadata_only_sessions() -> void:
	var config_root := _create_config_root("filters")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_path := "/tmp/filter-project"
	var project_dir := _make_project_dir(config_root, project_path)

	_write_session_file(project_dir, "55555555-5555-4555-8555-555555555555", [
		{"type": "user", "cwd": project_path, "isSidechain": true, "message": {"content": "sidechain"}},
		{"type": "summary", "summary": "ignored"},
	], 1712300500)
	_write_session_file(project_dir, "66666666-6666-4666-8666-666666666666", [
		{"type": "user", "cwd": project_path, "isMeta": true, "message": {"content": "meta"}},
	], 1712300600)
	_write_session_file(project_dir, "77777777-7777-4777-8777-777777777777", [
		{"type": "user", "cwd": project_path, "message": {"content": "real"}},
		{"type": "summary", "customTitle": "Visible session"},
	], 1712300700)

	var sessions := ClaudeSessions.list_sessions(project_path, 0, 0, false)

	assert_int(sessions.size()).is_equal(1)
	assert_str(sessions[0].summary).is_equal("Visible session")


func test_list_sessions_supports_worktree_toggle() -> void:
	var config_root := _create_config_root("worktree-list")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var repo_root := _create_temp_root("git-repo")
	var worktree_parent := _create_temp_root("git-worktree-parent")
	var worktree_root := worktree_parent.path_join("feature-session")
	_init_git_repo(repo_root)
	_create_git_worktree(repo_root, worktree_root, "feature/session")

	var repo_project_dir := _make_project_dir(config_root, repo_root)
	var worktree_project_dir := _make_project_dir(config_root, worktree_root)
	_write_session_file(repo_project_dir, "88888888-8888-4888-8888-888888888888", [
		{"type": "user", "cwd": repo_root, "message": {"content": "main"}},
		{"type": "summary", "summary": "Main worktree"},
	], 1712300800)
	_write_session_file(worktree_project_dir, "99999999-9999-4999-8999-999999999999", [
		{"type": "user", "cwd": worktree_root, "message": {"content": "feature"}},
		{"type": "summary", "summary": "Feature worktree"},
	], 1712300900)

	var single_tree := ClaudeSessions.list_sessions(repo_root, 0, 0, false)
	var all_worktrees := ClaudeSessions.list_sessions(repo_root, 0, 0, true)

	assert_int(single_tree.size()).is_equal(1)
	assert_int(all_worktrees.size()).is_equal(2)


func test_get_session_info_returns_null_for_invalid_or_missing_sessions() -> void:
	var config_root := _create_config_root("info-missing")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	assert_that(ClaudeSessions.get_session_info("not-a-uuid")).is_null()
	assert_that(ClaudeSessions.get_session_info("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")).is_null()


func test_get_session_info_reads_optional_fields_and_worktree_fallback() -> void:
	var config_root := _create_config_root("info-fields")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var repo_root := _create_temp_root("git-info-repo")
	var worktree_parent := _create_temp_root("git-info-worktree-parent")
	var worktree_root := worktree_parent.path_join("feature-info")
	_init_git_repo(repo_root)
	_create_git_worktree(repo_root, worktree_root, "feature/info")

	var session_id := "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
	var worktree_project_dir := _make_project_dir(config_root, worktree_root)
	_write_session_file(worktree_project_dir, session_id, [
		{"type": "user", "timestamp": "2026-04-05T12:00:00", "cwd": worktree_root, "gitBranch": "feature/info", "message": {"content": "Hello"}},
		{"type": "summary", "customTitle": "Named session", "gitBranch": "feature/info"},
		{"type": "tag", "tag": "review"},
	], 1712301000)

	var info = ClaudeSessions.get_session_info(session_id, repo_root)

	assert_object(info).is_not_null()
	if info == null:
		return
	assert_str(info.summary).is_equal("Named session")
	assert_str(str(info.cwd)).is_equal(worktree_root)
	assert_str(str(info.git_branch)).is_equal("feature/info")
	assert_str(str(info.tag)).is_equal("review")
	assert_int(int(info.file_size)).is_greater(0)


func test_get_session_messages_returns_visible_root_to_leaf_messages_with_pagination() -> void:
	var config_root := _create_config_root("messages")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_path := "/tmp/message-project"
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
	_write_session_file(project_dir, session_id, [
		{
			"type": "user",
			"uuid": "u-1",
			"sessionId": session_id,
			"timestamp": "2026-04-05T13:00:00",
			"message": {"role": "user", "content": "Hello"},
		},
		{
			"type": "assistant",
			"uuid": "a-1",
			"parentUuid": "u-1",
			"sessionId": session_id,
			"message": {"role": "assistant", "content": "Hi"},
		},
		{
			"type": "assistant",
			"uuid": "a-meta",
			"parentUuid": "a-1",
			"sessionId": session_id,
			"isMeta": true,
			"message": {"role": "assistant", "content": "ignore"},
		},
		{
			"type": "assistant",
			"uuid": "a-2",
			"parentUuid": "a-1",
			"sessionId": session_id,
			"isCompactSummary": true,
			"message": {"role": "assistant", "content": "Summary survives"},
		},
		{
			"type": "user",
			"uuid": "u-side",
			"parentUuid": "a-1",
			"sessionId": session_id,
			"isSidechain": true,
			"message": {"role": "user", "content": "ignore sidechain"},
		},
	], 1712301100)

	var messages := ClaudeSessions.get_session_messages(session_id, project_path)
	var paged_messages := ClaudeSessions.get_session_messages(session_id, project_path, 1, 1)

	assert_int(messages.size()).is_equal(3)
	assert_str(messages[0].type).is_equal("user")
	assert_str(messages[1].type).is_equal("assistant")
	assert_str(messages[2].uuid).is_equal("a-2")
	assert_str(str((messages[2].message as Dictionary).get("content"))).contains("Summary survives")
	assert_int(paged_messages.size()).is_equal(1)
	assert_str(paged_messages[0].uuid).is_equal("a-1")


func test_get_session_messages_returns_empty_for_invalid_or_missing_session() -> void:
	assert_array(ClaudeSessions.get_session_messages("not-a-uuid")).is_empty()
	assert_array(ClaudeSessions.get_session_messages("cccccccc-cccc-4ccc-8ccc-cccccccccccc")).is_empty()


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


func _init_git_repo(repo_root: String) -> void:
	var output: Array = []
	OS.execute("git", ["init", repo_root], output, true)
	OS.execute("git", ["-C", repo_root, "config", "user.email", "sdk@example.com"], output, true)
	OS.execute("git", ["-C", repo_root, "config", "user.name", "Claude SDK"], output, true)
	var readme := FileAccess.open(repo_root.path_join("README.txt"), FileAccess.WRITE)
	readme.store_string("repo\n")
	readme.close()
	OS.execute("git", ["-C", repo_root, "add", "README.txt"], output, true)
	OS.execute("git", ["-C", repo_root, "commit", "-m", "init"], output, true)


func _create_git_worktree(repo_root: String, worktree_root: String, branch_name: String) -> void:
	var output: Array = []
	OS.execute("git", ["-C", repo_root, "worktree", "add", worktree_root, "-b", branch_name], output, true)


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
