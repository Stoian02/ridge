extends Node
## Bounded opt-in cost attribution. No printing or file I/O during timed cases.
## Source/effects/audio/status are separate from the controller, not added twice.

const WIDTH := WaterWaveCostSampler.WIDTH + 9
const COLUMNS := "tick,frame,controller_usec,runtime_usec,emitter_usec,wave_query_usec,world_query_usec,bed_triangles," + WaterWaveCostSampler.COLUMNS + ",recorder_usec"
var waves: WaterWaveTestGround
var rig: DrivingRig
var samplers: Array[WaterWaveCostSampler] = []
var rows := PackedFloat64Array()
var count := 0
var overflow := false
var _previous := PackedInt64Array()
var _wave_usec := 0
var _query_usec := 0
var _triangles := 0
var _active := false


func _ready() -> void:
	process_physics_priority = 101
	set_physics_process(false)


func begin(coordinator: WaterWaveTestGround, split: bool) -> void:
	waves = coordinator
	rig = waves.rig
	samplers.clear()
	if waves.mode != WaterWaveTestGround.Mode.OFF:
		for index in waves.runtime.views.size():
			var view := waves.runtime.views[index]
			var sampler := WaterWaveCostSampler.new()
			sampler.split = split
			sampler.configure(view.sampler.topology, view.snapshot)
			view.sampler = sampler
			assert(waves.course.water_world.bind_wave(waves.course.water_world.bodies[index], sampler, view.origin))
			samplers.append(sampler)
	rows.resize(640 * WIDTH)
	count = 0
	overflow = false
	_previous.resize(WaterWaveCostSampler.WIDTH)
	_previous.fill(0)
	_wave_usec = rig.car.water.world.wave_query_usec
	_query_usec = rig.car.water.world.query_usec
	_triangles = rig.car.water.world.triangle_tests
	_active = true
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	var started := Time.get_ticks_usec()
	if (count + 1) * WIDTH > rows.size():
		overflow = true
		return
	var base := count * WIDTH
	var world := rig.car.water.world
	rows[base] = Engine.get_physics_frames()
	rows[base + 1] = Engine.get_process_frames()
	rows[base + 2] = rig.car.water.water_time_usec
	rows[base + 3] = waves.runtime.step_usec if not samplers.is_empty() else 0
	rows[base + 4] = waves.emitter.step_usec if not samplers.is_empty() else 0
	rows[base + 5] = world.wave_query_usec - _wave_usec
	rows[base + 6] = world.query_usec - _query_usec
	rows[base + 7] = world.triangle_tests - _triangles
	_wave_usec = world.wave_query_usec
	_query_usec = world.query_usec
	_triangles = world.triangle_tests
	for column in WaterWaveCostSampler.WIDTH:
		var total := 0
		for sampler in samplers:
			total += sampler.counters[column]
		rows[base + 8 + column] = total - _previous[column]
		_previous[column] = total
	rows[base + WIDTH - 1] = Time.get_ticks_usec() - started
	count += 1


func finish(path: String) -> void:
	_active = false
	set_physics_process(false)
	WaterHitchTrace._write(path, COLUMNS, rows, count, WIDTH)
	print("Wave cost trace ticks=", count, " overflow=", overflow, " split=", samplers[0].split if not samplers.is_empty() else false)


## Untimed-gameplay, same points/snapshot replay. Toggle only amplitude locally;
## never change the live snapshot or feed replay heights back into the car.
func replay() -> void:
	if samplers.is_empty():
		return
	var live := samplers[0].snapshot
	var snapshot := WaterWaveSnapshot.new()
	snapshot.ambient = live.ambient.duplicate()
	snapshot.packets = live.packets.duplicate()
	snapshot.directions = live.directions.duplicate()
	snapshot.shape = live.shape
	snapshot.envelope = live.envelope
	snapshot.bow = live.bow
	snapshot.bow_direction = live.bow_direction
	var local := rig.car.global_position - waves.runtime.views[0].origin
	var points := PackedVector2Array()
	for index in 32:
		points.append(Vector2(local.x, local.z) + Vector2(index % 8 - 4, index / 8 - 2) * 0.75)
	var original := snapshot.ambient.duplicate()
	var checksum := Vector3.ZERO
	for round_index in 6:
		for enabled: bool in ([false, true] if round_index % 2 == 0 else [true, false]):
			for index in 2:
				var wave := original[index]
				wave.z = waves.runtime.field.profile.ambient_amplitudes[index] if enabled else 0.0
				snapshot.ambient[index] = wave
			var started := Time.get_ticks_usec()
			for repetition in 64:
				for point in points:
					checksum += WaterWaveMath.raw(point, snapshot)
			print("Wave cost replay ", JSON.stringify({"round": round_index, "ambient": enabled,
				"evaluations": 2048, "raw_usec": Time.get_ticks_usec() - started, "checksum": str(checksum)}))
