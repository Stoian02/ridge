extends SceneTree
## B1 dry greybox: upper road, uninterrupted jump run-up, descent hairpins,
## cove, reserved bridge, climbing S-bends and headland finish. No water/art.

const OUTPUT := "res://levels/coastal_highway/coastal_highway_curve.tres"
const SEGMENTS := [
	["straight", 140, 0.01],
	["arc", 120, 60, 0],
	["straight", 80, -0.01],
	["arc", 100, -60, 0],
	["straight", 149.61653873674845, 0],
	["straight", 420, 0],
	["arc", 28, 55, -0.068],
	["straight", 25, -0.068],
	["arc", 18, -160, -0.068],
	["straight", 75, -0.068],
	["arc", 18, 160, -0.068],
	["straight", 102.59096460441378, -0.068],
	["arc", 60, -70, 0],
	["straight", 100, 0],
	["arc", 32, 90, 0],
	["straight", 60, 0],
	["arc", 50, -90, 0],
	["straight", 80, 0],
	["arc", 70, 80, 0],
	["straight", 60.15243450737421, 0],
	["arc", 90, -50, 0],
	["straight", 70, 0],
	["arc", 85, 55, 0],
	["straight", 69.86604112952, 0],
	["arc", 40, -80, 0.06],
	["straight", 35, 0.06],
	["arc", 32, 100, 0.06],
	["straight", 25, 0.06],
	["arc", 45, -90, 0.06],
	["straight", 57.61309316659208, 0.06],
	["straight", 75, 0.02],
	["arc", 90, 60, 0.02],
	["straight", 80, 0.015],
	["arc", 110, -60, 0.015],
	["straight", 85.56048976068041, 0.01],
]


static func build_curve() -> Curve3D:
	var curve := CurveGenerator.build_curve(SEGMENTS)
	for i in curve.point_count:
		curve.set_point_position(i, curve.get_point_position(i) + Vector3.UP * 24.0)
	return curve


func _init() -> void:
	var curve := build_curve()
	var problems := CurveGenerator.separation_problems(curve)
	if not problems.is_empty():
		push_error("Coastal route separation: %s" % [problems.slice(0, 5)])
		quit(FAILED)
		return
	var error := ResourceSaver.save(curve, OUTPUT)
	print("Coastal greybox: %.3f m, %d points, separation problems %d" % [
		curve.get_baked_length(), curve.point_count, problems.size()])
	quit(error)
