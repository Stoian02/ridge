extends Node
## Opt-in balanced, normally paced water gate. Never uses --fixed-fps.
## Phone: JSON in files/wave_acceptance. Desktop: key=value after --.
## Default is a short early gate; full matrix options are recorded in metadata.

const FLAG := "user://wave_acceptance"
const OUT := "user://wave_acceptance_results"
var options: Dictionary = {"warm_seconds": 60, "settle_seconds": 10,
	"seconds": 30, "rounds": 3, "car": "offroad_4x4", "fixture": "replay", "tag": "early"}
var level: Node3D
var rig: DrivingRig
var probe: WaterTotalMeasurement
var results: Array[Dictionary] = []
var phase := 0
var driving := false
var _camera: Camera3D
var _current_mode := 0
var _live_cycle := -1


func _ready() -> void:
	process_physics_priority = -70
	if FileAccess.file_exists(FLAG):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLAG))
		if parsed is Dictionary:
			options.merge(parsed, true)
		DirAccess.remove_absolute(FLAG)
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	if DisplayServer.get_name() == "headless" or int(options.rounds) <= 0 or float(options.seconds) <= 0.0:
		push_error("Wave acceptance needs a real renderer and nonempty cases")
		get_tree().quit(2)
		return
	var output := OUT + "/" + str(options.tag).validate_filename()
	DirAccess.make_dir_recursive_absolute(output)
	probe = WaterTotalMeasurement.new()
	add_child(probe)
	var metadata := {"options": options, "engine": Engine.get_version_info().string,
		"os": OS.get_name(), "display": DisplayServer.get_name(), "window": str(DisplayServer.window_get_size()),
		"adapter": RenderingServer.get_video_adapter_name(), "physics_hz": Engine.physics_ticks_per_second,
		"max_fps": Engine.max_fps, "start_unix": Time.get_unix_time_from_system(),
		"feedback_scope": "conservative whole mixed effects/audio callbacks; no nested double counting"}
	_store(output + "/metadata.json", metadata)
	print("WAVE_GATE metadata ", JSON.stringify(metadata))
	var cars := PackedStringArray([str(options.car)])
	var modes := str(options.get("modes", "0,1,2")).split(",")
	if str(options.car) == "all":
		cars = PackedStringArray(["offroad_4x4", "rally", "rally_tuned"])
	for car_id: String in cars:
		level = load("res://levels/test_ground/test_ground.tscn").instantiate()
		(level.get_node("DrivingRig") as DrivingRig).car_override = GameState.car_catalog.find_by_id(StringName(car_id))
		add_child(level)
		rig = level.rig
		rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
		rig.telemetry.hide()
		rig.car.freeze = true
		_camera = Camera3D.new()
		level.add_child(_camera)
		_camera.position = Vector3(94.0, 11.0, 112.0)
		_camera.look_at(Vector3(105.0, 2.82, 126.0))
		_camera.make_current()
		await level.water_waves.request_mode(WaterWaveTestGround.Mode.FULL)
		_store(output + "/memory_" + car_id + ".json", _memory())
		driving = true
		print("WAVE_GATE warming ", car_id)
		await _seconds(float(options.warm_seconds))
		for round_index in int(options.rounds):
			# Latin rotation: every mode occupies early/middle/late positions.
			for order_index in modes.size():
				var mode := int(modes[(order_index + round_index) % modes.size()])
				_current_mode = mode
				driving = false
				await level.water_waves.request_mode(1 if mode == 3 else mode)
				level.water_waves.reset_history()
				# Mode 3 is a debug-only refined flat-shader control. No UI/save
				# mode or production enum is added, and topology is unchanged.
				if level.water_waves.emitter != null and mode != 0:
					level.water_waves.emitter.set_physics_process(mode != 3)
					level.water_waves.emitter.step_usec = 0
				if str(options.fixture) == "stress":
					_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
					_camera.size = 240.0
					_camera.position = Vector3(110.0, 145.0, 240.0)
					_camera.look_at(Vector3(110.0, 0.0, 126.0))
				rig.place_car(Transform3D(Basis(Vector3.UP, PI), Vector3(105.0, 2.5, 126.0)))
				rig.car.freeze = str(options.fixture) != "live"
				phase = 0
				_live_cycle = -1
				driving = true
				await _seconds(float(options.settle_seconds))
				# Identical phase and elapsed source history in every timed case.
				var label := "%s_r%d_o%d_m%d" % [car_id, round_index, order_index, mode]
				print("WAVE_GATE begin ", label, " uptime_usec=", Time.get_ticks_usec())
				_case_start_usec = Time.get_ticks_usec()
				probe.begin(rig, level.water_waves)
				while probe.frames.is_empty() or _duration() < float(options.seconds):
					await get_tree().process_frame
				var summary := probe.finish(output + "/" + label)
				summary["case"] = label
				summary["car"] = car_id
				summary["mode"] = mode
				summary["round"] = round_index
				summary["order"] = order_index
				summary["preparation_usec"] = level.water_waves.preparation_usec
				summary["covered_wait_usec"] = level.water_waves.covered_wait_usec
				summary["start_phase"] = phase - probe.ticks.size()
				results.append(summary)
				_store(output + "/summary.json", results)
				print("WAVE_GATE result ", JSON.stringify(summary))
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(output + "/" + label + ".png")
		driving = false
		probe.rig = null
		probe.waves = null
		level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("WAVE_GATE done ", output)
	get_tree().quit()


