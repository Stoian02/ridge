class_name EngineSoundLogic
extends RefCounted
## The engine sound's two layers (spec §5.2): a low loop recorded at 1500 rpm and a
## high loop at 4500 rpm, each pitched by rpm and cross-faded between 2000 and
## 4000 rpm. Throttle makes it louder; a gear shift dips it.

const LOW_RPM := 1500.0
const HIGH_RPM := 4500.0
const PITCH_MIN := 0.5
const PITCH_MAX := 2.0
const BLEND_FROM := 2000.0
const BLEND_TO := 4000.0
const BASE_VOLUME := 0.45
const THROTTLE_VOLUME := 0.55
const SHIFT_DIP := 0.6


## Returns {"low_pitch", "low_volume", "high_pitch", "high_volume"}; volumes are linear 0-1.
static func layers(rpm: float, throttle: float, shifting: bool) -> Dictionary:
	var blend := smoothstep(BLEND_FROM, BLEND_TO, rpm)
	var loudness := (BASE_VOLUME + THROTTLE_VOLUME * clampf(throttle, 0.0, 1.0)) * (SHIFT_DIP if shifting else 1.0)
	return {
		"low_pitch": clampf(rpm / LOW_RPM, PITCH_MIN, PITCH_MAX),
		"low_volume": (1.0 - blend) * loudness,
		"high_pitch": clampf(rpm / HIGH_RPM, PITCH_MIN, PITCH_MAX),
		"high_volume": blend * loudness,
	}
