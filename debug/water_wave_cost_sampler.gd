class_name WaterWaveCostSampler
extends WaterWaveSampler
## Opt-in diagnostic replacement only. Same cache, order and float32 results.
## Wall-clock timings include preemption and instrumentation; not acceptance.

const COLUMNS := "requests,vertices,cache_hits,same_frame_repeats,lookup_usec,ambient_usec,packet_usec,bow_usec,bound_usec,raw_usec,sampler_usec"
const WIDTH := 11
var split := true
var counters := PackedInt64Array()
var _render_serials := PackedInt64Array()


func configure(top: WaterWaveMesh, data: WaterWaveSnapshot) -> void:
	super.configure(top, data)
	counters.resize(WIDTH)
	counters.fill(0)
	_render_serials.resize(top.vertices.size())
	_render_serials.fill(-1)


func height_at(at: Vector2) -> float:
	var started := Time.get_ticks_usec()
	counters[0] += 1
	var triangle := topology.triangle_at(at)
	if triangle < 0:
		counters[4] += Time.get_ticks_usec() - started
		counters[10] += Time.get_ticks_usec() - started
		return -INF
	var weights := topology.barycentric(at, triangle)
	counters[4] += Time.get_ticks_usec() - started
	var result := topology.level
	for corner in 3:
		result += weights[corner] * vertex_offset(topology.indices[triangle * 3 + corner])
	counters[10] += Time.get_ticks_usec() - started
	return result


func vertex_offset(index: int) -> float:
	if _serials[index] != snapshot.serial:
		var at := topology.vertices[index]
		var started := Time.get_ticks_usec()
		var raw := _raw_split(Vector2(at.x, at.z)) if split else WaterWaveMath.raw(Vector2(at.x, at.z), snapshot)
		counters[9] += Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		_values[index] = WaterWaveMath.bounded(raw, topology.limits[index]).x
		counters[8] += Time.get_ticks_usec() - started
		_serials[index] = snapshot.serial
		evaluated_vertices += 1
		counters[1] += 1
		var frame := Engine.get_process_frames()
		if _render_serials[index] == frame:
			counters[3] += 1
		_render_serials[index] = frame
	else:
		counters[2] += 1
	return _values[index]


## Diagnostic copy of raw's summation only; production functions are unchanged.
## Tests require bit-identical results, not just a visually close approximation.
func _raw_split(point: Vector2) -> Vector3:
	var started := Time.get_ticks_usec()
	var result := Vector3.ZERO
	for wave: Vector4 in snapshot.ambient:
		var angle := point.dot(Vector2(wave.x, wave.y)) + wave.w
		result += Vector3(wave.z * sin(angle), wave.z * cos(angle) * wave.x,
			wave.z * cos(angle) * wave.y)
	counters[5] += Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for index in WaterWaveProfile.PACKET_SLOTS:
		result += WaterWaveMath.packet(point, snapshot.packets[index], snapshot.directions[index],
			snapshot.shape, snapshot.envelope)
	counters[6] += Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	result += WaterWaveMath.bow(point, snapshot.bow, snapshot.bow_direction)
	counters[7] += Time.get_ticks_usec() - started
	return result
