# Milestone 2 Part B2 — Muddy Valley Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Muddy Valley, a ~1.5 km dirt-and-mud trail with a creek, as the second level, by teaching the trail builder surface stretches, ruts, unpainted roads, a creek and broadleaf trees, and give both levels road past the finish.

**Architecture:** `TrailDef` gains a base surface, a painted-lines switch, a list of `SurfaceStretch` resources and creek settings. `RoadProfile` adds ruts inside stretches, and `RoadBuilder` puts rows exactly at stretch ends and splits collision by surface. `TerrainField` cuts a level creek channel that `CreekBuilder` fills with a water ribbon. `ScatterBuilder` adds broadleaf trees and keeps scenery out of the creek. A shared `CurveGenerator` builds both levels' curves. Rally Road's road is proven unchanged by a regression test recorded from `master`.

**Tech Stack:** Godot 4.7.2 (Mobile renderer, Jolt physics at 120 ticks/s), typed GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-09-14-m2b2-muddy-valley-design.md`

## Global Constraints

- Godot 4.7.2, typed GDScript: every variable has a type or is inferred with `:=`. A loop over an array literal names its type (`for offset: float in [...]`), because a value taken from an untyped array cannot be inferred and Godot refuses to compile the file. Indent with tabs. Doc comments use `##`.
- **No car-physics changes.** Nothing under `car/` changes, and `surfaces/*.tres` values stay as they are. Mud uses the existing mud surface (grip 0.5, rolling resistance 0.1, sink 0.06, drag 40).
- **Rally Road stays as it is** apart from the 60 m run-off past its finish (`end_margin = 70`). The regression values in `tests/unit/test_rally_road_regression.gd` were recorded from `master` at b349da9 and are copied verbatim; never change them to make a test pass.
- Tests: `./run_tests.sh unit`, `./run_tests.sh scenarios` or `./run_tests.sh all`. A run fails on any failing test or any `SCRIPT ERROR`. After adding a file with a new `class_name`, run `godot --headless --import` once before running tests, so the class is known.
- Budgets (spec §6, from the M2A spec §8): 60 fps held, < 300k triangles on screen, < 150 draw calls, < 4 ms physics, < 3 s level load after a fresh app start; desktop build time is checked with `assert_lt(build_seconds, 3.0)`.
- Commits: stage files by name. Never `git add -A` or `git add .`. Never stage or change `tmux-session.sh`. Commit the `.uid` files Godot creates next to new scripts. Every commit message ends with a blank line and then these two lines, using the name of the model that wrote the commit:
  ```
  Co-Authored-By: Claude <model name> <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RhfJavT34eWyW3enLLKWgH
  ```

## Decisions made while verifying this plan

The code below was written and run in a scratch clone before this plan was written. These choices refine the spec:

- **Creek shape and water:** the valley floor slopes away from the road, which ruled out both simpler cuts. A fixed-depth cut into sloping ground left the downhill rim below the channel floor. A level bed made the road-side bank too deep to drive out of. So:
  - **Nearest point:** each sample near the creek takes its shape from the nearest point on the centre line.
  - **Floor:** `creek_depth` below the higher of the centre-line ground and the sample's own ground. It is level downhill and follows the ground uphill.
  - **Banks:** they rise over 3 m to at least the centre-line ground, which forms a low raised bank on the downhill side.
  - **Beyond the banks:** raised ground falls back to natural over 4 m.
  - **Ends:** they taper over 10 m.
  - **Water level:** the lowest centre-line ground within 5 m either side, less 0.15 m.
  - **Laying water:** water is laid wherever it is at least 0.1 m above the channel floor.
- **Creek placement:** the creek runs on the right of the road at 745–895 m, beside the mud stretch at 760–850 m. On the left the valley side rises 4–9 m above the road from 940 m, and a creek there sat on the hillside with almost no water.
- **Creek escape test:** a car placed in the creek, facing along it with the steering straight, must leave the channel within 10 s.
  - Measured in scratch: along the creek it takes about 6 s, and away from the road about 3 s.
  - Straight at the road it stalls, because the road-side bank (about 28°) adds to the road's roughly 4 m embankment. That was ruled acceptable: the driver turns along the creek or uses Reset, and the bank is listed as a phone feel item.
  - The test does not use `TrailDriver`, which steers straight at the road.
- **Placeholder star times:** the scripted driver's final time was 1:39.9, so 2 stars under 95 s and 3 stars under 85 s.
- **Triangle budget:** Muddy Valley's rough sections cover about 800 m of road. At 0.25 m rows the road mesh alone pushed the view to 318–368k primitives, so Muddy Valley uses `detail_step = 0.5`, which brings the peak down to about 274k. Broadleaf trees were also cut from 72 to 48 triangles, at 16 m spacing.
- **No `valley_depth`:** the spec's optional valley setting is not added. The screenshots already read as a valley: the road drops 45 m below the ridge with hills on both sides.
- **Build determinism:** spec §7.2's "build twice" check is covered by `tests/unit/test_trail_level.gd`'s existing rebuild test, which uses the same builders. Building Muddy Valley twice in a scenario would add more than 3 s for no extra coverage.
- **Water mesh:** one ribbon for the whole creek (about 130 cross-sections), not one per terrain chunk.
- **`SurfaceStretch.rut_width`** (0.8 m) is added to the spec's fields. RoadBuilder puts five cross-section stations across each rut, so the grooves are shaped rather than lost between the 0.5 m lateral grid.
- **`RoadBuilder.Part.ASPHALT` is renamed `Part.ROAD`**, because the road is not always asphalt.
- **Muddy Valley's checkpoints** are at 270, 650, 950 and 1230 m. 300 m would fall on the jump at 330 m.
- **`tools/level_shots.tscn`** is added as a permanent tool (Task 7), replacing throwaway screenshot scenes.

## Verified results (scratch clone, desktop)

| Check | Result |
|---|---|
| Full suite | `./run_tests.sh all` green: 348 passing, 1 pending (the known held-gas jump test) |
| Rally Road regression | first 15 road chunks, 36 potholes, 12 patches match master b349da9; finish still at 1503.38 m |
| Rally Road build (desktop) | 1.1–1.3 s; scripted driver 1:30.3, unchanged |
| Muddy Valley build (desktop) | 1.6–1.7 s; 11 × 11 terrain chunks, 2140 pines, 7507 broadleaf, 6533 rocks, 53 posts, 42 water points |
| Muddy Valley scripted driver | 1:39.9, no resets, 155 wheel-ticks without contact away from the jump |
| Standstill in the 8% mud climb (1400 m) to the finish | 16.5 s |
| 3 s at full throttle from rest | 8.6 m on mud, 14.0 m on dirt |
| Out of the creek along it | 6.0 s, facing along the creek with the steering straight |
| Run-off | Muddy Valley: finish crossed at 29 km/h, stopped 4 m past it; Rally Road: 95 km/h, stopped 30 m past it (70 m of road after each finish) |
| Render counts (desktop, chase camera) | Muddy Valley peak 273,968 primitives and 133 draw calls; Rally Road peak 268,456 and 129 |

## File map

| File | Task | Responsibility |
|---|---|---|
| `levels/trail/surface_stretch.gd` | 1 | new: one stretch of another surface, its ruts and blend |
| `levels/trail/trail_def.gd` | 1 | base surface, painted lines, stretches, creek settings |
| `levels/trail/road_profile.gd` | 1 | ruts, surface lookup, stretch boundaries; tarmac patches only on asphalt |
| `levels/trail/road_builder.gd` | 2 | unpainted cross-sections, rut stations, rows at stretch ends, collision and colour by surface |
| `tests/unit/test_rally_road_regression.gd` | 2, 3 | Rally Road's road against values recorded from master |
| `tools/curve_generator.gd` | 3 | new: shared segment curve building, separation check, saving |
| `tools/generate_rally_road_curve.gd`, `levels/rally_road/rally_road_curve.tres`, `rally_road_trail.tres` | 3 | segment list only; 60 m run-off; `end_margin = 70` |
| `tests/scenarios/trail_scenarios.gd` | 3 | new: shared scenario steps (wait for GO, place, full throttle, brake) |
| `levels/trail/terrain_field.gd` | 4 | creek channel, creek distances, bed and water levels |
| `levels/trail/creek_builder.gd` | 4 | new: the water ribbon |
| `levels/trail/trail_level.gd` | 4 | builds the creek |
| `levels/trail/scatter_def.gd`, `scatter_builder.gd`, `low_poly_meshes.gd` | 5 | broadleaf trees; scenery clear of the creek |
| `tools/generate_muddy_valley_curve.gd`, `levels/muddy_valley/*` | 6 | new: the level |
| `levels/catalog.tres`, `levels/shared/run_level.gd` | 6 | Muddy Valley second; warning for a scene missing from the catalog |
| `tools/level_shots.gd`, `tools/level_shots.tscn`, `docs/notes/performance-m2b2.md` | 7 | screenshots and render counts; measured notes |

---

### Task 1: Surface stretches and ruts in the road profile

**Files:**
- Create: `levels/trail/surface_stretch.gd`
- Modify (replace whole file): `levels/trail/trail_def.gd`, `levels/trail/road_profile.gd`
- Test: `tests/unit/test_road_profile.gd` (append)

**Interfaces:**
- Consumes: `SurfaceDef` (`surfaces/surface_def.gd`, has `id: StringName`), `RoughShapes.rut(distance_from_centre, half_width, depth)`, `surfaces/dirt.tres`, `surfaces/mud.tres`, `surfaces/asphalt.tres`.
- Produces:
  - `SurfaceStretch` (Resource): `start: float`, `length: float`, `surface: SurfaceDef`, `color: Color`, `rut_depth: float`, `rut_spacing: float` (1.55), `rut_width: float` (0.8), `blend_length: float` (2.0); `end() -> float`, `contains(distance: float) -> bool`, `weight(distance: float) -> float`.
  - `TrailDef`: `base_surface: SurfaceDef` (default asphalt), `painted_lines: bool` (true), `surface_stretches: Array[SurfaceStretch]`, `creek_start`, `creek_length` (0 = none), `creek_offset` (17), `creek_width` (4), `creek_depth` (0.7), `creek_color`, `has_creek() -> bool`.
  - `RoadProfile`: `stretch_at(distance) -> SurfaceStretch` (null on the base surface), `surface_at(distance) -> SurfaceDef`, `surface_boundaries() -> PackedFloat32Array` (sorted stretch starts and ends inside the road), `rut_height(distance, lateral) -> float`; `height()` now includes ruts; detail ranges cover `blend_length` either side of each stretch end; tarmac patches are only made when the base surface is asphalt.

- [ ] **Step 1: Write the failing tests.** Append to the end of `tests/unit/test_road_profile.gd`:

```gdscript
func _muddy_def() -> TrailDef:
	var muddy := TrailDef.new()
	muddy.undulation_amplitude = 0.0
	muddy.base_surface = preload("res://surfaces/dirt.tres")
	var stretch := SurfaceStretch.new()
	stretch.start = 200.0
	stretch.length = 100.0
	stretch.surface = preload("res://surfaces/mud.tres")
	stretch.rut_depth = 0.08
	muddy.surface_stretches = [stretch]
	return muddy


func test_ruts_reach_their_depth_inside_a_stretch_only() -> void:
	var profile := RoadProfile.new(_muddy_def(), 1000.0)
	var half_spacing: float = profile.def.surface_stretches[0].rut_spacing * 0.5
	assert_almost_eq(profile.rut_height(250.0, half_spacing), -0.08, 0.0001, "right rut mid-stretch")
	assert_almost_eq(profile.rut_height(250.0, -half_spacing), -0.08, 0.0001, "left rut mid-stretch")
	assert_almost_eq(profile.rut_height(250.0, 0.0), 0.0, 0.0001, "between the ruts")
	assert_almost_eq(profile.rut_height(150.0, half_spacing), 0.0, 0.0001, "before the stretch")
	assert_almost_eq(profile.rut_height(350.0, half_spacing), 0.0, 0.0001, "after it")
	assert_almost_eq(profile.height(250.0, half_spacing), -0.08, 0.0001, "the road height includes the ruts")


func test_ruts_fade_in_and_out_over_the_blend_length() -> void:
	var profile := RoadProfile.new(_muddy_def(), 1000.0)
	var half_spacing: float = profile.def.surface_stretches[0].rut_spacing * 0.5
	assert_almost_eq(profile.rut_height(200.0, half_spacing), 0.0, 0.0001, "at the start")
	assert_almost_eq(profile.rut_height(201.0, half_spacing), -0.04, 0.0001, "halfway into the blend")
	assert_almost_eq(profile.rut_height(202.0, half_spacing), -0.08, 0.0001, "full depth after 2 m")
	assert_almost_eq(profile.rut_height(299.0, half_spacing), -0.04, 0.0001, "fading out at the end")


func test_surface_follows_the_stretches() -> void:
	var profile := RoadProfile.new(_muddy_def(), 1000.0)
	assert_eq(profile.surface_at(199.9).id, &"dirt")
	assert_eq(profile.surface_at(200.0).id, &"mud")
	assert_eq(profile.surface_at(299.9).id, &"mud")
	assert_eq(profile.surface_at(300.0).id, &"dirt", "a stretch's end is back on the base surface")
	assert_eq(profile.surface_boundaries(), PackedFloat32Array([200.0, 300.0]))
	assert_eq(profile.detail_ranges, [Vector2(198.0, 202.0), Vector2(298.0, 302.0)] as Array[Vector2])


func test_a_dirt_road_has_potholes_but_no_tarmac_patches() -> void:
	var muddy := _muddy_def()
	muddy.rough_sections = [Vector3(400.0, 120.0, 20.0)]
	var profile := RoadProfile.new(muddy, 1000.0)
	assert_eq(profile.potholes.size(), 24)
	assert_true(profile.patches.is_empty())
```

- [ ] **Step 2: Run them to see them fail.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_road_profile.gd -gexit`
  Expected: SCRIPT ERROR — `SurfaceStretch` is not a known type.

- [ ] **Step 3: Create `levels/trail/surface_stretch.gd`.**

`levels/trail/surface_stretch.gd`:

```gdscript
class_name SurfaceStretch
extends Resource
## A stretch of a trail's road with another surface than the trail's base, such
## as mud with two wheel ruts. Distances are metres along the road.

@export var start: float = 0.0
@export var length: float = 50.0
@export var surface: SurfaceDef
@export var color: Color = Color(0.27, 0.2, 0.14)
## Depth of the two wheel ruts (m); 0 = no ruts.
@export var rut_depth: float = 0.0
## Distance between the two ruts' centre lines, centred on the road (m).
@export var rut_spacing: float = 1.55
## Width of each rut (m).
@export var rut_width: float = 0.8
## The colour and the ruts fade in over this distance inside each end (m).
@export var blend_length: float = 2.0


func end() -> float:
	return start + length


func contains(distance: float) -> bool:
	return distance >= start and distance < end()


## How strongly the stretch shows at `distance`: 0 outside it, rising to 1 over
## blend_length inside each end.
func weight(distance: float) -> float:
	if not contains(distance):
		return 0.0
	var blend := maxf(blend_length, 0.001)
	return minf(smoothstep(start, start + blend, distance), 1.0 - smoothstep(end() - blend, end(), distance))
```

- [ ] **Step 4: Replace `levels/trail/trail_def.gd`** (the Surface and Creek groups are new; everything else is unchanged):

`levels/trail/trail_def.gd`:

```gdscript
class_name TrailDef
extends Resource
## Road settings for one trail. Distances are metres along the road; lateral
## positions are metres from the centre line (+ = right when driving forward).

@export_group("Cross-section")
@export var road_width: float = 7.0
@export var shoulder_width: float = 2.5
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

@export_group("Surface")
## The road's surface outside any stretch. Shoulders are always dirt.
@export var base_surface: SurfaceDef = preload("res://surfaces/asphalt.tres")
## Painted edge lines along the road.
@export var painted_lines: bool = true
## Stretches of another surface (such as mud with ruts). They must not overlap.
@export var surface_stretches: Array[SurfaceStretch] = []

