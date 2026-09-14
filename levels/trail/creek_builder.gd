class_name CreekBuilder
extends Node3D
## Lays a creek's water in the channel TerrainField cuts beside the road: a flat,
## glossy ribbon at the field's water level. Visual only, with no collision; the
## channel floor underneath is ordinary ground.

## Where the water would be shallower than this (the tapered ends), none is laid (m).
const MIN_DEPTH := 0.1
## Distance between the ribbon's cross-sections (m).
const STEP := 2.0

## The water surface's centre point at each laid cross-section, for tests.
var water_points := PackedVector3Array()


func build(field: TerrainField, sampler: RoadSampler, trail: TrailDef) -> void:
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
	var material := StandardMaterial3D.new()
	material.albedo_color = trail.creek_color
	material.roughness = 0.15
	material.metallic_specular = 0.8
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = mesh
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
