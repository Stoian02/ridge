extends GutTest

var profile: VehicleWaterProfile
var state: VehicleWaterState


func before_each() -> void:
	profile = VehicleWaterProfile.new()
	state = VehicleWaterState.new()


func test_intake_requires_continuous_submersion_and_ignores_dry_splashes() -> void:
	state.step(2.50, profile, 0.0, true, -0.01)
	assert_false(state.stalled)
	state.step(0.01, profile, 0.0, true, 0.0)
	assert_eq(state.intake_seconds, 0.0)
	state.step(2.99, profile, 0.0, true, -0.01)
	assert_false(state.stalled)
	state.step(0.01, profile, 0.0, true, -0.01)
	assert_true(state.stalled)
	assert_eq(state.torque_scale, 0.0)
	assert_eq(state.flooding, 0.0, "intake and body immersion are independent")


func test_three_second_stall_boundary_at_60_and_120_hz() -> void:
	for hz: int in [60, 120]:
		state.reset()
		var delta := 1.0 / hz
		for tick in 3 * hz - 1:
			state.step(delta, profile, 0.0, true, -0.01)
			assert_false(state.stalled, "%d Hz tick %d is before three seconds" % [hz, tick + 1])
		state.step(delta, profile, 0.0, true, -0.01)
		assert_true(state.stalled, "%d Hz stalls at exactly three seconds" % hz)
		assert_eq(state.torque_scale, 0.0)


func test_restart_hysteresis_countdown_and_torque_ramp() -> void:
	state.step(3.00, profile, 1.0, true, -1.0)
	state.step(0.90, profile, 0.5, true, 0.05)
	assert_true(state.restarting)
	state.step(0.10, profile, 0.5, true, 0.049)
	assert_false(state.restarting)
	assert_eq(state.restart_seconds, 0.0)
	state.step(1.00, profile, 0.5, true, 0.05)
	assert_false(state.stalled)
	assert_almost_eq(state.torque_scale, 0.0, 0.000001)
	state.step(0.25, profile, 0.5, true, 0.05)
	assert_almost_eq(state.torque_scale, 0.5, 0.000001)
	state.step(0.25, profile, 0.5, true, 0.05)
	assert_eq(state.torque_scale, 1.0)
	state.step(3.00, profile, 0.5, true, -0.01)
	assert_true(state.stalled)
	assert_eq(state.torque_scale, 0.0, "a second stall immediately cancels restart torque")


func test_leaving_every_water_column_counts_as_clear() -> void:
	state.step(3.00, profile, 0.0, true, -0.1)
	state.step(1.00, profile, 0.0, false, -100.0)
	assert_false(state.stalled)
	assert_false(state.intake_at_risk)
	assert_eq(state.intake_clearance, INF)


func test_flooding_grace_bobbing_and_drain_are_independent_of_intake() -> void:
	state.step(3.0, profile, 0.65, false, 100.0)
	assert_eq(state.flooding, 0.0)
	state.step(4.0, profile, 0.65, false, 100.0)
	assert_almost_eq(state.flooding, 0.5, 0.000001)
	assert_false(state.stalled, "a high snorkel does not prevent flooding")
	state.step(20.0, profile, 0.64, false, 100.0)
	assert_almost_eq(state.flooding, 0.5, 0.000001, "bobbing neither fills nor drains")
	state.step(0.5, profile, 0.0, false, 100.0)
	state.step(0.1, profile, 0.5, false, 100.0)
	assert_eq(state.dry_seconds, 0.0)
	assert_almost_eq(state.deep_seconds, 7.0, 0.000001)
	state.step(1.0, profile, 0.02, false, 100.0)
	assert_eq(state.deep_seconds, 0.0)
	assert_almost_eq(state.flooding, 0.5, 0.000001)
	state.step(6.0, profile, 0.0, false, 100.0)
	assert_eq(state.flooding, 0.0)


func test_large_steps_only_consume_the_time_beyond_grace_and_dry_delay() -> void:
	state.step(7.0, profile, 1.0, false, 0.0)
	assert_almost_eq(state.flooding, 0.5, 0.000001)
	state.step(4.0, profile, 0.0, false, 0.0)
	assert_almost_eq(state.flooding, 0.25, 0.000001)


func test_pause_and_reset_do_not_leak_shared_state() -> void:
	state.step(8.0, profile, 1.0, true, -1.0)
	var other := VehicleWaterState.new()
	assert_eq(other.flooding, 0.0)
	assert_false(other.stalled)
	state.step(0.0, profile, 0.0, false, 0.0)
	assert_eq(state.body_immersion, 1.0)
	assert_eq(state.deep_seconds, 8.0)
	assert_true(state.stalled)
	state.reset()
	assert_eq(state.flooding, 0.0)
	assert_eq(state.deep_seconds, 0.0)
	assert_eq(state.dry_seconds, 0.0)
	assert_eq(state.intake_seconds, 0.0)
	assert_eq(state.restart_seconds, 0.0)
	assert_eq(state.intake_clearance, INF)
	assert_eq(state.torque_scale, 1.0)
	assert_false(state.stalled)
	assert_false(state.sinking)