@export_group("Undulation")
## Peak height of the gentle waves along the whole road.
@export var undulation_amplitude: float = 0.05
## The two summed wave lengths.
@export var undulation_wavelengths: Vector2 = Vector2(23.0, 37.0)

@export_group("Rough ground")
## Rough stretches as Vector3(start distance, length, potholes per 100 m).
@export var rough_sections: Array[Vector3] = []
## Short pothole clusters as Vector2(centre distance, pothole count).
@export var pothole_clusters: Array[Vector2] = []
@export var pothole_radius_range: Vector2 = Vector2(0.35, 0.65)
@export var pothole_depth_range: Vector2 = Vector2(0.06, 0.12)
## Potholes and patches keep this far from the ends of a rough stretch.
@export var rough_margin: float = 3.0

@export_group("Jumps")
## Jump crests shaped into the road, as Vector3(distance, height, length).
@export var jumps: Array[Vector3] = []

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

@export_group("Colours")
## The road's own colour: asphalt, or dirt on a dirt trail.
@export var asphalt_color: Color = Color(0.24, 0.23, 0.24)
@export var patch_color: Color = Color(0.3, 0.29, 0.28)
@export var line_color: Color = Color(0.92, 0.9, 0.84)
@export var shoulder_color: Color = Color(0.62, 0.47, 0.3)

## Seed for pothole and patch placement and undulation phases.
@export var seed: int = 1


## Half the width of road plus both shoulders.
func half_total_width() -> float:
	return road_width * 0.5 + shoulder_width


func has_creek() -> bool:
	return creek_length > 0.0
```

- [ ] **Step 5: Replace `levels/trail/road_profile.gd`:**

`levels/trail/road_profile.gd`:

```gdscript
class_name RoadProfile
extends RefCounted
## Surface height offsets along a trail: gentle undulation everywhere, potholes
## (and patched tarmac on asphalt) in rough ranges, jump crests, and wheel ruts
## in surface stretches. Built once from a TrailDef. All randomness comes from
## its seed, so the same settings always give the same road.

## Patched tarmac is raised this much above the surrounding asphalt (m).
const PATCH_RAISE := 0.012
## Pothole clusters spread over this distance either side of their centre (m).
const CLUSTER_SPREAD := 8.0
## Detailed cross-sections extend this far either side of a cluster's centre (m).
const CLUSTER_DETAIL := 10.0

var def: TrailDef
var road_length: float
## Potholes as Vector4(distance, lateral, radius, depth), sorted by distance.
var potholes: Array[Vector4] = []
## Patches as Rect2: position = (start distance, lateral from), size = (length, width).
var patches: Array[Rect2] = []
## Ranges needing detailed cross-sections, as Vector2(start, end), sorted and merged.
var detail_ranges: Array[Vector2] = []

var _pothole_distances := PackedFloat32Array()
var _max_pothole_radius := 0.0
var _phases := Vector2.ZERO


func _init(trail_def: TrailDef, length: float) -> void:
	def = trail_def
	road_length = length
	var rng := RandomNumberGenerator.new()
	rng.seed = def.seed
	_phases = Vector2(rng.randf() * TAU, rng.randf() * TAU)

	var patched := def.base_surface == null or def.base_surface.id == &"asphalt"
	var ranges: Array[Vector2] = []
	for section in def.rough_sections:
		var start := section.x
		var end := section.x + section.y
		for i in roundi(section.y / 100.0 * section.z):
			_add_random_pothole(rng, start + def.rough_margin, end - def.rough_margin)
		if patched:
			for i in int(section.y / 12.0):
				_add_random_patch(rng, start + def.rough_margin, end - def.rough_margin)
		ranges.append(Vector2(start, end))
	for cluster in def.pothole_clusters:
		for i in int(cluster.y):
			_add_random_pothole(rng, cluster.x - CLUSTER_SPREAD, cluster.x + CLUSTER_SPREAD)
		ranges.append(Vector2(cluster.x - CLUSTER_DETAIL, cluster.x + CLUSTER_DETAIL))
	for stretch in def.surface_stretches:
		for end: float in [stretch.start, stretch.end()]:
			ranges.append(Vector2(end - stretch.blend_length, end + stretch.blend_length))

	potholes.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.x < b.x)
	for pothole in potholes:
		_pothole_distances.append(pothole.x)
		_max_pothole_radius = maxf(_max_pothole_radius, pothole.z)
	detail_ranges = _merged(ranges)


## Total surface offset at a point of the road (m).
func height(distance: float, lateral: float) -> float:
	return undulation(distance) + jump_height(distance) + rough_height(distance, lateral) \
			+ rut_height(distance, lateral)


func undulation(distance: float) -> float:
	var waves := def.undulation_wavelengths
	return def.undulation_amplitude * 0.5 * (sin(TAU * distance / waves.x + _phases.x) \
			+ sin(TAU * distance / waves.y + _phases.y))


## A jump rises smoothly over the first 70% of its length, then drops away.
func jump_height(distance: float) -> float:
	var total := 0.0
	for jump in def.jumps:
		var t := (distance - (jump.x - jump.z * 0.5)) / jump.z
		if t <= 0.0 or t >= 1.0:
			continue
		if t < 0.7:
			total += jump.y * smoothstep(0.0, 0.7, t)
		else:
			total += jump.y * (1.0 - smoothstep(0.7, 1.0, t))
	return total


func rough_height(distance: float, lateral: float) -> float:
	var total := pothole_height(distance, lateral)
	if is_patch(distance, lateral):
		total += PATCH_RAISE
	return total


func pothole_height(distance: float, lateral: float) -> float:
	var total := 0.0
	var i := _pothole_distances.bsearch(distance - _max_pothole_radius)
	while i < potholes.size() and potholes[i].x <= distance + _max_pothole_radius:
		var pothole := potholes[i]
		var from_centre := Vector2(distance - pothole.x, lateral - pothole.y).length()
		total += RoughShapes.pothole(from_centre, pothole.z, pothole.w)
		i += 1
	return total


func is_patch(distance: float, lateral: float) -> bool:
	for patch in patches:
		if patch.has_point(Vector2(distance, lateral)):
			return true
	return false


func in_detail_range(distance: float) -> bool:
	for range in detail_ranges:
		if distance >= range.x and distance <= range.y:
			return true
	return false


## The surface stretch covering `distance`, or null where the road has its base surface.
func stretch_at(distance: float) -> SurfaceStretch:
	for stretch in def.surface_stretches:
		if stretch.contains(distance):
			return stretch
	return null


## The road's surface at `distance`: a stretch's surface, or the trail's base surface.
func surface_at(distance: float) -> SurfaceDef:
	var stretch := stretch_at(distance)
	return stretch.surface if stretch != null else def.base_surface


## Every stretch start and end on the road, sorted.
func surface_boundaries() -> PackedFloat32Array:
	var boundaries := PackedFloat32Array()
	for stretch in def.surface_stretches:
		for end: float in [stretch.start, stretch.end()]:
			if end > 0.0 and end < road_length:
				boundaries.append(end)
	boundaries.sort()
	return boundaries


## The two wheel ruts of a stretch, fading in and out with the stretch.
func rut_height(distance: float, lateral: float) -> float:
	var stretch := stretch_at(distance)
	if stretch == null or stretch.rut_depth <= 0.0:
		return 0.0
	var depth := stretch.rut_depth * stretch.weight(distance)
	var half_spacing := stretch.rut_spacing * 0.5
	var half_width := stretch.rut_width * 0.5
	return RoughShapes.rut(lateral + half_spacing, half_width, depth) \
			+ RoughShapes.rut(lateral - half_spacing, half_width, depth)


func _add_random_pothole(rng: RandomNumberGenerator, from: float, to: float) -> void:
	var radius := rng.randf_range(def.pothole_radius_range.x, def.pothole_radius_range.y)
	var depth := rng.randf_range(def.pothole_depth_range.x, def.pothole_depth_range.y)
	var lateral_limit := def.road_width * 0.5 - radius
	potholes.append(Vector4(rng.randf_range(from, to), rng.randf_range(-lateral_limit, lateral_limit), radius, depth))


func _add_random_patch(rng: RandomNumberGenerator, from: float, to: float) -> void:
	var length := rng.randf_range(2.0, 5.0)
	var start := rng.randf_range(from, maxf(from, to - length))
	var lateral_from := -def.road_width * 0.5 if rng.randf() < 0.5 else 0.0
	patches.append(Rect2(start, lateral_from, length, def.road_width * 0.5))


static func _merged(ranges: Array[Vector2]) -> Array[Vector2]:
	var sorted := ranges.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var result: Array[Vector2] = []
	for range in sorted:
		if not result.is_empty() and range.x <= result[-1].y:
			result[-1] = Vector2(result[-1].x, maxf(result[-1].y, range.y))
		else:
			result.append(range)
	return result
```

- [ ] **Step 6: Import, then run the profile tests and the unit suite.**
  Run: `godot --headless --import`, then `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_road_profile.gd -gexit`
  Expected: all tests in the file pass, including the 4 new ones.
  Run: `./run_tests.sh unit`
  Expected: exit 0. RoadBuilder still uses `Part.ASPHALT` and the old collision code at this point; both keep working.

- [ ] **Step 7: Commit.**
  ```bash
  git add levels/trail/surface_stretch.gd levels/trail/surface_stretch.gd.uid levels/trail/trail_def.gd levels/trail/road_profile.gd tests/unit/test_road_profile.gd
  git commit -m "Add surface stretches and wheel ruts to the road profile"
  ```
  (with the trailer from Global Constraints)

---

### Task 2: Road builder by surface

**Files:**
- Create: `tests/unit/test_rally_road_regression.gd`
- Modify (replace whole file): `levels/trail/road_builder.gd`
- Test: `tests/unit/test_road_builder.gd` (append)

**Interfaces:**
- Consumes (Task 1): `TrailDef.base_surface`, `painted_lines`, `surface_stretches`; `RoadProfile.stretch_at`, `surface_at`, `surface_boundaries`, `rut_height`; `SurfaceStretch.weight`, `rut_spacing`, `rut_width`, `rut_depth`.
- Produces: `RoadBuilder.Part { SHOULDER, ROAD, LINE }` (renamed from `ASPHALT`); `RoadBuilder.cross_section(def) -> Array[Vector2]` (no line stations when `painted_lines` is false; five stations across each rut); `RoadBuilder.row_distances(length, profile, def)` (includes every stretch boundary exactly); each road chunk adds one `StaticBody3D` per surface it covers (base first, then stretch surfaces in order of first appearance, skipping empty ones), then the dirt shoulder body.

- [ ] **Step 1: Write the regression test first, on the current builder.** Create `tests/unit/test_rally_road_regression.gd`:

```gdscript
extends GutTest
## Rally Road's road must come out of the surface-stretch builder exactly as it did
## before Muddy Valley: the values below were recorded from master at b349da9.

const CHUNK_VERTICES := [2727, 2727, 4347, 2727, 2727, 2727, 4266, 10827, 5238, 2727, 4347, 2727, 2727, 2727, 2727, 432]
## Collision faces per chunk as [asphalt road, dirt shoulders].
const CHUNK_FACES := [
	[10800, 1200], [10800, 1200], [17280, 1920], [10800, 1200], [10800, 1200], [10800, 1200], [16956, 1884],
	[43200, 4800], [20844, 2316], [10800, 1200], [17280, 1920], [10800, 1200], [10800, 1200], [10800, 1200],
	[10800, 1200], [1620, 180],
]


func _rally_road_trail() -> TrailLevel:
	var root: Node = load("res://levels/rally_road/rally_road.tscn").instantiate()
	var trail: TrailLevel = root.get_node("Trail")
	root.remove_child(trail)
	root.free()
	add_child_autofree(trail)  # builds in _ready
	return trail


