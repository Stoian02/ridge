class_name WaterWaveField
extends RefCounted
## One global bounded source store per world, with per-body packed snapshots.
## No Car/WaterWorld dependency: this can only be driven by explicit inputs.

enum Kind { ENTRY, WAKE }

class Packet:
	var active := false
	var pending := false
	var body_id: StringName
	var origin: Vector2
	var current: Vector2
	var direction: Vector2
	var amplitude: float
	var born: float
	var life: float
	var entry_radius := 0.0

var serial := 0
var skipped_packets := 0
var clock_seconds := 0.0
var profile: WaterWaveProfile
var _slots: Array[Packet] = []
var _bow_body: StringName
var _bow_position: Vector2
var _bow_direction := Vector2.UP
var _bow_width := 1.0
var _bow_sweep := 1.5
var _bow_target := 0.0
var _bow_value := 0.0
var _bow_pending := false
var _next_bow_body: StringName
var _next_bow_position: Vector2
var _next_bow_direction: Vector2
var _next_bow_width := 1.0
var _next_bow_sweep := 1.5
var _next_bow_target := 0.0


func _init(values: WaterWaveProfile = null) -> void:
	profile = (values.duplicate() as WaterWaveProfile) if values != null else WaterWaveProfile.new()
	assert(profile.is_valid(), "Invalid wave profile")
	for index in WaterWaveProfile.PACKET_SLOTS:
		_slots.append(Packet.new())


func queue_packet(kind: Kind, body: StringName, at: Vector2, current: Vector2,
		amplitude: float, direction := Vector2.UP, entry_radius := 0.0) -> bool:
	if body == &"" or not at.is_finite() or not current.is_finite() \
			or not direction.is_finite() or not is_finite(amplitude) or amplitude <= 0.0 \
			or not is_finite(entry_radius) or entry_radius < 0.0 or entry_radius > 1.5 \
			or (kind != Kind.ENTRY and kind != Kind.WAKE) \
			or (kind == Kind.WAKE and direction.length_squared() < 0.000001):
		return false
	var start := 0 if kind == Kind.ENTRY else WaterWaveProfile.ENTRY_SLOTS
	var end := WaterWaveProfile.ENTRY_SLOTS if kind == Kind.ENTRY else WaterWaveProfile.PACKET_SLOTS
	for index in range(start, end):
		var slot := _slots[index]
		if slot.active or slot.pending:
			continue
		slot.pending = true
		slot.body_id = body
		slot.origin = at
		slot.current = current
		slot.direction = direction.normalized()
		slot.amplitude = minf(amplitude, profile.entry_amplitude if kind == Kind.ENTRY else profile.wake_amplitude)
		slot.life = profile.entry_life if kind == Kind.ENTRY else profile.wake_life
		slot.entry_radius = entry_radius if kind == Kind.ENTRY else 0.0
		return true
	skipped_packets += 1
	return false


## Input coefficient is a target. Position/direction are committed at snapshot time.
func set_bow(body: StringName, at: Vector2, direction: Vector2, width: float,
		amplitude: float, sweep := 1.5) -> void:
	if not at.is_finite() or not direction.is_finite() or not is_finite(width) \
			or width <= 0.0 or not is_finite(amplitude) or not is_finite(sweep) \
			or sweep < 0.0 or sweep > 2.0:
		return
	_bow_pending = true
	_next_bow_body = body
	_next_bow_position = at
	_next_bow_direction = direction.normalized() if direction.length_squared() > 0.000001 else Vector2.UP
	_next_bow_width = maxf(1.5, width * 0.5 + 1.0)
	_next_bow_sweep = sweep
	# The ceiling covers the steady crest plus an entry's short-lived boost;
	# WaterWaveProfile keeps that sum inside the field's maximum offset.
	var ceiling := profile.bow_amplitude + profile.entry_kick_amplitude
	_next_bow_target = clampf(amplitude, 0.0, ceiling) if body != &"" else 0.0


## Advance old sources, then commit queued new ones at age zero. Zero is a valid
## commit-only step for deterministic fixtures; negative/non-finite time is ignored.
func step(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	clock_seconds += delta
	serial += 1
	for slot: Packet in _slots:
		if slot.active and clock_seconds - slot.born >= slot.life - 0.000000001:
			slot.active = false
		if slot.pending:
			slot.pending = false
			slot.active = true
			slot.born = clock_seconds
	if _bow_pending:
		if _next_bow_body != _bow_body:
			_bow_value = 0.0
		_bow_body = _next_bow_body
		_bow_position = _next_bow_position
		_bow_direction = _next_bow_direction
		_bow_width = _next_bow_width
		_bow_sweep = _next_bow_sweep
		_bow_target = _next_bow_target
		_bow_pending = false
	var response := profile.bow_rise_seconds if _bow_target > _bow_value else profile.bow_fall_seconds
	_bow_value = lerpf(_bow_value, _bow_target, 1.0 - exp(-delta / response))


func active_count() -> int:
	var count := 0
	for slot: Packet in _slots:
		count += 1 if slot.active else 0
	return count


func reset() -> void:
	clock_seconds = 0.0
	serial += 1
	skipped_packets = 0
	for slot: Packet in _slots:
		slot.active = false
		slot.pending = false
	_bow_body = &""
	_bow_value = 0.0
	_bow_target = 0.0
	_bow_pending = false


func write_snapshot(body: StringName, ambient_enabled: bool, into: WaterWaveSnapshot) -> void:
	into.serial = serial
	into.body_id = body
	into.shape = Vector4(profile.front_width, profile.front_speed, profile.core_radius, profile.radial_decay)
	into.envelope = Vector2(profile.onset_seconds, profile.fade_seconds)
	for index in 2:
		var direction := profile.ambient_direction_a if index == 0 else profile.ambient_direction_b
		var k := direction.normalized() * (TAU / profile.ambient_wavelengths[index])
		var phase := fposmod(profile.ambient_phases[index] - TAU \
			* fposmod(clock_seconds, profile.ambient_periods[index]) / profile.ambient_periods[index], TAU)
		into.ambient[index] = Vector4(k.x, k.y, profile.ambient_amplitudes[index] if ambient_enabled else 0.0, phase)
	for index in _slots.size():
		var slot := _slots[index]
		into.packets[index] = Vector4.ZERO
		into.directions[index] = Vector4.ZERO
		if not slot.active or slot.body_id != body:
			continue
		var age := clock_seconds - slot.born
		var centre := slot.origin + slot.current * age
		into.packets[index] = Vector4(centre.x, centre.y, age, slot.amplitude)
		into.directions[index] = Vector4(slot.direction.x, slot.direction.y, slot.life,
			1.0 if index >= WaterWaveProfile.ENTRY_SLOTS else -slot.entry_radius)
	into.bow = Vector4(_bow_position.x, _bow_position.y,
		_bow_value if body == _bow_body else 0.0, profile.bow_half_length)
	into.bow_direction = Vector4(_bow_direction.x, _bow_direction.y, _bow_width, _bow_sweep)
