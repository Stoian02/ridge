class_name WaterRegistration
extends RefCounted
## A builder owns its registrations. Rebuild/exit removes only its own bodies.

var _world: WaterWorld
var _bodies: Array[WaterBody] = []
var extract_usec: int = 0
var index_usec: int = 0
var top_triangles: int = 0
var bed_triangles: int = 0


func clear() -> void:
	if _world != null:
		for body: WaterBody in _bodies:
			_world.remove_body(body)
	_bodies.clear()
	_world = null
	extract_usec = 0
	index_usec = 0
	top_triangles = 0
	bed_triangles = 0


func add_mesh(world: WaterWorld, def: WaterBodyDef, instance: MeshInstance3D,
		field: TerrainField, static_roots: Array[Node3D], space_transform: Transform3D,
		currents: PackedVector3Array = PackedVector3Array(), bed_source: WaterBed = null) -> WaterBody:
	if world == null or instance == null or instance.mesh == null or not WaterBody.supports_transform(space_transform):
		return null
	if _world != null and _world != world:
		clear()
	_world = world
	var started := Time.get_ticks_usec()
	var relative := space_transform.affine_inverse() * WaterBed.node_transform(instance)
	var faces: PackedVector3Array = relative * WaterBed.mesh_faces(instance.mesh)
	var bed: PackedVector3Array = bed_source.extract_faces(faces) if bed_source != null \
			else WaterBed.extract(faces, field, static_roots, space_transform)
	extract_usec += Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var body := world.add_body(def, faces, bed, space_transform, currents)
	index_usec += Time.get_ticks_usec() - started
	top_triangles += faces.size() / 3
	bed_triangles += bed.size() / 3
	if body != null:
		_bodies.append(body)
	return body


func summary() -> String:
	return "extract %.3f, index %.3f, top %d, bed %d" % [
			extract_usec / 1000000.0, index_usec / 1000000.0, top_triangles, bed_triangles]
