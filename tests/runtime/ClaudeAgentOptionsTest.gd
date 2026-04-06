# GdUnit generated TestSuite
extends GdUnitTestSuite

const ClaudeSDKVersionScript := preload("res://addons/claude_agent_sdk/runtime/claude_sdk_version.gd")
const ClaudeAgentDefinitionScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_definition.gd")

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

	var preset_normalized = ClaudeAgentOptions.new({
		"tools": {"type": "preset", "preset": "future-default"},
	})
	assert_dict(preset_normalized.tools).is_equal({
		"type": "preset",
		"preset": "claude_code",
	})

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


func test_duplicate_options_preserves_agents_and_setting_sources() -> void:
	var options = ClaudeAgentOptions.new({
		"agents": {
			"reviewer": ClaudeAgentDefinitionScript.new({
				"description": "Reviews code",
				"prompt": "Be strict and helpful.",
				"tools": ["Read", "Grep"],
				"disallowed_tools": [],
				"model": "sonnet",
				"skills": ["code-review"],
				"memory": "project",
				"mcp_servers": ["filesystem", {"gameplay": {"command": "game-mcp"}}],
				"initial_prompt": "Start by scanning tests.",
				"max_turns": 3,
				"background": false,
				"effort": "high",
				"permission_mode": "plan",
			}),
			"doc-writer": {
				"description": "Writes docs",
				"prompt": "Explain clearly.",
			},
		},
		"setting_sources": ["user", "project"],
	})

	var duplicated = options.duplicate_options()
	assert_dict(duplicated.agents).contains_keys(["reviewer", "doc-writer"])
	assert_object(duplicated.agents["reviewer"]).is_instanceof(ClaudeAgentDefinitionScript)
	assert_object(duplicated.agents["doc-writer"]).is_instanceof(ClaudeAgentDefinitionScript)

	var reviewer: ClaudeAgentDefinition = duplicated.agents["reviewer"]
	var doc_writer: ClaudeAgentDefinition = duplicated.agents["doc-writer"]
	assert_str(reviewer.description).is_equal("Reviews code")
	assert_str(reviewer.prompt).is_equal("Be strict and helpful.")
	assert_array(reviewer.tools).is_equal(["Read", "Grep"])
	assert_array(reviewer.disallowed_tools).is_empty()
	assert_str(reviewer.model).is_equal("sonnet")
	assert_array(reviewer.skills).is_equal(["code-review"])
	assert_str(reviewer.memory).is_equal("project")
	assert_array(reviewer.mcp_servers).is_equal(["filesystem", {"gameplay": {"command": "game-mcp"}}])
	assert_str(reviewer.initial_prompt).is_equal("Start by scanning tests.")
	assert_int(reviewer.max_turns).is_equal(3)
	assert_bool(reviewer.background).is_false()
	assert_str(str(reviewer.effort)).is_equal("high")
	assert_str(reviewer.permission_mode).is_equal("plan")
	assert_str(doc_writer.description).is_equal("Writes docs")
	assert_str(doc_writer.prompt).is_equal("Explain clearly.")
	assert_that(doc_writer.tools).is_null()
	assert_array(duplicated.setting_sources).is_equal(["user", "project"])


func test_duplicate_options_preserves_transport_first_advanced_cli_fields() -> void:
	var options = ClaudeAgentOptions.new({
		"continue_conversation": true,
		"fallback_model": "sonnet",
		"betas": ["context-1m-2025-08-07", "custom-beta"],
		"permission_prompt_tool_name": "custom-permission",
		"add_dirs": ["res://addons", "/tmp/project"],
		"max_budget_usd": 1.25,
		"max_thinking_tokens": 4096,
		"thinking": {"type": "enabled", "budget_tokens": 2048},
		"task_budget": {"total": 12345},
	})

	var duplicated = options.duplicate_options()

	assert_bool(duplicated.continue_conversation).is_true()
	assert_str(duplicated.fallback_model).is_equal("sonnet")
	assert_array(duplicated.betas).is_equal(["context-1m-2025-08-07", "custom-beta"])
	assert_str(duplicated.permission_prompt_tool_name).is_equal("custom-permission")
	assert_array(duplicated.add_dirs).is_equal(["res://addons", "/tmp/project"])
	assert_float(float(duplicated.max_budget_usd)).is_equal(1.25)
	assert_int(int(duplicated.max_thinking_tokens)).is_equal(4096)
	assert_dict(duplicated.thinking).is_equal({"type": "enabled", "budget_tokens": 2048})
	assert_dict(duplicated.task_budget).is_equal({"total": 12345})


func test_apply_normalizes_agent_definitions_from_upstream_wire_keys() -> void:
	var options = ClaudeAgentOptions.new({
		"agents": {
			"wire-agent": {
				"description": "Wire-format agent",
				"prompt": "Use upstream-style keys.",
				"disallowedTools": ["Write"],
				"mcpServers": ["filesystem"],
				"initialPrompt": "Start carefully.",
				"maxTurns": 3,
				"permissionMode": "plan",
			},
		},
	})

	var agent: ClaudeAgentDefinition = options.agents["wire-agent"]
	assert_array(agent.disallowed_tools).is_equal(["Write"])
	assert_array(agent.mcp_servers).is_equal(["filesystem"])
	assert_str(agent.initial_prompt).is_equal("Start carefully.")
	assert_int(int(agent.max_turns)).is_equal(3)
	assert_str(agent.permission_mode).is_equal("plan")


