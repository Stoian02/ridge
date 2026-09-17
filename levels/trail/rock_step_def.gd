class_name RockStepDef
extends Resource
## A rock ledge the road climbs (M5 spec §6): the road's level rises by `height`
## at `distance` and stays up for the rest of the trail. Across
## lateral_from..lateral_to the rise is a vertical face topped by a short lip;
## outside that span the road ramps up over ramp_length beside it.
## Lateral positions are metres from the centre line (+ = right).

## The share of the height that is a vertical face. The rest is the lip: a slope
## over face_length that a wheel can ride up (a sphere-cast wheel cannot mount a
## face taller than the car's clearance).
const LEDGE_SHARE := 0.6

@export var distance: float = 0.0
@export_range(0.0, 1.0) var height: float = 0.35
@export var lateral_from: float = -6.5
@export var lateral_to: float = 6.5
## Depth of the rock lip on top of the face, along the road (m).
@export var face_length: float = 0.6
## The road beside the face climbs to the new level over this distance (m).
@export var ramp_length: float = 6.0
@export var color: Color = Color(0.62, 0.4, 0.31)
@export var seed: int = 53


## Whether `lateral` is inside the face's span.
func covers(lateral: float) -> bool:
	return lateral >= lateral_from and lateral <= lateral_to


## The road's rise at a point: nothing at or before the face; inside its span the
## vertical face's height then the lip climbing to the full height over
## face_length; beside the span the ramp.
func height_at(at: float, lateral: float) -> float:
	if at <= distance:
		return 0.0
	if covers(lateral):
		var lip := clampf((at - distance) / maxf(face_length, 0.001), 0.0, 1.0)
		return height * (LEDGE_SHARE + (1.0 - LEDGE_SHARE) * lip)
	return ramp_offset(at)


## The rise of the ramped road beside the face, which the terrain also follows.
func ramp_offset(at: float) -> float:
	return height * clampf((at - distance) / maxf(ramp_length, 0.001), 0.0, 1.0)
