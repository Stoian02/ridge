extends GutTest
## Worn, rocky shortcut path: its shape, where its mesh starts, roughness,
## blending into the road and grass, and collision, on a straight trail.

var sampler: RoadSampler
var trail: TrailDef
var profile: RoadProfile
var field: TerrainField
var shortcut: TrailShortcut
var builder: ShortcutBuilder


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -250.0))
	sampler = RoadSampler.new(curve)
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	shortcut = TrailShortcut.new()
	shortcut.start = 50.0
	shortcut.length = 150.0
	shortcut.side = -1.0
	shortcut.lateral_offset = 12.0
	shortcut.width = 4.0
	shortcut.entry_length = 20.0
	shortcut.exit_length = 20.0
	shortcut.meander_amplitude = 0.0
	shortcut.seed = 9
	trail.shortcut = shortcut
	profile = RoadProfile.new(trail, sampler.length)
	var terrain := TerrainDef.new()
	terrain.margin = 20.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	terrain.under_road_drop = 0.0
	field = TerrainField.generate(sampler, trail, terrain)
	builder = ShortcutBuilder.new()
	add_child_autofree(builder)


func test_path_eases_from_the_road_to_behind_the_hedge_and_back() -> void:
	assert_almost_eq(ShortcutBuilder.centre_lateral(shortcut, trail, 50.0), -1.5, 0.001)
	assert_almost_eq(ShortcutBuilder.centre_lateral(shortcut, trail, 70.0), -12.0, 0.001)
	assert_almost_eq(ShortcutBuilder.centre_lateral(shortcut, trail, 180.0), -12.0, 0.001)
	assert_almost_eq(ShortcutBuilder.centre_lateral(shortcut, trail, 200.0), -1.5, 0.001)


func test_the_path_wanders_and_changes_width() -> void:
	shortcut.meander_amplitude = 2.0
	var laterals: Array[float] = []
	var halves: Array[float] = []
	var distance := 70.0
	while distance <= 180.0:
		laterals.append(absf(ShortcutBuilder.centre_lateral(shortcut, trail, distance)))
		halves.append(ShortcutBuilder.half_width(shortcut, distance))
		distance += 1.0
	var nearest: float = laterals.min()
	var furthest: float = laterals.max()
	assert_gte(nearest, 10.0 - 0.001, "never more than the meander amplitude from its offset")
	assert_lte(furthest, 14.0 + 0.001)
	assert_gt(furthest - nearest, 1.0, "it wanders")
	var narrowest: float = halves.min()
	var widest: float = halves.max()
	assert_between(narrowest * 2.0, 3.3 - 0.001, 3.6)
	assert_between(widest * 2.0, 4.4, 4.7 + 0.001)


func test_the_mesh_starts_at_the_shoulder_edge_instead_of_covering_the_road() -> void:
	builder.build(field, sampler, profile, trail)
	var mesh: ArrayMesh = builder.get_node("ShortcutMesh").mesh
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var closest := INF
	for vertex in vertices:
		closest = minf(closest, absf(sampler.lateral_offset(vertex)))
	assert_almost_eq(closest, trail.half_total_width(), 0.05, "the path's nearest vertices sit on the shoulder edge")


func test_builds_a_worn_mesh_and_dirt_collision_above_lowered_terrain() -> void:
	var centre := sampler.position(120.0) + sampler.right(120.0) * -12.0
	var terrain_before := field.height_at(centre.x, centre.z)
	builder.build(field, sampler, profile, trail)
	assert_between(builder.primitive_count, 5000, 30000)
	assert_not_null(builder.get_node_or_null("ShortcutMesh"))
	var collision := builder.get_node("ShortcutCollision")
	assert_eq(SurfaceLookup.surface_of(collision).id, &"dirt")
	assert_lt(field.height_at(centre.x, centre.z), terrain_before - 0.25, "terrain leaves room under potholes")


