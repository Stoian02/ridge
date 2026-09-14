class_name TrailShortcut
extends Resource
## One narrow worn path branching from a trail and rejoining it later. Distances
## run along the main road; lateral offset is measured from its centre line.

@export var start: float = 0.0
@export var length: float = 100.0
@export_range(-1.0, 1.0) var side: float = -1.0
## Average distance from the road's centre line to the path's centre (m).
@export var lateral_offset: float = 12.0
## Average width of the path's worn middle (m).
@export var width: float = 4.0
@export var entry_length: float = 20.0
@export var exit_length: float = 20.0
@export var color: Color = Color(0.48, 0.56, 0.3)

@export_group("Shape")
## The path wanders this far either side of lateral_offset (m).
@export var meander_amplitude: float = 2.0
## The two summed wander wavelengths (m).
@export var meander_wavelengths: Vector2 = Vector2(47.0, 83.0)
## The worn middle is this much wider or narrower than `width` at most (m).
@export var width_variation: float = 0.7
@export var width_wavelength: float = 31.0
## The path's edges fade into the grass over this width either side (m).
@export var edge_blend: float = 1.5
## At each join the path's colour fades from road dirt to worn grass over this length (m).
@export var join_color_length: float = 15.0

@export_group("Roughness")
@export var washboard_amplitude: float = 0.015
@export var washboard_wavelength: float = 2.8
@export var undulation_amplitude: float = 0.03
@export var undulation_wavelengths: Vector2 = Vector2(6.5, 11.0)
@export var pothole_spacing: float = 18.0
@export var pothole_radius_range: Vector2 = Vector2(0.6, 1.0)
@export var pothole_depth_range: Vector2 = Vector2(0.12, 0.22)
## Average distance between stones along the path (m); 0 = none.
@export var stone_spacing: float = 1.2
## Stones are short, sharp bumps of these heights and radii (m).
@export var stone_height_range: Vector2 = Vector2(0.08, 0.15)
@export var stone_radius_range: Vector2 = Vector2(0.2, 0.4)
## Share of stones drawn with a half-buried rock.
@export_range(0.0, 1.0) var visible_stone_share: float = 0.35
@export var stone_color: Color = Color(0.5, 0.47, 0.42)
## Roughness fades in over this distance from each end (m).
@export var rough_fade: float = 20.0
@export var seed: int = 1


func end() -> float:
	return start + length
