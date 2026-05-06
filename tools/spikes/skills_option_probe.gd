extends SceneTree

# Spike probe for ClaudeAgentOptions.skills argv emission.
#
# Constructs a transport per supported skills shape (null, "all", list, [])
# and asserts the CLI argv produced by build_command_args() matches the
# Python SDK's _apply_skills_defaults decision tree. Run with:
#
#   godot --headless --quit-after 5 --script tools/spikes/skills_option_probe.gd

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeSubprocessCLITransportScript := preload("res://addons/claude_agent_sdk/runtime/transport/subprocess_cli_transport.gd")


func _init() -> void:
	var failures: Array[String] = []

	failures.append_array(_assert_unset_skills())
	failures.append_array(_assert_skills_all())
	failures.append_array(_assert_skills_all_with_existing_options())
	failures.append_array(_assert_skills_named_list())
	failures.append_array(_assert_skills_empty_list())

	if failures.is_empty():
		print("skills_option_probe: OK (5 cases)")
		quit(0)
		return

	for failure in failures:
		printerr("skills_option_probe FAIL: %s" % failure)
	quit(1)


func _build_args(config: Dictionary) -> PackedStringArray:
	var options = ClaudeAgentOptionsScript.new(config)
	var transport = ClaudeSubprocessCLITransportScript.new(options)
	return transport.build_command_args()


func _flag_value(args: PackedStringArray, flag: String) -> String:
	var index := args.find(flag)
	if index == -1 or index + 1 >= args.size():
		return ""
	return args[index + 1]


func _assert_unset_skills() -> Array[String]:
	var failures: Array[String] = []
	var args := _build_args({"allowed_tools": ["Read"]})
	if _flag_value(args, "--allowedTools") != "Read":
		failures.append("unset: expected --allowedTools=Read, got %s" % _flag_value(args, "--allowedTools"))
	if args.has("--setting-sources"):
		failures.append("unset: did not expect --setting-sources")
	if str(",".join(args)).contains("Skill"):
		failures.append("unset: did not expect any Skill tool reference")
	return failures


func _assert_skills_all() -> Array[String]:
	var failures: Array[String] = []
	var args := _build_args({"skills": "all"})
	if _flag_value(args, "--allowedTools") != "Skill":
		failures.append("all: expected --allowedTools=Skill, got %s" % _flag_value(args, "--allowedTools"))
	if _flag_value(args, "--setting-sources") != "user,project":
		failures.append("all: expected --setting-sources=user,project, got %s" % _flag_value(args, "--setting-sources"))
	return failures


func _assert_skills_all_with_existing_options() -> Array[String]:
	var failures: Array[String] = []
	var args := _build_args({
		"skills": "all",
		"allowed_tools": ["Read", "Glob"],
		"setting_sources": ["project"],
	})
	if _flag_value(args, "--allowedTools") != "Read,Glob,Skill":
		failures.append("all+existing: expected --allowedTools=Read,Glob,Skill, got %s" % _flag_value(args, "--allowedTools"))
	if _flag_value(args, "--setting-sources") != "project":
		failures.append("all+existing: expected --setting-sources=project (caller intent), got %s" % _flag_value(args, "--setting-sources"))
	return failures


func _assert_skills_named_list() -> Array[String]:
	var failures: Array[String] = []
	var args := _build_args({"skills": ["foo", "bar"]})
	if _flag_value(args, "--allowedTools") != "Skill(foo),Skill(bar)":
		failures.append("list: expected --allowedTools=Skill(foo),Skill(bar), got %s" % _flag_value(args, "--allowedTools"))
	if _flag_value(args, "--setting-sources") != "user,project":
		failures.append("list: expected --setting-sources=user,project, got %s" % _flag_value(args, "--setting-sources"))
	return failures


func _assert_skills_empty_list() -> Array[String]:
	var failures: Array[String] = []
	# Python parity: an explicit [] adds no Skill rules but still triggers
	# the setting_sources default so the CLI runs in skills-aware mode.
	var args := _build_args({"skills": [], "allowed_tools": ["Read"]})
	if _flag_value(args, "--allowedTools") != "Read":
		failures.append("empty: expected --allowedTools=Read, got %s" % _flag_value(args, "--allowedTools"))
	if _flag_value(args, "--setting-sources") != "user,project":
		failures.append("empty: expected --setting-sources=user,project, got %s" % _flag_value(args, "--setting-sources"))
	if str(",".join(args)).contains("Skill"):
		failures.append("empty: did not expect any Skill tool reference")
	return failures
