extends Node
## Loads each level several times in a row, prints how long each load took (the
## level's own "built in" line adds the build phases), then quits. It lives in
## debug/ so it is exported, for measuring on the phone:
##   adb shell am start -n com.ridge.game/com.godot.game.GodotAppLauncher --esa command_line_params res://debug/load_benchmark.tscn
##   adb logcat -s godot

const LEVELS: Array[String] = ["res://levels/rally_road/rally_road.tscn", "res://levels/muddy_valley/muddy_valley.tscn",
		"res://levels/frozen_pass/frozen_pass.tscn", "res://levels/rock_canyon/rock_canyon.tscn"]
const ROUNDS := 3
## Frames to wait after freeing a level, so it is gone before the next load.
const SETTLE_FRAMES := 30


func _ready() -> void:
	await get_tree().process_frame
	for round in ROUNDS:
		for path in LEVELS:
			var started := Time.get_ticks_usec()
			var scene: PackedScene = load(path)
			var loaded := Time.get_ticks_usec()
			var level: Node = scene.instantiate()
			add_child(level)
			var ready := Time.get_ticks_usec()
			print("benchmark round %d %s: load %.2f s, instantiate and ready %.2f s, total %.2f s" % [round + 1,
					path.get_file().get_basename(), (loaded - started) / 1000000.0, (ready - loaded) / 1000000.0,
					(ready - started) / 1000000.0])
			await get_tree().process_frame
			level.queue_free()
			for i in SETTLE_FRAMES:
				await get_tree().process_frame
	print("benchmark done")
	get_tree().quit()