func test_rally_road_is_built_as_before() -> void:
	var trail := _rally_road_trail()
	var vertices := []
	var faces := []
	for child in trail.road_builder.get_children():
		if child is MeshInstance3D:
			vertices.append(child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
		elif child is StaticBody3D:
			var shape: ConcavePolygonShape3D = child.get_child(0).shape
			faces.append([child.get_meta(SurfaceLookup.META_KEY).id, shape.get_faces().size()])
	assert_eq(vertices, CHUNK_VERTICES)
	for chunk in CHUNK_FACES.size():
		assert_eq(faces[chunk * 2], [&"asphalt", CHUNK_FACES[chunk][0]], "chunk %d road" % chunk)
		assert_eq(faces[chunk * 2 + 1], [&"dirt", CHUNK_FACES[chunk][1]], "chunk %d shoulders" % chunk)
	assert_eq(trail.profile.potholes.size(), 36)
	assert_eq(trail.profile.patches.size(), 12)
```

- [ ] **Step 2: Run it — it must pass before any builder change.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_rally_road_regression.gd -gexit`
  Expected: PASS. If it fails, stop and report (status BLOCKED): the recorded values no longer describe master and must not be edited.

- [ ] **Step 3: Write the failing builder tests.** Append to the end of `tests/unit/test_road_builder.gd`:

```gdscript
func _muddy_def() -> TrailDef:
	var muddy := TrailDef.new()
	muddy.undulation_amplitude = 0.0
	muddy.road_width = 9.0
	muddy.base_surface = preload("res://surfaces/dirt.tres")
	muddy.painted_lines = false
	var stretch := SurfaceStretch.new()
	stretch.start = 120.0
	stretch.length = 50.0
	stretch.surface = preload("res://surfaces/mud.tres")
	stretch.rut_depth = 0.08
	muddy.surface_stretches = [stretch]
	return muddy


func test_a_road_without_painted_lines_has_no_line_stations() -> void:
	var stations := RoadBuilder.cross_section(_muddy_def())
	assert_false(stations.any(func(s: Vector2) -> bool: return int(s.y) == RoadBuilder.Part.LINE))
	assert_almost_eq(stations[0].x, -7.0, 0.0001, "9 m road plus 2.5 m shoulders")
	assert_almost_eq(stations[-1].x, 7.0, 0.0001)
	for i in stations.size():
		assert_almost_eq(stations[i].x, -stations[-1 - i].x, 0.0001, "station %d mirrors" % i)


func test_ruts_get_their_own_cross_section_stations() -> void:
	var laterals := RoadBuilder.cross_section(_muddy_def()).map(func(s: Vector2) -> float: return s.x)
	for rut_station: float in [0.375, 0.575, 0.775, 0.975, 1.175]:
		for side: float in [-1.0, 1.0]:
			assert_true(laterals.any(func(x: float) -> bool: return absf(x - rut_station * side) < 0.0001),
					"station at %.3f m" % (rut_station * side))


func test_rows_land_exactly_on_stretch_ends() -> void:
	var muddy := _muddy_def()
	var distances := RoadBuilder.row_distances(sampler.length, RoadProfile.new(muddy, sampler.length), muddy)
	assert_true(distances.has(120.0))
	assert_true(distances.has(170.0))


func test_collision_follows_the_surface_stretch() -> void:
	var muddy := _muddy_def()
	builder.build(sampler, RoadProfile.new(muddy, sampler.length), muddy)
	var bodies := _children_of("StaticBody3D")
	assert_eq(bodies.size(), 7, "two bodies per chunk, plus mud in the middle chunk")
	assert_eq(bodies.filter(func(b: Node) -> bool: return b.get_meta(SurfaceLookup.META_KEY).id == &"mud").size(), 1)
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	for check in [[1.0, -100.0, &"dirt"], [1.0, -145.0, &"mud"], [1.0, -190.0, &"dirt"], [5.5, -145.0, &"dirt"]]:
		var from := Vector3(check[0], 5.0, check[1])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 10.0))
		assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, check[2], "at x %.1f, z %.0f" % [check[0], check[1]])
```

- [ ] **Step 4: Run them to see them fail.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_road_builder.gd -gexit`
  Expected: the line-station test fails (lines are still drawn), the rut-station and exact-row tests fail, and the collision test finds 6 bodies and no mud.

- [ ] **Step 5: Replace `levels/trail/road_builder.gd`:**

`levels/trail/road_builder.gd`:

```gdscript
class_name RoadBuilder
extends Node3D
## Builds the road surface along a trail in chunks: a mesh with optional painted
## edge lines, shaded potholes and ruts, and collision tagged with each stretch's
## surface (the trail's base surface elsewhere, dirt under the shoulders).

const DIRT := preload("res://surfaces/dirt.tres")

## Potholes and ruts are shaded darker by this much per metre of depth.
const SHADE_PER_METRE := 4.0
## Which part of the cross-section a station belongs to.
enum Part { SHOULDER, ROAD, LINE }
## Grid stations closer than this to a rut station are dropped (m).
const MIN_STATION_GAP := 0.05


func build(sampler: RoadSampler, profile: RoadProfile, def: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var stations := cross_section(def)
	var distances := row_distances(sampler.length, profile, def)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9

	var chunk_start := 0
	while chunk_start < distances.size() - 1:
		var chunk_end := chunk_start
		var limit := distances[chunk_start] + def.chunk_length
		while chunk_end < distances.size() - 1 and distances[chunk_end + 1] <= limit + 0.001:
			chunk_end += 1
		if chunk_end == chunk_start:
			chunk_end += 1
		_add_chunk(sampler, profile, def, stations, distances.slice(chunk_start, chunk_end + 1), material)
		chunk_start = chunk_end


## Cross-section stations from left to right as Vector2(lateral offset, part).
## Boundaries between parts appear twice (one station per part) so colours
## change sharply instead of fading.
static func cross_section(def: TrailDef) -> Array[Vector2]:
	var half_road := def.road_width * 0.5
	var outer := half_road + def.shoulder_width
	var stations: Array[Vector2] = [Vector2(-outer, Part.SHOULDER), Vector2(-half_road, Part.SHOULDER)]
	if def.painted_lines:
		var line_outer := half_road - def.line_inset
		var line_inner := line_outer - def.line_width
		stations.append_array([
			Vector2(-half_road, Part.ROAD), Vector2(-line_outer, Part.ROAD),
			Vector2(-line_outer, Part.LINE), Vector2(-line_inner, Part.LINE),
			Vector2(-line_inner, Part.ROAD),
		])
		for lateral in _interior_laterals(def, line_inner):
			stations.append(Vector2(lateral, Part.ROAD))
		stations.append_array([
			Vector2(line_inner, Part.ROAD), Vector2(line_inner, Part.LINE),
			Vector2(line_outer, Part.LINE), Vector2(line_outer, Part.ROAD),
			Vector2(half_road, Part.ROAD),
		])
	else:
		stations.append(Vector2(-half_road, Part.ROAD))
		for lateral in _interior_laterals(def, half_road):
			stations.append(Vector2(lateral, Part.ROAD))
		stations.append(Vector2(half_road, Part.ROAD))
	stations.append_array([Vector2(half_road, Part.SHOULDER), Vector2(outer, Part.SHOULDER)])
	return stations


## Distances of the cross-section rows: every sample_step, every detail_step
## inside rough ranges, and exactly at each surface stretch's ends. Always
## includes 0 and the road's end.
static func row_distances(length: float, profile: RoadProfile, def: TrailDef) -> PackedFloat32Array:
	var boundaries := profile.surface_boundaries()
	var next_boundary := 0
	var distances := PackedFloat32Array()
	var distance := 0.0
	while distance < length - 0.001:
		distances.append(distance)
		var next := distance + (def.detail_step if profile.in_detail_range(distance) else def.sample_step)
		while next_boundary < boundaries.size() and boundaries[next_boundary] <= distance + 0.001:
			next_boundary += 1
		if next_boundary < boundaries.size() and boundaries[next_boundary] < next - 0.001:
			next = boundaries[next_boundary]
		distance = next
	distances.append(length)
	return distances


## Road stations strictly between -limit and limit: a lateral_step grid, plus
## five stations across each wheel rut of any stretch.
static func _interior_laterals(def: TrailDef, limit: float) -> Array[float]:
	var laterals: Array[float] = []
	var lateral := -floorf(limit / def.lateral_step) * def.lateral_step
	if lateral <= -limit:
		lateral += def.lateral_step
	while lateral < limit - 0.001:
		laterals.append(lateral)
		lateral += def.lateral_step
	var ruts: Array[float] = []
	for stretch in def.surface_stretches:
		if stretch.rut_depth <= 0.0:
			continue
		var half_width := stretch.rut_width * 0.5
		for centre: float in [-stretch.rut_spacing * 0.5, stretch.rut_spacing * 0.5]:
			for offset: float in [-half_width, -half_width * 0.5, 0.0, half_width * 0.5, half_width]:
				if absf(centre + offset) < limit - MIN_STATION_GAP:
					ruts.append(centre + offset)
	if ruts.is_empty():
		return laterals
	var merged: Array[float] = ruts.duplicate()
	for grid in laterals:
		if not ruts.any(func(rut: float) -> bool: return absf(rut - grid) < MIN_STATION_GAP):
			merged.append(grid)
	merged.sort()
	return merged


func _add_chunk(sampler: RoadSampler, profile: RoadProfile, def: TrailDef, stations: Array[Vector2],
		distances: PackedFloat32Array, material: StandardMaterial3D) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for distance in distances:
		var centre := sampler.position(distance)
		var across := sampler.right(distance)
		var surface_up := sampler.up(distance)
		for station in stations:
			var lateral := station.x
			vertices.append(centre + across * lateral + surface_up * profile.height(distance, lateral))
			normals.append(surface_up)
			colors.append(_color(profile, def, distance, lateral, int(station.y)))

	var width := stations.size()
	var indices := PackedInt32Array()
	var row_surfaces: Array[SurfaceDef] = []
	var surfaces: Array[SurfaceDef] = [def.base_surface]
	for row in distances.size() - 1:
		var surface := profile.surface_at((distances[row] + distances[row + 1]) * 0.5)
		row_surfaces.append(surface)
		if not surfaces.has(surface):
			surfaces.append(surface)
		for column in width - 1:
			if is_equal_approx(stations[column].x, stations[column + 1].x):
				continue  # zero-width boundary between parts
			var i := row * width + column
			indices.append_array([i, i + width, i + 1, i + 1, i + width, i + width + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)

	for surface in surfaces:
		var faces := _faces(vertices, stations, row_surfaces, surface)
		if not faces.is_empty():
			add_child(_collision_body(faces, surface))
	add_child(_collision_body(_faces(vertices, stations, row_surfaces, null), DIRT))


## Collision faces of the road quads in rows whose surface is `surface`, or of
## every shoulder quad when `surface` is null.
static func _faces(vertices: PackedVector3Array, stations: Array[Vector2], row_surfaces: Array[SurfaceDef],
		surface: SurfaceDef) -> PackedVector3Array:
	var width := stations.size()
	var faces := PackedVector3Array()
	for row in row_surfaces.size():
		if surface != null and row_surfaces[row] != surface:
			continue
		for column in width - 1:
			var left := stations[column]
			if is_equal_approx(left.x, stations[column + 1].x):
				continue
			if (int(left.y) == Part.SHOULDER) != (surface == null):
				continue
			var i := row * width + column
			for corner in [i, i + width, i + 1, i + 1, i + width, i + width + 1]:
				faces.append(vertices[corner])
	return faces


func _color(profile: RoadProfile, def: TrailDef, distance: float, lateral: float, part: int) -> Color:
	match part:
		Part.SHOULDER:
			return def.shoulder_color
		Part.LINE:
			return def.line_color
	var base := def.patch_color if profile.is_patch(distance, lateral) else def.asphalt_color
	var stretch := profile.stretch_at(distance)
	if stretch != null:
		base = base.lerp(stretch.color, stretch.weight(distance))
	var dip := profile.pothole_height(distance, lateral) + profile.rut_height(distance, lateral)
	var shade := clampf(1.0 + dip * SHADE_PER_METRE, 0.5, 1.0)
	return Color(base.r * shade, base.g * shade, base.b * shade)


static func _collision_body(faces: PackedVector3Array, surface: SurfaceDef) -> StaticBody3D:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.set_meta(SurfaceLookup.META_KEY, surface)
	body.add_child(collision)
	return body
```

- [ ] **Step 6: Run the builder tests, the regression test and the unit suite.**
  Run the two `-gtest` commands above.
  Expected: every test passes, and the regression test still passes unchanged.
  Run: `grep -rn "Part.ASPHALT" levels tests tools game ui` — expected: no matches.
  Run: `./run_tests.sh unit` — expected: exit 0.

- [ ] **Step 7: Commit.**
  ```bash
  git add levels/trail/road_builder.gd tests/unit/test_road_builder.gd tests/unit/test_rally_road_regression.gd tests/unit/test_rally_road_regression.gd.uid
  git commit -m "Build road collision and colour by surface stretch"
  ```

---

### Task 3: Shared curve generator and road past the finish

**Files:**
- Create: `tools/curve_generator.gd`, `tests/unit/test_curve_generator.gd`, `tests/scenarios/trail_scenarios.gd`
- Modify (replace whole file): `tools/generate_rally_road_curve.gd`, `tests/unit/test_rally_road_regression.gd`
- Modify: `levels/rally_road/rally_road_trail.tres` (add `end_margin = 70.0`), `levels/rally_road/rally_road_curve.tres` (regenerated, never hand-edited)
- Test: `tests/scenarios/test_rally_road.gd` (append)

**Interfaces:**
- Consumes: `RunLevel` (`rig`, `trail`, `run.clock.stage`), `DrivingRig.place_car(transform)`, `TrailDriver.new(car, sampler).drive()`, `ScenarioHelper.ticks(seconds) -> int`, `CheckpointPlacer.RESET_HEIGHT`, `RoadSampler.transform_at(distance, height_above, profile)`, `closest_distance(point)`, `lateral_offset(point)`.
- Produces:
  - `CurveGenerator` (`class_name`, RefCounted): `generate(segments: Array, output: String, level_name: String) -> int` (OK or an error code, for `SceneTree.quit`); `build_curve(segments: Array) -> Curve3D`; `separation_problems(curve: Curve3D) -> Array`; constants `MIN_SEPARATION := 28.0`, `SEPARATION_CHECK_GAP := 80.0`.
  - Each `tools/generate_*_curve.gd` has `const OUTPUT` and `const SEGMENTS` and calls `quit(CurveGenerator.generate(SEGMENTS, OUTPUT, "<Level name>"))`.
  - `TrailScenarios` (`class_name`, static, each awaited): `wait_for_go(level)`, `place_on_road(level, distance)`, `place(level, transform)`, `full_throttle_until(level, seconds, done: Callable) -> float`, `brake_to_stop(level)`.

- [ ] **Step 1: Create `tools/curve_generator.gd`** (the building and checking code moves here unchanged from the Rally Road tool):

`tools/curve_generator.gd`:

```gdscript
class_name CurveGenerator
extends RefCounted
## Builds a trail's centre-line curve from a list of segments, checks that parts
## of the road far apart along it don't pass too close in space, and saves it.
## Each level's tools/generate_*_curve.gd holds only its segment list.
## Each segment is [kind, ...]:
##   ["straight", length_m, grade]
##   ["arc", radius_m, turn_deg (+ = left), grade]
## Grade is rise over run (0.12 = 12% up, -0.08 = 8% down). Arcs are split into
## 30-degree Bezier pieces so hairpins stay round.

## Parts of the road further apart than this along it must stay this far apart in space (m).
const MIN_SEPARATION := 28.0
const SEPARATION_CHECK_GAP := 80.0


## Builds, checks and saves a curve; returns OK or an error code for SceneTree.quit.
static func generate(segments: Array, output: String, level_name: String) -> int:
	var curve := build_curve(segments)
	var problems := separation_problems(curve)
	if not problems.is_empty():
		push_error("%s parts pass too close: %s" % [level_name, problems.slice(0, 5)])
		return FAILED
	var error := ResourceSaver.save(curve, output)
	var ends := [curve.get_point_position(0).y, curve.get_point_position(curve.point_count - 1).y]
	var heights := Array(curve.get_baked_points()).map(func(p: Vector3) -> float: return p.y)
	print("saved %s: %d points, %.0f m long, ends %+.0f m, lowest %+.0f m, highest %+.0f m" % [output,
			curve.point_count, curve.get_baked_length(), ends[1] - ends[0], heights.min(), heights.max()])
	return error


static func build_curve(segments: Array) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	var position := Vector3.ZERO
	var heading := 0.0  # radians; 0 = -Z, positive turns left
	curve.add_point(position)
	for segment in segments:
		if segment[0] == "straight":
			var direction := _direction(heading)
			var length: float = segment[1]
			var end := position + direction * length + Vector3(0.0, length * segment[2], 0.0)
			_set_out_handle(curve, (end - position) / 3.0)
			curve.add_point(end, -(end - position) / 3.0)
			position = end
		else:
			var radius: float = segment[1]
			var turn := deg_to_rad(segment[2])
			var grade: float = segment[3]
			var pieces := maxi(1, ceili(absf(turn) / deg_to_rad(30.0)))
			var piece_turn := turn / pieces
			var handle_length := 4.0 / 3.0 * tan(absf(piece_turn) / 4.0) * radius
			for i in pieces:
				var start_direction := _direction(heading)
				var arc_length := absf(piece_turn) * radius
				var chord_centre := position + _left(heading) * radius * signf(piece_turn)
				var end_heading := heading + piece_turn
				var flat_end := chord_centre - _left(end_heading) * radius * signf(piece_turn)
				var end := Vector3(flat_end.x, position.y + arc_length * grade, flat_end.z)
				var rise := arc_length * grade / 3.0
				_set_out_handle(curve, start_direction * handle_length + Vector3(0.0, rise, 0.0))
				curve.add_point(end, -_direction(end_heading) * handle_length - Vector3(0.0, rise, 0.0))
				position = end
				heading = end_heading
	return curve


## Pairs of road points far apart along the road but close in space.
static func separation_problems(curve: Curve3D) -> Array:
	var points := curve.get_baked_points()
	var problems := []
	var step := 5
	for i in range(0, points.size(), step):
		for j in range(i + int(SEPARATION_CHECK_GAP), points.size(), step):
			var flat := Vector2(points[i].x - points[j].x, points[i].z - points[j].z).length()
			if flat < MIN_SEPARATION:
				problems.append("%d m and %d m are %.1f m apart" % [i, j, flat])
	return problems


static func _direction(heading: float) -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


static func _left(heading: float) -> Vector3:
	return Vector3(-cos(heading), 0.0, sin(heading))


static func _set_out_handle(curve: Curve3D, handle: Vector3) -> void:
	curve.set_point_out(curve.point_count - 1, handle)
```

- [ ] **Step 2: Replace `tools/generate_rally_road_curve.gd`** (the segment list is unchanged apart from the last line, the run-off):

`tools/generate_rally_road_curve.gd`:

```gdscript
extends SceneTree
## Builds Rally Road's centre-line curve from a list of segments and saves it as
## levels/rally_road/rally_road_curve.tres. Re-run after changing SEGMENTS:
##   godot --headless -s tools/generate_rally_road_curve.gd
## Segment format: see CurveGenerator.

const OUTPUT := "res://levels/rally_road/rally_road_curve.tres"

const SEGMENTS := [
	["straight", 80.0, 0.01],     # start straight in the valley
	["arc", 120.0, 35.0, 0.04],
	["straight", 60.0, 0.04],
	["arc", 150.0, -45.0, 0.04],
	["straight", 130.0, 0.04],    # jump 1 at ~440 m, pothole cluster at ~250 m
	["arc", 100.0, 40.0, 0.04],
	["straight", 70.0, 0.04],     # checkpoint at 600 m
	["straight", 90.0, 0.03],     # rough stretch 680-830 m begins
	["arc", 200.0, -20.0, 0.03],
	["straight", 80.0, 0.03],
	["arc", 45.0, 50.0, 0.08],    # esses
	["arc", 45.0, -60.0, 0.08],
	["straight", 30.0, 0.08],
	["arc", 15.0, 180.0, 0.06],   # hairpin 1
	["straight", 80.0, 0.12],     # pothole cluster at ~1050 m
	["arc", 15.0, -180.0, 0.06],  # hairpin 2
	["straight", 80.0, 0.12],     # checkpoint at 1200 m
	["arc", 15.0, 180.0, 0.06],   # hairpin 3
	["straight", 60.0, 0.08],
	["straight", 120.0, 0.02],    # ridge straight, jump 2 at ~1380 m
	["arc", 200.0, -15.0, 0.02],
	["straight", 20.0, 0.0],      # finish overlooking the valley
	["straight", 60.0, 0.0],      # run-off past the finish
]


func _init() -> void:
	quit(CurveGenerator.generate(SEGMENTS, OUTPUT, "Rally Road"))
```

- [ ] **Step 3: Create `tests/unit/test_curve_generator.gd`:**

```gdscript
extends GutTest
## CurveGenerator's segments, and each level's saved curve matching its tool.

const LEVEL_CURVES := {
	"res://tools/generate_rally_road_curve.gd": "res://levels/rally_road/rally_road_curve.tres",
}


func test_a_straight_climbs_by_its_grade() -> void:
	var curve := CurveGenerator.build_curve([["straight", 100.0, -0.08]])
	assert_almost_eq(curve.get_point_position(1), Vector3(0.0, -8.0, -100.0), Vector3.ONE * 0.0001)


func test_a_left_hairpin_turns_the_road_around() -> void:
	var curve := CurveGenerator.build_curve([["straight", 50.0, 0.0], ["arc", 15.0, 180.0, 0.0]])
	assert_almost_eq(curve.get_point_position(curve.point_count - 1), Vector3(-30.0, 0.0, -50.0), Vector3.ONE * 0.001)


func test_parts_that_pass_too_close_are_reported() -> void:
	var curve := CurveGenerator.build_curve([["straight", 100.0, 0.0], ["arc", 5.0, 180.0, 0.0], ["straight", 100.0, 0.0]])
	assert_gt(CurveGenerator.separation_problems(curve).size(), 0)


func test_each_saved_level_curve_is_what_its_tool_builds() -> void:
	for tool_path: String in LEVEL_CURVES:
		var segments: Array = load(tool_path).get_script_constant_map()["SEGMENTS"]
		var built := CurveGenerator.build_curve(segments)
		var saved: Curve3D = load(LEVEL_CURVES[tool_path])
		assert_eq(saved.point_count, built.point_count, tool_path)
		for i in mini(saved.point_count, built.point_count):
			assert_almost_eq(saved.get_point_position(i), built.get_point_position(i), Vector3.ONE * 0.001,
					"%s point %d" % [tool_path, i])
		assert_eq(CurveGenerator.separation_problems(saved), [], "%s keeps its parts apart" % tool_path)
```

- [ ] **Step 4: Import and run it before regenerating the curve.**
  Run: `godot --headless --import`, then `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_curve_generator.gd -gexit`
  Expected: the three segment tests pass; `test_each_saved_level_curve_is_what_its_tool_builds` fails with the saved Rally Road curve having 43 points against 44 built.

- [ ] **Step 5: Regenerate Rally Road's curve and move its finish.**
  Run: `godot --headless -s tools/generate_rally_road_curve.gd`
  Expected output: `saved res://levels/rally_road/rally_road_curve.tres: 44 points, 1573 m long, ends +74 m, lowest +0 m, highest +74 m`
  Run: `git diff --stat levels/rally_road/rally_road_curve.tres` — expected: `point_count` 43 → 44; the earlier points are unchanged.
  In `levels/rally_road/rally_road_trail.tres`, add the line `end_margin = 70.0` directly above `checkpoint_distances = ...`.

- [ ] **Step 6: Replace `tests/unit/test_rally_road_regression.gd`** with the run-off version. The last chunk now covers the run-off, and the finish must not move:

`tests/unit/test_rally_road_regression.gd`:

```gdscript
extends GutTest
## Rally Road's road must come out of the surface-stretch builder exactly as it did
## before Muddy Valley: the values below were recorded from master at b349da9.
## Only the last chunk may differ, because the 60 m run-off past the finish extends it.

const CHUNK_VERTICES := [2727, 2727, 4347, 2727, 2727, 2727, 4266, 10827, 5238, 2727, 4347, 2727, 2727, 2727, 2727]
## Collision faces per chunk as [asphalt road, dirt shoulders].
const CHUNK_FACES := [
	[10800, 1200], [10800, 1200], [17280, 1920], [10800, 1200], [10800, 1200], [10800, 1200], [16956, 1884],
	[43200, 4800], [20844, 2316], [10800, 1200], [17280, 1920], [10800, 1200], [10800, 1200], [10800, 1200],
	[10800, 1200],
]


func _rally_road_trail() -> TrailLevel:
	var root: Node = load("res://levels/rally_road/rally_road.tscn").instantiate()
	var trail: TrailLevel = root.get_node("Trail")
	root.remove_child(trail)
	root.free()
	add_child_autofree(trail)  # builds in _ready
	return trail


func test_rally_road_is_built_as_before_up_to_the_old_road_end() -> void:
	var trail := _rally_road_trail()
	var vertices := []
	var faces := []
	for child in trail.road_builder.get_children():
		if child is MeshInstance3D:
			vertices.append(child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
		elif child is StaticBody3D:
			var shape: ConcavePolygonShape3D = child.get_child(0).shape
			faces.append([child.get_meta(SurfaceLookup.META_KEY).id, shape.get_faces().size()])
	assert_eq(vertices.size(), CHUNK_VERTICES.size() + 1, "one more chunk than recorded: the run-off")
	assert_eq(vertices.slice(0, CHUNK_VERTICES.size()), CHUNK_VERTICES)
	for chunk in CHUNK_FACES.size():
		assert_eq(faces[chunk * 2], [&"asphalt", CHUNK_FACES[chunk][0]], "chunk %d road" % chunk)
		assert_eq(faces[chunk * 2 + 1], [&"dirt", CHUNK_FACES[chunk][1]], "chunk %d shoulders" % chunk)
	assert_eq(trail.profile.potholes.size(), 36)
	assert_eq(trail.profile.patches.size(), 12)


func test_rally_road_gates_stay_put_with_road_past_the_finish() -> void:
	var trail := _rally_road_trail()
	var gates := trail.checkpoints.gate_distances
	assert_eq(Array(gates.slice(0, 5)), [10.0, 300.0, 600.0, 900.0, 1200.0])
	assert_almost_eq(gates[-1], 1503.38, 0.01, "the finish is where it was")
	assert_almost_eq(trail.sampler.length - gates[-1], 70.0, 0.01, "with 70 m of road after it")
```

- [ ] **Step 7: Create `tests/scenarios/trail_scenarios.gd`:**

`tests/scenarios/trail_scenarios.gd`:

```gdscript
class_name TrailScenarios
extends RefCounted
## Shared steps for scenario tests on real levels: wait out the countdown, put
## the car at rest somewhere, drive along the road at full throttle, and brake
## to a stop. Each step awaits physics ticks, so call them with await.


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Waits for the countdown to end, so the pedals work.
static func wait_for_go(level: RunLevel) -> void:
	while level.run.clock.stage != RunClock.Stage.RUNNING:
		await _tree().physics_frame


## Puts the car at rest on the road at `distance`, facing along it, and lets it settle.
static func place_on_road(level: RunLevel, distance: float) -> void:
	await place(level, level.trail.sampler.transform_at(distance, CheckpointPlacer.RESET_HEIGHT, level.trail.profile))


## Puts the car at rest at `transform` and lets it settle for half a second.
static func place(level: RunLevel, transform: Transform3D) -> void:
	level.rig.place_car(transform)
	for i in ScenarioHelper.ticks(0.5):
		level.rig.car.input.virtual_throttle = 0.0
		level.rig.car.input.virtual_brake = 1.0
		await _tree().physics_frame


## Steers along the road at full throttle until `done` returns true or `seconds`
## pass. Returns the seconds it took (or `seconds` if `done` never came true).
static func full_throttle_until(level: RunLevel, seconds: float, done: Callable) -> float:
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler)
	for tick in ScenarioHelper.ticks(seconds):
		if done.call():
			return tick / float(Engine.physics_ticks_per_second)
		driver.drive()
		car.input.virtual_throttle = 1.0
		car.input.virtual_brake = 0.0
		await _tree().physics_frame
	return seconds


## Brakes hard while steering along the road until the car stops (or 10 s pass).
static func brake_to_stop(level: RunLevel) -> void:
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler)
	for tick in ScenarioHelper.ticks(10.0):
		driver.drive()
		car.input.virtual_throttle = 0.0
		car.input.virtual_brake = 1.0
		await _tree().physics_frame
		if car.linear_velocity.length() < 0.3:
			return
```

- [ ] **Step 8: Append the run-off scenario to the end of `tests/scenarios/test_rally_road.gd`:**

```gdscript
func test_the_road_carries_on_past_the_finish() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var car := level.rig.car
	await TrailScenarios.wait_for_go(level)
	var finish := level.trail.checkpoints.gate_distances[-1]
	await TrailScenarios.place_on_road(level, finish - 150.0)
	await TrailScenarios.full_throttle_until(level, 30.0,
			func() -> bool: return sampler.closest_distance(car.global_position) >= finish)
	var speed := car.forward_speed()
	await TrailScenarios.brake_to_stop(level)
	var stopped_at := sampler.closest_distance(car.global_position)
	gut.p("crossed the finish at %.0f km/h and stopped %.0f m past it (road ends %.0f m past it)" % [
		speed * 3.6, stopped_at - finish, sampler.length - finish])
	assert_lt(stopped_at, sampler.length - 5.0, "stops on the run-off")
	assert_lt(absf(sampler.lateral_offset(car.global_position)), level.trail.trail.half_total_width())
```

- [ ] **Step 9: Import and run the tests.**
  Run: `godot --headless --import`
  Run the `-gtest` command for `res://tests/unit/test_curve_generator.gd` and for `res://tests/unit/test_rally_road_regression.gd` — expected: all pass.
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/scenarios/test_rally_road.gd -gexit`
  Expected: all pass; the run-off test prints `crossed the finish at 95 km/h and stopped 30 m past it (road ends 70 m past it)` or similar.
  Run: `./run_tests.sh all` — expected: exit 0.

- [ ] **Step 10: Commit.**
  ```bash
  git add tools/curve_generator.gd tools/curve_generator.gd.uid tools/generate_rally_road_curve.gd levels/rally_road/rally_road_curve.tres levels/rally_road/rally_road_trail.tres tests/unit/test_curve_generator.gd tests/unit/test_curve_generator.gd.uid tests/unit/test_rally_road_regression.gd tests/scenarios/trail_scenarios.gd tests/scenarios/trail_scenarios.gd.uid tests/scenarios/test_rally_road.gd
  git commit -m "Share the curve generator and give Rally Road road past the finish"
  ```

---

### Task 4: Creek channel and water

**Files:**
- Create: `levels/trail/creek_builder.gd`, `tests/unit/test_creek.gd`
- Modify (replace whole file): `levels/trail/terrain_field.gd`, `levels/trail/trail_level.gd`

**Interfaces:**
- Consumes (Task 1): `TrailDef.has_creek()`, `creek_start`, `creek_length`, `creek_offset`, `creek_width`, `creek_depth`, `creek_color`.
- Produces:
  - `TerrainField`: constants `CREEK_BANK := 3.0`, `CREEK_TAPER := 10.0`, `CREEK_SMOOTHING := 5.0`, `CREEK_BELOW_GROUND := 0.15`, `CREEK_LEVEE := 4.0`; `creek_distances: PackedFloat32Array` (`FAR` away from a creek); `static creek_point(sampler, trail, distance) -> Vector2` (world X/Z); `creek_distance_at(x, z) -> float`; `creek_water_level(distance) -> float` (`-INF` outside the creek).
  - `CreekBuilder` (Node3D): `build(field, sampler, trail)`; `water_points: PackedVector3Array`; a child `MeshInstance3D` named `Water` when any water is laid; `MIN_DEPTH := 0.1` (water at least this far above the channel floor), `STEP := 2.0`.
  - `TrailLevel.creek_builder: CreekBuilder`, built after the terrain as `Generated/Creek`.

- [ ] **Step 1: Write the failing tests.** Create `tests/unit/test_creek.gd`:

```gdscript
extends GutTest
## A creek beside a flat, noise-free straight road: the channel TerrainField cuts,
## the water CreekBuilder lays in it, and scenery keeping out of it.

var trail: TrailDef
var terrain: TerrainDef
var sampler: RoadSampler


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -300.0))
	sampler = RoadSampler.new(curve)
	trail = TrailDef.new()
	trail.creek_start = 50.0
	trail.creek_length = 200.0
	terrain = TerrainDef.new()
	terrain.margin = 60.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0


func _field() -> TerrainField:
	return TerrainField.generate(sampler, trail, terrain)


## The ground height `outward` metres further from the road than the creek's centre line.
func _height_beside(field: TerrainField, distance: float, outward: float) -> float:
	var centre := TerrainField.creek_point(sampler, trail, distance)
	var away := (centre - Vector2(sampler.position(distance).x, sampler.position(distance).z)).normalized()
	var spot := centre + away * outward
	return field.height_at(spot.x, spot.y)


func test_the_channel_floor_is_creek_depth_below_the_ground_beside_it() -> void:
	var field := _field()
	var floor := _height_beside(field, 150.0, 0.0)
	var beside := _height_beside(field, 150.0, 12.0)
	gut.p("floor %.2f m, ground beside %.2f m" % [floor, beside])
	assert_almost_eq(floor, beside - trail.creek_depth, 0.06)
	assert_almost_eq(_height_beside(field, 150.0, 1.0), floor, 0.02, "a flat floor across the creek's width")
	assert_between(_height_beside(field, 150.0, 3.5), floor + 0.05, beside - 0.05, "a sloping bank")


func test_the_channel_tapers_to_nothing_at_its_ends() -> void:
	var field := _field()
	var beside := _height_beside(field, 150.0, 12.0)
	assert_almost_eq(_height_beside(field, 30.0, 0.0), beside, 0.03, "before the creek")
	assert_almost_eq(_height_beside(field, 44.0, 0.0), beside, 0.03, "just beyond the reach of its first bank")
	assert_between(_height_beside(field, 55.0, 0.0), beside - trail.creek_depth + 0.05, beside - 0.05, "deepening")
	assert_almost_eq(_height_beside(field, 270.0, 0.0), beside, 0.03, "after its end")


func test_the_road_and_shoulders_are_not_cut() -> void:
	var with_creek := _field()
	trail.creek_length = 0.0
	var without := _field()
	var edge := trail.half_total_width()
	for lateral: float in [0.0, edge, edge + 2.0]:  # the creek's raised bank reaches 9 m from its centre, 17 m out
		var spot := sampler.position(150.0) + sampler.right(150.0) * lateral * signf(trail.creek_offset)
		assert_almost_eq(with_creek.height_at(spot.x, spot.z), without.height_at(spot.x, spot.z), 0.0001,
				"%.1f m from the centre line" % lateral)


func test_creek_distances_measure_from_the_centre_line() -> void:
	var field := _field()
	var centre := TerrainField.creek_point(sampler, trail, 150.0)
	assert_almost_eq(field.creek_distance_at(centre.x, centre.y), 0.0, 1.5)
	assert_eq(field.creek_distance_at(-200.0, -150.0), TerrainField.FAR, "far from the creek")
	trail.creek_length = 0.0
	assert_eq(_field().creek_distances.count(TerrainField.FAR), _field().creek_distances.size(), "no creek")


func test_water_lies_in_the_channel_below_both_rims() -> void:
	var field := _field()
	var builder := CreekBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, trail)
	assert_not_null(builder.get_node_or_null("Water"))
	assert_gt(builder.water_points.size(), 80, "water along most of 200 m at one point every 2 m")
	var across := sampler.right(150.0)
	var flat := Vector2(across.x, across.z).normalized()
	var half := trail.creek_width * 0.5 + TerrainField.CREEK_BANK
	for point in builder.water_points:
		var centre := Vector2(point.x, point.z)
		var lower_rim := minf(field.height_at(centre.x - flat.x * half, centre.y - flat.y * half),
				field.height_at(centre.x + flat.x * half, centre.y + flat.y * half))
		assert_gte(point.y, field.height_at(centre.x, centre.y) + CreekBuilder.MIN_DEPTH - 0.02, "above the floor")
		assert_lte(point.y, lower_rim - TerrainField.CREEK_BELOW_GROUND + 0.01, "below the lower rim (sampled between grid points)")


