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


func test_get_session_info_ignores_partial_tail_fragments_and_keeps_latest_tag() -> void:
	var config_root := _create_config_root("info-partial-tail")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_path := "/tmp/partial-tail-project"
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "acacacac-acac-4aca-8aca-acacacacacac"
	var large_prompt := "g".repeat(ClaudeSessionsScript.LITE_READ_BUF_SIZE + 128)
	var lines := [
		JSON.stringify({
			"type": "user",
			"timestamp": "2026-04-05T12:30:00",
			"cwd": project_path,
			"message": {"content": large_prompt},
		}),
		JSON.stringify({"type": "summary", "summary": "Large tail summary"}),
		JSON.stringify({"type": "tag", "tag": "ship-it"}),
	]
	_write_session_text_file(project_dir, session_id, "\n".join(lines) + "\n", 1712301050)

	var info = ClaudeSessions.get_session_info(session_id, project_path)
	assert_object(info).is_not_null()
	if info == null:
		return
	assert_str(info.summary).is_equal("Large tail summary")
	assert_str(str(info.tag)).is_equal("ship-it")


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


func test_get_session_transcript_expands_assistant_detail_blocks_without_changing_basic_message_api() -> void:
	var config_root := _create_config_root("transcript")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_path := "/tmp/transcript-project"
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "abababab-abab-4aba-8aba-abababababab"
	_write_session_file(project_dir, session_id, [
		{
			"type": "user",
			"uuid": "tx-u-1",
			"sessionId": session_id,
			"message": {"role": "user", "content": "Inspect this scene"},
		},
		{
			"type": "system",
			"uuid": "tx-s-1",
			"parentUuid": "tx-u-1",
			"sessionId": session_id,
			"subtype": "context",
			"message": {"message": "Loaded project context"},
		},
		{
			"type": "progress",
			"uuid": "tx-p-1",
			"parentUuid": "tx-s-1",
			"sessionId": session_id,
			"message": {"summary": "Scanning files"},
		},
		{
			"type": "attachment",
			"uuid": "tx-att-1",
			"parentUuid": "tx-p-1",
			"sessionId": session_id,
			"message": {"name": "scene.tscn", "path": "res://scene.tscn"},
		},
		{
			"type": "assistant",
			"uuid": "tx-a-1",
			"parentUuid": "tx-att-1",
			"sessionId": session_id,
			"message": {
				"role": "assistant",
				"content": [
					{"type": "text", "text": "I can help."},
					{"type": "thinking", "thinking": "Checking the available files."},
					{"type": "tool_use", "id": "tool-1", "name": "Read", "input": {"path": "scene.tscn"}},
					{"type": "tool_result", "tool_use_id": "tool-1", "content": {"ok": true}, "is_error": false},
				],
			},
		},
		{"type": "summary", "summary": "Transcript summary"},
	], 1712301110)

	var messages := ClaudeSessions.get_session_messages(session_id, project_path)
	var transcript := ClaudeSessions.get_session_transcript(session_id, project_path)
	var paged_transcript := ClaudeSessions.get_session_transcript(session_id, project_path, 2, 1)

	assert_int(messages.size()).is_equal(2)
	assert_int(transcript.size()).is_equal(8)
	assert_str(transcript[0].kind).is_equal("user")
	assert_str(transcript[1].kind).is_equal("system")
	assert_str(transcript[1].title).is_equal("System · context")
	assert_str(transcript[1].text).contains("Loaded project context")
	assert_str(transcript[2].kind).is_equal("progress")
	assert_str(transcript[2].text).contains("Scanning files")
	assert_str(transcript[3].kind).is_equal("attachment")
	assert_str(transcript[3].text).contains("scene.tscn")
	assert_str(transcript[4].kind).is_equal("assistant")
	assert_str(transcript[4].text).is_equal("I can help.")
	assert_array(transcript[4].payload).has_size(1)
	assert_str(transcript[5].kind).is_equal("thinking")
	assert_str(transcript[5].text).contains("Checking")
	assert_array(transcript[5].payload).has_size(1)
	assert_str(transcript[6].kind).is_equal("tool_use")
	assert_str(transcript[6].title).contains("Read")
	assert_str(transcript[7].kind).is_equal("tool_result")
	assert_dict(transcript[7].raw_data).contains_keys(["type", "content", "tool_use_id"])
	assert_int(paged_transcript.size()).is_equal(2)
	assert_str(paged_transcript[0].kind).is_equal("system")
	assert_str(paged_transcript[1].kind).is_equal("progress")


