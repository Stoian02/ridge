extends Node
## Rendered, normally paced PC smoke check. NOT the deferred phone/all-water gate.
## Normal gameplay never instantiates this runner. Use isolated desktop saves.

const OUT := "user://wave_pc_playcheck"
var _level: Node3D
var _rig: DrivingRig
var _probe: WaterMeasurement
var _diagnosis := false
var _split := true
var _reverse := false
var _trace: Node


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("PC playcheck requires a real renderer")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	var config := ""
	if FileAccess.file_exists("user://wave_cost_diagnosis"):
		config = FileAccess.get_file_as_string("user://wave_cost_diagnosis")
		DirAccess.remove_absolute("user://wave_cost_diagnosis")
		_diagnosis = true
	var args := OS.get_cmdline_user_args()
	_diagnosis = _diagnosis or args.has("--diagnose")
	_split = not (config.contains("counts") or args.has("--counts"))
	_reverse = config.contains("reverse") or args.has("--reverse")
	if _diagnosis:
		_trace = load("res://debug/water_wave_cost_trace.gd").new()
		add_child(_trace)
	_level = load("res://levels/test_ground/test_ground.tscn").instantiate()
	(_level.get_node("DrivingRig") as DrivingRig).car_override = load("res://car/cars/offroad_4x4.tres")
	add_child(_level)
	_rig = _level.rig
	_rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	_probe = WaterMeasurement.new()
	add_child(_probe)
	print("PC wave playcheck: ", Engine.get_version_info().string, " ", DisplayServer.get_name(),
		" viewport=", DisplayServer.window_get_size(), " physics_hz=", Engine.physics_ticks_per_second,
		" max_fps=", Engine.max_fps, " controller-only costs; NOT all-water acceptance")
	var modes: Array[int] = [WaterWaveTestGround.Mode.OFF, WaterWaveTestGround.Mode.CAR_WAVES, WaterWaveTestGround.Mode.FULL]
	if _reverse:
		modes.reverse()
	print("Wave cost diagnosis=", _diagnosis, " split=", _split, " reverse=", _reverse)
	for mode: int in modes:
		_level.pause_menu.open()
		if mode != _level.water_waves.mode:
			# A back press during covered first use must not leave a hidden,
			# paused menu or resume physics behind the cover.
			get_tree().create_timer(0.01).timeout.connect(_level.pause_menu.handle_back)
		# Exercise the actual pause UI callback, including cover and mode reset.
		await _level.pause_menu.level_options._choose(mode)
		if _level.water_waves.mode != mode or not _level.pause_menu.is_open() or not get_tree().paused:
			push_error(_level.water_waves.error)
			get_tree().quit(1)
			return
		await _capture("menu_%d" % mode)
		_level.pause_menu.close()
		var start := Vector3(105.0, WaterCourse.pool_floor_height(0.0, 29.0) + 1.0, 59.0)
		_rig.place_car(Transform3D(Basis(Vector3.UP, PI), start))
		await _ticks(120)
		_rig.car.linear_velocity = Vector3(0.0, 0.0, 8.0)
		for wheel in _rig.car.wheels:
			wheel.spin_speed = 8.0 / _rig.car.stats.wheel_radius
		_rig.car.input.virtual_throttle = 1.0
		if _diagnosis:
			_trace.begin(_level.water_waves, _split)
		_probe.begin(_rig.car)
		await _ticks(600)
		var result := _probe.finish(OUT + "/mode_%d.csv" % mode)
		result["mode"] = mode
		if mode != WaterWaveTestGround.Mode.OFF:
			result["entries"] = _level.water_waves.emitter.source.entries
			result["wakes"] = _level.water_waves.emitter.source.wakes
			result["preparation_usec"] = _level.water_waves.preparation_usec
		print("PC wave playcheck result ", JSON.stringify(result))
		if _diagnosis:
			_trace.finish(OUT + "/cost_mode_%d.csv" % mode)
			# After the timed window; no live physics observes replay snapshots.
			_trace.replay()
		await _capture("drive_%d" % mode)
		_rig.car.input.virtual_throttle = 0.0
		await _ticks(360)
		await _capture("settling_%d" % mode)
		if mode == WaterWaveTestGround.Mode.CAR_WAVES:
			# Separate untimed replay catches the entry while its four-second
			# packet still exists; screenshots never contaminate the timed case.
			_rig.place_car(Transform3D(Basis(Vector3.UP, PI), start))
			await _ticks(120)
			_rig.car.linear_velocity = Vector3(0.0, 0.0, 8.0)
			_rig.car.input.virtual_throttle = 1.0
			for wheel in _rig.car.wheels:
				wheel.spin_speed = 8.0 / _rig.car.stats.wheel_radius
			await _ticks(240)
			await _capture("entry_chase")
			var side := Camera3D.new()
			_level.add_child(side)
			side.position = _rig.car.global_position + Vector3(-7.0, 4.0, -5.0)
			side.look_at(_rig.car.global_position)
			side.make_current()
			await _capture("entry_side")
			_rig.camera.make_current()
			side.queue_free()
	# Surface transparency/underside are inspected separately, not in the timer.
	var camera := Camera3D.new()
	_level.add_child(camera)
	camera.position = Vector3(101.0, 2.4, 128.0)
	camera.look_at(Vector3(105.0, 2.82, 133.0))
	camera.make_current()
	await _capture("underwater_full")
	_level._on_reset_requested()
	if _level.water_waves.runtime != null and _level.water_waves.runtime.field.active_count() != 0:
		push_error("Reset retained wave packets")
		get_tree().quit(1)
		return
	_level.queue_free()
	await get_tree().process_frame
	print("PC wave playcheck done: ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _ticks(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "/" + name + ".png")
