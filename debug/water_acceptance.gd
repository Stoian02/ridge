extends Node
## Repeated, real-time acceptance measurements; never changes gameplay tuning.
## On Android, launch with JSON options in user://water_acceptance (one-shot).
## Desktop: godot --path . res://debug/water_acceptance.tscn -- mode=course rounds=3

const FLAG := "user://water_acceptance"
const OUT := "user://water_acceptance_results"
var _options: Dictionary = {"mode": "course", "rounds": 3}
var _probe: WaterMeasurement
var _results: Array[Dictionary] = []


func _ready() -> void:
	if OS.is_debug_build() and FileAccess.file_exists(FLAG):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLAG))
		if parsed is Dictionary:
			_options.merge(parsed, true)
		DirAccess.remove_absolute(FLAG)
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			_options[pair[0]] = pair[1]
	DirAccess.make_dir_recursive_absolute(OUT)
	_probe = WaterMeasurement.new()
	add_child(_probe)
	print("water acceptance metadata ", JSON.stringify({"options": _options,
		"engine": Engine.get_version_info().string, "os": OS.get_name(),
		"processor": OS.get_processor_name(), "display": DisplayServer.get_name(),
		"max_fps": Engine.max_fps, "physics_hz": Engine.physics_ticks_per_second,
		"args": OS.get_cmdline_args(), "window": str(DisplayServer.window_get_size())}))
	if str(_options.mode) == "views":
		await _views()
	else:
		await _course()
	if _results.is_empty():
		push_error("Water acceptance selected no cases; check mode/level/spot/rounds")
		get_tree().quit(1)
		return
	var output := FileAccess.open(OUT + "/summary.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(_results, "\t"))
	output.close()
	print("water acceptance done: ", _results.size(), " cases; ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _prepare(path: String, id: StringName) -> Node3D:
	var level: Node3D = load(path).instantiate()
	var rig: DrivingRig = level.get_node("DrivingRig")
	rig.car_override = GameState.car_catalog.find_by_id(id)
	add_child(level)
	# Measurement-only A/B switch: same geometry/forces, original coarse query.
	if str(_options.get("index", "refined")) == "coarse":
		for body: WaterBody in rig.car.water.world.bodies:
			body._refined_bed_cells.clear()
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	rig.telemetry.visible = false
	return level


func _measure(rig: DrivingRig, label: String, ticks: int, trace: WaterHitchTrace = null) -> void:
	# Warm up a full second after the teleport, then collect every completed tick.
	for tick in 120:
		await get_tree().physics_frame
	if _options.has("layout"):
		_query_layout(rig.car)
	_probe.begin(rig.car)
	while _probe.rows.size() < ticks:
		await get_tree().physics_frame
	if trace != null:
		trace.stop()  # Exclude CSV export and screenshot waits from diagnostic frames.
	var result := _probe.finish(OUT + "/" + label + ".csv")
	if trace != null:
		print("water hitch result ", JSON.stringify(trace.finish(OUT + "/" + label)))
	result["case"] = label
	result["final_flooding"] = rig.car.water.state.flooding
	result["final_stalled"] = rig.car.water.state.stalled
	_results.append(result)
	print("water acceptance result ", JSON.stringify(result))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "/" + label + ".png")


## Untimed diagnostic of the exact probe positions and their local bed bins.
func _query_layout(car: Car) -> void:
	var positions := car.water.body_positions.duplicate()
	positions.append(car.water.intake_world_position)
	positions.append_array(car.water.wheel_positions)
	for body: WaterBody in car.water.world.bodies:
		var counts: Array[Dictionary] = []
		for point: Vector3 in positions:
			var key := WaterBody._cell(point.x, point.z)
			if not body._top_bins.has(key):
				continue
			var bed: PackedInt32Array = body._bed_bins.get(key, PackedInt32Array())
			var hits := 0
			var point_boxes := 0
			var half_metre_boxes := 0
			var low := Vector2(floorf(point.x * 2.0), floorf(point.z * 2.0)) * 0.5
			for triangle: int in bed:
				var a := body._bed[triangle * 3]
				var b := body._bed[triangle * 3 + 1]
				var c := body._bed[triangle * 3 + 2]
				var first := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
				var last := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
				if first.x <= point.x and first.y <= point.z and last.x >= point.x and last.y >= point.z:
					point_boxes += 1
				if first.x <= low.x + 0.5 and first.y <= low.y + 0.5 and last.x >= low.x and last.y >= low.y:
					half_metre_boxes += 1
				if is_finite(WaterBody.triangle_height(body._bed, triangle * 3, point.x, point.z)):
					hits += 1
			counts.append({"position": str(point), "top": body._top_bins[key].size(),
				"bed": bed.size(), "bed_hits": hits, "point_boxes": point_boxes, "half_metre_boxes": half_metre_boxes})
		if not counts.is_empty():
			print("water query layout ", JSON.stringify({"body": body.id, "probes": counts}))


func _cleanup(level: Node) -> void:
	level.queue_free()
	_probe.car = null
	for frame in 30:
		await get_tree().process_frame
	print("water acceptance cleanup nodes=%d orphans=%d resources=%d" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])


