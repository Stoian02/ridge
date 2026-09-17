@tool
class_name TrailLevel
extends Node3D
## Generates a whole trail from its "Road" Path3D child and its settings: road
## surface, terrain, shortcuts, hedges, creek, scenery and checkpoint gates. It
## builds on load in the game. In the editor, tick Rebuild to preview after
## moving the road's curve points. The Road child must keep an identity
## transform: the curve's points are used as positions in this node's space.

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
var tunnel_builder: TunnelBuilder
var bridge_builder: BridgeBuilder
var shortcut_builder: ShortcutBuilder
var terrain_builder: TerrainBuilder
var hedge_builder: HedgeBuilder
var creek_builder: CreekBuilder
var scatter_builder: ScatterBuilder
var checkpoints: CheckpointPlacer
## How long the last build took (s).
var build_seconds := 0.0
## Seconds each part of the last build took, in build order (phase name -> seconds).
var build_phases := {}

var _lap_usec := 0


func _ready() -> void:
	if not Engine.is_editor_hint():
		build()


func build() -> void:
	var started := Time.get_ticks_usec()
	build_phases.clear()
	_lap_usec = started
	var old := get_node_or_null("Generated")
	if old != null:
		remove_child(old)
		old.queue_free()
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)

	var road: Path3D = $Road
	sampler = RoadSampler.new(road.curve, trail.use_curve_banking, trail)
	profile = RoadProfile.new(trail, sampler.length)
	field = TerrainField.generate(sampler, trail, terrain)
	_lap(&"field")

	road_builder = RoadBuilder.new()
	road_builder.name = "Road"
	generated.add_child(road_builder)
	road_builder.build(sampler, profile, trail)
	_lap(&"road")

	# The shortcut stores the unmodified terrain for its ribbon, then lowers the
	# field beneath its potholes before TerrainBuilder consumes it.
	shortcut_builder = ShortcutBuilder.new()
	shortcut_builder.name = "Shortcut"
	generated.add_child(shortcut_builder)
	shortcut_builder.build(field, sampler, profile, trail)
	_lap(&"shortcut")

	terrain_builder = TerrainBuilder.new()
	terrain_builder.name = "Terrain"
	generated.add_child(terrain_builder)
	terrain_builder.build(field)
	_lap(&"terrain")

	tunnel_builder = TunnelBuilder.new()
	tunnel_builder.name = "Tunnels"
	generated.add_child(tunnel_builder)
	tunnel_builder.build(sampler, field, trail)
	_lap(&"tunnels")

	bridge_builder = BridgeBuilder.new()
	bridge_builder.name = "Bridges"
	generated.add_child(bridge_builder)
	bridge_builder.build(sampler, profile, field, trail)
	_lap(&"bridges")

	hedge_builder = HedgeBuilder.new()
	hedge_builder.name = "Hedges"
	generated.add_child(hedge_builder)
	hedge_builder.build(field, sampler, trail)
	_lap(&"hedges")

	creek_builder = CreekBuilder.new()
	creek_builder.name = "Creek"
	generated.add_child(creek_builder)
	creek_builder.build(field, sampler, trail)
	_lap(&"creek")

	scatter_builder = ScatterBuilder.new()
	scatter_builder.name = "Scatter"
	generated.add_child(scatter_builder)
	scatter_builder.build(field, sampler, profile, trail, scatter)
	_lap(&"scatter")

	checkpoints = CheckpointPlacer.new()
	checkpoints.name = "Checkpoints"
	generated.add_child(checkpoints)
	checkpoints.build(sampler, profile, trail)
	_lap(&"checkpoints")

	build_seconds = (Time.get_ticks_usec() - started) / 1000000.0
	built.emit()


## The last build's phases as "field 0.29 s, road 0.21 s, ...".
func phase_summary() -> String:
	var parts := PackedStringArray()
	for phase: StringName in build_phases:
		parts.append("%s %.2f s" % [phase, build_phases[phase]])
	var split := PackedStringArray()
	for part: String in terrain_builder.last_timings if terrain_builder != null else {}:
		split.append("%s %.2f" % [part, terrain_builder.last_timings[part]])
	return ", ".join(parts) + ("; terrain: " + ", ".join(split) if not split.is_empty() else "")


## Records the time since the previous lap as `phase`.
func _lap(phase: StringName) -> void:
	var now := Time.get_ticks_usec()
	build_phases[phase] = (now - _lap_usec) / 1000000.0
	_lap_usec = now


## Where a run starts: the start gate's reset transform.
func start_transform() -> Transform3D:
	return checkpoints.reset_transforms[0]


## Falling below this height counts as falling off the map.
func kill_height() -> float:
	return field.kill_height()
