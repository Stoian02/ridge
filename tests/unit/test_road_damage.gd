extends GutTest

const TRAIL := preload("res://levels/rock_canyon/rock_canyon_trail.tres")
const CURVE := preload("res://levels/rock_canyon/rock_canyon_curve.tres")


func test_authored_damage_is_repeatable_and_stays_inside_its_section() -> void:
	for section: RoadDamageDef in TRAIL.damage_sections:
		var holes := section.generate(TRAIL)
		assert_eq(holes, section.generate(TRAIL))
		assert_gt(holes.size(), 50)
		for hole: Vector4 in holes:
			assert_gte(hole.x - hole.z, section.start - 0.0001)
			assert_lte(hole.x + hole.z, section.end() + 0.0001)
			assert_lte(absf(hole.y) + hole.z, TRAIL.road_width_at(hole.x) * 0.5)
			assert_between(hole.w, 0.0, section.depth_range.y)


func test_asphalt_damage_becomes_more_frequent_larger_and_deeper() -> void:
	var section: RoadDamageDef = TRAIL.damage_sections[0]
	var early := Vector4.ZERO  # count, summed radius, summed depth, deepest
	var late := Vector4.ZERO
	for hole: Vector4 in section.generate(TRAIL):
		if hole.x < section.start + section.length * 0.5:
			early += Vector4(1, hole.z, hole.w, 0)
			early.w = maxf(early.w, hole.w)
		else:
			late += Vector4(1, hole.z, hole.w, 0)
			late.w = maxf(late.w, hole.w)
	assert_gt(late.x, early.x)
	assert_gt(late.y / late.x, early.y / early.x)
	assert_gt(late.z / late.x, early.z / early.x)
	assert_gt(late.w, 0.22, "some substantial holes, mixed with small ones")


func test_tuning_the_opening_does_not_move_later_potholes_or_undulation() -> void:
	var original: TrailDef = TRAIL.duplicate(true)
	original.damage_sections = []
	original.rollers = []
	var before := RoadProfile.new(original, CURVE.get_baked_length())
	var after := RoadProfile.new(TRAIL, CURVE.get_baked_length())
	var later := after.potholes.filter(func(h: Vector4) -> bool: return h.x >= 560.0)
	assert_eq(later, before.potholes, "the wash retains its exact seeded obstacles")
	for distance: float in range(560, 2170, 3):
		assert_eq(after.height(distance, 0.8), before.height(distance, 0.8))
	assert_eq(after.height(15.0, 0.0), before.height(15.0, 0.0), "clear starting gate")


func test_dirt_has_mixed_deep_holes_and_raised_bumps_then_eases_into_mud() -> void:
	var section: RoadDamageDef = TRAIL.damage_sections[1]
	var shallow := 0
	var deep := 0
	var small := 0
	var big := 0
	for hole: Vector4 in section.generate(TRAIL):
		shallow += int(hole.w < 0.16)
		deep += int(hole.w > 0.3)
		small += int(hole.z < 0.8)
		big += int(hole.z > 1.2)
	assert_gt(shallow, 0)
	assert_gt(deep, 0)
	assert_gt(small, 0)
	assert_gt(big, 0)
	var profile := RoadProfile.new(TRAIL, CURVE.get_baked_length())
	assert_gt(profile.roller_height(262.0), 0.3)
	assert_eq(profile.rough_height(300.0, 0.8), 0.0)
	assert_eq(profile.roller_height(300.0), 0.0)
	assert_eq(profile.surface_at(303.0).id, &"mud")


func test_zero_density_or_length_is_safe_and_constant_density_is_supported() -> void:
	var section := RoadDamageDef.new()
	section.density = Vector2.ZERO
	assert_true(section.generate(TRAIL).is_empty())
	section.density = Vector2(10, 10)
	assert_eq(section.generate(TRAIL).size(), 10)
	section.length = 0.0
	assert_true(section.generate(TRAIL).is_empty())


func test_shadow_optimization_is_confined_to_the_ground_supported_opening() -> void:
	assert_false(TRAIL.casts_shadow(0.0, 100.0))
	assert_false(TRAIL.casts_shadow(220.0, 300.0))
	assert_false(TRAIL.casts_shadow(400.0, 500.0))
	assert_true(TRAIL.casts_shadow(550.0, 600.0), "a straddling chunk keeps its shadows")
	assert_true(TRAIL.casts_shadow(1200.0, 1300.0))
	assert_true(TrailDef.new().casts_shadow(0.0, 100.0), "other tracks keep their rendering")
