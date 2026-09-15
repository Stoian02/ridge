class_name CarEffects
extends Node3D
## The car's wheel sprays (spec §6): one WheelSpray per wheel, fed each frame from
## the wheel's surface and motion. Only reads the car.

const FEELS := preload("res://effects/surface_feel_table.tres")
## Sprays start this far above the contact point (m), so they don't clip into the ground.
const LIFT := 0.05

var car: Car
var sprays: Array[WheelSpray] = []


func setup(driven: Car) -> void:
	car = driven
	for wheel in car.wheels:
		var spray := WheelSpray.new()
		spray.name = "Spray%s" % wheel.name.trim_prefix("Wheel")
		add_child(spray)
		sprays.append(spray)


func _process(delta: float) -> void:
	if car == null:
		return
	for i in car.wheels.size():
		var wheel := car.wheels[i]
		var motion := WheelMotion.of(wheel, car)
		var feel: SurfaceFeel = FEELS.feel_for(wheel.surface) if motion["in_contact"] else null
		var strength := 0.0
		if feel != null:
			strength = SprayLogic.intensity(feel.spray, motion["ground_speed"], motion["slip_speed"], motion["sliding"])
			sprays[i].global_transform = Transform3D(car.global_basis, wheel.contact_point + wheel.contact_normal * LIFT)
		sprays[i].update(feel, strength, delta)


## A car reset: every spray stops at once.
func notify_reset() -> void:
	for spray in sprays:
		spray.stop_now()
