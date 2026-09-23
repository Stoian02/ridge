class_name CanyonWallData
extends RefCounted
## One terrain row band, with original 1 m wall stamps and tie/rounding order.
## Workers own their outputs and read only flat, immutable input arrays.


static func compute(input: Dictionary, into: Dictionary) -> void:
	var points: PackedVector3Array = input["points"]
	var flats: PackedVector2Array = input["flats"]
	var distances: PackedFloat64Array = input["distances"]
	var halves: PackedFloat64Array = input["halves"]
	var banks: PackedFloat64Array = input["banks"]
	var lefts: PackedFloat64Array = input["lefts"]
	var rights: PackedFloat64Array = input["rights"]
	var terrace_weights: PackedFloat64Array = input["terraces"]
	var first: int = input["first"]
	var count: int = input["count"]
	var columns: int = input["columns"]
	var spacing: float = input["spacing"]
	var origin: Vector2 = input["origin"]
	var reach: float = input["reach"]
	var blend: float = input["blend"]
	var shaped: bool = input["shaped"]
	var wall_edges := PackedFloat32Array()
	var wall_deltas := PackedFloat32Array()
	var wall_heights := PackedFloat32Array()
	var terraces := PackedFloat32Array()
	var setbacks := PackedFloat32Array()
	wall_edges.resize(count * columns)
	wall_edges.fill(TerrainField.FAR)
	wall_deltas.resize(count * columns)
	wall_heights.resize(count * columns)
	if shaped:
		terraces.resize(count * columns)
		setbacks.resize(count * columns)
	for s in points.size():
		var centre := points[s]
		var flat := flats[s]
		# Conservative band cull only. The inner loop still takes every old stamp.
		var z_reach := absf(flat.y) * reach + spacing
		if centre.z + z_reach < origin.y + first * spacing or centre.z - z_reach > origin.y + (first + count) * spacing:
			continue
		var distance := distances[s]
		var half := halves[s]
		var bank := banks[s]
		var terrace := terrace_weights[s]
		var lateral := -reach
		while lateral <= reach:
			var delta := rights[s] if lateral > 0.0 else lefts[s]
			var edge := absf(lateral) - half
			if delta != 0.0 and edge >= blend:
				var column := roundi((centre.x + flat.x * lateral - origin.x) / spacing)
				var row := roundi((centre.z + flat.y * lateral - origin.y) / spacing)
				if column >= 0 and column < columns and row >= first and row < first + count:
					var i := (row - first) * columns + column
					if edge < wall_edges[i]:
						wall_edges[i] = edge
						wall_deltas[i] = delta
						wall_heights[i] = centre.y + lateral * bank
						if shaped:
							terraces[i] = terrace
							var phase := 1.7 if lateral > 0.0 else 0.0
							setbacks[i] = terrace * (4.0 + 2.5 * sin(distance * 0.071 + phase)
									+ 1.5 * sin(distance * 0.19 + phase))
			lateral += TerrainField.WALL_STEP
	var stamps: Array[Vector3] = input["stamps"]
	var half_widths: PackedFloat32Array = input["half_widths"]
	var protected_edge := blend + spacing * sqrt(2.0)
	var full_edge := maxf(blend + TerrainField.WALL_RISE, protected_edge + spacing)
	var clearances := PackedFloat32Array()
	clearances.resize(count * columns)
	clearances.fill(TerrainField.FAR)
	for s in maxi(1, stamps.size() - 1):
		var next := mini(s + 1, stamps.size() - 1)
		var start := Vector2(stamps[s].x, stamps[s].z)
		var segment := Vector2(stamps[next].x, stamps[next].z) - start
		var length_squared := segment.length_squared()
		var half_width := maxf(half_widths[s], half_widths[next])
		var radius := half_width + full_edge + segment.length()
		var grid_reach := ceili(radius / spacing)
		var centre_column := roundi((start.x - origin.x) / spacing)
		var centre_row := roundi((start.y - origin.y) / spacing)
		if centre_row + grid_reach < first or centre_row - grid_reach >= first + count:
			continue
		for row in range(maxi(first, centre_row - grid_reach), mini(first + count, centre_row + grid_reach + 1)):
			var z := origin.y + row * spacing
			for column in range(maxi(0, centre_column - grid_reach), mini(columns, centre_column + grid_reach + 1)):
				var i := (row - first) * columns + column
				if wall_edges[i] >= TerrainField.FAR:
					continue
				var offset := Vector2(origin.x + column * spacing, z) - start
				var along := clampf(offset.dot(segment) / maxf(length_squared, 0.000001), 0.0, 1.0)
				var edge := (offset - segment * along).length() - half_width
				clearances[i] = minf(clearances[i], edge)
	var heights: PackedFloat32Array = input["heights"]
	var strata := PackedFloat32Array()
	if shaped:
		strata.resize(heights.size())
	for i in heights.size():
		if wall_edges[i] >= TerrainField.FAR:
			continue
		var weight := smoothstep(protected_edge, full_edge, clearances[i])
		var terrace := terraces[i] if shaped else 0.0
		var setback := setbacks[i] if shaped else 0.0
		heights[i] = TerrainField.walled_height(heights[i], wall_heights[i], wall_deltas[i], wall_edges[i], blend + setback, weight, terrace)
		if shaped:
			strata[i] = terrace * weight * smoothstep(blend, blend + TerrainField.WALL_RISE, wall_edges[i])
	into["heights"] = heights
	into["strata"] = strata
