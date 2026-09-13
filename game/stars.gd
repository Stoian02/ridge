class_name Stars
extends RefCounted
## Stars for a run (spec §5.2): one for finishing, two under the level's two-star
## time, three under its three-star time. A time exactly on a target doesn't beat it.

const MAX := 3


## Stars for a finish in `time` seconds; a negative time (no finish) earns none.
static func for_time(time: float, level: LevelDef) -> int:
	if time < 0.0:
		return 0
	if time < level.three_star_time:
		return 3
	if time < level.two_star_time:
		return 2
	return 1
