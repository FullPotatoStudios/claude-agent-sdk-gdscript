# GdUnit generated TestSuite
extends GdUnitTestSuite

const ClaudeMessageStreamScript := preload("res://addons/claude_agent_sdk/runtime/messages/claude_message_stream.gd")

var _finish_callback_count := 0


func after_test() -> void:
	_finish_callback_count = 0


func _record_stream_finish() -> void:
	_finish_callback_count += 1


func test_add_finish_callback_keeps_existing_finish_callback() -> void:
	var stream = ClaudeMessageStreamScript.new()
	stream.set_finish_callback(Callable(self, "_record_stream_finish"))
	stream.add_finish_callback(Callable(self, "_record_stream_finish"))

	stream.finish()

	assert_int(_finish_callback_count).is_equal(2)
	assert_bool((stream.get("_finish_callback") as Callable).is_valid()).is_false()


func test_finish_clears_finish_callback_and_retained_refs() -> void:
	var stream = ClaudeMessageStreamScript.new()
	stream.retain({"held": true})
	stream.set_finish_callback(Callable(self, "_record_stream_finish"))

	assert_bool((stream.get("_finish_callback") as Callable).is_valid()).is_true()
	assert_int((stream.get("_retained_refs") as Array).size()).is_equal(1)

	stream.finish()

	assert_int(_finish_callback_count).is_equal(1)
	assert_bool((stream.get("_finish_callback") as Callable).is_valid()).is_false()
	assert_array(stream.get("_retained_refs") as Array).is_empty()

	stream.finish()
	assert_int(_finish_callback_count).is_equal(1)


func test_fail_clears_finish_callback_and_retained_refs() -> void:
	var stream = ClaudeMessageStreamScript.new()
	stream.retain({"held": true})
	stream.set_finish_callback(Callable(self, "_record_stream_finish"))

	stream.fail("stream failed")

	assert_int(_finish_callback_count).is_equal(1)
	assert_str(stream.get_error()).is_equal("stream failed")
	assert_bool((stream.get("_finish_callback") as Callable).is_valid()).is_false()
	assert_array(stream.get("_retained_refs") as Array).is_empty()
