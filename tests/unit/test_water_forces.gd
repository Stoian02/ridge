extends GutTest


func test_caps_are_continuous_and_clipped_against_bed_and_footprint() -> void:
	assert_eq(WaterForces.probe_fraction(1.0, 1.0, 0.0, -5.0), 0.0)
	assert_almost_eq(WaterForces.probe_fraction(0.0, 1.0, 0.0, -5.0), 0.5, 0.000001)
	assert_eq(WaterForces.probe_fraction(-1.0, 1.0, 0.0, -5.0), 1.0)
	assert_almost_eq(WaterForces.probe_fraction(-1.0, 1.0, 0.0, -1.0), 0.5, 0.000001)
	assert_eq(WaterForces.probe_fraction(-2.0, 1.0, 0.0, -1.0), 0.0)
	assert_eq(WaterForces.probe_fraction(0.0, 1.0, 0.0, 0.0), 0.0)
	assert_eq(WaterForces.probe_fraction(0.0, 1.0, 0.0, -5.0, 0.0), 0.0)
	assert_almost_eq(WaterForces.probe_fraction(0.0, 1.0, 0.0, -5.0, 0.5), 0.25, 0.000001)
	assert_eq(WaterForces.probe_fraction(0.0, 0.0, 1.0, -1.0), 0.0)
	assert_almost_eq(WaterForces.wheel_fraction(0.0, 0.33, 0.0, -1.0), 0.5, 0.000001)
	assert_eq(WaterForces.wheel_fraction(0.0, 0.33, 0.0, 0.0), 0.0)


func test_probes_are_eight_equal_weight_spheres_in_approved_positions() -> void:
	var positions := WaterForces.probe_positions(Vector3(2.0, 1.0, 4.0))
	assert_eq(positions.size(), 8)
	for point in positions:
		assert_almost_eq(absf(point.x), 0.7, 0.000001)
		assert_almost_eq(absf(point.z), 1.28, 0.000001)
		assert_true(is_equal_approx(point.y, -0.2) or is_equal_approx(point.y, 0.4))
	var mass := 1300.0
	for ratio: float in [1.15, 0.35]:
		var sum := 0.0
		for point in positions:
			sum += mass * 9.8 * ratio * WaterForces.probe_fraction(point.y, 0.3, 5.0, -5.0) / 8.0
		assert_almost_eq(sum, mass * 9.8 * ratio, 0.001)


func test_drag_axes_remain_horizontal_when_pitched_rolled_or_inverted() -> void:
	for rotation: Vector3 in [Vector3.ZERO, Vector3(PI / 2.0, 0.0, 0.0), Vector3(0.0, 0.0, PI), Vector3(0.7, 1.2, 0.9)]:
		var axes := WaterForces.drag_axes(Basis.from_euler(rotation))
		assert_almost_eq(axes.x.length(), 1.0, 0.00001)
		assert_almost_eq(axes.z.length(), 1.0, 0.00001)
		assert_almost_eq(axes.x.y, 0.0, 0.00001)
		assert_almost_eq(axes.z.y, 0.0, 0.00001)
		assert_eq(axes.y, Vector3.UP)
		assert_almost_eq(axes.x.dot(axes.z), 0.0, 0.00001)
		var drag := WaterForces.new()
		drag.begin(0.001, Basis.IDENTITY)
		drag.add_axis(axes.z, 40.0, Vector3.ZERO, 40.0, 220.0, 1.0)
		drag.finish(1.0 / 60.0)
		assert_eq(drag.force.y, 0.0, "horizontal motion has no speed-generated lift")


func test_zero_relative_translation_is_zero_drag_and_current_reverses_sign() -> void:
	var drag := WaterForces.new()
	drag.begin(0.001, Basis.IDENTITY)
	drag.add_axis(Vector3.RIGHT, 0.0, Vector3.ZERO, 50.0, 350.0, 1.0)
	drag.finish(1.0 / 120.0)
	assert_eq(drag.force, Vector3.ZERO)
	assert_eq(drag.torque, Vector3.ZERO)
	for speed: float in [-0.75, 0.75]:
		drag.begin(0.001, Basis.IDENTITY)
		drag.add_axis(Vector3.RIGHT, speed, Vector3.ZERO, 50.0, 350.0, 1.0)
		drag.finish(1.0 / 120.0)
		assert_lt(drag.force.x * speed, 0.0)


