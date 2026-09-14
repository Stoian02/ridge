class_name ShortcutBuilder
extends Node3D
## Lays a narrow, worn and deliberately rough shortcut over the terrain. The
## terrain is lowered beneath the ribbon so its potholes keep their collision.

const DIRT := preload("res://surfaces/dirt.tres")

const ROW_STEP := 0.5
const LATERAL_STEP := 0.5
const SURFACE_LIFT := 0.02
const TERRAIN_CLEARANCE := 0.38
const CARVE_MARGIN := 0.5
const SHADE_PER_METRE := 2.0

var primitive_count: int = 0

var _field: TerrainField
var _sampler: RoadSampler
var _profile: RoadProfile
var _trail: TrailDef
var _shortcut: TrailShortcut
var _original_heights := PackedFloat32Array()
var _potholes: Array[Vector4] = []


func build(field: TerrainField, sampler: RoadSampler, profile: RoadProfile, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	primitive_count = 0
	_field = field
	_sampler = sampler
	_profile = profile
	_trail = trail
	_shortcut = trail.shortcut
	_potholes.clear()
	if _shortcut == null or _shortcut.length <= 0.0:
		return
	_original_heights = field.heights.duplicate()
	_generate_potholes()
	_add_surface()
	_carve_terrain()


## Centre-line lateral offset at `distance`, eased from the road to the full
## outside offset and back.
static func centre_lateral(shortcut: TrailShortcut, trail: TrailDef, distance: float) -> float:
	var road_offset := maxf(0.0, trail.road_width * 0.5 - shortcut.width * 0.5)
	var outside := maxf(shortcut.lateral_offset, road_offset)
	var amount := 1.0
	if shortcut.entry_length > 0.0 and distance < shortcut.start + shortcut.entry_length:
		amount = smoothstep(shortcut.start, shortcut.start + shortcut.entry_length, distance)
	if shortcut.exit_length > 0.0 and distance > shortcut.end() - shortcut.exit_length:
		amount = minf(amount, 1.0 - smoothstep(shortcut.end() - shortcut.exit_length, shortcut.end(), distance))
	return signf(shortcut.side) * lerpf(road_offset, outside, amount)


## Height above the unmodified road or terrain at a point across the shortcut.
func height_offset_at(distance: float, across: float) -> float:
	if _shortcut == null:
		return 0.0
	var edge_weight := 1.0 - smoothstep(_shortcut.width * 0.3, _shortcut.width * 0.5, absf(across))
	var from_end := minf(distance - _shortcut.start, _shortcut.end() - distance)
	var rough_weight := smoothstep(0.0, _shortcut.rough_fade, maxf(0.0, from_end))
	var along := distance - _shortcut.start
	var feature := RoughShapes.washboard(along, _shortcut.washboard_amplitude, _shortcut.washboard_wavelength)
	feature += _shortcut.undulation_amplitude * 0.5 * sin(TAU * along / _shortcut.undulation_wavelengths.x)
	feature += _shortcut.undulation_amplitude * 0.5 * sin(TAU * along / _shortcut.undulation_wavelengths.y + 1.7)
	for pothole: Vector4 in _potholes:
		feature += RoughShapes.pothole(Vector2(across - pothole.y, distance - pothole.x).length(), pothole.z, pothole.w)
	var offset := SURFACE_LIFT + feature * rough_weight
	return maxf(offset, -TERRAIN_CLEARANCE + 0.05) * edge_weight


## World point on the generated shortcut. Call after build().
func surface_point(distance: float, across: float = 0.0) -> Vector3:
	var at := clampf(distance, _shortcut.start, _shortcut.end())
	var lateral := centre_lateral(_shortcut, _trail, at) + across
	var point := _sampler.position(at) + _sampler.right(at) * lateral
	point.y = _base_height(at, lateral) + height_offset_at(at, across)
	return point


## Reset-height transform facing along the shortcut.
func transform_at(distance: float, height_above: float) -> Transform3D:
	var origin := surface_point(distance) + Vector3.UP * height_above
	var along := (surface_point(distance + 0.5) - surface_point(distance - 0.5)).normalized()
	return Transform3D(Basis.looking_at(along, Vector3.UP), origin)


func _generate_potholes() -> void:
	if _shortcut.pothole_spacing <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _shortcut.seed
	var distance := _shortcut.start + _shortcut.rough_fade + _shortcut.pothole_spacing * 0.5
	var last := _shortcut.end() - _shortcut.rough_fade
	while distance < last:
		_potholes.append(Vector4(distance,
				rng.randf_range(-_shortcut.width * 0.3, _shortcut.width * 0.3),
				rng.randf_range(_shortcut.pothole_radius_range.x, _shortcut.pothole_radius_range.y),
				rng.randf_range(_shortcut.pothole_depth_range.x, _shortcut.pothole_depth_range.y)))
		distance += _shortcut.pothole_spacing * rng.randf_range(0.8, 1.2)


func _add_surface() -> void:
	var distances := _sample_range(_shortcut.start, _shortcut.end(), ROW_STEP)
	var laterals := _sample_range(-_shortcut.width * 0.5, _shortcut.width * 0.5, LATERAL_STEP)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for distance: float in distances:
		for across: float in laterals:
			vertices.append(surface_point(distance, across))
			normals.append(_sampler.up(distance))
			colors.append(_color(distance, across))
	var indices := PackedInt32Array()
	var width := laterals.size()
	for row in distances.size() - 1:
		for column in width - 1:
			var i := row * width + column
			indices.append_array([i, i + width, i + 1, i + 1, i + width, i + width + 1])
	primitive_count = indices.size() / 3

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
	var instance := MeshInstance3D.new()
	instance.name = "ShortcutMesh"
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

	var faces := PackedVector3Array()
	for index: int in indices:
		faces.append(vertices[index])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	var body := StaticBody3D.new()
	body.name = "ShortcutCollision"
	body.set_meta(SurfaceLookup.META_KEY, DIRT)
	body.add_child(collision_shape)
	add_child(body)


func _color(distance: float, across: float) -> Color:
	var edge_weight := 1.0 - smoothstep(_shortcut.width * 0.25, _shortcut.width * 0.5, absf(across))
	var from_end := minf(distance - _shortcut.start, _shortcut.end() - distance)
	var join_weight := smoothstep(0.0, minf(_shortcut.entry_length, _shortcut.exit_length) * 0.5, maxf(0.0, from_end))
	var worn := _field.def.dirt_color.lerp(_shortcut.color, edge_weight)
	var base := _trail.asphalt_color.lerp(worn, join_weight)
	var shade := clampf(1.0 + height_offset_at(distance, across) * SHADE_PER_METRE, 0.65, 1.25)
	return Color(base.r * shade, base.g * shade, base.b * shade)


func _carve_terrain() -> void:
	var distance := _shortcut.start
	var radius := _shortcut.width * 0.5 + CARVE_MARGIN
	var reach := ceili(radius / _field.spacing)
	while distance <= _shortcut.end() + 0.001:
		var centre := surface_point(distance, 0.0)
		var centre_column := roundi((centre.x - _field.origin.x) / _field.spacing)
		var centre_row := roundi((centre.z - _field.origin.y) / _field.spacing)
		for row in range(maxi(0, centre_row - reach), mini(_field.rows, centre_row + reach + 1)):
			for column in range(maxi(0, centre_column - reach), mini(_field.columns, centre_column + reach + 1)):
				var sample := _field.sample_position(column, row)
				var flat_distance := Vector2(sample.x - centre.x, sample.z - centre.z).length()
				if flat_distance > radius:
					continue
				var weight := 1.0 - smoothstep(_shortcut.width * 0.5, radius, flat_distance)
				var i := _field.index(column, row)
				var target := _original_heights[i] - TERRAIN_CLEARANCE * weight
				_field.heights[i] = minf(_field.heights[i], target)
		distance += 1.0
	_field.lowest_height = INF
	for height: float in _field.heights:
		_field.lowest_height = minf(_field.lowest_height, height)


func _base_height(distance: float, lateral: float) -> float:
	if absf(lateral) <= _trail.half_total_width():
		return _sampler.surface_point(distance, lateral, _profile).y
	var point := _sampler.position(distance) + _sampler.right(distance) * lateral
	return _original_height_at(point.x, point.z)


func _original_height_at(x: float, z: float) -> float:
	var fx := clampf((x - _field.origin.x) / _field.spacing, 0.0, _field.columns - 1.001)
	var fz := clampf((z - _field.origin.y) / _field.spacing, 0.0, _field.rows - 1.001)
	var column := int(fx)
	var row := int(fz)
	var tx := fx - column
	var tz := fz - row
	var near := lerpf(_original_heights[_field.index(column, row)],
			_original_heights[_field.index(column + 1, row)], tx)
	var far := lerpf(_original_heights[_field.index(column, row + 1)],
			_original_heights[_field.index(column + 1, row + 1)], tx)
	return lerpf(near, far, tz)


static func _sample_range(from: float, to: float, step: float) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	var value := from
	while value < to - 0.001:
		values.append(value)
		value += step
	values.append(to)
	return values
