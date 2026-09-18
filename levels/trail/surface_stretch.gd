class_name SurfaceStretch
extends Resource
## A stretch of a trail's road with another surface than the trail's base, such
## as mud with two wheel ruts. Distances are metres along the road.

@export var start: float = 0.0
@export var length: float = 50.0
@export var surface: SurfaceDef
## Mud reaches the verges; winter ice/concrete can keep snowy shoulders instead.
@export var affects_shoulders: bool = true
## Ordered physical surfaces from the base road toward `surface`. They occupy
## equal parts of transition_length at both ends, in reverse order on exit.
@export var transition_surfaces: Array[SurfaceDef] = []
## Total physical transition length at each end (m).
@export var transition_length: float = 0.0
@export var color: Color = Color(0.27, 0.2, 0.14)
## Material roughness (ice is glossy); collision remains defined by surface.
@export_range(0.0, 1.0) var roughness: float = 0.9
## Depth of the two wheel ruts (m); 0 = no ruts.
@export var rut_depth: float = 0.0
## Opt-in standing water above the rut floor (m), clipped below both lips.
## Visual only; 0 preserves the dry geometry of every existing stretch.
@export var water_rut_depth: float = 0.0
## Distance between the two ruts' centre lines, centred on the road (m).
@export var rut_spacing: float = 1.55
## Width of each rut (m).
@export var rut_width: float = 0.8
## Additional driven lines: (lateral offset, weave amplitude, wavelength, phase).
## Each carries a pair of wheel tracks. Overlaps take the deeper rut rather
## than adding depths into an accidental trench. Empty keeps the original pair.
@export var extra_rut_paths: Array[Vector4] = []
## The colour and the ruts fade in over this distance inside each end (m).
@export var blend_length: float = 2.0


func end() -> float:
	return start + length


func rut_centres(distance: float) -> PackedFloat64Array:
	var half := rut_spacing * 0.5
	var centres := PackedFloat64Array([-half, half])
	for path: Vector4 in extra_rut_paths:
		var offset := path.x + path.y * sin(TAU * (distance - start) / maxf(path.z, 1.0) + path.w)
		centres.append(offset - half)
		centres.append(offset + half)
	return centres


func contains(distance: float) -> bool:
	return distance >= start and distance < end()


## Physical surface at a distance known to be inside this stretch.
func surface_at(distance: float) -> SurfaceDef:
	if transition_surfaces.is_empty() or transition_length <= 0.0:
		return surface
	var edge_distance := minf(distance - start, end() - distance)
	var stage_length := transition_length / transition_surfaces.size()
	var stage := floori(edge_distance / stage_length)
	return transition_surfaces[stage] if stage >= 0 and stage < transition_surfaces.size() else surface


## Stretch ends and every physical transition boundary, sorted.
func surface_boundaries() -> PackedFloat32Array:
	var boundaries := PackedFloat32Array([start, end()])
	if transition_surfaces.is_empty() or transition_length <= 0.0:
		return boundaries
	var stage_length := transition_length / transition_surfaces.size()
	for stage in range(1, transition_surfaces.size() + 1):
		var offset := stage_length * stage
		if offset >= length * 0.5:
			break
		boundaries.append(start + offset)
		boundaries.append(end() - offset)
	boundaries.sort()
	return boundaries


## How strongly the stretch shows at `distance`: 0 outside it, rising to 1 over
## blend_length inside each end.
func weight(distance: float) -> float:
	if not contains(distance):
		return 0.0
	var blend := maxf(blend_length, 0.001)
	return minf(smoothstep(start, start + blend, distance), 1.0 - smoothstep(end() - blend, end(), distance))
