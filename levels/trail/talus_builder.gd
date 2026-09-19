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
## Per stone: field/instance slot, geometry scale and conservative footprint.
var _fields := PackedInt32Array()
var _slots := PackedInt32Array()
var _scales: Array[Vector3] = []
var _footprints := PackedFloat32Array()
var _rest_transforms: Array[Transform3D] = []
var _was_awake := PackedByteArray()


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	_clear()
	var gates := CheckpointPlacer.distances_for(sampler.length, trail)
	for i in trail.talus.size():
		_build_field(sampler, profile, field, trail.talus[i], gates, i)


## A standalone test patch. height_at(x, z) returns the supporting floor in
## this builder's local coordinates; distance runs along -Z, lateral along X.
## Check all hull vertices against that floor and reject overlapping placements.
func build_patch(definitions: Array[TalusDef], height_at: Callable) -> void:
	_clear()
	for i in definitions.size():
		_build_field(null, null, null, definitions[i], PackedFloat32Array(), i, height_at)


## Test Ground reset: move the car clear first, then restore the original layout.
func reset_stones() -> void:
	for i in stones.size():
		var stone := stones[i]
		stone.linear_velocity = Vector3.ZERO
		stone.angular_velocity = Vector3.ZERO
		stone.transform = _rest_transforms[i]
		stone.force_update_transform()
		stone.sleeping = true
		_was_awake[i] = 0
		_sync_instance(i)


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	stones.clear()
	instance_transforms.clear()
	_multimeshes.clear()
	_fields.clear()
	_slots.clear()
	_scales.clear()
	_footprints.clear()
	_rest_transforms.clear()
	_was_awake.clear()


func awake_count() -> int:
	var awake := 0
	for stone in stones:
		if not stone.sleeping:
			awake += 1
	return awake


func _physics_process(_delta: float) -> void:
	for i in stones.size():
		if stones[i].sleeping and _was_awake[i] == 0:
			continue
		_sync_instance(i)
		_was_awake[i] = 0 if stones[i].sleeping else 1


func _sync_instance(i: int) -> void:
	var stone := stones[i]
	var transform := Transform3D(stone.basis * Basis.from_scale(_scales[i]), stone.position)
	# Write the final pose even on the tick a stone falls asleep. Local transforms
	# also keep visuals aligned when a whole patch is translated in Test Ground.
	if transform.is_equal_approx(instance_transforms[i]):
		return
	_multimeshes[_fields[i]].set_instance_transform(_slots[i], transform)
	instance_transforms[i] = transform


func _build_field(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, def: TalusDef,
		gates: PackedFloat32Array, index: int, height_at: Callable = Callable()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = def.seed
	var mesh := LowPolyMeshes.rock(def.color, def.seed)
	var points := mesh.get_faces()
	var unit_footprint := 0.0
	for point in points:
		unit_footprint = maxf(unit_footprint, Vector2(point.x, point.z).length())
	var physics := PhysicsMaterial.new()
	physics.friction = FRICTION
	physics.bounce = BOUNCE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	var placed: Array[Transform3D] = []
	# Never draws past the road's sampled length, where RoadSampler.forward()
	# and surface_point() would be out of range.
	var end: float = def.end() if sampler == null else minf(def.end(), sampler.length - 1.0)
	for n in (def.count if def.start < end else 0):
		# Every random draw happens before a stone can be skipped, so the layout
		# of the others never depends on the gates.
		var distance := rng.randf_range(def.start, end)
		var side: float = -1.0 if n % 2 == 0 else 1.0
		var lateral := side * rng.randf_range(def.lateral_range.x, def.lateral_range.y)
		var yaw := rng.randf() * TAU
		var radius := rng.randf_range(def.size_range.x, def.size_range.y)
		var footprint := radius * unit_footprint
		var mass := rng.randf_range(def.mass_range.x, def.mass_range.y)
		if Array(gates).any(func(gate: float) -> bool: return absf(gate - distance) < GATE_CLEARANCE):
			continue
		var origin: Vector3
		if height_at.is_valid():
			origin = Vector3(lateral, 0.0, -distance)
			for attempt in 24:
				if not _patch_overlaps(origin, footprint):
					break
				origin.x = side * rng.randf_range(def.lateral_range.x, def.lateral_range.y)
				origin.z = -rng.randf_range(def.start, end)
			if _patch_overlaps(origin, footprint):
				continue
		elif absf(lateral) <= sampler.half_width_at(distance):
			origin = sampler.surface_point(distance, lateral, profile)
		else:
			origin = sampler.position(distance) + sampler.right(distance) * lateral
			origin.y = field.height_at(origin.x, origin.z)
		var rotation := Basis(Vector3.UP, yaw)
		var scale := Vector3(radius, radius * def.height_scale, radius)
		var scaled := rotation * Basis.from_scale(scale)
		if height_at.is_valid():
			var support := -INF
			for point in points:
				var vertex := scaled * point
				var floor_height: float = height_at.call(origin.x + vertex.x, origin.z + vertex.z)
				support = maxf(support, floor_height - vertex.y)
			origin.y = support + REST_GAP
		else:
			origin.y += -mesh.get_aabb().position.y * scale.y + REST_GAP
		var stone := RigidBody3D.new()
		stone.name = "Stone%d_%d" % [index, n]
		stone.mass = mass
		stone.continuous_cd = def.continuous_collision
		stone.physics_material_override = physics
		stone.can_sleep = true
		stone.sleeping = true
		stone.set_meta(SurfaceLookup.META_KEY, ROCK)
		var hull := ConvexPolygonShape3D.new()
		var local := PackedVector3Array()
		local.resize(points.size())
		for p in points.size():
			local[p] = Basis.from_scale(scale) * points[p]
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
		_scales.append(scale)
		_footprints.append(footprint)
		_rest_transforms.append(stone.transform)
		_was_awake.append(0)
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


func _patch_overlaps(origin: Vector3, radius: float) -> bool:
	for i in stones.size():
		var separation := Vector2(origin.x - stones[i].position.x, origin.z - stones[i].position.z)
		if separation.length() < radius + _footprints[i] + 0.06:
			return true
	return false
