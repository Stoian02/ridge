extends GutTest
## Crawl zones are local to authored obstacles; the existing levels' driver
## behavior and the profile-free helper keep their previous speed choices.

var trail: TrailDef
var sampler: RoadSampler
var car: Car


func before_each() -> void:
	trail = TrailDef.new()
	var curve := Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -500.0))
	sampler = RoadSampler.new(curve, false, trail)
	car = Car.new()
	car.stats = preload("res://car/offroad_4x4.tres")
	car.grip_table = preload("res://surfaces/grip_table.tres")
	autofree(car)


func _driver(with_profile: bool = true) -> TrailDriver:
	return TrailDriver.new(car, sampler, RoadProfile.new(trail, sampler.length) if with_profile else null)


func _plain_profile_speed() -> float:
	var grip := trail.base_surface.grip * car.grip_table.multiplier(car.stats.archetype, trail.base_surface.id)
	return TrailDriver.MAX_SPEED * sqrt(minf(grip, 1.0))


func _assert_zone(driver: TrailDriver, distance: float, expected: bool) -> void:
	assert_true(driver.has_method("crawl_zone_ahead"), "driver exposes authored obstacle crawl zones")
	if driver.has_method("crawl_zone_ahead"):
		assert_eq(driver.call("crawl_zone_ahead", distance), expected, "crawl zone at %.1f m" % distance)


func test_no_profile_and_plain_roads_keep_existing_speeds() -> void:
	for with_profile: bool in [false, true]:
		var driver := _driver(with_profile)
		_assert_zone(driver, 100.0, false)
		var expected: float = _plain_profile_speed() if with_profile else TrailDriver.MAX_SPEED
		assert_almost_eq(driver.target_speed(100.0), expected, 0.0001)


func test_step_zone_includes_approach_and_the_complete_recovery_ramp() -> void:
	var step := RockStepDef.new()
	step.distance = 100.0
	step.ramp_length = 6.0
	trail.rock_steps = [step]
	var driver := _driver()
	_assert_zone(driver, 79.9, false)
	_assert_zone(driver, 80.0, true)
	_assert_zone(driver, 100.0, true)
	_assert_zone(driver, 111.0, true)
	_assert_zone(driver, 111.1, false)
	assert_almost_eq(driver.target_speed(90.0), 4.5, 0.0001, "crawl below the normal minimum speed")
	assert_almost_eq(driver.target_speed(140.0), _plain_profile_speed(), 0.0001)


func test_boulder_and_talus_zones_include_all_of_each_field() -> void:
	var boulders := BoulderFieldDef.new()
	boulders.start = 120.0
	boulders.length = 20.0
	trail.boulder_fields = [boulders]
	var talus := TalusDef.new()
	talus.start = 200.0
	talus.length = 50.0
	trail.talus = [talus]
	var driver := _driver()
	for distance: float in [100.0, 130.0, 145.0, 180.0, 220.0, 255.0]:
		_assert_zone(driver, distance, true)
	for distance: float in [99.9, 145.1, 179.9, 255.1]:
		_assert_zone(driver, distance, false)


func test_ford_zone_includes_both_bank_approaches() -> void:
	var ford := FordDef.new()
	ford.distance = 300.0
	ford.channel_width = 16.0
	ford.bank_run = 10.0
	trail.fords = [ford]
	var driver := _driver()
	_assert_zone(driver, 261.9, false)
	for distance: float in [262.0, 282.0, 300.0, 318.0, 323.0]:
		_assert_zone(driver, distance, true)
	_assert_zone(driver, 323.1, false)
	assert_almost_eq(driver.target_speed(275.0), 4.5, 0.0001)


func test_narrow_shelf_slows_before_its_taper_and_stays_slow_until_clear() -> void:
	trail.width_stretches = [Vector4(200.0, 100.0, 4.5, 0.0)]
	var driver := _driver()
	_assert_zone(driver, 179.9, false)
	for distance: float in [180.0, 200.0, 250.0, 300.0, 305.0]:
		_assert_zone(driver, distance, true)
		assert_almost_eq(driver.target_speed(distance), 4.5, 0.0001, "caution includes approach and exit")
	_assert_zone(driver, 305.1, false)
	assert_almost_eq(driver.target_speed(330.0), _plain_profile_speed(), 0.0001)


func test_wide_profile_and_profile_free_helper_keep_legacy_speed() -> void:
	trail.width_stretches = [Vector4(200.0, 100.0, 6.0, 0.0)]
	var driver := _driver()
	_assert_zone(driver, 250.0, false)
	assert_almost_eq(driver.target_speed(250.0), _plain_profile_speed(), 0.0001)
	trail.width_stretches = [Vector4(200.0, 100.0, 4.5, 0.0)]
	var without_profile := _driver(false)
	_assert_zone(without_profile, 250.0, false)
	assert_almost_eq(without_profile.target_speed(250.0), TrailDriver.MAX_SPEED, 0.0001)
