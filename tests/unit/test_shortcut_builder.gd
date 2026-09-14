extends GutTest
## Worn shortcut path geometry, roughness and collision on a straight trail.

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


func test_builds_a_worn_mesh_and_dirt_collision_above_lowered_terrain() -> void:
	var centre := sampler.position(120.0) + sampler.right(120.0) * -12.0
	var terrain_before := field.height_at(centre.x, centre.z)
	builder.build(field, sampler, profile, trail)
	assert_eq(builder.primitive_count, 4800, "300 half-metre rows by eight quads")
	assert_eq(builder.get_children().filter(func(child: Node) -> bool: return child is MeshInstance3D).size(), 1)
	var collision := builder.get_node("ShortcutCollision")
	assert_eq(SurfaceLookup.surface_of(collision).id, &"dirt")
	assert_lt(field.height_at(centre.x, centre.z), terrain_before - 0.25, "terrain leaves room under potholes")


func test_roughness_has_a_large_range_but_fades_at_the_joins() -> void:
	builder.build(field, sampler, profile, trail)
	var lowest := INF
	var highest := -INF
	var distance := 80.0
	while distance < 170.0:
		var offset := builder.height_offset_at(distance, 0.0)
		lowest = minf(lowest, offset)
		highest = maxf(highest, offset)
		distance += 0.25
	assert_gt(highest - lowest, 0.25, "washboard, undulation and potholes are much rougher than grass")
	assert_almost_eq(builder.height_offset_at(50.0, 0.0), 0.02, 0.001)
	assert_almost_eq(builder.height_offset_at(200.0, 0.0), 0.02, 0.001)


func test_shortcut_surface_has_collision() -> void:
	builder.build(field, sampler, profile, trail)
	await wait_physics_frames(2)
	var point := builder.surface_point(120.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 2.0)
	var hit := builder.get_world_3d().direct_space_state.intersect_ray(query)
	assert_eq(hit["collider"], builder.get_node("ShortcutCollision"))
