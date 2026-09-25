class_name WaterTotalMeasurement
extends Node
## Acceptance recorder, not production. Non-overlapping script CPU upper bound:
## controller + wave runtime/emitter/coordinator + flat animation + full mixed
## effects/audio callbacks + water HUD. Nested queries are attribution ONLY.
## Engine renderer/physics/audio worker cost is represented by frame/GPU timing.

const TICK_HEADER := "process_frame,physics_tick,controller_usec,runtime_usec,emitter_usec,coordinator_usec,wave_query_usec,immersion,flooding,stalled,vertices,packets,x,y,z,velocity_x,velocity_y,velocity_z"
const FRAME_HEADER := "process_frame,frame_usec,physics_ticks,controller_usec,runtime_usec,emitter_usec,coordinator_usec,effects_upper_usec,audio_upper_usec,hud_usec,flat_usec,total_upper_usec,wave_query_usec,gpu_ms,render_cpu_ms,draws,primitives"
var rig: DrivingRig
var waves: WaterWaveTestGround
var active := false
var ticks: Array[PackedFloat64Array] = []
var frames: Array[PackedFloat64Array] = []
var _pending: Array[PackedFloat64Array] = []
var _last_usec := 0
var _previous_query := 0
var _previous_vertices := 0


func _ready() -> void:
	process_physics_priority = 200
	process_priority = 200
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func begin(driving: DrivingRig, coordinator: WaterWaveTestGround) -> void:
	rig = driving
	waves = coordinator
	rig.effects.trace_enabled = true
	rig.audio.trace_enabled = true
	rig.water_status.trace_enabled = true
	waves.trace_enabled = true
	waves.course.trace_enabled = true
	ticks.clear()
	frames.clear()
	_pending.clear()
	_last_usec = 0
	_previous_query = rig.car.water.world.wave_query_usec
	_previous_vertices = _vertices()
	active = true


func _vertices() -> int:
	var count := 0
	if waves.runtime != null:
		for view: WaterWaveRuntime.View in waves.runtime.views:
			count += view.sampler.evaluated_vertices
	return count


func _physics_process(_delta: float) -> void:
	if not active:
		return
	var enabled := waves.mode != WaterWaveTestGround.Mode.OFF
	var query := rig.car.water.world.wave_query_usec
	var vertices := _vertices()
	_pending.append(PackedFloat64Array([Engine.get_process_frames(), Engine.get_physics_frames(),
		rig.car.water.water_time_usec, waves.runtime.step_usec if enabled else 0,
		waves.emitter.step_usec if enabled else 0, waves.trace_usec if enabled else 0,
		query - _previous_query, rig.car.water.state.body_immersion,
		rig.car.water.state.flooding, int(rig.car.water.state.stalled),
		vertices - _previous_vertices, waves.runtime.field.active_count() if enabled else 0,
		rig.car.global_position.x, rig.car.global_position.y, rig.car.global_position.z,
		rig.car.linear_velocity.x, rig.car.linear_velocity.y, rig.car.linear_velocity.z]))
	_previous_query = query
	_previous_vertices = vertices


func _process(_delta: float) -> void:
	if not active:
		return
	var now := Time.get_ticks_usec()
	if _last_usec != 0:
		var row := PackedFloat64Array()
		row.resize(17)
		row[0] = Engine.get_process_frames()
		row[1] = now - _last_usec
		row[2] = _pending.size()
		for tick: PackedFloat64Array in _pending:
			# Explicit grouping survives engine/version differences in when the
			# process counter increments. No assumed two-ticks-per-frame factor.
			tick[0] = row[0]
			ticks.append(tick)
			for component in range(2, 6):
				row[component + 1] += tick[component]
			row[12] += tick[6]
		row[7] = rig.effects.trace_usec
		row[8] = rig.audio.trace_usec
		row[9] = rig.water_status.trace_usec
		row[10] = waves.course.trace_usec if waves.course.is_processing() else 0
		for component in range(3, 11):
			row[11] += row[component]
		var viewport := get_viewport().get_viewport_rid()
		row[13] = RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		row[14] = RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		row[15] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		row[16] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		frames.append(row)
	_last_usec = now
	_pending.clear()


func finish(path: String) -> Dictionary:
	active = false
	# Only complete process frames enter either file. Discard partial trailing
	# physics ticks rather than inventing a frame or losing their association.
	_pending.clear()
	write_csv(path + "_ticks.csv", TICK_HEADER, ticks)
	write_csv(path + "_frames.csv", FRAME_HEADER, frames)
	return summarize(frames)


static func write_csv(path: String, header: String, rows: Array[PackedFloat64Array]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line(header)
	for row: PackedFloat64Array in rows:
		var values := PackedStringArray()
		for value: float in row:
			values.append(str(value))
		file.store_csv_line(values)
	file.close()


static func summarize(rows: Array[PackedFloat64Array]) -> Dictionary:
	var result := {"frames": rows.size(), "cpu_scope": "total_script_upper_bound_including_mixed_dry_feedback"}
	var frame_sum := 0.0
	var tails := 0
	var gpu_valid := not rows.is_empty()
	for row: PackedFloat64Array in rows:
		frame_sum += row[1]
		tails += int(row[1] > 33300.0)
		gpu_valid = gpu_valid and row[13] > 0.0
	result["fps"] = rows.size() * 1000000.0 / frame_sum if frame_sum > 0.0 else 0.0
	result["over_33ms"] = tails
	result["gpu_valid"] = gpu_valid
	var names := {1: "frame", 3: "controller", 4: "runtime", 5: "emitter", 6: "coordinator",
		7: "effects_upper", 8: "audio_upper", 9: "hud", 10: "flat", 11: "total_upper", 12: "wave_query", 13: "gpu", 14: "render_cpu"}
	for column: int in names:
		var values := PackedFloat64Array()
		for row: PackedFloat64Array in rows:
			values.append(row[column] / (1.0 if column >= 13 else 1000.0))
		for fraction: float in [0.95, 0.99, 1.0]:
			result["%s_p%d_ms" % [names[column], roundi(fraction * 100)]] = WaterMeasurement.percentile(values, fraction)
	return result
