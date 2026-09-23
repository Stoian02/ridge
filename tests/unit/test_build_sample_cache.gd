extends GutTest

const TRAIL := preload("res://levels/rock_canyon/rock_canyon_trail.tres")
const CURVE := preload("res://levels/rock_canyon/rock_canyon_curve.tres")


func test_build_cache_preserves_exact_frames_and_profile_heights() -> void:
	var reference := RoadSampler.new(CURVE, true, TRAIL)
	var cached := RoadSampler.new(CURVE, true, TRAIL)
	var profile := RoadProfile.new(TRAIL, reference.length)
	var cached_profile := RoadProfile.new(TRAIL, reference.length)
	cached.cache_build_samples(true)
	cached_profile.cache_build_samples(true)
	for distance: float in [-1.0, 0.0, 299.99, 320.12345678, 758.02, 1290.0, 1500.0, 1580.5, 1685.0, 1888.0, 1900.0, 2200.0]:
		for repeat in 2:
			assert_eq(cached.position(distance), reference.position(distance))
			assert_eq(cached.forward(distance), reference.forward(distance))
			assert_eq(cached.up(distance), reference.up(distance))
			assert_eq(cached.right(distance), reference.right(distance))
			for lateral: float in [-5.0, -2.25, 0.0, 2.25, 5.0]:
				assert_eq(cached_profile.height(distance, lateral), profile.height(distance, lateral))
	cached.cache_build_samples(false)
	cached_profile.cache_build_samples(false)
	assert_true(cached._positions.is_empty())
	assert_true(cached._forwards.is_empty())
	assert_true(cached._ups.is_empty())
	assert_true(cached._rights.is_empty())
	assert_true(cached_profile._longitudinal.is_empty())
	assert_true(cached_profile._height_samples.is_empty())
	assert_true(cached_profile._height_profiles.is_empty())


func test_disabling_cache_restores_live_queries_after_an_edit() -> void:
	var trail: TrailDef = TRAIL.duplicate(true)
	var curve: Curve3D = CURVE.duplicate(true)
	var sampler := RoadSampler.new(curve, true, trail)
	var profile := RoadProfile.new(trail, sampler.length)
	sampler.cache_build_samples(true)
	profile.cache_build_samples(true)
	var before := sampler.position(0.0)
	var old_height := profile.longitudinal_height(20.0)
	sampler.cache_build_samples(false)
	profile.cache_build_samples(false)
	curve.set_point_position(0, curve.get_point_position(0) + Vector3.UP)
	trail.undulation_amplitude += 0.5
	assert_ne(sampler.position(0.0), before)
	assert_ne(profile.longitudinal_height(20.0), old_height)
	sampler.cache_build_samples(true)
	profile.cache_build_samples(true)
	assert_eq(sampler.position(0.0), curve.sample_baked(0.0, true))
	assert_eq(profile.longitudinal_height(20.0), RoadProfile.new(trail, sampler.length).longitudinal_height(20.0))


func test_flat_height_snapshots_match_every_authored_road_row() -> void:
	for id: String in ["rally_road", "muddy_valley", "frozen_pass", "rock_canyon"]:
		var trail: TrailDef = load("res://levels/%s/%s_trail.tres" % [id, id])
		var curve: Curve3D = load("res://levels/%s/%s_curve.tres" % [id, id])
		var profile := RoadProfile.new(trail, curve.get_baked_length())
		var cached := RoadProfile.new(trail, curve.get_baked_length())
		cached.cache_build_samples(true)
		for distance: float in RoadBuilder.row_distances(profile.road_length, profile, trail):
			for lateral: float in [-7.0, -4.0, -0.775, 0.0, 0.775, 4.0, 7.0]:
				assert_eq(cached.height(distance, lateral), profile.height(distance, lateral), "%s row %.5f" % [id, distance])
			for shoulder: bool in [false, true]:
				for color: Color in [trail.asphalt_color, trail.patch_color, trail.shoulder_color]:
					assert_eq(cached.surface_color(distance, color, shoulder), profile.surface_color(distance, color, shoulder))
		cached.cache_build_samples(false)
		assert_true(cached._road_color_weights.is_empty())
		assert_true(cached._shoulder_color_weights.is_empty())