func test_the_path_is_rough_in_the_middle_and_smooth_at_the_joins() -> void:
	builder.build(field, sampler, profile, trail)
	var lowest := INF
	var highest := -INF
	var distance := 80.0
	while distance < 170.0:
		for across: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var offset := builder.height_offset_at(distance, across)
			lowest = minf(lowest, offset)
			highest = maxf(highest, offset)
		distance += 0.25
	assert_gt(highest - lowest, 0.25, "stones and potholes make it much rougher than grass")
	assert_almost_eq(builder.height_offset_at(50.0, 0.0), 0.0, 0.001, "level with the road where it branches off")
	assert_almost_eq(builder.height_offset_at(200.0, 0.0), 0.0, 0.001, "level with the road where it rejoins")


func test_stones_stand_up_from_the_path_and_some_show_a_rock() -> void:
	builder.build(field, sampler, profile, trail)
	assert_gt(builder.stone_count, 60)
	assert_gt(builder.visible_stone_count, 10)
	assert_not_null(builder.get_node_or_null("Stones"))
	var stone: Vector4 = builder.stones[builder.stones.size() / 2]
	assert_gt(builder.height_offset_at(stone.x, stone.y), stone.w - 0.1, "a stone lifts the surface at its centre")


func test_the_ground_beside_the_path_is_tinted_and_kept_clear_of_scenery() -> void:
	builder.build(field, sampler, profile, trail)
	var centre := sampler.position(120.0) + sampler.right(120.0) * -12.0
	assert_gt(field.wear_at(centre.x, centre.z), 0.3)
	var away := sampler.position(120.0) + sampler.right(120.0) * 12.0
	assert_eq(field.wear_at(away.x, away.z), 0.0, "the other side of the road is untouched")
	var scatter := ScatterDef.new()
	scatter.pine_spacing = 3.0
	scatter.rock_spacing = 3.0
	var scenery := ScatterBuilder.new()
	add_child_autofree(scenery)
	scenery.build(field, sampler, profile, trail, scatter)
	var on_worn_ground := 0
	for child in scenery.get_children():
		if child is MultiMeshInstance3D:
			for i in child.multimesh.instance_count:
				var spot: Vector3 = child.multimesh.get_instance_transform(i).origin
				if field.wear_at(spot.x, spot.z) > 0.0:
					on_worn_ground += 1
	assert_eq(on_worn_ground, 0)


func test_the_road_shoulder_turns_to_road_dirt_along_each_join() -> void:
	assert_almost_eq(ShortcutBuilder.junction_weight(shortcut, 60.0), 1.0, 0.001, "along the entry")
	assert_almost_eq(ShortcutBuilder.junction_weight(shortcut, 73.0), 0.5, 0.001, "fading after it")
	assert_almost_eq(ShortcutBuilder.junction_weight(shortcut, 120.0), 0.0, 0.001, "beside the middle")
	assert_almost_eq(ShortcutBuilder.junction_weight(shortcut, 190.0), 1.0, 0.001, "along the exit")
	var road := RoadBuilder.new()
	add_child_autofree(road)
	road.build(sampler, profile, trail)
	var edge := trail.half_total_width()
	assert_true(_close(_shoulder_color_near(road, 60.0, -edge), trail.asphalt_color), "left shoulder at the entry")
	assert_true(_close(_shoulder_color_near(road, 120.0, -edge), trail.shoulder_color), "left shoulder beside the middle")
	assert_true(_close(_shoulder_color_near(road, 60.0, edge), trail.shoulder_color), "the other shoulder is unchanged")


func test_shortcut_surface_has_collision() -> void:
	builder.build(field, sampler, profile, trail)
	await wait_physics_frames(2)
	var point := builder.surface_point(120.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 2.0)
	var hit := builder.get_world_3d().direct_space_state.intersect_ray(query)
	assert_eq(hit["collider"], builder.get_node("ShortcutCollision"))


## Vertex colour of the road mesh vertex nearest `distance` along the road and `lateral` across it.
func _shoulder_color_near(road: RoadBuilder, distance: float, lateral: float) -> Color:
	var target := sampler.position(distance) + sampler.right(distance) * lateral
	var best := INF
	var color := Color.BLACK
	for child in road.get_children():
		if child is MeshInstance3D:
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for i in vertices.size():
				var gap := Vector2(vertices[i].x - target.x, vertices[i].z - target.z).length()
				if gap < best:
					best = gap
					color = colors[i]
	return color


## Vertex colours are stored as 8-bit, so compare within a couple of steps.
func _close(a: Color, b: Color) -> bool:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) < 0.02
