extends GutTest

var stats: CarStats
var drivetrain: Drivetrain


func before_each() -> void:
	stats = CarStats.new()
	drivetrain = Drivetrain.new(stats)


## One tick with the wheels rolling (no slip) at the speed that turns the engine
## at engine_rpm in the current gear.
func _update_at_rpm(engine_rpm: float, throttle: float, brake: float, driven_slip := 0.0) -> void:
	var wheel_speed := engine_rpm / Drivetrain.RPM_PER_RAD_PER_SEC / absf(drivetrain.overall_ratio())
	drivetrain.update(0.01, throttle, brake, wheel_speed, wheel_speed * stats.wheel_radius, driven_slip)


func _assert_wheels(actual: PackedFloat32Array, expected: Array) -> void:
	assert_eq(actual.size(), expected.size())
	for i in expected.size():
		assert_almost_eq(actual[i], float(expected[i]), 0.01, "wheel %d" % i)


func test_torque_curve_hits_points_exactly() -> void:
	assert_almost_eq(Drivetrain.torque_at(4000.0, stats.torque_curve_rpm, stats.torque_curve_nm), 390.0, 0.01)


func test_torque_curve_interpolates_between_points() -> void:
	# Halfway between 2500 rpm (320 Nm) and 4000 rpm (390 Nm).
	assert_almost_eq(Drivetrain.torque_at(3250.0, stats.torque_curve_rpm, stats.torque_curve_nm), 355.0, 0.01)


func test_torque_curve_holds_flat_beyond_the_ends() -> void:
	assert_almost_eq(Drivetrain.torque_at(0.0, stats.torque_curve_rpm, stats.torque_curve_nm), 220.0, 0.01)
	assert_almost_eq(Drivetrain.torque_at(9000.0, stats.torque_curve_rpm, stats.torque_curve_nm), 280.0, 0.01)


func test_traction_factor() -> void:
	assert_almost_eq(Drivetrain.traction_factor(0.1, 0.2, true), 1.0, 0.0001, "below target: full torque")
	assert_almost_eq(Drivetrain.traction_factor(0.3, 0.2, true), 0.5, 0.0001, "halfway to 2x target")
	assert_almost_eq(Drivetrain.traction_factor(5.0, 0.2, true), 0.2, 0.0001, "never below 20%")
	assert_almost_eq(Drivetrain.traction_factor(5.0, 0.2, false), 1.0, 0.0001, "switched off")


func test_first_gear_ratio_includes_final_drive() -> void:
	assert_almost_eq(drivetrain.overall_ratio(), 3.3 * 4.4, 0.001)


func test_throttle_from_standstill_pulls_away_with_clutch_slip() -> void:
	drivetrain.update(0.01, 1.0, 0.0, 0.0, 0.0, 0.0)
	assert_eq(drivetrain.gear, 1)
	assert_almost_eq(drivetrain.rpm, stats.launch_rpm, 0.01)
	assert_gt(drivetrain.drive_torque, 0.0)
	assert_almost_eq(drivetrain.brake_input, 0.0, 0.0001)


func test_upshifts_above_upshift_rpm_and_cuts_torque_while_shifting() -> void:
	_update_at_rpm(7000.0, 1.0, 0.0)
	assert_eq(drivetrain.gear, 2)
	assert_true(drivetrain.is_shifting())
	assert_almost_eq(drivetrain.drive_torque, 0.0, 0.0001)


func test_torque_returns_after_the_shift() -> void:
	_update_at_rpm(7000.0, 1.0, 0.0)
	for i in 20:  # 0.2 s, longer than shift_time
		_update_at_rpm(5000.0, 1.0, 0.0)
	assert_eq(drivetrain.gear, 2)
	assert_false(drivetrain.is_shifting())
	assert_gt(drivetrain.drive_torque, 0.0)


func test_wheelspin_alone_does_not_upshift() -> void:
	# Wheels spinning at 7000 rpm-worth while the car barely moves.
	var spinning := 7000.0 / Drivetrain.RPM_PER_RAD_PER_SEC / absf(drivetrain.overall_ratio())
	drivetrain.update(0.01, 1.0, 0.0, spinning, 2.0, 3.0)
	assert_eq(drivetrain.gear, 1)


