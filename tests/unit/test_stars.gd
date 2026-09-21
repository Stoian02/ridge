extends GutTest

var level: LevelDef


func before_each() -> void:
	level = LevelDef.new()
	level.two_star_time = 85.0
	level.three_star_time = 74.0


func test_any_finish_earns_one_star() -> void:
	assert_eq(Stars.for_time(140.0, level), 1)


func test_under_the_two_star_time_earns_two() -> void:
	assert_eq(Stars.for_time(84.9, level), 2)


func test_under_the_three_star_time_earns_three() -> void:
	assert_eq(Stars.for_time(73.9, level), 3)


func test_a_time_exactly_on_a_target_does_not_beat_it() -> void:
	assert_eq(Stars.for_time(85.0, level), 1, "exactly the two-star time")
	assert_eq(Stars.for_time(74.0, level), 2, "exactly the three-star time")


func test_no_finish_earns_nothing() -> void:
	assert_eq(Stars.for_time(-1.0, level), 0)


func test_rock_canyon_uses_owner_approved_time_boundaries() -> void:
	var canyon: LevelDef = load("res://levels/rock_canyon/rock_canyon_level.tres")
	assert_eq(Stars.for_time(144.99, canyon), 3, "under 2:25")
	assert_eq(Stars.for_time(145.0, canyon), 2, "exactly 2:25 is not three stars")
	assert_eq(Stars.for_time(179.99, canyon), 2, "under 3:00")
	assert_eq(Stars.for_time(180.0, canyon), 1, "exactly 3:00 is not two stars")
