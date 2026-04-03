extends RefCounted
class_name ClaudeSDKVersion

const VERSION_PATH := "res://addons/claude_agent_sdk/VERSION"
const FALLBACK_VERSION := "0.0.0-dev"


static func get_version() -> String:
	var file := FileAccess.open(VERSION_PATH, FileAccess.READ)
	if file == null:
		return FALLBACK_VERSION
	var version := file.get_as_text().strip_edges()
	return version if not version.is_empty() else FALLBACK_VERSION
