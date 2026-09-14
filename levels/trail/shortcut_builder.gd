class_name ShortcutBuilder
extends Node3D
## Lays a narrow, worn, rocky shortcut over the terrain beside a trail. The path
## wanders and changes width. Its mesh starts at the shoulder edge instead of
## covering the road, turns from road dirt into worn grass along each join, and
## fades into the grass at its edges, where the terrain is tinted to match.
## Short sharp stone bumps, some showing a half-buried rock, make it rough. The
## terrain is lowered beneath the path so its potholes keep their collision.

const DIRT := preload("res://surfaces/dirt.tres")

## Distance between the path's cross-sections (m).
const ROW_STEP := 0.33
## Largest spacing between vertices across the path's worn middle (m).
const LATERAL_STEP := 0.4
const SURFACE_LIFT := 0.02
const TERRAIN_CLEARANCE := 0.38
const CARVE_MARGIN := 0.5
const SHADE_PER_METRE := 2.0
## Next to the road the path's height changes fade out over this distance past the shoulder edge (m).
const ROAD_FADE := 1.0
## The terrain tint reaches this far past the path's blended edge (m).
const WEAR_REACH := 2.5
## Strongest tint of the terrain beside the path (0..1).
const WEAR_STRENGTH := 0.5
## The shoulder on the path's side is dirt-coloured along each join and fades back over this distance (m).
const JUNCTION_FADE := 6.0
## Stones stay within this share of the half width, where the path is fully rough.
const STONE_SPREAD := 0.6
const STONE_VIEW_DISTANCE := 150.0

var primitive_count: int = 0
var stone_count: int = 0
var visible_stone_count: int = 0
## Stones as Vector4(distance, across, radius, height), sorted by distance.
var stones: Array[Vector4] = []

var _field: TerrainField
var _sampler: RoadSampler
var _profile: RoadProfile
var _trail: TrailDef
var _shortcut: TrailShortcut
var _original_heights := PackedFloat32Array()
var _potholes: Array[Vector4] = []
var _stone_distances := PackedFloat32Array()


