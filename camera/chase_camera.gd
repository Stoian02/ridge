class_name ChaseCamera
extends Camera3D
## Smooth third-person camera behind and above the car. It follows the car's
## heading flattened to the horizontal, so it doesn't tumble with the car in the air.

@export var target: Car
@export var distance: float = 6.5
@export var height: float = 2.4
## The camera looks at a point this far ahead of the car and this high above it.
@export var look_ahead: float = 3.0
@export var look_height: float = 0.8
## How quickly the camera catches up, per second. Higher = tighter.
@export var follow_stiffness: float = 5.0
@export var look_stiffness: float = 10.0

var _heading := Vector3.FORWARD
var _look_point := Vector3.ZERO


func _ready() -> void:
	if target != null:
		snap_to_target()


func _process(delta: float) -> void:
	if target == null:
		return
	_heading = flat_heading(target.global_basis, _heading)
	var position_now := damp(global_position, _desired_position(), follow_stiffness, delta)
	global_position = _avoid_terrain(position_now)
	_look_point = damp(_look_point, _desired_look_point(), look_stiffness, delta)
	look_at(_look_point, Vector3.UP)


## Jump straight to the resting position, e.g. after a reset.
func snap_to_target() -> void:
	_heading = flat_heading(target.global_basis, _heading)
	global_position = _desired_position()
	_look_point = _desired_look_point()
	look_at(_look_point, Vector3.UP)


## Frame-rate independent exponential smoothing toward target_value.
static func damp(current: Vector3, target_value: Vector3, stiffness: float, delta: float) -> Vector3:
	return target_value + (current - target_value) * exp(-stiffness * delta)


## The car's forward direction flattened onto the horizontal plane. When the car
## points nearly straight up or down, the previous heading is kept.
static func flat_heading(car_basis: Basis, previous: Vector3) -> Vector3:
	var forward := -car_basis.z
	forward.y = 0.0
	if forward.length() < 0.2:
		return previous
	return forward.normalized()


func _desired_position() -> Vector3:
	return target.global_position - _heading * distance + Vector3.UP * height


func _desired_look_point() -> Vector3:
	return target.global_position + _heading * look_ahead + Vector3.UP * look_height


## Pull the camera in front of any terrain between it and the car.
func _avoid_terrain(camera_position: Vector3) -> Vector3:
	var from := target.global_position + Vector3.UP * look_height
	var query := PhysicsRayQueryParameters3D.create(from, camera_position)
	query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return camera_position
	var hit_position: Vector3 = hit["position"]
	return hit_position + (from - camera_position).normalized() * 0.3