func test_no_creek_builds_no_water() -> void:
	trail.creek_length = 0.0
	var builder := CreekBuilder.new()
	add_child_autofree(builder)
	builder.build(_field(), sampler, trail)
	assert_eq(builder.get_child_count(), 0)
	assert_eq(builder.water_points.size(), 0)
```

- [ ] **Step 2: Run them to see them fail.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_creek.gd -gexit`
  Expected: SCRIPT ERROR — `creek_point` and `CreekBuilder` don't exist.

- [ ] **Step 3: Replace `levels/trail/terrain_field.gd`:**

`levels/trail/terrain_field.gd`:

```gdscript
class_name TerrainField
extends RefCounted
## The mountainside around a trail as a grid of height samples, generated once.
## The natural ground is a plane fitted to the road's overall climb plus noise.
## Near the road, the ground follows a smoothed road elevation and is carved to
## meet the shoulders (see Corridor). A creek, if the trail has one, is cut as a
## shallow channel beside the road.
## Grid rows run along +Z and columns along +X; index = row * columns + column.

## Sentinel edge distance for samples far from any road.
const FAR := 1.0e6
## A creek's banks rise from its floor to the ground over this width (m).
const CREEK_BANK := 3.0
## A creek's channel deepens from nothing over this distance at each end (m).
const CREEK_TAPER := 10.0
## A creek's bed is kept level with its lowest point within this distance either side (m).
const CREEK_SMOOTHING := 5.0
## The creek's water sits this far below the lowest ground across its channel (m).
const CREEK_BELOW_GROUND := 0.15
## Beyond a creek's banks, raised ground falls back to the natural ground over this width (m).
const CREEK_LEVEE := 4.0

var def: TerrainDef
## World X/Z of sample (column 0, row 0).
var origin := Vector2.ZERO
var spacing := 2.0
var columns := 0
var rows := 0
## Samples per chunk side minus one (chunks share their border samples).
var cells_per_chunk := 64
var heights := PackedFloat32Array()
## Metres outside the nearest shoulder edge (negative under the road).
var edge_distances := PackedFloat32Array()
## Metres from the creek's centre line; FAR away from any creek.
var creek_distances := PackedFloat32Array()
## The creek's water heights, one per metre along the road from creek_start.
var creek_start := 0.0
var creek_levels := PackedFloat32Array()
var lowest_height := 0.0


static func generate(sampler: RoadSampler, trail: TrailDef, terrain: TerrainDef) -> TerrainField:
	var field := TerrainField.new()
	field.def = terrain
	field.spacing = terrain.sample_spacing
	field.cells_per_chunk = maxi(1, roundi(terrain.chunk_size / terrain.sample_spacing))

	# Road stamps every metre: position, flat right direction, and banking slope.
	var stamps: Array[Vector3] = []
	var rights: Array[Vector2] = []
	var bank_slopes := PackedFloat32Array()
	var distance := 0.0
	while distance <= sampler.length:
		var point := sampler.position(distance)
		var across := sampler.right(distance)
		var flat := Vector2(across.x, across.z)
		stamps.append(point)
		rights.append(flat.normalized())
		bank_slopes.append(across.y / maxf(flat.length(), 0.0001))
		distance += 1.0

	field._size_grid(stamps, terrain.margin)
	field._fill_natural(stamps, terrain)
	field._carve(stamps, rights, bank_slopes, trail, terrain)
	field._cut_creek(sampler, trail)
	return field


## World X/Z of the creek's centre line beside the road at `distance`.
static func creek_point(sampler: RoadSampler, trail: TrailDef, distance: float) -> Vector2:
	var point := sampler.position(distance)
	var across := sampler.right(distance)
	return Vector2(point.x, point.z) + Vector2(across.x, across.z).normalized() * trail.creek_offset


func chunk_count() -> Vector2i:
	return Vector2i((columns - 1) / cells_per_chunk, (rows - 1) / cells_per_chunk)


func index(column: int, row: int) -> int:
	return clampi(row, 0, rows - 1) * columns + clampi(column, 0, columns - 1)


func sample_position(column: int, row: int) -> Vector3:
	return Vector3(origin.x + column * spacing, heights[index(column, row)], origin.y + row * spacing)


## Bilinear height at a world X/Z.
func height_at(x: float, z: float) -> float:
	var fx := clampf((x - origin.x) / spacing, 0.0, columns - 1.001)
	var fz := clampf((z - origin.y) / spacing, 0.0, rows - 1.001)
	var column := int(fx)
	var row := int(fz)
	var tx := fx - column
	var tz := fz - row
	var near := lerpf(heights[index(column, row)], heights[index(column + 1, row)], tx)
	var far := lerpf(heights[index(column, row + 1)], heights[index(column + 1, row + 1)], tx)
	return lerpf(near, far, tz)


## Edge distance at the nearest sample to a world X/Z.
func edge_distance_at(x: float, z: float) -> float:
	return edge_distances[index(roundi((x - origin.x) / spacing), roundi((z - origin.y) / spacing))]


## Distance from the creek's centre line at the nearest sample to a world X/Z.
func creek_distance_at(x: float, z: float) -> float:
	return creek_distances[index(roundi((x - origin.x) / spacing), roundi((z - origin.y) / spacing))]


## Surface normal at a sample, from its neighbours.
func normal_at_index(column: int, row: int) -> Vector3:
	var dx := heights[index(column - 1, row)] - heights[index(column + 1, row)]
	var dz := heights[index(column, row - 1)] - heights[index(column, row + 1)]
	return Vector3(dx, 2.0 * spacing, dz).normalized()


func normal_at(x: float, z: float) -> Vector3:
	return normal_at_index(roundi((x - origin.x) / spacing), roundi((z - origin.y) / spacing))


## Falling below this height counts as falling off the map.
func kill_height() -> float:
	return lowest_height - def.kill_depth


func _size_grid(stamps: Array[Vector3], margin: float) -> void:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for stamp in stamps:
		low = low.min(Vector2(stamp.x, stamp.z))
		high = high.max(Vector2(stamp.x, stamp.z))
	low -= Vector2(margin, margin)
	high += Vector2(margin, margin)
	var chunk_metres := cells_per_chunk * spacing
	var chunks := Vector2i(ceili((high.x - low.x) / chunk_metres), ceili((high.y - low.y) / chunk_metres))
	origin = Vector2(floorf(low.x / spacing) * spacing, floorf(low.y / spacing) * spacing)
	columns = chunks.x * cells_per_chunk + 1
	rows = chunks.y * cells_per_chunk + 1
	heights.resize(columns * rows)
	edge_distances.resize(columns * rows)
	creek_distances.resize(columns * rows)
	creek_distances.fill(FAR)


## Natural ground: a plane fitted to the road's elevations, plus fractal noise.
func _fill_natural(stamps: Array[Vector3], terrain: TerrainDef) -> void:
	var centre := Vector3.ZERO
	for stamp in stamps:
		centre += stamp
	centre /= stamps.size()
	var sxx := 0.0
	var sxz := 0.0
	var szz := 0.0
	var sxe := 0.0
	var sze := 0.0
	for stamp in stamps:
		var dx := stamp.x - centre.x
		var dz := stamp.z - centre.z
		var de := stamp.y - centre.y
		sxx += dx * dx
		sxz += dx * dz
		szz += dz * dz
		sxe += dx * de
		sze += dz * de
	# A little regularisation keeps a straight road (all points on one line) from
	# making the fit degenerate: the slope along it is kept, none is assumed across it.
	var ridge := (sxx + szz) * 0.001 + 0.000001
	sxx += ridge
	szz += ridge
	var determinant := sxx * szz - sxz * sxz
	var slope := Vector2.ZERO
	if absf(determinant) > 0.0001:
		slope = Vector2((sxe * szz - sze * sxz) / determinant, (sze * sxx - sxe * sxz) / determinant)

	var noise := FastNoiseLite.new()
	noise.seed = terrain.seed
	noise.frequency = 1.0 / terrain.noise_wavelength
	noise.fractal_octaves = terrain.noise_octaves
	for row in rows:
		var z := origin.y + row * spacing
		for column in columns:
			var x := origin.x + column * spacing
			var plane := centre.y + slope.x * (x - centre.x) + slope.y * (z - centre.z)
			heights[row * columns + column] = plane + noise.get_noise_2d(x, z) * terrain.noise_amplitude


## Near the road, blend the natural ground toward a smoothed road elevation.
func _carve(stamps: Array[Vector3], rights: Array[Vector2], bank_slopes: PackedFloat32Array,
		trail: TrailDef, terrain: TerrainDef) -> void:
	var cell_count := columns * rows
	var weight_sums := PackedFloat32Array()
	var height_sums := PackedFloat32Array()
	weight_sums.resize(cell_count)
	height_sums.resize(cell_count)
	edge_distances.fill(FAR)

	var half_width := trail.half_total_width()
	var radius := half_width + terrain.corridor_blend + 2.0
	var radius_squared := radius * radius
	var sigma_squared := terrain.smoothing_radius * terrain.smoothing_radius
	var reach := ceili(radius / spacing)
	for s in stamps.size():
		var stamp := stamps[s]
		var across := rights[s]
		var bank := bank_slopes[s]
		var centre_column := roundi((stamp.x - origin.x) / spacing)
		var centre_row := roundi((stamp.z - origin.y) / spacing)
		for row in range(maxi(0, centre_row - reach), mini(rows, centre_row + reach + 1)):
			var dz := origin.y + row * spacing - stamp.z
			for column in range(maxi(0, centre_column - reach), mini(columns, centre_column + reach + 1)):
				var dx := origin.x + column * spacing - stamp.x
				var squared := dx * dx + dz * dz
				if squared > radius_squared:
					continue
				var i := row * columns + column
				var weight := exp(-squared / sigma_squared)
				var lateral := dx * across.x + dz * across.y
				weight_sums[i] += weight
				height_sums[i] += weight * (stamp.y + lateral * bank)
				var edge := sqrt(squared) - half_width
				if edge < edge_distances[i]:
					edge_distances[i] = edge

	lowest_height = INF
	for i in cell_count:
		if weight_sums[i] > 0.000001 and edge_distances[i] < terrain.corridor_blend:
			var road_height := height_sums[i] / weight_sums[i]
			heights[i] = Corridor.carved_height(road_height, heights[i], edge_distances[i],
					terrain.corridor_blend, terrain.under_road_drop)
		lowest_height = minf(lowest_height, heights[i])


## Shapes the ground along the creek. Each nearby sample takes its shape from the
## nearest point on the creek's centre line:
## - across creek_width, a floor creek_depth below the higher of the centre-line
##   ground and its own ground, so the floor is level where the ground falls away
##   and follows the ground up a slope;
## - banks rising over CREEK_BANK to at least the centre-line ground, so a
##   downhill side gets a low raised bank that holds the water;
## - beyond the banks, raised ground falls back to the natural ground over CREEK_LEVEE.
## The ends taper to nothing. The water level is the lowest centre-line ground
## within CREEK_SMOOTHING either side, less CREEK_BELOW_GROUND, so it never steps
## up and never tops a bank.
func _cut_creek(sampler: RoadSampler, trail: TrailDef) -> void:
	if not trail.has_creek():
		return
	var half_width := trail.creek_width * 0.5
	var radius := half_width + CREEK_BANK
	var outer := radius + CREEK_LEVEE
	var start := trail.creek_start
	var end := minf(trail.creek_start + trail.creek_length, sampler.length)
	var steps := int(end - start) + 1
	var centres: Array[Vector2] = []
	var grounds := PackedFloat32Array()
	var tapers := PackedFloat32Array()
	for step in steps:
		var distance := start + step
		var centre := creek_point(sampler, trail, distance)
		centres.append(centre)
		grounds.append(height_at(centre.x, centre.y))
		tapers.append(minf(smoothstep(start, start + CREEK_TAPER, distance), 1.0 - smoothstep(end - CREEK_TAPER, end, distance)))
	creek_start = start
	creek_levels.resize(steps)
	for step in steps:
		var ground := grounds[step]
		for other in range(maxi(0, step - int(CREEK_SMOOTHING)), mini(steps, step + int(CREEK_SMOOTHING) + 1)):
			ground = minf(ground, grounds[other])
		creek_levels[step] = ground - CREEK_BELOW_GROUND

	var nearest := PackedInt32Array()
	nearest.resize(columns * rows)
	nearest.fill(-1)
	var touched := PackedInt32Array()
	var reach := ceili(outer / spacing) + 1
	for step in steps:
		var centre := centres[step]
		var centre_column := roundi((centre.x - origin.x) / spacing)
		var centre_row := roundi((centre.y - origin.y) / spacing)
		for row in range(maxi(0, centre_row - reach), mini(rows, centre_row + reach + 1)):
			for column in range(maxi(0, centre_column - reach), mini(columns, centre_column + reach + 1)):
				var i := row * columns + column
				var from_centre := Vector2(origin.x + column * spacing, origin.y + row * spacing).distance_to(centre)
				if from_centre < creek_distances[i]:
					if nearest[i] < 0:
						touched.append(i)
					creek_distances[i] = from_centre
					nearest[i] = step

	for i in touched:
		var from_centre := creek_distances[i]
		if from_centre >= outer:
			continue
		var step := nearest[i]
		var natural := heights[i]
		var depth := trail.creek_depth * tapers[step]
		var top := lerpf(natural, grounds[step], tapers[step])
		if from_centre < radius:
			var floor := maxf(grounds[step], natural) - depth
			heights[i] = lerpf(floor, maxf(natural, top), smoothstep(half_width, radius, from_centre))
		else:
			heights[i] = maxf(natural, lerpf(top, natural, smoothstep(radius, outer, from_centre)))
		lowest_height = minf(lowest_height, heights[i])


## The creek's water height at `distance` along the road, or -INF where there is no creek.
func creek_water_level(distance: float) -> float:
	var step := roundi(distance - creek_start)
	return creek_levels[step] if step >= 0 and step < creek_levels.size() else -INF
```

