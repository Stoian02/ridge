class_name CarPreview
extends SubViewportContainer
## A small turning 3D view of a car for car select (spec §6.3): its low-poly body
## and simple wheels, lit by their own light in their own world, so the preview costs
## nothing outside the menu.

## Turning speed (radians per second).
const TURN_SPEED := 0.6
const TIRE_COLOR := Color(0.12, 0.12, 0.12)

var car: CarDef
## The node the body and wheels sit on; it turns.
var turntable: Node3D

var _viewport_size: Vector2i


func _init(shown_car: CarDef = null, viewport_size := Vector2i(480, 280)) -> void:
	car = shown_car
	_viewport_size = viewport_size
	stretch = true
	custom_minimum_size = Vector2(viewport_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = _viewport_size
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	add_child(viewport)
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.72, 0.66)
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	viewport.add_child(sun)
	turntable = Node3D.new()
	viewport.add_child(turntable)
	if car != null:
		_add_car()
	var reach := car.stats.body_size.z if car != null else 4.0
	var camera := Camera3D.new()
	camera.fov = 40.0
	# Close enough that the car fills most of the view as it turns.
	camera.position = Vector3(reach * 0.72, reach * 0.42, reach * 0.95)
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.15, 0.0))
	camera.current = true


func _process(delta: float) -> void:
	turntable.rotate_y(TURN_SPEED * delta)


func _add_car() -> void:
	var stats := car.stats
	var body := MeshInstance3D.new()
	body.mesh = CarBodyBuilder.build(car.body, stats)
	body.material_override = CarBodyBuilder.material()
	turntable.add_child(body)
	var tire := CylinderMesh.new()
	tire.top_radius = stats.wheel_radius
	tire.bottom_radius = stats.wheel_radius
	tire.height = stats.wheel_width
	var tire_material := StandardMaterial3D.new()
	tire_material.albedo_color = TIRE_COLOR
	for is_front: bool in [true, false]:
		for is_left: bool in [true, false]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = tire
			wheel.material_override = tire_material
			# Where the wheel rests with the car on its springs.
			wheel.position = stats.wheel_mount_position(is_front, is_left)
			wheel.position.y = stats.wheel_rest_height()
			wheel.rotation_degrees.z = 90.0
			turntable.add_child(wheel)
