class_name WaterEffects
extends Node3D
## One bounded surface emitter shared by entry splashes and the short wake.
## The spray cone tilts toward travel; it never becomes horizontal.
## Updated by CarEffects, before CarAudio; no independent sampling or forces.

const AMOUNT := 32
const LIFETIME := 0.50
## Horizontal share of the spray cone's aim at speed; the cone stays upward.
const MAXIMUM_LEAN := 0.6

var car: Car
var emitter: CPUParticles3D
var entries := 0
var entry_strength := 0.0
var wash_volume := 0.0
var _cooldown := 0.0
var _entry_left := 0.0
var _idle := 0.0
var _was_wet := false
var _suppress_first := true


func setup(driven: Car) -> void:
	car = driven
	emitter = CPUParticles3D.new()
	emitter.name = "SurfaceWake"
	emitter.amount = AMOUNT
	emitter.lifetime = LIFETIME
	emitter.local_coords = false
	emitter.top_level = true
	emitter.emitting = false
	emitter.visible = false
	emitter.mesh = WheelSpray._shared_quad()
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.gravity = Vector3(0.0, -4.0, 0.0)
	emitter.direction = Vector3.UP
	emitter.spread = 70.0
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.emission_box_extents = Vector3(driven.stats.body_size.x * 0.5, 0.01, 0.35)
	emitter.scale_amount_min = 0.8
	emitter.scale_amount_max = 1.8
	emitter.color_ramp = WheelSpray._fading_ramp()
	add_child(emitter)


func update(delta: float, wheel_slip: float) -> void:
	if car == null or car.water == null:
		return
	var water := car.water
	_cooldown = maxf(0.0, _cooldown - delta)
	_entry_left = maxf(0.0, _entry_left - delta)
	var wetness := water.state.body_immersion
	for wet: float in water.wheel_wetness:
		wetness = maxf(wetness, wet)
	wash_volume = WaterFeedback.wash(wetness, water.relative_speed, wheel_slip)
	var total := 0.0
	var surface := Vector3.ZERO
	var tint := Color(0.28, 0.55, 0.58)
	for i: int in water.body_samples.size():
		var sample: WaterSample = water.body_samples[i]
		if not sample.valid or water.body_wetness[i] <= 0.0:
			continue
		var point: Vector3 = water.body_positions[i]
		var weight := 1.0 - smoothstep(water.probe_radius,
			water.probe_radius + 0.30, sample.surface_y - point.y)
		surface += Vector3(point.x, sample.surface_y + 0.03, point.z) * weight
		total += weight
		tint = sample.color
	var body_wet := water.state.body_immersion > 0.01
	var relative := car.linear_velocity - water.current_velocity
	if not _suppress_first and body_wet and not _was_wet and total > 0.0 \
			and -relative.y >= WaterFeedback.ENTRY_SPEED and _cooldown <= 0.0:
		entries += 1
		entry_strength = clampf(-relative.y / 5.0, 0.2, 1.0)
		_entry_left = 0.18
		_cooldown = WaterFeedback.ENTRY_COOLDOWN
	_was_wet = body_wet
	_suppress_first = false
	var horizontal := Vector2(relative.x, relative.z).length()
	var strength := WaterFeedback.wake(horizontal, minf(total / 4.0, 1.0))
	if _entry_left > 0.0 and total > 0.0:
		strength = maxf(strength, entry_strength)
	if total > 0.0 and strength > 0.01:
		# Thrown water follows the car, so the cone leans the way it is moving
		# rather than going straight up out of a moving hull.
		var lean := Vector3(relative.x, 0.0, relative.z)
		if lean.length() > 0.1:
			emitter.direction = (Vector3.UP + lean.normalized()
				* clampf(horizontal / 6.0, 0.0, MAXIMUM_LEAN)).normalized()
		else:
			emitter.direction = Vector3.UP
		emitter.global_transform = Transform3D(Basis.IDENTITY, surface / total)
		emitter.color = Color(tint.lightened(0.35), strength * 0.55)
		emitter.initial_velocity_min = 0.4 + strength
		emitter.initial_velocity_max = 1.0 + strength * 2.5
		emitter.visible = true
		emitter.emitting = true
		_idle = 0.0
	else:
		emitter.emitting = false
		_idle += delta
		if _idle >= LIFETIME:
			emitter.visible = false


func notify_reset() -> void:
	_cooldown = WaterFeedback.ENTRY_COOLDOWN
	_entry_left = 0.0
	_idle = 0.0
	_was_wet = false
	_suppress_first = true
	entry_strength = 0.0
	wash_volume = 0.0
	if emitter != null:
		emitter.restart()
		emitter.emitting = false
		emitter.visible = false


func _exit_tree() -> void:
	if emitter != null:
		emitter.emitting = false
