extends SceneTree

func _init() -> void:
    var probe := preload("res://tools/spikes/claude_cli_probe.gd").new()
    var summary: Dictionary = await probe.run(self, OS.get_cmdline_user_args())
    quit(0 if summary.get("ok", false) else 2)
