class_name WaterBed
extends RefCounted
## Build-time extraction of only static triangles near a water footprint. The
## road/StructureMesh arrays are also their concave-collision input. Terrain
## uses its actual triangle diagonal; boulders use their convex collision hull.

## One candidate per static mesh/rock instance. Geometry is resolved lazily,
## only after its cheap bounds intersect a water body, then reused by other
## bodies in this build. None of this build cache survives registration.
class Chunk:
	extends RefCounted
	var mesh: Mesh
	var transform: Transform3D
	var bounds: AABB
	var convex: bool = false
	var ready: bool = false
	var vertices: Array[PackedVector3Array] = []
	var indices: Array[PackedInt32Array] = []

var _field: TerrainField
var _chunks: Array[Chunk] = []
var _mesh_arrays: Dictionary = {}
var _hull_faces: Dictionary = {}


func configure(field: TerrainField, roots: Array[Node3D],
		space_transform: Transform3D = Transform3D.IDENTITY) -> void:
	_field = field
	_chunks.clear()
	_mesh_arrays.clear()
	_hull_faces.clear()
	var inverse := space_transform.affine_inverse()
	for root: Node3D in roots:
		if root != null:
			_collect(root, inverse)


static func extract(top: PackedVector3Array, field: TerrainField, roots: Array[Node3D],
		space_transform: Transform3D = Transform3D.IDENTITY) -> PackedVector3Array:
	var source := WaterBed.new()
	source.configure(field, roots, space_transform)
	return source.extract_faces(top)


func extract_faces(top: PackedVector3Array) -> PackedVector3Array:
	var faces := PackedVector3Array()
	if top.is_empty():
		return faces
	var bounds := AABB(top[0], Vector3.ZERO)
	for point: Vector3 in top:
		bounds = bounds.expand(point)
	# A small numerical margin includes both cells sharing a footprint edge.
	bounds = bounds.grow(0.0001)
	if _field != null:
		_terrain(faces, bounds, _field)
	for chunk: Chunk in _chunks:
		if not _overlaps_xz(bounds, chunk.bounds):
			continue
		_resolve(chunk)
		for surface in chunk.vertices.size():
			faces.append_array(_near_faces(chunk.vertices[surface], chunk.indices[surface], bounds))
	return faces


## Works before _ready as well as in the tree, without off-tree global-transform
## errors. Generated builders do not use top_level transforms.
static func node_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != null:
		if parent is Node3D:
			result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result


static func _terrain(into: PackedVector3Array, bounds: AABB, field: TerrainField) -> void:
	var first_x := maxi(0, floori((bounds.position.x - field.origin.x) / field.spacing))
	var first_z := maxi(0, floori((bounds.position.z - field.origin.y) / field.spacing))
	var last_x := mini(field.columns - 2, floori((bounds.end.x - field.origin.x) / field.spacing))
	var last_z := mini(field.rows - 2, floori((bounds.end.z - field.origin.y) / field.spacing))
	for z in range(first_z, last_z + 1):
		for x in range(first_x, last_x + 1):
			var a := z * field.columns + x
			var b := a + 1
			var c := a + field.columns
			var d := c + 1
			if not field.portal_holes.is_empty() and (field.portal_holes[a] != 0 \
					or field.portal_holes[b] != 0 or field.portal_holes[c] != 0 or field.portal_holes[d] != 0):
				continue
			var near_left := Vector3(field.origin.x + x * field.spacing, field.heights[a], field.origin.y + z * field.spacing)
			var near_right := Vector3(near_left.x + field.spacing, field.heights[b], near_left.z)
			var far_left := Vector3(near_left.x, field.heights[c], near_left.z + field.spacing)
			var far_right := Vector3(near_right.x, field.heights[d], far_left.z)
			into.append_array([near_left, near_right, far_left, near_right, far_right, far_left])


func _collect(node: Node, inverse: Transform3D) -> void:
	# Static collision nodes duplicate these exact meshes; recursing through
	# hundreds of individual boulder shapes cannot discover another mesh.
	if node is CollisionObject3D:
		return
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			var transform := inverse * node_transform(instance)
			_add_chunk(instance.mesh, transform, false)
	elif node is MultiMeshInstance3D:
		var instance := node as MultiMeshInstance3D
		var multi := instance.multimesh
		if multi != null and multi.mesh != null:
			var base := inverse * node_transform(instance)
			for index in multi.instance_count:
				var transform := base * multi.get_instance_transform(index)
				_add_chunk(multi.mesh, transform, true)
	for child: Node in node.get_children():
		_collect(child, inverse)


