class_name WaterBody
extends RefCounted
## Immutable world-space top/bed triangles. Fine bins bound dense rut queries;
## the world's 16 m bins choose bodies before any triangle work happens.

const CELL_SIZE := 2.0
const TRIANGLE_EPSILON := 0.000001
const BED_SUBDIVISIONS := 4
const BED_FINE_SIZE := CELL_SIZE / BED_SUBDIVISIONS
const BED_REFINE_THRESHOLD := 32

var id: StringName
var bounds: AABB
var triangle_tests: int = 0
var top_triangle_count: int = 0
var bed_triangle_count: int = 0

var _top := PackedVector3Array()
var _bed := PackedVector3Array()
var _currents := PackedVector3Array()
var _top_bins: Dictionary = {}
var _bed_bins: Dictionary = {}
var _bed_fine_bins: Dictionary = {}
var _refined_bed_cells: Dictionary = {}
var _edge_bins: Dictionary = {}
var _edges := PackedVector3Array()
var _color: Color
var _blend: float
var _epsilon: float
var _bottom: float = INF


## Reject shear, reflection, singular/non-uniform scales and non-finite inputs.
## Uniform scale is supported; rotations need not be restricted to yaw.
static func supports_transform(transform: Transform3D) -> bool:
	if not transform.origin.is_finite() or not transform.basis.x.is_finite() \
			or not transform.basis.y.is_finite() or not transform.basis.z.is_finite():
		return false
	var lengths := Vector3(transform.basis.x.length(), transform.basis.y.length(), transform.basis.z.length())
	if lengths.x <= 0.000001 or not is_equal_approx(lengths.x, lengths.y) or not is_equal_approx(lengths.x, lengths.z):
		return false
	var basis := transform.basis.orthonormalized()
	return transform.basis.determinant() > 0.0 \
			and absf(transform.basis.x.dot(transform.basis.y)) < lengths.x * lengths.x * 0.00001 \
			and absf(transform.basis.x.dot(transform.basis.z)) < lengths.x * lengths.x * 0.00001 \
			and absf(transform.basis.y.dot(transform.basis.z)) < lengths.x * lengths.x * 0.00001 \
			and basis.determinant() > 0.0


func configure(def: WaterBodyDef, top_faces: PackedVector3Array, bed_faces: PackedVector3Array,
		transform: Transform3D, face_currents: PackedVector3Array) -> bool:
	if def == null or not supports_transform(transform) or top_faces.is_empty() or bed_faces.is_empty() \
			or top_faces.size() % 3 != 0 or bed_faces.size() % 3 != 0 \
			or (not face_currents.is_empty() and face_currents.size() != top_faces.size() / 3):
		return false
	if not is_finite(def.shore_probe_blend) or not is_finite(def.depth_epsilon):
		return false
	id = def.id
	_color = def.color
	_blend = maxf(0.0, def.shore_probe_blend) * transform.basis.x.length()
	_epsilon = maxf(0.0, def.depth_epsilon) * transform.basis.x.length()
	_top = transform * top_faces
	_bed = transform * bed_faces
	bounds = AABB(_top[0], Vector3.ZERO)
	for point: Vector3 in _top:
		if not point.is_finite():
			return false
		bounds = bounds.expand(point)
	for point: Vector3 in _bed:
		if not point.is_finite():
			return false
		_bottom = minf(_bottom, point.y)
	top_triangle_count = _top.size() / 3
	bed_triangle_count = _bed.size() / 3
	var rotation := transform.basis.orthonormalized()
	for triangle in top_triangle_count:
		var velocity: Vector3 = def.current_velocity if face_currents.is_empty() else face_currents[triangle]
		if not velocity.is_finite():
			return false
		_currents.append(rotation * velocity)
	_index_faces(_top, _top_bins)
	_index_faces(_bed, _bed_bins)
	_refine_bed_index()
	_index_boundary()
	return true


