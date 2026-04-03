extends RefCounted
class_name ClaudeHookMatcher

var matcher: String = ""
var hooks: Array[Callable] = []
var timeout_sec: float = 0.0


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	if config.has("matcher"):
		matcher = "" if config["matcher"] == null else str(config["matcher"])
	if config.has("hooks") and config["hooks"] is Array:
		hooks = _to_callable_array(config["hooks"] as Array)
	if config.has("timeout_sec"):
		timeout_sec = float(config["timeout_sec"])
	elif config.has("timeout"):
		timeout_sec = float(config["timeout"])
	return self


func duplicate_matcher() -> ClaudeHookMatcher:
	return ClaudeHookMatcher.new({
		"matcher": matcher,
		"hooks": hooks.duplicate(),
		"timeout_sec": timeout_sec,
	})


static func _to_callable_array(values: Array) -> Array[Callable]:
	var result: Array[Callable] = []
	for value in values:
		if value is Callable:
			result.append(value)
	return result
