class_name WaterWaveMesh
extends RefCounted
## Standalone opt-in top only. Does not register a body or change source arrays.
## Initial scope: one horizontal simple footprint, no islands/holes or transforms.

const WELD := 10000.0
const EPS := 0.00001

var vertices := PackedVector3Array()
var indices := PackedInt32Array()
var colors := PackedColorArray()
var limits := PackedFloat32Array()
var limit_gradients := PackedVector2Array()
var mesh: ArrayMesh
var pitch := 0.75
var level := 0.0
var build_usec := 0
## Optional preparation audit. Timing never changes the generated geometry.
var build_phases: Dictionary = {}
var error := ""
var _cells: Dictionary = {}
var _points: Dictionary = {}
var _source: WaterBody
var _profile: WaterWaveProfile
var _source_colors := PackedColorArray()
var _shore := PackedVector2Array()
var _shore_bins: Dictionary = {}


## Fail closed on stale/missing packaged data: never silently rebuild in play.
## Arrays are copy-on-write; topology remains scene-owned, not mutable global state.
func use_bake(bake: WaterWaveBake, expected: String) -> bool:
	var started := Time.get_ticks_usec()
	clear()
	if bake == null or not bake.matches(expected):
		return _fail("Wave bake missing/stale; regenerate offline before enabling waves")
	vertices = bake.vertices
	indices = bake.indices
	colors = bake.colors
	limits = bake.limits
	limit_gradients = bake.limit_gradients
	_cells = bake.cells.duplicate()
	mesh = bake.mesh
	pitch = bake.pitch
	level = bake.level
	build_usec = Time.get_ticks_usec() - started
	return true


func build(top: PackedVector3Array, bed: PackedVector3Array,
		top_colors := PackedColorArray(), settings: WaterWaveProfile = null, audit := false) -> bool:
	var started := Time.get_ticks_usec()
	clear()
	_profile = settings if settings != null else WaterWaveProfile.new()
	if not _profile.is_valid() or top.is_empty() or (not top_colors.is_empty() and top_colors.size() != top.size()):
		return _fail("Invalid profile/top colours")
	pitch = _profile.mesh_pitch
	level = top[0].y
	for point: Vector3 in top:
		if not point.is_finite() or absf(point.y - level) > EPS:
			return _fail("Only finite horizontal water tops are supported")
	var def := WaterBodyDef.new()
	def.shore_probe_blend = _profile.shore_distance
	_source = WaterBody.new()
	if not _source.configure(def, top, bed, Transform3D.IDENTITY, PackedVector3Array()):
		return _fail("Invalid static water geometry")
	var indexed := Time.get_ticks_usec()
	if audit:
		build_phases["source_index_usec"] = indexed - started
	_source_colors = top_colors
	var outline := _outline()
	if outline.size() < 3:
		outline = _union_outline(top)
	if outline.size() < 3:
		return _fail("Expected one closed simple footprint (no holes)")
	error = ""
	_shore = outline
	var boundary_cells: Dictionary = {}
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var low := _cell(a.min(b) - Vector2.ONE * EPS)
		var high := _cell(a.max(b) + Vector2.ONE * EPS)
		for z in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				boundary_cells[Vector2i(x, z)] = true
		low = _cell(a.min(b) - Vector2.ONE * _profile.shore_distance)
		high = _cell(a.max(b) + Vector2.ONE * _profile.shore_distance)
		for z in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var key := Vector2i(x, z)
				var edges: PackedInt32Array = _shore_bins.get(key, PackedInt32Array())
				edges.append(index)
				_shore_bins[key] = edges
	var outlined := Time.get_ticks_usec()
	var depth_usec := 0
	if audit:
		build_phases["outline_shore_index_usec"] = outlined - indexed
	var first := _cell(Vector2(_source.bounds.position.x, _source.bounds.position.z))
	var last := _cell(Vector2(_source.bounds.end.x, _source.bounds.end.z))
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var key := Vector2i(x, z)
			var low := Vector2(key) * pitch
			var high := low + Vector2.ONE * pitch
			var rectangle := PackedVector2Array([low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)])
			var polygons: Array[PackedVector2Array] = []
			if boundary_cells.has(key):
				polygons = Geometry2D.intersect_polygons(rectangle, outline)
			elif _top_triangle((low + high) * 0.5) >= 0:
				polygons.append(rectangle)
			if polygons.is_empty():
				continue
			# Maximum over every intersecting static bed face, including breakpoints
			# within the cell. A whole-cell bound is conservative for both triangles.
			var depth_started := Time.get_ticks_usec() if audit else 0
			var bottom := _cell_highest_bed(low, high)
			if audit:
				depth_usec += Time.get_ticks_usec() - depth_started
			if not is_finite(bottom):
				return _fail("Water cell has no bed")
			var local_limit := minf(_profile.maximum_offset, maxf(0.0, level - bottom) * _profile.depth_fraction)
			for polygon: PackedVector2Array in polygons:
				if Geometry2D.is_polygon_clockwise(polygon):
					polygon.reverse()
				var triangles := Geometry2D.triangulate_polygon(polygon)
				for triangle in triangles.size() / 3:
					var a := polygon[triangles[triangle * 3]]
					var b := polygon[triangles[triangle * 3 + 1]]
					var c := polygon[triangles[triangle * 3 + 2]]
					if absf((b - a).cross(c - a)) < 0.00000001:
						continue
					var corners := PackedInt32Array([_vertex(a, local_limit), _vertex(b, local_limit), _vertex(c, local_limit)])
					var va := vertices[corners[0]]
					var vb := vertices[corners[1]]
					var vc := vertices[corners[2]]
					if Vector2(vb.x - va.x, vb.z - va.z).cross(Vector2(vc.x - va.x, vc.z - va.z)) <= 0.00000001:
						continue  # welding a microscopic clipped sliver can collapse it
					var id := indices.size() / 3
					indices.append_array(corners)
					var cell_triangles: PackedInt32Array = _cells.get(key, PackedInt32Array())
					cell_triangles.append(id)
					_cells[key] = cell_triangles
	if indices.is_empty():
		return _fail("Empty refined water top")
	if audit:
		build_phases["depth_derivation_usec"] = depth_usec
		build_phases["topology_attributes_usec"] = Time.get_ticks_usec() - outlined - depth_usec
	_finish_arrays(audit)
	# Source extraction/index data is build-only, not another persistent bed cache.
	_source = null
	_source_colors = PackedColorArray()
	_points.clear()
	_shore.clear()
	_shore_bins.clear()
	_profile = null
	build_usec = Time.get_ticks_usec() - started
	if audit:
		build_phases["total_usec"] = build_usec
	return true


