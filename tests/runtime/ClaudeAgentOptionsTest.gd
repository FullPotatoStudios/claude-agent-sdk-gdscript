# GdUnit generated TestSuite
extends GdUnitTestSuite

const ClaudeSDKVersionScript := preload("res://addons/claude_agent_sdk/runtime/claude_sdk_version.gd")

func test_duplicate_options_preserves_phase_4_fields() -> void:
	var permission_callback := func(_tool_name: String, _input_data: Dictionary, _context):
		return ClaudePermissionResultAllow.new()
	var options = ClaudeAgentOptions.new({
		"model": "haiku",
		"effort": "low",
		"cwd": "/tmp/project",
		"cli_path": "/usr/local/bin/claude",
		"env": {"CLAUDE_PATH": "claude"},
		"system_prompt": "Be brief.",
		"tools": {"type": "preset", "preset": "claude_code"},
		"allowed_tools": ["Read"],
		"disallowed_tools": ["Edit"],
		"permission_mode": "plan",
		"max_turns": 2,
		"resume": "resume-id",
		"session_id": "session-id",
		"hooks": {
			"PreToolUse": [
				ClaudeHookMatcher.new({
					"matcher": "Bash",
					"hooks": [func(_input_data: Dictionary, _tool_use_id: String, _context): return {}],
					"timeout_sec": 30.0,
				}),
			],
		},
		"can_use_tool": permission_callback,
		"include_partial_messages": true,
		"output_format": {"type": "json_schema", "schema": {"type": "object"}},
		"mcp_servers": {"filesystem": {"command": "mcp-server", "args": ["stdio"]}},
	})

	var duplicated = options.duplicate_options()

	assert_str(duplicated.model).is_equal("haiku")
	assert_str(duplicated.effort).is_equal("low")
	assert_str(duplicated.cwd).is_equal("/tmp/project")
	assert_str(duplicated.cli_path).is_equal("/usr/local/bin/claude")
	assert_dict(duplicated.env).is_equal({"CLAUDE_PATH": "claude"})
	assert_str(duplicated.system_prompt).is_equal("Be brief.")
	assert_dict(duplicated.tools).is_equal({"type": "preset", "preset": "claude_code"})
	assert_array(duplicated.allowed_tools).is_equal(["Read"])
	assert_array(duplicated.disallowed_tools).is_equal(["Edit"])
	assert_str(duplicated.permission_mode).is_equal("plan")
	assert_int(duplicated.max_turns).is_equal(2)
	assert_str(duplicated.resume).is_equal("resume-id")
	assert_str(duplicated.session_id).is_equal("session-id")
	assert_bool(duplicated.can_use_tool.is_valid()).is_true()
	assert_bool(duplicated.include_partial_messages).is_true()
	assert_dict(duplicated.output_format).is_equal({"type": "json_schema", "schema": {"type": "object"}})
	assert_dict(duplicated.mcp_servers).is_equal({"filesystem": {"command": "mcp-server", "args": ["stdio"]}})
	assert_dict(duplicated.hooks).contains_keys(["PreToolUse"])
	assert_int((duplicated.hooks["PreToolUse"] as Array).size()).is_equal(1)


func test_duplicate_options_preserves_system_prompt_variants_and_tools_shapes() -> void:
	var preset_options = ClaudeAgentOptions.new({
		"system_prompt": {"type": "preset", "preset": "claude_code", "append": "Stay in character."},
		"tools": ["Read", "Glob"],
	})
	var preset_duplicate = preset_options.duplicate_options()
	assert_dict(preset_duplicate.system_prompt).is_equal({
		"type": "preset",
		"preset": "claude_code",
		"append": "Stay in character.",
	})
	assert_array(preset_duplicate.tools).is_equal(["Read", "Glob"])

	var file_options = ClaudeAgentOptions.new({
		"system_prompt": {"type": "file", "path": "res://prompts/game.md"},
		"tools": [],
	})
	var file_duplicate = file_options.duplicate_options()
	assert_dict(file_duplicate.system_prompt).is_equal({
		"type": "file",
		"path": "res://prompts/game.md",
	})
	assert_array(file_duplicate.tools).is_empty()

	var default_options = ClaudeAgentOptions.new()
	assert_that(default_options.tools).is_null()


