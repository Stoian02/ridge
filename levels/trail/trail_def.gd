class_name TrailDef
extends Resource
## Road settings for one trail. Distances are metres along the road; lateral
## positions are metres from the centre line (+ = right when driving forward).

@export_group("Cross-section")
@export var road_width: float = 7.0
@export var shoulder_width: float = 2.5
## Use the curve's transported up vector and authored tilt; false keeps snow roads unbanked.
@export var use_curve_banking: bool = true
@export var line_width: float = 0.15
## Painted edge lines sit this far inside each road edge.
@export var line_inset: float = 0.3
## Spacing of vertices across the road.
@export var lateral_step: float = 0.5
## Distance between cross-sections outside rough ranges.
@export var sample_step: float = 1.0
## Distance between cross-sections inside rough ranges and pothole clusters.
@export var detail_step: float = 0.25
## Length of road built as one mesh and collision chunk.
@export var chunk_length: float = 100.0
## Mesh-only visibility distance; 0 keeps the original unlimited drawing.
## Collision is never culled. Match this to the level's terrain/fog horizon.
@export var road_view_distance: float = 0.0
## Opt-in earth join outside the shoulders; 0 keeps existing levels unchanged.
@export var terrain_blend_width: float = 0.0
## Actual missing spans with ramps and dry ravine cuts; empty preserves old roads.
@export var road_gaps: Array[RoadGapDef] = []
## Ground-supported road sections which need not be redrawn into shadow maps.
## (start, length); receiving shadows and all collision stay enabled.
@export var shadowless_sections: Array[Vector2] = []

@export_group("Width profile")
## Stretches where the road changes width, as Vector4(start, length, road width,
## shoulder width) in metres. They must not overlap. Outside them the road keeps
## road_width and shoulder_width.
@export var width_stretches: Array[Vector4] = []
## The widths ease from the trail's to a stretch's over this distance inside each of its ends (m).
@export var width_blend: float = 10.0
## Optional (distance, outward-bank degrees) knots, smoothly interpolated.
## Positive angles put the left edge above the right. Zero outside the knots.
@export var bank_profile: Array[Vector2] = []
## Close rock cuts on the left: (start, length, face height, reach into hillside).
## Separate closed meshes preserve the terrain grid's protection of nearby roads.
@export var shelf_walls: Array[Vector4] = []

@export_group("Surface")
## The road's surface outside any stretch. Shoulders are dirt outside stretches.
@export var base_surface: SurfaceDef = preload("res://surfaces/asphalt.tres")
## Shoulder surface outside stretches (snow on Frozen Pass, dirt by default).
@export var shoulder_surface: SurfaceDef = preload("res://surfaces/dirt.tres")
## Painted edge lines along the road.
@export var painted_lines: bool = true
## Stretches of another surface (such as mud with ruts). They must not overlap.
@export var surface_stretches: Array[SurfaceStretch] = []
@export_range(0.0, 1.0) var road_roughness: float = 0.9
## Opt-in two-sided colour transitions (m); does not alter physical surfaces/ruts.
@export var surface_color_blend: float = 0.0

@export_group("Undulation")
## Peak height of the gentle waves along the whole road.
@export var undulation_amplitude: float = 0.05
## The two summed wave lengths.
@export var undulation_wavelengths: Vector2 = Vector2(23.0, 37.0)
## Local shallow rises/dips: (start, length, maximum amplitude, wavelength).
## Smoothly fade inside both ends; no sharp faces or extra fine-mesh ranges.
@export var undulation_sections: Array[Vector4] = []

