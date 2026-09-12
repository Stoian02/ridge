class_name Wheel
extends Node3D
## One wheel. Sits at the suspension top mount. Each tick it finds the ground with
## a sphere cast, runs the suspension and tire maths, and returns the force the car
## should apply at the contact point. It also moves and spins its visual mesh.

@export var is_front: bool = false
@export var is_left: bool = false

var stats: CarStats
var grip_table: GripTable

# --- Contact, refreshed by update_contact() ---
var in_contact: bool = false
## Global position where the tire touches the ground.
var contact_point: Vector3 = Vector3.ZERO
## Global ground normal at the contact point.
var contact_normal: Vector3 = Vector3.UP
var surface: SurfaceDef = null
## Metres squeezed from full extension (0 = hanging at full droop).
var compression: float = 0.0
## m/s, + while compressing.
var compression_speed: float = 0.0

# --- Tire state ---
## Front-wheel angle in radians, + = right. Set by the car.
var steer_angle: float = 0.0
## Wheel spin in rad/s, + = rolling forward.
var spin_speed: float = 0.0
## Set by the car each tick (Nm).
var drive_torque: float = 0.0
var brake_torque: float = 0.0
## Vertical load this wheel carries (N).
var tire_load: float = 0.0
var slip_ratio: float = 0.0
var slip_angle: float = 0.0

var _cast: ShapeCast3D
var _steer_pivot: Node3D
var _spin_pivot: Node3D
var _spin_visual_angle: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


## Called once by the car in its _ready().
func setup(car_stats: CarStats, table: GripTable, car_body: CollisionObject3D) -> void:
	stats = car_stats
	grip_table = table
	position = stats.wheel_mount_position(is_front, is_left)
	_cast = ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = stats.wheel_radius
	_cast.shape = sphere
	_cast.target_position = Vector3(0.0, -stats.suspension_length, 0.0)
	_cast.enabled = false  # updated manually once per tick, in update_contact()
	_cast.add_exception(car_body)
	add_child(_cast)
	_build_visual()


func reset() -> void:
	spin_speed = 0.0
	compression = 0.0
	compression_speed = 0.0
	tire_load = 0.0
	slip_ratio = 0.0
	slip_angle = 0.0


## Step 1 of a tick: find the ground and measure the suspension.
func update_contact(delta: float) -> void:
	var previous_compression := compression
	_cast.force_shapecast_update()
	in_contact = _cast.is_colliding()
	if not in_contact:
		compression = 0.0
		compression_speed = 0.0
		surface = null
		return
	contact_point = _cast.get_collision_point(0)
	contact_normal = _cast.get_collision_normal(0)
	surface = SurfaceLookup.surface_of(_cast.get_collider(0))
	# How far the wheel centre travelled down from the mount before touching.
	# Soft surfaces let the wheel sink a little further.
	var hit_distance := _cast.get_closest_collision_safe_fraction() * stats.suspension_length
	var wheel_distance := minf(hit_distance + surface.sink_depth, stats.suspension_length)
	compression = stats.suspension_length - wheel_distance
	compression_speed = (compression - previous_compression) / delta


