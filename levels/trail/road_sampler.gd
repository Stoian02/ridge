class_name RoadSampler
extends RefCounted
## Answers questions about a road's centre line: where the road is at a
## distance, which way it faces, and how far a world point is from it.
## Forward follows the road; right is across it; up is the road surface's
## normal, including any banking set as curve tilt.

var curve: Curve3D
var length: float
var use_curve_banking: bool
## The trail whose width profile half_width_at follows; a default TrailDef when none is given.
var trail: TrailDef


func _init(road_curve: Curve3D, banking: bool = true, trail_def: TrailDef = null) -> void:
	curve = road_curve
	length = curve.get_baked_length()
	use_curve_banking = banking
	trail = trail_def if trail_def != null else TrailDef.new()


## Half the road plus one shoulder at `distance`, following the trail's width stretches.
func half_width_at(distance: float) -> float:
	return trail.half_total_width_at(distance)


## Half the road alone at `distance`.
func road_half_width_at(distance: float) -> float:
	return trail.road_width_at(distance) * 0.5


func position(distance: float) -> Vector3:
	return curve.sample_baked(clampf(distance, 0.0, length), true)


func forward(distance: float) -> Vector3:
	return (position(distance + 0.5) - position(distance - 0.5)).normalized()


func up(distance: float) -> Vector3:
	var tilted_up: Vector3 = curve.sample_baked_up_vector(clampf(distance, 0.0, length), true) if use_curve_banking else Vector3.UP
	var along := forward(distance)
	return (tilted_up - along * tilted_up.dot(along)).normalized()


func right(distance: float) -> Vector3:
	return forward(distance).cross(up(distance)).normalized()


## Distance along the road of the centre-line point nearest to `point`.
func closest_distance(point: Vector3) -> float:
	return curve.get_closest_offset(point)


## Signed distance of `point` from the centre line, measured across the road
## at its nearest point (+ = right of the road).
func lateral_offset(point: Vector3) -> float:
	var distance := closest_distance(point)
	return (point - position(distance)).dot(right(distance))


## A point on the road surface.
func surface_point(distance: float, lateral: float, profile: RoadProfile) -> Vector3:
	return position(distance) + right(distance) * lateral + up(distance) * profile.height(distance, lateral)


## A transform on the road's centre at `distance`, facing along the road,
## `height_above` metres above the surface.
func transform_at(distance: float, height_above: float, profile: RoadProfile) -> Transform3D:
	var along := forward(distance)
	var surface_up := up(distance)
	var origin := surface_point(distance, 0.0, profile) + surface_up * height_above
	return Transform3D(Basis.looking_at(along, surface_up), origin)