func clear() -> void:
	vertices.clear()
	indices.clear()
	colors.clear()
	limits.clear()
	limit_gradients.clear()
	_cells.clear()
	_points.clear()
	mesh = null
	_source = null
	_profile = null
	_source_colors = PackedColorArray()
	_shore.clear()
	_shore_bins.clear()
	error = ""
	build_usec = 0
	build_phases.clear()


func _fail(message: String) -> bool:
	clear()
	error = message
	return false


func triangle_at(at: Vector2) -> int:
	return int(locate(at).w)


## Same triangle order and barycentric equations as the original search. A
## generated triangle stays inside its grid cell except tiny weld/float error;
## don't triangle-test lower neighbours when the point is well past that seam.
## Return weights with the ID so a height query needn't calculate them twice.
func locate(at: Vector2) -> Vector4:
	if not at.is_finite():
		return Vector4(0.0, 0.0, 0.0, -1.0)
	var key := _cell(at)
	var margin := 2.0 / WELD + 4.0 * EPS * maxf(1.0, pitch) \
		+ maxf(absf(at.x), absf(at.y)) * 0.000001
	# Boundary points can belong to the cell immediately below a grid seam.
	for dz in range(-1, 1):
		if dz == -1 and at.y > key.y * pitch + margin:
			continue
		for dx in range(-1, 1):
			if dx == -1 and at.x > key.x * pitch + margin:
				continue
			var candidates: PackedInt32Array = _cells.get(key + Vector2i(dx, dz), PackedInt32Array())
			for triangle: int in candidates:
				var weights := barycentric(at, triangle)
				if weights.x >= -EPS and weights.y >= -EPS and weights.z >= -EPS:
					return Vector4(weights.x, weights.y, weights.z, triangle)
	return Vector4(0.0, 0.0, 0.0, -1.0)