func test_rename_session_validates_inputs_and_updates_visible_title() -> void:
	var config_root := _create_config_root("rename")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	assert_int(ClaudeSessions.rename_session("not-a-uuid", "Title")).is_equal(ERR_INVALID_PARAMETER)
	assert_str(ClaudeSessions.get_last_error()).contains("Invalid session_id")

	var project_path := "/tmp/rename-project"
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
	_write_session_file(project_dir, session_id, [
		{"type": "user", "cwd": project_path, "message": {"content": "Original"}},
		{"type": "summary", "summary": "Original summary"},
	], 1712301200)

	assert_int(ClaudeSessions.rename_session(session_id, "   ")).is_equal(ERR_INVALID_PARAMETER)
	assert_str(ClaudeSessions.get_last_error()).contains("title must be non-empty")
	assert_int(
		ClaudeSessions.rename_session("10101010-1010-4101-8101-101010101010", "Missing", project_path)
	).is_equal(ERR_DOES_NOT_EXIST)
	assert_str(ClaudeSessions.get_last_error()).contains("not found")

	assert_int(ClaudeSessions.rename_session(session_id, "  Final Title  ", project_path)).is_equal(OK)
	assert_str(ClaudeSessions.get_last_error()).is_empty()

	var session_file := project_dir.path_join("%s.jsonl" % session_id)
	var lines := FileAccess.get_file_as_string(session_file).strip_edges().split("\n", false)
	assert_str(lines[-1]).is_equal(
		'{"type":"custom-title","customTitle":"Final Title","sessionId":"%s"}' % session_id
	)

	var info = ClaudeSessions.get_session_info(session_id, project_path)
	assert_object(info).is_not_null()
	if info == null:
		return
	assert_str(info.custom_title).is_equal("Final Title")
	assert_str(info.summary).is_equal("Final Title")


func test_rename_session_searches_all_projects_and_skips_zero_byte_stub() -> void:
	var config_root := _create_config_root("rename-search")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var stub_project_dir := _make_project_dir(config_root, "/aaa/project")
	var real_project_dir := _make_project_dir(config_root, "/zzz/project")
	var session_id := "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
	var stub_file := stub_project_dir.path_join("%s.jsonl" % session_id)
	var stub := FileAccess.open(stub_file, FileAccess.WRITE)
	stub.close()
	_write_session_file(real_project_dir, session_id, [
		{"type": "user", "cwd": "/zzz/project", "message": {"content": "Real prompt"}},
		{"type": "summary", "summary": "Real summary"},
	], 1712301300)

	assert_int(ClaudeSessions.rename_session(session_id, "New Title")).is_equal(OK)
	assert_str(ClaudeSessions.get_last_error()).is_empty()
	assert_str(FileAccess.get_file_as_string(stub_file)).is_empty()
	assert_str(FileAccess.get_file_as_string(real_project_dir.path_join("%s.jsonl" % session_id))).contains(
		'"customTitle":"New Title"'
	)


func test_tag_session_validates_sanitizes_clears_and_updates_visible_tag() -> void:
	var config_root := _create_config_root("tag")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	assert_int(ClaudeSessions.tag_session("not-a-uuid", "tag")).is_equal(ERR_INVALID_PARAMETER)
	assert_str(ClaudeSessions.get_last_error()).contains("Invalid session_id")

	var project_path := "/tmp/tag-project"
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "ffffffff-ffff-4fff-8fff-ffffffffffff"
	_write_session_file(project_dir, session_id, [
		{"type": "user", "cwd": project_path, "message": {"content": "Tagged"}},
		{"type": "summary", "summary": "Tagged summary"},
	], 1712301400)

	assert_int(ClaudeSessions.tag_session(session_id, "   ", project_path)).is_equal(ERR_INVALID_PARAMETER)
	assert_str(ClaudeSessions.get_last_error()).contains("tag must be non-empty")
	assert_int(
		ClaudeSessions.tag_session("14141414-1414-4141-8141-141414141414", "tag", project_path)
	).is_equal(ERR_DOES_NOT_EXIST)
	assert_int(ClaudeSessions.tag_session(session_id, "\u200b\u200c\ufeff", project_path)).is_equal(ERR_INVALID_PARAMETER)

	assert_int(ClaudeSessions.tag_session(session_id, "  clean\u200btag\ufeff  ", project_path)).is_equal(OK)
	assert_int(ClaudeSessions.tag_session(session_id, "second", project_path)).is_equal(OK)
	assert_int(ClaudeSessions.tag_session(session_id, null, project_path)).is_equal(OK)
	assert_str(ClaudeSessions.get_last_error()).is_empty()

	var session_file := project_dir.path_join("%s.jsonl" % session_id)
	var lines := FileAccess.get_file_as_string(session_file).strip_edges().split("\n", false)
	assert_str(lines[-3]).is_equal(
		'{"type":"tag","tag":"cleantag","sessionId":"%s"}' % session_id
	)
	assert_str(lines[-2]).is_equal(
		'{"type":"tag","tag":"second","sessionId":"%s"}' % session_id
	)
	assert_str(lines[-1]).is_equal(
		'{"type":"tag","tag":"","sessionId":"%s"}' % session_id
	)

	var cleared_info = ClaudeSessions.get_session_info(session_id, project_path)
	assert_object(cleared_info).is_not_null()
	if cleared_info == null:
		return
	assert_that(cleared_info.tag).is_null()

	assert_int(ClaudeSessions.tag_session(session_id, "Ａ\u200b", project_path)).is_equal(OK)
	var tagged_info = ClaudeSessions.get_session_info(session_id, project_path)
	assert_object(tagged_info).is_not_null()
	if tagged_info == null:
		return
	assert_str(str(tagged_info.tag)).is_equal("A")


