class_name RoadBuilder
extends Node3D
## Builds the road surface along a trail in chunks: a mesh with painted edge
## lines and shaded potholes, asphalt collision for the road, and dirt
## collision for the shoulders.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")

## Potholes are shaded darker by this much per metre of depth.
const SHADE_PER_METRE := 4.0
## Which part of the cross-section a station belongs to.
enum Part { SHOULDER, ASPHALT, LINE }


func build(sampler: RoadSampler, profile: RoadProfile, def: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var stations := cross_section(def)
	var distances := row_distances(sampler.length, profile, def)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9

	var chunk_start := 0
	while chunk_start < distances.size() - 1:
		var chunk_end := chunk_start
		var limit := distances[chunk_start] + def.chunk_length
		while chunk_end < distances.size() - 1 and distances[chunk_end + 1] <= limit + 0.001:
			chunk_end += 1
		if chunk_end == chunk_start:
			chunk_end += 1
		_add_chunk(sampler, profile, def, stations, distances.slice(chunk_start, chunk_end + 1), material)
		chunk_start = chunk_end


## Cross-section stations from left to right as Vector2(lateral offset, part).
## Boundaries between parts appear twice (one station per part) so colours
## change sharply instead of fading.
static func cross_section(def: TrailDef) -> Array[Vector2]:
	var half_road := def.road_width * 0.5
	var outer := half_road + def.shoulder_width
	var line_outer := half_road - def.line_inset
	var line_inner := line_outer - def.line_width
	var stations: Array[Vector2] = [
		Vector2(-outer, Part.SHOULDER), Vector2(-half_road, Part.SHOULDER),
		Vector2(-half_road, Part.ASPHALT), Vector2(-line_outer, Part.ASPHALT),
		Vector2(-line_outer, Part.LINE), Vector2(-line_inner, Part.LINE),
		Vector2(-line_inner, Part.ASPHALT),
	]
	var lateral := -floorf(line_inner / def.lateral_step) * def.lateral_step
	if lateral <= -line_inner:
		lateral += def.lateral_step
	while lateral < line_inner - 0.001:
		stations.append(Vector2(lateral, Part.ASPHALT))
		lateral += def.lateral_step
	stations.append_array([
		Vector2(line_inner, Part.ASPHALT), Vector2(line_inner, Part.LINE),
		Vector2(line_outer, Part.LINE), Vector2(line_outer, Part.ASPHALT),
		Vector2(half_road, Part.ASPHALT), Vector2(half_road, Part.SHOULDER),
		Vector2(outer, Part.SHOULDER),
	])
	return stations


## Distances of the cross-section rows: every sample_step, and every
## detail_step inside rough ranges. Always includes 0 and the road's end.
static func row_distances(length: float, profile: RoadProfile, def: TrailDef) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	var distance := 0.0
	while distance < length - 0.001:
		distances.append(distance)
		distance += def.detail_step if profile.in_detail_range(distance) else def.sample_step
	distances.append(length)
	return distances


func _add_chunk(sampler: RoadSampler, profile: RoadProfile, def: TrailDef, stations: Array[Vector2],
		distances: PackedFloat32Array, material: StandardMaterial3D) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for distance in distances:
		var centre := sampler.position(distance)
		var across := sampler.right(distance)
		var surface_up := sampler.up(distance)
		for station in stations:
			var lateral := station.x
			vertices.append(centre + across * lateral + surface_up * profile.height(distance, lateral))
			normals.append(surface_up)
			colors.append(_color(profile, def, distance, lateral, int(station.y)))

	var width := stations.size()
	var indices := PackedInt32Array()
	var road_faces := PackedVector3Array()
	var shoulder_faces := PackedVector3Array()
	for row in distances.size() - 1:
		for column in width - 1:
			var left := stations[column]
			var right := stations[column + 1]
			if is_equal_approx(left.x, right.x):
				continue  # zero-width boundary between parts
			var i := row * width + column
			var quad := [i, i + width, i + 1, i + 1, i + width, i + width + 1]
			indices.append_array(quad)
			var faces := road_faces if int(left.y) != Part.SHOULDER else shoulder_faces
			for corner in quad:
				faces.append(vertices[corner])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)

	add_child(_collision_body(road_faces, ASPHALT))
	add_child(_collision_body(shoulder_faces, DIRT))


func _color(profile: RoadProfile, def: TrailDef, distance: float, lateral: float, part: int) -> Color:
	match part:
		Part.SHOULDER:
			return def.shoulder_color
		Part.LINE:
			return def.line_color
	var base := def.patch_color if profile.is_patch(distance, lateral) else def.asphalt_color
	var shade := clampf(1.0 + profile.pothole_height(distance, lateral) * SHADE_PER_METRE, 0.5, 1.0)
	return Color(base.r * shade, base.g * shade, base.b * shade)


static func _collision_body(faces: PackedVector3Array, surface: SurfaceDef) -> StaticBody3D:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.set_meta(SurfaceLookup.META_KEY, surface)
	body.add_child(collision)
	return body
