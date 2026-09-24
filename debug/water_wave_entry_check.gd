extends Node
## Event-aligned entry diagnostics. Sampling/captures are NOT performance results.
## Headless prints measurements only; rendered runs capture the same snapshots.

var _level: Node3D
var _rig: DrivingRig
var _waves: WaterWaveTestGround
var _rendered := false
var _output := "user://wave_entry_check"
var _slow := false
var _failed := false


func _ready() -> void:
	_rendered = DisplayServer.get_name() != "headless"
	_slow = "--slow" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(_output)
	_level = load("res://levels/test_ground/test_ground.tscn").instantiate()
	(_level.get_node("DrivingRig") as DrivingRig).car_override = load("res://car/cars/offroad_4x4.tres")
	add_child(_level)
	_rig = _level.rig
	_waves = _level.water_waves
	_rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	if not _waves.set_mode(WaterWaveTestGround.Mode.CAR_WAVES):
		push_error(_waves.error)
		get_tree().quit(1)
		return
	var speeds: Array[float] = [3.0, 8.0, 14.0]
	if _slow:
		speeds.resize(1)
	for speed in speeds:
		await _drive(speed)
	_level.queue_free()
	await get_tree().process_frame
	print("Entry diagnostic complete: ", ProjectSettings.globalize_path(_output))
	get_tree().quit(1 if _failed else 0)


func _drive(speed: float) -> void:
	var hz := Engine.physics_ticks_per_second
	var start := Vector3(105.0, WaterCourse.pool_floor_height(0.0, 29.0) + 1.0, 59.0)
	_rig.place_car(Transform3D(Basis(Vector3.UP, PI), start))
	await _ticks(hz)
	_rig.car.linear_velocity = Vector3(0.0, 0.0, speed)
	for wheel in _rig.car.wheels:
		wheel.spin_speed = speed / _rig.car.stats.wheel_radius
	_rig.car.input.virtual_throttle = 1.0
	var entry_tick := -1
	var captures := 0
	var times: Array[float] = [0.25, 0.65, 1.2, 2.0]
	for tick in hz * 12:
		await get_tree().physics_frame
		if _slow:
			# Ordinary pedal inputs, not a fixed velocity or modified car tuning.
			var actual := _rig.car.linear_velocity.z
			_rig.car.input.virtual_throttle = clampf((speed - actual) * 1.5, 0.0, 1.0)
			_rig.car.input.virtual_brake = clampf(actual - speed - 0.1, 0.0, 1.0)
		if entry_tick < 0 and _waves.emitter.source.entries > 0:
			entry_tick = tick
			var observation := _waves.emitter.observation
			print("Entry event ", JSON.stringify({"launch_speed": speed, "paced_slow": _slow,
				"time": float(tick) / hz, "car": str(_rig.car.global_position),
				"origin": str(observation.at), "velocity": str(observation.velocity),
				"immersion": observation.body_immersion}))
		if entry_tick < 0:
			continue
		var age := float(tick - entry_tick) / hz
		if captures < times.size() and age >= times[captures]:
			_measure(speed, age)
			if _rendered:
				await _capture_pair("speed_%d_age_%d" % [int(speed), int(times[captures] * 100)])
			captures += 1
		if captures == times.size():
			break
	if entry_tick < 0:
		push_error("No natural entry for approach speed %.1f" % speed)
		_failed = true
	_rig.car.input.virtual_throttle = 0.0
	_rig.car.input.virtual_brake = 0.0


func _measure(speed: float, age: float) -> void:
	var view := _waves.runtime.views[0]
	var entry := WaterWaveSnapshot.new()
	_waves.runtime.field.write_snapshot(view.body_id, false, entry)
	entry.bow.z = 0.0
	for index in range(WaterWaveProfile.ENTRY_SLOTS, WaterWaveProfile.PACKET_SLOTS):
		entry.packets[index] = Vector4.ZERO
	var sampler := WaterWaveSampler.new()
	sampler.configure(view.sampler.topology, entry)
	var peak := 0.0
	var exposed := 0.0
	var peak_at := Vector2.ZERO
	var visible_vertices := 0
	var top := sampler.topology
	for index in top.vertices.size():
		var height := sampler.vertex_offset(index)
		var vertex := top.vertices[index] + view.origin
		var local := _rig.car.to_local(vertex)
		var outside := absf(local.x) > _rig.car.stats.body_size.x * 0.5 + 0.3 \
			or absf(local.z) > _rig.car.stats.body_size.z * 0.5 + 0.3
		if height > peak:
			peak = height
			peak_at = Vector2(vertex.x, vertex.z)
		if outside:
			exposed = maxf(exposed, height)
			if height >= 0.015:
				visible_vertices += 1
	print("Entry crest ", JSON.stringify({"launch_speed": speed, "age": age,
		"peak_m": peak, "outside_hull_peak_m": exposed, "peak_at": str(peak_at),
		"outside_vertices_over_15mm": visible_vertices, "packet": str(entry.packets[0])}))


func _capture_pair(label: String) -> void:
	get_tree().paused = true
	await _capture(label + "_chase")
	var side := Camera3D.new()
	_level.add_child(side)
	side.position = _rig.car.global_position + Vector3(-7.0, 4.0, -5.0)
	side.look_at(_rig.car.global_position)
	side.make_current()
	await _capture(label + "_side")
	_rig.camera.make_current()
	side.queue_free()
	get_tree().paused = false


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output + "/" + label + ".png")


func _ticks(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
