class_name TerrainDef
extends Resource
## Settings for the mountainside generated around a trail.

@export var surface: SurfaceDef = preload("res://surfaces/dirt.tres")

## Terrain extends this far past the road on every side (m).
@export var margin: float = 300.0
## Size of one terrain chunk (m). Chunks share their border samples.
@export var chunk_size: float = 128.0
## Distance between height samples (m).
@export var sample_spacing: float = 2.0
## Width outside the shoulder edge over which terrain blends back to natural (m).
@export var corridor_blend: float = 25.0
## Terrain sits this far below the road under the asphalt (m).
@export var under_road_drop: float = 0.3
## How far along and across the road its elevation is averaged when shaping
## the terrain (m). Keeps switchback legs from producing steps between them.
@export var smoothing_radius: float = 12.0
## Natural mountainside noise.
@export var noise_amplitude: float = 20.0
@export var noise_wavelength: float = 200.0
@export var noise_octaves: int = 4
## Slopes steeper than this are coloured as rock (degrees).
@export var rock_slope_deg: float = 35.0
## Beyond this distance from the camera terrain is drawn from every second
## height sample, a quarter of the triangles (m). Collision always uses every sample.
@export var detail_distance: float = 200.0
## Terrain chunks further than this from the camera are not drawn (m).
@export var view_distance: float = 500.0
## The car is reset when it falls this far below the lowest terrain (m).
@export var kill_depth: float = 30.0
@export var dirt_color: Color = Color(0.62, 0.47, 0.3)
@export var rock_color: Color = Color(0.55, 0.45, 0.38)
@export var seed: int = 7

@export_group("Canyon walls")
## Sections where the ground beyond the corridor blend is raised into a wall
## or dropped away, as Vector4(start, length, left delta, right delta): metres
## along the road, then metres up (+) or down (-) relative to the road on each
## side. Deltas ease in and out over wall_blend inside each end.
@export var wall_sections: Array[Vector4] = []
@export var wall_blend: float = 25.0
## Local sandstone ledges and layered colour, as (start, length). Empty preserves
## the plain walls elsewhere; this adds no meshes, textures or draw calls.
@export var terraced_wall_sections: Array[Vector2] = []


func terrace_weight(distance: float) -> float:
	var weight := 0.0
	for section: Vector2 in terraced_wall_sections:
		var blend := maxf(wall_blend, 0.001)
		weight = maxf(weight, minf(smoothstep(section.x, section.x + blend, distance),
				1.0 - smoothstep(section.x + section.y - blend, section.x + section.y, distance)))
	return weight


## The wall delta at `distance` on `side` (-1 = left, +1 = right): the covering
## section's delta eased over wall_blend inside each of its ends, 0 elsewhere.
func wall_delta(distance: float, side: float) -> float:
	var total := 0.0
	for section: Vector4 in wall_sections:
		var end := section.x + section.y
		if distance < section.x or distance >= end:
			continue
		var blend := maxf(wall_blend, 0.001)
		var weight := minf(smoothstep(section.x, section.x + blend, distance),
				1.0 - smoothstep(end - blend, end, distance))
		total += (section.w if side > 0.0 else section.z) * weight
	return total


func has_walls() -> bool:
	return wall_sections.any(func(section: Vector4) -> bool: return section.z != 0.0 or section.w != 0.0)
