class_name TunnelBuilder
extends Node3D
## Arched rock shells, framed portals and instanced luminous ceiling lamps.

const ROCK := preload("res://surfaces/dirt.tres")
const STEP := 2.0
var lamp_distances := PackedFloat32Array()


static func cross_section(tunnel: TunnelDef) -> Array[Vector2]:
	var half := tunnel.inner_width * 0.5
	var spring := tunnel.height * 0.5
	var points: Array[Vector2] = [Vector2(-half, -0.4)]
	for i in 9:
		var angle := PI - PI * i / 8.0
		points.append(Vector2(cos(angle) * half, spring + sin(angle) * (tunnel.height - spring)))
	points.append(Vector2(half, -0.4))
	return points


func build(sampler: RoadSampler, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	lamp_distances.clear()
	for tunnel: TunnelDef in trail.tunnels:
		_build_tunnel(sampler, field, trail, tunnel)


func _build_tunnel(sampler: RoadSampler, field: TerrainField, trail: TrailDef, tunnel: TunnelDef) -> void:
	var shell := StructureMesh.new()
	var section := cross_section(tunnel)
	var rows: Array[PackedVector3Array] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = tunnel.seed
	var count := ceili(tunnel.length / STEP)
	for row in count + 1:
		var at := tunnel.start + minf(row * STEP, tunnel.length)
		var centre := sampler.position(at)
		var right := sampler.right(at)
		var points := PackedVector3Array()
		for point: Vector2 in section:
			var rough: float = rng.randf_range(0.0, 0.07) if row > 0 and row < count else 0.0
			points.append(centre + right * (point.x + signf(point.x) * rough) + Vector3.UP * point.y)
		rows.append(points)
	for row in count:
		for column in section.size() - 1:
			var shade := rng.randf_range(0.83, 1.12)
			shell.quad(rows[row][column], rows[row + 1][column], rows[row + 1][column + 1],
					rows[row][column + 1], tunnel.wall_color * Color(shade, shade, shade))
	shell.add_to(self, "Shell", ROCK)
	for end: float in [tunnel.start, tunnel.end()]:
		_add_portal(sampler, field, trail, tunnel, end, section)
	var transforms: Array[Transform3D] = []
	var distance := tunnel.start + tunnel.lamp_spacing * 0.5
	while distance < tunnel.end():
		transforms.append(Transform3D(Basis.IDENTITY, sampler.position(distance) + Vector3.UP * (tunnel.height - 0.16)))
		lamp_distances.append(distance)
		distance += tunnel.lamp_spacing
	var box := BoxMesh.new()
	box.size = Vector3(0.65, 0.18, 0.38)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tunnel.lamp_color
	box.material = material
	var lamps := MultiMesh.new()
	lamps.transform_format = MultiMesh.TRANSFORM_3D
	lamps.mesh = box
	lamps.instance_count = transforms.size()
	for i in transforms.size():
		lamps.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "Lamps"
	instance.multimesh = lamps
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _add_portal(sampler: RoadSampler, field: TerrainField, trail: TrailDef, tunnel: TunnelDef,
		distance: float, section: Array[Vector2]) -> void:
	var portal := StructureMesh.new()
	var centre := sampler.position(distance)
	var right := sampler.right(distance)
	var outer_half := tunnel.inner_width * 0.5 + 8.0
	var top := field.height_at(centre.x, centre.z) - centre.y
	for i in section.size() - 1:
		var a := section[i]
		var b := section[i + 1]
		var outer_a := Vector2(a.x, top)
		var outer_b := Vector2(b.x, top)
		if i == 0:
			outer_a = Vector2(-outer_half, -0.4)
			outer_b = Vector2(-outer_half, b.y)
		elif i == section.size() - 2:
			outer_a = Vector2(outer_half, a.y)
			outer_b = Vector2(outer_half, -0.4)
		portal.quad(centre + right * a.x + Vector3.UP * a.y,
				centre + right * b.x + Vector3.UP * b.y,
				centre + right * outer_b.x + Vector3.UP * outer_b.y,
				centre + right * outer_a.x + Vector3.UP * outer_a.y, tunnel.wall_color.lightened(0.13))
	# The upper corners complete the rectangular rock face around the arch.
	for side: float in [-1.0, 1.0]:
		var inner := right * side * tunnel.inner_width * 0.5
		var outer := right * side * outer_half
		var spring := Vector3.UP * tunnel.height * 0.5
		portal.quad(centre + inner + spring, centre + outer + spring,
				centre + outer + Vector3.UP * top, centre + inner + Vector3.UP * top,
				tunnel.wall_color.lightened(0.13))
	# Closed retaining sides frame the road cut leading into each portal.
	var direction: float = -1.0 if distance == tunnel.start else 1.0
	for side: float in [-1.0, 1.0]:
		for step in ceili(tunnel.portal_length / STEP):
			var a_distance := distance + direction * minf(step * STEP, tunnel.portal_length)
			var b_distance := distance + direction * minf((step + 1) * STEP, tunnel.portal_length)
			var a := sampler.position(a_distance) + sampler.right(a_distance) * side * trail.half_total_width()
			var b := sampler.position(b_distance) + sampler.right(b_distance) * side * trail.half_total_width()
			var a_top := Vector3(a.x, maxf(a.y, field.height_at(a.x, a.z)), a.z)
			var b_top := Vector3(b.x, maxf(b.y, field.height_at(b.x, b.z)), b.z)
			portal.quad(a + Vector3.DOWN * 0.5, b + Vector3.DOWN * 0.5, b_top, a_top, tunnel.wall_color)
	portal.add_to(self, "Portal", ROCK)
	_close_excavation(sampler, field, trail, tunnel, distance, direction)


## Restore the removed heightmap triangles, clipped around the driving opening.
## Using the exact grid faces avoids overlaps/z-fighting on the steep banks.
func _close_excavation(sampler: RoadSampler, field: TerrainField, trail: TrailDef,
		tunnel: TunnelDef, distance: float, direction: float) -> void:
	var caps := StructureMesh.new()
	var half := trail.half_total_width()
	var samples := TrailEarthworks.nearest_samples(field, sampler, distance - tunnel.portal_length - 8.0,
			distance + tunnel.portal_length + 8.0, half + field.spacing * 3.0)
	for i: int in samples:
		if i % field.columns == field.columns - 1 or i >= field.heights.size() - field.columns:
			continue
		var corners: Array[int] = [i, i + 1, i + field.columns, i + field.columns + 1]
		var removed := false
		var complete := true
		var points: Array = []
		for corner: int in corners:
			removed = removed or field.portal_holes[corner] != 0
			if not samples.has(corner):
				complete = false
				break
			var sample: Vector4 = samples[corner]
			var position := field.sample_position(corner % field.columns, corner / field.columns)
			points.append([position, Vector2(sample.w, direction * (sample.y - distance))])
		if not removed or not complete:
			continue
		for indices: Array in [[0, 1, 2], [1, 3, 2]]:
			var triangle: Array = [points[indices[0]], points[indices[1]], points[indices[2]]]
			_add_cap_polygon(caps, _clip_cap(triangle, 1, 0.0, false), field.def.dirt_color)
			var approach := _clip_cap(triangle, 1, 0.0, true)
			_add_cap_polygon(caps, _clip_cap(approach, 0, -half, false), field.def.dirt_color)
			_add_cap_polygon(caps, _clip_cap(approach, 0, half, true), field.def.dirt_color)
	caps.add_to(self, "PortalSnowCaps", field.def.surface)


## Polygon vertices are [world position, (lateral, distance outside portal)].
func _clip_cap(polygon: Array, axis: int, threshold: float, keep_greater: bool) -> Array:
	var result: Array = []
	if polygon.is_empty():
		return result
	var previous: Array = polygon[-1]
	for current: Array in polygon:
		var a_uv: Vector2 = previous[1]
		var b_uv: Vector2 = current[1]
		var a_inside: bool = a_uv[axis] >= threshold if keep_greater else a_uv[axis] <= threshold
		var b_inside: bool = b_uv[axis] >= threshold if keep_greater else b_uv[axis] <= threshold
		if a_inside != b_inside:
			var weight := (threshold - a_uv[axis]) / (b_uv[axis] - a_uv[axis])
			var a: Vector3 = previous[0]
			var b: Vector3 = current[0]
			result.append([a.lerp(b, weight), a_uv.lerp(b_uv, weight)])
		if b_inside:
			result.append(current)
		previous = current
	return result


func _add_cap_polygon(caps: StructureMesh, polygon: Array, color: Color) -> void:
	for i in range(1, polygon.size() - 1):
		caps.triangle(polygon[0][0], polygon[i][0], polygon[i + 1][0], color)
