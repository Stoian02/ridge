extends RunLevel
## Dry, uncatalogued Coastal preview. Overrides are runtime-only, not save edits.
## Launch: godot --path . res://debug/coastal_playcheck.tscn -- car=rally tc=0.15

const FLAG := "user://coastal_playcheck"
var options: Dictionary = {}
var _captured := false
var _peak_draws := 0
var _peak_primitives := 0


func _process(_delta: float) -> void:
	if options.get("mode", "manual") != "smoke" or DisplayServer.get_name() == "headless":
		return
	_peak_draws = maxi(_peak_draws, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	_peak_primitives = maxi(_peak_primitives, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var capture_at := 2064.0 if options.start == "bridge" else 858.0
	if options.start in ["sand", "climb"]:
		capture_at = 2300.0 if options.start == "climb" else 1400.0
	if not _captured and options.has("capture") and trail.sampler.closest_distance(rig.car.position) >= capture_at:
		_captured = true
		_capture.call_deferred()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(options.capture)


func _enter_tree() -> void:
	options = read_options(OS.get_cmdline_user_args(), FLAG if OS.is_debug_build() else "")
	if options.has("car"):
		var chosen: CarDef = GameState.car_catalog.find_by_id(StringName(options.car))
		($DrivingRig as DrivingRig).car_override = chosen


func _ready() -> void:
	super._ready()
	if options.has("tc"):
		rig.car.drivetrain.traction_control_strength = options.tc
	if options.start != "course":
		var index := _preview_checkpoint()
		run.start_transform = tracker.gate_transforms[index]
		run.countdown_started.connect(_mark_approach_checkpoint)
		run.restart()
	$PreviewLabel/Label.text = "COASTAL B1 — DRY ROAD PREVIEW\nPause: change car / traction control. Reset: checkpoint.\nFirm sand and structures; scenery and water still to come."
	if options.mode == "smoke":
		_smoke.call_deferred()
	elif options.mode == "views":
		_views.call_deferred()


func _preview_checkpoint() -> int:
	if options.start in ["sand", "climb"]:
		return CoastalSurfaceProbe.checkpoint_index(self, options.start == "climb")
	return CoastalBridgeProbe.checkpoint_index(self) if options.start == "bridge" else 1


func _mark_approach_checkpoint() -> void:
	var index := _preview_checkpoint()
	for i in range(1, index + 1):
		tracker.enter_gate(i)


func _smoke() -> void:
	var result: Dictionary
	var samples: Array[Dictionary]
	if options.start in ["sand", "climb"]:
		var probe := CoastalSurfaceProbe.new()
		result = await probe.attempt(self, rig.car.drivetrain.traction_control_strength, options.start == "climb")
		samples = probe.samples
	elif options.start == "bridge":
		var probe := CoastalBridgeProbe.new()
		result = await probe.attempt(self, rig.car.drivetrain.traction_control_strength)
		samples = probe.samples
	else:
		var probe := CoastalGapProbe.new()
		result = await probe.attempt(self, rig.car.drivetrain.traction_control_strength,
			options.get("held", false), 0.0, 1.0, false, options.get("balance", false), options.start == "course")
		samples = probe.samples
	print("COASTAL_PREVIEW ", JSON.stringify({"renderer": DisplayServer.get_name(),
		"build_seconds": trail.build_seconds, "peak_draws": _peak_draws,
		"peak_primitives": _peak_primitives, "water_bodies": trail.water_world.bodies.size()}))
	if options.has("samples"):
		var file := FileAccess.open(options.samples, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(samples))
	# Exit after the awaiting probe has unwound, not with a live coroutine stack.
	get_tree().quit.call_deferred(0 if result.reached and result.upright and result.resets == 0 else 1)


## Normal-speed fixed views are rendering diagnostics, never driving evidence.
## Refuse the headless backend rather than report zero draws as a passing budget.
func _views() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Coastal rendered views require a real renderer")
		get_tree().quit(2)
		return
	while run.clock.stage == RunClock.Stage.COUNTDOWN:
		await get_tree().process_frame
	for layer: CanvasLayer in find_children("*", "CanvasLayer", true, false):
		layer.hide()
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var views := [
		["tunnel_entry", 602.0, Vector3(0, 3, -8), Vector3(0, 2, 18)],
		["tunnel_inside", 660.0, Vector3(0, 2.5, -7), Vector3(0, 2, 25)],
		["tunnel_exit", 710.0, Vector3(0, 3, -8), Vector3(0, 1, 30)],
		["jump", 850.0, Vector3(0, 7, -12), Vector3(0, 0, 35)],
		["bridge_deck", 2060.0, Vector3(0, 3, -14), Vector3(0, 0.5, 14)],
		["bridge_arch", 2064.0, Vector3(20, -1.5, -8), Vector3(0, -2, 0)],
		["sand_entry", 1350.0, Vector3(0, 4, -14), Vector3(0, 0, 18)],
		["sand_exit", 1950.0, Vector3(0, 4, -14), Vector3(0, 0, 18)],
		["sand_climb", 2380.0, Vector3(0, 4, -14), Vector3(0, 0, 18)],
	]
	for view: Array in views:
		var at: float = view[1]
		var origin := trail.sampler.position(at)
		var basis := Basis(trail.sampler.right(at), Vector3.UP, trail.sampler.forward(at))
		rig.place_car(trail.sampler.transform_at(at, 0.7, trail.profile))
		rig.car.freeze = true
		camera.position = origin + basis * (view[2] as Vector3)
		camera.look_at(origin + basis * (view[3] as Vector3))
		for frame in 90:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if options.has("capture"):
			get_viewport().get_texture().get_image().save_png("%s-%s.png" % [options.capture, view[0]])
		print("COASTAL_VIEW ", JSON.stringify({"view": view[0], "distance": at,
			"draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			"build_seconds": trail.build_seconds, "phases": trail.build_phases, "water_bodies": trail.water_world.bodies.size()}))
	get_tree().quit.call_deferred()


## The phone flag may contain JSON options or be empty for manual driving.
## It is consumed once; malformed/unknown inputs safely retain preview defaults.
static func read_options(args: PackedStringArray, flag_path: String = "") -> Dictionary:
	var raw: Dictionary = {}
	if not flag_path.is_empty() and FileAccess.file_exists(flag_path):
		var content := FileAccess.get_file_as_string(flag_path)
		DirAccess.remove_absolute(flag_path)
		if not content.strip_edges().is_empty():
			var json := JSON.new()
			if json.parse(content) == OK and json.data is Dictionary:
				raw = json.data
	for arg: String in args:
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			raw[pair[0]] = pair[1]
	var parsed := {"start": "jump", "mode": "manual"}
	if str(raw.get("start", "")) in ["course", "bridge", "sand", "climb"]:
		parsed.start = str(raw.start)
	if str(raw.get("mode", "")) in ["smoke", "views"]:
		parsed.mode = str(raw.mode)
	if str(raw.get("car", "")) in ["rally", "rally_tuned", "offroad_4x4"]:
		parsed.car = str(raw.car)
	if raw.has("tc") and str(raw.tc).is_valid_float():
		var strength := float(raw.tc)
		if is_finite(strength) and strength >= 0.0 and strength <= 1.0:
			parsed.tc = strength
	parsed.held = str(raw.get("held", "false")) in ["true", "1"]
	parsed.balance = not parsed.held and str(raw.get("balance", "false")) in ["true", "1"]
	for key: String in ["capture", "samples"]:
		if raw.has(key) and not str(raw[key]).is_empty():
			parsed[key] = str(raw[key])
	return parsed