func _course() -> void:
	var cars: Array[StringName] = [&"offroad_4x4", &"rally", &"rally_tuned"]
	if _options.has("car"):
		cars = [StringName(str(_options.car))]
	for round in int(_options.rounds):
		for id in cars:
			var level := _prepare("res://levels/test_ground/test_ground.tscn", id)
			var rig: DrivingRig = level.get_node("DrivingRig")
			var course: WaterCourse = level.water_course
			print("water acceptance course round=%d car=%s build=%.6f" % [round + 1, id, course.build_seconds])
			var spots: Array[Vector3] = [Vector3(60.0, 0.45, 55.0), Vector3(60.0, 0.45, 95.0),
				Vector3(105.0, 2.5, 126.0), Vector3(155.0, 2.5, 126.0)]
			var names: Array[String] = ["shallow05", "shallow30", "calm", "current"]
			for index in spots.size():
				if _options.has("spot") and str(_options.spot) != names[index]:
					continue
				rig.place_car(Transform3D(Basis(Vector3.UP, PI), spots[index]))
				rig.car.linear_velocity = Vector3(0.0, 0.0, 3.0)
				var ticks := 600 if index < 2 else 1920
				var label := "%d_%s_%s" % [round + 1, id, names[index]]
				if wants_hitch_trace(_options):
					# Capture from first tick, including transitions normally lost to warm-up.
					var trace := WaterHitchTrace.new()
					add_child(trace)
					print("water hitch clock ", JSON.stringify({"case": label, "ticks_usec": Time.get_ticks_usec(),
						"unix_seconds": Time.get_unix_time_from_system()}))
					trace.begin(rig, ticks + 240)
					await _measure(rig, label, ticks, trace)
					trace.queue_free()
				else:
					await _measure(rig, label, ticks)
			await _cleanup(level)


static func wants_hitch_trace(options: Dictionary) -> bool:
	# JSON numbers arrive as floats; command-line values arrive as strings.
	return int(options.get("trace", 0)) == 1


func _views() -> void:
	for round in int(_options.rounds):
		for name: String in ["muddy_valley", "rock_canyon"]:
			if _options.has("level") and str(_options.level) != name:
				continue
			var id := &"rally" if name == "muddy_valley" else &"offroad_4x4"
			var level: RunLevel = _prepare("res://levels/%s/%s.tscn" % [name, name], id)
			while level.run.clock.stage == RunClock.Stage.COUNTDOWN:
				await get_tree().process_frame
			# Captures must not record finishes or reset a deliberately placed fixture.
			level.run.set_physics_process(false)
			level.resets.set_physics_process(false)
			var spots: Array[float] = []
			if name == "muddy_valley":
				spots.assign([780.0, 820.0, 860.0])
			else:
				spots.assign([340.0, 1290.0])
			for spot in spots:
				if _options.has("spot") and float(_options.spot) != spot:
					continue
				var target := level.trail.sampler.transform_at(spot, 1.0, level.trail.profile)
				if name == "muddy_valley":
					target.origin += level.trail.sampler.right(spot) * 17.0
					var query := PhysicsRayQueryParameters3D.create(target.origin + Vector3.UP * 100.0,
						target.origin - Vector3.UP * 100.0)
					query.exclude = [level.rig.car.get_rid()]
					var hit := level.get_world_3d().direct_space_state.intersect_ray(query)
					if not hit.is_empty():
						target.origin.y = (hit.position as Vector3).y + 1.0
				level.rig.place_car(target)
				await _measure(level.rig, "%d_%s_%d" % [round + 1, name, int(spot)], 1200)
			await _cleanup(level)
