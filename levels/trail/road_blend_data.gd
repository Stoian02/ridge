class_name RoadBlendData
extends RefCounted
## Earth-join chunk computation on immutable value snapshots. Each worker owns
## its arrays/cache; no sampler, field, profile or scene methods in the hot loop.


static func compute(input: Dictionary, into: Dictionary) -> void:
	var edges: PackedVector3Array = input["edges"]
	var outwards: PackedVector3Array = input["outwards"]
	var ups: PackedVector3Array = input["ups"]
	var reaches: PackedFloat64Array = input["reaches"]
	var shoulder_colors: PackedColorArray = input["colors"]
	var surface_ids: PackedInt32Array = input["surface_ids"]
	var heights: PackedFloat32Array = input["heights"]
	var strata: PackedFloat32Array = input["strata"]
	var wear: PackedFloat32Array = input["wear"]
	var origin: Vector2 = input["origin"]
	var spacing: float = input["spacing"]
	var columns: int = input["columns"]
	var field_rows: int = input["field_rows"]
	var dirt_color: Color = input["dirt_color"]
	var rock_color: Color = input["rock_color"]
	var wear_color: Color = input["wear_color"]
	var rock_slope: float = input["rock_slope"]
	var count := ups.size()
	var width := RoadBlendBuilder.COLUMNS
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var faces: Array[PackedVector3Array] = []
	for i: int in input["surface_count"]:
		faces.append(PackedVector3Array())
	var ground_cache: Dictionary = {}
	for side_index in 2:
		var offset := vertices.size()
		for row in count:
			var edge := edges[side_index * count + row]
			var outward := outwards[side_index * count + row]
			var reach := reaches[row]
			for column in width:
				var t := float(column) / (width - 1)
				var point := edge + outward * reach * t
				var fx := clampf((point.x - origin.x) / spacing, 0.0, columns - 1.001)
				var fz := clampf((point.z - origin.y) / spacing, 0.0, field_rows - 1.001)
				var x := int(fx)
				var z := int(fz)
				var tx := fx - x
				var tz := fz - z
				var a := heights[z * columns + x]
				var b := heights[z * columns + x + 1]
				var c := heights[(z + 1) * columns + x]
				var d := heights[(z + 1) * columns + x + 1]
				var ground := a + (b - a) * tx + (c - a) * tz
				var corners: Array[Vector2i] = [Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x, z + 1)]
				var weights := Vector3(1.0 - tx - tz, tx, tz)
				if tx + tz > 1.0:
					ground = d + (c - d) * (1.0 - tx) + (b - d) * (1.0 - tz)
					corners = [Vector2i(x + 1, z + 1), Vector2i(x, z + 1), Vector2i(x + 1, z)]
					weights = Vector3(tx + tz - 1.0, 1.0 - tx, 1.0 - tz)
				var ground_normal := Vector3.ZERO
				var ground_color := Color(0, 0, 0, 0)
				for i in 3:
					var corner := corners[i]
					var index := corner.y * columns + corner.x
					if not ground_cache.has(index):
						var dx := heights[corner.y * columns + maxi(corner.x - 1, 0)] \
								- heights[corner.y * columns + mini(corner.x + 1, columns - 1)]
						var dz := heights[maxi(corner.y - 1, 0) * columns + corner.x] \
								- heights[mini(corner.y + 1, field_rows - 1) * columns + corner.x]
						var normal := Vector3(dx, 2.0 * spacing, dz).normalized()
						var slope := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
						var rockiness := smoothstep(rock_slope - TerrainBuilder.COLOR_BLEND_DEG,
								rock_slope + TerrainBuilder.COLOR_BLEND_DEG, slope)
						var color := dirt_color.lerp(rock_color, rockiness)
						if not strata.is_empty() and strata[index] > 0.0:
							var position := Vector3(origin.x + corner.x * spacing, heights[index], origin.y + corner.y * spacing)
							var layer := position.y + sin(position.x * 0.025) * 1.5 + sin(position.z * 0.018)
							var band := smoothstep(-0.25, 0.25, sin(layer * 0.72))
							var sandstone := rock_color * lerpf(0.76, 1.13, band)
							sandstone.a = 1.0
							color = color.lerp(sandstone, strata[index] * 0.85)
						if not wear.is_empty():
							color = color.lerp(wear_color, wear[index])
						ground_cache[index] = {"normal": normal, "color": color}
					var cached: Dictionary = ground_cache[index]
					var normal: Vector3 = cached["normal"]
					var color: Color = cached["color"]
					ground_normal += normal * weights[i]
					ground_color += color * weights[i]
				ground_normal = ground_normal.normalized()
				if column > 0 and reach > 0.0001:
					point.y = maxf(lerpf(edge.y, ground, t), ground + 0.01)
					if column == width - 1:
						point.y = ground - 0.035
				var blend := smoothstep(0.0, 0.5, t)
				vertices.append(point)
				normals.append(ups[row].slerp(ground_normal, blend))
				colors.append(shoulder_colors[row].lerp(ground_color, blend))
		for row in count - 1:
			if reaches[row] < 0.001 and reaches[row + 1] < 0.001:
				continue
			var collision := faces[surface_ids[row]]
			for column in width - 1:
				var i := offset + row * width + column
				var corners: Array[int] = [i, i + width, i + 1, i + 1, i + width, i + width + 1]
				if side_index == 0:
					corners = [i, i + 1, i + width, i + 1, i + width + 1, i + width]
				for corner: int in corners:
					indices.append(corner)
					collision.append(vertices[corner])
			faces[surface_ids[row]] = collision
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	into["arrays"] = arrays
	into["faces"] = faces
