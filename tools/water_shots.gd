extends Node
## Driving-camera water review, plus one elevated course overview/underside.
## DISPLAY=:1 WAYLAND_DISPLAY=wayland-1 godot --path . res://tools/water_shots.tscn

const OUT := "res://build/water_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var level: Node3D = load("res://levels/test_ground/test_ground.tscn").instantiate()
	var rig: DrivingRig = level.get_node("DrivingRig")
	rig.car_override = GameState.car_catalog.find_by_id(&"offroad_4x4")
	add_child(level)
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	rig.telemetry.visible = false
	var positions: Array[Vector3] = [Vector3(60.0, 0.9, 24.0), Vector3(105.0, 0.9, 24.0),
		Vector3(155.0, 0.9, 24.0), Vector3(60.0, 0.9, 46.0), Vector3(105.0, 3.6, 57.0),
		Vector3(155.0, 3.6, 57.0), Vector3(105.0, 2.7, 73.0)]
	var names: Array[String] = ["shallow_sign", "calm_sign", "current_sign", "shallow_entry",
		"calm_entry", "current_entry", "submerged_tyres"]
	for i in positions.size():
		rig.place_car(Transform3D(Basis(Vector3.UP, PI), positions[i]))
		for frame in 45:
			await get_tree().process_frame
		await _capture(names[i])
	rig.car.freeze = true
	rig.camera.set_process(false)
	rig.camera.global_position = Vector3(180.0, 55.0, 35.0)
	rig.camera.look_at(Vector3(110.0, 0.0, 120.0), Vector3.UP)
	await _capture("course_overview")
	rig.place_car(Transform3D(Basis(Vector3.UP, PI), Vector3(105.0, 0.7, 126.0)))
	rig.camera.global_position = Vector3(105.0, 1.0, 119.0)
	rig.camera.look_at(Vector3(105.0, 2.6, 128.0), Vector3.UP)
	for frame in 90:
		await get_tree().process_frame
	await _capture("underwater_stall")
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _capture(label: String) -> void:
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, label]))
	print("water shot %s: %d primitives, %d draw calls" % [label,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
