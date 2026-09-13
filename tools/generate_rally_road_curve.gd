extends SceneTree
## Builds Rally Road's centre-line curve from a list of segments and saves it as
## levels/rally_road/rally_road_curve.tres. Re-run after changing SEGMENTS:
##   godot --headless -s tools/generate_rally_road_curve.gd
## Each segment is [kind, ...]:
##   ["straight", length_m, grade]
##   ["arc", radius_m, turn_deg (+ = left), grade]
## Grade is rise over run (0.12 = 12%). Arcs are split into 30-degree Bezier
## pieces so hairpins stay round.

const OUTPUT := "res://levels/rally_road/rally_road_curve.tres"
## Parts of the road further apart than this along it must stay this far apart in space (m).
const MIN_SEPARATION := 28.0
const SEPARATION_CHECK_GAP := 80.0

const SEGMENTS := [
	["straight", 80.0, 0.01],     # start straight in the valley
	["arc", 120.0, 35.0, 0.04],
	["straight", 60.0, 0.04],
	["arc", 150.0, -45.0, 0.04],
	["straight", 130.0, 0.04],    # jump 1 at ~440 m, pothole cluster at ~250 m
	["arc", 100.0, 40.0, 0.04],
	["straight", 70.0, 0.04],     # checkpoint at 600 m
	["straight", 90.0, 0.03],     # rough stretch 680-830 m begins
	["arc", 200.0, -20.0, 0.03],
	["straight", 80.0, 0.03],
	["arc", 45.0, 50.0, 0.08],    # esses
	["arc", 45.0, -60.0, 0.08],
	["straight", 30.0, 0.08],
	["arc", 15.0, 180.0, 0.06],   # hairpin 1
	["straight", 80.0, 0.12],     # pothole cluster at ~1050 m
	["arc", 15.0, -180.0, 0.06],  # hairpin 2
	["straight", 80.0, 0.12],     # checkpoint at 1200 m
	["arc", 15.0, 180.0, 0.06],   # hairpin 3
	["straight", 60.0, 0.08],
	["straight", 120.0, 0.02],    # ridge straight, jump 2 at ~1380 m
	["arc", 200.0, -15.0, 0.02],
	["straight", 20.0, 0.0],      # finish overlooking the valley
]


func _init() -> void:
	var curve := build_curve(SEGMENTS)
	var problems := separation_problems(curve)
	if not problems.is_empty():
		push_error("Rally Road parts pass too close: %s" % [problems.slice(0, 5)])
		quit(1)
		return
	var error := ResourceSaver.save(curve, OUTPUT)
	print("saved %s: %d points, %.0f m long, climbs %.0f m" % [OUTPUT, curve.point_count,
			curve.get_baked_length(), curve.get_point_position(curve.point_count - 1).y])
	quit(0 if error == OK else 1)


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
