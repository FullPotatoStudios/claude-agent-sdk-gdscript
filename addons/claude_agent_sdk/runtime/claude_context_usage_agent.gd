extends RefCounted
class_name ClaudeContextUsageAgent

var agent_type := ""
var source := ""
var tokens := 0
var raw_data: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	raw_data = config.duplicate(true)
	if config.has("agent_type"):
		agent_type = str(config["agent_type"])
	elif config.has("agentType"):
		agent_type = str(config["agentType"])
	if config.has("source"):
		source = str(config["source"])
	if config.has("tokens"):
		tokens = int(config["tokens"])
	return self


func duplicate_agent() -> ClaudeContextUsageAgent:
	return ClaudeContextUsageAgent.new(to_dict())


func to_dict() -> Dictionary:
	return {
		"agentType": agent_type,
		"source": source,
		"tokens": tokens,
	}


static func coerce(value: Variant):
	if value is ClaudeContextUsageAgent:
		return (value as ClaudeContextUsageAgent).duplicate_agent()
	if value is Dictionary:
		return ClaudeContextUsageAgent.new(value as Dictionary)
	return null