## Step 2 of a tick: returns the global force to apply at contact_point (zero in
## the air). anti_roll: extra suspension force from the anti-roll bar (N, + = up).
func compute_force(delta: float, anti_roll: float, body: RigidBody3D) -> Vector3:
	if not in_contact:
		tire_load = 0.0
		slip_ratio = 0.0
		slip_angle = 0.0
		_spin_freely(delta)
		return Vector3.ZERO

	var suspension := SuspensionModel.spring_damper_force(compression, compression_speed,
			stats.spring_stiffness, stats.compress_damping, stats.rebound_damping)
	suspension += SuspensionModel.bump_stop_force(compression, stats.suspension_length,
			stats.bump_stop_stiffness)
	tire_load = maxf(0.0, suspension + anti_roll)

	# The wheel's heading, flattened onto the ground plane.
	var car_up := body.global_basis.y
	var heading := (-body.global_basis.z).rotated(car_up, -steer_angle)
	var forward := (heading - contact_normal * heading.dot(contact_normal)).normalized()
	var right := forward.cross(contact_normal).normalized()

	# How the contact patch moves over the ground.
	var patch_velocity := body.linear_velocity \
			+ body.angular_velocity.cross(contact_point - body.global_position)
	var forward_speed := patch_velocity.dot(forward)
	var sideways_speed := patch_velocity.dot(right)
	var tread_speed := spin_speed * stats.wheel_radius

	slip_ratio = TireModel.slip_ratio(tread_speed, forward_speed, stats.low_speed_reference)
	slip_angle = TireModel.slip_angle(forward_speed, sideways_speed, stats.low_speed_reference)
	var friction := surface.grip * stats.tire_grip * grip_table.multiplier(stats.archetype, surface.id)
	if not is_front:
		friction *= stats.rear_grip_bias
	var tire := TireModel.contact_force(slip_ratio, slip_angle, friction * tire_load,
			stats.peak_slip_ratio, deg_to_rad(stats.peak_slip_angle_deg), stats.slide_grip,
			Vector2(tread_speed - forward_speed, sideways_speed))

	# Never let a force overshoot within one tick: this is what stops low-speed jitter.
	var corner_mass := maxf(tire_load / _gravity, 1.0)
	var wheel_held := brake_torque > 0.0 and is_zero_approx(spin_speed)
	var long_limit := TireModel.max_longitudinal_force(tread_speed - forward_speed,
			stats.wheel_radius, stats.wheel_inertia, corner_mass, wheel_held, delta)
	var longitudinal := clampf(tire.x, -long_limit, long_limit)
	var lateral_limit := TireModel.max_lateral_force(sideways_speed, corner_mass, delta)
	var lateral := clampf(tire.y, -lateral_limit, lateral_limit)

	_update_spin(delta, longitudinal)

	# Rolling resistance and surface drag slow the car down but never reverse it.
	var resistance := surface.rolling_resistance * tire_load + surface.drag * absf(forward_speed)
	resistance = minf(resistance, absf(forward_speed) * corner_mass / delta)
	longitudinal -= signf(forward_speed) * resistance

	return car_up * tire_load + forward * longitudinal + right * lateral


## Step 3 of a tick: place and spin the visual wheel.
func update_visual(delta: float) -> void:
	var wheel_distance := stats.suspension_length - compression
	_steer_pivot.position = Vector3(0.0, -wheel_distance, 0.0)
	_steer_pivot.rotation.y = -steer_angle
	# Rolling forward (-Z) is a negative rotation about +X.
	_spin_visual_angle = wrapf(_spin_visual_angle - spin_speed * delta, -PI, PI)
	_spin_pivot.rotation.x = _spin_visual_angle


func _update_spin(delta: float, tire_force: float) -> void:
	# The road pushes back on the tread with the opposite of the tire force.
	spin_speed += (drive_torque - tire_force * stats.wheel_radius) / stats.wheel_inertia * delta
	_apply_brakes(delta, tire_force)


func _spin_freely(delta: float) -> void:
	spin_speed += drive_torque / stats.wheel_inertia * delta
	_apply_brakes(delta, 0.0)


## road_force: the longitudinal tire force this tick (N), which is all the brake
## can react against before the wheel locks.
func _apply_brakes(delta: float, road_force: float) -> void:
	var torque := brake_torque
	# ABS: once the wheel slips more than the target, hold the brake at what the
	# road can take, so the wheel keeps turning near peak grip instead of locking.
	if stats.abs_enabled and in_contact and slip_ratio < -stats.abs_target_slip:
		torque = minf(torque, absf(road_force) * stats.wheel_radius)
	spin_speed = move_toward(spin_speed, 0.0, torque / stats.wheel_inertia * delta)


func _build_visual() -> void:
	_steer_pivot = Node3D.new()
	add_child(_steer_pivot)
	_spin_pivot = Node3D.new()
	_steer_pivot.add_child(_spin_pivot)

	var tire := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = stats.wheel_radius
	cylinder.bottom_radius = stats.wheel_radius
	cylinder.height = stats.wheel_width
	tire.mesh = cylinder
	tire.rotation_degrees.z = 90.0  # cylinder axis (Y) -> axle axis (X)
	tire.material_override = _flat_material(Color(0.12, 0.12, 0.12))
	_spin_pivot.add_child(tire)

	# A bar across the wheel face, so you can see it spin.
	var hub := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(stats.wheel_width + 0.02, stats.wheel_radius * 1.6, 0.08)
	hub.mesh = bar
	hub.material_override = _flat_material(Color(0.75, 0.75, 0.78))
	_spin_pivot.add_child(hub)


static func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