func barycentric(at: Vector2, triangle: int) -> Vector3:
	var a3 := vertices[indices[triangle * 3]]
	var b3 := vertices[indices[triangle * 3 + 1]]
	var c3 := vertices[indices[triangle * 3 + 2]]
	var a := Vector2(a3.x, a3.z)
	var ab := Vector2(b3.x, b3.z) - a
	var ac := Vector2(c3.x, c3.z) - a
	var u := (at - a).cross(ac) / ab.cross(ac)
	var v := ab.cross(at - a) / ab.cross(ac)
	return Vector3(1.0 - u - v, u, v)


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / pitch), floori(at.y / pitch))


static func _point_key(at: Vector2) -> Vector2i:
	return Vector2i(roundi(at.x * WELD), roundi(at.y * WELD))


static func _near_key(at: Vector2, positions: Dictionary) -> Vector2i:
	var key := _point_key(at)
	for z in range(-1, 2):
		for x in range(-1, 2):
			var neighbour := key + Vector2i(x, z)
			if positions.has(neighbour) and (positions[neighbour] as Vector2).distance_squared_to(at) < 1.0 / (WELD * WELD):
				return neighbour
	return key


## WaterBody already splits source T-junctions: only its actual external edges
## form this loop. Internal source colour/triangle seams are not wave shorelines.
func _outline() -> PackedVector2Array:
	var neighbours: Dictionary = {}
	var positions: Dictionary = {}
	for index in _source._edges.size() / 2:
		var a3 := _source._edges[index * 2]
		var b3 := _source._edges[index * 2 + 1]
		var a := _near_key(Vector2(a3.x, a3.z), positions)
		positions[a] = Vector2(a3.x, a3.z)
		var b := _near_key(Vector2(b3.x, b3.z), positions)
		if a == b:
			continue
		positions[a] = Vector2(a3.x, a3.z)
		positions[b] = Vector2(b3.x, b3.z)
		for pair: Array in [[a, b], [b, a]]:
			var adjacent: Array = neighbours.get(pair[0], [])
			if not adjacent.has(pair[1]):
				adjacent.append(pair[1])
			neighbours[pair[0]] = adjacent
	if neighbours.is_empty():
		return PackedVector2Array()
	for key: Vector2i in neighbours:
		var adjacent: Array = neighbours[key]
		if adjacent.size() != 2:
			error = "Footprint endpoint %s has %d neighbours" % [positions[key], adjacent.size()]
			return PackedVector2Array()
	var first: Vector2i = neighbours.keys()[0]
	var previous := first
	var at := first
	var result := PackedVector2Array()
	for index in neighbours.size():
		result.append(positions[at])
		var adjacent: Array = neighbours[at]
		var next: Vector2i = adjacent[0] if adjacent[0] != previous else adjacent[1]
		previous = at
		at = next
		if at == first:
			return result if result.size() == neighbours.size() else PackedVector2Array()
	return PackedVector2Array()


## Clipped source meshes can retain microscopic T-junction gaps. Union snapped
## source triangles if the fast edge chain cannot close. Snap only this temporary
## outline (<=0.1 mm), never the registered/static source or the ground.
static func _union_outline(top: PackedVector3Array) -> PackedVector2Array:
	var polygons: Array[PackedVector2Array] = []
	for index in top.size() / 3:
		var incoming := PackedVector2Array()
		for corner in 3:
			var point := top[index * 3 + corner]
			incoming.append(Vector2(_point_key(Vector2(point.x, point.z))) / WELD)
		var at := 0
		while at < polygons.size():
			var joined := Geometry2D.merge_polygons(incoming, polygons[at])
			if joined.size() == 1:
				incoming = joined[0]
				polygons.remove_at(at)
				at = 0
			else:
				at += 1
		polygons.append(incoming)
	return polygons[0] if polygons.size() == 1 else PackedVector2Array()


func _top_triangle(at: Vector2) -> int:
	var candidates: PackedInt32Array = _source._top_bins.get(WaterBody._cell(at.x, at.y), PackedInt32Array())
	for triangle: int in candidates:
		if is_finite(WaterBody.triangle_height(_source._top, triangle * 3, at.x, at.y)):
			return triangle
	return -1


