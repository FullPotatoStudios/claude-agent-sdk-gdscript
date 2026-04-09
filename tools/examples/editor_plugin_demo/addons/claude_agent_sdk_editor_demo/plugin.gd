@tool
extends EditorPlugin

var _dock: Control = null


func _enter_tree() -> void:
	var dock_scene := load(_dock_scene_path()) as PackedScene
	if dock_scene == null:
		push_warning("Claude editor demo dock scene is missing.")
		return
	_dock = dock_scene.instantiate()
	if _dock == null:
		push_warning("Claude editor demo dock could not be instantiated.")
		return
	_dock.name = "Claude"
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock != null and is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
	_dock = null


func _dock_scene_path() -> String:
	return get_script().resource_path.get_base_dir().path_join("claude_editor_dock.tscn")
