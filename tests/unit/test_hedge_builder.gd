extends GutTest
## Hedge visuals and collision on a small straight trail.

var sampler: RoadSampler
var trail: TrailDef
var field: TerrainField
var builder: HedgeBuilder


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -150.0))
	sampler = RoadSampler.new(curve)
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.hedges = [Vector3(50.0, 40.0, -1.0)]
	trail.hedge_gaps = [Vector3(68.0, 4.0, -1.0)]
	trail.hedge_returns = [Vector3(50.0, 12.0, -1.0), Vector3(90.0, 12.0, -1.0)]
	var terrain := TerrainDef.new()
	terrain.margin = 20.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	terrain.under_road_drop = 0.0
	field = TerrainField.generate(sampler, trail, terrain)
	builder = HedgeBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, trail)


func _point(distance: float, lateral: float) -> Vector3:
	var point := sampler.position(distance) + sampler.right(distance) * lateral
	point.y = field.height_at(point.x, point.z) + 0.7
	return point


func _crossing_hit(distance: float) -> Dictionary:
	var line := HedgeBuilder.line_lateral(trail, -1.0)
	var query := PhysicsRayQueryParameters3D.create(_point(distance, line + 3.0), _point(distance, line - 3.0))
	return builder.get_world_3d().direct_space_state.intersect_ray(query)


func test_bushes_are_batched_and_wall_is_tagged_as_dirt() -> void:
	assert_gt(builder.bush_count, 25)
	assert_gt(builder.wall_segment_count, 4)
	assert_gt(builder.get_children().filter(func(child: Node) -> bool: return child is MultiMeshInstance3D).size(), 0)
	var collision := builder.get_node("HedgeCollision")
	assert_eq(SurfaceLookup.surface_of(collision).id, &"dirt")


func test_wall_follows_the_run_but_leaves_the_configured_gap() -> void:
	await wait_physics_frames(2)
	assert_false(_crossing_hit(60.0).is_empty(), "solid hedge before the gap")
	assert_true(_crossing_hit(70.0).is_empty(), "four-metre opening centred at 70 m")
	assert_false(_crossing_hit(80.0).is_empty(), "solid hedge after the gap")
	assert_true(_crossing_hit(30.0).is_empty(), "nothing before the configured run")


func test_return_blocks_the_route_around_the_hedge_end() -> void:
	await wait_physics_frames(2)
	var line := HedgeBuilder.line_lateral(trail, -1.0)
	var lateral := line - 6.0
	var query := PhysicsRayQueryParameters3D.create(_point(46.0, lateral), _point(54.0, lateral))
	assert_false(builder.get_world_3d().direct_space_state.intersect_ray(query).is_empty())


func test_empty_configuration_builds_nothing() -> void:
	trail.hedges.clear()
	trail.hedge_gaps.clear()
	trail.hedge_returns.clear()
	builder.build(field, sampler, trail)
	await wait_process_frames(1)
	assert_eq(builder.bush_count, 0)
	assert_eq(builder.wall_segment_count, 0)
	assert_eq(builder.get_child_count(), 0)