func _vertex(at: Vector2, cell_limit: float) -> int:
	var key := _point_key(at)
	var id: int = _points.get(key, -1)
	if id < 0:
		id = vertices.size()
		_points[key] = id
		vertices.append(Vector3(at.x, level, at.y))
		limits.append(_profile.maximum_offset)
		var triangle := _top_triangle(at)
		var color := WaterAppearance.SHALLOW
		if triangle >= 0 and not _source_colors.is_empty():
			var first := triangle * 3
			var a := _source._top[first]
			var b := _source._top[first + 1]
			var c := _source._top[first + 2]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var ac := Vector2(c.x - a.x, c.z - a.z)
			var delta := at - Vector2(a.x, a.z)
			var u := delta.cross(ac) / ab.cross(ac)
			var v := ab.cross(delta) / ab.cross(ac)
			color = _source_colors[first] * (1.0 - u - v) + _source_colors[first + 1] * u + _source_colors[first + 2] * v
		colors.append(color)
	var distance := _profile.shore_distance
	var edges: PackedInt32Array = _shore_bins.get(_cell(at), PackedInt32Array())
	for edge: int in edges:
		var a := _shore[edge]
		var b := _shore[(edge + 1) % _shore.size()]
		var span := b - a
		var t := clampf((at - a).dot(span) / maxf(span.length_squared(), 0.00000001), 0.0, 1.0)
		distance = minf(distance, at.distance_to(a + span * t))
	var weight := distance / _profile.shore_distance
	limits[id] = minf(limits[id], cell_limit * smoothstep(0.0, 1.0, weight))
	return id


func _cell_highest_bed(low: Vector2, high: Vector2) -> float:
	var candidates: Dictionary = {}
	var first := WaterBody._cell(low.x, low.y)
	var last := WaterBody._cell(high.x, high.y)
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var faces: PackedInt32Array = _source._bed_bins.get(Vector2i(x, z), PackedInt32Array())
			for triangle: int in faces:
				candidates[triangle] = true
	var maximum := -INF
	for triangle: int in candidates:
		var start := triangle * 3
		var face := PackedVector3Array([_source._bed[start], _source._bed[start + 1], _source._bed[start + 2]])
		face = _clip_axis(face, 0, low.x, false)
		face = _clip_axis(face, 0, high.x, true)
		face = _clip_axis(face, 2, low.y, false)
		face = _clip_axis(face, 2, high.y, true)
		for point: Vector3 in face:
			maximum = maxf(maximum, point.y)
	return maximum


static func _clip_axis(polygon: PackedVector3Array, axis: int, cut: float, below: bool) -> PackedVector3Array:
	var result := PackedVector3Array()
	if polygon.is_empty():
		return result
	var previous := polygon[polygon.size() - 1]
	var prior_inside: bool = previous[axis] <= cut if below else previous[axis] >= cut
	for point: Vector3 in polygon:
		var inside: bool = point[axis] <= cut if below else point[axis] >= cut
		if inside != prior_inside:
			result.append(previous.lerp(point, (cut - previous[axis]) / (point[axis] - previous[axis])))
		if inside:
			result.append(point)
		previous = point
		prior_inside = inside
	return result


func _finish_arrays(audit := false) -> void:
	var started := Time.get_ticks_usec()
	limit_gradients.resize(vertices.size())
	var counts := PackedInt32Array()
	counts.resize(vertices.size())
	for triangle in indices.size() / 3:
		var a := indices[triangle * 3]
		var b := indices[triangle * 3 + 1]
		var c := indices[triangle * 3 + 2]
		var ab := Vector2(vertices[b].x - vertices[a].x, vertices[b].z - vertices[a].z)
		var ac := Vector2(vertices[c].x - vertices[a].x, vertices[c].z - vertices[a].z)
		var db := limits[b] - limits[a]
		var dc := limits[c] - limits[a]
		var gradient := Vector2(db * ac.y - dc * ab.y, dc * ab.x - db * ac.x) / ab.cross(ac)
		for id: int in [a, b, c]:
			limit_gradients[id] += gradient
			counts[id] += 1
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var uv := PackedVector2Array()
	uv.resize(vertices.size())
	for index in vertices.size():
		limit_gradients[index] /= maxf(1.0, counts[index])
		uv[index] = Vector2(limits[index], 0.0)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = limit_gradients
	arrays[Mesh.ARRAY_INDEX] = indices
	var prepared := Time.get_ticks_usec()
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = mesh.get_aabb().grow(_profile.maximum_offset)
	if audit:
		build_phases["normals_arrays_usec"] = prepared - started
		build_phases["mesh_commit_usec"] = Time.get_ticks_usec() - prepared
