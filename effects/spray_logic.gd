class_name SprayLogic
extends RefCounted
## How hard a wheel sprays (spec §4.1), from 0 to 1: mud clods from wheelspin and
## speed, dust from speed, a water sheet from speed and wheelspin, and tyre smoke
## only while the tyre slides.

## Below this intensity a spray stops emitting.
const THRESHOLD := 0.05
const CLODS_SLIP := 6.0
const CLODS_SPEED_FROM := 3.0
const CLODS_SPEED_RANGE := 15.0
const CLODS_SPEED_SHARE := 0.5
const DUST_SPEED_FROM := 4.0
const DUST_SPEED_RANGE := 16.0
const DUST_SLIP := 10.0
const DUST_SLIP_SHARE := 0.4
const SMOKE_BASE := 0.3
const SMOKE_SLIP := 8.0
const SPLASH_SPEED_FROM := 1.0
const SPLASH_SPEED_RANGE := 10.0
const SPLASH_SLIP_SHARE := 0.5


## ground_speed: how fast the contact point moves over the ground (m/s).
## slip_speed: the gap between tread speed and ground speed (m/s).
static func intensity(kind: SurfaceFeel.SprayKind, ground_speed: float, slip_speed: float, sliding: bool) -> float:
	match kind:
		SurfaceFeel.SprayKind.CLODS:
			return minf(clampf(slip_speed / CLODS_SLIP, 0.0, 1.0)
					+ clampf((ground_speed - CLODS_SPEED_FROM) / CLODS_SPEED_RANGE, 0.0, CLODS_SPEED_SHARE), 1.0)
		SurfaceFeel.SprayKind.DUST:
			return minf(clampf((ground_speed - DUST_SPEED_FROM) / DUST_SPEED_RANGE, 0.0, 1.0)
					+ clampf(slip_speed / DUST_SLIP, 0.0, DUST_SLIP_SHARE), 1.0)
		SurfaceFeel.SprayKind.SMOKE:
			return clampf(SMOKE_BASE + slip_speed / SMOKE_SLIP, 0.0, 1.0) if sliding else 0.0
		SurfaceFeel.SprayKind.SPLASH:
			return minf(clampf((ground_speed - SPLASH_SPEED_FROM) / SPLASH_SPEED_RANGE, 0.0, 1.0)
					+ clampf(slip_speed / CLODS_SLIP, 0.0, SPLASH_SLIP_SHARE), 1.0)
	return 0.0
