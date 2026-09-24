class_name WaterSample
extends RefCounted
## Reused query result. Valid describes a finite water column, not immersion.

var valid: bool = false
var surface_y: float = 0.0
## Static mean height for source detection; physics always uses surface_y.
var rest_surface_y: float = 0.0
var bed_y: float = 0.0
var current: Vector3 = Vector3.ZERO
var edge_weight: float = 0.0
var body_id: StringName = &""
var color: Color = Color.TRANSPARENT


func clear() -> void:
	valid = false
	surface_y = 0.0
	rest_surface_y = 0.0
	bed_y = 0.0
	current = Vector3.ZERO
	edge_weight = 0.0
	body_id = &""
	color = Color.TRANSPARENT


func copy_from(other: WaterSample) -> void:
	valid = other.valid
	surface_y = other.surface_y
	rest_surface_y = other.rest_surface_y
	bed_y = other.bed_y
	current = other.current
	edge_weight = other.edge_weight
	body_id = other.body_id
	color = other.color
