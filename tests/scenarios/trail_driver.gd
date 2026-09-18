class_name TrailDriver
extends RefCounted
## A scripted driver for scenario tests: steers toward a point a little way up
## the road (pure pursuit) and picks a speed from how sharply the road bends
## ahead. Not a good driver - just a steady one. Given the road's profile, it also
## slows for the grip of the surface ahead (mud, dirt), on straights as in bends,
## and crawls through rock steps, boulder fields, talus, fords and narrow shelves.

## Steer toward the road point this far ahead of the car (m).
const LOOKAHEAD := 12.0
## Judge the bend over this distance ahead (m).
const CURVE_WINDOW := 30.0
## Share of the grip-limited cornering speed to aim for.
const CAUTION := 0.6
const MIN_SPEED := 6.0
const MAX_SPEED := 25.0
## Slow this far before an authored obstacle and until the whole car is clear.
const CRAWL_LOOKAHEAD := 20.0
const CRAWL_SPEED := 4.5
## Avoid accelerating between obstacles on a shelf that leaves little room to
## brake or recover. Wider/profile-free roads retain their original behavior.
const NARROW_ROAD_WIDTH := 5.0

var car: Car
var sampler: RoadSampler
## When set, the speed also allows for the surface ahead; without it (the default)
## the driver judges bends by the car's tire grip alone.
var profile: RoadProfile


func _init(driven_car: Car, road: RoadSampler, road_profile: RoadProfile = null) -> void:
	car = driven_car
	sampler = road
	profile = road_profile


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
	var surface_grip := _lowest_surface_grip(distance) if profile != null else 1.0
	var fastest := MAX_SPEED * sqrt(minf(surface_grip, 1.0))
	var wanted := fastest
	if sharpest >= 0.0001:
		var grip_speed := sqrt(car.stats.tire_grip * surface_grip * 9.8 / sharpest)
		wanted = clampf(grip_speed * CAUTION, MIN_SPEED, fastest)
	if crawl_zone_ahead(distance):
		wanted = minf(wanted, CRAWL_SPEED)
	return wanted


## An obstacle intersects the 20 m approach window or lies up to 5 m behind,
## keeping the rear wheels slow until they finish the ramp, field or ford bank.
func crawl_zone_ahead(distance: float) -> bool:
	if profile == null:
		return false
	var from := distance - 5.0
	var to := distance + CRAWL_LOOKAHEAD
	var def := profile.def
	for width: Vector4 in def.width_stretches:
		if width.z <= NARROW_ROAD_WIDTH and width.x + width.y >= from and width.x <= to:
			return true
	for step: RockStepDef in def.rock_steps:
		if step.distance + step.ramp_length >= from and step.distance <= to:
			return true
	for field: BoulderFieldDef in def.boulder_fields:
		if field.end() >= from and field.start <= to:
			return true
	for field: TalusDef in def.talus:
		if field.end() >= from and field.start <= to:
			return true
	for ford: FordDef in def.fords:
		var reach := ford.half_width() + ford.bank_run
		if ford.distance + reach >= from and ford.distance - reach <= to:
			return true
	return false


## The lowest grip of the road surface over the window ahead, as this car feels it
## (the surface's grip times the car's grip-table multiplier for it).
func _lowest_surface_grip(distance: float) -> float:
	var lowest := INF
	var ahead := 0.0
	while ahead <= CURVE_WINDOW:
		var surface := profile.surface_at(distance + ahead)
		lowest = minf(lowest, surface.grip * car.grip_table.multiplier(car.stats.archetype, surface.id))
		ahead += 5.0
	return lowest
