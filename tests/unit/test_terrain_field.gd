extends GutTest
## TerrainField on small, noise-free roads so heights can be checked exactly.

var trail: TrailDef
var terrain: TerrainDef


func before_each() -> void:
	trail = TrailDef.new()
	terrain = TerrainDef.new()
	terrain.margin = 60.0
	terrain.chunk_size = 32.0
	terrain.sample_spacing = 2.0
	terrain.noise_amplitude = 0.0


func _sampler(points: Array[Vector3]) -> RoadSampler:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for point in points:
		curve.add_point(point)
	return RoadSampler.new(curve)


func _flat_straight() -> TerrainField:
	return TerrainField.generate(_sampler([Vector3.ZERO, Vector3(0.0, 0.0, -200.0)]), trail, terrain)


func test_grid_covers_the_road_plus_margin_in_whole_chunks() -> void:
	var field := _flat_straight()
	assert_lte(field.origin.x, -60.0)
	assert_lte(field.origin.y, -260.0)
	assert_gte(field.origin.x + (field.columns - 1) * field.spacing, 60.0)
	assert_gte(field.origin.y + (field.rows - 1) * field.spacing, 60.0)
	assert_eq((field.columns - 1) % field.cells_per_chunk, 0, "columns fill whole chunks")
	assert_eq((field.rows - 1) % field.cells_per_chunk, 0, "rows fill whole chunks")


func test_terrain_sits_below_the_road_and_meets_the_shoulders() -> void:
	var field := _flat_straight()
	assert_almost_eq(field.height_at(0.0, -100.0), -terrain.under_road_drop, 0.02, "under the road centre")
	assert_almost_eq(field.height_at(trail.half_total_width(), -100.0), -Corridor.EDGE_GAP, 0.05, "at the shoulder edge")
	assert_almost_eq(field.height_at(50.0, -100.0), 0.0, 0.01, "natural ground beyond the blend")


func test_edge_distance_measures_from_the_shoulder_edge() -> void:
	var field := _flat_straight()
	assert_almost_eq(field.edge_distance_at(16.0, -100.0), 10.0, 1.1)
	assert_lt(field.edge_distance_at(0.0, -100.0), 0.0, "negative under the road")


func test_natural_ground_follows_the_road_climb() -> void:
	var field := TerrainField.generate(_sampler([Vector3.ZERO, Vector3(0.0, 20.0, -200.0)]), trail, terrain)
	assert_almost_eq(field.height_at(55.0, -100.0), 10.0, 0.2, "beside the middle of a 20 m climb")
	assert_almost_eq(field.height_at(-55.0, -180.0), 18.0, 0.2, "beside its upper end")


func test_flat_ground_faces_up() -> void:
	var field := _flat_straight()
	assert_gt(field.normal_at(50.0, -100.0).y, 0.999)


func test_kill_height_is_below_the_lowest_ground() -> void:
	var field := _flat_straight()
	assert_almost_eq(field.kill_height(), field.lowest_height - terrain.kill_depth, 0.0001)


func test_generation_is_deterministic() -> void:
	terrain.noise_amplitude = 20.0
	var a := _flat_straight()
	var b := _flat_straight()
	assert_eq(a.heights, b.heights)


func test_switchback_legs_leave_no_cliff_between_them() -> void:
	# Down one leg, a tight turn, and back up a parallel leg 30 m away and 12 m higher.
	var field := TerrainField.generate(_sampler([
		Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -120.0),
		Vector3(15.0, 6.0, -135.0), Vector3(30.0, 12.0, -120.0), Vector3(30.0, 12.0, 0.0),
	]), trail, terrain)
	var steepest := 0.0
	for x in range(6, 26, 2):
		var step := absf(field.height_at(x + 2.0, -60.0) - field.height_at(float(x), -60.0))
		steepest = maxf(steepest, step)
	gut.p("steepest 2 m step between the legs: %.2f m" % steepest)
	assert_lt(steepest, 2.5, "no vertical step where the two legs' corridors meet")
