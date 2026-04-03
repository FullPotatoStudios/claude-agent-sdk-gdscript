# GdUnit generated TestSuite
extends GdUnitTestSuite

const DemoScene: PackedScene = preload("res://demo/phase7_demo.tscn")


func test_demo_scene_loads_and_uses_shipped_chat_panel() -> void:
	var demo = DemoScene.instantiate()
	get_tree().root.add_child(demo)
	await get_tree().process_frame

	var chat_panel: Node = demo.find_child("ClaudeChatPanel", true, false)
	assert_object(chat_panel).is_not_null()
	assert_object(chat_panel.get_client_node()).is_not_null()

	demo.queue_free()
	await get_tree().process_frame
