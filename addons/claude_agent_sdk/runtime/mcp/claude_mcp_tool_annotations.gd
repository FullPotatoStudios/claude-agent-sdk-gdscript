extends RefCounted
class_name ClaudeMcpToolAnnotations

var read_only_hint: Variant = null
var destructive_hint: Variant = null
var idempotent_hint: Variant = null
var open_world_hint: Variant = null


func _init(config: Dictionary = {}) -> void:
	if config.has("read_only_hint"):
		read_only_hint = bool(config["read_only_hint"])
	elif config.has("readOnlyHint"):
		read_only_hint = bool(config["readOnlyHint"])
	if config.has("destructive_hint"):
		destructive_hint = bool(config["destructive_hint"])
	elif config.has("destructiveHint"):
		destructive_hint = bool(config["destructiveHint"])
	if config.has("idempotent_hint"):
		idempotent_hint = bool(config["idempotent_hint"])
	elif config.has("idempotentHint"):
		idempotent_hint = bool(config["idempotentHint"])
	if config.has("open_world_hint"):
		open_world_hint = bool(config["open_world_hint"])
	elif config.has("openWorldHint"):
		open_world_hint = bool(config["openWorldHint"])


func to_mcp_dictionary() -> Dictionary:
	var serialized: Dictionary = {}
	if read_only_hint != null:
		serialized["readOnlyHint"] = bool(read_only_hint)
	if destructive_hint != null:
		serialized["destructiveHint"] = bool(destructive_hint)
	if idempotent_hint != null:
		serialized["idempotentHint"] = bool(idempotent_hint)
	if open_world_hint != null:
		serialized["openWorldHint"] = bool(open_world_hint)
	return serialized
