class_name WaterMeasurement
extends Node
## Samples the completed Car tick at a later physics priority. No force changes.
## Controller cost excludes Jolt, dry car work, effects, audio and this recorder.

var car: Car
var active := false
var rows: Array[PackedFloat64Array] = []
var frame_usec := PackedFloat64Array()
var frames: Array[PackedFloat64Array] = []
var draw_peak := 0
var primitive_peak := 0
var _last_frame_usec := 0
var _first_usec := 0
var _last_tick := -1
var _previous_queries := 0
var _previous_triangles := 0
var _previous_query_usec := 0
var _frame_water_usec := 0.0
var _frame_ticks := 0


func _ready() -> void:
	process_physics_priority = 100
	process_priority = 100


func begin(driven: Car) -> void:
	car = driven
	rows.clear()
	frame_usec.clear()
	frames.clear()
	draw_peak = 0
	primitive_peak = 0
	_last_tick = -1
	_last_frame_usec = 0
	_first_usec = Time.get_ticks_usec()
	_frame_water_usec = 0.0
	_frame_ticks = 0
	var world := car.water.world
	_previous_queries = world.query_count if world != null else 0
	_previous_triangles = world.triangle_tests if world != null else 0
	_previous_query_usec = world.query_usec if world != null else 0
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
	var world := water.world
	var queries := world.query_count if world != null else 0
	var triangles := world.triangle_tests if world != null else 0
	var query_time := world.query_usec if world != null else 0
	rows.append(PackedFloat64Array([tick, water.water_time_usec,
		water.state.body_immersion, water.state.flooding,
		1.0 if water.state.stalled else 0.0, water.relative_speed,
		queries - _previous_queries, triangles - _previous_triangles,
		query_time - _previous_query_usec]))
	_previous_queries = queries
	_previous_triangles = triangles
	_previous_query_usec = query_time
	_frame_water_usec += water.water_time_usec
	_frame_ticks += 1


func _process(_delta: float) -> void:
	if not active:
		return
	var now := Time.get_ticks_usec()
	if _last_frame_usec != 0:
		frame_usec.append(now - _last_frame_usec)
		frames.append(PackedFloat64Array([Engine.get_process_frames(), now - _last_frame_usec,
			_frame_ticks, _frame_water_usec]))
	_last_frame_usec = now
	_frame_water_usec = 0.0
	_frame_ticks = 0
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
	file.store_line("physics_tick,water_usec,immersion,flooding,stalled,relative_speed,queries,triangle_tests,query_usec")
	var queries := 0.0
	var triangles := 0.0
	var query_time := 0.0
	for row in rows:
		costs.append(row[1])
		queries += row[6]
		triangles += row[7]
		query_time += row[8]
		file.store_csv_line(PackedStringArray([str(int(row[0])), str(row[1]),
			str(row[2]), str(row[3]), str(row[4]), str(row[5]), str(row[6]), str(row[7]), str(row[8])]))
	file.close()
	var frame_costs := PackedFloat64Array()
	file = FileAccess.open(path.get_basename() + "_frames.csv", FileAccess.WRITE)
	file.store_line("process_frame,frame_usec,physics_ticks,water_usec")
	for row in frames:
		frame_costs.append(row[3])
		file.store_csv_line(PackedStringArray([str(int(row[0])), str(row[1]), str(int(row[2])), str(row[3])]))
	file.close()
	var frame_total := 0.0
	for duration in frame_usec:
		frame_total += duration
	return {"samples": rows.size(), "elapsed_seconds": elapsed,
		"water_p95_ms": percentile(costs, 0.95) / 1000.0,
		"water_max_ms": percentile(costs, 1.0) / 1000.0,
		"queries": queries, "triangle_tests": triangles,
		"triangles_per_query": triangles / queries if queries > 0.0 else 0.0,
		"query_total_ms": query_time / 1000.0,
		"water_frame_p95_ms": percentile(frame_costs, 0.95) / 1000.0,
		"water_frame_max_ms": percentile(frame_costs, 1.0) / 1000.0,
		"frame_samples": frame_usec.size(),
		"fps": frame_usec.size() * 1000000.0 / frame_total if frame_total > 0.0 else 0.0,
		"frame_p95_ms": percentile(frame_usec, 0.95) / 1000.0,
		"frame_max_ms": percentile(frame_usec, 1.0) / 1000.0,
		"draw_peak": draw_peak, "primitive_peak": primitive_peak}
