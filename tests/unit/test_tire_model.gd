extends GutTest

const SLIDE := 0.75


func test_grip_curve_is_zero_without_slip() -> void:
	assert_almost_eq(TireModel.grip_curve(0.0, SLIDE), 0.0, 0.0001)


func test_grip_curve_peaks_at_one() -> void:
	assert_almost_eq(TireModel.grip_curve(1.0, SLIDE), 1.0, 0.0001)


func test_grip_curve_rises_smoothly_before_peak() -> void:
	assert_almost_eq(TireModel.grip_curve(0.5, SLIDE), 0.75, 0.0001)


func test_grip_curve_fades_to_slide_grip() -> void:
	assert_almost_eq(TireModel.grip_curve(2.0, SLIDE), 0.875, 0.0001)
	assert_almost_eq(TireModel.grip_curve(3.0, SLIDE), SLIDE, 0.0001)
	assert_almost_eq(TireModel.grip_curve(10.0, SLIDE), SLIDE, 0.0001)


func test_grip_curve_ignores_sign() -> void:
	assert_almost_eq(TireModel.grip_curve(-0.5, SLIDE), TireModel.grip_curve(0.5, SLIDE), 0.0001)


func test_slip_ratio_uses_min_reference_when_stopped() -> void:
	# Tread moving at 1.5 m/s on a stopped car: 1.5 / 3.0
	assert_almost_eq(TireModel.slip_ratio(1.5, 0.0, 3.0), 0.5, 0.0001)


func test_slip_ratio_at_speed() -> void:
	assert_almost_eq(TireModel.slip_ratio(22.0, 20.0, 3.0), 0.1, 0.0001)
	assert_almost_eq(TireModel.slip_ratio(0.0, 20.0, 3.0), -1.0, 0.0001)


func test_slip_angle_is_zero_when_rolling_straight() -> void:
	assert_almost_eq(TireModel.slip_angle(20.0, 0.0, 3.0), 0.0, 0.0001)


func test_slip_angle_sign_follows_sideways_speed() -> void:
	assert_gt(TireModel.slip_angle(20.0, 2.0, 3.0), 0.0)
	assert_lt(TireModel.slip_angle(20.0, -2.0, 3.0), 0.0)
	assert_almost_eq(TireModel.slip_angle(10.0, 10.0, 3.0), PI / 4.0, 0.0001)


func test_contact_force_is_zero_without_slip() -> void:
	var force := TireModel.contact_force(0.0, 0.0, 3000.0, 0.1, 0.14, SLIDE)
	assert_almost_eq(force.length(), 0.0, 0.0001)


func test_spinning_tire_pushes_forward_with_full_grip_at_peak() -> void:
	var force := TireModel.contact_force(0.1, 0.0, 3000.0, 0.1, 0.14, SLIDE)
	assert_almost_eq(force.x, 3000.0, 0.01)
	assert_almost_eq(force.y, 0.0, 0.01)


func test_braking_tire_pushes_backward() -> void:
	var force := TireModel.contact_force(-0.05, 0.0, 3000.0, 0.1, 0.14, SLIDE)
	assert_lt(force.x, 0.0)


func test_tire_sliding_right_pushes_left() -> void:
	var force := TireModel.contact_force(0.0, 0.14, 3000.0, 0.1, 0.14, SLIDE)
	assert_almost_eq(force.y, -3000.0, 0.01)


func test_combined_slip_shares_one_grip_budget() -> void:
	# At peak slip in both directions the combined slip is sqrt(2) x the peak,
	# so the total force is below the grip force (the friction circle).
	var force := TireModel.contact_force(0.1, 0.14, 3000.0, 0.1, 0.14, SLIDE)
	var expected := TireModel.grip_curve(sqrt(2.0), SLIDE) * 3000.0
	assert_almost_eq(force.length(), expected, 0.01)
	assert_lt(force.length(), 3000.0)


func test_max_longitudinal_force_for_free_wheel_is_limited_by_wheel_inertia() -> void:
	# compliance = 1/300 + 0.3^2 / 1.0 = 0.09333 -> 1.0 / (0.09333 * 0.01) = 1071.43
	var force := TireModel.max_longitudinal_force(1.0, 0.3, 1.0, 300.0, false, 0.01)
	assert_almost_eq(force, 1071.43, 0.1)


func test_max_longitudinal_force_for_held_wheel_is_limited_by_car_mass() -> void:
	var force := TireModel.max_longitudinal_force(1.0, 0.3, 1.0, 300.0, true, 0.01)
	assert_almost_eq(force, 30000.0, 0.1)


func test_max_lateral_force_cancels_sideways_speed_in_one_tick() -> void:
	assert_almost_eq(TireModel.max_lateral_force(-0.5, 300.0, 0.01), 15000.0, 0.1)