- [ ] **Step 4: Create `levels/trail/creek_builder.gd`:**

`levels/trail/creek_builder.gd`:

```gdscript
class_name CreekBuilder
extends Node3D
## Lays a creek's water in the channel TerrainField cuts beside the road: a flat,
## glossy ribbon at the field's water level. Visual only, with no collision; the
## channel floor underneath is ordinary ground.

## Where the water would be shallower than this (the tapered ends), none is laid (m).
const MIN_DEPTH := 0.1
## Distance between the ribbon's cross-sections (m).
const STEP := 2.0

## The water surface's centre point at each laid cross-section, for tests.
var water_points := PackedVector3Array()


func build(field: TerrainField, sampler: RoadSampler, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	water_points.clear()
	if not trail.has_creek():
		return
	var half_ribbon := trail.creek_width * 0.5 + TerrainField.CREEK_BANK
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var previous_laid := false
	var end := minf(trail.creek_start + trail.creek_length, sampler.length)
	var distance := trail.creek_start
	while distance <= end:
		var level := field.creek_water_level(distance)
		var centre := TerrainField.creek_point(sampler, trail, distance)
		var laid := level >= field.height_at(centre.x, centre.y) + MIN_DEPTH
		if laid:
			var across := sampler.right(distance)
			var flat := Vector2(across.x, across.z).normalized()
			if previous_laid:
				var i := vertices.size() - 2
				indices.append_array([i, i + 2, i + 1, i + 1, i + 2, i + 3])
			var left := centre - flat * half_ribbon
			var right := centre + flat * half_ribbon
			vertices.append(Vector3(left.x, level, left.y))
			vertices.append(Vector3(right.x, level, right.y))
			water_points.append(Vector3(centre.x, level, centre.y))
		previous_laid = laid
		distance += STEP
	if indices.is_empty():
		return

	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = trail.creek_color
	material.roughness = 0.15
	material.metallic_specular = 0.8
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = mesh
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
```

- [ ] **Step 5: Replace `levels/trail/trail_level.gd`** (the creek builder is new):

`levels/trail/trail_level.gd`:

