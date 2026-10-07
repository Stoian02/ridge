class_name CoastalEarthworks
extends RefCounted
## Replaces only opted-in natural ground, before road/structure carving.
## Workers receive immutable value snapshots; no shared Resource calls per sample.

static func fill(field: TerrainField, coast: CoastalTerrainDef, threaded: bool) -> void:
	assert(coast.validation_error().is_empty(), coast.validation_error())
	var inputs: Array[Dictionary] = []
	var results: Array[Dictionary] = []
	for first in range(0, field.rows, 32):
		var input := coast.snapshot()
		input.merge({"first": first, "count": mini(32, field.rows - first),
			"columns": field.columns, "origin": field.origin, "spacing": field.spacing})
		inputs.append(input)
		results.append({})
	var work := func(i: int) -> void: compute(inputs[i], results[i])
	if threaded:
		var task := WorkerThreadPool.add_group_task(work, inputs.size(), -1, true, "Coastal ground")
		WorkerThreadPool.wait_for_group_task_completion(task)
	else:
		for i in inputs.size():
			work.call(i)
	field.heights.clear()
	for result: Dictionary in results:
		field.heights.append_array(result.heights)


static func compute(input: Dictionary, into: Dictionary) -> void:
	var shore: Array[Vector4] = input.shore
	var hills: Array[Vector4] = input.hills
	var low: float = input.low
	var relief: float = input.relief
	var first: int = input.first
	var count: int = input.count
	var columns: int = input.columns
	var origin: Vector2 = input.origin
	var spacing: float = input.spacing
	var heights := PackedFloat32Array()
	heights.resize(count * columns)
	var segment := 0
	for row in range(first, first + count):
		var z := origin.y + row * spacing
		while segment < shore.size() - 2 and z > shore[segment + 1].x:
			segment += 1
		var a := shore[segment]
		var b := shore[segment + 1]
		var t := smoothstep(a.x, b.x, z)
		var edge := lerpf(a.y, b.y, t)
		var plateau := lerpf(a.z, b.z, t)
		var width := lerpf(a.w, b.w, t)
		for column in columns:
			var x := origin.x + column * spacing
			var inland := edge - x
			var land := smoothstep(0.0, width, inland)
			var height := plateau
			for hill: Vector4 in hills:
				var distance := Vector2(x - hill.x, z - hill.y).length()
				var weight := 1.0 - smoothstep(0.0, hill.z, distance)
				height += hill.w * weight
			# Broad relief, not random craters or repeated road-shaped terraces.
			height += relief * sin(x * 0.029 + sin(z * 0.012)) * sin(z * 0.035)
			heights[(row - first) * columns + column] = lerpf(low, height, land)
	into.heights = heights