func test_sinking_warning_has_hysteresis_and_does_not_survive_leaving_water() -> void:
	state.flooding = 0.20
	state.step(0.01, profile, 0.70, false, 0.0)
	assert_true(state.sinking)
	state.flooding = 0.16
	state.step(0.01, profile, 0.70, false, 0.0)
	assert_true(state.sinking)
	state.flooding = 0.13
	state.step(0.01, profile, 0.70, false, 0.0)
	assert_false(state.sinking)
	state.flooding = 1.0
	state.step(0.01, profile, 0.0, false, 0.0)
	assert_false(state.sinking)


func test_configured_profiles_have_only_the_approved_water_starting_values() -> void:
	var rally: CarStats = load("res://car/rally_car.tres")
	var tuned: CarStats = load("res://car/rally_car_tuned.tres")
	var offroad: CarStats = load("res://car/offroad_4x4.tres")
	assert_not_null(rally.water_profile)
	assert_same(rally.water_profile, tuned.water_profile)
	assert_eq(rally.water_profile.intake_local_position, Vector3(0.45, 0.15, -1.50))
	assert_eq(offroad.water_profile.intake_local_position, Vector3(0.95, 1.10, -0.90))
	assert_eq(rally.water_profile.body_linear_drag, Vector3(50.0, 80.0, 40.0))
	assert_eq(rally.water_profile.body_quadratic_drag, Vector3(350.0, 500.0, 220.0))
	assert_eq(offroad.water_profile.body_linear_drag, Vector3(65.0, 105.0, 55.0))
	assert_eq(offroad.water_profile.body_quadratic_drag, Vector3(450.0, 650.0, 300.0))
	assert_eq(rally.water_profile.wheel_quadratic_drag, 8.0)
	assert_eq(offroad.water_profile.wheel_quadratic_drag, 10.0)
	for stats: CarStats in [rally, tuned, offroad]:
		assert_eq(stats.water_profile.stall_submerged_seconds, 3.0)
		assert_eq(stats.water_profile.fresh_buoyancy_ratio, 1.15)
		assert_eq(stats.water_profile.flooded_buoyancy_ratio, 0.35)
		assert_eq(stats.water_profile.flood_grace_seconds, 3.0)
		assert_eq(stats.water_profile.flood_fill_seconds, 8.0)
		assert_eq(stats.water_profile.flood_drain_seconds, 12.0)
	assert_null(CarStats.new().water_profile, "unconfigured fixture cars retain their old dry path")


func test_stalled_brakes_retain_both_gears_without_engine_or_shifts() -> void:
	var drive := Drivetrain.new(CarStats.new())
	for selected: int in [1, -1]:
		drive.gear = selected
		drive.update_stalled(0.0, 0.8, 0.0)
		assert_eq(drive.gear, selected)
		assert_eq(drive.rpm, 0.0)
		assert_eq(drive.drive_torque, 0.0)
		assert_eq(drive.brake_input, 0.8)
		drive.update_stalled(0.0, 0.0, 0.0)
		assert_eq(drive.brake_input, 1.0, "normal auto hold still works")
		drive.update_stalled(0.0, 0.0, 10.0)
		assert_eq(drive.drive_torque, 0.0, "no engine braking")
	drive.gear = -1
	drive.update_stalled(0.7, 0.0, -3.0)
	assert_eq(drive.brake_input, 0.7, "reverse gas-as-brake remains available too")
	drive.reset()
	drive.update(0.01, 1.0, 0.0, 100.0, 20.0, 0.0)
	var shifting := drive.is_shifting()
	var selected := drive.gear
	for tick in 100:
		drive.update_stalled(1.0, 0.0, 20.0)
	assert_eq(drive.is_shifting(), shifting)
	assert_eq(drive.gear, selected)


func test_restart_torque_limit_does_not_override_tc_throttle_or_limiter() -> void:
	var stats := CarStats.new()
	var drive := Drivetrain.new(stats)
	drive.update(0.01, 1.0, 0.0, 0.0, 0.0, 0.0)
	var full := drive.drive_torque
	drive.update(0.01, 1.0, 0.0, 0.0, 0.0, 0.0, 0.25)
	assert_almost_eq(drive.drive_torque, full * 0.25, 0.001)
	drive.update(0.01, 1.0, 0.0, 0.0, 0.0, 5.0, 0.25)
	assert_almost_eq(drive.drive_torque, full * 0.25 * 0.20, 0.001)
	drive.update(0.01, 0.0, 0.0, 10.0, 4.0, 0.0, 0.25)
	assert_lt(drive.drive_torque, 0.0, "restart does not inject torque after throttle release")
	drive.gear = 6
	drive.update(0.01, 1.0, 0.0, 10000.0, 70.0, 0.0, 0.25)
	assert_eq(drive.drive_torque, 0.0, "rev limiter still wins")
