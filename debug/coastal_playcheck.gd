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
	if not _captured and options.has("capture") and trail.sampler.closest_distance(rig.car.position) >= 858.0:
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
	if options.start == "jump":
		run.start_transform = tracker.gate_transforms[1]
		run.countdown_started.connect(_mark_approach_checkpoint)
		run.restart()
	$PreviewLabel/Label.text = "COASTAL B1 — DRY JUMP PREVIEW\nPause: change car / traction control. Reset: full run-up.\nNo scenery, structures, water or final sand yet."
	if options.mode == "smoke":
		_smoke.call_deferred()


func _mark_approach_checkpoint() -> void:
	tracker.enter_gate(1)


func _smoke() -> void:
	var probe := CoastalGapProbe.new()
	var result := await probe.attempt(self, rig.car.drivetrain.traction_control_strength,
		options.get("held", false))
	print("COASTAL_PREVIEW ", JSON.stringify({"renderer": DisplayServer.get_name(),
		"build_seconds": trail.build_seconds, "peak_draws": _peak_draws,
		"peak_primitives": _peak_primitives, "water_bodies": trail.water_world.bodies.size()}))
	if options.has("samples"):
		var file := FileAccess.open(options.samples, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(probe.samples))
	# Exit after the awaiting probe has unwound, not with a live coroutine stack.
	get_tree().quit.call_deferred(0 if result.reached and result.upright and result.resets == 0 else 1)


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
	if str(raw.get("start", "")) == "course":
		parsed.start = "course"
	if str(raw.get("mode", "")) == "smoke":
		parsed.mode = "smoke"
	if str(raw.get("car", "")) in ["rally", "rally_tuned", "offroad_4x4"]:
		parsed.car = str(raw.car)
	if raw.has("tc") and str(raw.tc).is_valid_float():
		var strength := float(raw.tc)
		if is_finite(strength) and strength >= 0.0 and strength <= 1.0:
			parsed.tc = strength
	parsed.held = str(raw.get("held", "false")) in ["true", "1"]
	for key: String in ["capture", "samples"]:
		if raw.has(key) and not str(raw[key]).is_empty():
			parsed[key] = str(raw[key])
	return parsed
