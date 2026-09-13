class_name ScatterDef
extends Resource
## Settings for scenery placed around a trail.

## Average distance between pines (m); 12.2 m is about one per 150 m².
@export var pine_spacing: float = 12.2
## Average distance between rocks (m); 17.3 m is about one per 300 m².
@export var rock_spacing: float = 17.3
## Nothing is placed closer than this to a shoulder edge (m).
@export var road_clearance: float = 6.0
## Nothing is placed on slopes steeper than this (degrees).
@export var max_slope_deg: float = 35.0
## Pines further than this from the camera are not drawn (m).
@export var pine_view_distance: float = 300.0
## Rocks further than this from the camera are not drawn (m).
@export var rock_view_distance: float = 150.0
## Distance between roadside posts (m).
@export var post_spacing: float = 25.0
## Posts go on a side where the terrain falls more than this within 10 m of the edge (m).
@export var post_drop: float = 2.0
## Rocks within this distance of a shoulder edge get collision (m).
@export var rock_collision_distance: float = 30.0
@export var foliage_color: Color = Color(0.33, 0.4, 0.24)
@export var trunk_color: Color = Color(0.36, 0.26, 0.18)
@export var rock_color: Color = Color(0.55, 0.45, 0.38)
@export var post_color: Color = Color(0.93, 0.92, 0.88)
@export var reflector_color: Color = Color(0.95, 0.45, 0.1)
@export var seed: int = 11
