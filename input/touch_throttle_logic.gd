class_name TouchThrottleLogic
extends RefCounted
## Absolute touch throttle: bottom is closed, top is full, horizontal drift ignored.

enum Mode { PEDAL, LEVER }

## The bottom 10% gives the thumb a definite closed position.
const DEAD_ZONE := 0.1


static func value_for(rect: Rect2, point: Vector2) -> float:
	if rect.size.y <= 0.0:
		return 0.0
	var value := clampf((rect.end.y - point.y) / rect.size.y, 0.0, 1.0)
	return 0.0 if value <= DEAD_ZONE else value
