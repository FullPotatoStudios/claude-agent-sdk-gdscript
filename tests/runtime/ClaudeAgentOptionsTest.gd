# GdUnit generated TestSuite
extends GdUnitTestSuite


func test_duplicate_options_preserves_phase_4_fields() -> void:
	var options = ClaudeAgentOptions.new({
		"model": "haiku",
		"effort": "low",
		"cwd": "/tmp/project",
		"cli_path": "/usr/local/bin/claude",
		"env": {"CLAUDE_PATH": "claude"},
		"system_prompt": "Be brief.",
		"allowed_tools": ["Read"],
		"disallowed_tools": ["Edit"],
		"permission_mode": "plan",
		"max_turns": 2,
		"resume": "resume-id",
		"session_id": "session-id",
	})

	var duplicated = options.duplicate_options()

	assert_str(duplicated.model).is_equal("haiku")
	assert_str(duplicated.effort).is_equal("low")
	assert_str(duplicated.cwd).is_equal("/tmp/project")
	assert_str(duplicated.cli_path).is_equal("/usr/local/bin/claude")
	assert_dict(duplicated.env).is_equal({"CLAUDE_PATH": "claude"})
	assert_str(duplicated.system_prompt).is_equal("Be brief.")
	assert_array(duplicated.allowed_tools).is_equal(["Read"])
	assert_array(duplicated.disallowed_tools).is_equal(["Edit"])
	assert_str(duplicated.permission_mode).is_equal("plan")
	assert_int(duplicated.max_turns).is_equal(2)
	assert_str(duplicated.resume).is_equal("resume-id")
	assert_str(duplicated.session_id).is_equal("session-id")


func test_subprocess_transport_builds_phase_4_command_flags() -> void:
	var options = ClaudeAgentOptions.new({
		"model": "haiku",
		"effort": "low",
		"system_prompt": "Stay concise.",
		"allowed_tools": ["Read", "Glob"],
		"disallowed_tools": ["Edit"],
		"permission_mode": "plan",
		"max_turns": 1,
		"resume": "resume-id",
		"session_id": "session-id",
		"cwd": "/tmp/project",
		"env": {"CLAUDE_TEST": "1"},
	})
	var transport = ClaudeSubprocessCLITransport.new(options)

	var args = transport.build_command_args()
	var process_spec = transport.build_process_spec()

	assert_array(args).contains_exactly([
		"--output-format", "stream-json",
		"--verbose",
		"--system-prompt", "Stay concise.",
		"--allowedTools", "Read,Glob",
		"--max-turns", "1",
		"--disallowedTools", "Edit",
		"--model", "haiku",
		"--permission-mode", "plan",
		"--resume", "resume-id",
		"--session-id", "session-id",
		"--effort", "low",
		"--input-format", "stream-json",
	])
	assert_str(str(process_spec.get("logical_path", ""))).is_equal("claude")
	assert_bool(str(process_spec.get("args", PackedStringArray())).contains("CLAUDE_TEST")).is_true()
	assert_bool(str(process_spec.get("args", PackedStringArray())).contains("/tmp/project")).is_true()
