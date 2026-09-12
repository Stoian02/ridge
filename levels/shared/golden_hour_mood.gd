class_name GoldenHourMood
extends Node3D
## Over the Hill-inspired lighting: a low warm sun, a gradient sky, sky-tinted fog
## and a soft colour grade. Drop into any level; tweak the exported values per level.

@export var sun_color := Color(1.0, 0.82, 0.6)
@export var sun_energy := 1.3
## Sun height above the horizon and its compass direction, in degrees.
@export var sun_elevation_deg := 22.0
@export var sun_azimuth_deg := -35.0
@export var sky_top := Color(0.36, 0.52, 0.78)
@export var sky_horizon := Color(0.98, 0.76, 0.56)
@export var ground_color := Color(0.42, 0.33, 0.27)
@export var fog_density := 0.006
## How far from the camera the sun still casts shadows (m). Lower = cheaper.
@export var shadow_distance := 80.0

var environment: Environment
var sun: DirectionalLight3D


func _ready() -> void:
	environment = _build_environment()
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	sun = _build_sun()
	add_child(sun)


func _build_environment() -> Environment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = sky_top
	sky_material.sky_horizon_color = sky_horizon
	sky_material.ground_horizon_color = sky_horizon
	sky_material.ground_bottom_color = ground_color
	sky_material.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.fog_enabled = true
	env.fog_light_color = sky_horizon
	env.fog_density = fog_density
	env.fog_sky_affect = 0.3
	env.glow_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	return env


func _build_sun() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.light_color = sun_color
	light.light_energy = sun_energy
	light.shadow_enabled = true
	light.directional_shadow_max_distance = shadow_distance
	light.rotation_degrees = Vector3(-sun_elevation_deg, sun_azimuth_deg, 0.0)
	return light
