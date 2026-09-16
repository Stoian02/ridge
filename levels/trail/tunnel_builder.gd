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
	var top := tunnel.height + tunnel.cover + 1.0
	for i in section.size() - 1:
		var a := section[i]
		var b := section[i + 1]
		var outer_a := Vector2(a.x, top)
		var outer_b := Vector2(b.x, top)
		if i == 0:
			outer_a = Vector2(-outer_half, -0.4)
			outer_b = Vector2(-outer_half, top)
		elif i == section.size() - 2:
			outer_a = Vector2(outer_half, top)
			outer_b = Vector2(outer_half, -0.4)
		portal.quad(centre + right * a.x + Vector3.UP * a.y,
				centre + right * b.x + Vector3.UP * b.y,
				centre + right * outer_b.x + Vector3.UP * outer_b.y,
				centre + right * outer_a.x + Vector3.UP * outer_a.y, tunnel.wall_color.lightened(0.13))
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
