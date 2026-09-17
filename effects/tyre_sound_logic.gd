class_name TyreSoundLogic
extends RefCounted
## How loud the tyre and surface sounds are (spec §5.3), from the four wheels:
## each wheel on the ground adds to its surface's rolling sound, mud also by
## wheelspin, and a sliding tyre on a skidding surface adds to the squeal.

## One wheel's share of each sound.
const WHEEL_SHARE := 0.25
const ROLL_SPEED := 25.0
## Rolling on asphalt is a quiet hum under the engine: it tops out at this loudness,
## reached at ROAD_SPEED (m/s), so it grows gently instead of drowning the car out.
const ROAD_MAX := 0.35
const ROAD_SPEED := 35.0
const MUD_SLIP := 8.0
const SKID_BASE := 0.3
const SKID_SLIP := 10.0
## Rock grinds under the engine: it tops out at this loudness, quieter than gravel.
const ROCK_MAX := 0.6


## wheels: one Dictionary per wheel with "feel" (SurfaceFeel or null in the air),
## "ground_speed", "slip_speed" and "sliding". Returns {"road", "gravel", "mud", "skid", "snow", "rock"}, each 0-1.
static func mix(wheels: Array[Dictionary]) -> Dictionary:
	var result := {"road": 0.0, "gravel": 0.0, "mud": 0.0, "skid": 0.0, "snow": 0.0, "rock": 0.0}
	for wheel in wheels:
		var feel: SurfaceFeel = wheel["feel"]
		if feel == null:
			continue
		var ground_speed: float = wheel["ground_speed"]
		var slip_speed: float = wheel["slip_speed"]
		var rolling := clampf(ground_speed / ROLL_SPEED, 0.0, 1.0) * WHEEL_SHARE
		match feel.rolling:
			SurfaceFeel.RollingSound.ROAD:
				result["road"] += clampf(ground_speed / ROAD_SPEED, 0.0, 1.0) * WHEEL_SHARE * ROAD_MAX
			SurfaceFeel.RollingSound.GRAVEL:
				result["gravel"] += rolling
			SurfaceFeel.RollingSound.SNOW:
				result["snow"] += rolling
			SurfaceFeel.RollingSound.MUD:
				result["mud"] += rolling + clampf(slip_speed / MUD_SLIP, 0.0, 1.0) * WHEEL_SHARE
			SurfaceFeel.RollingSound.ROCK:
				result["rock"] += rolling * ROCK_MAX
		if feel.skids and wheel["sliding"]:
			result["skid"] += clampf(SKID_BASE + slip_speed / SKID_SLIP, 0.0, 1.0) * WHEEL_SHARE * feel.skid_volume
	for key: String in result:
		result[key] = minf(result[key], 1.0)
	return result
