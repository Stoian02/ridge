class_name ScenarioHelper
extends RefCounted
## Builds minimal worlds for scenario tests, independent of the Test Ground layout
## (which will keep changing as we tune).

const CAR_SCENE := preload("res://car/car.tscn")


static func ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


## A flat square of one surface, top face at center.y.
static func make_flat_ground(surface: SurfaceDef, center := Vector3.ZERO, size := 600.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.set_meta(SurfaceLookup.META_KEY, surface)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0, size)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	return body


static func spawn_car(test: GutTest, at: Vector3) -> Car:
	var car: Car = CAR_SCENE.instantiate()
	car.position = at
	test.add_child_autofree(car)
	return car


static func is_upright(car: Car) -> bool:
	return car.global_basis.y.dot(Vector3.UP) > 0.8
