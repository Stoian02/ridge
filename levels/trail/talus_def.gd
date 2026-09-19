class_name TalusDef
extends Resource
## A field of loose stones that move when pushed (M5 spec §8): one rigid body
## each, sized to be shoved aside rather than climbed. Distances are metres along the road.

@export var start: float = 0.0
@export var length: float = 100.0
@export var count: int = 40
## Stone radii (m).
@export var size_range: Vector2 = Vector2(0.18, 0.32)
## Vertical scale of both mesh and hull. Flatter fragments are less prone to
## becoming chassis-height wedges; 1 retains the original rounded stones.
@export_range(0.2, 1.5) var height_scale: float = 1.0
## Swept collision for small fragments pushed quickly by tyres; prevents them
## skipping through a thin floor between physics ticks.
@export var continuous_collision: bool = false
## Stone masses (kg): light enough that the 2150 kg 4x4 pushes through.
@export var mass_range: Vector2 = Vector2(30.0, 120.0)
## How far from the centre line stones may sit (m); alternate stones go left and right.
@export var lateral_range: Vector2 = Vector2(0.0, 4.0)
@export var color: Color = Color(0.66, 0.5, 0.4)
@export var seed: int = 71
## Contact friction of the stone hull, not the tyre/surface grip table.
@export_range(0.0, 1.0) var contact_friction: float = 1.0
## Opt-in dense placement: no overlapping hull footprints, including boulders.
@export var avoid_overlap: bool = false
## Fill the road's changing width, leaving only each stone's edge clearance.
@export var cover_road: bool = false
## Fine, non-colliding gravel shading between the actual movable fragments.
@export var gravel_bed: bool = false


func end() -> float:
	return start + length
