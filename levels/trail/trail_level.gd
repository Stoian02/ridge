@tool
class_name TrailLevel
extends Node3D
## Generates a whole trail from its "Road" Path3D child and its settings: road
## surface, terrain, hedges, creek, scenery and checkpoint gates. It builds on load in
## the game. In the editor, tick Rebuild to preview after moving the road's curve
## points. The Road child must keep an identity transform: the curve's points
## are used as positions in this node's space.

signal built

@export var trail: TrailDef
@export var terrain: TerrainDef
@export var scatter: ScatterDef
## Tick in the editor to regenerate the preview.
@export var rebuild: bool = false:
	set(value):
		if value and is_inside_tree():
			build()

var sampler: RoadSampler
var profile: RoadProfile
var field: TerrainField
var road_builder: RoadBuilder
var terrain_builder: TerrainBuilder
var hedge_builder: HedgeBuilder
var creek_builder: CreekBuilder
var scatter_builder: ScatterBuilder
var checkpoints: CheckpointPlacer
## How long the last build took (s).
var build_seconds := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		build()


func build() -> void:
	var started := Time.get_ticks_usec()
	var old := get_node_or_null("Generated")
	if old != null:
		remove_child(old)
		old.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)

	var road: Path3D = $Road
	sampler = RoadSampler.new(road.curve)
	profile = RoadProfile.new(trail, sampler.length)
	field = TerrainField.generate(sampler, trail, terrain)

	road_builder = RoadBuilder.new()
	road_builder.name = "Road"
	generated.add_child(road_builder)
	road_builder.build(sampler, profile, trail)

	terrain_builder = TerrainBuilder.new()
	terrain_builder.name = "Terrain"
	generated.add_child(terrain_builder)
	terrain_builder.build(field)

	hedge_builder = HedgeBuilder.new()
	hedge_builder.name = "Hedges"
	generated.add_child(hedge_builder)
	hedge_builder.build(field, sampler, trail)

	creek_builder = CreekBuilder.new()
	creek_builder.name = "Creek"
	generated.add_child(creek_builder)
	creek_builder.build(field, sampler, trail)

	scatter_builder = ScatterBuilder.new()
	scatter_builder.name = "Scatter"
	generated.add_child(scatter_builder)
	scatter_builder.build(field, sampler, profile, trail, scatter)

	checkpoints = CheckpointPlacer.new()
	checkpoints.name = "Checkpoints"
	generated.add_child(checkpoints)
	checkpoints.build(sampler, profile, trail)

	build_seconds = (Time.get_ticks_usec() - started) / 1000000.0
	built.emit()


## Where a run starts: the start gate's reset transform.
func start_transform() -> Transform3D:
	return checkpoints.reset_transforms[0]


## Falling below this height counts as falling off the map.
func kill_height() -> float:
	return field.kill_height()
