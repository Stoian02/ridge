extends Node
## Repeatable water-only physics timing, usable headless or on the phone.
## godot --path . res://debug/water_benchmark.tscn -- car=offroad_4x4
## Phone: adb shell run-as com.ridge.game touch files/water_benchmark; launch.
## Samples real ticks (not a synthetic tight query loop); prints p95 and max.

const COURSE := preload("res://levels/test_ground/test_ground.tscn")
const SAMPLES := 600


func _ready() -> void:
	var id := &"offroad_4x4"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("car="):
			id = StringName(arg.trim_prefix("car="))
	var level: Node3D = COURSE.instantiate()
	var rig: DrivingRig = level.get_node("DrivingRig")
	rig.car_override = GameState.car_catalog.find_by_id(id)
	if rig.car_override == null:
		push_error("Unknown water benchmark car: " + id)
		get_tree().quit(1)
		return
	add_child(level)
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	rig.telemetry.visible = false
	var course: WaterCourse = level.water_course
	print("water benchmark %s course build %.6f s, geometry %d primitives" % [
		id, course.build_seconds, course.geometry_primitives])
	var spots: Array[Vector3] = [Vector3(60.0, 0.45, 55.0),
		Vector3(60.0, 0.45, 95.0), Vector3(105.0, 2.5, 126.0), Vector3(155.0, 2.5, 126.0)]
	var names: Array[String] = ["shallow_05", "shallow_30", "calm_deep", "current_deep"]
	for i in spots.size():
		rig.place_car(Transform3D(Basis(Vector3.UP, PI), spots[i]))
		rig.car.linear_velocity = Vector3(0.0, 0.0, 3.0)
		course.water_world.reset_metrics()
		var times := PackedFloat64Array()
		var draws := 0
		var primitives := 0
		for tick in SAMPLES:
			await get_tree().physics_frame
			if tick >= 30:
				times.append(rig.car.water.water_time_usec / 1000.0)
			draws = maxi(draws, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			primitives = maxi(primitives, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		times.sort()
		print("water benchmark %s %s: n=%d p95=%.3f ms max=%.3f ms queries=%d triangles=%d draw=%d primitives=%d flood=%.3f stalled=%s" % [
			id, names[i], times.size(), times[floori((times.size() - 1) * 0.95)], times[-1],
			course.water_world.query_count, course.water_world.triangle_tests, draws, primitives,
			rig.car.water.state.flooding, rig.car.water.state.stalled])
	level.queue_free()
	for frame in 30:
		await get_tree().process_frame
	print("water benchmark cleanup: nodes %d orphans %d resources %d" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	get_tree().quit()
