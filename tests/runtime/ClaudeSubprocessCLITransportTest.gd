# GdUnit generated TestSuite
extends GdUnitTestSuite

const DEFAULT_MAX_BUFFER_SIZE := 1024 * 1024
const PROCESS_EXIT_GRACE_MSEC := 5000
const W3C_TRACE_ENV_KEYS := ["TRACEPARENT", "TRACESTATE"]

var _original_w3c_trace_env: Dictionary = {}


class CloseBehaviorTransport extends ClaudeSubprocessCLITransport:
	var wait_results: Array[bool] = []
	var wait_timeouts: Array[int] = []
	var kill_calls := 0
	var close_pipes_calls := 0
	var reader_wait_calls := 0

	func _init(config: Dictionary = {}, results: Array[bool] = []) -> void:
		wait_results = results.duplicate()
		super(ClaudeAgentOptions.new(config))

	func _close_pipes() -> void:
		close_pipes_calls += 1
		_stdio = null
		_stderr = null

	func _wait_for_reader_threads() -> void:
		reader_wait_calls += 1
		_stdout_thread = null
		_stderr_thread = null

	func _wait_for_process_exit_with_timeout(timeout_msec: int) -> bool:
		if _pid <= 0:
			return true
		wait_timeouts.append(timeout_msec)
		if wait_results.is_empty():
			return true
		return bool(wait_results.pop_front())

	func _kill_process() -> void:
		kill_calls += 1


class CliDiscoveryTransport extends ClaudeSubprocessCLITransport:
	var mocked_path_env := ""
	var mocked_home := ""
	var existing_paths: Dictionary = {}
	var last_execute_path := ""
	var last_execute_args := PackedStringArray()

	func _init(config: Dictionary = {}, path_env: String = "", home: String = "", paths: Array[String] = []) -> void:
		mocked_path_env = path_env
		mocked_home = home
		for path in paths:
			existing_paths[path] = true
		super(ClaudeAgentOptions.new(config))

	func _get_cli_search_path_env() -> String:
		return mocked_path_env

	func _get_home_directory() -> String:
		return mocked_home

	func _path_is_file(path: String) -> bool:
		return existing_paths.has(path)

	func _execute_with_pipe(path: String, args: PackedStringArray) -> Dictionary:
		last_execute_path = path
		last_execute_args = args.duplicate()
		return {}


func _make_transport(config: Dictionary = {}) -> ClaudeSubprocessCLITransport:
	return ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new(config))


func _messages_from_result(result: Dictionary) -> Array[String]:
	return result.get("messages", []) if result.get("messages", []) is Array else []


func before_test() -> void:
	_original_w3c_trace_env = _capture_environment(W3C_TRACE_ENV_KEYS)
	ClaudeSubprocessCLITransport.clear_trace_context_provider()


func after_test() -> void:
	_restore_environment(_original_w3c_trace_env)
	ClaudeSubprocessCLITransport.clear_trace_context_provider()


func _capture_environment(keys: Array) -> Dictionary:
	var captured: Dictionary = {}
	for key_variant in keys:
		var key := str(key_variant)
		captured[key] = {
			"present": OS.has_environment(key),
			"value": OS.get_environment(key),
		}
	return captured


func _restore_environment(values: Dictionary) -> void:
	for key_variant in values.keys():
		var key := str(key_variant)
		var entry := values[key_variant] as Dictionary
		var value := str(entry.get("value", ""))
		if bool(entry.get("present", false)):
			OS.set_environment(key, value)
		else:
			OS.set_environment(key, "")


func test_resolve_cli_path_prefers_effective_path_before_upstream_fallback_locations() -> void:
	if OS.get_name() == "Windows":
		return
	var transport := CliDiscoveryTransport.new(
		{},
		"/custom/bin:/unused/bin",
		"/Users/tester",
		[
			"/custom/bin/claude",
			"/Users/tester/.npm-global/bin/claude",
		]
	)

	var resolved_path := transport._resolve_cli_path_for_launch()

	assert_str(resolved_path).is_equal("/custom/bin/claude")


