class_name CarEffects
extends Node3D
## The car's wheel sprays (spec §6): one WheelSpray per wheel, fed each frame from
## the wheel's surface and motion. Only reads the car.

const FEELS := preload("res://effects/surface_feel_table.tres")
## Sprays start this far above the contact point (m), so they don't clip into the ground.
const LIFT := 0.05

var car: Car
var sprays: Array[WheelSpray] = []
## One Dictionary per wheel ("in_contact", "ground_speed", "slip_speed", "sliding", "feel"),
## refilled in place each frame instead of allocated fresh. CarAudio reads this same array,
## so it doesn't have to work out each wheel's motion a second time.
var wheels: Array[Dictionary] = []


func setup(driven: Car) -> void:
	car = driven
	for wheel in car.wheels:
		var spray := WheelSpray.new()
		spray.name = "Spray%s" % wheel.name.trim_prefix("Wheel")
		add_child(spray)
		sprays.append(spray)
		wheels.append({"in_contact": false, "ground_speed": 0.0, "slip_speed": 0.0, "sliding": false, "feel": null})


func _process(delta: float) -> void:
	if car == null:
		return
	for i in car.wheels.size():
		var wheel := car.wheels[i]
		var motion := wheels[i]
		WheelMotion.fill(motion, wheel, car)
		var in_contact: bool = motion["in_contact"]
		var feel: SurfaceFeel = FEELS.feel_for(wheel.surface) if in_contact else null
		motion["feel"] = feel
		var strength := 0.0
		if feel != null:
			var ground_speed: float = motion["ground_speed"]
			var slip_speed: float = motion["slip_speed"]
			var sliding: bool = motion["sliding"]
			strength = SprayLogic.intensity(feel.spray, ground_speed, slip_speed, sliding)
			sprays[i].global_transform = Transform3D(car.global_basis, wheel.contact_point + wheel.contact_normal * LIFT)
		sprays[i].update(feel, strength, delta)


## A car reset: every spray stops at once.
func notify_reset() -> void:
	for spray in sprays:
		spray.stop_now()
