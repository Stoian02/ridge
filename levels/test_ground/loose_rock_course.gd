class_name LooseRockCourse
extends Node3D
## Isolated loose-rock practice lane. Local entry is z = 0, driving toward -Z.

const SIZE := Vector2(4.5, 90.0)
const SURFACE := preload("res://surfaces/scree.tres")
const PROFILE := RoughPatch.Profile.LOOSE_ROCK_SLOPE

var talus: TalusBuilder


func _ready() -> void:
	var patch := RoughPatch.new()
	patch.name = "BankedLane"
	patch.surface = SURFACE
	patch.profile = PROFILE
	patch.size = SIZE
	patch.spacing = 0.25
	patch.position.z = -SIZE.y * 0.5
	add_child(patch)
	for child in patch.get_children():
		if child is MeshInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	talus = TalusBuilder.new()
	talus.name = "LooseStones"
	add_child(talus)
	talus.build_patch(definitions(), floor_height)


## Same height function as the rendered/colliding patch, in course-local space.
static func floor_height(x: float, z: float) -> float:
	return RoughPatch.height_at(PROFILE, Vector2(x, z + SIZE.y * 0.5), SIZE)


static func definitions() -> Array[TalusDef]:
	# Keep fragments small even when they tip onto an edge. The first prototype's
	# 0.30 m radii could stand upright beneath the chassis and unload the tyres.
	return [
		_field(12.0, 17.0, 24, Vector2(0.07, 0.10), Vector2(1.0, 4.0), 901),
		_field(12.0, 17.0, 12, Vector2(0.11, 0.125), Vector2(4.0, 10.0), 902),
		_field(38.0, 41.0, 54, Vector2(0.07, 0.10), Vector2(1.0, 4.0), 903),
		_field(38.0, 41.0, 30, Vector2(0.11, 0.125), Vector2(4.0, 10.0), 904),
	]


static func _field(start: float, length: float, count: int, sizes: Vector2,
		masses: Vector2, seed_value: int) -> TalusDef:
	var def := TalusDef.new()
	def.start = start
	def.length = length
	def.count = count
	def.size_range = sizes
	def.mass_range = masses * 2.0
	def.height_scale = 0.45
	def.continuous_collision = true
	def.contact_friction = 0.20
	def.lateral_range = Vector2(0.0, 1.8)
	def.color = Color(0.72, 0.66, 0.55) if sizes.y <= 0.10 else Color(0.52, 0.46, 0.39)
	def.seed = seed_value
	return def
