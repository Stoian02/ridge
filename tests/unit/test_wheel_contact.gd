extends GutTest
## Wheel ground detection against real collision shapes (no car body needed).

const ASPHALT := preload("res://surfaces/asphalt.tres")
const MUD := preload("res://surfaces/mud.tres")

var stats: CarStats


func before_each() -> void:
	stats = CarStats.new()


func _add_ground(surface: SurfaceDef) -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	shape.position.y = -0.5  # top face at y = 0
	ground.add_child(shape)
	if surface != null:
		ground.set_meta(SurfaceLookup.META_KEY, surface)
	add_child_autofree(ground)


## A wheel whose suspension mount sits at mount_height above the ground.
func _add_wheel(mount_height: float) -> Wheel:
	var holder := StaticBody3D.new()  # stands in for the car body
	holder.position.y = mount_height - stats.wheel_mount_height
	add_child_autofree(holder)
	var wheel := Wheel.new()
	holder.add_child(wheel)
	wheel.setup(stats, GripTable.new(), holder)
	return wheel


func test_detects_ground_and_measures_compression() -> void:
	_add_ground(ASPHALT)
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	# Sphere (r = 0.33) touches when its centre is 0.33 up: 0.17 m below the
	# mount, so the spring is squeezed 0.35 - 0.17 = 0.18 m.
	assert_true(wheel.in_contact)
	assert_almost_eq(wheel.compression, 0.18, 0.01)
	assert_eq(wheel.surface, ASPHALT)


func test_no_contact_when_the_ground_is_out_of_reach() -> void:
	_add_ground(ASPHALT)
	var wheel := _add_wheel(2.0)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	assert_false(wheel.in_contact)
	assert_almost_eq(wheel.compression, 0.0, 0.0001)


func test_untagged_ground_counts_as_dirt() -> void:
	_add_ground(null)
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	assert_eq(wheel.surface.id, &"dirt")


func test_mud_lets_the_wheel_sink() -> void:
	_add_ground(MUD)
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	# 0.18 m on hard ground, minus the 0.06 m the wheel sinks into mud.
	assert_almost_eq(wheel.compression, 0.12, 0.01)


func _moving_body(at: Vector3, body_mass: float = 40.0) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.position = at
	body.mass = body_mass
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp = 0.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 1.0, 6.0)
	shape.shape = box
	body.add_child(shape)
	body.set_meta(SurfaceLookup.META_KEY, ASPHALT)
	add_child_autofree(body)
	return body


func test_contact_tracks_dynamic_body_and_clears_on_reset_and_miss() -> void:
	var support := _moving_body(Vector3(0.0, -0.5, 0.0))
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	assert_eq(wheel.contact_body, support)
	wheel.reset()
	assert_null(wheel.contact_body)
	assert_false(wheel.in_contact)
	wheel.update_contact(1.0 / 120.0)
	wheel.get_parent().position.y += 10.0
	wheel.update_contact(1.0 / 120.0)
	assert_null(wheel.contact_body)
	assert_false(wheel.in_contact)


func test_slip_uses_the_moving_supports_velocity() -> void:
	var support := _moving_body(Vector3(0.0, -0.5, 0.0))
	var car := _moving_body(Vector3(0.0, 10.0, 0.0), 1300.0)
	var wheel := _add_wheel(0.5)
	support.linear_velocity = Vector3(1.0, 0.0, -3.0)
	car.linear_velocity = support.linear_velocity
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	wheel.compression_speed = 0.0
	wheel.spin_speed = 0.0
	var force := wheel.compute_force(1.0 / 120.0, 0.0, car)
	assert_almost_eq(wheel.slip_ratio, 0.0, 0.0001, "no relative longitudinal motion")
	assert_almost_eq(wheel.slip_angle, 0.0, 0.0001, "no relative lateral motion")
	assert_almost_eq(force.x, 0.0, 0.001)
	assert_almost_eq(force.z, 0.0, 0.001)