@export_group("Rough ground")
## Rough stretches as Vector3(start distance, length, potholes per 100 m).
@export var rough_sections: Array[Vector3] = []
## Short pothole clusters as Vector2(centre distance, pothole count).
@export var pothole_clusters: Array[Vector2] = []
@export var pothole_radius_range: Vector2 = Vector2(0.35, 0.65)
@export var pothole_depth_range: Vector2 = Vector2(0.06, 0.12)
## Potholes and patches keep this far from the ends of a rough stretch.
@export var rough_margin: float = 3.0
## Individually seeded, graded damage with its own size/depth range and terrain clearance.
@export var damage_sections: Array[RoadDamageDef] = []
## Authored diagonal erosion channels; their terrain clearance is cut as well.
@export var cross_ruts: Array[CrossRutDef] = []

@export_group("Jumps")
## Jump crests shaped into the road, as Vector3(distance, height, length).
@export var jumps: Array[Vector3] = []
## Smooth full-width rollers as (distance, height, length), with no takeoff ledge.
@export var rollers: Array[Vector3] = []

@export_group("Checkpoints")
## The start gate sits this far along the road, leaving road behind the car.
@export var start_distance: float = 10.0
## The finish gate sits this far before the end of the road.
@export var end_margin: float = 10.0
## Checkpoint gate distances between the start and the finish. The start (0)
## and finish (road length) gates are added automatically.
@export var checkpoint_distances: PackedFloat32Array = PackedFloat32Array()

@export_group("Creek")
## A creek runs beside the road from creek_start for creek_length (m); 0 length = no creek.
@export var creek_start: float = 0.0
@export var creek_length: float = 0.0
## Lateral distance from the road centre to the creek's centre line (m, + = right).
@export var creek_offset: float = 17.0
@export var creek_width: float = 4.0
@export var creek_depth: float = 0.7
@export var creek_color: Color = Color(0.3, 0.4, 0.42)
## Steady flow along the drawn ribbon toward its lower end (m/s).
@export var creek_current_speed: float = 0.0

@export_group("Hedges")
## Dense hedge runs as Vector3(start distance, length, side), with -1 on the
## left and +1 on the right.
@export var hedges: Array[Vector3] = []
## Openings in hedge runs as Vector3(start distance, length, side).
@export var hedge_gaps: Array[Vector3] = []
## Outward hedge segments as Vector3(distance, length, side).
@export var hedge_returns: Array[Vector3] = []
@export var hedge_color: Color = Color(0.16, 0.25, 0.11)

@export_group("Shortcut")
@export var shortcut: TrailShortcut

@export_group("Structures")
@export var tunnels: Array[TunnelDef] = []
@export var bridges: Array[BridgeDef] = []
## Separate asphalt-deck masonry structures; empty leaves old builders untouched.
@export var stone_bridges: Array[StoneBridgeDef] = []
@export var rock_steps: Array[RockStepDef] = []
@export var boulder_fields: Array[BoulderFieldDef] = []
@export var fallen_trees: Array[FallenTreeDef] = []
@export var talus: Array[TalusDef] = []
@export var fords: Array[FordDef] = []

@export_group("Colours")
## The road's own colour: asphalt, or dirt on a dirt trail.
@export var asphalt_color: Color = Color(0.24, 0.23, 0.24)
@export var patch_color: Color = Color(0.3, 0.29, 0.28)
@export var line_color: Color = Color(0.92, 0.9, 0.84)
@export var shoulder_color: Color = Color(0.62, 0.47, 0.3)

## Seed for pothole and patch placement and undulation phases.
@export var seed: int = 1


## Half the widest road-plus-shoulders on the trail: the coarse bound terrain
## search radii, tunnel portals and earthworks use.
func half_total_width() -> float:
	var widest := road_width * 0.5 + shoulder_width
	for stretch: Vector4 in width_stretches:
		widest = maxf(widest, stretch.z * 0.5 + stretch.w)
	return widest


## The road's width at `distance`, eased into and out of any width stretch.
func road_width_at(distance: float) -> float:
	var stretch := _width_stretch_at(distance)
	return lerpf(road_width, stretch.y, stretch.x)


## The shoulder width at `distance`, eased like the road's.
func shoulder_width_at(distance: float) -> float:
	var stretch := _width_stretch_at(distance)
	return lerpf(shoulder_width, stretch.z, stretch.x)


