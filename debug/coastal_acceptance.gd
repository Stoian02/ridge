extends Node
## Opt-in real-renderer acceptance. No catalog, car tuning or progress writes.
## Phone: JSON in user://coastal_acceptance; desktop: -- mode=loads|views|drive|soak.
## Cover timings belong to this harness, not the uncatalogued menu-loading path.

const FLAG := "user://coastal_acceptance"
const OUT := "user://coastal_acceptance_results"
const LEVEL := "res://levels/coastal_highway/coastal_highway.tscn"
const CARS: Array[String] = ["rally", "rally_tuned", "offroad_4x4"]
const VIEWS := {"opening": 180.0, "tunnel_exit": 710.0, "jump": 850.0,
	"landing": 900.0, "descent": 1130.0, "cove": 1700.0, "bridge": 2060.0, "finish": 2960.0}
var options: Dictionary
var meter: CoastalFrameMeasurement
var _failed := false


func _ready() -> void:
	options = read_options(OS.get_cmdline_user_args(), FLAG if OS.is_debug_build() else "")
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Coastal acceptance requires a real renderer; use route GUT tests headless")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	meter = CoastalFrameMeasurement.new()
	add_child(meter)
	_store("metadata", {"options": options, "os": OS.get_name(),
		"processor": OS.get_processor_name(), "engine": Engine.get_version_info(),
		"window": DisplayServer.window_get_size(), "renderer": RenderingServer.get_current_rendering_method(),
		"physics_hz": Engine.physics_ticks_per_second, "max_fps": Engine.max_fps,
		"unix_time": Time.get_unix_time_from_system(), "scope": "B1 dry; no B2 headroom claim"})
	if options.mode == "loads":
		for repeat in 4:
			var level := await _load_level("load_%d" % repeat, "rally")
			await _cleanup(level)
	elif options.mode == "drive":
		var cars: Array[String] = CARS.duplicate()
		if options.car != "all":
			cars.assign([options.car])
		for id: String in cars:
			var level := await _load_level("drive_" + id, id)
			meter.begin(level)
			var probe := CoastalRouteProbe.new()
			var route := await probe.attempt(level, options.tc)
			var measured := meter.finish(OUT.path_join("drive_%s_frames.csv" % id))
			_store("drive_" + id, {"route": route, "frames": measured})
			_store("drive_" + id + "_trajectory", {"samples": probe.samples})
			_failed = _failed or not route.reached or route.resets != 0
			await _cleanup(level)
	else:
		var level := await _load_level(options.mode, "rally")
		var camera := Camera3D.new()
		level.add_child(camera)
		camera.current = true
		camera.far = level.rig.camera.far
		level.resets.set_physics_process(false)
		if options.mode == "soak":
			_place_view(level, camera, "opening")
			await _seconds(10.0)
			await _capture_case(level, "soak", 300.0)
		else:
			for round_index in 2:
				var names := VIEWS.keys()
				if round_index == 1:
					names.reverse()
				for view: String in names:
					_place_view(level, camera, view)
					await _seconds(2.0)
					await _capture_case(level, "view_%d_%s" % [round_index, view], options.seconds)
		await _cleanup(level)
	_store("complete", {"mode": options.mode, "functional_failure": _failed,
		"note": "Budget decisions require inspecting all distributions; exit 0 is not a performance pass"})
	get_tree().quit.call_deferred(1 if _failed else 0)


func _load_level(label: String, car_id: String) -> RunLevel:
	var cover_start := Time.get_ticks_usec()
	GameState.loading_screen.show_for("Coastal Highway — B1 acceptance")
	await get_tree().process_frame
	await get_tree().process_frame
	var before := Time.get_ticks_usec()
	var packed := load(LEVEL) as PackedScene
	var loaded := Time.get_ticks_usec()
	var level := packed.instantiate() as RunLevel
	var instantiated := Time.get_ticks_usec()
	(level.get_node("DrivingRig") as DrivingRig).car_override = GameState.car_catalog.find_by_id(StringName(car_id))
	add_child(level)
	var ready_at := Time.get_ticks_usec()
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var drawn := Time.get_ticks_usec()
	GameState.loading_screen.hide()
	while level.run.clock.stage == RunClock.Stage.COUNTDOWN:
		await get_tree().process_frame
	await get_tree().process_frame
	var interactive := Time.get_ticks_usec()
	_store(label + "_load", {"car": car_id, "resource_ms": (loaded - before) / 1000.0,
		"instantiate_ms": (instantiated - loaded) / 1000.0, "ready_ms": (ready_at - instantiated) / 1000.0,
		"resource_through_ready_ms": (ready_at - before) / 1000.0,
		"trail_seconds": level.trail.build_seconds, "phases": level.trail.build_phases,
		"harness_cover_ms": (drawn - cover_start) / 1000.0,
		"first_draw_from_load_ms": (drawn - before) / 1000.0,
		"first_interactive_from_cover_ms": (interactive - cover_start) / 1000.0,
		"water_bodies": level.trail.water_world.bodies.size(),
		"wave_bindings": level.trail.water_world.wave_binding_count()})
	_failed = _failed or not level.trail.water_world.bodies.is_empty() or level.trail.water_world.wave_binding_count() != 0
	return level


func _place_view(level: RunLevel, camera: Camera3D, label: String) -> void:
	var at: float = VIEWS[label]
	var sampler := level.trail.sampler
	level.rig.place_car(sampler.transform_at(at, 0.7, level.trail.profile))
	level.rig.car.freeze = true
	var basis := Basis(sampler.right(at), Vector3.UP, sampler.forward(at))
	camera.position = sampler.position(at) + basis * Vector3(0, 3, -10)
	camera.look_at(sampler.position(at) + basis * Vector3(0, 1, 35))


func _capture_case(level: RunLevel, label: String, seconds: float) -> void:
	meter.begin(level)
	await _seconds(seconds)
	var result := meter.finish(OUT.path_join(label + "_frames.csv"))
	_store(label, result)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT.path_join(label + ".png"))


func _seconds(duration: float) -> void:
	var until := Time.get_ticks_usec() + roundi(duration * 1000000.0)
	while Time.get_ticks_usec() < until:
		await get_tree().process_frame


func _cleanup(level: RunLevel) -> void:
	meter.rig = null
	meter.sampler = null
	level.queue_free()
	for frame in 30:
		await get_tree().process_frame


func _store(label: String, data: Dictionary) -> void:
	var file := FileAccess.open(OUT.path_join(label + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	print("COASTAL_ACCEPTANCE ", label, " ", JSON.stringify(data))


## Fail closed to load-only diagnostics on malformed input. One-shot, save-free.
static func read_options(args: PackedStringArray, flag_path: String = "") -> Dictionary:
	var raw: Dictionary = {}
	if not flag_path.is_empty() and FileAccess.file_exists(flag_path):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(flag_path)) == OK and json.data is Dictionary:
			raw = json.data
		DirAccess.remove_absolute(flag_path)
	for arg: String in args:
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			raw[pair[0]] = pair[1]
	var parsed := {"mode": "loads", "car": "all", "tc": 0.20, "seconds": 10.0}
	if str(raw.get("mode", "")) in ["loads", "views", "drive", "soak"]:
		parsed.mode = str(raw.mode)
	if str(raw.get("car", "")) in CARS:
		parsed.car = str(raw.car)
	for key: String in ["tc", "seconds"]:
		if raw.has(key) and str(raw[key]).is_valid_float():
			var value := float(raw[key])
			if is_finite(value) and value >= (0.0 if key == "tc" else 2.0) and value <= (1.0 if key == "tc" else 60.0):
				parsed[key] = value
	return parsed
