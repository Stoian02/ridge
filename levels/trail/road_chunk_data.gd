class_name RoadChunkData
extends RefCounted
## Pure chunk arrays. The caller snapshots the row frames and profile data;
## workers use only locals and own their output Dictionary. No scene objects.


static func compute(input: Dictionary, into: Dictionary) -> void:
	var stations: Array[Vector2] = input["stations"]
	var distances: PackedFloat32Array = input["distances"]
	var centres: PackedVector3Array = input["centres"]
	var rights: PackedVector3Array = input["rights"]
	var ups: PackedVector3Array = input["ups"]
	var heights: PackedFloat64Array = input["heights"]
	var ruts: Array[PackedFloat64Array] = input["ruts"]
	var rut_centres: Array[PackedFloat64Array] = input["rut_centres"]
	var road_colors: Array[Color] = input["road_colors"]
	var patch_colors: Array[Color] = input["patch_colors"]
	var left_colors: Array[Color] = input["left_colors"]
	var right_colors: Array[Color] = input["right_colors"]
	var line_color: Color = input["line_color"]
	var potholes: Array[Vector4] = input["potholes"]
	var patches: Array[Rect2] = input["patches"]
	var road_surfaces: PackedInt32Array = input["road_surfaces"]
	var shoulder_surfaces: PackedInt32Array = input["shoulder_surfaces"]
	var surface_count: int = input["surface_count"]
	var skip_rows: PackedByteArray = input["skip_rows"]
	var road_scales: PackedFloat64Array = input["road_scales"]
	var shoulder_scales: PackedFloat64Array = input["shoulder_scales"]
	var half_road: float = input["half_road"]
	var steps: Array[PackedFloat64Array] = input["steps"]
	var cross_ruts: Array[PackedFloat64Array] = input["cross_ruts"]
	var width := stations.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(distances.size() * width)
	normals.resize(vertices.size())
	colors.resize(vertices.size())
	# The lateral each vertex actually sits at, so columns that a narrowed row
	# collapsed onto one another can be skipped when the quads are built.
	var laterals := PackedFloat32Array()
	laterals.resize(vertices.size())
	for row in distances.size():
		var distance := distances[row]
		var rut := ruts[row]
		var road_scale := road_scales[row]
		var shoulder_scale := shoulder_scales[row]
		for column in width:
			var station := stations[column]
			var lateral := station.x
			if road_scale != 1.0 or shoulder_scale != 1.0:
				if int(station.y) == RoadBuilder.Part.SHOULDER:
					lateral = signf(station.x) * (half_road * road_scale + (absf(station.x) - half_road) * shoulder_scale)
				else:
					lateral = station.x * road_scale
			var pothole_height := 0.0
			for pothole: Vector4 in potholes:
				if absf(distance - pothole.x) > pothole.z:
					continue
				var radius := Vector2(distance - pothole.x, lateral - pothole.y).length()
				if radius < pothole.z:
					var t := radius / pothole.z
					pothole_height += -pothole.w * (1.0 - t * t)
			var is_patch := false
			for patch: Rect2 in patches:
				if patch.has_point(Vector2(distance, lateral)):
					is_patch = true
					break
			var rut_height := 0.0
			if rut[0] > 0.0:
				for centre: float in rut_centres[row]:
					var t := absf(lateral - centre) / rut[1]
					if t < 1.0:
						var depression := -rut[0] * (0.5 + 0.5 * cos(PI * t))
						if rut[3] > 0.0:
							rut_height = minf(rut_height, depression)
						else:
							rut_height += depression
			var step_height := 0.0
			for step: PackedFloat64Array in steps:
				if distance <= step[0]:
					continue
				if lateral >= step[2] and lateral <= step[3]:
					var lip := clampf((distance - step[0]) / maxf(step[5], 0.001), 0.0, 1.0)
					step_height += step[1] * (RockStepDef.LEDGE_SHARE + (1.0 - RockStepDef.LEDGE_SHARE) * lip)
				else:
					step_height += step[1] * clampf((distance - step[0]) / maxf(step[4], 0.001), 0.0, 1.0)
			var cross_height := 0.0
			for channel: PackedFloat64Array in cross_ruts:
				var t := absf(distance - channel[0] - lateral * channel[3]) / maxf(channel[4] * 0.5, 0.001)
				if t < 1.0 and lateral > channel[1] and lateral < channel[2]:
					var fade := minf(smoothstep(channel[1], channel[1] + channel[6], lateral),
							1.0 - smoothstep(channel[2] - channel[6], channel[2], lateral))
					cross_height -= channel[5] * (0.5 + 0.5 * cos(PI * t)) * fade
			var rough := pothole_height + cross_height
			if is_patch:
				rough += RoadProfile.PATCH_RAISE
			var i := row * width + column
			laterals[i] = lateral
			vertices[i] = centres[row] + rights[row] * lateral \
					+ ups[row] * (heights[row] + rough + rut_height + step_height)
			normals[i] = ups[row]
			if int(station.y) == RoadBuilder.Part.SHOULDER:
				colors[i] = left_colors[row] if lateral < 0.0 else right_colors[row]
			elif int(station.y) == RoadBuilder.Part.LINE:
				colors[i] = line_color
			else:
				var base: Color = patch_colors[row] if is_patch else road_colors[row]
				var shade := clampf(1.0 + (pothole_height + cross_height + rut_height) * RoadBuilder.SHADE_PER_METRE, 0.5, 1.0)
				colors[i] = Color(base.r * shade, base.g * shade, base.b * shade)
	var indices := PackedInt32Array()
	var faces: Array[PackedVector3Array] = []
	for surface in surface_count:
		faces.append(PackedVector3Array())
	for row in distances.size() - 1:
		if skip_rows[row] != 0:
			continue
		for column in width - 1:
			if is_equal_approx(stations[column].x, stations[column + 1].x):
				continue
			var i := row * width + column
			if absf(laterals[i] - laterals[i + 1]) < 0.001 and absf(laterals[i + width] - laterals[i + width + 1]) < 0.001:
				continue  # a narrowed row collapsed this column onto the next
			var surface: int = shoulder_surfaces[row] if int(stations[column].y) == RoadBuilder.Part.SHOULDER else road_surfaces[row]
			for corner: int in [i, i + width, i + 1, i + 1, i + width, i + width + 1]:
				indices.append(corner)
				faces[surface].append(vertices[corner])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	into["arrays"] = arrays
	into["faces"] = faces
