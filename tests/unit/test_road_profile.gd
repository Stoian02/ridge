extends GutTest

var def: TrailDef


func before_each() -> void:
	def = TrailDef.new()


func _rough_def() -> TrailDef:
	var rough := TrailDef.new()
	rough.undulation_amplitude = 0.0
	rough.rough_sections = [Vector3(100.0, 150.0, 20.0)]  # 30 potholes
	rough.pothole_clusters = [Vector2(400.0, 4.0)]
	return rough


func test_undulation_stays_within_its_amplitude() -> void:
	var profile := RoadProfile.new(def, 1500.0)
	var peak := 0.0
	var distance := 0.0
	while distance <= 1500.0:
		peak = maxf(peak, absf(profile.undulation(distance)))
		distance += 0.5
	assert_lte(peak, def.undulation_amplitude + 0.0001)
	assert_gt(peak, def.undulation_amplitude * 0.5, "and it actually undulates")


func test_plain_road_has_no_rough_height() -> void:
	var profile := RoadProfile.new(def, 1500.0)
	assert_almost_eq(profile.rough_height(500.0, 1.0), 0.0, 0.0001)
	assert_true(profile.potholes.is_empty())


func test_potholes_land_inside_their_section_and_on_the_asphalt() -> void:
	var profile := RoadProfile.new(_rough_def(), 1500.0)
	assert_eq(profile.potholes.size(), 34, "30 in the section + 4 in the cluster")
	for pothole in profile.potholes:
		var in_section := pothole.x >= 103.0 and pothole.x <= 247.0
		var in_cluster := pothole.x >= 392.0 and pothole.x <= 408.0
		assert_true(in_section or in_cluster, "pothole at %.1f m" % pothole.x)
		assert_lte(absf(pothole.y) + pothole.z, 3.5 + 0.0001, "inside the road edges")


func test_a_pothole_is_as_deep_as_its_depth_at_the_centre() -> void:
	var profile := RoadProfile.new(_rough_def(), 1500.0)
	var pothole := profile.potholes[0]
	var nearby_overlap := 0.0
	for other in profile.potholes.slice(1):
		nearby_overlap += RoughShapes.pothole(Vector2(pothole.x - other.x, pothole.y - other.y).length(), other.z, other.w)
	assert_almost_eq(profile.pothole_height(pothole.x, pothole.y), -pothole.w + nearby_overlap, 0.0001)


func test_the_same_seed_gives_the_same_road() -> void:
	var a := RoadProfile.new(_rough_def(), 1500.0)
	var b := RoadProfile.new(_rough_def(), 1500.0)
	assert_eq(a.potholes, b.potholes)
	assert_eq(a.patches, b.patches)


func test_a_different_seed_gives_a_different_road() -> void:
	var other := _rough_def()
	other.seed = 99
	assert_ne(RoadProfile.new(_rough_def(), 1500.0).potholes, RoadProfile.new(other, 1500.0).potholes)


func test_patches_are_raised() -> void:
	var profile := RoadProfile.new(_rough_def(), 1500.0)
	assert_eq(profile.patches.size(), 12, "one per 12 m of the 150 m section")
	var patch := profile.patches[0]
	var centre := patch.get_center()
	assert_true(profile.is_patch(centre.x, centre.y))
	assert_false(profile.is_patch(600.0, 0.0))


func test_jump_crest_reaches_its_height_then_drops() -> void:
	def.jumps = [Vector3(450.0, 1.2, 12.0)]
	var profile := RoadProfile.new(def, 1500.0)
	# The jump starts at 444 m; its crest is 70% of the way along, at 452.4 m.
	assert_almost_eq(profile.jump_height(444.0), 0.0, 0.0001)
	assert_almost_eq(profile.jump_height(452.4), 1.2, 0.0001)
	assert_almost_eq(profile.jump_height(456.0), 0.0, 0.0001)
	assert_gt(profile.jump_height(448.0), 0.0)


func test_detail_ranges_cover_rough_ground_and_merge() -> void:
	var rough := _rough_def()
	rough.rough_sections.append(Vector3(240.0, 30.0, 10.0))  # overlaps the first section
	var profile := RoadProfile.new(rough, 1500.0)
	assert_eq(profile.detail_ranges, [Vector2(100.0, 270.0), Vector2(390.0, 410.0)] as Array[Vector2])
	assert_true(profile.in_detail_range(200.0))
	assert_true(profile.in_detail_range(400.0))
	assert_false(profile.in_detail_range(320.0))
