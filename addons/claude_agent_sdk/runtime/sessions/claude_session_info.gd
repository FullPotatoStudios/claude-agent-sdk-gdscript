extends RefCounted
class_name ClaudeSessionInfo

var session_id: String = ""
var summary: String = ""
var last_modified: int = 0
var file_size: Variant = null
var custom_title: Variant = null
var first_prompt: Variant = null
var git_branch: Variant = null
var cwd: Variant = null
var tag: Variant = null
var created_at: Variant = null


func _init(
	value_session_id: String = "",
	value_summary: String = "",
	value_last_modified: int = 0,
	value_file_size: Variant = null,
	value_custom_title: Variant = null,
	value_first_prompt: Variant = null,
	value_git_branch: Variant = null,
	value_cwd: Variant = null,
	value_tag: Variant = null,
	value_created_at: Variant = null
) -> void:
	session_id = value_session_id
	summary = value_summary
	last_modified = value_last_modified
	file_size = value_file_size
	custom_title = value_custom_title
	first_prompt = value_first_prompt
	git_branch = value_git_branch
	cwd = value_cwd
	tag = value_tag
	created_at = value_created_at