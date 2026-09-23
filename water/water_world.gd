class_name WaterWorld
extends RefCounted
## Level-owned registry; no autoload, water collider or scene-tree scan per tick.

const CELL_SIZE := 16.0

var bodies: Array[WaterBody] = []
var generation: int = 0
var query_count: int = 0
var triangle_tests: int = 0
var query_usec: int = 0
## Registration/index time since clear; terrain/mesh extraction is measured by
## TrailLevel's complete "water" build phase instead.
var setup_usec: int = 0

var _bins: Dictionary = {}
var _candidate := WaterSample.new()
var _cached_cell := Vector2i(2147483647, 2147483647)
var _cached_bodies: Array = []


func add_body(def: WaterBodyDef, top_faces: PackedVector3Array, bed_faces: PackedVector3Array,
		transform: Transform3D = Transform3D.IDENTITY,
		face_currents: PackedVector3Array = PackedVector3Array()) -> WaterBody:
	var started := Time.get_ticks_usec()
	var body := WaterBody.new()
	if not body.configure(def, top_faces, bed_faces, transform, face_currents):
		setup_usec += Time.get_ticks_usec() - started
		return null
	# Re-authoring an ID replaces it; it never layers duplicate forces on a seam.
	for existing: WaterBody in bodies.duplicate():
		if existing.id == body.id:
			remove_body(existing)
	bodies.append(body)
	_index_body(body)
	_invalidate()
	setup_usec += Time.get_ticks_usec() - started
	return body


func remove_body(body: WaterBody) -> void:
	if not bodies.has(body):
		return
	bodies.erase(body)
	_reindex()


func clear() -> void:
	bodies.clear()
	_bins.clear()
	setup_usec = 0
	reset_metrics()
	_invalidate()


func reset_metrics() -> void:
	query_count = 0
	triangle_tests = 0
	query_usec = 0


func sample(point: Vector3, result: WaterSample, radius: float = 0.0) -> void:
	var started := Time.get_ticks_usec()
	query_count += 1
	result.clear()
	if not point.is_finite() or not is_finite(radius):
		query_usec += Time.get_ticks_usec() - started
		return
	var cell := Vector2i(floori(point.x / CELL_SIZE), floori(point.z / CELL_SIZE))
	if cell != _cached_cell:
		_cached_cell = cell
		_cached_bodies = _bins.get(cell, [])
	for body: WaterBody in _cached_bodies:
		body.sample(point, _candidate, radius)
		triangle_tests += body.triangle_tests
		if not _candidate.valid:
			continue
		if not result.valid or _candidate.surface_y > result.surface_y \
				or (_candidate.surface_y == result.surface_y and String(_candidate.body_id) < String(result.body_id)):
			result.copy_from(_candidate)
	query_usec += Time.get_ticks_usec() - started


func _index_body(body: WaterBody) -> void:
	var first := Vector2i(floori(body.bounds.position.x / CELL_SIZE), floori(body.bounds.position.z / CELL_SIZE))
	var last := Vector2i(floori(body.bounds.end.x / CELL_SIZE), floori(body.bounds.end.z / CELL_SIZE))
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var key := Vector2i(x, z)
			var entries: Array = _bins.get(key, [])
			entries.append(body)
			_bins[key] = entries


func _reindex() -> void:
	_bins.clear()
	for body: WaterBody in bodies:
		_index_body(body)
	_invalidate()


func _invalidate() -> void:
	generation += 1
	_cached_cell = Vector2i(2147483647, 2147483647)
	_cached_bodies = []
