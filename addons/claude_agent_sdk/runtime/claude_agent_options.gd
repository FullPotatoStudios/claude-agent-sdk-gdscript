extends RefCounted
class_name ClaudeAgentOptions

# Phase 3 scaffold: this class reserves the core v1 option surface without
# implementing validation or runtime behavior yet.

var model: String = ""
var effort: String = ""
var cwd: String = ""
var cli_path: String = "claude"
var env: Dictionary = {}
var system_prompt: String = ""
var allowed_tools: Array[String] = []
var disallowed_tools: Array[String] = []
var permission_mode: String = ""
var max_turns: int = 0
var resume: String = ""
var session_id: String = ""