func _duration() -> float:
	# O(1), using timestamps retained by the recorder instead of rescanning CSV.
	return float(Time.get_ticks_usec() - _case_start_usec) / 1000000.0


var _case_start_usec := 0


func _physics_process(_delta: float) -> void:
	if not driving:
		return
	if str(options.fixture) == "live":
		_live()
		phase += 1
		return
	# Measurement-only kinematic replay, not a claim about live driving feel.
	# Same 12-second loop: entry, shallow/deep travel, stop and reverse.
	var time := float(phase % (Engine.physics_ticks_per_second * 12)) / Engine.physics_ticks_per_second
	var z := 60.0 + time * 8.0 if time < 7.0 else 116.0
	var velocity := 8.0 if time < 7.0 else 0.0
	if time >= 9.0:
		z = 116.0 - (time - 9.0) * 8.0
		velocity = -8.0
	var y := WaterCourse.pool_floor_height(0.0, z - WaterCourse.START_Z) + 0.65
	if str(options.fixture) in ["pool", "stress"]:
		z = 126.0
		y = 2.5
		velocity = 3.0
	rig.car.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(105.0, y, z))
	rig.car.linear_velocity = Vector3(0.0, 0.0, velocity)
	rig.car.angular_velocity = Vector3.ZERO
	for wheel: Wheel in rig.car.wheels:
		wheel.spin_speed = velocity / rig.car.stats.wheel_radius
	if str(options.fixture) == "stress" and _current_mode in [1, 2]:
		# Keep all sixteen slots overlapped at distinct ages. Only the debug
		# fixture writes private packet state; normal source limits are intact.
		var field: WaterWaveField = level.water_waves.runtime.field
		for index in field._slots.size():
			var slot := field._slots[index]
			slot.active = true
			slot.pending = false
			slot.body_id = &"test_calm"
			slot.origin = Vector2(float(index % 4) * 0.2, 96.0 + float(index / 4) * 0.2)
			slot.current = Vector2.ZERO
			slot.direction = Vector2.DOWN
			slot.amplitude = 0.08 if index < 4 else 0.03
			slot.life = 4.0 if index < 4 else 3.0
			slot.born = field.clock_seconds - 0.3 - float(index) * 0.05
			field.set_bow(&"test_calm", Vector2(0.0, 97.0), Vector2.DOWN, 2.0, 0.09)
	phase += 1


func _live() -> void:
	# Unfrozen checks are separate from matched replay: real forces/contacts and
	# entry effects run. Reset at explicit 12 s boundaries; retain those tails.
	var hz := Engine.physics_ticks_per_second
	var cycle := phase / (hz * 12)
	if cycle != _live_cycle:
		_live_cycle = cycle
		var kind := cycle % 6
		var x := 155.0 if kind == 4 else 105.0
		var z := 126.0 if kind >= 4 else 59.0
		var y := 2.5 if kind >= 4 else WaterCourse.pool_floor_height(0.0, 29.0) + 1.0
		rig.place_car(Transform3D(Basis(Vector3.UP, 0.0 if kind == 3 else PI), Vector3(x, y, z)))
		rig.car.input.virtual_throttle = 0.0
		var speed: float = [3.0, 8.0, 15.0, 8.0, 0.0, 0.0][kind]
		rig.car.linear_velocity = Vector3(0.0, 0.0, speed)
		for wheel: Wheel in rig.car.wheels:
			wheel.spin_speed = speed / rig.car.stats.wheel_radius * (-1.0 if kind == 3 else 1.0)
	if cycle % 6 < 3:
		rig.car.input.virtual_throttle = 1.0 if phase % (hz * 12) < hz * 5 else 0.0
	_camera.position = rig.car.global_position + Vector3(-9.0, 7.0, -12.0)
	_camera.look_at(rig.car.global_position)


func _memory() -> Dictionary:
	# Conservative ownership estimate, not process RSS or driver allocation.
	# Shared mesh/top arrays counted once; per-view caches counted separately.
	var tops: Array[WaterWaveMesh] = []
	var cpu := 0
	var gpu := 0
	for view: WaterWaveRuntime.View in level.water_waves.runtime.views:
		var top := view.sampler.topology
		cpu += top.vertices.size() * 12  # int64 serial + float32 height per view
		cpu += 4096  # packed snapshot, source/sampler bookkeeping allowance
		gpu += 4096 * 3  # padded uniforms, conservatively triple buffered
		if top in tops:
			continue
		tops.append(top)
		cpu += top.vertices.size() * (12 + 16 + 4 + 8) + top.indices.size() * 4
		# Backing mesh arrays as well as retained sampling arrays; count both.
		cpu += top.vertices.size() * 64 + top.indices.size() * 4
		gpu += top.vertices.size() * 64 + top.indices.size() * 4
		for cell: Vector2i in top._cells:
			cpu += 192 + (top._cells[cell] as PackedInt32Array).size() * 4
	# Extra reserve for objects, arrays, source pools and allocator overhead.
	cpu += 1024 * 1024
	return {"scope": "estimated wave-owned CPU/GPU buffers; shared tops once; 1 MiB reserve; not driver RSS",
		"cpu_bytes": cpu, "gpu_bytes": gpu, "total_mib": float(cpu + gpu) / (1024 * 1024),
		"unique_topologies": tops.size(), "views": level.water_waves.runtime.views.size()}


func _seconds(seconds: float) -> void:
	var count := roundi(seconds * Engine.physics_ticks_per_second)
	for tick in count:
		await get_tree().physics_frame


func _store(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
