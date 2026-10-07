extends GutTest

const GENERATOR := preload("res://tools/generate_coastal_highway_curve.gd")
const CURVE := preload("res://levels/coastal_highway/coastal_highway_curve.tres")
const TRAIL := preload("res://levels/coastal_highway/coastal_highway_trail.tres")
const SCATTER := preload("res://levels/coastal_highway/coastal_highway_scatter.tres")


func test_route_is_three_km_and_reproduces_from_generator_without_crowding() -> void:
	var generated: Curve3D = GENERATOR.build_curve()
	assert_almost_eq(CURVE.get_baked_length(), 3000.0, 5.0)
	assert_eq(generated.get_baked_points(), CURVE.get_baked_points())
	assert_true(CurveGenerator.separation_problems(generated).is_empty())
	assert_eq(CURVE.get_point_position(0).y, 24.0)


func test_preview_preserves_surface_split_and_has_no_water_or_scenery() -> void:
	assert_eq(TRAIL.surface_stretches.size(), 2)
	assert_eq(TRAIL.surface_stretches[0].start, 1350.0)
	assert_eq(TRAIL.surface_stretches[1].start, 2250.0)
	assert_eq(TRAIL.surface_stretches[0].length + TRAIL.surface_stretches[1].length, 900.0)
	assert_true(TRAIL.fords.is_empty())
	assert_false(TRAIL.has_creek())
	assert_eq(TRAIL.tunnels.size(), 1, "approved structure stage")
	assert_true(TRAIL.bridges.is_empty())
	assert_eq(TRAIL.stone_bridges.size(), 1)
	assert_true(TRAIL.talus.is_empty())
	assert_eq(SCATTER.pine_spacing + SCATTER.rock_spacing + SCATTER.post_spacing + SCATTER.broadleaf_spacing, 0.0)
	for stretch: SurfaceStretch in TRAIL.surface_stretches:
		assert_eq(stretch.water_rut_depth, 0.0)
		assert_eq(stretch.surface.id, &"dirt", "sand is explicitly a placeholder at this gate")


func test_gap_reset_runup_landing_width_and_recovery_are_unobstructed() -> void:
	var sampler := RoadSampler.new(CURVE, false, TRAIL)
	assert_true(TRAIL.gap_validation_errors(sampler.length).is_empty())
	assert_true(TRAIL.stone_bridge_validation_errors(sampler.length).is_empty())
	assert_eq(TRAIL.stone_bridges[0].alignment_error(sampler), "")
	assert_eq(TRAIL.checkpoint_distances[0], 730.0)
	assert_eq(TRAIL.checkpoint_distances[1], 980.0)
	assert_eq(TRAIL.road_gaps.size(), 1)
	var gap: RoadGapDef = TRAIL.road_gaps[0]
	assert_eq(gap.landing_start - gap.takeoff_end, 18.0, "owner requested a bigger gap")
	assert_eq(gap.landing_drop, 2.0, "lower landing gives longer flight")
	assert_gte(gap.takeoff_end - TRAIL.checkpoint_distances[0], 120.0, "full acceleration run-up retained")
	assert_almost_eq(TRAIL.road_width_at(gap.landing_start), 9.0, 0.0001)
	for at: float in [730.0, 800.0, gap.takeoff_start, gap.takeoff_end, gap.landing_start, 929.0, 990.0]:
		assert_gt(sampler.forward(at).dot(sampler.forward(800.0)), 0.9999)
		assert_eq(TRAIL.base_surface.id, &"asphalt")
	assert_null(GameState.catalog.find_by_id(&"coastal_highway"), "no invented star times/progress entry")
