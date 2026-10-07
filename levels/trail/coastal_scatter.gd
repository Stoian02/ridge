class_name CoastalScatter
extends RefCounted
## Sparse wind-shaped trees, scrub/grass and static rocks in mixed chunk batches.
## Only Coastal opts in; old placement order/RNG is never visited or modified.

static func build(parent: Node3D, field: TerrainField, def: ScatterDef) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = def.seed
	var meshes: Array[ArrayMesh] = [LowPolyMeshes.hedge_bush(def.foliage_color, def.seed),
		LowPolyMeshes.rock(def.rock_color, def.seed),
		LowPolyMeshes.broadleaf(def.broadleaf_color, def.trunk_color, def.seed)]
	var spacings: Array[float] = [def.scrub_spacing, def.rock_spacing, def.broadleaf_spacing]
	var batches: Dictionary = {}
	var colliders: Dictionary = {}
	var counts := {"scrub": 0, "rocks": 0, "trees": 0}
	var placements: Array[Vector3] = []
	for kind in 3:
		var spacing := spacings[kind]
		if spacing <= 0.0:
			continue
		var source: Array = meshes[kind].surface_get_arrays(0)
		for row in ceili((field.rows - 1) * field.spacing / spacing):
			for column in ceili((field.columns - 1) * field.spacing / spacing):
				var x := field.origin.x + (column + rng.randf()) * spacing
				var z := field.origin.y + (row + rng.randf()) * spacing
				var yaw := rng.randf() * TAU
				var scale := rng.randf_range(0.65, 1.15)
				var edge := field.edge_distance_at(x, z)
				if edge < def.road_clearance or edge > 35.0:
					continue
				if def.coastal_exclusions.any(func(area: Rect2) -> bool: return area.has_point(Vector2(x, z))):
					continue
				var height := field.height_at(x, z)
				if height < 0.8 or field.normal_at(x, z).y < cos(deg_to_rad(def.max_slope_deg)):
					continue
				var key := Vector2i(floori(x / 100.0), floori(z / 100.0))
				if not batches.has(key):
					batches[key] = StructureMesh.new()
					colliders[key] = StructureMesh.new()
				var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
				if kind == 0:
					basis = basis.scaled(Vector3(0.8, 0.55, 0.8))
				elif kind == 2:
					# Consistent prevailing wind, not trees leaning randomly at the road.
					basis = Basis(Vector3.FORWARD, -0.20) * basis.scaled(Vector3(0.8, 0.75, 0.8))
				var origin := Vector3(x, height - (0.25 * scale if kind == 1 else 0.08), z)
				var transform := Transform3D(basis, origin)
				_append(batches[key], source, transform)
				if kind == 1:
					_append(colliders[key], source, transform)
				if kind == 0:
					_grass(batches[key], origin + Vector3(1.0, 0.0, 0.5), def.foliage_color)
				counts[["scrub", "rocks", "trees"][kind]] += 1
				placements.append(origin)
	for key: Vector2i in batches:
		var node: MeshInstance3D = (batches[key] as StructureMesh).add_to(parent, "CoastalScenery%s" % key, null, false)
		node.visibility_range_end = 180.0
		var solid: StructureMesh = colliders[key]
		if not solid.vertices.is_empty():
			var body := RoadBuilder._collision_body(solid.vertices, preload("res://surfaces/rock.tres"))
			parent.add_child(body)
	# Authoring/debug evidence, not per-frame work or hidden dynamic stones.
	parent.set_meta(&"coastal_placements", placements)
	parent.set_meta(&"coastal_counts", counts)
	return counts


static func _append(target: StructureMesh, arrays: Array, transform: Transform3D) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count := vertices.size() if indices.is_empty() else indices.size()
	for i in range(0, count, 3):
		var a := i if indices.is_empty() else indices[i]
		var b := i + 1 if indices.is_empty() else indices[i + 1]
		var c := i + 2 if indices.is_empty() else indices[i + 2]
		target.triangle(transform * vertices[a], transform * vertices[b], transform * vertices[c], colors[a])


static func _grass(target: StructureMesh, p: Vector3, color: Color) -> void:
	for direction: Vector3 in [Vector3.RIGHT, Vector3.FORWARD]:
		target.triangle(p - direction * 0.22, p + Vector3(0.15, 0.55, 0), p + direction * 0.22, color.lightened(0.12))
