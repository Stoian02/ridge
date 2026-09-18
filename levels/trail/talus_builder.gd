class_name TalusBuilder
extends Node3D
## Loose stones (M5 spec §8.2): one RigidBody3D per stone with a convex hull,
## resting on the road or terrain and asleep on build, so untouched stones cost
## almost nothing. Each field is drawn from a single MultiMesh whose instance
## transforms are refreshed each physics frame only from the stones that are
## awake. Provisional: the phone check decides whether it stays (spec §8.3).

const ROCK := preload("res://surfaces/rock.tres")
## Tiny separation from the ground; the hull's actual lowest vertex sets its rest height.
const REST_GAP := 0.005
const FRICTION := 1.0
const BOUNCE := 0.0
const VIEW_DISTANCE := 160.0
## Nothing is placed closer than this to a checkpoint gate's centre (m).
const GATE_CLEARANCE := 1.5

var stones: Array[RigidBody3D] = []
## Per stone, mirroring exactly what was last written into its MultiMesh
## instance (headless Godot does not reliably retain MultiMesh instance data,
## so tests read this instead of MultiMesh.get_instance_transform()).
var instance_transforms: Array[Transform3D] = []

var _multimeshes: Array[MultiMesh] = []
## Per stone: its field's MultiMesh index, its instance slot and its radius.
var _fields := PackedInt32Array()
var _slots := PackedInt32Array()
var _radii := PackedFloat32Array()


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	stones.clear()
	instance_transforms.clear()
	_multimeshes.clear()
	_fields.clear()
	_slots.clear()
	_radii.clear()
	var gates := CheckpointPlacer.distances_for(sampler.length, trail)
	for i in trail.talus.size():
		_build_field(sampler, profile, field, trail.talus[i], gates, i)


func awake_count() -> int:
	var awake := 0
	for stone in stones:
		if not stone.sleeping:
			awake += 1
	return awake


func _physics_process(_delta: float) -> void:
	for i in stones.size():
		var stone := stones[i]
		if stone.sleeping:
			continue
		var transform := Transform3D(stone.global_basis * Basis.from_scale(Vector3.ONE * _radii[i]), stone.global_position)
		_multimeshes[_fields[i]].set_instance_transform(_slots[i], transform)
		instance_transforms[i] = transform


func _build_field(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, def: TalusDef,
		gates: PackedFloat32Array, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = def.seed
	var mesh := LowPolyMeshes.rock(def.color, def.seed)
	var points := mesh.get_faces()
	var physics := PhysicsMaterial.new()
	physics.friction = FRICTION
	physics.bounce = BOUNCE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	var placed: Array[Transform3D] = []
	# Never draws past the road's sampled length, where RoadSampler.forward()
	# and surface_point() would be out of range.
	var end := minf(def.end(), sampler.length - 1.0)
	for n in (def.count if def.start < end else 0):
		# Every random draw happens before a stone can be skipped, so the layout
		# of the others never depends on the gates.
		var distance := rng.randf_range(def.start, end)
		var side: float = -1.0 if n % 2 == 0 else 1.0
		var lateral := side * rng.randf_range(def.lateral_range.x, def.lateral_range.y)
		var yaw := rng.randf() * TAU
		var radius := rng.randf_range(def.size_range.x, def.size_range.y)
		var mass := rng.randf_range(def.mass_range.x, def.mass_range.y)
		if Array(gates).any(func(gate: float) -> bool: return absf(gate - distance) < GATE_CLEARANCE):
			continue
		var origin: Vector3
		if absf(lateral) <= sampler.half_width_at(distance):
			origin = sampler.surface_point(distance, lateral, profile)
		else:
			origin = sampler.position(distance) + sampler.right(distance) * lateral
			origin.y = field.height_at(origin.x, origin.z)
		origin.y += -mesh.get_aabb().position.y * radius + REST_GAP
		var rotation := Basis(Vector3.UP, yaw)
		var scaled := rotation * Basis.from_scale(Vector3.ONE * radius)
		var stone := RigidBody3D.new()
		stone.name = "Stone%d_%d" % [index, n]
		stone.mass = mass
		stone.physics_material_override = physics
		stone.can_sleep = true
		stone.sleeping = true
		stone.set_meta(SurfaceLookup.META_KEY, ROCK)
		var hull := ConvexPolygonShape3D.new()
		var local := PackedVector3Array()
		local.resize(points.size())
		for p in points.size():
			local[p] = Basis.from_scale(Vector3.ONE * radius) * points[p]
		hull.points = local
		var shape := CollisionShape3D.new()
		shape.shape = hull
		stone.add_child(shape)
		stone.transform = Transform3D(rotation, origin)
		add_child(stone)
		# Flush the queued enter-tree transform before sleeping: submitting it
		# later wakes a Jolt body even when its transform has not changed.
		stone.force_update_transform()
		stone.sleeping = true
		stones.append(stone)
		instance_transforms.append(Transform3D(scaled, origin))
		_fields.append(index)
		_slots.append(placed.size())
		_radii.append(radius)
		placed.append(Transform3D(scaled, origin))
	multimesh.instance_count = placed.size()
	for i in placed.size():
		multimesh.set_instance_transform(i, placed[i])
	_multimeshes.append(multimesh)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	var instance := MultiMeshInstance3D.new()
	instance.name = "Talus%d" % index
	instance.multimesh = multimesh
	instance.material_override = material
	instance.visibility_range_end = VIEW_DISTANCE
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
