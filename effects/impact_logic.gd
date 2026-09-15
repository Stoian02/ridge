class_name ImpactLogic
extends RefCounted
## How hard a wheel hit something (spec §5.4), from 0 to 1: the suspension
## compressing fast, or reaching the bump stop.

const SOFT_SPEED := 1.2
const SPEED_RANGE := 3.0
const BOTTOMED_SHARE := 0.85
const BOTTOMED_STRENGTH := 0.6


## compression_speed: m/s, + while compressing.
static func strength(compression_speed: float, bottomed_out: bool) -> float:
	var hit := clampf((compression_speed - SOFT_SPEED) / SPEED_RANGE, 0.0, 1.0)
	return maxf(hit, BOTTOMED_STRENGTH) if bottomed_out else hit


## True when the wheel is within the last 15% of its travel.
static func is_bottomed_out(compression: float, travel: float) -> bool:
	return travel > 0.0 and compression > travel * BOTTOMED_SHARE