func sample(point: Vector3, result: WaterSample, radius: float = 0.0) -> void:
	result.clear()
	triangle_tests = 0
	if point.y + maxf(radius, 0.0) < _bottom - _epsilon:
		return
	var key := _cell(point.x, point.z)
	if not _top_bins.has(key) or not _bed_bins.has(key):
		return
	var surface := -INF
	var chosen := -1
	var tops: PackedInt32Array = _top_bins[key]
	for triangle: int in tops:
		triangle_tests += 1
		var height := triangle_height(_top, triangle * 3, point.x, point.z)
		if height > surface:
			surface = height
			chosen = triangle
	if chosen < 0:
		return
	var bed := -INF
	var bottoms: PackedInt32Array = _bed_bins[key]
	if _refined_bed_cells.has(key):
		var fine_key := Vector2i(floori(point.x / BED_FINE_SIZE), floori(point.z / BED_FINE_SIZE))
		bottoms = _bed_fine_bins.get(fine_key, PackedInt32Array())
	for triangle: int in bottoms:
		triangle_tests += 1
		bed = maxf(bed, triangle_height(_bed, triangle * 3, point.x, point.z))
	if not is_finite(bed) or surface - bed <= _epsilon or point.y + maxf(radius, 0.0) < bed - _epsilon:
		return
	result.valid = true
	result.surface_y = surface
	result.bed_y = bed
	result.current = _currents[chosen]
	result.body_id = id
	result.color = _color
	result.edge_weight = _edge_weight(point, key)


## Exact triangle interpolation, not bilinear terrain/nominal road heights.
static func triangle_height(faces: PackedVector3Array, start: int, x: float, z: float) -> float:
	var a := faces[start]
	var b := faces[start + 1]
	var c := faces[start + 2]
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ac := Vector2(c.x - a.x, c.z - a.z)
	var denominator := ab.cross(ac)
	if absf(denominator) < 0.0000000001:
		return -INF
	var relative := Vector2(x - a.x, z - a.z)
	var u := relative.cross(ac) / denominator
	var v := ab.cross(relative) / denominator
	if u < -TRIANGLE_EPSILON or v < -TRIANGLE_EPSILON or u + v > 1.0 + TRIANGLE_EPSILON:
		return -INF
	return a.y + u * (b.y - a.y) + v * (c.y - a.y)


static func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL_SIZE), floori(z / CELL_SIZE))


static func _insert_bounds(index: Dictionary, low: Vector2, high: Vector2, value: int) -> void:
	var first := _cell(low.x, low.y)
	var last := _cell(high.x, high.y)
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var key := Vector2i(x, z)
			var values: PackedInt32Array = index.get(key, PackedInt32Array())
			values.append(value)
			index[key] = values


static func _index_faces(faces: PackedVector3Array, index: Dictionary) -> void:
	for triangle in faces.size() / 3:
		var a := faces[triangle * 3]
		var b := faces[triangle * 3 + 1]
		var c := faces[triangle * 3 + 2]
		_insert_bounds(index, Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z))),
				Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z))), triangle)


## Dense road meshes put hundreds of tiny bed triangles in a 2 m cell. Refine
## only crowded cells beneath a possible water top, retaining face order and
## the original interpolation. Sparse terrain/pool cells pay no extra lookup.
## Bounds include the barycentric tolerance; this must never trim a valid hit.
func _refine_bed_index() -> void:
	for key: Vector2i in _top_bins:
		var candidates: PackedInt32Array = _bed_bins.get(key, PackedInt32Array())
		if candidates.size() <= BED_REFINE_THRESHOLD:
			continue
		_refined_bed_cells[key] = true
		var cell_first := key * BED_SUBDIVISIONS
		var cell_last := cell_first + Vector2i.ONE * (BED_SUBDIVISIONS - 1)
		for triangle: int in candidates:
			var a := _bed[triangle * 3]
			var b := _bed[triangle * 3 + 1]
			var c := _bed[triangle * 3 + 2]
			# u/v can reach 1+2*epsilon when the other is -epsilon. Include
			# that whole accepted region, plus float-vector rounding.
			var margin_x := (absf(b.x - a.x) + absf(c.x - a.x)) * 2.0 * TRIANGLE_EPSILON + 0.0001
			var margin_z := (absf(b.z - a.z) + absf(c.z - a.z)) * 2.0 * TRIANGLE_EPSILON + 0.0001
			var first := Vector2i(floori((minf(a.x, minf(b.x, c.x)) - margin_x) / BED_FINE_SIZE),
				floori((minf(a.z, minf(b.z, c.z)) - margin_z) / BED_FINE_SIZE))
			var last := Vector2i(floori((maxf(a.x, maxf(b.x, c.x)) + margin_x) / BED_FINE_SIZE),
				floori((maxf(a.z, maxf(b.z, c.z)) + margin_z) / BED_FINE_SIZE))
			for z in range(maxi(first.y, cell_first.y), mini(last.y, cell_last.y) + 1):
				for x in range(maxi(first.x, cell_first.x), mini(last.x, cell_last.x) + 1):
					var fine_key := Vector2i(x, z)
					var entries: PackedInt32Array = _bed_fine_bins.get(fine_key, PackedInt32Array())
					entries.append(triangle)
					_bed_fine_bins[fine_key] = entries


