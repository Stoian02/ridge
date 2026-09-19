class_name BoulderFieldDef
extends Resource
## A seeded cluster of fixed boulders and tilted slabs on and beside the road
## (M5 spec §7). Distances are metres along the road.

@export var start: float = 0.0
@export var length: float = 100.0
@export var count: int = 20
## Radii of boulders on the road (m). 0.30-0.45 lifts the rally cars and lets the 4x4 climb (spec §7.3).
@export var size_range: Vector2 = Vector2(0.3, 0.45)
## Radii of boulders beyond the shoulders, which are scenery and walls to the line (m).
@export var off_road_size_range: Vector2 = Vector2(0.6, 1.2)
## Sink the hull into its supporting surface (m), exposing broad crawlable
## crowns on large bed stones. Zero preserves existing fields exactly.
@export_range(0.0, 1.0) var burial_depth: float = 0.0
## How far from the centre line boulders may sit (m); alternate boulders go left and right.
@export var lateral_range: Vector2 = Vector2(0.0, 9.0)
## Share built as low tilted slabs instead of rounded boulders.
@export_range(0.0, 1.0) var slab_fraction: float = 0.25
@export var color: Color = Color(0.62, 0.4, 0.31)
@export var seed: int = 61


func end() -> float:
	return start + length
