extends Node3D
## Gray-box tuning ground, reached as Free Drive from the main menu (no clock or
## stars). From the spawn point, facing -Z:
##   - dirt everywhere (the base ground)
##   - an asphalt runway straight ahead, with slalom cones, a kicker jump and a
##     distance board every 10 m
##   - a mud strip parallel to the runway, 30 m to the right
##   - three hills to the left: 10 and 20 degree dirt, 30 degree asphalt
##   - two side slopes further left, asphalt then dirt: drive along them and the
##     ground tilts from flat to 40 degrees across, with a marker every 5 degrees
##   - a rough asphalt lane 60 m to the right: potholes, speed bumps, washboard
##   - a rutted mud strip 90 m to the right
##   - a suspension course further right: an axle twister, whoops, curb steps
##     (10-40 cm), and ground clearance logs (15, 25, 35 cm)
##   - a skidpad behind the spawn: a flat asphalt circle 30 m across
## Press R (or the Reset button) to return to the spawn point; Pause, Escape or the
## back gesture open a pause menu without Restart.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")

## Thickness of ramps and plateaus (m).
const SLAB := 1.0

## Side slopes: centre x, and the size of both strips (width across, length along).
const ASPHALT_SLOPE_X := -110.0
const DIRT_SLOPE_X := -140.0
const SLOPE_SIZE := Vector2(14.0, 180.0)
## Every strip's entry (+Z) end sits on this line.
const STRIP_ENTRY_Z := 10.0
const TWISTER_X := 125.0
const WHOOPS_X := 145.0
const STEPS_X := 165.0
const LOGS_X := 185.0
## Curb step heights (m) and log diameters (m), in the order you reach them.
const STEP_HEIGHTS: Array[float] = [0.1, 0.2, 0.3, 0.4]
const LOG_DIAMETERS: Array[float] = [0.15, 0.25, 0.35]
const SKIDPAD_CENTER := Vector3(0.0, 0.0, 70.0)
const SKIDPAD_RADIUS := 15.0
const RUNWAY_BOARD_SPACING := 10.0
const RUNWAY_LENGTH := 390.0
const SIGN_COLOR := Color(1.0, 0.95, 0.8)
const MARKER_COLOR := Color(1.0, 0.45, 0.1)
## Small labels (distances, degrees, heights) are drawn only this close (m): every
## label costs draw calls, and farther ones can't be read anyway.
const LABEL_RANGE := 70.0
## Area titles stay visible from this far (m), so each area can be found.
const TITLE_RANGE := 300.0

@onready var rig: DrivingRig = $DrivingRig

var pause_menu: PauseMenu
var _spawn: Transform3D
## Marker posts as Vector4(base x, base y, base z, height), merged into one mesh.
var _posts: Array[Vector4] = []


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
	_add_runway_boards()
	_add_side_slope(ASPHALT, ASPHALT_SLOPE_X, "SIDE SLOPE - ASPHALT")
	_add_side_slope(DIRT, DIRT_SLOPE_X, "SIDE SLOPE - DIRT")
	_add_suspension_course()
	_add_skidpad()
	_build_posts()


## A distance board every 10 m down the left edge of the runway, counted from the spawn.
func _add_runway_boards() -> void:
	var distance := RUNWAY_BOARD_SPACING
	while distance <= RUNWAY_LENGTH:
		_add_post(Vector3(-8.0, 0.0, -distance), 1.2)
		_add_label("%d m" % roundi(distance), Vector3(-8.0, 1.7, -distance), 72)
		distance += RUNWAY_BOARD_SPACING


## A side slope entered at STRIP_ENTRY_Z, rising toward -X, with a marker every 5
## degrees just off its low (+X) edge.
func _add_side_slope(surface: SurfaceDef, center_x: float, title: String) -> void:
	var center := Vector3(center_x, 0.0, STRIP_ENTRY_Z - SLOPE_SIZE.y * 0.5)
	_add_rough_patch(surface, RoughPatch.Profile.SIDE_SLOPE, center, SLOPE_SIZE, 0.5)
	_add_label(title, Vector3(center_x, 3.0, STRIP_ENTRY_Z + 4.0), 160, TITLE_RANGE)
	var marker_x := center_x + SLOPE_SIZE.x * 0.5 + 1.5
	for step in range(1, 9):
		var degrees := step * 5.0
		var z := STRIP_ENTRY_Z - RoughPatch.slope_distance_for(degrees, SLOPE_SIZE.y)
		_add_post(Vector3(marker_x, 0.0, z), 1.0)
		_add_label("%d°" % roundi(degrees), Vector3(marker_x, 1.6, z), 96)


