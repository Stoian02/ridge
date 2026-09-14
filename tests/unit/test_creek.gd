extends GutTest
## A creek beside a flat, noise-free straight road: the channel TerrainField cuts,
## the water CreekBuilder lays in it, and scenery keeping out of it.

var trail: TrailDef
var terrain: TerrainDef
var sampler: RoadSampler


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -300.0))
	sampler = RoadSampler.new(curve)
	trail = TrailDef.new()
	trail.creek_start = 50.0
	trail.creek_length = 200.0
	terrain = TerrainDef.new()
	terrain.margin = 60.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0


func _field() -> TerrainField:
	return TerrainField.generate(sampler, trail, terrain)


## The ground height `outward` metres further from the road than the creek's centre line.
func _height_beside(field: TerrainField, distance: float, outward: float) -> float:
	var centre := TerrainField.creek_point(sampler, trail, distance)
	var away := (centre - Vector2(sampler.position(distance).x, sampler.position(distance).z)).normalized()
	var spot := centre + away * outward
	return field.height_at(spot.x, spot.y)


func test_the_channel_floor_is_creek_depth_below_the_ground_beside_it() -> void:
	var field := _field()
	var floor := _height_beside(field, 150.0, 0.0)
	var beside := _height_beside(field, 150.0, 12.0)
	gut.p("floor %.2f m, ground beside %.2f m" % [floor, beside])
	assert_almost_eq(floor, beside - trail.creek_depth, 0.06)
	assert_almost_eq(_height_beside(field, 150.0, 1.0), floor, 0.02, "a flat floor across the creek's width")
	assert_between(_height_beside(field, 150.0, 3.5), floor + 0.05, beside - 0.05, "a sloping bank")


func test_the_channel_tapers_to_nothing_at_its_ends() -> void:
	var field := _field()
	var beside := _height_beside(field, 150.0, 12.0)
	assert_almost_eq(_height_beside(field, 30.0, 0.0), beside, 0.03, "before the creek")
	assert_almost_eq(_height_beside(field, 44.0, 0.0), beside, 0.03, "just beyond the reach of its first bank")
	assert_between(_height_beside(field, 55.0, 0.0), beside - trail.creek_depth + 0.05, beside - 0.05, "deepening")
	assert_almost_eq(_height_beside(field, 270.0, 0.0), beside, 0.03, "after its end")


func test_the_road_and_shoulders_are_not_cut() -> void:
	var with_creek := _field()
	trail.creek_length = 0.0
	var without := _field()
	var edge := trail.half_total_width()
	for lateral: float in [0.0, edge, edge + 2.0]:  # the creek's raised bank reaches 9 m from its centre, 17 m out
		var spot := sampler.position(150.0) + sampler.right(150.0) * lateral * signf(trail.creek_offset)
		assert_almost_eq(with_creek.height_at(spot.x, spot.z), without.height_at(spot.x, spot.z), 0.0001,
				"%.1f m from the centre line" % lateral)


func test_creek_distances_measure_from_the_centre_line() -> void:
	var field := _field()
	var centre := TerrainField.creek_point(sampler, trail, 150.0)
	assert_almost_eq(field.creek_distance_at(centre.x, centre.y), 0.0, 1.5)
	assert_eq(field.creek_distance_at(-200.0, -150.0), TerrainField.FAR, "far from the creek")
	trail.creek_length = 0.0
	assert_eq(_field().creek_distances.count(TerrainField.FAR), _field().creek_distances.size(), "no creek")


func test_water_lies_in_the_channel_below_both_rims() -> void:
	var field := _field()
	var builder := CreekBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, trail)
	assert_not_null(builder.get_node_or_null("Water"))
	assert_gt(builder.water_points.size(), 80, "water along most of 200 m at one point every 2 m")
	var across := sampler.right(150.0)
	var flat := Vector2(across.x, across.z).normalized()
	var half := trail.creek_width * 0.5 + TerrainField.CREEK_BANK
	for point in builder.water_points:
		var centre := Vector2(point.x, point.z)
		var lower_rim := minf(field.height_at(centre.x - flat.x * half, centre.y - flat.y * half),
				field.height_at(centre.x + flat.x * half, centre.y + flat.y * half))
		assert_gte(point.y, field.height_at(centre.x, centre.y) + CreekBuilder.MIN_DEPTH - 0.02, "above the floor")
		assert_lte(point.y, lower_rim - TerrainField.CREEK_BELOW_GROUND + 0.01, "below the lower rim (sampled between grid points)")


func test_no_creek_builds_no_water() -> void:
	trail.creek_length = 0.0
	var builder := CreekBuilder.new()
	add_child_autofree(builder)
	builder.build(_field(), sampler, trail)
	assert_eq(builder.get_child_count(), 0)
	assert_eq(builder.water_points.size(), 0)


func test_scenery_keeps_out_of_the_creek() -> void:
	var field := _field()
	var scatter := ScatterDef.new()
	scatter.pine_spacing = 4.0
	scatter.rock_spacing = 4.0
	scatter.broadleaf_spacing = 4.0
	var builder := ScatterBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, RoadProfile.new(trail, sampler.length), trail, scatter)
	assert_gt(builder.broadleaf_count, 100)
	var clearance := trail.creek_width * 0.5 + ScatterBuilder.CREEK_CLEARANCE
	var checked := 0
	for child in builder.get_children():
		if child is MultiMeshInstance3D:
			for i in child.multimesh.instance_count:
				var spot: Vector3 = child.multimesh.get_instance_transform(i).origin
				assert_gte(field.creek_distance_at(spot.x, spot.z), clearance)
				checked += 1
	assert_gt(checked, 300)


func test_broadleaf_trees_are_only_placed_when_spaced() -> void:
	var field := _field()
	var builder := ScatterBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, RoadProfile.new(trail, sampler.length), trail, ScatterDef.new())
	assert_eq(builder.broadleaf_count, 0, "Rally Road's default: none")
