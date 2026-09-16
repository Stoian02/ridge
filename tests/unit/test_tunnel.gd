extends GutTest

var sampler: RoadSampler
var trail: TrailDef
var tunnel: TunnelDef
var field: TerrainField
var builder: TunnelBuilder


func before_each() -> void:
	var curve := Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0, 0, -200))
	sampler = RoadSampler.new(curve)
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	tunnel = TunnelDef.new()
	tunnel.start = 50.0
	tunnel.length = 100.0
	tunnel.inner_width = 9.0
	trail.tunnels = [tunnel]
	var terrain := TerrainDef.new()
	terrain.margin = 40.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	field = TerrainField.generate(sampler, trail, terrain)
	builder = TunnelBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, field, trail)


func test_arch_matches_width_and_height_and_lamps_follow_spacing() -> void:
	var section := TunnelBuilder.cross_section(tunnel)
	assert_almost_eq(section[0].x, -tunnel.inner_width * 0.5, 0.001)
	assert_almost_eq(section[-1].x, tunnel.inner_width * 0.5, 0.001)
	var top := 0.0
	for point: Vector2 in section:
		top = maxf(top, point.y)
	assert_almost_eq(top, tunnel.height, 0.001)
	assert_eq(builder.lamp_distances.size(), 8)
	for i in range(1, builder.lamp_distances.size()):
		assert_almost_eq(builder.lamp_distances[i] - builder.lamp_distances[i - 1], tunnel.lamp_spacing, 0.001)


func test_shell_has_collision_and_portal_is_open() -> void:
	var ground := TerrainBuilder.new()
	add_child_autofree(ground)
	ground.build(field)
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 2, -100), Vector3(8, 2, -100)))
	assert_false(wall.is_empty(), "inside ray hits the wall")
	var entrance := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1, -30), Vector3(0, 1, -75)))
	assert_true(entrance.is_empty(), "terrain and portals leave the driving opening clear")
	var ceiling := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 2, -100), Vector3(0, 10, -100)))
	assert_false(ceiling.is_empty())
	assert_almost_eq(ceiling["position"].y, tunnel.height, 0.12)


func test_ridge_has_cover_and_approaches_rejoin_natural_corridor() -> void:
	for distance: float in [50.0, 60.0, 100.0, 140.0, 150.0]:
		assert_gte(field.height_at(0.0, -distance), tunnel.height + tunnel.cover - 0.01)
	assert_lt(field.height_at(0.0, -30.0), 0.0)
	assert_lt(field.height_at(0.0, -170.0), 0.0)
	for row in field.rows:
		for column in field.columns:
			var i := field.index(column, row)
			if field.portal_holes[i] == 0:
				continue
			var at := -field.sample_position(column, row).z
			assert_between(at, tunnel.start - tunnel.portal_length - 1.0,
					tunnel.end() + tunnel.portal_length + 1.0, "portal search radius must not extend the hole")
