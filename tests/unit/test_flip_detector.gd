extends GutTest

const ON_ITS_ROOF := Vector3.DOWN
const ON_ITS_SIDE := Vector3.RIGHT

var detector: FlipDetector


func before_each() -> void:
	detector = FlipDetector.new()


func _hold(seconds: float, up: Vector3, speed: float) -> bool:
	var result := false
	var steps := roundi(seconds * 10.0)
	for i in steps:
		result = detector.update(0.1, up, speed)
	return result


func test_upright_car_is_never_flipped() -> void:
	assert_false(_hold(5.0, Vector3.UP, 0.0))


func test_car_on_its_roof_triggers_after_two_seconds() -> void:
	assert_false(_hold(1.9, ON_ITS_ROOF, 0.0), "not yet at 1.9 s")
	assert_true(_hold(0.1, ON_ITS_ROOF, 0.0), "flipped at 2 s")


func test_car_on_its_side_counts_as_flipped() -> void:
	assert_true(_hold(2.0, ON_ITS_SIDE, 0.5))


func test_a_steep_but_driveable_tilt_does_not_count() -> void:
	var tilted_60 := Vector3.UP.rotated(Vector3.FORWARD, deg_to_rad(60.0))
	assert_false(_hold(5.0, tilted_60, 0.0))


func test_moving_car_is_not_stuck() -> void:
	assert_false(_hold(5.0, ON_ITS_ROOF, 6.0), "still sliding or tumbling")


func test_recovering_resets_the_timer() -> void:
	_hold(1.5, ON_ITS_ROOF, 0.0)
	_hold(0.1, Vector3.UP, 0.0)
	assert_false(_hold(1.5, ON_ITS_ROOF, 0.0), "the 2 s starts again after recovering")


func test_reset_clears_the_timer() -> void:
	_hold(1.9, ON_ITS_ROOF, 0.0)
	detector.reset()
	assert_false(_hold(0.5, ON_ITS_ROOF, 0.0))
