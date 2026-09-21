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
## Physics frames between activation-window passes. The window moves with the
## camera at driving speed, so a few frames of lag costs nothing.
const WINDOW_FRAMES := 6
## Swept collision costs a cast per step per body, so only stones actually
## moving fast enough to skip through the floor get it (m/s).
const CCD_SPEED := 5.0

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
## Only awake stones need transform polling; thousands of sleeping stones do not.
var _active: Dictionary = {}
## Where each stone was built, for the activation window's distance test.
var _origins: PackedVector3Array = PackedVector3Array()
## Per stone, its field's active_distance squared; 0 = always simulated.
var _window_squared := PackedFloat32Array()
## 1 where this builder turns swept collision on and off with speed; 0 where the
## field asked for it outright and it stays on.
var _dynamic_ccd := PackedByteArray()
var _frames_until_window := 0
var _windowed := false
## One-metre XZ bins of (x, z, radius), used only while placing non-overlapping fields.
var _occupied: Dictionary = {}


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef,
		boulders: BoulderBuilder = null) -> void:
	_clear()
	if boulders != null:
		for transforms: Array in boulders.placed:
			for placed: Transform3D in transforms:
				# Conservative bound for the lumpy rock and stretched slab meshes.
				_occupy(placed.origin, placed.basis.get_scale().length() * 1.2)
	var gates := CheckpointPlacer.distances_for(sampler.length, trail)
	for i in trail.talus.size():
		_build_field(sampler, profile, field, trail.talus[i], gates, i)
	_occupied.clear()


## A standalone test patch. height_at(x, z) returns the supporting floor in
## this builder's local coordinates; distance runs along -Z, lateral along X.
## Check all hull vertices against that floor and reject overlapping placements.
func build_patch(definitions: Array[TalusDef], height_at: Callable) -> void:
	_clear()
	for i in definitions.size():
		_build_field(null, null, null, definitions[i], PackedFloat32Array(), i, height_at)
	_occupied.clear()


## Test Ground reset: move the car clear first, then restore the original layout.
func reset_stones() -> void:
	_active.clear()
	for i in stones.size():
		var stone := stones[i]
		stone.linear_velocity = Vector3.ZERO
		stone.angular_velocity = Vector3.ZERO
		stone.transform = _rest_transforms[i]
		stone.force_update_transform()
		stone.sleeping = true
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
	_active.clear()
	_occupied.clear()
	_origins.clear()
	_window_squared.clear()
	_dynamic_ccd.clear()
	_windowed = false
	_frames_until_window = 1


## Stones the physics engine is currently solving. A frozen stone is static, so
## it is not awake however its sleeping flag reads.
func awake_count() -> int:
	var awake := 0
	for stone in stones:
		if not stone.sleeping and not stone.freeze:
			awake += 1
	return awake


func _physics_process(_delta: float) -> void:
	for i: int in _active.keys():
		_sync_instance(i)
		var stone := stones[i]
		# Swept collision costs a cast per step, so stones that did not ask for
		# it outright get it only while they are quick enough to skip the floor.
		if _dynamic_ccd[i] == 1:
			var fast := stone.linear_velocity.length_squared() > CCD_SPEED * CCD_SPEED
			if stone.continuous_cd != fast:
				stone.continuous_cd = fast
		if stone.sleeping:
			_active.erase(i)
	if not _windowed:
		return
	_frames_until_window -= 1
	if _frames_until_window > 0:
		return
	_frames_until_window = WINDOW_FRAMES
	_update_window()


## Freezes stones far from the camera and thaws the ones near it. A frozen body
## is static to Jolt: no island, no solver, no swept collision. Without a camera
## (some headless tests) every stone stays simulated, as it was before.
func _update_window() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var focus := camera.global_position
	for i in stones.size():
		var window := _window_squared[i]
		if window <= 0.0:
			continue
		var near := _origins[i].distance_squared_to(focus) <= window
		var stone := stones[i]
		if stone.freeze == near:
			stone.freeze = not near
			if not near:
				_sync_instance(i)
				_active.erase(i)


