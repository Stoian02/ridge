class_name TrailScenarios
extends RefCounted
## Shared steps for scenario tests on real levels: wait out the countdown, put
## the car at rest somewhere, drive along the road at full throttle, and brake
## to a stop. Each step awaits physics ticks, so call them with await.


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Waits for the countdown to end, so the pedals work.
static func wait_for_go(level: RunLevel) -> void:
	while level.run.clock.stage != RunClock.Stage.RUNNING:
		await _tree().physics_frame


## Puts the car at rest on the road at `distance`, facing along it, and lets it settle.
static func place_on_road(level: RunLevel, distance: float) -> void:
	await place(level, level.trail.sampler.transform_at(distance, CheckpointPlacer.RESET_HEIGHT, level.trail.profile))


## Puts the car at rest at a lateral offset from the road, facing along it.
## Road and shoulder offsets use the generated road height; positions beyond
## the shoulder use the terrain height.
static func place_at_offset(level: RunLevel, distance: float, lateral: float) -> void:
	var sampler := level.trail.sampler
	var along := sampler.forward(distance)
	var surface_up := sampler.up(distance)
	var origin := sampler.position(distance) + sampler.right(distance) * lateral
	if absf(lateral) <= level.trail.trail.half_total_width():
		origin = sampler.surface_point(distance, lateral, level.trail.profile)
	else:
		origin.y = level.trail.field.height_at(origin.x, origin.z)
	origin += surface_up * CheckpointPlacer.RESET_HEIGHT
	await place(level, Transform3D(Basis.looking_at(along, surface_up), origin))


## Puts the car at rest at `transform` and lets it settle for half a second.
static func place(level: RunLevel, transform: Transform3D) -> void:
	level.rig.place_car(transform)
	for i in ScenarioHelper.ticks(0.5):
		level.rig.car.input.virtual_throttle = 0.0
		level.rig.car.input.virtual_brake = 1.0
		await _tree().physics_frame


## Steers along the road at full throttle until `done` returns true or `seconds`
## pass. Returns the seconds it took (or `seconds` if `done` never came true).
static func full_throttle_until(level: RunLevel, seconds: float, done: Callable) -> float:
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler)
	for tick in ScenarioHelper.ticks(seconds):
		if done.call():
			return tick / float(Engine.physics_ticks_per_second)
		driver.drive()
		car.input.virtual_throttle = 1.0
		car.input.virtual_brake = 0.0
		await _tree().physics_frame
	return seconds


## Drives toward a world-space point at a restrained target speed. Useful for
## off-road scenario paths where TrailDriver would steer back to the centre line.
static func drive_toward(car: Car, target: Vector3, wanted_speed: float = 10.0) -> void:
	var to_target := target - car.global_position
	var heading := -car.global_basis.z
	var flat_heading := Vector2(heading.x, heading.z).normalized()
	var flat_target := Vector2(to_target.x, to_target.z).normalized()
	var angle := flat_heading.angle_to(flat_target)
	var max_angle := Steering.max_angle_for_speed(car.forward_speed(), car.stats)
	car.input.virtual_steer = clampf(angle / maxf(max_angle, 0.05), -1.0, 1.0)
	var speed := car.forward_speed()
	car.input.virtual_throttle = 1.0 if speed < wanted_speed - 0.5 else 0.0
	car.input.virtual_brake = 1.0 if speed > wanted_speed + 1.5 else 0.0


## Brakes hard while steering along the road until the car stops (or 10 s pass).
static func brake_to_stop(level: RunLevel) -> void:
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler)
	for tick in ScenarioHelper.ticks(10.0):
		driver.drive()
		car.input.virtual_throttle = 0.0
		car.input.virtual_brake = 1.0
		await _tree().physics_frame
		if car.linear_velocity.length() < 0.3:
			return
