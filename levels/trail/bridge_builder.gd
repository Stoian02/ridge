class_name BridgeBuilder
extends Node3D
## Collidable transverse logs, supports and broken rails over an icy gorge.

const LOGS := preload("res://surfaces/logs.tres")
const ICE := preload("res://surfaces/ice.tres")
const WOOD := Color(0.32, 0.23, 0.16)
var log_tops := PackedVector3Array()
var log_width: float = 0.0


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	log_tops.clear()
	log_width = trail.road_width + 1.4
	for bridge: BridgeDef in trail.bridges:
		_build_bridge(sampler, profile, field, trail, bridge)


func _build_bridge(sampler: RoadSampler, profile: RoadProfile, field: TerrainField,
		trail: TrailDef, bridge: BridgeDef) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = bridge.seed
	var count := ceili(bridge.length / bridge.log_diameter_range.x)
	if count % 2 != 0:
		count += 1
	var step := bridge.length / count
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 1.0
	cylinder.radial_segments = 10
	cylinder.rings = 1
	var logs := MultiMesh.new()
	logs.transform_format = MultiMesh.TRANSFORM_3D
	logs.use_colors = true
	logs.mesh = cylinder
	logs.instance_count = count
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	var body := StaticBody3D.new()
	body.name = "LogsCollision"
	body.set_meta(SurfaceLookup.META_KEY, LOGS)
	for i in count:
		var at := bridge.start + (i + 0.5) * step
		var diameter := rng.randf_range(bridge.log_diameter_range.x, bridge.log_diameter_range.y)
		var along := sampler.forward(at)
		var across := sampler.right(at)
		var basis := Basis(along, across, along.cross(across).normalized())
		var point := sampler.surface_point(at, 0.0, profile) - Vector3.UP * 0.15
		var transform := Transform3D(basis, point)
		logs.set_instance_transform(i, Transform3D(basis.scaled_local(Vector3(diameter, log_width, diameter)), point))
		logs.set_instance_color(i, WOOD.lightened(rng.randf_range(0.0, 0.15)))
		var shape := CylinderShape3D.new()
		shape.height = log_width
		shape.radius = diameter * 0.5
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = transform
		body.add_child(collision)
		log_tops.append(point + Vector3.UP * diameter * 0.5)
	add_child(body)
	var instance := MultiMeshInstance3D.new()
	instance.name = "Logs"
	instance.multimesh = logs
	instance.material_override = material
	add_child(instance)
	_add_supports(sampler, profile, field, trail, bridge)
	_add_ice_floor(sampler, field, bridge)


func _add_supports(sampler: RoadSampler, profile: RoadProfile, field: TerrainField,
		trail: TrailDef, bridge: BridgeDef) -> void:
	var wood := StructureMesh.new()
	var at := bridge.start
	while at <= bridge.end() + 0.01:
		for side: float in [-1.0, 1.0]:
			var point := sampler.surface_point(at, side * (trail.road_width * 0.5 + 0.45), profile)
			var ground := field.height_at(point.x, point.z)
			var height := maxf(1.2, point.y + 1.0 - ground)
			wood.box(Transform3D(Basis.IDENTITY, Vector3(point.x, point.y + 1.0 - height * 0.5, point.z)),
					Vector3(0.24, height, 0.24), WOOD)
			var next := minf(at + 3.0, bridge.end())
			# Alternating gaps and short broken pieces on the sagged half.
			if next > at and (at < bridge.start + bridge.length * 0.5 or int((at - bridge.start) / 3.0) % 3 != 1):
				var end := sampler.surface_point(next, side * (trail.road_width * 0.5 + 0.45), profile)
				var vector := end - point
				var basis := Basis.looking_at(vector.normalized(), Vector3.UP)
				wood.box(Transform3D(basis, (point + end) * 0.5 + Vector3.UP * 0.85),
						Vector3(0.16, 0.18, vector.length()), WOOD.lightened(0.04))
		at += 3.0
	wood.add_to(self, "SupportsAndRails", LOGS)


func _add_ice_floor(sampler: RoadSampler, field: TerrainField, bridge: BridgeDef) -> void:
	var ice := StructureMesh.new()
	var rows := ceili((bridge.length - 8.0) / field.spacing)
	var columns := ceili(bridge.gorge_width / field.spacing)
	var points: Array[PackedVector3Array] = []
	for row in rows + 1:
		var at := lerpf(bridge.start + 4.0, bridge.end() - 4.0, row / float(rows))
		var line := PackedVector3Array()
		for column in columns + 1:
			var lateral := lerpf(-bridge.gorge_width * 0.5, bridge.gorge_width * 0.5, column / float(columns))
			var point := sampler.position(at) + sampler.right(at) * lateral
			point.y = field.height_at(point.x, point.z) + 0.035
			line.append(point)
		points.append(line)
	for row in rows:
		for column in columns:
			ice.quad(points[row][column], points[row + 1][column], points[row + 1][column + 1], points[row][column + 1],
					Color(0.4, 0.57, 0.68))
	var instance := ice.add_to(self, "GorgeIce", ICE, false)
	(instance.material_override as StandardMaterial3D).roughness = 0.18