func test_delete_session_removes_file_and_visibility() -> void:
	var config_root := _create_config_root("delete")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	assert_int(ClaudeSessions.delete_session("not-a-uuid")).is_equal(ERR_INVALID_PARAMETER)
	assert_str(ClaudeSessions.get_last_error()).contains("Invalid session_id")

	var project_path := "/tmp/delete-project"
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "12121212-1212-4121-8121-121212121212"
	var session_file := project_dir.path_join("%s.jsonl" % session_id)
	assert_int(ClaudeSessions.delete_session("15151515-1515-4151-8151-151515151515", project_path)).is_equal(
		ERR_DOES_NOT_EXIST
	)
	_write_session_file(project_dir, session_id, [
		{"type": "user", "cwd": project_path, "message": {"content": "Delete me"}},
		{"type": "summary", "summary": "Delete summary"},
	], 1712301500)

	assert_bool(FileAccess.file_exists(session_file)).is_true()
	assert_int(ClaudeSessions.delete_session(session_id)).is_equal(OK)
	assert_str(ClaudeSessions.get_last_error()).is_empty()
	assert_bool(FileAccess.file_exists(session_file)).is_false()
	assert_that(ClaudeSessions.get_session_info(session_id, project_path)).is_null()
	assert_array(ClaudeSessions.list_sessions(project_path, 0, 0, false)).is_empty()


func test_session_mutations_remain_worktree_aware() -> void:
	var config_root := _create_config_root("mutation-worktree")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var repo_root := _create_temp_root("git-mutation-repo")
	var worktree_parent := _create_temp_root("git-mutation-worktree-parent")
	var worktree_root := worktree_parent.path_join("feature-mutation")
	_init_git_repo(repo_root)
	_create_git_worktree(repo_root, worktree_root, "feature/mutation")

	var session_id := "13131313-1313-4131-8131-131313131313"
	var worktree_project_dir := _make_project_dir(config_root, worktree_root)
	_write_session_file(worktree_project_dir, session_id, [
		{"type": "user", "cwd": worktree_root, "message": {"content": "Worktree session"}},
		{"type": "summary", "summary": "Worktree summary"},
	], 1712301600)

	assert_int(ClaudeSessions.rename_session(session_id, "Worktree title", repo_root)).is_equal(OK)
	assert_int(ClaudeSessions.tag_session(session_id, "review", repo_root)).is_equal(OK)

	var info = ClaudeSessions.get_session_info(session_id, repo_root)
	assert_object(info).is_not_null()
	if info == null:
		return
	assert_str(info.summary).is_equal("Worktree title")
	assert_str(str(info.tag)).is_equal("review")


func test_unscoped_mutations_target_newest_visible_duplicate_session() -> void:
	var config_root := _create_config_root("duplicate-target")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var older_dir := _make_project_dir(config_root, "/tmp/older-project")
	var newer_dir := _make_project_dir(config_root, "/tmp/newer-project")
	var session_id := "20202020-2020-4202-8202-202020202020"
	_write_session_file(older_dir, session_id, [
		{"type": "user", "cwd": "/tmp/older-project", "message": {"content": "Older prompt"}},
		{"type": "summary", "summary": "Older summary"},
	], 1712301700)
	_write_session_file(newer_dir, session_id, [
		{"type": "user", "cwd": "/tmp/newer-project", "message": {"content": "Newer prompt"}},
		{"type": "summary", "summary": "Newer summary"},
	], 1712301800)

	assert_int(ClaudeSessions.rename_session(session_id, "Newest title")).is_equal(OK)
	assert_str(FileAccess.get_file_as_string(older_dir.path_join("%s.jsonl" % session_id))).contains(
		'"summary":"Older summary"'
	)
	assert_str(FileAccess.get_file_as_string(newer_dir.path_join("%s.jsonl" % session_id))).contains(
		'"customTitle":"Newest title"'
	)

	assert_int(ClaudeSessions.tag_session(session_id, "ship-it")).is_equal(OK)
	assert_str(FileAccess.get_file_as_string(older_dir.path_join("%s.jsonl" % session_id))).not_contains(
		'"tag":"ship-it"'
	)
	assert_str(FileAccess.get_file_as_string(newer_dir.path_join("%s.jsonl" % session_id))).contains(
		'"tag":"ship-it"'
	)

	assert_int(ClaudeSessions.delete_session(session_id)).is_equal(OK)
	assert_bool(FileAccess.file_exists(newer_dir.path_join("%s.jsonl" % session_id))).is_false()
	assert_bool(FileAccess.file_exists(older_dir.path_join("%s.jsonl" % session_id))).is_true()