func _sleep_changed(i: int) -> void:
	if stones[i].sleeping:
		_sync_instance(i)
		_active.erase(i)
	else:
		_active[i] = true


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
	physics.friction = def.contact_friction
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
		if def.cover_road and sampler != null:
			lateral = side * rng.randf_range(0.0, maxf(0.0, sampler.road_half_width_at(distance) - footprint - 0.04))
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
		if def.avoid_overlap and sampler != null:
			for attempt in 24:
				if not _patch_overlaps(origin, footprint):
					break
				distance = rng.randf_range(def.start, end)
				lateral = side * rng.randf_range(0.0, maxf(0.0, sampler.road_half_width_at(distance) - footprint - 0.04)) if def.cover_road else side * rng.randf_range(def.lateral_range.x, def.lateral_range.y)
				origin = sampler.surface_point(distance, lateral, profile)
			if _patch_overlaps(origin, footprint) or Array(gates).any(func(gate: float) -> bool: return absf(gate - distance) < GATE_CLEARANCE):
				continue
		var rotation := Basis(Vector3.UP, yaw)
		if def.cover_road and sampler != null:
			rotation = Basis.looking_at(sampler.forward(distance), sampler.up(distance)) * rotation
			if not profile.def.undulation_sections.is_empty():
				# Seat fragments on the local rise/dip, not the unmodified curve frame.
				var along := (sampler.surface_point(distance + 0.1, lateral, profile)
					- sampler.surface_point(distance - 0.1, lateral, profile)).normalized()
				var normal := sampler.right(distance).cross(along).normalized()
				rotation = Basis.looking_at(along, normal) * Basis(Vector3.UP, yaw)
		var scale := Vector3(radius, radius * def.height_scale, radius)
		var scaled := rotation * Basis.from_scale(scale)
		if height_at.is_valid():
			var support := -INF
			for point in points:
				var vertex := scaled * point
				var floor_height: float = height_at.call(origin.x + vertex.x, origin.z + vertex.z)
				support = maxf(support, floor_height - vertex.y)
			origin.y = support + REST_GAP
		elif def.cover_road and sampler != null:
			origin += rotation.y * (-mesh.get_aabb().position.y * scale.y + REST_GAP)
		else:
			origin.y += -mesh.get_aabb().position.y * scale.y + REST_GAP
		var stone := RigidBody3D.new()
		stone.name = "Stone%d_%d" % [index, n]
		stone.mass = mass
		stone.continuous_cd = def.continuous_collision
		stone.linear_damp = def.linear_damp
		stone.angular_damp = def.angular_damp
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
		stone.sleeping_state_changed.connect(_sleep_changed.bind(stones.size() - 1))
		instance_transforms.append(Transform3D(scaled, origin))
		_fields.append(index)
		_slots.append(placed.size())
		_scales.append(scale)
		_footprints.append(footprint)
		_origins.append(stone.global_position if is_inside_tree() else origin)
		_window_squared.append(def.active_distance * def.active_distance)
		_dynamic_ccd.append(0 if def.continuous_collision else 1)
		_windowed = _windowed or def.active_distance > 0.0
		_occupy(origin, footprint)
		_rest_transforms.append(stone.transform)
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
	var reach := radius + 0.06
	for x in range(floori(origin.x - reach), floori(origin.x + reach) + 1):
		for z in range(floori(origin.z - reach), floori(origin.z + reach) + 1):
			for circle: Vector3 in _occupied.get(Vector2i(x, z), []):
				if Vector2(origin.x - circle.x, origin.z - circle.y).length() < radius + circle.z + 0.06:
					return true
	return false


func _occupy(origin: Vector3, radius: float) -> void:
	for x in range(floori(origin.x - radius), floori(origin.x + radius) + 1):
		for z in range(floori(origin.z - radius), floori(origin.z + radius) + 1):
			var key := Vector2i(x, z)
			if not _occupied.has(key):
				_occupied[key] = []
			(_occupied[key] as Array).append(Vector3(origin.x, origin.z, radius))