func test_resolve_cli_path_uses_upstream_fallback_locations_when_path_lookup_misses() -> void:
	if OS.get_name() == "Windows":
		return
	var transport := CliDiscoveryTransport.new(
		{},
		"",
		"/Users/tester",
		[
			"/usr/local/bin/claude",
			"/Users/tester/.local/bin/claude",
		]
	)

	var resolved_path := transport._resolve_cli_path_for_launch()

	assert_str(resolved_path).is_equal("/usr/local/bin/claude")


func test_resolve_cli_path_treats_empty_cli_path_as_default_like() -> void:
	if OS.get_name() == "Windows":
		return
	var transport := CliDiscoveryTransport.new(
		{"cli_path": ""},
		"",
		"/Users/tester",
		[
			"/Users/tester/.npm-global/bin/claude",
		]
	)

	var resolved_path := transport._resolve_cli_path_for_launch()

	assert_str(resolved_path).is_equal("/Users/tester/.npm-global/bin/claude")


func test_resolve_cli_path_preserves_explicit_custom_override() -> void:
	var explicit_path := "/tmp/custom/claude"
	var transport := CliDiscoveryTransport.new(
		{"cli_path": explicit_path},
		"/custom/bin",
		"/Users/tester",
		[
			"/custom/bin/claude",
		]
	)

	var resolved_path := transport._resolve_cli_path_for_launch()

	assert_str(resolved_path).is_equal(explicit_path)


func test_resolve_cli_path_uses_host_path_instead_of_options_env_override() -> void:
	if OS.get_name() == "Windows":
		return
	var transport := CliDiscoveryTransport.new(
		{"env": {"PATH": "/override/bin"}},
		"/host/bin",
		"/Users/tester",
		[
			"/host/bin/claude",
			"/override/bin/claude",
		]
	)

	var resolved_path := transport._resolve_cli_path_for_launch()

	assert_str(resolved_path).is_equal("/host/bin/claude")


func test_fallback_cli_locations_match_upstream_non_bundled_order() -> void:
	if OS.get_name() == "Windows":
		return
	var transport := CliDiscoveryTransport.new({}, "", "/Users/tester")

	assert_array(Array(transport._fallback_cli_locations())).is_equal([
		"/Users/tester/.npm-global/bin/claude",
		"/usr/local/bin/claude",
		"/Users/tester/.local/bin/claude",
		"/Users/tester/node_modules/.bin/claude",
		"/Users/tester/.yarn/bin/claude",
		"/Users/tester/.claude/local/claude",
	])


func test_probe_auth_status_uses_resolved_cli_path_without_changing_public_logical_spec() -> void:
	if OS.get_name() == "Windows":
		return
	var discovered_path := "/Users/tester/.npm-global/bin/claude"
	var transport := CliDiscoveryTransport.new(
		{},
		"",
		"/Users/tester",
		[
			discovered_path,
		]
	)

	var preview_spec := transport.build_process_spec()
	var probe_result := transport.probe_auth_status()

	assert_str(str(preview_spec.get("logical_path", ""))).is_equal("claude")
	assert_str(transport.last_execute_path).is_equal("/bin/sh")
	assert_bool(str((transport.last_execute_args[1] if transport.last_execute_args.size() > 1 else "")).contains(discovered_path)).is_true()
	assert_str(str(probe_result.get("error_code", ""))).is_equal("command_failed")


func test_probe_auth_status_reports_binary_not_found_when_cli_lookup_fails() -> void:
	var transport := CliDiscoveryTransport.new()

	var result := transport.probe_auth_status()

	assert_str(str(result.get("error_code", ""))).is_equal("binary_not_found")
	assert_str(str(result.get("error_message", ""))).contains("Claude Code not found")