## Count shared edges before making a shoreline: the diagonal of each quad and
## adjacent row seams must never fade the car's force in the middle of water.
func _index_boundary() -> void:
	var points: Dictionary = {}
	var unique := PackedVector3Array()
	var point_bins: Dictionary = {}
	var counts: Dictionary = {}
	for triangle in _top.size() / 3:
		var ids := PackedInt32Array()
		for corner in 3:
			var point := _top[triangle * 3 + corner]
			if not points.has(point):
				points[point] = unique.size()
				_insert_bounds(point_bins, Vector2(point.x, point.z), Vector2(point.x, point.z), unique.size())
				unique.append(point)
			ids.append(points[point])
		for corner in 3:
			var edge := Vector2i(mini(ids[corner], ids[(corner + 1) % 3]), maxi(ids[corner], ids[(corner + 1) % 3]))
			counts[edge] = int(counts.get(edge, 0)) + 1
	# Clipped/merged meshes can have a long edge meeting several shorter ones.
	# Split only unmatched edges at local collinear vertices, then recount. A
	# T-junction is not a shoreline. Vertex bins avoid an all-vertices scan.
	var split_counts: Dictionary = {}
	for edge: Vector2i in counts:
		if int(counts[edge]) != 1:
			continue
		var a := unique[edge.x]
		var b := unique[edge.y]
		var span := b - a
		var length_squared := span.length_squared()
		if length_squared <= 0.0000000001:
			continue
		var cuts: Array[Vector2] = [Vector2(0.0, edge.x), Vector2(1.0, edge.y)]
		var first := _cell(minf(a.x, b.x) - 0.00001, minf(a.z, b.z) - 0.00001)
		var last := _cell(maxf(a.x, b.x) + 0.00001, maxf(a.z, b.z) + 0.00001)
		for z in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var candidates: PackedInt32Array = point_bins.get(Vector2i(x, z), PackedInt32Array())
				for candidate: int in candidates:
					var fraction := (unique[candidate] - a).dot(span) / length_squared
					if fraction <= 0.000001 or fraction >= 0.999999:
						continue
					if unique[candidate].distance_squared_to(a + span * fraction) < 0.000000001:
						cuts.append(Vector2(fraction, candidate))
		cuts.sort_custom(func(left: Vector2, right: Vector2) -> bool: return left.x < right.x)
		for cut in cuts.size() - 1:
			var left := int(cuts[cut].y)
			var right := int(cuts[cut + 1].y)
			var part := Vector2i(mini(left, right), maxi(left, right))
			split_counts[part] = int(split_counts.get(part, 0)) + 1
	for edge: Vector2i in split_counts:
		if int(split_counts[edge]) != 1:
			continue
		var a := unique[edge.x]
		var b := unique[edge.y]
		var index := _edges.size() / 2
		_edges.append_array([a, b])
		_insert_bounds(_edge_bins, Vector2(minf(a.x, b.x) - _blend, minf(a.z, b.z) - _blend),
				Vector2(maxf(a.x, b.x) + _blend, maxf(a.z, b.z) + _blend), index)


func _edge_weight(point: Vector3, key: Vector2i) -> float:
	if _blend <= 0.0 or not _edge_bins.has(key):
		return 1.0
	var distance := _blend
	var candidates: PackedInt32Array = _edge_bins[key]
	var at := Vector2(point.x, point.z)
	for edge: int in candidates:
		var a := Vector2(_edges[edge * 2].x, _edges[edge * 2].z)
		var b := Vector2(_edges[edge * 2 + 1].x, _edges[edge * 2 + 1].z)
		var span := b - a
		var fraction := clampf((at - a).dot(span) / maxf(span.length_squared(), 0.000000001), 0.0, 1.0)
		distance = minf(distance, at.distance_to(a + span * fraction))
	return clampf(distance / _blend, 0.0, 1.0)
