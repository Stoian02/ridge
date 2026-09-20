class_name RoadBlendBuilder
extends Node3D
## A grounded, colliding earth join outside the authored shoulders. Road vertices
## stay untouched. Opt-in per trail; absent on the narrow shelf and river bed.

const COLUMNS := 5
var _appearance_field: TerrainField
var _ground_cache: Dictionary = {}


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_ground_cache.clear()
	_appearance_field = field
	if trail.terrain_blend_width <= 0.0:
		return
	var rows := RoadBuilder.row_distances(sampler.length, profile, trail)
	var first := 0
	while first < rows.size() - 1:
		var last := first + 1
		while last < rows.size() - 1 and rows[last + 1] <= rows[first] + trail.chunk_length:
			last += 1
		_chunk(sampler, profile, field, trail, rows.slice(first, last + 1))
		first = last


## Keep the technical shelf's width and the ford's open water/rock banks.
static func width_at(trail: TrailDef, distance: float) -> float:
	var weight := 1.0
	for section: Vector4 in trail.shelf_walls:
		var before := 1.0 - smoothstep(section.x, section.x + trail.width_blend, distance)
		var after := smoothstep(section.x + section.y - trail.width_blend, section.x + section.y, distance)
		weight = minf(weight, maxf(before, after))
	for ford: FordDef in trail.fords:
		var away := absf(distance - ford.distance) - ford.half_width() - ford.bank_run
		weight = minf(weight, smoothstep(0.0, 6.0, away))
	for bridge: BridgeDef in trail.bridges:
		if distance >= bridge.start and distance <= bridge.end() + bridge.ramp_length:
			return 0.0
	return trail.terrain_blend_width * weight


func _chunk(sampler: RoadSampler, profile: RoadProfile, field: TerrainField,
		trail: TrailDef, rows: PackedFloat32Array) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision: Dictionary = {}
	for side: float in [-1.0, 1.0]:
		var offset := vertices.size()
		for distance: float in rows:
			var ring := _ring(sampler, profile, field, trail, distance, side)
			vertices.append_array(ring["vertices"])
			normals.append_array(ring["normals"])
			colors.append_array(ring["colors"])
		for row in rows.size() - 1:
			if width_at(trail, rows[row]) < 0.001 and width_at(trail, rows[row + 1]) < 0.001:
				continue
			var midpoint := (rows[row] + rows[row + 1]) * 0.5
			var surface := trail.shoulder_surface
			var stretch := profile.stretch_at(midpoint)
			if stretch != null and stretch.affects_shoulders:
				surface = stretch.surface_at(midpoint)
			var faces: PackedVector3Array = collision.get(surface, PackedVector3Array())
			for column in COLUMNS - 1:
				var i := offset + row * COLUMNS + column
				var corners: Array[int] = [i, i + COLUMNS, i + 1, i + 1, i + COLUMNS, i + COLUMNS + 1]
				if side < 0.0:
					corners = [i, i + 1, i + COLUMNS, i + 1, i + COLUMNS + 1, i + COLUMNS]
				for corner: int in corners:
					indices.append(corner)
					faces.append(vertices[corner])
			collision[surface] = faces
	if indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.name = "EarthJoin%d" % roundi(rows[0])
	instance.visibility_range_end = trail.road_view_distance
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	for surface: SurfaceDef in collision:
		var body := RoadBuilder._collision_body(collision[surface], surface)
		body.name = "%s_%sCollision" % [instance.name, surface.id]
		add_child(body)


func _ring(sampler: RoadSampler, profile: RoadProfile, field: TerrainField,
		trail: TrailDef, distance: float, side: float) -> Dictionary:
	var edge := sampler.surface_point(distance, side * sampler.half_width_at(distance), profile)
	var right := sampler.right(distance)
	var outward := Vector3(right.x, 0.0, right.z).normalized() * side
	var up := sampler.up(distance)
	var color := profile.surface_color(distance, trail.shoulder_color, true)
	var reach := width_at(trail, distance)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for column in COLUMNS:
		var t := float(column) / (COLUMNS - 1)
		var point := edge + outward * reach * t
		var ground := ground_height(field, point.x, point.z)
		var appearance := _ground_appearance(field, point.x, point.z)
		var ground_normal: Vector3 = appearance["normal"]
		if column > 0 and reach > 0.0001:
			point.y = maxf(lerpf(edge.y, ground, t), ground + 0.01)
			if column == COLUMNS - 1:
				point.y = ground - 0.035  # bury the seam, not a second floating layer
		var ground_color: Color = appearance["color"]
		# The outer half already uses the ground's exact interpolated appearance.
		# Partly buried triangles must not leave coloured sawteeth at intersections.
		var blend := smoothstep(0.0, 0.5, t)
		vertices.append(point)
		normals.append(up.slerp(ground_normal, blend))
		colors.append(color.lerp(ground_color, blend))
	return {"vertices": vertices, "normals": normals, "colors": colors}


