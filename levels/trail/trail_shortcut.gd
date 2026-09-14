class_name TrailShortcut
extends Resource
## One narrow worn path branching from a trail and rejoining it later. Distances
## run along the main road; lateral offset is measured from its centre line.

@export var start: float = 0.0
@export var length: float = 100.0
@export_range(-1.0, 1.0) var side: float = -1.0
@export var lateral_offset: float = 12.0
@export var width: float = 4.0
@export var entry_length: float = 20.0
@export var exit_length: float = 20.0
@export var color: Color = Color(0.48, 0.56, 0.3)

@export_group("Roughness")
@export var washboard_amplitude: float = 0.08
@export var washboard_wavelength: float = 2.8
@export var undulation_amplitude: float = 0.1
@export var undulation_wavelengths: Vector2 = Vector2(6.5, 11.0)
@export var pothole_spacing: float = 9.0
@export var pothole_radius_range: Vector2 = Vector2(0.6, 1.0)
@export var pothole_depth_range: Vector2 = Vector2(0.12, 0.22)
@export var rough_fade: float = 20.0
@export var seed: int = 1


func end() -> float:
	return start + length
