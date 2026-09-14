class_name RoadBuilder
extends Node3D
## Builds the road surface along a trail in chunks: a mesh with optional painted
## edge lines, shaded potholes and ruts, and collision tagged with each stretch's
## surface (the trail's base surface elsewhere, dirt under the shoulders).

const DIRT := preload("res://surfaces/dirt.tres")

## Potholes and ruts are shaded darker by this much per metre of depth.
const SHADE_PER_METRE := 4.0
## Which part of the cross-section a station belongs to.
enum Part { SHOULDER, ROAD, LINE }
## Grid stations closer than this to a rut station are dropped (m).
const MIN_STATION_GAP := 0.05


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
	var stations: Array[Vector2] = [Vector2(-outer, Part.SHOULDER), Vector2(-half_road, Part.SHOULDER)]
	if def.painted_lines:
		var line_outer := half_road - def.line_inset
		var line_inner := line_outer - def.line_width
		stations.append_array([
			Vector2(-half_road, Part.ROAD), Vector2(-line_outer, Part.ROAD),
			Vector2(-line_outer, Part.LINE), Vector2(-line_inner, Part.LINE),
			Vector2(-line_inner, Part.ROAD),
		])
		for lateral in _interior_laterals(def, line_inner):
			stations.append(Vector2(lateral, Part.ROAD))
		stations.append_array([
			Vector2(line_inner, Part.ROAD), Vector2(line_inner, Part.LINE),
			Vector2(line_outer, Part.LINE), Vector2(line_outer, Part.ROAD),
			Vector2(half_road, Part.ROAD),
		])
	else:
		stations.append(Vector2(-half_road, Part.ROAD))
		for lateral in _interior_laterals(def, half_road):
			stations.append(Vector2(lateral, Part.ROAD))
		stations.append(Vector2(half_road, Part.ROAD))
	stations.append_array([Vector2(half_road, Part.SHOULDER), Vector2(outer, Part.SHOULDER)])
	return stations


## Distances of the cross-section rows: every sample_step, every detail_step
## inside rough ranges, and exactly at each surface stretch's ends. Always
## includes 0 and the road's end.
static func row_distances(length: float, profile: RoadProfile, def: TrailDef) -> PackedFloat32Array:
	var boundaries := profile.surface_boundaries()
	var next_boundary := 0
	var distances := PackedFloat32Array()
	var distance := 0.0
	while distance < length - 0.001:
		distances.append(distance)
		var next := distance + (def.detail_step if profile.in_detail_range(distance) else def.sample_step)
		while next_boundary < boundaries.size() and boundaries[next_boundary] <= distance + 0.001:
			next_boundary += 1
		if next_boundary < boundaries.size() and boundaries[next_boundary] < next - 0.001:
			next = boundaries[next_boundary]
		distance = next
	distances.append(length)
	return distances


## Road stations strictly between -limit and limit: a lateral_step grid, plus
## five stations across each wheel rut of any stretch.
static func _interior_laterals(def: TrailDef, limit: float) -> Array[float]:
	var laterals: Array[float] = []
	var lateral := -floorf(limit / def.lateral_step) * def.lateral_step
	if lateral <= -limit:
		lateral += def.lateral_step
	while lateral < limit - 0.001:
		laterals.append(lateral)
		lateral += def.lateral_step
	var ruts: Array[float] = []
	for stretch in def.surface_stretches:
		if stretch.rut_depth <= 0.0:
			continue
		var half_width := stretch.rut_width * 0.5
		for centre: float in [-stretch.rut_spacing * 0.5, stretch.rut_spacing * 0.5]:
			for offset: float in [-half_width, -half_width * 0.5, 0.0, half_width * 0.5, half_width]:
				if absf(centre + offset) < limit - MIN_STATION_GAP:
					ruts.append(centre + offset)
	if ruts.is_empty():
		return laterals
	var merged: Array[float] = ruts.duplicate()
	for grid in laterals:
		if not ruts.any(func(rut: float) -> bool: return absf(rut - grid) < MIN_STATION_GAP):
			merged.append(grid)
	merged.sort()
	return merged


## Collision faces of the road quads in rows whose surface is `surface`, or of
## every shoulder quad when `surface` is null.
static func _faces(vertices: PackedVector3Array, stations: Array[Vector2], row_surfaces: Array[SurfaceDef],
		surface: SurfaceDef) -> PackedVector3Array:
	var width := stations.size()
	var faces := PackedVector3Array()
	for row in row_surfaces.size():
		if surface != null and row_surfaces[row] != surface:
			continue
		for column in width - 1:
			var left := stations[column]
			if is_equal_approx(left.x, stations[column + 1].x):
				continue
			if (int(left.y) == Part.SHOULDER) != (surface == null):
				continue
			var i := row * width + column
			for corner in [i, i + width, i + 1, i + 1, i + width, i + width + 1]:
				faces.append(vertices[corner])
	return faces


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
	var row_surfaces: Array[SurfaceDef] = []
	var surfaces: Array[SurfaceDef] = [def.base_surface]
	for row in distances.size() - 1:
		var surface := profile.surface_at((distances[row] + distances[row + 1]) * 0.5)
		row_surfaces.append(surface)
		if not surfaces.has(surface):
			surfaces.append(surface)
		for column in width - 1:
			if is_equal_approx(stations[column].x, stations[column + 1].x):
				continue  # zero-width boundary between parts
			var i := row * width + column
			indices.append_array([i, i + width, i + 1, i + 1, i + width, i + width + 1])

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

	for surface in surfaces:
		var faces := _faces(vertices, stations, row_surfaces, surface)
		if not faces.is_empty():
			add_child(_collision_body(faces, surface))
	add_child(_collision_body(_faces(vertices, stations, row_surfaces, null), DIRT))


func _color(profile: RoadProfile, def: TrailDef, distance: float, lateral: float, part: int) -> Color:
	match part:
		Part.SHOULDER:
			return def.shoulder_color
		Part.LINE:
			return def.line_color
	var base := def.patch_color if profile.is_patch(distance, lateral) else def.asphalt_color
	var stretch := profile.stretch_at(distance)
	if stretch != null:
		base = base.lerp(stretch.color, stretch.weight(distance))
	var dip := profile.pothole_height(distance, lateral) + profile.rut_height(distance, lateral)
	var shade := clampf(1.0 + dip * SHADE_PER_METRE, 0.5, 1.0)
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
