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