## Half the road plus one shoulder at `distance`.
func half_total_width_at(distance: float) -> float:
	return road_width_at(distance) * 0.5 + shoulder_width_at(distance)


## (weight, road width, shoulder width) of the width stretch covering `distance`.
## The weight is 0 outside every stretch and rises to 1 over width_blend inside
## each end, so lerping the trail's widths toward the stretch's by it eases them.
## Off every stretch the weight is exactly 0, so the trail's widths come back unchanged.
func _width_stretch_at(distance: float) -> Vector3:
	for stretch: Vector4 in width_stretches:
		var end := stretch.x + stretch.y
		if distance >= stretch.x and distance < end:
			var blend := maxf(width_blend, 0.001)
			var weight := minf(smoothstep(stretch.x, stretch.x + blend, distance),
					1.0 - smoothstep(end - blend, end, distance))
			return Vector3(weight, stretch.z, stretch.w)
	return Vector3(0.0, road_width, shoulder_width)


func has_creek() -> bool:
	return creek_length > 0.0


func bank_degrees_at(distance: float) -> float:
	if bank_profile.size() < 2 or distance < bank_profile[0].x or distance > bank_profile[-1].x:
		return 0.0
	for i in range(1, bank_profile.size()):
		var a := bank_profile[i - 1]
		var b := bank_profile[i]
		if distance <= b.x:
			return lerpf(a.y, b.y, smoothstep(a.x, b.x, distance))
	return 0.0


func casts_shadow(from: float, to: float) -> bool:
	for section: Vector2 in shadowless_sections:
		if from >= section.x - 0.001 and to <= section.x + section.y + 0.001:
			return false
	return true


func gap_at(distance: float) -> RoadGapDef:
	for gap: RoadGapDef in road_gaps:
		if gap.contains(distance):
			return gap
	return null


func stone_bridge_at(distance: float) -> StoneBridgeDef:
	for bridge: StoneBridgeDef in stone_bridges:
		if bridge.contains(distance):
			return bridge
	return null


## Whole join-cell omission; collapsing endpoint widths alone leaves slivers.
func omits_earth_join(distance: float) -> bool:
	if gap_at(distance) != null or stone_bridge_at(distance) != null:
		return true
	for tunnel: TunnelDef in tunnels:
		if tunnel.omit_earth_joins and distance >= tunnel.start - tunnel.portal_length \
				and distance <= tunnel.end() + tunnel.portal_length:
			return true
	return false


## Independent validation keeps log bridges and established level defaults intact.
func stone_bridge_validation_errors(road_length: float) -> PackedStringArray:
	var errors := PackedStringArray()
	for i in stone_bridges.size():
		var bridge := stone_bridges[i]
		if bridge == null:
			errors.append("Null stone bridge")
			continue
		var error := bridge.validation_error(road_length)
		if not error.is_empty():
			errors.append(error)
			continue
		for at: float in [bridge.start, bridge.end()]:
			if not is_equal_approx(road_width_at(at), bridge.clear_width):
				errors.append("Stone deck must join the full approach road width")
		if base_surface == null or base_surface.id != &"asphalt":
			errors.append("Stone bridge requires a dry asphalt reservation")
		var occupied: Array[Vector2] = []
		for j in range(i):
			var other := stone_bridges[j]
			if other != null:
				occupied.append(Vector2(other.start, other.end()))
		for other: BridgeDef in bridges:
			occupied.append(Vector2(other.start, other.end() + other.ramp_length))
		for tunnel: TunnelDef in tunnels:
			occupied.append(Vector2(tunnel.start - tunnel.portal_length, tunnel.end() + tunnel.portal_length))
		for gap: RoadGapDef in road_gaps:
			if gap != null:
				occupied.append(Vector2(gap.takeoff_start, gap.recovery_end))
		for stretch: SurfaceStretch in surface_stretches:
			occupied.append(Vector2(stretch.start - stretch.blend_length, stretch.end() + stretch.blend_length))
		for section: Vector3 in rough_sections:
			occupied.append(Vector2(section.x, section.x + section.y))
		for section: RoadDamageDef in damage_sections:
			occupied.append(Vector2(section.start, section.start + section.length))
		for rut: CrossRutDef in cross_ruts:
			occupied.append(rut.bounds())
		for hump: Vector3 in jumps:
			occupied.append(Vector2(hump.x - hump.z * 0.5, hump.x + hump.z * 0.5))
		for roller: Vector3 in rollers:
			occupied.append(Vector2(roller.x - roller.z * 0.5, roller.x + roller.z * 0.5))
		for step: RockStepDef in rock_steps:
			occupied.append(Vector2(step.distance - step.face_length, step.distance + step.ramp_length))
		for ford: FordDef in fords:
			occupied.append(Vector2(ford.distance - ford.half_width() - ford.bank_run,
				ford.distance + ford.half_width() + ford.bank_run))
		for span: Vector2 in occupied:
			if span.x < bridge.end() and span.y > bridge.start:
				errors.append("Stone bridge overlaps another structure, surface or road profile")
	return errors


