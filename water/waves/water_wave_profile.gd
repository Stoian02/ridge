class_name WaterWaveProfile
extends Resource
## Wave-only starting values. Never changes a car, bed or steady current.

const ENTRY_SLOTS := 4
const WAKE_SLOTS := 12
const PACKET_SLOTS := ENTRY_SLOTS + WAKE_SLOTS

@export var mesh_pitch: float = 0.75
@export var maximum_offset: float = 0.12
@export var depth_fraction: float = 0.20
@export var shore_distance: float = 1.5
@export var ambient_amplitudes: Vector2 = Vector2(0.025, 0.015)
@export var ambient_wavelengths: Vector2 = Vector2(8.0, 5.0)
@export var ambient_periods: Vector2 = Vector2(3.6, 2.5)
@export var ambient_direction_a: Vector2 = Vector2(1.0, 0.35)
@export var ambient_direction_b: Vector2 = Vector2(-0.3, 1.0)
@export var ambient_phases: Vector2 = Vector2(0.0, 1.3)
@export var entry_life: float = 4.0
@export var wake_life: float = 3.0
@export var onset_seconds: float = 0.12
@export var fade_seconds: float = 0.75
@export var front_width: float = 1.5
@export var front_speed: float = 2.0
@export var core_radius: float = 0.5
@export var radial_decay: float = 0.15
@export var entry_amplitude: float = 0.08
@export var wake_amplitude: float = 0.03
@export var bow_amplitude: float = 0.05
@export var bow_half_length: float = 1.5
@export var bow_rise_seconds: float = 0.12
@export var bow_fall_seconds: float = 0.40


func is_valid() -> bool:
	for value: float in [mesh_pitch, maximum_offset, depth_fraction, shore_distance,
			ambient_wavelengths.x, ambient_wavelengths.y, ambient_periods.x, ambient_periods.y,
			entry_life, wake_life, onset_seconds, fade_seconds, front_width, front_speed,
			core_radius, bow_half_length, bow_rise_seconds, bow_fall_seconds]:
		if not is_finite(value) or value <= 0.0:
			return false
	for value: float in [ambient_amplitudes.x, ambient_amplitudes.y, radial_decay,
			entry_amplitude, wake_amplitude, bow_amplitude]:
		if not is_finite(value) or value < 0.0:
			return false
	return maximum_offset <= 0.12 and depth_fraction <= 0.20 \
		and ambient_phases.is_finite() and ambient_direction_a.is_finite() \
		and ambient_direction_b.is_finite() and ambient_direction_a.length_squared() > 0.0 \
		and ambient_direction_b.length_squared() > 0.0