## The axle twister and whoops strips, curb steps and ground clearance logs, side by
## side and entered at STRIP_ENTRY_Z.
func _add_suspension_course() -> void:
	_add_rough_patch(ASPHALT, RoughPatch.Profile.TWISTER, Vector3(TWISTER_X, 0.0, STRIP_ENTRY_Z - 35.0), Vector2(10.0, 70.0))
	_add_label("AXLE TWISTER", Vector3(TWISTER_X, 3.0, STRIP_ENTRY_Z + 4.0), 128, TITLE_RANGE)
	_add_rough_patch(DIRT, RoughPatch.Profile.WHOOPS, Vector3(WHOOPS_X, 0.0, STRIP_ENTRY_Z - 55.0), Vector2(10.0, 110.0))
	_add_label("WHOOPS", Vector3(WHOOPS_X, 3.0, STRIP_ENTRY_Z + 4.0), 128, TITLE_RANGE)
	_add_label("CURB STEPS", Vector3(STEPS_X, 3.0, STRIP_ENTRY_Z + 4.0), 128, TITLE_RANGE)
	for i in STEP_HEIGHTS.size():
		var height := STEP_HEIGHTS[i]
		var z := STRIP_ENTRY_Z - 20.0 - i * 20.0
		# Each step is a 4 m long block you drive up onto and drop off again.
		_add_block(ASPHALT, Vector3(10.0, height, 4.0), Vector3(STEPS_X, height * 0.5, z))
		_add_label("%d cm" % roundi(height * 100.0), Vector3(STEPS_X + 6.5, 1.6, z), 96)
	_add_label("CLEARANCE LOGS", Vector3(LOGS_X, 3.0, STRIP_ENTRY_Z + 4.0), 128, TITLE_RANGE)
	for i in LOG_DIAMETERS.size():
		var diameter := LOG_DIAMETERS[i]
		var z := STRIP_ENTRY_Z - 25.0 - i * 25.0
		_add_log(Vector3(LOGS_X, 0.0, z), diameter, 10.0)
		_add_label("%d cm" % roundi(diameter * 100.0), Vector3(LOGS_X + 6.5, 1.6, z), 96)


## A flat asphalt circle with a painted ring, for comparing cornering grip.
func _add_skidpad() -> void:
	var body := StaticBody3D.new()
	body.name = "Skidpad"
	body.set_meta(SurfaceLookup.META_KEY, ASPHALT)
	body.position = SKIDPAD_CENTER + Vector3(0.0, -0.08, 0.0)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = SKIDPAD_RADIUS
	cylinder.height = 0.2
	shape.shape = cylinder
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = SKIDPAD_RADIUS
	disc.bottom_radius = SKIDPAD_RADIUS
	disc.height = 0.2
	disc.radial_segments = 48
	mesh.mesh = disc
	mesh.material_override = _flat_material(ASPHALT.debug_color)
	body.add_child(mesh)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = SKIDPAD_RADIUS - 2.4
	torus.outer_radius = SKIDPAD_RADIUS - 2.0
	torus.rings = 64
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.position.y = 0.11
	ring.material_override = _flat_material(Color(0.95, 0.95, 0.9))
	body.add_child(ring)
	add_child(body)
	_add_label("SKIDPAD", SKIDPAD_CENTER + Vector3(0.0, 3.0, -SKIDPAD_RADIUS - 3.0), 160, TITLE_RANGE)


## An uneven strip (see RoughPatch). center: middle of the strip at ground level.
func _add_rough_patch(surface: SurfaceDef, profile: RoughPatch.Profile, center: Vector3, size: Vector2,
		spacing := RoughPatch.SPACING) -> void:
	var patch := RoughPatch.new()
	patch.surface = surface
	patch.profile = profile
	patch.size = size
	patch.spacing = spacing
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


## A log lying across a lane (along X), resting on the ground.
func _add_log(base: Vector3, diameter: float, length: float) -> void:
	var body := StaticBody3D.new()
	body.position = base + Vector3(0.0, diameter * 0.5, 0.0)
	body.rotation_degrees.z = 90.0
	body.set_meta(SurfaceLookup.META_KEY, DIRT)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = diameter * 0.5
	cylinder.height = length
	shape.shape = cylinder
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = diameter * 0.5
	cylinder_mesh.bottom_radius = diameter * 0.5
	cylinder_mesh.height = length
	mesh.mesh = cylinder_mesh
	mesh.material_override = _flat_material(Color(0.42, 0.29, 0.18))
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
	mesh.material_override = _flat_material(MARKER_COLOR)
	mesh.position = base + Vector3(0.0, 0.35, 0.0)
	add_child(mesh)


## Visual-only marker post, `height` metres tall, standing on `base`. Posts are
## collected here and built together by _build_posts().
func _add_post(base: Vector3, height: float) -> void:
	_posts.append(Vector4(base.x, base.y, base.z, height))


## Every marker post in one vertex-coloured mesh: one draw call instead of one each.
func _build_posts() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for post in _posts:
		var center := Vector3(post.x, post.y + post.w * 0.5, post.z)
		LowPolyMeshes._add_box(tool, center, Vector3(0.12, post.w, 0.12), MARKER_COLOR)
	var mesh := MeshInstance3D.new()
	mesh.name = "MarkerPosts"
	mesh.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	mesh.material_override = material
	add_child(mesh)


## Visual-only text that always faces the camera, drawn only within `max_distance` metres.
func _add_label(text: String, position: Vector3, font_size: int, max_distance := LABEL_RANGE) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.01
	label.outline_size = 16
	label.modulate = SIGN_COLOR
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = max_distance
	label.position = position
	add_child(label)


static func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