func test_duplicate_options_preserves_mixed_external_and_sdk_mcp_servers() -> void:
	var sdk_server := ClaudeMcp.create_sdk_server(
		"tools",
		"1.0.0",
		[
				ClaudeMcp.tool(
					"echo",
					"Echo input",
					ClaudeMcp.schema_object({"text": ClaudeMcp.schema_scalar("string")}, ["text"]),
					func(tool_args: Dictionary): return {"content": [{"type": "text", "text": str(tool_args.get("text", ""))}]}
				),
		]
	)
	var options = ClaudeAgentOptions.new({
		"mcp_servers": {
			"sdk_tools": sdk_server,
			"filesystem": {"command": "mcp-server", "args": ["stdio"]},
		},
	})

	var duplicated = options.duplicate_options()
	var duplicated_servers := duplicated.mcp_servers as Dictionary

	assert_dict(duplicated_servers).contains_keys(["sdk_tools", "filesystem"])
	assert_str(str((duplicated_servers["sdk_tools"] as Dictionary).get("type", ""))).is_equal("sdk")
	assert_bool((duplicated_servers["sdk_tools"] as Dictionary).get("instance") == (sdk_server as Dictionary).get("instance")).is_true()
	assert_dict(duplicated_servers["filesystem"]).is_equal({"command": "mcp-server", "args": ["stdio"]})


func test_subprocess_transport_builds_phase_4_command_flags() -> void:
	var permission_callback := func(_tool_name: String, _input_data: Dictionary, _context):
		return ClaudePermissionResultAllow.new()
	var options = ClaudeAgentOptions.new({
		"model": "haiku",
		"effort": "low",
		"system_prompt": "Stay concise.",
		"tools": ["Read", "Glob"],
		"allowed_tools": ["Read", "Glob"],
		"disallowed_tools": ["Edit"],
		"permission_mode": "plan",
		"max_turns": 1,
		"resume": "resume-id",
		"session_id": "session-id",
		"cwd": "/tmp/project",
		"env": {"CLAUDE_TEST": "1"},
		"include_partial_messages": true,
		"output_format": {"type": "json_schema", "schema": {"type": "object", "properties": {"ok": {"type": "boolean"}}}},
		"mcp_servers": {"filesystem": {"command": "mcp-server", "args": ["stdio"]}},
		"can_use_tool": permission_callback,
	})
	var transport = ClaudeSubprocessCLITransport.new(options)

	var args = transport.build_command_args()
	var process_spec = transport.build_process_spec()

	assert_array(args).contains_exactly([
		"--output-format", "stream-json",
		"--verbose",
		"--system-prompt", "Stay concise.",
		"--tools", "Read,Glob",
		"--allowedTools", "Read,Glob",
		"--max-turns", "1",
		"--disallowedTools", "Edit",
		"--model", "haiku",
			"--permission-mode", "plan",
			"--resume", "resume-id",
			"--session-id", "session-id",
			"--effort", "low",
			"--include-partial-messages",
			"--permission-prompt-tool", "stdio",
			"--json-schema", args[args.find("--json-schema") + 1],
			"--mcp-config", args[args.find("--mcp-config") + 1],
			"--input-format", "stream-json",
		])
	assert_dict(JSON.parse_string(args[args.find("--json-schema") + 1])).is_equal({
		"type": "object",
		"properties": {
			"ok": {"type": "boolean"},
		},
	})
	assert_dict(JSON.parse_string(args[args.find("--mcp-config") + 1])).is_equal({
		"mcpServers": {
			"filesystem": {
				"command": "mcp-server",
				"args": ["stdio"],
			},
		},
	})
	assert_str(str(process_spec.get("logical_path", ""))).is_equal("claude")
	assert_bool(str(process_spec.get("args", PackedStringArray())).contains("CLAUDE_TEST")).is_true()
	assert_bool(str(process_spec.get("args", PackedStringArray())).contains("/tmp/project")).is_true()
	assert_bool(str(process_spec.get("args", PackedStringArray())).contains("CLAUDE_CODE_ENTRYPOINT")).is_true()
	assert_bool(str(process_spec.get("args", PackedStringArray())).contains("CLAUDE_AGENT_SDK_VERSION")).is_true()
	assert_bool(str(process_spec.get("args", PackedStringArray())).contains("PWD")).is_true()
	assert_bool(str(process_spec.get("args", PackedStringArray())).contains("CLAUDECODE")).is_true()


