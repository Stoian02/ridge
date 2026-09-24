class_name WaterHitchTrace
extends Node
## Bounded diagnostic, not an acceptance gate. No file I/O/print during capture.
## All durations are wall time, which includes thread preemption/locking.

const TICK_COLUMNS := "tick,process_frame,end_usec,water_usec,body_usec,wheels_usec,forces_usec,query_usec,queries,triangles,immersion,flooding,stalled,sinking,intake_seconds,speed,car_y,contacts,physics_callbacks_usec"
const FRAME_COLUMNS := "frame,end_usec,interval_usec,first_tick,last_tick,ticks,water_usec,effects_usec,audio_usec,status_usec,script_callbacks_usec,loop_starts,water_entries,thumps,emitting,objects,nodes,resources,static_bytes,engine_process_sec,engine_physics_sec,recorder_usec"
const TW := 19
const FW := 22

class Before extends Node:
	var owner_trace: WaterHitchTrace
	func _physics_process(_delta: float) -> void:
		owner_trace._physics_start = Time.get_ticks_usec()
	func _process(_delta: float) -> void:
		owner_trace._process_start = Time.get_ticks_usec()

var rig: DrivingRig
var tick_count := 0
var frame_count := 0
var overflow := false
var _active := false
var _ticks := PackedFloat64Array()
var _frames := PackedFloat64Array()
var _last_queries := 0
var _last_triangles := 0
var _last_query_usec := 0
var _last_frame := 0
var _first_tick := -1
var _last_tick := -1
var _frame_ticks := 0
var _frame_water := 0
var _physics_start := 0
var _process_start := 0
var _recorder_usec := 0
var _before: Before


func _ready() -> void:
	process_priority = 1000
	process_physics_priority = 1000
	_before = Before.new()
	_before.owner_trace = self
	_before.process_priority = -1000
	_before.process_physics_priority = -1000
	add_child(_before)
	set_process(false)
	set_physics_process(false)
	_before.set_process(false)
	_before.set_physics_process(false)


func begin(driven: DrivingRig, capacity: int) -> void:
	assert(capacity > 0)
	rig = driven
	_ticks.resize(capacity * TW)
	_frames.resize((capacity + 32) * FW)
	tick_count = 0
	frame_count = 0
	overflow = false
	_last_frame = 0
	_first_tick = -1
	_last_tick = -1
	_frame_ticks = 0
	_frame_water = 0
	_recorder_usec = 0
	_last_queries = rig.car.water.world.query_count
	_last_triangles = rig.car.water.world.triangle_tests
	_last_query_usec = rig.car.water.world.query_usec
	rig.car.water.trace_enabled = true
	rig.effects.trace_enabled = true
	rig.audio.trace_enabled = true
	rig.water_status.trace_enabled = true
	_active = true
	set_process(true)
	set_physics_process(true)
	_before.set_process(true)
	_before.set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	var start := Time.get_ticks_usec()
	if (tick_count + 1) * TW > _ticks.size():
		overflow = true
		return
	var water := rig.car.water
	var world := water.world
	var offset := tick_count * TW
	var tick := Engine.get_physics_frames()
	_ticks[offset] = tick
	_ticks[offset + 1] = Engine.get_process_frames()
	_ticks[offset + 2] = start
	_ticks[offset + 3] = water.water_time_usec
	_ticks[offset + 4] = water.trace_body_usec
	_ticks[offset + 5] = water.trace_wheels_usec
	_ticks[offset + 6] = water.trace_forces_usec
	_ticks[offset + 7] = world.query_usec - _last_query_usec
	_ticks[offset + 8] = world.query_count - _last_queries
	_ticks[offset + 9] = world.triangle_tests - _last_triangles
	_ticks[offset + 10] = water.state.body_immersion
	_ticks[offset + 11] = water.state.flooding
	_ticks[offset + 12] = 1.0 if water.state.stalled else 0.0
	_ticks[offset + 13] = 1.0 if water.state.sinking else 0.0
	_ticks[offset + 14] = water.state.intake_seconds
	_ticks[offset + 15] = rig.car.linear_velocity.length()
	_ticks[offset + 16] = rig.car.position.y
	var contacts := 0
	for wheel in rig.car.wheels:
		contacts += 1 if wheel.in_contact else 0
	_ticks[offset + 17] = contacts
	_ticks[offset + 18] = start - _physics_start
	_last_queries = world.query_count
	_last_triangles = world.triangle_tests
	_last_query_usec = world.query_usec
	if _frame_ticks == 0:
		_first_tick = tick
	_last_tick = tick
	_frame_ticks += 1
	_frame_water += water.water_time_usec
	tick_count += 1
	_recorder_usec += Time.get_ticks_usec() - start


func _process(_delta: float) -> void:
	if not _active:
		return
	var start := Time.get_ticks_usec()
	if (frame_count + 1) * FW > _frames.size():
		overflow = true
		return
	var offset := frame_count * FW
	_frames[offset] = Engine.get_process_frames()
	_frames[offset + 1] = start
	_frames[offset + 2] = start - _last_frame if _last_frame != 0 else 0
	_frames[offset + 3] = _first_tick
	_frames[offset + 4] = _last_tick
	_frames[offset + 5] = _frame_ticks
	_frames[offset + 6] = _frame_water
	_frames[offset + 7] = rig.effects.trace_usec
	_frames[offset + 8] = rig.audio.trace_usec
	_frames[offset + 9] = rig.water_status.trace_usec
	_frames[offset + 10] = start - _process_start
	_frames[offset + 11] = rig.audio.trace_loop_starts
	_frames[offset + 12] = rig.effects.water_effects.entries
	_frames[offset + 13] = rig.audio.thumps_played
	var emitting := 1 if rig.effects.water_effects.emitter.emitting else 0
	for spray in rig.effects.sprays:
		emitting += 1 if spray.emitting else 0
	_frames[offset + 14] = emitting
	_frames[offset + 15] = Performance.get_monitor(Performance.OBJECT_COUNT)
	_frames[offset + 16] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_frames[offset + 17] = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	_frames[offset + 18] = Performance.get_monitor(Performance.MEMORY_STATIC)
	_frames[offset + 19] = Performance.get_monitor(Performance.TIME_PROCESS)
	_frames[offset + 20] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	_frames[offset + 21] = _recorder_usec
	frame_count += 1
	_last_frame = start
	_first_tick = -1
	_last_tick = -1
	_frame_ticks = 0
	_frame_water = 0
	_recorder_usec = Time.get_ticks_usec() - start


func stop() -> void:
	_active = false
	set_process(false)
	set_physics_process(false)
	_before.set_process(false)
	_before.set_physics_process(false)
	rig.car.water.trace_enabled = false
	rig.effects.trace_enabled = false
	rig.audio.trace_enabled = false
	rig.water_status.trace_enabled = false


func finish(path: String) -> Dictionary:
	stop()
	_write(path + "_hitch_ticks.csv", TICK_COLUMNS, _ticks, tick_count, TW)
	_write(path + "_hitch_frames.csv", FRAME_COLUMNS, _frames, frame_count, FW)
	var result := {"ticks": tick_count, "frames": frame_count, "overflow": overflow,
		"final_flooding": rig.car.water.state.flooding, "final_stalled": rig.car.water.state.stalled}
	rig = null
	return result


static func _write(path: String, columns: String, data: PackedFloat64Array, count: int, width: int) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line(columns)
	var row := PackedStringArray()
	row.resize(width)
	for index in count:
		for column in width:
			row[column] = str(data[index * width + column])
		file.store_csv_line(row)
	file.close()
