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
var water_effects: WaterEffects
var trace_enabled := false
var trace_usec := 0
var _water_reset_serial := -1


func setup(driven: Car) -> void:
	car = driven
	for wheel in car.wheels:
		var spray := WheelSpray.new()
		spray.name = "Spray%s" % wheel.name.trim_prefix("Wheel")
		add_child(spray)
		sprays.append(spray)
		wheels.append({"in_contact": false, "ground_speed": 0.0, "slip_speed": 0.0, "sliding": false, "feel": null})
	water_effects = WaterEffects.new()
	water_effects.name = "WaterEffects"
	add_child(water_effects)
	water_effects.setup(car)


func _process(delta: float) -> void:
	if car == null:
		return
	var trace_started := Time.get_ticks_usec() if trace_enabled else 0
	if _water_reset_serial != car.water.reset_serial:
		notify_reset()
		_water_reset_serial = car.water.reset_serial
	var largest_slip := 0.0
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
		var wetness: float = car.water.wheel_wetness[i]
		motion["water_wetness"] = wetness
		largest_slip = maxf(largest_slip, absf(motion["slip_speed"]))
		if wetness > 0.0:
			var sample: WaterSample = car.water.wheel_samples[i]
			var center: Vector3 = car.water.wheel_positions[i]
			var upper_depth := sample.surface_y - (center.y + car.water.wheel_extents[i])
			# Physics wetness excludes the tyre volume inside the solid bed. That
			# must not make a completely submerged tyre look partly dry.
			var dry_strength := strength * (1.0 - smoothstep(-0.10, 0.0, upper_depth))
			var heading := -car.global_basis.z
			var water_speed := (car.linear_velocity - sample.current).dot(heading)
			var water_slip := clampf(wheel.spin_speed * car.stats.wheel_radius - water_speed, -8.0, 8.0)
			largest_slip = maxf(largest_slip, absf(water_slip))
			var splash := WaterFeedback.wheel_splash(wetness, car.water.relative_speed,
				water_slip, upper_depth)
			var position := Vector3(center.x, sample.surface_y + LIFT, center.z)
			sprays[i].global_transform = Transform3D(car.global_basis, position)
			sprays[i].update_water(feel, dry_strength, sample.color, splash, wetness, delta)
		else:
			sprays[i].update(feel, strength, delta)
	water_effects.update(delta, largest_slip)
	if trace_enabled:
		trace_usec = Time.get_ticks_usec() - trace_started


## A car reset: every spray stops at once.
func notify_reset() -> void:
	for spray in sprays:
		spray.stop_now()
	if water_effects != null:
		water_effects.notify_reset()
