class_name TrailDriver
extends RefCounted
## A scripted driver for scenario tests: steers toward a point a little way up
## the road (pure pursuit) and picks a speed from how sharply the road bends
## ahead. Not a good driver - just a steady one.

## Steer toward the road point this far ahead of the car (m).
const LOOKAHEAD := 12.0
## Judge the bend over this distance ahead (m).
const CURVE_WINDOW := 30.0
## Share of the grip-limited cornering speed to aim for.
const CAUTION := 0.6
const MIN_SPEED := 6.0
const MAX_SPEED := 25.0

var car: Car
var sampler: RoadSampler


func _init(driven_car: Car, road: RoadSampler) -> void:
	car = driven_car
	sampler = road


## Sets the car's virtual steer, throttle and brake for this tick.
func drive() -> void:
	var distance := sampler.closest_distance(car.global_position)
	var target := sampler.position(distance + LOOKAHEAD)
	var to_target := target - car.global_position
	var heading := -car.global_basis.z
	var flat_heading := Vector2(heading.x, heading.z).normalized()
	var flat_target := Vector2(to_target.x, to_target.z).normalized()
	# Positive when the target is to the right (x = world X, y = world Z).
	var angle := flat_heading.angle_to(flat_target)
	var max_angle := Steering.max_angle_for_speed(car.forward_speed(), car.stats)
	car.input.virtual_steer = clampf(angle / maxf(max_angle, 0.05), -1.0, 1.0)

	var speed := car.forward_speed()
	var wanted := target_speed(distance)
	car.input.virtual_throttle = 1.0 if speed < wanted - 1.0 else 0.0
	car.input.virtual_brake = 1.0 if speed > wanted + 2.0 else 0.0


## Speed to aim for at `distance`, from the sharpest bend in the window ahead.
func target_speed(distance: float) -> float:
	var sharpest := 0.0
	var step := 5.0
	var ahead := 0.0
	while ahead < CURVE_WINDOW:
		var a := sampler.forward(distance + ahead)
		var b := sampler.forward(distance + ahead + step)
		var turn := Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z))
		sharpest = maxf(sharpest, absf(turn) / step)
		ahead += step
	if sharpest < 0.0001:
		return MAX_SPEED
	var grip_speed := sqrt(car.stats.tire_grip * 9.8 / sharpest)
	return clampf(grip_speed * CAUTION, MIN_SPEED, MAX_SPEED)
