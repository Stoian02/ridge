extends Node3D
## Gray-box tuning ground, reached as Free Drive from the main menu (no clock or
## stars). From the spawn point, facing -Z:
##   - dirt everywhere (the base ground)
##   - an asphalt runway straight ahead, with slalom cones and a kicker jump
##   - a mud strip parallel to the runway, 30 m to the right
##   - three hills to the left: 10 and 20 degree dirt, 30 degree asphalt
##   - a rough asphalt lane 60 m to the right: potholes, speed bumps, washboard
##   - a rutted mud strip 90 m to the right
## Press R (or the Reset button) to return to the spawn point; Pause, Escape or the
## back gesture open a pause menu without Restart.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")

## Thickness of ramps and plateaus (m).
const SLAB := 1.0

@onready var rig: DrivingRig = $DrivingRig

var pause_menu: PauseMenu
var _spawn: Transform3D


func _ready() -> void:
	_build_layout()
	_spawn = rig.car.global_transform
	rig.car.input.reset_requested.connect(_on_reset_requested)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.show_restart = false
	add_child(pause_menu)
	pause_menu.setup(rig)
	rig.pause_requested.connect(pause_menu.toggle)
	pause_menu.back_pressed.connect(pause_menu.open)
	pause_menu.main_menu_pressed.connect(GameState.change_scene.bind(GameState.MAIN_MENU))
	pause_menu.car_select_pressed.connect(GameState.choose_car_for.bind(GameState.FREE_DRIVE))


func _on_reset_requested() -> void:
	rig.place_car(_spawn)


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
	_add_rough_patch(ASPHALT, RoughPatch.Profile.ROUGH_ASPHALT, Vector3(60.0, 0.0, -110.0), Vector2(10.0, 200.0))
	_add_rough_patch(MUD, RoughPatch.Profile.RUTTED_MUD, Vector3(90.0, 0.0, -60.0), Vector2(10.0, 100.0))


## An uneven strip (see RoughPatch). center: middle of the strip at ground level.
func _add_rough_patch(surface: SurfaceDef, profile: RoughPatch.Profile, center: Vector3, size: Vector2) -> void:
	var patch := RoughPatch.new()
	patch.surface = surface
	patch.profile = profile
	patch.size = size
	patch.position = center
	add_child(patch)


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