func build(field: TerrainField, sampler: RoadSampler, profile: RoadProfile, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	primitive_count = 0
	stone_count = 0
	visible_stone_count = 0
	stones.clear()
	_stone_distances.clear()
	_potholes.clear()
	_field = field
	_sampler = sampler
	_profile = profile
	_trail = trail
	_shortcut = trail.shortcut
	if _shortcut == null or _shortcut.length <= 0.0:
		return
	_original_heights = field.heights.duplicate()
	_generate_potholes()
	_generate_stones()
	_add_surface()
	_add_visible_stones()
	_carve_terrain()


## Centre-line lateral offset at `distance`: eased from the road out to the
## wandering outside offset and back.
static func centre_lateral(shortcut: TrailShortcut, trail: TrailDef, distance: float) -> float:
	var road_offset := maxf(0.0, trail.road_width * 0.5 - shortcut.width * 0.5)
	var outside := maxf(shortcut.lateral_offset + meander(shortcut, distance), road_offset)
	var amount := 1.0
	if shortcut.entry_length > 0.0 and distance < shortcut.start + shortcut.entry_length:
		amount = smoothstep(shortcut.start, shortcut.start + shortcut.entry_length, distance)
	if shortcut.exit_length > 0.0 and distance > shortcut.end() - shortcut.exit_length:
		amount = minf(amount, 1.0 - smoothstep(shortcut.end() - shortcut.exit_length, shortcut.end(), distance))
	return signf(shortcut.side) * lerpf(road_offset, outside, amount)


## How far the path wanders from its average offset at `distance` (m).
static func meander(shortcut: TrailShortcut, distance: float) -> float:
	var waves := shortcut.meander_wavelengths
	return shortcut.meander_amplitude * 0.5 * (sin(TAU * distance / waves.x) + sin(TAU * distance / waves.y + 2.3))


## Half the width of the worn middle at `distance` (m).
static func half_width(shortcut: TrailShortcut, distance: float) -> float:
	return 0.5 * (shortcut.width + shortcut.width_variation * sin(TAU * distance / shortcut.width_wavelength + 0.9))


## How far a point `across` the path lies outside the shoulder edge (m); negative over the road.
static func outside_shoulder(shortcut: TrailShortcut, trail: TrailDef, distance: float, across: float) -> float:
	return signf(shortcut.side) * (centre_lateral(shortcut, trail, distance) + across) - trail.half_total_width()


## Tint of the ground `past_edge` metres outside the path's worn middle (0..1).
## The path mesh and the terrain both use it, so the path's edge matches the ground.
static func wear_amount(shortcut: TrailShortcut, distance: float, past_edge: float) -> float:
	var from_end := minf(distance - shortcut.start, shortcut.end() - distance)
	if from_end < 0.0:
		return 0.0
	var fade := smoothstep(0.0, shortcut.join_color_length, from_end)
	return WEAR_STRENGTH * fade * (1.0 - smoothstep(0.0, shortcut.edge_blend + WEAR_REACH, past_edge))


## How dirt-coloured the road shoulder on the path's side is at `distance`: 1
## along each join, fading out over JUNCTION_FADE.
static func junction_weight(shortcut: TrailShortcut, distance: float) -> float:
	var outside_entry := maxf(shortcut.start - distance, distance - (shortcut.start + shortcut.entry_length))
	var outside_exit := maxf(shortcut.end() - shortcut.exit_length - distance, distance - shortcut.end())
	return 1.0 - smoothstep(0.0, JUNCTION_FADE, minf(outside_entry, outside_exit))


## Height above the unmodified road or terrain at a point across the shortcut.
func height_offset_at(distance: float, across: float) -> float:
	if _shortcut == null:
		return 0.0
	var half := half_width(_shortcut, distance)
	var from_centre := absf(across)
	var lift := SURFACE_LIFT * (1.0 - smoothstep(half, half + _shortcut.edge_blend, from_centre))
	var from_end := minf(distance - _shortcut.start, _shortcut.end() - distance)
	var rough_weight := (1.0 - smoothstep(half * STONE_SPREAD, half, from_centre)) \
			* smoothstep(0.0, _shortcut.rough_fade, maxf(0.0, from_end))
	var along := distance - _shortcut.start
	var feature := RoughShapes.washboard(along, _shortcut.washboard_amplitude, _shortcut.washboard_wavelength)
	feature += _shortcut.undulation_amplitude * 0.5 * sin(TAU * along / _shortcut.undulation_wavelengths.x)
	feature += _shortcut.undulation_amplitude * 0.5 * sin(TAU * along / _shortcut.undulation_wavelengths.y + 1.7)
	for pothole: Vector4 in _potholes:
		feature += RoughShapes.pothole(Vector2(across - pothole.y, distance - pothole.x).length(), pothole.z, pothole.w)
	feature += _stone_height(distance, across)
	var road_fade := smoothstep(0.0, ROAD_FADE, outside_shoulder(_shortcut, _trail, distance, across))
	return (lift + maxf(feature * rough_weight, -TERRAIN_CLEARANCE + 0.05)) * road_fade


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


func _generate_stones() -> void:
	if _shortcut.stone_spacing <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _shortcut.seed + 7717
	var distance := _shortcut.start + _shortcut.rough_fade * 0.5
	var last := _shortcut.end() - _shortcut.rough_fade * 0.5
	while distance < last:
		var spread := half_width(_shortcut, distance) * STONE_SPREAD
		stones.append(Vector4(distance, rng.randf_range(-spread, spread),
				rng.randf_range(_shortcut.stone_radius_range.x, _shortcut.stone_radius_range.y),
				rng.randf_range(_shortcut.stone_height_range.x, _shortcut.stone_height_range.y)))
		_stone_distances.append(distance)
		distance += _shortcut.stone_spacing * rng.randf_range(0.5, 1.5)
	stone_count = stones.size()


func _stone_height(distance: float, across: float) -> float:
	var reach := _shortcut.stone_radius_range.y
	var highest := 0.0
	var i := _stone_distances.bsearch(distance - reach)
	while i < stones.size() and stones[i].x <= distance + reach:
		var stone := stones[i]
		highest = maxf(highest, RoughShapes.bump(Vector2(distance - stone.x, across - stone.y).length(), stone.z * 2.0, stone.w))
		i += 1
	return highest


func _add_surface() -> void:
	# Columns as Vector2(share of the half width, share of the edge blend), left to right.
	var core := ceili((_shortcut.width + absf(_shortcut.width_variation)) / LATERAL_STEP) + 1
	var columns: Array[Vector2] = [Vector2(-1.0, -1.0), Vector2(-1.0, -0.5)]
	for i in core:
		columns.append(Vector2(lerpf(-1.0, 1.0, float(i) / (core - 1)), 0.0))
	columns.append_array([Vector2(1.0, 0.5), Vector2(1.0, 1.0)])

	var side := signf(_shortcut.side)
	var limit := _trail.half_total_width()
	var rows := PackedFloat32Array()
	for distance: float in _sample_range(_shortcut.start, _shortcut.end(), ROW_STEP):
		var far_edge := side * centre_lateral(_shortcut, _trail, distance) + half_width(_shortcut, distance) + _shortcut.edge_blend
		if far_edge > limit + 0.1:
			rows.append(distance)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var acrosses := PackedFloat32Array()
	for distance: float in rows:
		var half := half_width(_shortcut, distance)
		var centre := centre_lateral(_shortcut, _trail, distance)
		for column: Vector2 in columns:
			var across := column.x * half + column.y * _shortcut.edge_blend
			# Pull points that would lie over the road back to the shoulder edge.
			if side * (centre + across) < limit:
				across = side * limit - centre
			acrosses.append(across)
			vertices.append(surface_point(distance, across))
			normals.append(_sampler.up(distance))
			colors.append(_color(distance, across))

	var width := columns.size()
	var indices := PackedInt32Array()
	for row in rows.size() - 1:
		for column in width - 1:
			var i := row * width + column
			if is_equal_approx(acrosses[i], acrosses[i + 1]) and is_equal_approx(acrosses[i + width], acrosses[i + width + 1]):
				continue  # both edges pulled back to the shoulder: no width
			indices.append_array([i, i + width, i + 1, i + 1, i + width, i + width + 1])
	primitive_count = indices.size() / 3
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
	var half := half_width(_shortcut, distance)
	var from_centre := absf(across)
	var ground := _field.def.dirt_color.lerp(_shortcut.color, wear_amount(_shortcut, distance, from_centre - half))
	var from_end := minf(distance - _shortcut.start, _shortcut.end() - distance)
	var worn_color := _trail.asphalt_color.lerp(_shortcut.color,
			smoothstep(0.0, _shortcut.join_color_length, maxf(0.0, from_end)))
	var worn := 1.0 - smoothstep(half * 0.5, half + _shortcut.edge_blend, from_centre)
	var base := ground.lerp(worn_color, worn)
	var shade := clampf(1.0 + height_offset_at(distance, across) * SHADE_PER_METRE, 0.65, 1.25)
	return Color(base.r * shade, base.g * shade, base.b * shade)


func _add_visible_stones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _shortcut.seed + 104729
	var transforms: Array[Transform3D] = []
	for stone: Vector4 in stones:
		var shown := rng.randf() < _shortcut.visible_stone_share
		var yaw := rng.randf() * TAU
		if not shown or outside_shoulder(_shortcut, _trail, stone.x, stone.y) < ROAD_FADE \
				or minf(stone.x - _shortcut.start, _shortcut.end() - stone.x) < _shortcut.rough_fade:
			continue
		var scale := stone.z * 1.3
		var point := surface_point(stone.x, stone.y)
		# A rock reaches about 0.7 of its scale above its centre; leave the top half of the bump showing.
		point.y -= scale * 0.7 - stone.w * 0.5
		transforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), point))
	visible_stone_count = transforms.size()
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = LowPolyMeshes.rock(_shortcut.stone_color, _shortcut.seed)
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	var instance := MultiMeshInstance3D.new()
	instance.name = "Stones"
	instance.multimesh = multimesh
	instance.material_override = material
	instance.visibility_range_end = STONE_VIEW_DISTANCE
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## Lowers the terrain under the path, and tints the ground around it.
func _carve_terrain() -> void:
	var wear := PackedFloat32Array()
	wear.resize(_field.heights.size())
	var widest := 0.5 * (_shortcut.width + absf(_shortcut.width_variation))
	var reach := ceili((widest + _shortcut.edge_blend + WEAR_REACH) / _field.spacing) + 1
	var distance := _shortcut.start
	while distance <= _shortcut.end() + 0.001:
		var centre := surface_point(distance, 0.0)
		var half := half_width(_shortcut, distance)
		var radius := half + CARVE_MARGIN
		var centre_column := roundi((centre.x - _field.origin.x) / _field.spacing)
		var centre_row := roundi((centre.z - _field.origin.y) / _field.spacing)
		for row in range(maxi(0, centre_row - reach), mini(_field.rows, centre_row + reach + 1)):
			for column in range(maxi(0, centre_column - reach), mini(_field.columns, centre_column + reach + 1)):
				var sample := _field.sample_position(column, row)
				var flat_distance := Vector2(sample.x - centre.x, sample.z - centre.z).length()
				var i := _field.index(column, row)
				wear[i] = maxf(wear[i], wear_amount(_shortcut, distance, flat_distance - half))
				if flat_distance > radius:
					continue
				var weight := 1.0 - smoothstep(half, radius, flat_distance)
				_field.heights[i] = minf(_field.heights[i], _original_heights[i] - TERRAIN_CLEARANCE * weight)
		distance += 1.0
	_field.wear = wear
	_field.wear_color = _shortcut.color
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
