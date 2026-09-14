class_name CurveGenerator
extends RefCounted
## Builds a trail's centre-line curve from a list of segments, checks that parts
## of the road far apart along it don't pass too close in space, and saves it.
## Each level's tools/generate_*_curve.gd holds only its segment list.
## Each segment is [kind, ...]:
##   ["straight", length_m, grade]
##   ["arc", radius_m, turn_deg (+ = left), grade]
## Grade is rise over run (0.12 = 12% up, -0.08 = 8% down). Arcs are split into
## 30-degree Bezier pieces so hairpins stay round.

## Parts of the road further apart than this along it must stay this far apart in space (m).
const MIN_SEPARATION := 28.0
const SEPARATION_CHECK_GAP := 80.0


## Builds, checks and saves a curve; returns OK or an error code for SceneTree.quit.
static func generate(segments: Array, output: String, level_name: String) -> int:
	var curve := build_curve(segments)
	var problems := separation_problems(curve)
	if not problems.is_empty():
		push_error("%s parts pass too close: %s" % [level_name, problems.slice(0, 5)])
		return FAILED
	var error := ResourceSaver.save(curve, output)
	var ends := [curve.get_point_position(0).y, curve.get_point_position(curve.point_count - 1).y]
	var heights := Array(curve.get_baked_points()).map(func(p: Vector3) -> float: return p.y)
	print("saved %s: %d points, %.0f m long, ends %+.0f m, lowest %+.0f m, highest %+.0f m" % [output,
			curve.point_count, curve.get_baked_length(), ends[1] - ends[0], heights.min(), heights.max()])
	return error


static func build_curve(segments: Array) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	var position := Vector3.ZERO
	var heading := 0.0  # radians; 0 = -Z, positive turns left
	curve.add_point(position)
	for segment in segments:
		if segment[0] == "straight":
			var direction := _direction(heading)
			var length: float = segment[1]
			var end := position + direction * length + Vector3(0.0, length * segment[2], 0.0)
			_set_out_handle(curve, (end - position) / 3.0)
			curve.add_point(end, -(end - position) / 3.0)
			position = end
		else:
			var radius: float = segment[1]
			var turn := deg_to_rad(segment[2])
			var grade: float = segment[3]
			var pieces := maxi(1, ceili(absf(turn) / deg_to_rad(30.0)))
			var piece_turn := turn / pieces
			var handle_length := 4.0 / 3.0 * tan(absf(piece_turn) / 4.0) * radius
			for i in pieces:
				var start_direction := _direction(heading)
				var arc_length := absf(piece_turn) * radius
				var chord_centre := position + _left(heading) * radius * signf(piece_turn)
				var end_heading := heading + piece_turn
				var flat_end := chord_centre - _left(end_heading) * radius * signf(piece_turn)
				var end := Vector3(flat_end.x, position.y + arc_length * grade, flat_end.z)
				var rise := arc_length * grade / 3.0
				_set_out_handle(curve, start_direction * handle_length + Vector3(0.0, rise, 0.0))
				curve.add_point(end, -_direction(end_heading) * handle_length - Vector3(0.0, rise, 0.0))
				position = end
				heading = end_heading
	return curve


## Pairs of road points far apart along the road but close in space.
static func separation_problems(curve: Curve3D) -> Array:
	var points := curve.get_baked_points()
	var problems := []
	var step := 5
	for i in range(0, points.size(), step):
		for j in range(i + int(SEPARATION_CHECK_GAP), points.size(), step):
			var flat := Vector2(points[i].x - points[j].x, points[i].z - points[j].z).length()
			if flat < MIN_SEPARATION:
				problems.append("%d m and %d m are %.1f m apart" % [i, j, flat])
	return problems


static func _direction(heading: float) -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


static func _left(heading: float) -> Vector3:
	return Vector3(-cos(heading), 0.0, sin(heading))


static func _set_out_handle(curve: Curve3D, handle: Vector3) -> void:
	curve.set_point_out(curve.point_count - 1, handle)
