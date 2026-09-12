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