func test_subprocess_transport_omits_phase_5_flags_by_default() -> void:
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new())
	var args = transport.build_command_args()

	assert_bool(args.has("--include-partial-messages")).is_false()
	assert_bool(args.has("--permission-prompt-tool")).is_false()
	assert_bool(args.has("--json-schema")).is_false()
	assert_bool(args.has("--mcp-config")).is_false()
	assert_bool(args.has("--tools")).is_false()


func test_subprocess_transport_supports_system_prompt_variants() -> void:
	var preset_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"system_prompt": {"type": "preset", "preset": "claude_code"},
	}))
	var preset_args := preset_transport.build_command_args()
	assert_bool(preset_args.has("--system-prompt")).is_false()
	assert_bool(preset_args.has("--append-system-prompt")).is_false()
	assert_bool(preset_args.has("--system-prompt-file")).is_false()

	var append_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"system_prompt": {"type": "preset", "preset": "claude_code", "append": "Mention gameplay implications."},
	}))
	var append_args := append_transport.build_command_args()
	assert_array(append_args).contains([
		"--append-system-prompt",
		"Mention gameplay implications.",
	])

	var file_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"system_prompt": {"type": "file", "path": "res://demo_prompt.md"},
	}))
	var file_args := file_transport.build_command_args()
	assert_array(file_args).contains([
		"--system-prompt-file",
		ProjectSettings.globalize_path("res://demo_prompt.md"),
	])


func test_subprocess_transport_supports_tools_unset_empty_and_preset() -> void:
	var empty_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"tools": [],
	}))
	var empty_args := empty_transport.build_command_args()
	assert_array(empty_args).contains(["--tools", ""])

	var preset_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"tools": {"type": "preset", "preset": "claude_code"},
	}))
	var preset_args := preset_transport.build_command_args()
	assert_array(preset_args).contains(["--tools", "default"])


func test_subprocess_transport_omits_sdk_servers_from_mcp_config() -> void:
	var sdk_server := ClaudeMcp.create_sdk_server(
		"tools",
		"1.0.0",
		[
				ClaudeMcp.tool(
					"echo",
					"Echo input",
					ClaudeMcp.schema_object({"text": ClaudeMcp.schema_scalar("string")}, ["text"]),
					func(tool_args: Dictionary): return {"content": [{"type": "text", "text": str(tool_args.get("text", ""))}]}
				),
			]
		)
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"mcp_servers": {
			"sdk_tools": sdk_server,
			"filesystem": {"command": "mcp-server", "args": ["stdio"]},
		},
	}))
	var args = transport.build_command_args()
	var mcp_config: Dictionary = JSON.parse_string(args[args.find("--mcp-config") + 1])

	assert_dict(mcp_config).is_equal({
		"mcpServers": {
			"filesystem": {
				"command": "mcp-server",
				"args": ["stdio"],
			},
		},
	})


func test_subprocess_transport_builds_default_environment_overrides() -> void:
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"cwd": "/tmp/project",
		"env": {"CUSTOM_FLAG": "1"},
	}))

	assert_bool(transport.filters_inherited_claudecode()).is_true()
	assert_dict(transport.build_environment_overrides()).is_equal({
		"CLAUDE_CODE_ENTRYPOINT": "sdk-gd",
		"CLAUDE_AGENT_SDK_VERSION": ClaudeSDKVersionScript.get_version(),
		"PWD": "/tmp/project",
		"CUSTOM_FLAG": "1",
	})


func test_subprocess_transport_allows_explicit_claudecode_override() -> void:
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"env": {
			"CLAUDECODE": "1",
			"CLAUDE_CODE_ENTRYPOINT": "custom-entry",
			"CLAUDE_AGENT_SDK_VERSION": "custom-version",
		},
	}))

	assert_bool(transport.filters_inherited_claudecode()).is_false()
	assert_dict(transport.build_environment_overrides()).is_equal({
		"CLAUDE_CODE_ENTRYPOINT": "custom-entry",
		"CLAUDE_AGENT_SDK_VERSION": "custom-version",
		"CLAUDECODE": "1",
	})


func test_sdk_version_reads_canonical_version_file() -> void:
	assert_str(ClaudeSDKVersionScript.get_version()).is_equal("0.1.0")