## Interpolate the same three vertex normals/colours that TerrainBuilder draws.
## Nearest-grid sampling leaves visible zigzags where the meshes intersect.
func _ground_appearance(field: TerrainField, x: float, z: float) -> Dictionary:
	if _appearance_field != field:
		_ground_cache.clear()
		_appearance_field = field
	var fx := clampf((x - field.origin.x) / field.spacing, 0.0, field.columns - 1.001)
	var fz := clampf((z - field.origin.y) / field.spacing, 0.0, field.rows - 1.001)
	var column := int(fx)
	var row := int(fz)
	var tx := fx - column
	var tz := fz - row
	var corners: Array[Vector2i] = [Vector2i(column, row), Vector2i(column + 1, row), Vector2i(column, row + 1)]
	var weights := Vector3(1.0 - tx - tz, tx, tz)
	if tx + tz > 1.0:
		corners = [Vector2i(column + 1, row + 1), Vector2i(column, row + 1), Vector2i(column + 1, row)]
		weights = Vector3(tx + tz - 1.0, 1.0 - tx, 1.0 - tz)
	var normal := Vector3.ZERO
	var color := Color(0, 0, 0, 0)
	for i in 3:
		var corner := corners[i]
		var index := field.index(corner.x, corner.y)
		if not _ground_cache.has(index):
			_ground_cache[index] = _ground_vertex(field, corner)
		var cached: Dictionary = _ground_cache[index]
		var n: Vector3 = cached["normal"]
		var c: Color = cached["color"]
		normal += n * weights[i]
		color += c * weights[i]
	return {"normal": normal.normalized(), "color": color}


func _ground_vertex(field: TerrainField, corner: Vector2i) -> Dictionary:
	var normal := field.normal_at_index(corner.x, corner.y)
	var slope := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
	var rockiness := smoothstep(field.def.rock_slope_deg - TerrainBuilder.COLOR_BLEND_DEG,
		field.def.rock_slope_deg + TerrainBuilder.COLOR_BLEND_DEG, slope)
	var color := field.def.dirt_color.lerp(field.def.rock_color, rockiness)
	var index := field.index(corner.x, corner.y)
	if not field.wall_strata.is_empty() and field.wall_strata[index] > 0.0:
		var point := field.sample_position(corner.x, corner.y)
		var layer := point.y + sin(point.x * 0.025) * 1.5 + sin(point.z * 0.018)
		var band := smoothstep(-0.25, 0.25, sin(layer * 0.72))
		var sandstone := field.def.rock_color * lerpf(0.76, 1.13, band)
		sandstone.a = 1.0
		color = color.lerp(sandstone, field.wall_strata[index] * 0.85)
	if not field.wear.is_empty():
		color = color.lerp(field.wear_color, field.wear[index])
	return {"normal": normal, "color": color}


## Match TerrainBuilder's visible triangle diagonal, not bilinear interpolation.
static func ground_height(field: TerrainField, x: float, z: float) -> float:
	var fx := clampf((x - field.origin.x) / field.spacing, 0.0, field.columns - 1.001)
	var fz := clampf((z - field.origin.y) / field.spacing, 0.0, field.rows - 1.001)
	var column := int(fx)
	var row := int(fz)
	var tx := fx - column
	var tz := fz - row
	var a := field.heights[field.index(column, row)]
	var b := field.heights[field.index(column + 1, row)]
	var c := field.heights[field.index(column, row + 1)]
	var d := field.heights[field.index(column + 1, row + 1)]
	if tx + tz <= 1.0:
		return a + (b - a) * tx + (c - a) * tz
	return d + (c - d) * (1.0 - tx) + (b - d) * (1.0 - tz)
