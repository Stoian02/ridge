extends GutTest
## Opt-in visual standing water must stay inside the existing wheel ruts.

var trail: TrailDef
var stretch: SurfaceStretch
var sampler: RoadSampler
var profile: RoadProfile
var builder: RutWaterBuilder


func before_each() -> void:
	trail = TrailDef.new()
	trail.painted_lines = false
	trail.undulation_amplitude = 0.0
	stretch = SurfaceStretch.new()
	stretch.start = 20.0
	stretch.length = 160.0
	stretch.surface = preload("res://surfaces/deep_mud.tres")
	stretch.rut_depth = 0.15
	stretch.rut_spacing = 1.6
	stretch.rut_width = 0.9
	stretch.blend_length = 12.0
	stretch.transition_length = 12.0
	trail.surface_stretches = [stretch]
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -220.0))
	sampler = RoadSampler.new(curve, false, trail)
	profile = RoadProfile.new(trail, sampler.length)
	builder = RutWaterBuilder.new()
	add_child_autofree(builder)


func _enable() -> void:
	stretch.water_rut_depth = 0.09
	builder.build(sampler, profile, trail)


func test_water_is_omitted_by_default_and_without_ruts() -> void:
	assert_eq(stretch.water_rut_depth, 0.0)
	builder.build(sampler, profile, trail)
	assert_eq(builder.get_child_count(), 0)
	assert_true(builder.water_rows.is_empty())
	stretch.water_rut_depth = 0.09
	stretch.rut_depth = 0.0
	builder.build(sampler, profile, trail)
	assert_eq(builder.get_child_count(), 0)


func test_puddles_are_in_both_ruts_with_dry_gaps_and_clear_of_transitions() -> void:
	_enable()
	assert_gt(builder.puddle_ranges.size(), 4)
	var last_end := {-1.0: -INF, 1.0: -INF}
	var sides := {}
	for puddle: Vector3 in builder.puddle_ranges:
		var side := signf(puddle.z)
		sides[side] = true
		assert_gte(puddle.x, stretch.start + stretch.blend_length)
		assert_lte(puddle.y, stretch.end() - stretch.blend_length)
		assert_between(puddle.y - puddle.x, 6.0, 12.0)
		assert_gt(puddle.x, last_end[side] + 2.0, "dry gaps, not two endless ribbons")
		last_end[side] = puddle.y
	assert_eq(sides.size(), 2)


func test_flat_water_is_inside_the_bowls_and_below_the_rut_lips() -> void:
	_enable()
	assert_false(builder.water_rows.is_empty())
	for row: Vector4 in builder.water_rows:
		var centre := signf(row.y + row.z) * stretch.rut_spacing * 0.5
		assert_gt(row.y, centre - stretch.rut_width * 0.5)
		assert_lt(row.z, centre + stretch.rut_width * 0.5)
		assert_gt(row.z, row.y)
		var floor := sampler.surface_point(row.x, centre, profile).y
		var lip := sampler.surface_point(row.x, centre + stretch.rut_width * 0.5, profile).y
		assert_almost_eq(row.w - floor, stretch.water_rut_depth, 0.001)
		assert_lt(row.w, lip)
		assert_almost_eq(sampler.surface_point(row.x, row.y, profile).y, row.w, 0.002)
		assert_almost_eq(sampler.surface_point(row.x, row.z, profile).y, row.w, 0.002)


func test_water_is_only_low_cost_translucent_shadowless_geometry() -> void:
	_enable()
	assert_lte(builder.get_child_count(), 3, "puddles share short mesh chunks")
	for child in builder.get_children():
		assert_true(child is MeshInstance3D)
		if child is MeshInstance3D:
			assert_eq(child.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert_lte(child.visibility_range_end, 200.0)
			var material: StandardMaterial3D = child.material_override
			assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
			assert_lt(material.roughness, 0.3)
			var colors: PackedColorArray = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			assert_true(Array(colors).any(func(color: Color) -> bool: return color.a == 0.0), "puddle ends fade")
	assert_true(builder.find_children("*", "CollisionObject3D", true, false).is_empty())


func test_water_never_rises_above_lips_on_banked_undulating_bends() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(20.0, 0.0, -80.0))
	curve.add_point(Vector3(80.0, 0.0, -200.0))
	for i in curve.point_count:
		curve.set_point_tilt(i, 0.08)
	sampler = RoadSampler.new(curve, true, trail)
	trail.undulation_amplitude = 0.05
	profile = RoadProfile.new(trail, sampler.length)
	_enable()
	assert_false(builder.water_rows.is_empty())
	for row: Vector4 in builder.water_rows:
		var centre := signf(row.y + row.z) * stretch.rut_spacing * 0.5
		var floor := sampler.surface_point(row.x, centre, profile).y
		assert_gt(row.w, floor)
		for side: float in [-1.0, 1.0]:
			var lip := sampler.surface_point(row.x, centre + side * stretch.rut_width * 0.5, profile).y
			assert_lt(row.w, lip, "even the low bank contains the water")


func test_overdeep_authoring_is_clamped_and_rebuilding_without_water_clears_it() -> void:
	stretch.water_rut_depth = 2.0
	builder.build(sampler, profile, trail)
	assert_false(builder.water_rows.is_empty())
	for row: Vector4 in builder.water_rows:
		assert_lt(row.w, 0.0, "clamped below the lips")
	stretch.water_rut_depth = 0.0
	builder.build(sampler, profile, trail)
	await wait_process_frames(1)
	assert_eq(builder.get_child_count(), 0)
	assert_true(builder.water_rows.is_empty())
	assert_true(builder.puddle_ranges.is_empty())


func test_same_data_is_deterministic_and_water_stays_inside_the_road_end() -> void:
	stretch.length = 400.0
	_enable()
	var first_rows := builder.water_rows.duplicate()
	var first_ranges := builder.puddle_ranges.duplicate()
	builder.build(sampler, profile, trail)
	assert_eq(builder.water_rows, first_rows)
	assert_eq(builder.puddle_ranges, first_ranges)
	for row: Vector4 in builder.water_rows:
		assert_lt(row.x, sampler.length)
