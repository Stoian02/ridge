extends Node3D
## Gray-box tuning ground (dev only). From the spawn point, facing -Z:
##   - dirt everywhere (the base ground)
##   - an asphalt runway straight ahead, with slalom cones and a kicker jump
##   - a mud strip parallel to the runway, 30 m to the right
##   - three hills to the left: 10 and 20 degree dirt, 30 degree asphalt
## Press R (or the Reset button) to return to the spawn point.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")

## Thickness of ramps and plateaus (m).
const SLAB := 1.0

@onready var car: Car = $Car
@onready var camera: ChaseCamera = $ChaseCamera
@onready var touch_controls: TouchControls = $TouchControls
@onready var telemetry: TelemetryOverlay = $TelemetryOverlay
@onready var recorder: RunRecorder = $RunRecorder

var _spawn: Transform3D


func _ready() -> void:
	_build_layout()
	_spawn = car.global_transform
	car.input.reset_requested.connect(_on_reset_requested)
	touch_controls.telemetry_toggled.connect(telemetry.toggle)
	touch_controls.recording_toggled.connect(recorder.toggle)


func _on_reset_requested() -> void:
	car.reset_to(_spawn)
	camera.snap_to_target()


func _build_layout() -> void:
	_add_block(DIRT, Vector3(600.0, 1.0, 600.0), Vector3(0.0, -0.5, 0.0))
	# Strips sit 2 cm above the dirt so their surfaces don't overlap.
	_add_block(ASPHALT, Vector3(14.0, 0.2, 400.0), Vector3(0.0, -0.08, -190.0))
	_add_block(MUD, Vector3(14.0, 0.2, 300.0), Vector3(30.0, -0.08, -140.0))
	for i in 8:
		_add_cone(Vector3(-3.5 if i % 2 == 0 else 3.5, 0.02, -30.0 - i * 18.0))
	_add_ramp(ASPHALT, Vector3(0.0, 0.02, -250.0), 8.0, 15.0, 8.0)
	_add_hill(DIRT, Vector3(-30.0, 0.0, -20.0), 10.0, 40.0)
	_add_hill(DIRT, Vector3(-50.0, 0.0, -20.0), 20.0, 25.0)
	_add_hill(ASPHALT, Vector3(-70.0, 0.0, -20.0), 30.0, 16.0)


## A box of one surface. tilt_deg rotates it about X (+ raises its -Z end).
func _add_block(surface: SurfaceDef, size: Vector3, center: Vector3, tilt_deg := 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = center
	body.rotation_degrees.x = tilt_deg
	body.set_meta(SurfaceLookup.META_KEY, surface)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = surface.debug_color
	material.roughness = 0.9
	mesh.material_override = material
	body.add_child(mesh)

	add_child(body)


## A ramp whose top surface starts at near_edge and climbs toward -Z at angle_deg
## (negative angles go down). Returns the far edge of its top surface.
func _add_ramp(surface: SurfaceDef, near_edge: Vector3, width: float, angle_deg: float, length: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	# Where the near edge of the top face ends up, relative to the box centre,
	# once the box is tilted.
	var edge_offset := Vector3(0.0,
			SLAB * 0.5 * cos(a) - length * 0.5 * sin(a),
			SLAB * 0.5 * sin(a) + length * 0.5 * cos(a))
	_add_block(surface, Vector3(width, SLAB, length), near_edge - edge_offset, angle_deg)
	return near_edge + Vector3(0.0, length * sin(a), -length * cos(a))


## Up-ramp, a 10 m flat top, and a down-ramp.
func _add_hill(surface: SurfaceDef, start: Vector3, angle_deg: float, ramp_length: float) -> void:
	var width := 10.0
	var top := _add_ramp(surface, start, width, angle_deg, ramp_length)
	_add_block(surface, Vector3(width, SLAB, 10.0), top + Vector3(0.0, -SLAB * 0.5, -5.0))
	_add_ramp(surface, top + Vector3(0.0, 0.0, -10.0), width, -angle_deg, ramp_length)


## Visual-only cone marker.
func _add_cone(base: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.25
	cone.height = 0.7
	mesh.mesh = cone
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.45, 0.1)
	mesh.material_override = material
	mesh.position = base + Vector3(0.0, 0.35, 0.0)
	add_child(mesh)
