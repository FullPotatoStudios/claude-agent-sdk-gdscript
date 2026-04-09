# GdUnit generated TestSuite
extends GdUnitTestSuite

const DEFAULT_MAX_BUFFER_SIZE := 1024 * 1024
const PROCESS_EXIT_GRACE_MSEC := 5000


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


func _make_transport(config: Dictionary = {}) -> ClaudeSubprocessCLITransport:
	return ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new(config))


func _messages_from_result(result: Dictionary) -> Array[String]:
	return result.get("messages", []) if result.get("messages", []) is Array else []


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