func test_build_environment_overrides_forwards_inherited_w3c_trace_context() -> void:
	OS.set_environment("TRACEPARENT", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01")
	OS.set_environment("TRACESTATE", "vendor=value")
	var transport := _make_transport()

	var overrides := transport.build_environment_overrides()

	assert_str(str(overrides.get("TRACEPARENT", ""))).is_equal("00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01")
	assert_str(str(overrides.get("TRACESTATE", ""))).is_equal("vendor=value")


func test_build_environment_overrides_uses_registered_trace_context_provider() -> void:
	ClaudeSubprocessCLITransport.set_trace_context_provider(func():
		return {
			"traceparent": "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
			"tracestate": "vendor=value",
		}
	)
	var transport := _make_transport()

	var overrides := transport.build_environment_overrides()

	assert_str(str(overrides.get("TRACEPARENT", ""))).is_equal("00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01")
	assert_str(str(overrides.get("TRACESTATE", ""))).is_equal("vendor=value")


func test_build_environment_overrides_keeps_explicit_trace_env_overrides_authoritative() -> void:
	OS.set_environment("TRACEPARENT", "00-stale-parent")
	OS.set_environment("TRACESTATE", "vendor=stale")
	var transport := _make_transport({
		"env": {
			"TRACEPARENT": "00-custom-parent",
			"TRACESTATE": "vendor=custom",
		},
	})

	var overrides := transport.build_environment_overrides()

	assert_str(str(overrides.get("TRACEPARENT", ""))).is_equal("00-custom-parent")
	assert_str(str(overrides.get("TRACESTATE", ""))).is_equal("vendor=custom")


func test_build_environment_overrides_keeps_explicit_trace_env_overrides_authoritative_over_provider() -> void:
	ClaudeSubprocessCLITransport.set_trace_context_provider(func():
		return {
			"traceparent": "00-provider-parent",
			"tracestate": "vendor=provider",
		}
	)
	var transport := _make_transport({
		"env": {
			"TRACEPARENT": "00-custom-parent",
			"TRACESTATE": "vendor=custom",
		},
	})

	var overrides := transport.build_environment_overrides()

	assert_str(str(overrides.get("TRACEPARENT", ""))).is_equal("00-custom-parent")
	assert_str(str(overrides.get("TRACESTATE", ""))).is_equal("vendor=custom")


func test_build_environment_overrides_partial_explicit_trace_override_scrubs_provider_opposite_half() -> void:
	ClaudeSubprocessCLITransport.set_trace_context_provider(func():
		return {
			"traceparent": "00-provider-parent",
			"tracestate": "vendor=provider",
		}
	)
	var transport := _make_transport({
		"env": {
			"TRACEPARENT": "00-custom-parent",
		},
	})

	var overrides := transport.build_environment_overrides()

	assert_str(str(overrides.get("TRACEPARENT", ""))).is_equal("00-custom-parent")
	assert_bool(overrides.has("TRACESTATE")).is_false()
	assert_array(Array(transport.build_environment_unset_keys())).contains_exactly(["TRACESTATE", "CLAUDECODE"])


func test_build_environment_overrides_scrubs_inherited_tracestate_when_traceparent_is_explicit() -> void:
	OS.set_environment("TRACEPARENT", "00-stale-parent")
	OS.set_environment("TRACESTATE", "vendor=stale")
	var transport := _make_transport({
		"env": {
			"TRACEPARENT": "00-custom-parent",
		},
	})

	var overrides := transport.build_environment_overrides()

	assert_str(str(overrides.get("TRACEPARENT", ""))).is_equal("00-custom-parent")
	assert_bool(overrides.has("TRACESTATE")).is_false()
	assert_array(Array(transport.build_environment_unset_keys())).contains_exactly(["TRACESTATE", "CLAUDECODE"])


func test_build_environment_overrides_scrubs_inherited_traceparent_when_tracestate_is_explicit() -> void:
	OS.set_environment("TRACEPARENT", "00-stale-parent")
	OS.set_environment("TRACESTATE", "vendor=stale")
	var transport := _make_transport({
		"env": {
			"TRACESTATE": "vendor=custom",
		},
	})

	var overrides := transport.build_environment_overrides()

	assert_bool(overrides.has("TRACEPARENT")).is_false()
	assert_str(str(overrides.get("TRACESTATE", ""))).is_equal("vendor=custom")
	assert_array(Array(transport.build_environment_unset_keys())).contains_exactly(["TRACEPARENT", "CLAUDECODE"])


func test_build_environment_overrides_leaves_trace_context_absent_when_not_present() -> void:
	OS.set_environment("TRACEPARENT", "")
	OS.set_environment("TRACESTATE", "")
	var transport := _make_transport()

	var overrides := transport.build_environment_overrides()

	assert_bool(overrides.has("TRACEPARENT")).is_false()
	assert_bool(overrides.has("TRACESTATE")).is_false()


func test_build_environment_overrides_active_provider_replaces_stale_inherited_trace_context() -> void:
	OS.set_environment("TRACEPARENT", "00-stale-parent")
	OS.set_environment("TRACESTATE", "vendor=stale")
	ClaudeSubprocessCLITransport.set_trace_context_provider(func():
		return {
			"traceparent": "00-active-parent",
		}
	)
	var transport := _make_transport()

	var overrides := transport.build_environment_overrides()

	assert_str(str(overrides.get("TRACEPARENT", ""))).is_equal("00-active-parent")
	assert_bool(overrides.has("TRACESTATE")).is_false()
	assert_array(Array(transport.build_environment_unset_keys())).contains_exactly(["TRACESTATE", "CLAUDECODE"])


func test_build_environment_overrides_provider_without_traceparent_preserves_inherited_trace_context() -> void:
	OS.set_environment("TRACEPARENT", "00-ambient-parent")
	OS.set_environment("TRACESTATE", "vendor=ambient")
	ClaudeSubprocessCLITransport.set_trace_context_provider(func():
		return {
			"baggage": "user=alice",
			"tracestate": "vendor=ignored-without-traceparent",
		}
	)
	var transport := _make_transport()

	var overrides := transport.build_environment_overrides()

	assert_str(str(overrides.get("TRACEPARENT", ""))).is_equal("00-ambient-parent")
	assert_str(str(overrides.get("TRACESTATE", ""))).is_equal("vendor=ambient")
	assert_array(Array(transport.build_environment_unset_keys())).contains_exactly(["CLAUDECODE"])


func test_build_environment_overrides_invalid_provider_output_noops() -> void:
	OS.set_environment("TRACEPARENT", "00-ambient-parent")
	ClaudeSubprocessCLITransport.set_trace_context_provider(func(): return "not-a-dictionary")
	var transport := _make_transport()

	var overrides := transport.build_environment_overrides()

	assert_str(str(overrides.get("TRACEPARENT", ""))).is_equal("00-ambient-parent")
	assert_array(Array(transport.build_environment_unset_keys())).contains_exactly(["CLAUDECODE"])


func test_user_launch_path_preserves_trace_context_assignments_in_posix_shell_script() -> void:
	if OS.get_name() == "Windows":
		return
	OS.set_environment("TRACEPARENT", "00-ambient-parent")
	OS.set_environment("TRACESTATE", "vendor=ambient")
	var transport := _make_transport({"user": "sdk-user"})

	var spec := transport._build_process_spec_for_args(PackedStringArray(["auth", "status"]), "/usr/bin/claude")
	var shell_script := str((spec.get("args", PackedStringArray()) as PackedStringArray)[6])

	assert_str(str(spec.get("path", ""))).is_equal("sudo")
	assert_str(shell_script).contains("TRACEPARENT='00-ambient-parent'")
	assert_str(shell_script).contains("TRACESTATE='vendor=ambient'")


func test_user_launch_path_scrubs_inherited_trace_half_when_explicit_override_is_partial() -> void:
	if OS.get_name() == "Windows":
		return
	OS.set_environment("TRACEPARENT", "00-stale-parent")
	OS.set_environment("TRACESTATE", "vendor=stale")
	var transport := _make_transport({
		"user": "sdk-user",
		"env": {
			"TRACEPARENT": "00-custom-parent",
		},
	})

	var spec := transport._build_process_spec_for_args(PackedStringArray(["auth", "status"]), "/usr/bin/claude")
	var shell_script := str((spec.get("args", PackedStringArray()) as PackedStringArray)[6])

	assert_str(str(spec.get("path", ""))).is_equal("sudo")
	assert_str(shell_script).contains("TRACEPARENT='00-custom-parent'")
	assert_str(shell_script).contains("-u TRACESTATE")
	assert_bool(shell_script.contains("TRACESTATE='vendor=stale'")).is_false()


func test_user_launch_path_scrubs_stale_tracestate_when_provider_supplies_active_traceparent() -> void:
	if OS.get_name() == "Windows":
		return
	OS.set_environment("TRACEPARENT", "00-stale-parent")
	OS.set_environment("TRACESTATE", "vendor=stale")
	ClaudeSubprocessCLITransport.set_trace_context_provider(func():
		return {
			"traceparent": "00-active-parent",
		}
	)
	var transport := _make_transport({"user": "sdk-user"})

	var spec := transport._build_process_spec_for_args(PackedStringArray(["auth", "status"]), "/usr/bin/claude")
	var shell_script := str((spec.get("args", PackedStringArray()) as PackedStringArray)[6])

	assert_str(str(spec.get("path", ""))).is_equal("sudo")
	assert_str(shell_script).contains("TRACEPARENT='00-active-parent'")
	assert_str(shell_script).contains("-u TRACESTATE")
	assert_bool(shell_script.contains("TRACESTATE='vendor=stale'")).is_false()


func test_consume_stdout_chunk_parses_multiple_json_objects_in_one_chunk() -> void:
	var first := JSON.stringify({
		"type": "message",
		"id": "msg1",
		"content": "First message",
	})
	var second := JSON.stringify({
		"type": "result",
		"id": "res1",
		"status": "completed",
	})
	var transport := _make_transport()

	var messages := _messages_from_result(transport._consume_stdout_chunk("%s\n%s" % [first, second]))

	assert_array(messages).has_size(2)
	assert_dict(JSON.parse_string(messages[0])).contains_keys(["type", "id", "content"])
	assert_str(str((JSON.parse_string(messages[0]) as Dictionary).get("content", ""))).is_equal("First message")
	assert_str(str((JSON.parse_string(messages[1]) as Dictionary).get("type", ""))).is_equal("result")


func test_consume_stdout_chunk_preserves_escaped_newlines_inside_json_strings() -> void:
	var first := JSON.stringify({
		"type": "message",
		"content": "Line 1\nLine 2\nLine 3",
	})
	var second := JSON.stringify({
		"type": "result",
		"data": "Some\nMultiline\nContent",
	})
	var transport := _make_transport()

	var messages := _messages_from_result(transport._consume_stdout_chunk("%s\n%s" % [first, second]))

	assert_array(messages).has_size(2)
	assert_str(str((JSON.parse_string(messages[0]) as Dictionary).get("content", ""))).is_equal("Line 1\nLine 2\nLine 3")
	assert_str(str((JSON.parse_string(messages[1]) as Dictionary).get("data", ""))).is_equal("Some\nMultiline\nContent")


func test_consume_stdout_chunk_skips_blank_lines_between_messages() -> void:
	var first := JSON.stringify({"type": "message", "id": "msg1"})
	var second := JSON.stringify({"type": "result", "id": "res1"})
	var transport := _make_transport()

	var messages := _messages_from_result(transport._consume_stdout_chunk("%s\n\n\n%s" % [first, second]))

	assert_array(messages).has_size(2)
	assert_str(str((JSON.parse_string(messages[0]) as Dictionary).get("id", ""))).is_equal("msg1")
	assert_str(str((JSON.parse_string(messages[1]) as Dictionary).get("id", ""))).is_equal("res1")


func test_build_command_args_emits_thinking_display_independently_of_thinking_type() -> void:
	var transport := _make_transport({"thinking": {"display": "summarized"}})

	var args := transport.build_command_args()

	assert_int(args.find("--thinking-display")).is_greater_equal(0)
	assert_str(args[args.find("--thinking-display") + 1]).is_equal("summarized")
	assert_int(args.find("--thinking")).is_equal(-1)
	assert_int(args.find("--max-thinking-tokens")).is_equal(-1)


func test_build_command_args_emits_thinking_display_alongside_adaptive_thinking() -> void:
	var transport := _make_transport({"thinking": {"type": "adaptive", "display": "omitted"}})

	var args := transport.build_command_args()

	var display_index := args.find("--thinking-display")
	var thinking_index := args.find("--thinking")
	assert_int(display_index).is_greater_equal(0)
	assert_str(args[display_index + 1]).is_equal("omitted")
	assert_int(thinking_index).is_greater_equal(0)
	assert_str(args[thinking_index + 1]).is_equal("adaptive")


func test_build_command_args_emits_thinking_display_alongside_enabled_budget_tokens() -> void:
	var transport := _make_transport({
		"thinking": {"type": "enabled", "budget_tokens": 1024, "display": "summarized"},
	})

	var args := transport.build_command_args()

	var display_index := args.find("--thinking-display")
	var budget_index := args.find("--max-thinking-tokens")
	assert_int(display_index).is_greater_equal(0)
	assert_str(args[display_index + 1]).is_equal("summarized")
	assert_int(budget_index).is_greater_equal(0)
	assert_str(args[budget_index + 1]).is_equal("1024")


func test_build_command_args_omits_thinking_display_when_unset() -> void:
	var transport := _make_transport({"thinking": {"type": "adaptive"}})

	var args := transport.build_command_args()

	assert_int(args.find("--thinking-display")).is_equal(-1)


func test_end_input_reports_subprocess_half_close_is_unavailable() -> void:
	var transport := _make_transport()

	assert_bool(transport.supports_end_input()).is_false()
	assert_bool(transport.end_input()).is_false()
	assert_str(transport.get_last_error()).is_empty()


func test_consume_stdout_chunk_buffers_split_json_across_multiple_chunks() -> void:
	var payload := JSON.stringify({
		"type": "assistant",
		"message": {
			"content": [
				{"type": "text", "text": "x".repeat(1000)},
				{
					"type": "tool_use",
					"id": "tool_123",
					"name": "Read",
					"input": {"file_path": "/test.txt"},
				},
			],
		},
	})
	var transport := _make_transport()

	var first := _messages_from_result(transport._consume_stdout_chunk(payload.substr(0, 100)))
	var second := _messages_from_result(transport._consume_stdout_chunk(payload.substr(100, 150)))
	var third := _messages_from_result(transport._consume_stdout_chunk(payload.substr(250)))

	assert_array(first).is_empty()
	assert_array(second).is_empty()
	assert_array(third).has_size(1)
	assert_str(str((JSON.parse_string(third[0]) as Dictionary).get("type", ""))).is_equal("assistant")


func test_consume_stdout_chunk_parses_large_minified_json_split_across_chunks() -> void:
	var large_data: Array = []
	for index in range(1000):
		large_data.append({"id": index, "value": "x".repeat(100)})
	var payload := JSON.stringify({
		"type": "user",
		"message": {
			"role": "user",
			"content": [
				{
					"tool_use_id": "toolu_016fed1NhiaMLqnEvrj5NUaj",
					"type": "tool_result",
					"content": JSON.stringify({"data": large_data}),
				},
			],
		},
	})
	var transport := _make_transport()
	var chunks: Array[String] = []
	var chunk_size := 64 * 1024
	for offset in range(0, payload.length(), chunk_size):
		chunks.append(payload.substr(offset, mini(chunk_size, payload.length() - offset)))

	var messages: Array[String] = []
	for chunk in chunks:
		messages.append_array(_messages_from_result(transport._consume_stdout_chunk(chunk)))

	assert_array(messages).has_size(1)
	assert_str(str((((JSON.parse_string(messages[0]) as Dictionary).get("message", {}) as Dictionary).get("content", []) as Array)[0].get("tool_use_id", ""))).is_equal("toolu_016fed1NhiaMLqnEvrj5NUaj")


func test_consume_stdout_chunk_handles_mixed_complete_and_split_messages() -> void:
	var first := JSON.stringify({"type": "system", "subtype": "start"})
	var second := JSON.stringify({
		"type": "assistant",
		"message": {"content": [{"type": "text", "text": "y".repeat(5000)}]},
	})
	var third := JSON.stringify({"type": "system", "subtype": "end"})
	var transport := _make_transport()
	var chunks := [
		"%s\n" % first,
		second.substr(0, 1000),
		second.substr(1000, 2000),
		"%s\n%s" % [second.substr(3000), third],
	]

	var messages: Array[String] = []
	for chunk in chunks:
		messages.append_array(_messages_from_result(transport._consume_stdout_chunk(chunk)))

	assert_array(messages).has_size(3)
	assert_str(str((JSON.parse_string(messages[0]) as Dictionary).get("subtype", ""))).is_equal("start")
	assert_str(str((JSON.parse_string(messages[2]) as Dictionary).get("subtype", ""))).is_equal("end")


func test_consume_stdout_chunk_skips_non_json_debug_lines_when_buffer_is_empty() -> void:
	var debug := "[SandboxDebug] Seccomp filtering not available"
	var first := JSON.stringify({"type": "system", "subtype": "init"})
	var second := JSON.stringify({"type": "result", "subtype": "success"})
	var transport := _make_transport()

	var messages := _messages_from_result(transport._consume_stdout_chunk("%s\n%s\n%s\n%s\n" % [debug, first, debug, second]))

	assert_array(messages).has_size(2)
	assert_str(str((JSON.parse_string(messages[0]) as Dictionary).get("type", ""))).is_equal("system")
	assert_str(str((JSON.parse_string(messages[1]) as Dictionary).get("type", ""))).is_equal("result")


func test_consume_stdout_chunk_skips_interleaved_non_json_warning_lines() -> void:
	var transport := _make_transport()
	var messages: Array[String] = []
	var chunks := [
		"[SandboxDebug] line 1\n",
		"[SandboxDebug] line 2\n",
		"%s\n" % JSON.stringify({"type": "system", "subtype": "init"}),
		"WARNING: something\n",
		"%s\n" % JSON.stringify({"type": "result", "subtype": "success"}),
	]

	for chunk in chunks:
		messages.append_array(_messages_from_result(transport._consume_stdout_chunk(chunk)))

	assert_array(messages).has_size(2)
	assert_str(str((JSON.parse_string(messages[0]) as Dictionary).get("type", ""))).is_equal("system")
	assert_str(str((JSON.parse_string(messages[1]) as Dictionary).get("type", ""))).is_equal("result")


func test_drain_pending_events_emits_parsed_message_before_overflow_error_in_same_chunk() -> void:
	var transport := _make_transport({"max_buffer_size": 64})
	var events: Array[String] = []
	transport.stdout_line.connect(func(line: String) -> void:
		events.append("stdout:%s" % str((JSON.parse_string(line) as Dictionary).get("type", "")))
	)
	transport.transport_error.connect(func(message: String) -> void:
		events.append("error:%s" % message)
	)

	transport._queue_line(
		"stdout",
		"%s\n{\"data\":\"%s" % [
			JSON.stringify({"type": "system", "subtype": "init"}),
			"x".repeat(64),
		]
	)
	transport._drain_pending_events()

	assert_array(events).is_equal([
		"stdout:system",
		"error:JSON message exceeded maximum buffer size of 64 bytes",
	])


func test_consume_stdout_chunk_reports_default_buffer_overflow() -> void:
	var transport := _make_transport()
	var huge_incomplete := "{\"data\": \"%s" % "x".repeat(DEFAULT_MAX_BUFFER_SIZE + 1000)

	var result := transport._consume_stdout_chunk(huge_incomplete)
	var messages := _messages_from_result(result)
	var error_message := str(result.get("error", ""))

	assert_array(messages).is_empty()
	assert_str(error_message).contains("maximum buffer size of %d bytes" % DEFAULT_MAX_BUFFER_SIZE)


func test_consume_stdout_chunk_respects_custom_buffer_limit() -> void:
	var custom_limit := 512
	var transport := _make_transport({"max_buffer_size": custom_limit})
	var huge_incomplete := "{\"data\": \"%s" % "x".repeat(custom_limit + 10)

	var result := transport._consume_stdout_chunk(huge_incomplete)

	assert_str(str(result.get("error", ""))).contains("maximum buffer size of %d bytes" % custom_limit)


func test_consume_stdout_chunk_does_not_normalize_zero_buffer_limit() -> void:
	var transport := _make_transport({"max_buffer_size": 0})

	var result := transport._consume_stdout_chunk(JSON.stringify({"type": "system"}))

	assert_str(str(result.get("error", ""))).contains("maximum buffer size of 0 bytes")


func test_close_waits_for_graceful_process_exit_before_force_kill() -> void:
	var transport := CloseBehaviorTransport.new({}, [true])
	var close_events := [0]
	transport.transport_closed.connect(func() -> void:
		close_events[0] += 1
	)
	transport._pid = 123
	transport._connected = true
	transport._process = {"pid": 123}

	transport.close()

	assert_array(transport.wait_timeouts).is_equal([PROCESS_EXIT_GRACE_MSEC])
	assert_int(transport.kill_calls).is_equal(0)
	assert_int(transport.close_pipes_calls).is_equal(1)
	assert_int(transport.reader_wait_calls).is_equal(1)
	assert_bool(transport.transport_is_connected()).is_false()
	assert_int(transport._pid).is_equal(0)
	assert_dict(transport._process).is_empty()
	assert_int(int(close_events[0])).is_equal(1)


func test_close_force_kills_process_after_grace_period_timeout() -> void:
	var transport := CloseBehaviorTransport.new({}, [false, true])
	transport._pid = 456
	transport._connected = true
	transport._process = {"pid": 456}

	transport.close()

	assert_array(transport.wait_timeouts).is_equal([
		PROCESS_EXIT_GRACE_MSEC,
		PROCESS_EXIT_GRACE_MSEC,
	])
	assert_int(transport.kill_calls).is_equal(1)
	assert_int(transport.close_pipes_calls).is_equal(1)
	assert_int(transport.reader_wait_calls).is_equal(1)
	assert_bool(transport.transport_is_connected()).is_false()
	assert_int(transport._pid).is_equal(0)


func test_close_does_not_wait_or_kill_again_after_process_has_already_exited() -> void:
	var transport := CloseBehaviorTransport.new({}, [true])
	var close_events := [0]
	transport.transport_closed.connect(func() -> void:
		close_events[0] += 1
	)
	transport._pid = 789
	transport._connected = true
	transport._process = {"pid": 789}

	transport.close()
	transport.close()

	assert_array(transport.wait_timeouts).is_equal([PROCESS_EXIT_GRACE_MSEC])
	assert_int(transport.kill_calls).is_equal(0)
	assert_int(transport.close_pipes_calls).is_equal(2)
	assert_int(transport.reader_wait_calls).is_equal(2)
	assert_bool(transport.transport_is_connected()).is_false()
	assert_int(transport._pid).is_equal(0)
	assert_dict(transport._process).is_empty()
	assert_int(int(close_events[0])).is_equal(1)