func test_delete_session_surfaces_lookup_permission_failure() -> void:
	var config_root := _create_config_root("delete-permission")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var project_path := "/tmp/delete-permission-project"
	var project_dir := _make_project_dir(config_root, project_path)
	var session_id := "21212121-2121-4212-8212-212121212121"
	var session_file := project_dir.path_join("%s.jsonl" % session_id)
	_write_session_file(project_dir, session_id, [
		{"type": "user", "cwd": project_path, "message": {"content": "Locked"}},
		{"type": "summary", "summary": "Locked summary"},
	], 1712301900)

	var chmod_output: Array = []
	OS.execute("chmod", ["000", session_file], chmod_output, true)
	var result := ClaudeSessions.delete_session(session_id, project_path)
	OS.execute("chmod", ["600", session_file], chmod_output, true)

	assert_int(result).is_not_equal(ERR_DOES_NOT_EXIST)
	assert_str(ClaudeSessions.get_last_error()).contains(session_file)


func test_tag_sanitization_handles_compatibility_characters() -> void:
	assert_str(ClaudeSessionsScript._sanitize_tag("Ⓐ①ﬃ")).is_equal("A1ffi")
	assert_str(ClaudeSessionsScript._sanitize_tag("Ⅳ")).is_equal("IV")
	assert_str(ClaudeSessionsScript._sanitize_tag("a\u2066Ⓑ\u2069")).is_equal("aB")


func test_scoped_mutation_falls_through_primary_access_error_to_worktree_session() -> void:
	var config_root := _create_config_root("worktree-fallback")
	OS.set_environment("CLAUDE_CONFIG_DIR", config_root)

	var repo_root := _create_temp_root("git-fallback-repo")
	var worktree_parent := _create_temp_root("git-fallback-worktree-parent")
	var worktree_root := worktree_parent.path_join("feature-fallback")
	_init_git_repo(repo_root)
	_create_git_worktree(repo_root, worktree_root, "feature/fallback")

	var session_id := "23232323-2323-4232-8232-232323232323"
	var repo_project_dir := _make_project_dir(config_root, repo_root)
	var worktree_project_dir := _make_project_dir(config_root, worktree_root)
	var repo_file := repo_project_dir.path_join("%s.jsonl" % session_id)
	var worktree_file := worktree_project_dir.path_join("%s.jsonl" % session_id)
	_write_session_file(repo_project_dir, session_id, [
		{"type": "user", "cwd": repo_root, "message": {"content": "Repo copy"}},
		{"type": "summary", "summary": "Repo summary"},
	], 1712302300)
	_write_session_file(worktree_project_dir, session_id, [
		{"type": "user", "cwd": worktree_root, "message": {"content": "Worktree copy"}},
		{"type": "summary", "summary": "Worktree summary"},
	], 1712302400)

	var chmod_output: Array = []
	OS.execute("chmod", ["000", repo_file], chmod_output, true)
	var result := ClaudeSessions.rename_session(session_id, "Worktree title", repo_root)
	OS.execute("chmod", ["600", repo_file], chmod_output, true)

	assert_int(result).is_equal(OK)
	assert_bool(FileAccess.get_file_as_string(repo_file).contains('"customTitle":"Worktree title"')).is_false()
	assert_bool(FileAccess.get_file_as_string(worktree_file).contains('"customTitle":"Worktree title"')).is_true()


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
	_set_session_file_mtime(project_dir.path_join("%s.jsonl" % session_id), mtime)


func _write_session_text_file(project_dir: String, session_id: String, content: String, mtime: int) -> void:
	var path := project_dir.path_join("%s.jsonl" % session_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
	_set_session_file_mtime(path, mtime)


func _set_session_file_mtime(path: String, mtime: int) -> void:
	var output: Array = []
	OS.execute("python3", [
		"-c",
		"import os, sys; ts=int(sys.argv[2]); os.utime(sys.argv[1], (ts, ts))",
		path,
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