func _add_chunk(mesh: Mesh, transform: Transform3D, convex: bool) -> void:
	var chunk := Chunk.new()
	chunk.mesh = mesh
	chunk.transform = transform
	chunk.bounds = transform * mesh.get_aabb()
	chunk.convex = convex
	_chunks.append(chunk)


func _resolve(chunk: Chunk) -> void:
	if chunk.ready:
		return
	chunk.ready = true
	if chunk.convex:
		# Fixed boulder vertices define collision, but seeded radius jitter can
		# make their visual triangle groups differ from the exact convex hull.
		# BoulderBuilder itself uses get_faces() as the hull's input, so retain
		# precisely those points here (once per nearby source rock mesh).
		if not _hull_faces.has(chunk.mesh):
			_hull_faces[chunk.mesh] = convex_faces(chunk.mesh.get_faces())
		var hull: PackedVector3Array = _hull_faces[chunk.mesh]
		chunk.vertices.append(hull if chunk.transform == Transform3D.IDENTITY else chunk.transform * hull)
		chunk.indices.append(PackedInt32Array())
		return
	if not _mesh_arrays.has(chunk.mesh):
		var surfaces: Array[Array] = []
		for surface in chunk.mesh.get_surface_count():
			var arrays := chunk.mesh.surface_get_arrays(surface)
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			surfaces.append([arrays[Mesh.ARRAY_VERTEX], indices])
		_mesh_arrays[chunk.mesh] = surfaces
	var cached_surfaces: Array = _mesh_arrays[chunk.mesh]
	for surface: Array in cached_surfaces:
		var points: PackedVector3Array = surface[0]
		var indices: PackedInt32Array = surface[1]
		chunk.vertices.append(points if chunk.transform == Transform3D.IDENTITY else chunk.transform * points)
		chunk.indices.append(indices)


## Mesh.get_faces builds a TriangleMesh/BVH and can quantize positions. Read
## the existing stored arrays directly: these are the actual drawn vertices,
## and expansion preserves their index/face order (including per-face currents).
static func mesh_faces(mesh: Mesh) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			faces.append_array(vertices)
		else:
			var first := faces.size()
			faces.resize(first + indices.size())
			for index in indices.size():
				faces[first + index] = vertices[indices[index]]
	return faces


static func _near_faces(vertices: PackedVector3Array, indices: PackedInt32Array,
		bounds: AABB) -> PackedVector3Array:
	var indexed := not indices.is_empty()
	var size: int = indices.size() if indexed else vertices.size()
	var faces := PackedVector3Array()
	faces.resize(size)
	var used := 0
	var low_x := bounds.position.x
	var low_z := bounds.position.z
	var high_x := bounds.end.x
	var high_z := bounds.end.z
	for index in size / 3:
		var at := index * 3
		var a := vertices[indices[at] if indexed else at]
		var b := vertices[indices[at + 1] if indexed else at + 1]
		var c := vertices[indices[at + 2] if indexed else at + 2]
		if low_x <= maxf(a.x, maxf(b.x, c.x)) and high_x >= minf(a.x, minf(b.x, c.x)) \
				and low_z <= maxf(a.z, maxf(b.z, c.z)) and high_z >= minf(a.z, minf(b.z, c.z)):
			faces[used] = a
			faces[used + 1] = b
			faces[used + 2] = c
			used += 3
	faces.resize(used)
	return faces


static func _overlaps_xz(a: AABB, b: AABB) -> bool:
	return a.position.x <= b.end.x and a.end.x >= b.position.x \
			and a.position.z <= b.end.z and a.end.z >= b.position.z


## Small static rocks have twelve unique vertices. Enumerating supporting
## planes gives the exact convex hull independent of point/face ordering.
## Coplanar triples may overlap; height queries take a maximum, never a sum.
static func convex_faces(source: PackedVector3Array) -> PackedVector3Array:
	var known: Dictionary = {}
	var points := PackedVector3Array()
	for point: Vector3 in source:
		if not known.has(point):
			known[point] = true
			points.append(point)
	var faces := PackedVector3Array()
	for a in points.size() - 2:
		for b in range(a + 1, points.size() - 1):
			for c in range(b + 1, points.size()):
				var normal := (points[b] - points[a]).cross(points[c] - points[a])
				if normal.length_squared() < 0.0000000001:
					continue
				normal = normal.normalized()
				var positive := false
				var negative := false
				for point: Vector3 in points:
					var distance := normal.dot(point - points[a])
					positive = positive or distance > 0.000001
					negative = negative or distance < -0.000001
					if positive and negative:
						break
				if not (positive and negative):
					faces.append_array([points[a], points[b], points[c]])
	return faces
