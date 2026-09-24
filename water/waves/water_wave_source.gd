class_name WaterWaveSource
extends RefCounted
## Pure post-car source history. Observations use REST water and translation,
## never the wave height, throttle or wheel spin. All writes are next-tick inputs.

class Observation:
	var body_id: StringName
	var at := Vector2.ZERO
	var bow_at := Vector2.ZERO
	var wake_at := Vector2.ZERO
	var current := Vector2.ZERO
	var velocity := Vector3.ZERO
	var size := Vector3(1.8, 1.0, 4.0)
	var body_immersion := 0.0
	var wheel_immersion := 0.0
	var upper_clearance := 0.0

var entries := 0
var wakes := 0
var _seeded := false
var _armed := false
var _dry_seconds := 0.0
var _previous_immersion := 0.0
var _body: StringName
var _wake_seconds := 0.0
var _wake_distance := 0.0
var _bow_body: StringName
var _bow_at := Vector2.ZERO
var _direction := Vector2.UP
var _width := 1.8


func reset() -> void:
	entries = 0
	wakes = 0
	_seeded = false
	_armed = false
	_dry_seconds = 0.0
	_previous_immersion = 0.0
	_body = &""
	_bow_body = &""
	_wake_seconds = 0.0
	_wake_distance = 0.0


func step(delta: float, observation: Observation, field: WaterWaveField) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	var wet := observation.body_immersion
	if not _seeded:
		_seeded = true
		_previous_immersion = wet
		_body = observation.body_id
		return
	if wet <= 0.02:
		_dry_seconds += delta
		if _dry_seconds >= 0.5 - 0.00000001:
			_armed = true
	else:
		_dry_seconds = 0.0
	if observation.body_id != _body:
		_wake_seconds = 0.0
		_wake_distance = 0.0
		_body = observation.body_id
	var velocity := Vector2(observation.velocity.x, observation.velocity.z)
	var speed := velocity.length()
	var size_factor := clampf(observation.size.x * observation.size.z / 7.2, 0.8, 1.25)
	var deep_fade := 1.0 - smoothstep(0.30, 0.60, -observation.upper_clearance)
	if _body != &"" and _armed and _previous_immersion < 0.05 and wet >= 0.05:
		var entry := clampf(0.02 + 0.004 * speed + 0.01 * maxf(0.0, -observation.velocity.y), 0.02, 0.08)
		# Displace a hull-sized patch, not a point hidden beneath the bonnet.
		# The same shore/depth-limited field still determines visible AND physical height.
		var radius := clampf(observation.size.x * 0.5, 0.6, 1.5)
		if field.queue_packet(WaterWaveField.Kind.ENTRY, _body, observation.at,
				observation.current, minf(0.08, entry * size_factor) * deep_fade, Vector2.UP, radius):
			entries += 1
		_armed = false
	_previous_immersion = wet
	var weight := maxf(clampf(wet / 0.35, 0.0, 1.0), 0.15 * observation.wheel_immersion)
	var strength := smoothstep(0.75, 8.0, speed) * weight * deep_fade
	if _body == &"":
		strength = 0.0
	if strength > 0.0:
		_direction = velocity.normalized()
		_bow_body = _body
		_bow_at = observation.bow_at
		_width = observation.size.x
		_wake_seconds += delta
		_wake_distance += speed * delta
		if _wake_seconds >= 0.30 - 0.00000001 and _wake_distance >= 1.0 - 0.00000001:
			if field.queue_packet(WaterWaveField.Kind.WAKE, _body, observation.wake_at,
					observation.current, minf(0.03, field.profile.wake_amplitude * size_factor * strength), _direction):
				wakes += 1
			_wake_seconds = 0.0
			_wake_distance = 0.0
	else:
		_wake_seconds = 0.0
		_wake_distance = 0.0
	# Keep the last wet body's bow location while fading, not an abrupt reset.
	field.set_bow(_bow_body, _bow_at, _direction, _width,
		minf(0.05, field.profile.bow_amplitude * size_factor * strength))
