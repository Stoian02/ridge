extends Node
## Renders a level in a window at points along its road, saves a PNG for each
## and prints the build time and what was drawn there (primitives, draw calls,
## objects). Run from the project root:
##   godot --path . res://tools/level_shots.tscn -- res://levels/muddy_valley/muddy_valley.tscn 15 320 760 car=offroad_4x4
## The first argument after "--" is the level scene; the rest are distances along
## the road (m), plus an optional car=<id> to drive instead of the selected car.
## Shots are saved as build/level_shots/<level>[_<car>]_<distance>.png.
## For Test Ground, spots are lane X coordinates instead of road distances.
## Optional along=<metres> moves down that lane from its entry (z = 10).

const OUT_DIR := "res://build/level_shots"
## Frames to wait at each spot so the camera and visibility ranges settle.
const SETTLE_FRAMES := 45


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var car_id := ""
	var ground_along := -16.0
	var spots: Array[float] = []
	for arg in args.slice(1):
		if arg.begins_with("car="):
			car_id = arg.trim_prefix("car=")
		elif arg.begins_with("along="):
			ground_along = float(arg.trim_prefix("along="))
		else:
			spots.append(float(arg))
	if args.is_empty() or spots.is_empty():
		push_error("usage: -- <level scene> <distance> [distance...] [car=<id>]")
		get_tree().quit(1)
		return
	var level: Node3D = load(args[0]).instantiate()
	if not car_id.is_empty():
		var car := GameState.car_catalog.find_by_id(StringName(car_id))
		if car == null:
			push_error("unknown car: %s" % car_id)
			get_tree().quit(1)
			return
		(level.get_node("DrivingRig") as DrivingRig).car_override = car
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	add_child(level)
	await get_tree().process_frame
	var rig: DrivingRig = level.get_node("DrivingRig")
	var tag := args[0].get_file().get_basename()
	if not car_id.is_empty():
		tag += "_" + car_id
	if not level is RunLevel and ground_along != -16.0:
		tag += "_along_%03d" % roundi(ground_along)
	if level is RunLevel:
		print("%s built in %.2f s" % [tag, level.trail.build_seconds])
		while level.run.clock.stage == RunClock.Stage.COUNTDOWN:
			await get_tree().process_frame
	for spot in spots:
		if level is RunLevel:
			rig.place_car(level.trail.sampler.transform_at(spot, 1.0, level.trail.profile))
		else:
			var position := Vector3(spot, 1.0, 10.0 - ground_along)
			if ground_along != -16.0:
				await get_tree().physics_frame
				var ray := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 100.0, position - Vector3.UP * 100.0)
				var hit := level.get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty():
					position.y = (hit.position as Vector3).y + 1.0
			rig.place_car(Transform3D(Basis.IDENTITY, position))
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("%s/%s_%04d.png" % [OUT_DIR, tag, int(spot)]))
		print("%s at %4d m: %d primitives, %d draw calls, %d objects" % [tag, int(spot),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	get_tree().quit()
