extends RefCounted
class_name ClaudePromptStream

signal state_changed

var _messages: Array[Dictionary] = []
var _finished := false
var _error_message := ""
var _retained_refs: Array = []


func push_message(message: Dictionary) -> void:
	if _finished:
		return
	_messages.append(message.duplicate(true))
	state_changed.emit()


func seed_messages(messages: Array) -> void:
	for message in messages:
		if message is not Dictionary:
			continue
		push_message(message as Dictionary)


func finish() -> void:
	if _finished:
		return
	_finished = true
	state_changed.emit()
	_retained_refs.clear()


func fail(message: String) -> void:
	_error_message = message
	finish()


func is_finished() -> bool:
	return _finished and _messages.is_empty()


func get_error() -> String:
	return _error_message


func retain(reference: Variant) -> void:
	if reference == null:
		return
	_retained_refs.append(reference)


func next_message() -> Variant:
	while _messages.is_empty() and not _finished:
		await state_changed
	if _messages.is_empty():
		return null
	return (_messages.pop_front() as Dictionary).duplicate(true)


func collect() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	while true:
		var message: Variant = await next_message()
		if message == null:
			break
		result.append((message as Dictionary).duplicate(true))
	return result
