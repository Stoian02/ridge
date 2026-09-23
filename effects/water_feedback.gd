class_name WaterFeedback
extends RefCounted
## Pure visual/audio decisions. These values never feed back into car forces.

const WASH_MAX := 0.35
const ENTRY_MAX := 0.50
const ENTRY_SPEED := 1.0
const ENTRY_COOLDOWN := 0.40
const WAKE_SPEED := 0.50
const DEEP_SPLASH_FADE := 0.30


static func wheel_splash(wetness: float, relative_speed: float, slip: float,
		upper_depth: float) -> float:
	var activity := clampf(relative_speed / 12.0 + minf(absf(slip), 8.0) / 16.0, 0.0, 1.0)
	var surface_fade := 1.0 - smoothstep(0.0, DEEP_SPLASH_FADE, upper_depth)
	return clampf(wetness, 0.0, 1.0) * activity * surface_fade


static func wash(wetness: float, relative_speed: float, slip: float) -> float:
	return WASH_MAX * clampf(wetness, 0.0, 1.0) \
		* clampf(relative_speed / 12.0 + minf(absf(slip), 8.0) / 24.0, 0.0, 1.0)


static func wake(relative_horizontal_speed: float, surface_weight: float) -> float:
	return smoothstep(WAKE_SPEED, 8.0, relative_horizontal_speed) * surface_weight


static func warning(sinking: bool, stalled: bool, restarting: bool, risk: bool) -> String:
	if sinking:
		return "Sinking — Reset available"
	if restarting:
		return "Restarting…"
	if stalled:
		return "Engine stalled"
	if risk:
		return "Intake at risk"
	return ""
