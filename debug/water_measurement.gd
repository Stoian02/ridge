class_name WaterMeasurement
extends Node
## Samples the completed Car tick at a later physics priority. No force changes.
## Controller cost excludes Jolt, dry car work, effects, audio and this recorder.

var car: Car
var active := false
var rows: Array[PackedFloat64Array] = []
var frame_usec := PackedFloat64Array()
var draw_peak := 0
var primitive_peak := 0
var _last_frame_usec := 0
var _first_usec := 0
var _last_tick := -1


func _ready() -> void:
	process_physics_priority = 100
	process_priority = 100


func begin(driven: Car) -> void:
	car = driven
	rows.clear()
	frame_usec.clear()
	draw_peak = 0
	primitive_peak = 0
	_last_tick = -1
	_last_frame_usec = 0
	_first_usec = Time.get_ticks_usec()
	active = true


func _physics_process(_delta: float) -> void:
	if not active or car == null:
		return
	var tick := Engine.get_physics_frames()
	if tick == _last_tick:
		push_error("Water measurement sampled one physics tick twice")
		return
	_last_tick = tick
	var water := car.water
	rows.append(PackedFloat64Array([tick, water.water_time_usec,
		water.state.body_immersion, water.state.flooding,
		1.0 if water.state.stalled else 0.0, water.relative_speed]))


func _process(_delta: float) -> void:
	if not active:
		return
	var now := Time.get_ticks_usec()
	if _last_frame_usec != 0:
		frame_usec.append(now - _last_frame_usec)
	_last_frame_usec = now
	draw_peak = maxi(draw_peak, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	primitive_peak = maxi(primitive_peak, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))


static func percentile(values: PackedFloat64Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(ordered.size() * fraction) - 1, 0, ordered.size() - 1)]


func finish(path: String) -> Dictionary:
	active = false
	var elapsed := (Time.get_ticks_usec() - _first_usec) / 1000000.0
	var costs := PackedFloat64Array()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line("physics_tick,water_usec,immersion,flooding,stalled,relative_speed")
	for row in rows:
		costs.append(row[1])
		file.store_csv_line(PackedStringArray([str(int(row[0])), str(row[1]),
			str(row[2]), str(row[3]), str(row[4]), str(row[5])]))
	file.close()
	var frame_total := 0.0
	for duration in frame_usec:
		frame_total += duration
	return {"samples": rows.size(), "elapsed_seconds": elapsed,
		"water_p95_ms": percentile(costs, 0.95) / 1000.0,
		"water_max_ms": percentile(costs, 1.0) / 1000.0,
		"frame_samples": frame_usec.size(),
		"fps": frame_usec.size() * 1000000.0 / frame_total if frame_total > 0.0 else 0.0,
		"frame_p95_ms": percentile(frame_usec, 0.95) / 1000.0,
		"frame_max_ms": percentile(frame_usec, 1.0) / 1000.0,
		"draw_peak": draw_peak, "primitive_peak": primitive_peak}