func test_apply_normalizes_transport_first_advanced_cli_fields() -> void:
	var options = ClaudeAgentOptions.new({
		"continue_conversation": true,
		"fallback_model": "sonnet",
		"betas": ["context-1m-2025-08-07"],
		"permission_prompt_tool_name": "custom-permission",
		"add_dirs": ["res://addons", "/tmp/project"],
		"max_budget_usd": 0.5,
		"max_thinking_tokens": 2048,
		"thinking": {"type": "adaptive"},
		"task_budget": {"total": 5000},
	})

	assert_bool(options.continue_conversation).is_true()
	assert_str(options.fallback_model).is_equal("sonnet")
	assert_array(options.betas).is_equal(["context-1m-2025-08-07"])
	assert_str(options.permission_prompt_tool_name).is_equal("custom-permission")
	assert_array(options.add_dirs).is_equal(["res://addons", "/tmp/project"])
	assert_float(float(options.max_budget_usd)).is_equal(0.5)
	assert_int(int(options.max_thinking_tokens)).is_equal(2048)
	assert_dict(options.thinking).is_equal({"type": "adaptive"})
	assert_dict(options.task_budget).is_equal({"total": 5000})


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
		"--permission-prompt-tool", "stdio",
			"--permission-mode", "plan",
			"--resume", "resume-id",
			"--session-id", "session-id",
			"--json-schema", args[args.find("--json-schema") + 1],
			"--mcp-config", args[args.find("--mcp-config") + 1],
			"--include-partial-messages",
			"--effort", "low",
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

	var normalized_preset_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"tools": {"type": "preset", "preset": "future-default"},
	}))
	var normalized_preset_args := normalized_preset_transport.build_command_args()
	assert_array(normalized_preset_args).contains(["--tools", "default"])


func test_subprocess_transport_supports_setting_sources_only_when_non_empty() -> void:
	var unset_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new())
	var unset_args := unset_transport.build_command_args()
	assert_bool(unset_args.has("--setting-sources")).is_false()

	var empty_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"setting_sources": [],
	}))
	var empty_args := empty_transport.build_command_args()
	assert_bool(empty_args.has("--setting-sources")).is_false()

	var configured_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"setting_sources": ["user", "project", "local"],
	}))
	var configured_args := configured_transport.build_command_args()
	assert_array(configured_args).contains(["--setting-sources", "user,project,local"])


func test_subprocess_transport_supports_transport_first_advanced_cli_flags() -> void:
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"continue_conversation": true,
		"fallback_model": "sonnet",
		"betas": ["context-1m-2025-08-07", "custom-beta"],
		"permission_prompt_tool_name": "custom-permission",
		"add_dirs": ["res://addons", "/tmp/project"],
		"max_budget_usd": 1.25,
		"task_budget": {"total": 12345},
	}))
	var args := transport.build_command_args()

	assert_array(args).contains(["--continue"])
	assert_array(args).contains(["--fallback-model", "sonnet"])
	assert_array(args).contains(["--betas", "context-1m-2025-08-07,custom-beta"])
	assert_array(args).contains(["--permission-prompt-tool", "custom-permission"])
	assert_array(args).contains(["--max-budget-usd", "1.25"])
	assert_array(args).contains(["--task-budget", "12345"])

	var add_dir_indices: Array[int] = []
	for index in range(args.size()):
		if args[index] == "--add-dir":
			add_dir_indices.append(index)
	assert_int(add_dir_indices.size()).is_equal(2)
	assert_str(args[add_dir_indices[0] + 1]).is_equal("res://addons")
	assert_str(args[add_dir_indices[1] + 1]).is_equal("/tmp/project")


func test_subprocess_transport_resolves_thinking_precedence() -> void:
	var deprecated_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"max_thinking_tokens": 2048,
	}))
	assert_array(deprecated_transport.build_command_args()).contains(["--max-thinking-tokens", "2048"])

	var adaptive_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"thinking": {"type": "adaptive"},
	}))
	assert_array(adaptive_transport.build_command_args()).contains(["--max-thinking-tokens", "32000"])

	var adaptive_with_deprecated_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"max_thinking_tokens": 2048,
		"thinking": {"type": "adaptive"},
	}))
	assert_array(adaptive_with_deprecated_transport.build_command_args()).contains(["--max-thinking-tokens", "2048"])

	var enabled_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"max_thinking_tokens": 2048,
		"thinking": {"type": "enabled", "budget_tokens": 8192},
	}))
	assert_array(enabled_transport.build_command_args()).contains(["--max-thinking-tokens", "8192"])

	var disabled_transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"max_thinking_tokens": 2048,
		"thinking": {"type": "disabled"},
	}))
	assert_array(disabled_transport.build_command_args()).contains(["--max-thinking-tokens", "0"])


func test_subprocess_transport_rejects_explicit_permission_prompt_when_can_use_tool_is_configured() -> void:
	var permission_callback := func(_tool_name: String, _input_data: Dictionary, _context):
		return ClaudePermissionResultAllow.new()
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"can_use_tool": permission_callback,
		"permission_prompt_tool_name": "custom-permission",
	}))

	var args := transport.build_command_args()

	assert_int(args.size()).is_equal(0)
	assert_str(transport.get_last_error()).contains("cannot be used with permission_prompt_tool_name")


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
