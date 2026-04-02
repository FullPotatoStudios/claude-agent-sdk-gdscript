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
