extends RefCounted
class_name ClaudeMessageStream

signal state_changed

var _messages: Array = []
var _finished := false
var _finish_on_result := false
var _error_message := ""
var _finish_callback: Callable = Callable()
var _retained_refs: Array = []


func _init(finish_on_result: bool = false) -> void:
	_finish_on_result = finish_on_result


func push_message(message: Variant) -> void:
	if _finished or message == null:
		return
	_messages.append(message)
	state_changed.emit()
	if _finish_on_result and message is Object and str(message.get("message_type")) == "result":
		finish()


func seed_messages(messages: Array) -> void:
	for message in messages:
		push_message(message)


func finish() -> void:
	if _finished:
		return
	_finished = true
	state_changed.emit()
	if _finish_callback.is_valid():
		_finish_callback.call()
	_retained_refs.clear()


func fail(message: String) -> void:
	_error_message = message
	finish()


func is_finished() -> bool:
	return _finished and _messages.is_empty()


func get_error() -> String:
	return _error_message


func set_finish_callback(callback: Callable) -> void:
	_finish_callback = callback


func retain(reference: Variant) -> void:
	if reference == null:
		return
	_retained_refs.append(reference)


func next_message() -> Variant:
	while _messages.is_empty() and not _finished:
		await state_changed
	if _messages.is_empty():
		return null
	return _messages.pop_front()


func collect() -> Array:
	var result: Array = []
	while true:
		var message: Variant = await next_message()
		if message == null:
			break
		result.append(message)
	return result
