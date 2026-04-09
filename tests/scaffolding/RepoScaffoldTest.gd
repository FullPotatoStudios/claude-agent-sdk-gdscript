# GdUnit generated TestSuite
extends GdUnitTestSuite


func test_addon_runtime_tree_exists() -> void:
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/claude_agent_sdk/runtime"))).is_true()
	assert_bool(FileAccess.file_exists("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://addons/claude_agent_sdk/runtime/claude_sdk_client.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://addons/claude_agent_sdk/runtime/query.gd")).is_true()


func test_tests_and_probes_stay_outside_distributable_addon_tree() -> void:
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://tests"))).is_true()
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://tools/spikes"))).is_true()
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/claude_agent_sdk"))).is_true()
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/claude_agent_sdk/tests"))).is_false()
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons/claude_agent_sdk/tools"))).is_false()


func test_probe_runner_scene_remains_available() -> void:
	assert_bool(FileAccess.file_exists("res://tools/spikes/export_probe_runner.tscn")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/spikes/godot_cli_pipe_probe.gd")).is_true()


func test_examples_readme_lists_advanced_example_inventory() -> void:
	var readme := FileAccess.get_file_as_string("res://tools/examples/README.md")
	assert_str(readme).contains("agents_example.gd")
	assert_str(readme).contains("setting_sources_example.gd")
	assert_str(readme).contains("plugin_example.gd")
	assert_str(readme).contains("stderr_callback_example.gd")
	assert_str(readme).contains("include_partial_messages_example.gd")
	assert_str(readme).contains("hooks_example.gd")
	assert_str(readme).contains("tool_permission_callback_example.gd")
	assert_str(readme).contains("max_budget_usd_example.gd")
	assert_str(readme).contains("sdk_mcp_calculator_example.gd")
	assert_str(readme).contains("editor_plugin_demo/addons/claude_agent_sdk_editor_demo/")
	assert_bool(FileAccess.file_exists("res://tools/examples/agents_example.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/setting_sources_example.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/plugin_example.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/stderr_callback_example.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/include_partial_messages_example.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/hooks_example.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/tool_permission_callback_example.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/max_budget_usd_example.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/sdk_mcp_calculator_example.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/editor_plugin_demo/README.md")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/editor_plugin_demo/addons/claude_agent_sdk_editor_demo/plugin.cfg")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/editor_plugin_demo/addons/claude_agent_sdk_editor_demo/plugin.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/editor_plugin_demo/addons/claude_agent_sdk_editor_demo/claude_editor_dock.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/editor_plugin_demo/addons/claude_agent_sdk_editor_demo/claude_editor_dock.tscn")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/example_support.gd")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/fixtures/setting_sources_workspace/.claude/settings.local.json")).is_true()
	assert_bool(FileAccess.file_exists("res://tools/examples/fixtures/plugins/demo-plugin/.claude-plugin/plugin.json")).is_true()
