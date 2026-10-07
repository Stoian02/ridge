class_name CoastalFrameMeasurement
extends Node
## Wall-clock rendered intervals, including every tail; never derived from FPS.
## Empty-water script regions are upper bounds, not renderer/Jolt CPU attribution.

const HEADER := "end_usec,frame_usec,physics_ticks,water_upper_usec,draws,primitives,distance,case_elapsed_usec"
var rig: DrivingRig
var sampler: RoadSampler
var rows: Array[PackedFloat64Array] = []
var active := false
var _last := 0
var _start := 0
var _ticks := 0
var _water := 0


func _ready() -> void:
	process_priority = 200
	process_physics_priority = 200


func begin(level: RunLevel) -> void:
	rig = level.rig
	sampler = level.trail.sampler
	rig.effects.trace_enabled = true
	rig.audio.trace_enabled = true
	rig.water_status.trace_enabled = true
	rows.clear()
	_last = 0
	_start = Time.get_ticks_usec()
	_ticks = 0
	_water = 0
	active = true


func _physics_process(_delta: float) -> void:
	if active:
		_ticks += 1
		# Frozen static-view cars do not integrate; do not repeat a stale cost.
		_water += 0 if rig.car.freeze else rig.car.water.water_time_usec


func _process(_delta: float) -> void:
	if not active:
		return
	var now := Time.get_ticks_usec()
	if _last != 0:
		rows.append(PackedFloat64Array([now, now - _last, _ticks,
			_water + rig.effects.trace_water_usec + rig.audio.trace_water_usec + rig.water_status.trace_usec,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			sampler.closest_distance(rig.car.global_position), now - _start]))
	_last = now
	_ticks = 0
	_water = 0


func finish(path: String) -> Dictionary:
	active = false
	rig.effects.trace_enabled = false
	rig.audio.trace_enabled = false
	rig.water_status.trace_enabled = false
	WaterTotalMeasurement.write_csv(path, HEADER, rows)
	return summarize(rows)


static func summarize(values: Array[PackedFloat64Array]) -> Dictionary:
	var times := PackedFloat64Array()
	var water := PackedFloat64Array()
	var total := 0.0
	var draws := 0
	var primitives := 0
	var tails: Array[Dictionary] = []
	for row: PackedFloat64Array in values:
		times.append(row[1] / 1000.0)
		water.append(row[3] / 1000.0)
		total += row[1]
		draws = maxi(draws, int(row[4]))
		primitives = maxi(primitives, int(row[5]))
		if row[1] > 33300.0:
			tails.append({"end_usec": row[0], "ms": row[1] / 1000.0,
				"case_seconds": row[7] / 1000000.0, "distance": row[6],
				"classification": "start" if row[7] - row[1] <= 100000.0 else "warmed"})
	return {"frames": values.size(), "seconds": total / 1000000.0,
		"fps": values.size() * 1000000.0 / total if total > 0.0 else 0.0,
		"p95_ms": WaterMeasurement.percentile(times, 0.95),
		"p99_ms": WaterMeasurement.percentile(times, 0.99),
		"max_ms": WaterMeasurement.percentile(times, 1.0),
		"empty_water_upper_p95_ms": WaterMeasurement.percentile(water, 0.95),
		"empty_water_upper_p99_ms": WaterMeasurement.percentile(water, 0.99),
		"draw_peak": draws, "primitive_peak": primitives, "tails": tails}