```gdscript
@tool
class_name TrailLevel
extends Node3D
## Generates a whole trail from its "Road" Path3D child and its settings: road
## surface, terrain, creek, scenery and checkpoint gates. It builds on load in
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
```

- [ ] **Step 6: Import and run the tests.**
  Run: `godot --headless --import`, then the `-gtest` command for `res://tests/unit/test_creek.gd`.
  Expected: all 6 pass.
  Run: `./run_tests.sh unit` — expected: exit 0, and the Rally Road regression test still passes (a trail without a creek builds exactly as before).

- [ ] **Step 7: Commit.**
  ```bash
  git add levels/trail/terrain_field.gd levels/trail/creek_builder.gd levels/trail/creek_builder.gd.uid levels/trail/trail_level.gd tests/unit/test_creek.gd tests/unit/test_creek.gd.uid
  git commit -m "Cut a creek channel beside the road and fill it with water"
  ```

---

### Task 5: Broadleaf trees and scenery clear of the creek

**Files:**
- Modify (replace whole file): `levels/trail/scatter_def.gd`, `levels/trail/scatter_builder.gd`, `levels/trail/low_poly_meshes.gd`
- Test: `tests/unit/test_creek.gd` (append), `tests/unit/test_low_poly_meshes.gd` (append)

**Interfaces:**
- Consumes (Task 4): `TerrainField.creek_distance_at(x, z)`; `TrailDef.creek_width`.
- Produces:
  - `ScatterDef`: `broadleaf_spacing` (0 = none), `broadleaf_view_distance` (300), `broadleaf_color`.
  - `ScatterBuilder`: `broadleaf_count`; `CREEK_CLEARANCE := 2.0`. Nothing is placed within `creek_width / 2 + CREEK_CLEARANCE` of the creek's centre line. Broadleaf trees are scattered after posts, and only when `broadleaf_spacing > 0`, so Rally Road's pines, rocks and posts use the same random numbers as before.
  - `LowPolyMeshes.broadleaf(foliage: Color, trunk: Color, seed: int) -> ArrayMesh`: a 4-sided trunk and two leaf clumps, 48 triangles. Rocks now share `_add_lumpy_ball` with the tree clumps and draw the same random numbers in the same order, so rocks are unchanged.

- [ ] **Step 1: Write the failing tests.** Append to the end of `tests/unit/test_creek.gd`:

```gdscript
func test_scenery_keeps_out_of_the_creek() -> void:
	var field := _field()
	var scatter := ScatterDef.new()
	scatter.pine_spacing = 4.0
	scatter.rock_spacing = 4.0
	scatter.broadleaf_spacing = 4.0
	var builder := ScatterBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, RoadProfile.new(trail, sampler.length), trail, scatter)
	assert_gt(builder.broadleaf_count, 100)
	var clearance := trail.creek_width * 0.5 + ScatterBuilder.CREEK_CLEARANCE
	var checked := 0
	for child in builder.get_children():
		if child is MultiMeshInstance3D:
			for i in child.multimesh.instance_count:
				var spot: Vector3 = child.multimesh.get_instance_transform(i).origin
				assert_gte(field.creek_distance_at(spot.x, spot.z), clearance)
				checked += 1
	assert_gt(checked, 300)


func test_broadleaf_trees_are_only_placed_when_spaced() -> void:
	var field := _field()
	var builder := ScatterBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, RoadProfile.new(trail, sampler.length), trail, ScatterDef.new())
	assert_eq(builder.broadleaf_count, 0, "Rally Road's default: none")
```

  And append to the end of `tests/unit/test_low_poly_meshes.gd`:

```gdscript
func test_broadleaf_tree_has_a_trunk_and_leaves_and_stays_cheap() -> void:
	var mesh := LowPolyMeshes.broadleaf(Color(0.38, 0.5, 0.22), Color(0.33, 0.25, 0.18), 4)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_between(vertices.size() / 3, 20, 150, "about as cheap as a pine")
	var top: float = Array(vertices).map(func(v: Vector3) -> float: return v.y).max()
	assert_between(top, 4.0, 6.5, "about 5 m tall")
	var trunk := Vector3(0.33, 0.25, 0.18)
	assert_true(Array(colors).any(func(c: Color) -> bool: return Vector3(c.r, c.g, c.b).distance_to(trunk) < 0.01), "trunk colour present")
```

- [ ] **Step 2: Run them to see them fail.**
  Run the `-gtest` commands for `res://tests/unit/test_creek.gd` and `res://tests/unit/test_low_poly_meshes.gd`.
  Expected: SCRIPT ERROR — `broadleaf_spacing`, `broadleaf_count`, `CREEK_CLEARANCE` and `LowPolyMeshes.broadleaf` don't exist.

- [ ] **Step 3: Replace `levels/trail/scatter_def.gd`:**

`levels/trail/scatter_def.gd`:

```gdscript
class_name ScatterDef
extends Resource
## Settings for scenery placed around a trail.

## Average distance between pines (m); 12.2 m is about one per 150 m².
@export var pine_spacing: float = 12.2
## Average distance between broadleaf trees (m); 0 = none.
@export var broadleaf_spacing: float = 0.0
## Average distance between rocks (m); 17.3 m is about one per 300 m².
@export var rock_spacing: float = 17.3
## Nothing is placed closer than this to a shoulder edge (m).
@export var road_clearance: float = 6.0
## Nothing is placed on slopes steeper than this (degrees).
@export var max_slope_deg: float = 35.0
## Pines further than this from the camera are not drawn (m).
@export var pine_view_distance: float = 300.0
## Broadleaf trees further than this from the camera are not drawn (m).
@export var broadleaf_view_distance: float = 300.0
## Rocks further than this from the camera are not drawn (m).
@export var rock_view_distance: float = 150.0
## Distance between roadside posts (m).
@export var post_spacing: float = 25.0
## Posts go on a side where the terrain falls more than this within 10 m of the edge (m).
@export var post_drop: float = 2.0
## Rocks within this distance of a shoulder edge get collision (m).
@export var rock_collision_distance: float = 30.0
@export var foliage_color: Color = Color(0.33, 0.4, 0.24)
@export var broadleaf_color: Color = Color(0.38, 0.5, 0.22)
@export var trunk_color: Color = Color(0.36, 0.26, 0.18)
@export var rock_color: Color = Color(0.55, 0.45, 0.38)
@export var post_color: Color = Color(0.93, 0.92, 0.88)
@export var reflector_color: Color = Color(0.95, 0.45, 0.1)
@export var seed: int = 11
```

- [ ] **Step 4: Replace `levels/trail/scatter_builder.gd`:**

`levels/trail/scatter_builder.gd`:

```gdscript
class_name ScatterBuilder
extends Node3D
## Places pines, rocks, roadside posts and broadleaf trees around a trail. Trees
## and rocks are scattered one per grid cell with a random offset, kept clear of
## the road and any creek, and off steep slopes; posts line shoulders where the
## ground drops away. Each kind is drawn as one MultiMesh per terrain chunk.

const DIRT := preload("res://surfaces/dirt.tres")

## How far outward from the shoulder edge the ground is checked for a drop (m).
const DROP_CHECK_DISTANCE := 10.0
## Nothing is placed closer than this to a creek's edge (m).
const CREEK_CLEARANCE := 2.0

## Counts of placed items, for tests and build reports.
var pine_count := 0
var rock_count := 0
var post_count := 0
var broadleaf_count := 0


func build(field: TerrainField, sampler: RoadSampler, profile: RoadProfile, trail: TrailDef, def: ScatterDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	pine_count = 0
	rock_count = 0
	post_count = 0
	broadleaf_count = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = def.seed
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	var creek_clearance := trail.creek_width * 0.5 + CREEK_CLEARANCE

	var rock_collision := StaticBody3D.new()
	rock_collision.name = "RockCollision"
	rock_collision.set_meta(SurfaceLookup.META_KEY, DIRT)
	add_child(rock_collision)

	var pines := _scatter(field, def, def.pine_spacing, Vector2(0.8, 1.3), 0.0, creek_clearance, rng)
	pine_count = pines.size()
	_add_multimeshes(field, pines, LowPolyMeshes.pine(def.foliage_color, def.trunk_color), material,
			def.pine_view_distance, true)

	var rocks := _scatter(field, def, def.rock_spacing, Vector2(0.6, 1.6), 0.25, creek_clearance, rng)
	rock_count = rocks.size()
	_add_multimeshes(field, rocks, LowPolyMeshes.rock(def.rock_color, def.seed), material,
			def.rock_view_distance, false)
	for rock in rocks:
		if field.edge_distance_at(rock.origin.x, rock.origin.z) < def.rock_collision_distance:
			var sphere := SphereShape3D.new()
			sphere.radius = 0.8 * rock.basis.get_scale().x
			var shape := CollisionShape3D.new()
			shape.shape = sphere
			shape.position = rock.origin
			rock_collision.add_child(shape)

	var posts := _posts(field, sampler, profile, trail, def)
	post_count = posts.size()
	_add_multimeshes(field, posts, LowPolyMeshes.post(def.post_color, def.reflector_color), material,
			def.rock_view_distance, false)

	if def.broadleaf_spacing > 0.0:
		var trees := _scatter(field, def, def.broadleaf_spacing, Vector2(0.8, 1.3), 0.0, creek_clearance, rng)
		broadleaf_count = trees.size()
		_add_multimeshes(field, trees, LowPolyMeshes.broadleaf(def.broadleaf_color, def.trunk_color, def.seed),
				material, def.broadleaf_view_distance, true)


## One transform per grid cell of `spacing`, jittered, skipping cells too close
## to the road or a creek, or too steep. `sink` lowers each item by that share of its scale.
func _scatter(field: TerrainField, def: ScatterDef, spacing: float, scale_range: Vector2, sink: float,
		creek_clearance: float, rng: RandomNumberGenerator) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var width := (field.columns - 1) * field.spacing
	var depth := (field.rows - 1) * field.spacing
	var max_slope := deg_to_rad(def.max_slope_deg)
	var z := 0.0
	while z < depth:
		var x := 0.0
		while x < width:
			var world_x := field.origin.x + x + rng.randf() * spacing
			var world_z := field.origin.y + z + rng.randf() * spacing
			var yaw := rng.randf() * TAU
			var scale := rng.randf_range(scale_range.x, scale_range.y)
			x += spacing
			if field.edge_distance_at(world_x, world_z) < def.road_clearance:
				continue
			if field.creek_distance_at(world_x, world_z) < creek_clearance:
				continue
			if acos(clampf(field.normal_at(world_x, world_z).y, -1.0, 1.0)) > max_slope:
				continue
			var ground := field.height_at(world_x, world_z) - sink * scale
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
			transforms.append(Transform3D(basis, Vector3(world_x, ground, world_z)))
		z += spacing
	return transforms


## Posts every post_spacing along the road, on each side whose ground drops away.
func _posts(field: TerrainField, sampler: RoadSampler, profile: RoadProfile, trail: TrailDef,
		def: ScatterDef) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var half := trail.half_total_width()
	var distance := def.post_spacing * 0.5
	while distance < sampler.length:
		var across := sampler.right(distance)
		var flat_across := Vector3(across.x, 0.0, across.z).normalized()
		for side: float in [-1.0, 1.0]:
			var edge := sampler.surface_point(distance, side * half, profile)
			var outside := edge + flat_across * side * DROP_CHECK_DISTANCE
			if edge.y - field.height_at(outside.x, outside.z) < def.post_drop:
				continue
			var spot := edge + flat_across * side * 0.3
			transforms.append(Transform3D(Basis.looking_at(sampler.forward(distance), Vector3.UP), spot))
		distance += def.post_spacing
	return transforms


func _add_multimeshes(field: TerrainField, transforms: Array[Transform3D], mesh: ArrayMesh,
		material: StandardMaterial3D, view_distance: float, casts_shadow: bool) -> void:
	var chunk_metres := field.cells_per_chunk * field.spacing
	var buckets := {}
	for transform in transforms:
		var key := Vector2i(floori((transform.origin.x - field.origin.x) / chunk_metres),
				floori((transform.origin.z - field.origin.y) / chunk_metres))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(transform)
	for key in buckets:
		var bucket: Array = buckets[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = bucket.size()
		for i in bucket.size():
			multimesh.set_instance_transform(i, bucket[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = material
		instance.visibility_range_end = view_distance
		if not casts_shadow:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
```

- [ ] **Step 5: Replace `levels/trail/low_poly_meshes.gd`:**

`levels/trail/low_poly_meshes.gd`:

```gdscript
class_name LowPolyMeshes
extends RefCounted
## Small flat-shaded meshes for scenery, built in code with vertex colours:
## pine, broadleaf tree, rock, roadside post, gate post and gate banner. Every
## triangle is flat-shaded, wound and lit so it faces away from its shape's centre.

const ICOSAHEDRON_FACES := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
	[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5],
	[2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
]


## A pine about 4.7 m tall: a trunk and three stacked cones.
static func pine(foliage: Color, trunk: Color) -> ArrayMesh:
	var tool := _begin()
	_add_cylinder(tool, Vector3.ZERO, 0.15, 1.2, 6, trunk)
	# Only the lowest cone has a base; the upper bases are hidden inside the cone below.
	_add_cone(tool, Vector3(0.0, 0.8, 0.0), 1.6, 2.2, 7, foliage, true)
	_add_cone(tool, Vector3(0.0, 2.0, 0.0), 1.2, 1.9, 7, foliage.lightened(0.05), false)
	_add_cone(tool, Vector3(0.0, 3.1, 0.0), 0.8, 1.6, 7, foliage.lightened(0.1), false)
	return _finish(tool)


## A broadleaf tree about 5 m tall: a trunk and two lumpy leaf clumps (48 triangles).
static func broadleaf(foliage: Color, trunk: Color, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tool := _begin()
	_add_cylinder(tool, Vector3.ZERO, 0.18, 2.6, 4, trunk)
	_add_lumpy_ball(tool, Vector3(0.0, 3.4, 0.0), 1.8, 0.8, foliage, rng)
	_add_lumpy_ball(tool, Vector3(-0.5, 4.4, -0.3), 1.2, 0.8, foliage.lightened(0.08), rng)
	return _finish(tool)


## A rough, slightly flattened boulder about 2 m across.
static func rock(color: Color, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tool := _begin()
	_add_lumpy_ball(tool, Vector3.ZERO, 1.0, 0.7, color, rng)
	return _finish(tool)


## A roadside post 1 m tall with a reflector band near the top.
static func post(body: Color, band: Color) -> ArrayMesh:
	var tool := _begin()
	_add_box(tool, Vector3(0.0, 0.5, 0.0), Vector3(0.12, 1.0, 0.12), body)
	_add_box(tool, Vector3(0.0, 0.8, 0.0), Vector3(0.14, 0.12, 0.14), band)
	return _finish(tool)


## One upright of a checkpoint gate.
static func gate_post(color: Color, height: float) -> ArrayMesh:
	var tool := _begin()
	_add_box(tool, Vector3(0.0, height * 0.5, 0.0), Vector3(0.3, height, 0.3), color)
	return _finish(tool)


## The banner across the top of a checkpoint gate.
static func banner(color: Color, width: float) -> ArrayMesh:
	var tool := _begin()
	_add_box(tool, Vector3.ZERO, Vector3(width, 0.8, 0.1), color)
	return _finish(tool)


static func _begin() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


static func _finish(tool: SurfaceTool) -> ArrayMesh:
	return tool.commit()


## Adds a flat-shaded triangle facing away from `centre` (Godot's front faces
## have (b - a) x (c - a) pointing into the shape). Normals are set per triangle
## rather than generated, because generated normals smooth shared corners.
static func _add_triangle(tool: SurfaceTool, centre: Vector3, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var outward := (a + b + c) / 3.0 - centre
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var swap := b
		b = c
		c = swap
	tool.set_color(color)
	tool.set_normal(-(b - a).cross(c - a).normalized())
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)


## A jittered icosahedron of about `radius`, squashed vertically by `flatten`,
## with each face shaded slightly differently.
static func _add_lumpy_ball(tool: SurfaceTool, centre: Vector3, radius: float, flatten: float, color: Color,
		rng: RandomNumberGenerator) -> void:
	var golden := (1.0 + sqrt(5.0)) * 0.5
	var corners: Array[Vector3] = [
		Vector3(-1, golden, 0), Vector3(1, golden, 0), Vector3(-1, -golden, 0), Vector3(1, -golden, 0),
		Vector3(0, -1, golden), Vector3(0, 1, golden), Vector3(0, -1, -golden), Vector3(0, 1, -golden),
		Vector3(golden, 0, -1), Vector3(golden, 0, 1), Vector3(-golden, 0, -1), Vector3(-golden, 0, 1),
	]
	for i in corners.size():
		var jittered := corners[i].normalized() * rng.randf_range(0.8, 1.2)
		corners[i] = centre + Vector3(jittered.x, jittered.y * flatten, jittered.z) * radius
	for face in ICOSAHEDRON_FACES:
		var shade := rng.randf_range(0.9, 1.05)
		_add_triangle(tool, centre, corners[face[0]], corners[face[1]], corners[face[2]],
				Color(color.r * shade, color.g * shade, color.b * shade))


static func _add_box(tool: SurfaceTool, centre: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(centre + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for quad in [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]:
		_add_triangle(tool, centre, corners[quad[0]], corners[quad[1]], corners[quad[2]], color)
		_add_triangle(tool, centre, corners[quad[0]], corners[quad[2]], corners[quad[3]], color)


static func _add_cone(tool: SurfaceTool, base: Vector3, radius: float, height: float, sides: int, color: Color,
		with_base: bool) -> void:
	var tip := base + Vector3(0.0, height, 0.0)
	var centre := base + Vector3(0.0, height * 0.25, 0.0)
	for i in sides:
		var a := base + Vector3(cos(TAU * i / sides), 0.0, sin(TAU * i / sides)) * radius
		var b := base + Vector3(cos(TAU * (i + 1) / sides), 0.0, sin(TAU * (i + 1) / sides)) * radius
		_add_triangle(tool, centre, a, b, tip, color)
		if with_base:
			_add_triangle(tool, centre, a, b, base, color.darkened(0.2))


static func _add_cylinder(tool: SurfaceTool, base: Vector3, radius: float, height: float, sides: int, color: Color) -> void:
	var centre := base + Vector3(0.0, height * 0.5, 0.0)
	var top := Vector3(0.0, height, 0.0)
	for i in sides:
		var a := base + Vector3(cos(TAU * i / sides), 0.0, sin(TAU * i / sides)) * radius
		var b := base + Vector3(cos(TAU * (i + 1) / sides), 0.0, sin(TAU * (i + 1) / sides)) * radius
		_add_triangle(tool, centre, a, b, b + top, color)
		_add_triangle(tool, centre, a, b + top, a + top, color)
```

