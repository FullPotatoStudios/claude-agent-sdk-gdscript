# GdUnit generated TestSuite
extends GdUnitTestSuite

const EditorDockScene := preload("res://tools/examples/editor_plugin_demo/addons/claude_agent_sdk_editor_demo/claude_editor_dock.tscn")


func test_editor_dock_example_mounts_chat_panel_with_project_scoped_defaults() -> void:
	var dock = EditorDockScene.instantiate()
	get_tree().root.add_child(dock)
	await _await_frames(2)

	var panel = dock.get_chat_panel()
	assert_object(panel).is_not_null()
	assert_str(dock.get_status_message()).contains("current project root")

	var configured_options = panel.get("_configured_options") as ClaudeAgentOptions
	assert_object(configured_options).is_not_null()
	assert_str(configured_options.cwd).is_equal(ProjectSettings.globalize_path("res://"))
	assert_str(configured_options.model).is_equal("haiku")
	assert_str(configured_options.effort).is_equal("low")
	assert_str(configured_options.permission_mode).is_equal("plan")

	dock.queue_free()
	await _await_frames(1)


func test_editor_plugin_example_script_loads() -> void:
	assert_object(load("res://tools/examples/editor_plugin_demo/addons/claude_agent_sdk_editor_demo/plugin.gd")).is_not_null()


func _await_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame
