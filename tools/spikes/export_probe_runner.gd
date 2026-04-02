extends Node


func _ready() -> void:
    var probe := preload("res://tools/spikes/claude_cli_probe.gd").new()
    var summary: Dictionary = await probe.run(get_tree(), OS.get_cmdline_user_args())
    get_tree().quit(0 if summary.get("ok", false) else 2)