func test_combined_probe_and_wheel_drag_dissipates_six_dof_energy_at_60_and_120_hz() -> void:
	var mass := 1450.0
	var inertia := Vector3(2400.0, 2700.0, 550.0)
	var inverse := Basis.from_scale(Vector3.ONE / inertia)
	var probes := WaterForces.probe_positions(Vector3(1.6, 0.5, 4.2))
	# Include four wheel contributions and the real nonzero COM lever-arm offset.
	probes.append_array(PackedVector3Array([Vector3(-0.76, -0.3, -1.26), Vector3(0.76, -0.3, -1.26), Vector3(-0.76, -0.3, 1.26), Vector3(0.76, -0.3, 1.26)]))
	for hz: float in [60.0, 120.0]:
		for factor: float in [0.0, 1.0, 100.0]:
			var velocity := Vector3(4.0, -2.0, -15.0) * factor
			var angular := Vector3(2.0, -1.0, 4.0) * factor
			var before := 0.5 * mass * velocity.length_squared() + 0.5 * angular.dot(inertia * angular)
			var drag := WaterForces.new()
			drag.begin(1.0 / mass, inverse)
			for point in probes:
				var arm := point - Vector3(0.0, -0.15, 0.0)
				var local_speed := velocity + angular.cross(arm)
				for direction: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]:
					drag.add_axis(direction, local_speed.dot(direction), arm, 80.0, 500.0, 1.0 / 8.0)
			drag.finish(1.0 / hz)
			var after_velocity := velocity + drag.force / mass / hz
			var after_angular := angular + inverse * drag.torque / hz
			var after := 0.5 * mass * after_velocity.length_squared() + 0.5 * after_angular.dot(inertia * after_angular)
			assert_true(after <= before + 0.001, "combined translation/rotation damping cannot add still-water energy")
			assert_true(after_velocity.is_finite() and after_angular.is_finite())
			assert_true(velocity.dot(after_velocity) >= -0.00001, "net translation cannot reverse in one tick")
			assert_true(angular.dot(inertia * after_angular) >= -0.00001)


func test_pure_translation_never_reverses_even_when_all_probes_would_overshoot() -> void:
	var drag := WaterForces.new()
	drag.begin(1.0 / 1000.0, Basis.from_scale(Vector3(0.001, 0.001, 0.001)))
	for index in 8:
		drag.add_axis(Vector3.RIGHT, 1000.0, Vector3.ZERO, 50.0, 350.0, 1.0 / 8.0)
	drag.finish(1.0 / 60.0)
	var after := 1000.0 + drag.force.x / 1000.0 / 60.0
	assert_between(after, -0.001, 1000.0)
	assert_lt(drag.damping_scale, 1.0)


func test_asymmetric_wet_probes_with_rotated_inertia_still_dissipate_total_energy() -> void:
	var mass := 1450.0
	var rotation := Basis.from_euler(Vector3(0.7, 1.1, 0.4))
	var inertia := rotation * Basis.from_scale(Vector3(2400.0, 2700.0, 550.0)) * rotation.transposed()
	var inverse := inertia.inverse()
	var probes := WaterForces.probe_positions(Vector3(1.6, 0.5, 4.2))
	for hz: float in [60.0, 120.0]:
		var velocity := Vector3(40.0, -20.0, -150.0)
		var angular := Vector3(20.0, -10.0, 40.0)
		var before := 0.5 * mass * velocity.length_squared() + 0.5 * angular.dot(inertia * angular)
		var drag := WaterForces.new()
		drag.begin(1.0 / mass, inverse)
		for index in probes.size():
			var arm := rotation * (probes[index] - Vector3(0.0, -0.15, 0.0))
			var at := velocity + angular.cross(arm)
			var wetness := (index + 1.0) / 64.0
			for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]:
				drag.add_axis(axis, at.dot(axis), arm, 80.0, 500.0, wetness)
		drag.finish(1.0 / hz)
		var after_v := velocity + drag.force / mass / hz
		var after_w := angular + inverse * drag.torque / hz
		var after := 0.5 * mass * after_v.length_squared() + 0.5 * after_w.dot(inertia * after_w)
		assert_lte(after, before, "coupled angular/linear drag cannot create total kinetic energy")