- [ ] **Step 6: Run the tests.**
  Run the two `-gtest` commands — expected: all pass.
  Run: `./run_tests.sh all` — expected: exit 0.

- [ ] **Step 7: Commit.**
  ```bash
  git add levels/trail/scatter_def.gd levels/trail/scatter_builder.gd levels/trail/low_poly_meshes.gd tests/unit/test_creek.gd tests/unit/test_low_poly_meshes.gd
  git commit -m "Add broadleaf trees and keep scenery out of the creek"
  ```

---

### Task 6: Muddy Valley

**Files:**
- Create: `tools/generate_muddy_valley_curve.gd`, `levels/muddy_valley/muddy_valley_curve.tres` (generated), `levels/muddy_valley/muddy_valley_trail.tres`, `muddy_valley_terrain.tres`, `muddy_valley_scatter.tres`, `muddy_valley_level.tres`, `muddy_valley.tscn`, `tests/scenarios/test_muddy_valley.gd`
- Modify: `levels/catalog.tres`, `levels/shared/run_level.gd`, `tests/unit/test_curve_generator.gd`, `tests/unit/test_level_catalog.gd` (append), `tests/unit/test_menus.gd`, `tests/scenarios/test_rally_road.gd`

**Interfaces:**
- Consumes: everything from Tasks 1–5; `TrailScenarios` (Task 3); `SaveSandbox`, `SaveSystem.read`, `LevelCatalog`, `Progress.record_finish(level, time, splits)`, `Progress.is_unlocked(catalog, level)`, `ResultsScreen._next` (the Next level button), `ResultsScreen.next_pressed`.
- Produces: `LevelDef` id `&"muddy_valley"`, scene `res://levels/muddy_valley/muddy_valley.tscn`, second in the catalog; `static RunLevel.is_missing_from_catalog(scene_path: String, found: LevelDef) -> bool`, and `RunLevel._ready` calls `push_warning` when it is true.

- [ ] **Step 1: Create `tools/generate_muddy_valley_curve.gd` and generate the curve.**

`tools/generate_muddy_valley_curve.gd`:

```gdscript
extends SceneTree
## Builds Muddy Valley's centre-line curve from a list of segments and saves it as
## levels/muddy_valley/muddy_valley_curve.tres. Re-run after changing SEGMENTS:
##   godot --headless -s tools/generate_muddy_valley_curve.gd
## Segment format: see CurveGenerator.

const OUTPUT := "res://levels/muddy_valley/muddy_valley_curve.tres"

const SEGMENTS := [
	["straight", 80.0, 0.0],      # ridge start, looking over the valley
	["arc", 120.0, 30.0, -0.05],
	["straight", 70.0, -0.08],
	["arc", 90.0, -45.0, -0.08],
	["straight", 90.0, -0.09],    # the jump
	["arc", 50.0, 55.0, -0.09],   # esses
	["arc", 50.0, -60.0, -0.09],
	["straight", 40.0, -0.1],
	["arc", 18.0, 180.0, -0.07],  # hairpin
	["straight", 60.0, -0.06],
	["arc", 150.0, -35.0, -0.02], # into the valley
	["straight", 80.0, 0.0],      # mud stretch 1
	["arc", 200.0, 25.0, 0.01],
	["straight", 250.0, 0.01],    # the creek, with mud stretch 2
	["arc", 120.0, -40.0, 0.03],
	["straight", 130.0, 0.08],    # the final climb
	["arc", 100.0, 30.0, 0.08],
	["straight", 100.0, 0.08],    # mud to the finish
	["straight", 60.0, 0.0],      # run-off past the finish
]


func _init() -> void:
	quit(CurveGenerator.generate(SEGMENTS, OUTPUT, "Muddy Valley"))
```

  Run: `mkdir -p levels/muddy_valley && godot --headless -s tools/generate_muddy_valley_curve.gd`
  Expected output: `saved res://levels/muddy_valley/muddy_valley_curve.tres: 30 points, 1568 m long, ends -16 m, lowest -45 m, highest +0 m`

  Segment distances along the road, for reference: descent 80–632 m (jump straight 284–374 m, hairpin 515–572 m), valley floor 632–1141 m (straight 724–804 m, arc 804–891 m, straight 891–1141 m; the creek runs on the right at 745–895 m, where the ground is below the road), final climb 1141–1508 m, run-off 1508–1568 m. Finish = 1568 − 70 = 1498 m.

- [ ] **Step 2: In `tests/unit/test_curve_generator.gd`, add Muddy Valley to `LEVEL_CURVES`**, so the dictionary reads:
  ```gdscript
  const LEVEL_CURVES := {
  	"res://tools/generate_rally_road_curve.gd": "res://levels/rally_road/rally_road_curve.tres",
  	"res://tools/generate_muddy_valley_curve.gd": "res://levels/muddy_valley/muddy_valley_curve.tres",
  }
  ```

- [ ] **Step 3: Create the level's resources.**

`levels/muddy_valley/muddy_valley_trail.tres`:

```ini
[gd_resource type="Resource" script_class="TrailDef" format=3]

[ext_resource type="Script" path="res://levels/trail/trail_def.gd" id="1_trail"]
[ext_resource type="Script" path="res://levels/trail/surface_stretch.gd" id="2_stretch"]
[ext_resource type="Resource" path="res://surfaces/dirt.tres" id="3_dirt"]
[ext_resource type="Resource" path="res://surfaces/mud.tres" id="4_mud"]

[sub_resource type="Resource" id="Resource_mud_creek_side"]
script = ExtResource("2_stretch")
start = 760.0
length = 90.0
surface = ExtResource("4_mud")
color = Color(0.22, 0.16, 0.11, 1)
rut_depth = 0.08

[sub_resource type="Resource" id="Resource_mud_floor"]
script = ExtResource("2_stretch")
start = 980.0
length = 70.0
surface = ExtResource("4_mud")
color = Color(0.22, 0.16, 0.11, 1)
rut_depth = 0.08

[sub_resource type="Resource" id="Resource_mud_climb"]
script = ExtResource("2_stretch")
start = 1300.0
length = 200.0
surface = ExtResource("4_mud")
color = Color(0.22, 0.16, 0.11, 1)
rut_depth = 0.08

[resource]
script = ExtResource("1_trail")
road_width = 9.0
detail_step = 0.5
base_surface = ExtResource("3_dirt")
painted_lines = false
surface_stretches = Array[ExtResource("2_stretch")]([SubResource("Resource_mud_creek_side"), SubResource("Resource_mud_floor"), SubResource("Resource_mud_climb")])
undulation_amplitude = 0.1
undulation_wavelengths = Vector2(13, 21)
rough_sections = Array[Vector3]([Vector3(150, 130, 25), Vector3(380, 180, 25), Vector3(600, 110, 25), Vector3(900, 240, 20), Vector3(1150, 140, 20)])
pothole_clusters = Array[Vector2]([Vector2(110, 5), Vector2(800, 6), Vector2(1250, 5)])
pothole_radius_range = Vector2(0.25, 1.1)
pothole_depth_range = Vector2(0.05, 0.18)
jumps = Array[Vector3]([Vector3(330, 1, 10)])
end_margin = 70.0
checkpoint_distances = PackedFloat32Array(270, 650, 950, 1230)
creek_start = 745.0
creek_length = 150.0
creek_offset = 17.0
asphalt_color = Color(0.45, 0.34, 0.23, 1)
shoulder_color = Color(0.38, 0.47, 0.23, 1)
seed = 5
```

`levels/muddy_valley/muddy_valley_terrain.tres`:

```ini
[gd_resource type="Resource" script_class="TerrainDef" format=3]

[ext_resource type="Script" path="res://levels/trail/terrain_def.gd" id="1_terrain"]

[resource]
script = ExtResource("1_terrain")
dirt_color = Color(0.4, 0.5, 0.25, 1)
rock_color = Color(0.33, 0.26, 0.19, 1)
seed = 21
```

`levels/muddy_valley/muddy_valley_scatter.tres`:

```ini
[gd_resource type="Resource" script_class="ScatterDef" format=3]

[ext_resource type="Script" path="res://levels/trail/scatter_def.gd" id="1_scatter"]

[resource]
script = ExtResource("1_scatter")
pine_spacing = 30.0
broadleaf_spacing = 16.0
foliage_color = Color(0.25, 0.35, 0.2, 1)
broadleaf_color = Color(0.38, 0.5, 0.22, 1)
trunk_color = Color(0.33, 0.25, 0.18, 1)
rock_color = Color(0.5, 0.47, 0.42, 1)
post_color = Color(0.45, 0.33, 0.22, 1)
reflector_color = Color(0.9, 0.6, 0.15, 1)
seed = 23
```

`levels/muddy_valley/muddy_valley_level.tres`:

```ini
[gd_resource type="Resource" script_class="LevelDef" format=3]

[ext_resource type="Script" path="res://game/level_def.gd" id="1_level"]

[resource]
script = ExtResource("1_level")
id = &"muddy_valley"
display_name = "Muddy Valley"
scene_path = "res://levels/muddy_valley/muddy_valley.tscn"
two_star_time = 95.0
three_star_time = 85.0
```

`levels/muddy_valley/muddy_valley.tscn`:

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://levels/shared/run_level.gd" id="1_level"]
[ext_resource type="Script" path="res://levels/shared/golden_hour_mood.gd" id="2_mood"]
[ext_resource type="Script" path="res://levels/trail/trail_level.gd" id="3_trail"]
[ext_resource type="Resource" path="res://levels/muddy_valley/muddy_valley_trail.tres" id="4_trail_def"]
[ext_resource type="Resource" path="res://levels/muddy_valley/muddy_valley_terrain.tres" id="5_terrain_def"]
[ext_resource type="Resource" path="res://levels/muddy_valley/muddy_valley_scatter.tres" id="6_scatter_def"]
[ext_resource type="Curve3D" path="res://levels/muddy_valley/muddy_valley_curve.tres" id="7_curve"]
[ext_resource type="PackedScene" path="res://levels/shared/driving_rig.tscn" id="8_rig"]
[ext_resource type="Script" path="res://game/checkpoint_tracker.gd" id="9_tracker"]
[ext_resource type="Script" path="res://game/reset_controller.gd" id="10_resets"]
[ext_resource type="Script" path="res://game/run_controller.gd" id="11_run"]
[ext_resource type="Script" path="res://ui/run_hud.gd" id="12_hud"]

[node name="MuddyValley" type="Node3D"]
script = ExtResource("1_level")

[node name="Mood" type="Node3D" parent="."]
script = ExtResource("2_mood")
sun_color = Color(1, 0.8, 0.58, 1)
sun_energy = 1.25
sun_elevation_deg = 18.0
sky_top = Color(0.4, 0.56, 0.76, 1)
sky_horizon = Color(0.9, 0.82, 0.6, 1)
ground_color = Color(0.3, 0.34, 0.22, 1)
fog_density = 0.009

[node name="Trail" type="Node3D" parent="."]
script = ExtResource("3_trail")
trail = ExtResource("4_trail_def")
terrain = ExtResource("5_terrain_def")
scatter = ExtResource("6_scatter_def")

[node name="Road" type="Path3D" parent="Trail"]
curve = ExtResource("7_curve")

[node name="DrivingRig" parent="." instance=ExtResource("8_rig")]

[node name="CheckpointTracker" type="Node" parent="."]
script = ExtResource("9_tracker")

[node name="ResetController" type="Node" parent="."]
script = ExtResource("10_resets")

[node name="RunController" type="Node" parent="."]
script = ExtResource("11_run")

[node name="RunHud" type="CanvasLayer" parent="."]
script = ExtResource("12_hud")
```

- [ ] **Step 4: Add Muddy Valley to the catalog.** Replace `levels/catalog.tres` with:

`levels/catalog.tres`:

```ini
[gd_resource type="Resource" script_class="LevelCatalog" format=3]

[ext_resource type="Script" path="res://game/level_def.gd" id="1_gufqt"]
[ext_resource type="Resource" path="res://levels/rally_road/rally_road_level.tres" id="2_3v4in"]
[ext_resource type="Script" path="res://game/level_catalog.gd" id="3_sd0ii"]
[ext_resource type="Resource" path="res://levels/muddy_valley/muddy_valley_level.tres" id="4_muddy"]

[resource]
script = ExtResource("3_sd0ii")
levels = Array[ExtResource("1_gufqt")]([ExtResource("2_3v4in"), ExtResource("4_muddy")])
```

- [ ] **Step 5: Warn about a level scene missing from the catalog.** In `levels/shared/run_level.gd`, directly after `level = GameState.level_for_scene(scene_file_path)` in `_ready`, add:
  ```gdscript
  	if is_missing_from_catalog(scene_file_path, level):
  		push_warning("%s is not in the level catalog, so it runs without stars or saving" % scene_file_path)
  ```
  and add this function directly above `func _add_overlays() -> void:`:
  ```gdscript
  ## True for a level saved as a scene but not listed in the catalog. Levels built
  ## in code by tests have no scene path and are expected to be missing.
  static func is_missing_from_catalog(scene_path: String, found: LevelDef) -> bool:
  	return found == null and not scene_path.is_empty()


  ```

- [ ] **Step 6: Write the tests.** Append to the end of `tests/unit/test_level_catalog.gd`:

```gdscript
func test_muddy_valley_follows_rally_road_and_unlocks_after_it() -> void:
	var shipped: LevelCatalog = load("res://levels/catalog.tres")
	assert_eq(shipped.levels.size(), 2)
	var muddy: LevelDef = shipped.levels[1]
	assert_eq(muddy.id, &"muddy_valley")
	assert_eq(muddy.display_name, "Muddy Valley")
	assert_true(ResourceLoader.exists(muddy.scene_path), "its scene exists")
	assert_gt(muddy.two_star_time, muddy.three_star_time, "two stars is the easier target")
	var progress := Progress.new()
	assert_false(progress.is_unlocked(shipped, muddy), "locked at first")
	progress.record_finish(shipped.levels[0], 90.0, {})
	assert_true(progress.is_unlocked(shipped, muddy), "unlocked by finishing Rally Road")