func test_rotating_support_velocity_includes_its_offset_center_of_mass() -> void:
	var support := _moving_body(Vector3(0.0, -0.5, 0.0))
	support.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	support.center_of_mass = Vector3(0.3, 0.1, 0.2)
	var car := _moving_body(Vector3(0.0, 10.0, 0.0), 1300.0)
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	support.angular_velocity = Vector3(0.0, 2.0, 0.0)
	var state := PhysicsServer3D.body_get_direct_state(support.get_rid())
	car.linear_velocity = support.angular_velocity.cross(wheel.contact_point - support.global_position - state.center_of_mass)
	wheel.compression_speed = 0.0
	wheel.compute_force(1.0 / 120.0, 0.0, car)
	assert_almost_eq(wheel.slip_ratio, 0.0, 0.001)
	assert_almost_eq(wheel.slip_angle, 0.0, 0.001)


func test_contact_force_has_equal_opposite_reaction_and_wakes_the_stone() -> void:
	var support := _moving_body(Vector3(0.0, -0.5, 0.0))
	var car := _moving_body(Vector3(0.0, 10.0, 0.0), 1300.0)
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	support.sleeping = true
	wheel.apply_contact_force(Vector3(80.0, 1000.0, -240.0), car)
	await wait_physics_frames(2)
	assert_false(support.sleeping)
	assert_gt(support.linear_velocity.z, 0.0, "a forward-driving tyre pushes the stone backwards")
	assert_lt(support.linear_velocity.y, 0.0, "suspension pushes down on its support")
	assert_gt(support.angular_velocity.length(), 0.0, "an off-centre contact rotates the stone")
	var momentum := car.linear_velocity * car.mass + support.linear_velocity * support.mass
	assert_lt(momentum.length(), 0.01, "contact does not create net linear momentum")


func test_light_support_reduces_the_low_speed_force_limit_including_rotation() -> void:
	var support := _moving_body(Vector3(0.0, -0.5, 0.0), 3.0)
	var car := _moving_body(Vector3(0.0, 10.0, 0.0), 1300.0)
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	wheel.compression_speed = 0.0
	car.linear_velocity = Vector3(0.1, 0.0, 0.0)
	wheel.spin_speed = 0.1 / stats.wheel_radius
	var moving_force := wheel.compute_force(1.0 / 120.0, 0.0, car)
	var state := PhysicsServer3D.body_get_direct_state(support.get_rid())
	var arm := wheel.contact_point - support.global_position - state.center_of_mass
	var effective := Wheel._coupled_mass(300.0, state, arm, Vector3.RIGHT)
	assert_lt(effective, 1.0 / (1.0 / 300.0 + 1.0 / support.mass), "off-centre rotation further lowers effective mass")
	wheel.contact_body = null
	wheel.spin_speed = 0.1 / stats.wheel_radius
	var static_force := wheel.compute_force(1.0 / 120.0, 0.0, car)
	assert_lt(absf(moving_force.x), absf(static_force.x) * 0.2)
	assert_lt(absf(moving_force.z), absf(static_force.z) * 0.8)


func test_frozen_support_keeps_the_static_ground_force_path() -> void:
	var support := _moving_body(Vector3(0.0, -0.5, 0.0))
	support.freeze = true
	var car := _moving_body(Vector3(0.0, 10.0, 0.0), 1300.0)
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	wheel.compression_speed = 0.0
	wheel.spin_speed = 4.0
	var frozen_force := wheel.compute_force(1.0 / 120.0, 0.0, car)
	wheel.contact_body = null
	wheel.spin_speed = 4.0
	assert_eq(wheel.compute_force(1.0 / 120.0, 0.0, car), frozen_force)


func test_light_support_bounds_suspension_spikes_and_preserves_spin_reaction() -> void:
	var support := _moving_body(Vector3(0.0, -0.5, 0.0), 1.0)
	var car := _moving_body(Vector3(0.0, 10.0, 0.0), 1300.0)
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)  # new contact: deliberately large damper spike
	wheel.spin_speed = 4.0
	var before := wheel.spin_speed
	var dt := 1.0 / 120.0
	var force := wheel.compute_force(dt, 0.0, car)
	assert_lte(force.length() * dt / support.mass, Wheel.MAX_SUPPORT_DELTA_SPEED + 0.001)
	assert_almost_eq(force.y, wheel.tire_load, 0.001, "telemetry reports the force actually transmitted")
	var spin_change := (before - wheel.spin_speed) * stats.wheel_inertia
	assert_almost_eq(spin_change, -force.z * stats.wheel_radius * dt, 0.001, "same scaled reaction at the tyre")