## Fail closed before generating a partially supported or overlapping gap.
func gap_validation_errors(road_length: float) -> PackedStringArray:
	var errors := PackedStringArray()
	for i in road_gaps.size():
		var gap := road_gaps[i]
		if gap == null:
			errors.append("Null road gap")
			continue
		var problem := gap.validation_error(road_length)
		if not problem.is_empty():
			errors.append(problem)
		if gap.cut_half_width < half_total_width() + terrain_blend_width + 4.0:
			errors.append("Gap cut must extend beyond the shoulders and earth join")
		for j in range(i):
			var other := road_gaps[j]
			if other != null and gap.takeoff_start < other.recovery_end and gap.recovery_end > other.takeoff_start:
				errors.append("Road gap profiles overlap")
		for bridge: BridgeDef in bridges:
			if bridge.start < gap.recovery_end and bridge.end() + bridge.ramp_length > gap.takeoff_start:
				errors.append("Road gap overlaps a log bridge")
		for bridge: StoneBridgeDef in stone_bridges:
			if bridge != null and bridge.start < gap.recovery_end and bridge.end() > gap.takeoff_start:
				errors.append("Road gap overlaps a stone bridge")
		for tunnel: TunnelDef in tunnels:
			if tunnel.start - tunnel.portal_length < gap.recovery_end and tunnel.end() + tunnel.portal_length > gap.takeoff_start:
				errors.append("Road gap overlaps a tunnel portal")
		for stretch: SurfaceStretch in surface_stretches:
			for at: float in stretch.surface_boundaries():
				if at > gap.takeoff_start and at < gap.recovery_end:
					errors.append("Surface transition inside a gap approach/landing")
		var occupied: Array[Vector2] = []
		for hump: Vector3 in jumps:
			occupied.append(Vector2(hump.x - hump.z * 0.5, hump.x + hump.z * 0.5))
		for ford: FordDef in fords:
			var reach := ford.channel_width * 0.5 + ford.bank_run
			occupied.append(Vector2(ford.distance - reach, ford.distance + reach))
		for step: RockStepDef in rock_steps:
			occupied.append(Vector2(step.distance - step.face_length, step.distance + step.ramp_length))
		for rocks: BoulderFieldDef in boulder_fields:
			occupied.append(Vector2(rocks.start, rocks.end()))
		for stones: TalusDef in talus:
			occupied.append(Vector2(stones.start, stones.end()))
		for tree: FallenTreeDef in fallen_trees:
			occupied.append(Vector2(tree.distance - tree.length, tree.distance + tree.length))
		for span: Vector2 in occupied:
			if span.x < gap.recovery_end and span.y > gap.takeoff_start:
				errors.append("Road gap overlaps an obstacle or another road profile")
	return errors