func test_downshifts_below_downshift_rpm() -> void:
	drivetrain.gear = 3
	_update_at_rpm(2000.0, 0.5, 0.0)
	assert_eq(drivetrain.gear, 2)


func test_traction_control_trims_torque_while_wheels_spin() -> void:
	stats.traction_slip_target = 0.2  # set here so the car's tuning can move freely
	_update_at_rpm(4000.0, 1.0, 0.0, 0.0)
	var gripping := drivetrain.drive_torque
	_update_at_rpm(4000.0, 1.0, 0.0, 0.3)
	assert_almost_eq(drivetrain.drive_torque, gripping * 0.5, 1.0)


func test_brake_at_standstill_selects_reverse_and_drives_backwards() -> void:
	drivetrain.update(0.01, 0.0, 1.0, 0.0, 0.0, 0.0)
	assert_eq(drivetrain.gear, -1)
	assert_lt(drivetrain.drive_torque, 0.0)
	assert_almost_eq(drivetrain.brake_input, 0.0, 0.0001)


func test_gas_brakes_while_reversing() -> void:
	drivetrain.update(0.01, 0.0, 1.0, 0.0, 0.0, 0.0)       # into reverse
	drivetrain.update(0.01, 1.0, 0.0, -10.0, -3.0, 0.0)    # gas while rolling back at 3 m/s
	assert_eq(drivetrain.gear, -1)
	assert_almost_eq(drivetrain.brake_input, 1.0, 0.0001)


func test_gas_near_standstill_returns_to_first_gear() -> void:
	drivetrain.update(0.01, 0.0, 1.0, 0.0, 0.0, 0.0)
	drivetrain.update(0.01, 1.0, 0.0, 0.0, -0.2, 0.0)
	assert_eq(drivetrain.gear, 1)


func test_brake_at_speed_does_not_select_reverse() -> void:
	_update_at_rpm(4000.0, 0.0, 1.0)
	assert_eq(drivetrain.gear, 1)
	assert_almost_eq(drivetrain.brake_input, 1.0, 0.0001)


func test_direction_change_speed_comes_from_stats() -> void:
	stats.direction_change_speed = 3.0
	drivetrain.update(0.01, 0.0, 1.0, 0.0, 2.0, 0.0)  # braking at 2 m/s
	assert_eq(drivetrain.gear, -1, "below the car's direction-change speed, brake selects reverse")


func test_auto_hold_when_stopped_without_pedals() -> void:
	drivetrain.update(0.01, 0.0, 0.0, 0.0, 0.1, 0.0)
	assert_almost_eq(drivetrain.brake_input, 1.0, 0.0001)


func test_no_auto_hold_while_rolling() -> void:
	drivetrain.update(0.01, 0.0, 0.0, 0.0, 5.0, 0.0)
	assert_almost_eq(drivetrain.brake_input, 0.0, 0.0001)


func test_rev_limiter_cuts_torque_at_redline() -> void:
	drivetrain.gear = 6
	_update_at_rpm(7300.0, 1.0, 0.0)
	assert_almost_eq(drivetrain.drive_torque, 0.0, 0.0001)


func test_engine_braking_opposes_rolling_when_off_throttle() -> void:
	_update_at_rpm(4000.0, 0.0, 0.0)
	assert_lt(drivetrain.drive_torque, 0.0)


func test_split_torque_awd() -> void:
	_assert_wheels(Drivetrain.split_torque(1000.0, CarStats.DriveType.AWD, 0.4), [200, 200, 300, 300])


func test_split_torque_fwd_and_rwd() -> void:
	_assert_wheels(Drivetrain.split_torque(1000.0, CarStats.DriveType.FWD, 0.4), [500, 500, 0, 0])
	_assert_wheels(Drivetrain.split_torque(1000.0, CarStats.DriveType.RWD, 0.4), [0, 0, 500, 500])


func test_split_brake_uses_front_bias() -> void:
	_assert_wheels(Drivetrain.split_brake(1000.0, 0.65), [325, 325, 175, 175])
