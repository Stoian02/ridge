class_name CreekBuilder
extends Node3D
## Lays a creek's water in the channel TerrainField cuts beside the road: a flat,
## glossy ribbon at the field's water level. The query layer follows its actual
## triangles; the ordinary solid channel floor remains the wheel support.

## Where the water would be shallower than this (the tapered ends), none is laid (m).
const MIN_DEPTH := 0.1
## Distance between the ribbon's cross-sections (m).
const STEP := 2.0

## The water surface's centre point at each laid cross-section, for tests.
var water_points := PackedVector3Array()
var _face_currents := PackedVector3Array()
var _water_def: WaterBodyDef
var _registrations := WaterRegistration.new()


func build(field: TerrainField, sampler: RoadSampler, trail: TrailDef) -> void:
	_registrations.clear()
	_face_currents.clear()
	_water_def = null
	set_process(false)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	water_points.clear()
	if not trail.has_creek():
		return
	var half_ribbon := trail.creek_width * 0.5 + TerrainField.CREEK_BANK
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var previous_laid := false
	var end := minf(trail.creek_start + trail.creek_length, sampler.length)
	var distance := trail.creek_start
	while distance <= end:
		var level := field.creek_water_level(distance)
		var centre := TerrainField.creek_point(sampler, trail, distance)
		var laid := level >= field.height_at(centre.x, centre.y) + MIN_DEPTH
		if laid:
			var across := sampler.right(distance)
			var flat := Vector2(across.x, across.z).normalized()
			if previous_laid:
				var i := vertices.size() - 2
				indices.append_array([i, i + 2, i + 1, i + 1, i + 2, i + 3])
				var tangent := Vector3(centre.x, level, centre.y) - water_points[-1]
				tangent.y = 0.0
				tangent = tangent.normalized() * trail.creek_current_speed
				_face_currents.append_array([tangent, tangent])
			var left := centre - flat * half_ribbon
			var right := centre + flat * half_ribbon
			vertices.append(Vector3(left.x, level, left.y))
			vertices.append(Vector3(right.x, level, right.y))
			water_points.append(Vector3(centre.x, level, centre.y))
		previous_laid = laid
		distance += STEP
	if indices.is_empty():
		return

	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := WaterAppearance.make_material(Color(trail.creek_color, 0.55), false, true)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = mesh
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_water_def = WaterBodyDef.new()
	_water_def.id = &"creek"
	_water_def.color = Color(trail.creek_color, 0.55)
	# Consistent direction along connected segments, from the higher end toward
	# the lower end; no reversal at tiny interpolated ripples in the ribbon.
	if water_points[-1].y > water_points[0].y:
		for index in _face_currents.size():
			_face_currents[index] = -_face_currents[index]
	set_process(true)


func register_water(world: WaterWorld, field: TerrainField, static_roots: Array[Node3D],
		space_transform: Transform3D = Transform3D.IDENTITY, bed_source: WaterBed = null) -> void:
	_registrations.clear()
	if _water_def != null:
		_registrations.add_mesh(world, _water_def, get_node("Water"), field, static_roots,
				space_transform, _face_currents, bed_source)


func _process(delta: float) -> void:
	if _water_def != null:
		var water: MeshInstance3D = get_node("Water")
		var current: Vector3 = _face_currents[0] if not _face_currents.is_empty() else Vector3.ZERO
		WaterAppearance.advance(water.material_override as StandardMaterial3D, current, delta)


func _exit_tree() -> void:
	_registrations.clear()


func water_summary() -> String:
	return _registrations.summary()
