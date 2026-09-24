extends Node
## Same static fixture on pre-water master and M6A; no water-class dependency.
## godot --path <tree> res://tools/creek_render_audit.tscn -- tag=baseline
## Use the same renderer/window size for both. road_shadows=off diagnoses the
## redundant shadow-map passes without editing the authored level resource.

func _ready() -> void:
	var root := get_tree().root
	var options: Dictionary = {"tag": "current"}
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	var level: RunLevel = load("res://levels/muddy_valley/muddy_valley.tscn").instantiate()
	var rig: DrivingRig = level.get_node("DrivingRig")
	rig.car_override = root.get_node("GameState").car_catalog.find_by_id(&"rally")
	add_child(level)
	await get_tree().process_frame
	level.run.set_physics_process(false)
	level.resets.set_physics_process(false)
	rig.car.freeze = true
	rig.car.set_physics_process(false)
	rig.camera.set_process(false)
	rig.effects.set_process(false)
	rig.effects.set_physics_process(false)
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	_hide_ui(level)
	if options.has("road_shadows") and str(options.road_shadows) == "off":
		for child: Node in level.trail.road_builder.get_children():
			if child is MeshInstance3D:
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var out := "user://creek_render_audit"
	DirAccess.make_dir_recursive_absolute(out)
	print("creek render metadata ", JSON.stringify({"tag": options.tag,
		"window": str(root.size), "engine": Engine.get_version_info().string,
		"options": options, "renderer": RenderingServer.get_current_rendering_method()}))
	for spot: float in [780.0, 820.0, 860.0]:
		var target := level.trail.sampler.transform_at(spot, 1.0, level.trail.profile)
		target.origin += level.trail.sampler.right(spot) * 17.0
		var query := PhysicsRayQueryParameters3D.create(target.origin + Vector3.UP * 100.0, target.origin - Vector3.UP * 100.0)
		query.exclude = [rig.car.get_rid()]
		var hit := level.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			target.origin.y = (hit.position as Vector3).y + 0.5
		rig.place_car(target)
		await _settle()
		print("creek render result ", JSON.stringify({"tag": options.tag, "spot": spot,
			"camera": str(rig.camera.global_transform), "primitives": _primitives(), "draws": _draws()}))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out + "/%s_%d.png" % [options.tag, int(spot)])
		for name: String in ["terrain_builder", "scatter_builder", "road_builder"]:
			var builder: Node3D = level.trail.get(name)
			builder.visible = false
			await _settle()
			print("creek render without ", JSON.stringify({"tag": options.tag, "spot": spot,
				"hidden": name, "primitives": _primitives(), "draws": _draws()}))
			builder.visible = true
	level.queue_free()
	for frame in 30:
		await get_tree().process_frame
	get_tree().quit()


func _settle() -> void:
	for frame in 12:
		await get_tree().process_frame


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	for child: Node in node.get_children():
		_hide_ui(child)


func _primitives() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)


func _draws() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