func test_a_saved_level_scene_missing_from_the_catalog_is_flagged() -> void:
	assert_true(RunLevel.is_missing_from_catalog("res://levels/lost/lost.tscn", null))
	assert_false(RunLevel.is_missing_from_catalog("", null), "a level built in code by a test")
	assert_false(RunLevel.is_missing_from_catalog("res://a.tscn", catalog.levels[0]), "a catalog level")
```

  In `tests/unit/test_menus.gd`, in `test_main_menu_shows_total_stars`, change the expected label from `"2 / 3 stars"` to `"2 / 6 stars"`: the catalog now holds two levels of three stars each.

  In `tests/scenarios/test_rally_road.gd`, in `test_scripted_driver_completes_rally_road`, directly after the line `assert_eq(SaveSandbox.requested_scenes, [level.scene_file_path], "Retry reloads Rally Road")`, add:

```gdscript
	assert_true(level.results._next.visible, "finishing Rally Road unlocks the next level")
	level.results.next_pressed.emit()
	assert_eq(SaveSandbox.requested_scenes[-1], "res://levels/muddy_valley/muddy_valley.tscn", "Next level opens Muddy Valley")
```

  Create `tests/scenarios/test_muddy_valley.gd`:

`tests/scenarios/test_muddy_valley.gd`:

```gdscript
extends GutTest
## Muddy Valley as a whole: it builds with its mud, ruts and creek, a scripted
## driver can complete it, mud slows the car without trapping it, a car can drive
## out of the creek, and the road carries on past the finish.

const MUDDY_VALLEY := preload("res://levels/muddy_valley/muddy_valley.tscn")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _load() -> RunLevel:
	var level: RunLevel = MUDDY_VALLEY.instantiate()
	add_child_autofree(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func _surface_under_road(level: RunLevel, distance: float) -> StringName:
	var sampler := level.trail.sampler
	var above := sampler.position(distance) + Vector3.UP * 3.0
	var query := PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * 6.0)
	query.exclude = [level.rig.car.get_rid()]
	var hit := level.get_world_3d().direct_space_state.intersect_ray(query)
	return SurfaceLookup.surface_of(hit["collider"]).id if not hit.is_empty() else &""


func test_muddy_valley_builds_with_its_gates_mud_and_creek() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var scatter := level.trail.scatter_builder
	gut.p("Muddy Valley: %.0f m long, built in %.2f s (%d x %d terrain chunks, %d pines, %d broadleaf, %d rocks, %d posts, %d water points)" % [
		sampler.length, level.trail.build_seconds,
		level.trail.field.chunk_count().x, level.trail.field.chunk_count().y,
		scatter.pine_count, scatter.broadleaf_count, scatter.rock_count, scatter.post_count,
		level.trail.creek_builder.water_points.size()])
	assert_between(sampler.length, 1450.0, 1650.0, "about 1.5 km plus the run-off")
	assert_eq(level.trail.checkpoints.reset_transforms.size(), 6, "start, 4 checkpoints, finish")
	assert_lt(level.trail.build_seconds, 3.0, "desktop build time")
	assert_not_null(level.level, "Muddy Valley finds its catalog entry")
	assert_gt(scatter.broadleaf_count, 0, "broadleaf trees")
	assert_gt(level.trail.creek_builder.water_points.size(), 35, "water along more than 70 m of the creek's 150 m")
	await wait_physics_frames(2)
	assert_eq(_surface_under_road(level, 800.0), &"mud", "the mud stretch beside the creek")
	assert_eq(_surface_under_road(level, 1400.0), &"mud", "the final climb")
	assert_eq(_surface_under_road(level, 600.0), &"dirt", "the descent")


func test_scripted_driver_completes_muddy_valley() -> void:
	var level := _load()
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler)
	watch_signals(level.resets)
	watch_signals(level.run)
	var ticks := 0
	var lost_contact := 0
	var jumps := level.trail.trail.jumps
	while not level.tracker.is_finished() and ticks < ScenarioHelper.ticks(200.0):
		driver.drive()
		await get_tree().physics_frame
		ticks += 1
		if level.run.clock.stage != RunClock.Stage.RUNNING or car.air_control.is_active:
			continue
		var distance := level.trail.sampler.closest_distance(car.global_position)
		if not jumps.any(func(j: Vector3) -> bool: return absf(distance - j.x) < 25.0):
			for wheel in car.wheels:
				if not wheel.in_contact:
					lost_contact += 1
	var time := level.run.clock.elapsed
	gut.p("scripted driver: finished %s after %s, %d checkpoints, %d wheel-ticks without contact away from the jump" % [
		level.tracker.is_finished(), RunHud.format_time(time),
		get_signal_emit_count(level.run, "checkpoint_reached"), lost_contact])
	assert_true(level.tracker.is_finished(), "reached the finish")
	assert_signal_not_emitted(level.resets, "car_reset")
	assert_signal_emit_count(level.run, "checkpoint_reached", 4)
	assert_between(time, 60.0, 150.0)
	assert_lt(lost_contact, 240, "rough ground shakes the wheels but doesn't throw them off")
	assert_true(level.results.is_showing(), "results appear at the finish")
	var saved: Dictionary = SaveSystem.read(SaveSandbox.PATH)["levels"]["muddy_valley"]
	assert_almost_eq(float(saved["best_time"]), time, 0.001, "the finish was saved")


func test_a_car_stopped_in_the_mud_climb_reaches_the_finish() -> void:
	var level := _load()
	await TrailScenarios.wait_for_go(level)
	await TrailScenarios.place_on_road(level, 1400.0)
	var finish := level.trail.checkpoints.gate_distances[-1]
	var car := level.rig.car
	var seconds := await TrailScenarios.full_throttle_until(level, 30.0,
			func() -> bool: return level.trail.sampler.closest_distance(car.global_position) >= finish)
	gut.p("from a standstill at 1400 m (8%% mud climb) to the finish at %.0f m: %.1f s" % [finish, seconds])
	assert_lt(seconds, 30.0, "mud slows the car but never traps it")


func test_mud_is_slower_than_dirt_from_a_standstill() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var car := level.rig.car
	await TrailScenarios.wait_for_go(level)
	var covered := {}
	for start: float in [765.0, 860.0]:  # flat mud beside the creek; 1% uphill dirt just after it
		await TrailScenarios.place_on_road(level, start)
		await TrailScenarios.full_throttle_until(level, 3.0, func() -> bool: return false)
		covered[start] = sampler.closest_distance(car.global_position) - start
	gut.p("3 s at full throttle from rest: %.1f m on mud, %.1f m on dirt" % [covered[765.0], covered[860.0]])
	assert_lt(covered[765.0], covered[860.0] * 0.9, "mud is clearly slower")


## A car that slides into the creek can drive out along it. (Straight up the
## road-side bank it stalls: there the bank adds to the road's embankment.)
func test_a_car_in_the_creek_drives_out_along_it() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var trail := level.trail.trail
	var field := level.trail.field
	var car := level.rig.car
	await TrailScenarios.wait_for_go(level)
	var distance := 820.0
	var centre := TerrainField.creek_point(sampler, trail, distance)
	var along := sampler.forward(distance)
	var spot := Vector3(centre.x, field.height_at(centre.x, centre.y) + 1.0, centre.y)
	await TrailScenarios.place(level, Transform3D(Basis.looking_at(Vector3(along.x, 0.0, along.z)), spot))
	var out_of_channel := trail.creek_width * 0.5 + TerrainField.CREEK_BANK
	var seconds := 10.0
	for tick in ScenarioHelper.ticks(10.0):
		if field.creek_distance_at(car.global_position.x, car.global_position.z) > out_of_channel:
			seconds = tick / float(Engine.physics_ticks_per_second)
			break
		car.input.virtual_steer = 0.0
		car.input.virtual_throttle = 1.0
		car.input.virtual_brake = 0.0
		await get_tree().physics_frame
	gut.p("out of the creek channel in %.1f s" % seconds)
	assert_lt(seconds, 10.0, "the creek channel is shallow enough to drive out of")


func test_the_road_carries_on_past_the_finish() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var car := level.rig.car
	await TrailScenarios.wait_for_go(level)
	var finish := level.trail.checkpoints.gate_distances[-1]
	await TrailScenarios.place_on_road(level, finish - 150.0)
	await TrailScenarios.full_throttle_until(level, 30.0,
			func() -> bool: return sampler.closest_distance(car.global_position) >= finish)
	var speed := car.forward_speed()
	await TrailScenarios.brake_to_stop(level)
	var stopped_at := sampler.closest_distance(car.global_position)
	gut.p("crossed the finish at %.0f km/h and stopped %.0f m past it (road ends %.0f m past it)" % [
		speed * 3.6, stopped_at - finish, sampler.length - finish])
	assert_lt(stopped_at, sampler.length - 5.0, "stops on the run-off")
	assert_lt(absf(sampler.lateral_offset(car.global_position)), level.trail.trail.half_total_width())
```

- [ ] **Step 7: Import and run everything.**
  Run: `godot --headless --import`
  Run the `-gtest` commands for `res://tests/unit/test_curve_generator.gd`, `res://tests/unit/test_level_catalog.gd`, `res://tests/scenarios/test_rally_road.gd` and `res://tests/scenarios/test_muddy_valley.gd`.
  Expected: all pass. In the scratch clone, `test_muddy_valley.gd` printed:
  ```
  Muddy Valley: 1568 m long, built in 1.64 s (11 x 11 terrain chunks, 2140 pines, 7507 broadleaf, 6533 rocks, 53 posts, 42 water points)
  scripted driver: finished true after 1:39.9, 4 checkpoints, 155 wheel-ticks without contact away from the jump
  from a standstill at 1400 m (8% mud climb) to the finish at 1498 m: 16.5 s
  3 s at full throttle from rest: 8.6 m on mud, 14.0 m on dirt
  out of the creek channel in 6.0 s
  crossed the finish at 29 km/h and stopped 4 m past it (road ends 70 m past it)
  ```
  Timing lines may differ slightly between machines; the assertions must pass.
  Run: `./run_tests.sh all` — expected: exit 0.

- [ ] **Step 8: Commit.**
  ```bash
  git add tools/generate_muddy_valley_curve.gd tools/generate_muddy_valley_curve.gd.uid levels/muddy_valley levels/catalog.tres levels/shared/run_level.gd tests/unit/test_curve_generator.gd tests/unit/test_level_catalog.gd tests/unit/test_menus.gd tests/scenarios/test_rally_road.gd tests/scenarios/test_muddy_valley.gd tests/scenarios/test_muddy_valley.gd.uid
  git commit -m "Add Muddy Valley as the second level"
  ```

---

### Task 7: Level screenshots and B2 performance notes

**Files:**
- Create: `tools/level_shots.gd`, `tools/level_shots.tscn`, `docs/notes/performance-m2b2.md`

**Interfaces:**
- Consumes: `RunLevel` (`trail.build_seconds`, `trail.sampler`, `trail.profile`, `rig.place_car`).
- Produces: `godot --path . res://tools/level_shots.tscn -- <scene> <distance>...` saves `build/level_shots/<level>_<distance>.png` (`build/` is already git-ignored) and prints the build time and render counts per spot.

- [ ] **Step 1: Create the tool.**

`tools/level_shots.gd`:

```gdscript
extends Node
## Renders a level in a window at points along its road, saves a PNG for each
## and prints the build time and what was drawn there (primitives, draw calls,
## objects). Run from the project root:
##   godot --path . res://tools/level_shots.tscn -- res://levels/muddy_valley/muddy_valley.tscn 15 320 760
## The first argument after "--" is the level scene, the rest are distances along
## the road (m). Shots are saved as build/level_shots/<level>_<distance>.png.

const OUT_DIR := "res://build/level_shots"
## Frames to wait at each spot so the camera and visibility ranges settle.
const SETTLE_FRAMES := 45


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <level scene> <distance> [distance...]")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var level: RunLevel = load(args[0]).instantiate()
	add_child(level)
	await get_tree().process_frame
	var tag := args[0].get_file().get_basename()
	print("%s built in %.2f s" % [tag, level.trail.build_seconds])
	for arg in args.slice(1):
		var spot := float(arg)
		level.rig.place_car(level.trail.sampler.transform_at(spot, 1.0, level.trail.profile))
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("%s/%s_%04d.png" % [OUT_DIR, tag, int(spot)]))
		print("%s at %4d m: %d primitives, %d draw calls, %d objects" % [tag, int(spot),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	get_tree().quit()
```

`tools/level_shots.tscn`:

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://tools/level_shots.gd" id="1_shots"]

[node name="LevelShots" type="Node"]
script = ExtResource("1_shots")
```

- [ ] **Step 2: Take the shots** (this opens a window; it needs a display).
  Run: `godot --headless --import`
  Run: `godot --path . res://tools/level_shots.tscn -- res://levels/muddy_valley/muddy_valley.tscn 15 320 560 760 1000 1250 1450`
  Run: `godot --path . res://tools/level_shots.tscn -- res://levels/rally_road/rally_road.tscn 15 700 1490`
  Expected: 10 PNGs in `build/level_shots/`, and one line per spot. In the scratch clone the counts were:
  ```
  muddy_valley built in 1.66 s
  muddy_valley at   15 m: 261436 primitives, 133 draw calls, 603 objects
  muddy_valley at  320 m: 273968 primitives, 127 draw calls, 599 objects
  muddy_valley at  560 m: 261696 primitives, 129 draw calls, 601 objects
  muddy_valley at  760 m: 242300 primitives, 121 draw calls, 593 objects
  muddy_valley at 1000 m: 259296 primitives, 110 draw calls, 578 objects
  muddy_valley at 1250 m: 209644 primitives, 111 draw calls, 587 objects
  muddy_valley at 1450 m: 150652 primitives, 96 draw calls, 564 objects
  rally_road built in 1.17 s
  rally_road at   15 m: 268456 primitives, 129 draw calls, 623 objects
  rally_road at  700 m: 261236 primitives, 105 draw calls, 603 objects
  rally_road at 1490 m: 190092 primitives, 101 draw calls, 601 objects
  ```

- [ ] **Step 3: Write `docs/notes/performance-m2b2.md`** with this structure, filled in with the numbers printed in Step 2 and by the Task 6 tests:
  ```markdown
  # Performance: Muddy Valley (Milestone 2 Part B2), desktop

  Build: `<branch>` at `<commit>`. Measured with `tools/level_shots.tscn` and the scenario tests. Phone numbers come from the user's session after merge.

  ## Build time (desktop)
  | Level | Build time | Terrain chunks | Pines | Broadleaf | Rocks | Posts |

  ## Render counts (desktop, the chase camera at each spot)
  | Level | Spot (m) | Primitives | Draw calls | Objects |

  ## Scripted driver and mud (desktop)
  - Scripted driver: <time>, no resets, <n> wheel-ticks without contact away from the jump.
  - Standstill in the mud climb at 1400 m to the finish: <s>.
  - 3 s from rest: <m> on mud, <m> on dirt.
  - Out of the creek: <s>.
  - Run-off: Muddy Valley <line>; Rally Road <line>.

  ## Budgets still to check on the phone
  60 fps, < 300k triangles, < 150 draw calls, < 4 ms physics, < 3 s load after a fresh app start.
  ```

- [ ] **Step 4: Report the screenshot paths** in your report file so the controller can look at them. Do not commit the PNGs.

- [ ] **Step 5: Commit.**
  ```bash
  git add tools/level_shots.gd tools/level_shots.gd.uid tools/level_shots.tscn docs/notes/performance-m2b2.md
  git commit -m "Add a level screenshot tool and Muddy Valley performance notes"
  ```
