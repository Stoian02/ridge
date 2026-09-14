extends Node
## Renders a level in a window at points along its road, saves a PNG for each
## and prints the build time and what was drawn there (primitives, draw calls,
## objects). Run from the project root:
##   godot --path . res://tools/level_shots.tscn -- res://levels/muddy_valley/muddy_valley.tscn 15 320 760
## The first argument after "--" is the level scene, the rest are distances along
## the road (m). Shots are saved as build/level_shots/<level>_<distance>.png.

const OUT_DIR := "res://build/level_shots"
## Frames to wait at each spot so the camera and visibility ranges settle.
const SETTLE_FRAMES := 45


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <level scene> <distance> [distance...]")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var level: RunLevel = load(args[0]).instantiate()
	add_child(level)
	await get_tree().process_frame
	var tag := args[0].get_file().get_basename()
	print("%s built in %.2f s" % [tag, level.trail.build_seconds])
	for arg in args.slice(1):
		var spot := float(arg)
		level.rig.place_car(level.trail.sampler.transform_at(spot, 1.0, level.trail.profile))
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("%s/%s_%04d.png" % [OUT_DIR, tag, int(spot)]))
		print("%s at %4d m: %d primitives, %d draw calls, %d objects" % [tag, int(spot),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	get_tree().quit()
