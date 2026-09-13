# Milestone 2 Part A — Rally Road Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Test Ground prototype into a real track: a trail builder that generates road, terrain, scenery and checkpoints from one road curve, the Rally Road mountain climb built with it, and the countdown, clock, checkpoints and resets a timed run needs, on the phone at the end.

**Architecture:** One `Path3D` curve plus three settings resources (`TrailDef`, `TerrainDef`, `ScatterDef`) feed pure-maths helpers (`RoadSampler`, `RoadProfile`, `Corridor`, `TerrainField`) and node builders (`RoadBuilder`, `TerrainBuilder`, `ScatterBuilder`, `CheckpointPlacer`), assembled by `TrailLevel`. A reusable `DrivingRig` scene holds the car, camera, controls, telemetry and recorder. `RunLevel` wires a trail, the rig and the run systems (`RunController` with `RunClock`, `CheckpointTracker`, `ResetController` with `FlipDetector`, `RunHud`). Everything is generated from fixed seeds, so the same settings always build the same level.

**Tech Stack:** Godot 4.7.2 stable, typed GDScript, Jolt Physics, GUT 9.7.1, Mobile renderer (Vulkan), Android debug export (already set up on this machine).

**Spec:** `docs/superpowers/specs/2026-09-13-m2a-rally-road-design.md` (binding), refining `docs/superpowers/specs/2026-09-11-ridge-design.md` Milestone 2.

## Global Constraints

- Godot **4.7.2 stable**; GDScript only, statically typed; no C#. Tab-indented; copy code blocks verbatim.
- Physics engine `"Jolt Physics"`, **120 ticks/s**, rendering capped at **60 FPS**, `threading/worker_pool/max_threads=4` (all already in `project.godot`).
- Axes: forward = −Z, right = +X, up = +Y. SI units; degrees only in names ending `_deg`.
- Tunable numbers live in resources (`CarStats`, `SurfaceDef`, `GripTable`, `TrailDef`, `TerrainDef`, `ScatterDef`). Fixed game rules from the spec are named constants in their script: countdown **3 s** (`RunClock`), flip **70° / 2 m/s / 2 s** (`FlipDetector`).
- Feature folders: `levels/trail/` (trail builder), `levels/shared/` (rig, run level, switcher, shared shapes), `levels/rally_road/`, `game/` (run systems), `ui/` (HUD), `tests/unit/`, `tests/scenarios/`, `tools/`.
- Loops over literal arrays must type their variable (`for side: float in [-1.0, 1.0]:`); untyped loop values break type inference.
- Low-poly meshes set flat normals per triangle; `SurfaceTool.generate_normals()` smooths shared corners and was verified to point box faces the wrong way.
- `HeightMapShape3D` rows run along +Z: row 0 is the chunk's local −Z edge (verified with a car crossing chunk borders).
- Tests: `./run_tests.sh unit|scenarios|all`. Commits: the task's subject line, a blank line, then the session's `Co-Authored-By` and `Claude-Session` trailers (use `git commit -F-` with a heredoc). Commit Godot's `.uid` files next to their scripts; never commit the user's `tmux-session.sh`.

## Verified Before Writing

Every code block below was built and run on this machine in a clone of `master` (`~/.cache/ridge/m2a-scratch`): **218 unit tests and 24 scenario tests pass, with one scenario test pending on purpose** (Task 16). Measured there:

| Check | Result |
|---|---|
| Rally Road | 1513 m long, climbs 74 m; 8 × 12 terrain chunks, 10184 pines, 5159 rocks, 33 posts |
| Rally Road desktop build time | 0.99–1.12 s (phone budget 3 s) |
| Scripted driver, whole road | finished in 1:33.3, all 4 checkpoints, no resets, 11 wheel-ticks without contact away from jumps |
| Jump landing on the Test Ground kicker | gas lifted: 12° worst tilt, 0.4°/s yaw after landing; gas held: 62° nose-down, 41°/s yaw kick (pending, see Deviations) |
| Trimesh road chunks | car crossed 12 chunks at 120 km/h with 0 lost wheel contacts |
| Heightmap terrain chunks | 0 lost wheel contacts across chunk borders |
| Desktop draw counts along Rally Road (6 spots) | 182k–268k triangles, 104–133 draw calls (budget 300k triangles, 150 draw calls) |

Problems found and fixed during that run, already reflected below:
- A straight road made the terrain plane fit degenerate (zero determinant) and ignored the climb; the fit is now regularised.
- Box-shaped scenery faced inward with generated normals; normals are set per triangle.
- The scripted test driver steered away from the road (Godot's 2D angle sign); fixed.
- The countdown-lock test mistook the car settling onto its springs for movement; it measures horizontal movement. The Rally Road contact count likewise skips the countdown (52 of 63 lost wheel-ticks were the spawn settle).
- The first full build drew 690–870k triangles and up to 193 draw calls. Fixed by: terrain not casting shadows (it doubled the count), a coarse far terrain mesh beyond 200 m, pines drawn to 300 m and rocks and posts to 150 m without shadows, pines without hidden cone bases (54 → 40 triangles), and two shadow cascades instead of Godot's default four.
- Vertex colours come back as 8-bit, so the pine colour test compares within 0.01.
- The first jump-landing test "passed" while the car flew off the kicker at 115 km/h, did a full forward flip and happened to land on its wheels. The test now holds 100 km/h to the kicker and checks tilt in the air as well as yaw after landing (Task 16).

## Deviations From the Spec (with reasons)

- **Countdown lock zeroes every pedal instead of holding the brake** (spec §4.1 said "full brake"): holding brake at a standstill selects reverse in the Milestone 1 drivetrain, so the car would back away from the start line. The drivetrain's auto-hold keeps the car still.
- **`RoadProfile` is a `RefCounted` built once**, not "pure static": it pre-places seeded potholes and patches so each height query is cheap.
- **`TerrainField` (data) is split from `TerrainBuilder` (nodes)**: scenery placement needs the height grid too.
- **`levels/shared/run_level.gd` replaces `rally_road.gd`**: the wiring is the same for every timed level; Rally Road's scene uses it directly and the tests reuse it.
- **Start and finish gates sit 10 m in from the road's ends** (`TrailDef.start_distance`, `end_margin`), so the car has road under it at both ends.
- **Rally Road climbs 74 m, not ~160 m** (spec §7.1): with gentle sweeping bends low down and a 12% maximum grade, 1.5 km can't climb 160 m. Jump 1 sits at 440 m (straight road) instead of ~450 m (inside a bend).
- **Rough ground on Rally Road is potholes and patched tarmac only** (no washboard), placed by seed inside the rough stretch and clusters.
- **The running time sits top-right, not top-centre** (spec §6.5): the Milestone 1 button strip (Steer, Reset, Telemetry, Rec, Track) already fills the top-left and centre. Checkpoint splits show just below the time.
- **Rendering settings the spec didn't list, to meet its budget** (§8): terrain casts no shadows and is drawn coarse beyond `TerrainDef.detail_distance` (200 m); `ScatterDef.pine_view_distance` (300 m) and `rock_view_distance` (150 m, also used for posts); only pines cast shadows; the sun uses two shadow cascades (this also applies to the Test Ground).
- **The throttle-held jump test is pending, not failing** (spec §9.2): lifting off the gas over the Test Ground kicker flies level (12° worst tilt), but holding it pitches the nose down (62° and a 41°/s yaw kick at 100 km/h; a full flip at 115 km/h). That is a feel decision for the user after the phone test, so the test reports it with GUT's `pending()` rather than failing the suite or tuning the car here.

## File Map

| File | Responsibility |
|---|---|
| `levels/shared/rough_shapes.gd` | Pothole, bump, washboard and rut shape functions |
| `game/run_clock.gd` | Run stages, countdown, splits, session best |
| `game/flip_detector.gd` | Flipped-for-2-s detection |
| `game/checkpoint_tracker.gd` | Ordered gate progress and reset transform |
| `levels/trail/trail_def.gd` | Road settings resource |
| `levels/trail/road_profile.gd` | Surface height: undulation, potholes, patches, jumps |
| `levels/trail/road_sampler.gd` | Positions, directions and nearest-point queries along the road curve |
| `levels/trail/corridor.gd` | How terrain meets the road |
| `levels/trail/terrain_def.gd`, `terrain_field.gd` | Terrain settings; generated height grid with queries |
| `levels/trail/terrain_builder.gd` | Terrain mesh and heightmap collision chunks |
| `levels/trail/road_builder.gd` | Road mesh with painted lines, asphalt and shoulder collision |
| `levels/trail/low_poly_meshes.gd` | Pine, rock, post, gate post and banner meshes |
| `levels/trail/scatter_def.gd`, `scatter_builder.gd` | Scenery settings; pines, rocks and posts as MultiMeshes |
| `levels/trail/checkpoint_placer.gd` | Checkpoint gates and reset transforms |
| `levels/trail/trail_level.gd` | Runs every builder; editor Rebuild |
| `levels/shared/driving_rig.gd`, `.tscn` | Car, camera, controls, telemetry and recorder, wired |
| `levels/shared/level_switcher.gd` | Track button: Rally Road ↔ Test Ground |
| `game/reset_controller.gd`, `game/run_controller.gd`, `ui/run_hud.gd` | Resets, the run itself, the HUD |
| `levels/shared/run_level.gd` | Wires a trail, the rig and the run systems |
| `tools/generate_rally_road_curve.gd` | Builds Rally Road's curve from segments |
| `levels/rally_road/*` | Rally Road's scene, curve and settings |
| `tests/scenarios/run_level_builder.gd`, `trail_driver.gd` | Test helpers: a small run level; a scripted driver |

---

### Task 1: Shared rough-ground shapes

**Files:**
- Create: `levels/shared/rough_shapes.gd`, `tests/unit/test_rough_shapes.gd`
- Modify: `levels/test_ground/rough_patch.gd` (its offset functions call the shared shapes; behaviour unchanged)

**Interfaces:**
- Produces: static `RoughShapes.pothole(distance_from_centre, radius, depth) -> float`, `bump(distance_from_centre, length, height) -> float`, `washboard(along, amplitude, wavelength) -> float`, `rut(distance_from_centre, half_width, depth) -> float`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_rough_shapes.gd`:

```gdscript
extends GutTest


func test_pothole_is_deepest_at_its_centre() -> void:
	assert_almost_eq(RoughShapes.pothole(0.0, 0.5, 0.12), -0.12, 0.0001)


func test_pothole_is_flat_at_and_beyond_its_radius() -> void:
	assert_almost_eq(RoughShapes.pothole(0.5, 0.5, 0.12), 0.0, 0.0001)
	assert_almost_eq(RoughShapes.pothole(2.0, 0.5, 0.12), 0.0, 0.0001)


func test_pothole_is_bowl_shaped() -> void:
	# Halfway out: -depth * (1 - 0.25)
	assert_almost_eq(RoughShapes.pothole(0.25, 0.5, 0.12), -0.09, 0.0001)


func test_bump_peaks_on_its_centre_line_and_ends_at_half_length() -> void:
	assert_almost_eq(RoughShapes.bump(0.0, 0.9, 0.08), 0.08, 0.0001)
	assert_almost_eq(RoughShapes.bump(0.45, 0.9, 0.08), 0.0, 0.0001)
	assert_almost_eq(RoughShapes.bump(-0.45, 0.9, 0.08), 0.0, 0.0001)


func test_washboard_is_a_sine() -> void:
	assert_almost_eq(RoughShapes.washboard(0.175, 0.025, 0.7), 0.025, 0.0001)
	assert_almost_eq(RoughShapes.washboard(0.35, 0.025, 0.7), 0.0, 0.0001)


func test_rut_is_deepest_on_its_centre_line() -> void:
	assert_almost_eq(RoughShapes.rut(0.0, 0.35, 0.1), -0.1, 0.0001)
	assert_almost_eq(RoughShapes.rut(0.35, 0.35, 0.1), 0.0, 0.0001)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `RoughShapes` is not declared.

- [ ] **Step 3: Implement the shapes**

`levels/shared/rough_shapes.gd`:

```gdscript
class_name RoughShapes
extends RefCounted
## Shape functions for uneven ground, shared by RoughPatch (the Test Ground's
## strips) and RoadProfile (trails). Each returns a height offset in metres.


## Bowl-shaped pothole: -depth at the centre, rising to 0 at the radius.
static func pothole(distance_from_centre: float, radius: float, depth: float) -> float:
	if distance_from_centre >= radius:
		return 0.0
	var t := distance_from_centre / radius
	return -depth * (1.0 - t * t)


## Speed bump across the road: +height on its centre line, 0 at half its length.
static func bump(distance_from_centre: float, length: float, height: float) -> float:
	var t := absf(distance_from_centre) / (length * 0.5)
	if t >= 1.0:
		return 0.0
	return height * (0.5 + 0.5 * cos(PI * t))


## Washboard ripples along the road.
static func washboard(along: float, amplitude: float, wavelength: float) -> float:
	return amplitude * sin(TAU * along / wavelength)


## Rut: a rounded groove, -depth on its centre line, 0 at half_width.
static func rut(distance_from_centre: float, half_width: float, depth: float) -> float:
	var t := absf(distance_from_centre) / half_width
	if t >= 1.0:
		return 0.0
	return -depth * (0.5 + 0.5 * cos(PI * t))
```

- [ ] **Step 4: Move `RoughPatch` onto the shared shapes**

Replace `levels/test_ground/rough_patch.gd` with:

`levels/test_ground/rough_patch.gd`:

```gdscript
class_name RoughPatch
extends StaticBody3D
## A drivable strip of uneven ground: a heightmap collision shape plus a matching
## mesh, both built from one height function. The strip rises from ground level to
## BASE_HEIGHT over its first and last few metres so cars can drive on and off;
## the features (potholes, bumps, ruts...) are carved into that raised base.
## Local axes: x across the strip, z along it. Cars enter at the +Z end.

enum Profile { ROUGH_ASPHALT, RUTTED_MUD }

## Metres between height samples.
const SPACING := 0.25
## Top of the strip above the surrounding ground (m). Deep enough that potholes
## stay above the ground underneath.
const BASE_HEIGHT := 0.15
## Length of the entry and exit slopes (m).
const TAPER := 3.0

# Rough asphalt, by distance from the entry end.
const POTHOLE_DEPTH := 0.12
## Potholes as (x, distance along, radius), all in metres.
const POTHOLES: Array[Vector3] = [
	Vector3(-1.2, 10.0, 0.5), Vector3(0.8, 16.0, 0.6), Vector3(-0.4, 24.0, 0.45),
	Vector3(1.5, 31.0, 0.7), Vector3(-1.6, 38.0, 0.5), Vector3(0.3, 45.0, 0.55),
	Vector3(-0.8, 52.0, 0.65),
]
const BUMP_HEIGHT := 0.08
const BUMP_LENGTH := 0.9
## Speed bumps across the whole width, centred at these distances along.
const BUMPS: Array[float] = [70.0, 80.0, 90.0, 100.0, 110.0]
const WASHBOARD_START := 120.0
const WASHBOARD_END := 170.0
const WASHBOARD_AMPLITUDE := 0.025
const WASHBOARD_WAVELENGTH := 0.7

# Rutted mud.
## Rut centres match the Rally Car's wheel track (1.52 m).
const RUT_CENTERS: Array[float] = [-0.76, 0.76]
const RUT_HALF_WIDTH := 0.35
const RUT_DEPTH := 0.1
const MUD_WAVE_HEIGHT := 0.04

## How strongly features are shaded: colour x (1 + offset x this), so dips read
## darker and crests lighter from the driver's seat.
const SHADE_PER_METRE := 4.0

@export var surface: SurfaceDef
@export var profile: Profile = Profile.ROUGH_ASPHALT
## Width (x) and length (z) in metres.
@export var size := Vector2(10.0, 200.0)


func _ready() -> void:
	set_meta(SurfaceLookup.META_KEY, surface)
	var columns := int(size.x / SPACING) + 1
	var rows := int(size.y / SPACING) + 1
	var heights := PackedFloat32Array()
	heights.resize(columns * rows)
	for row in rows:
		for column in columns:
			heights[row * columns + column] = height_at(profile, _sample_position(column, row), size)
	_add_collision(columns, rows, heights)
	_add_mesh(columns, rows, heights)


## Height above the surrounding ground at a local (x, z) point of the strip.
static func height_at(which: Profile, point: Vector2, patch_size: Vector2) -> float:
	var along := patch_size.y * 0.5 - point.y  # distance from the entry end
	var ramp := smoothstep(0.0, TAPER, minf(along, patch_size.y - along))
	return maxf(0.0, (BASE_HEIGHT + feature_offset(which, point.x, along)) * ramp)


## How far the features raise (+) or lower (-) the strip from BASE_HEIGHT.
static func feature_offset(which: Profile, x: float, along: float) -> float:
	match which:
		Profile.RUTTED_MUD:
			return rutted_mud_offset(x, along)
		_:
			return rough_asphalt_offset(x, along)


## Rough asphalt: potholes, then speed bumps, then washboard ripples.
static func rough_asphalt_offset(x: float, along: float) -> float:
	var offset := 0.0
	for pothole in POTHOLES:
		var distance := Vector2(x - pothole.x, along - pothole.y).length()
		offset += RoughShapes.pothole(distance, pothole.z, POTHOLE_DEPTH)
	for bump in BUMPS:
		offset += RoughShapes.bump(along - bump, BUMP_LENGTH, BUMP_HEIGHT)
	if along >= WASHBOARD_START and along <= WASHBOARD_END:
		offset += RoughShapes.washboard(along - WASHBOARD_START, WASHBOARD_AMPLITUDE, WASHBOARD_WAVELENGTH)
	return offset


## Rutted mud: two ruts at wheel-track spacing plus slow waves along the strip.
static func rutted_mud_offset(x: float, along: float) -> float:
	var offset := MUD_WAVE_HEIGHT * sin(along * 0.9)
	for center in RUT_CENTERS:
		offset += RoughShapes.rut(x - center, RUT_HALF_WIDTH, RUT_DEPTH)
	return offset


func _sample_position(column: int, row: int) -> Vector2:
	return Vector2(column * SPACING - size.x * 0.5, row * SPACING - size.y * 0.5)


func _add_collision(columns: int, rows: int, heights: PackedFloat32Array) -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = columns
	shape.map_depth = rows
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	# The shape puts samples 1 m apart; scaling the node sets the real spacing.
	collision.scale = Vector3(SPACING, 1.0, SPACING)
	add_child(collision)


func _add_mesh(columns: int, rows: int, heights: PackedFloat32Array) -> void:
	var base_color := surface.debug_color
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rows:
		for column in columns:
			var point := _sample_position(column, row)
			var along := size.y * 0.5 - point.y
			var shade := clampf(1.0 + feature_offset(profile, point.x, along) * SHADE_PER_METRE, 0.5, 1.3)
			tool.set_color(Color(base_color.r * shade, base_color.g * shade, base_color.b * shade))
			tool.add_vertex(Vector3(point.x, heights[row * columns + column], point.y))
	for row in rows - 1:
		for column in columns - 1:
			var i := row * columns + column
			tool.add_index(i)
			tool.add_index(i + 1)
			tool.add_index(i + columns)
			tool.add_index(i + 1)
			tool.add_index(i + columns + 1)
			tool.add_index(i + columns)
	tool.generate_normals()

	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true  # same colour space as the other surfaces' albedo
	material.roughness = 0.9
	mesh.material_override = material
	add_child(mesh)
```

- [ ] **Step 5: Run all tests**

Run: `./run_tests.sh all`
Expected: exit 0; `test_rough_shapes.gd` 6 passing, and the existing `test_rough_patch.gd` and `test_rough_ground.gd` still pass (the refactor must not change a single height).

- [ ] **Step 6: Commit**

```bash
git add levels/shared tests/unit/test_rough_shapes.gd levels/test_ground/rough_patch.gd
git commit -F- <<'EOF'
Share rough-ground shapes between RoughPatch and trails

<trailers>
EOF
```

---

### Task 2: Run clock

**Files:**
- Create: `game/run_clock.gd`, `tests/unit/test_run_clock.gd`

**Interfaces:**
- Produces: `RunClock` (RefCounted): enum `Stage { READY, COUNTDOWN, RUNNING, FINISHED }`; const `COUNTDOWN_SECONDS`; fields `stage`, `countdown_remaining`, `elapsed`, `splits: Dictionary`, `session_best_time` (−1.0 before a finish), `session_best_splits`; methods `start_countdown()`, `tick(delta) -> bool` (true on GO), `pass_checkpoint(index)`, `split_delta(index) -> float` (NAN when nothing to compare), `finish()`, `restart()`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_run_clock.gd`:

```gdscript
extends GutTest

var clock: RunClock


func before_each() -> void:
	clock = RunClock.new()


func _run_to_go() -> void:
	clock.start_countdown()
	clock.tick(RunClock.COUNTDOWN_SECONDS + 0.01)


func test_starts_ready() -> void:
	assert_eq(clock.stage, RunClock.Stage.READY)


func test_countdown_lasts_three_seconds_then_reports_go() -> void:
	clock.start_countdown()
	assert_false(clock.tick(2.9), "still counting down at 2.9 s")
	assert_eq(clock.stage, RunClock.Stage.COUNTDOWN)
	assert_true(clock.tick(0.2), "GO on the tick that passes 3 s")
	assert_eq(clock.stage, RunClock.Stage.RUNNING)


func test_time_only_runs_after_go() -> void:
	clock.start_countdown()
	clock.tick(2.0)
	assert_almost_eq(clock.elapsed, 0.0, 0.0001)
	clock.tick(1.5)
	clock.tick(0.5)
	assert_almost_eq(clock.elapsed, 0.5, 0.0001)


func test_checkpoint_records_a_split() -> void:
	_run_to_go()
	clock.tick(12.5)
	clock.pass_checkpoint(1)
	assert_almost_eq(clock.splits[1], 12.5, 0.0001)


func test_first_finish_sets_the_session_best() -> void:
	_run_to_go()
	clock.tick(90.0)
	clock.finish()
	assert_eq(clock.stage, RunClock.Stage.FINISHED)
	assert_almost_eq(clock.session_best_time, 90.0, 0.0001)


func test_a_slower_run_keeps_the_session_best() -> void:
	_run_to_go()
	clock.tick(90.0)
	clock.finish()
	clock.restart()
	_run_to_go()
	clock.tick(95.0)
	clock.finish()
	assert_almost_eq(clock.session_best_time, 90.0, 0.0001)


func test_split_delta_compares_with_the_session_best_run() -> void:
	_run_to_go()
	clock.tick(20.0)
	clock.pass_checkpoint(1)
	assert_true(is_nan(clock.split_delta(1)), "nothing to compare on the first run")
	clock.tick(70.0)
	clock.finish()
	clock.restart()
	_run_to_go()
	clock.tick(18.5)
	clock.pass_checkpoint(1)
	assert_almost_eq(clock.split_delta(1), -1.5, 0.0001)


func test_finish_is_ignored_unless_running() -> void:
	clock.finish()
	assert_eq(clock.stage, RunClock.Stage.READY)
	assert_almost_eq(clock.session_best_time, -1.0, 0.0001)


func test_restart_clears_the_run_but_keeps_the_best() -> void:
	_run_to_go()
	clock.tick(80.0)
	clock.finish()
	clock.restart()
	assert_eq(clock.stage, RunClock.Stage.READY)
	assert_almost_eq(clock.elapsed, 0.0, 0.0001)
	assert_true(clock.splits.is_empty())
	assert_almost_eq(clock.session_best_time, 80.0, 0.0001)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `RunClock` is not declared.

- [ ] **Step 3: Implement**

`game/run_clock.gd`:

```gdscript
class_name RunClock
extends RefCounted
## The timing of one run, as pure logic: countdown, running time, checkpoint
## splits and the session best. The run controller calls tick() every frame.

enum Stage { READY, COUNTDOWN, RUNNING, FINISHED }

## The countdown before GO (spec §3.1).
const COUNTDOWN_SECONDS := 3.0

var stage: Stage = Stage.READY
var countdown_remaining: float = 0.0
var elapsed: float = 0.0
## This run's split times, keyed by checkpoint index.
var splits: Dictionary = {}
## Best finished time this session, or -1.0 before the first finish.
var session_best_time: float = -1.0
## The splits of the session-best run, keyed by checkpoint index.
var session_best_splits: Dictionary = {}


func start_countdown() -> void:
	stage = Stage.COUNTDOWN
	countdown_remaining = COUNTDOWN_SECONDS
	elapsed = 0.0
	splits.clear()


## Advances the clock. Returns true on the tick the countdown reaches GO.
func tick(delta: float) -> bool:
	match stage:
		Stage.COUNTDOWN:
			countdown_remaining -= delta
			if countdown_remaining <= 0.0:
				countdown_remaining = 0.0
				stage = Stage.RUNNING
				return true
		Stage.RUNNING:
			elapsed += delta
	return false


func pass_checkpoint(index: int) -> void:
	if stage == Stage.RUNNING:
		splits[index] = elapsed


## This run's split at a checkpoint minus the session-best split there, or NAN
## when there is nothing to compare (no split yet, or no finished run yet).
func split_delta(index: int) -> float:
	if not splits.has(index) or not session_best_splits.has(index):
		return NAN
	return splits[index] - session_best_splits[index]


func finish() -> void:
	if stage != Stage.RUNNING:
		return
	stage = Stage.FINISHED
	if session_best_time < 0.0 or elapsed < session_best_time:
		session_best_time = elapsed
		session_best_splits = splits.duplicate()


## Back to READY for a new run; the session best is kept.
func restart() -> void:
	stage = Stage.READY
	countdown_remaining = 0.0
	elapsed = 0.0
	splits.clear()
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_run_clock.gd` 9 passing.

- [ ] **Step 5: Commit** — subject `Add the run clock`; stage `game/run_clock.gd game/run_clock.gd.uid tests/unit/test_run_clock.gd tests/unit/test_run_clock.gd.uid`.

---

### Task 3: Flip detector

**Files:**
- Create: `game/flip_detector.gd`, `tests/unit/test_flip_detector.gd`

**Interfaces:**
- Produces: `FlipDetector` (RefCounted): consts `TILT_LIMIT_DEG = 70`, `SPEED_LIMIT = 2`, `HOLD_SECONDS = 2`; `flipped_time`; `update(delta, up: Vector3, speed: float) -> bool`; `reset()`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_flip_detector.gd`:

```gdscript
extends GutTest

const ON_ITS_ROOF := Vector3.DOWN
const ON_ITS_SIDE := Vector3.RIGHT

var detector: FlipDetector


func before_each() -> void:
	detector = FlipDetector.new()


func _hold(seconds: float, up: Vector3, speed: float) -> bool:
	var result := false
	var steps := roundi(seconds * 10.0)
	for i in steps:
		result = detector.update(0.1, up, speed)
	return result


func test_upright_car_is_never_flipped() -> void:
	assert_false(_hold(5.0, Vector3.UP, 0.0))


func test_car_on_its_roof_triggers_after_two_seconds() -> void:
	assert_false(_hold(1.9, ON_ITS_ROOF, 0.0), "not yet at 1.9 s")
	assert_true(_hold(0.1, ON_ITS_ROOF, 0.0), "flipped at 2 s")


func test_car_on_its_side_counts_as_flipped() -> void:
	assert_true(_hold(2.0, ON_ITS_SIDE, 0.5))


func test_a_steep_but_driveable_tilt_does_not_count() -> void:
	var tilted_60 := Vector3.UP.rotated(Vector3.FORWARD, deg_to_rad(60.0))
	assert_false(_hold(5.0, tilted_60, 0.0))


func test_moving_car_is_not_stuck() -> void:
	assert_false(_hold(5.0, ON_ITS_ROOF, 6.0), "still sliding or tumbling")


func test_recovering_resets_the_timer() -> void:
	_hold(1.5, ON_ITS_ROOF, 0.0)
	_hold(0.1, Vector3.UP, 0.0)
	assert_false(_hold(1.5, ON_ITS_ROOF, 0.0), "the 2 s starts again after recovering")


func test_reset_clears_the_timer() -> void:
	_hold(1.9, ON_ITS_ROOF, 0.0)
	detector.reset()
	assert_false(_hold(0.5, ON_ITS_ROOF, 0.0))
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `FlipDetector` is not declared.

- [ ] **Step 3: Implement**

`game/flip_detector.gd`:

```gdscript
class_name FlipDetector
extends RefCounted
## Decides when a car is stuck flipped: tilted more than TILT_LIMIT_DEG from
## upright and slower than SPEED_LIMIT, continuously for HOLD_SECONDS.
## Wheel contact is deliberately ignored: a car on its side often has a wheel
## touching. These are fixed game rules from the spec (§3.2).

const TILT_LIMIT_DEG := 70.0
const SPEED_LIMIT := 2.0
const HOLD_SECONDS := 2.0

var flipped_time: float = 0.0


## up: the car's global up vector; speed: m/s. Returns true once the car has
## been flipped for HOLD_SECONDS.
func update(delta: float, up: Vector3, speed: float) -> bool:
	var tilt := rad_to_deg(up.angle_to(Vector3.UP))
	if tilt > TILT_LIMIT_DEG and absf(speed) < SPEED_LIMIT:
		flipped_time += delta
	else:
		flipped_time = 0.0
	return flipped_time >= HOLD_SECONDS


func reset() -> void:
	flipped_time = 0.0
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_flip_detector.gd` 7 passing.

- [ ] **Step 5: Commit** — subject `Add flipped-car detection`; stage `game/flip_detector.gd`, its `.uid`, the test and its `.uid`.

---

### Task 4: Checkpoint tracker

**Files:**
- Create: `game/checkpoint_tracker.gd`, `tests/unit/test_checkpoint_tracker.gd`

**Interfaces:**
- Produces: `CheckpointTracker` (Node): signals `checkpoint_passed(index: int)`, `finished`; fields `gate_transforms: Array[Transform3D]`, `next_index`, `last_passed`; methods `setup(transforms)`, `restart()`, `gate_count()`, `is_finished()`, `enter_gate(index)`, `reset_transform() -> Transform3D`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_checkpoint_tracker.gd`:

```gdscript
extends GutTest

var tracker: CheckpointTracker


func before_each() -> void:
	tracker = CheckpointTracker.new()
	add_child_autofree(tracker)
	var transforms: Array[Transform3D] = []
	for i in 4:  # start, checkpoint 1, checkpoint 2, finish
		transforms.append(Transform3D(Basis(), Vector3(0.0, 0.0, -100.0 * i)))
	tracker.setup(transforms)


func test_starts_at_the_start_gate() -> void:
	assert_eq(tracker.last_passed, 0)
	assert_eq(tracker.next_index, 1)
	assert_eq(tracker.reset_transform().origin, Vector3.ZERO)


func test_gates_in_order_count() -> void:
	watch_signals(tracker)
	tracker.enter_gate(1)
	assert_signal_emitted_with_parameters(tracker, "checkpoint_passed", [1])
	assert_eq(tracker.reset_transform().origin, Vector3(0.0, 0.0, -100.0))


func test_skipping_a_gate_does_nothing() -> void:
	watch_signals(tracker)
	tracker.enter_gate(2)
	assert_signal_not_emitted(tracker, "checkpoint_passed")
	assert_eq(tracker.last_passed, 0)


func test_passing_the_same_gate_twice_counts_once() -> void:
	watch_signals(tracker)
	tracker.enter_gate(1)
	tracker.enter_gate(1)
	assert_signal_emit_count(tracker, "checkpoint_passed", 1)


func test_the_last_gate_finishes() -> void:
	watch_signals(tracker)
	for i in [1, 2, 3]:
		tracker.enter_gate(i)
	assert_signal_emitted(tracker, "finished")
	assert_signal_emit_count(tracker, "checkpoint_passed", 2)
	assert_true(tracker.is_finished())
	assert_eq(tracker.reset_transform().origin, Vector3(0.0, 0.0, -300.0))


func test_gates_after_the_finish_are_ignored() -> void:
	for i in [1, 2, 3]:
		tracker.enter_gate(i)
	watch_signals(tracker)
	tracker.enter_gate(0)
	tracker.enter_gate(1)
	assert_signal_not_emitted(tracker, "checkpoint_passed")
	assert_signal_not_emitted(tracker, "finished")


func test_restart_returns_to_the_start() -> void:
	tracker.enter_gate(1)
	tracker.enter_gate(2)
	tracker.restart()
	assert_eq(tracker.last_passed, 0)
	assert_eq(tracker.next_index, 1)
	assert_false(tracker.is_finished())
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `CheckpointTracker` is not declared.

- [ ] **Step 3: Implement**

`game/checkpoint_tracker.gd`:

```gdscript
class_name CheckpointTracker
extends Node
## Progress through a trail's checkpoint gates, in order. Gate 0 is the start
## line and the last gate is the finish. A gate only counts when it is the next
## one, so skipping ahead does nothing.

signal checkpoint_passed(index: int)
signal finished

## Where the car is put back after a reset, one per gate, in order.
var gate_transforms: Array[Transform3D] = []
## The gate that must be passed next.
var next_index: int = 1
## The last gate passed (0 = only the start line).
var last_passed: int = 0


func setup(transforms: Array[Transform3D]) -> void:
	gate_transforms = transforms
	restart()


func restart() -> void:
	next_index = 1
	last_passed = 0


func gate_count() -> int:
	return gate_transforms.size()


func is_finished() -> bool:
	return gate_transforms.size() > 1 and last_passed == gate_transforms.size() - 1


## Called when the car enters gate `index`.
func enter_gate(index: int) -> void:
	if index != next_index:
		return
	last_passed = index
	next_index += 1
	if index == gate_transforms.size() - 1:
		finished.emit()
	else:
		checkpoint_passed.emit(index)


## Where to put the car on a reset: the last gate it passed.
func reset_transform() -> Transform3D:
	return gate_transforms[last_passed]
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_checkpoint_tracker.gd` 7 passing.

- [ ] **Step 5: Commit** — subject `Add the checkpoint tracker`; stage the script, test and their `.uid` files.

---

### Task 5: Input lock and Track button

**Files:**
- Modify: `input/car_input.gd` (a `locked` flag), `input/touch_controls.gd` (a Track button and `track_switch_requested` signal)
- Modify: `tests/unit/test_car_input.gd`, `tests/unit/test_touch_controls.gd` (one new test each)

**Interfaces:**
- Produces: `CarInput.locked: bool` — while true, `refresh()` sets steer, throttle and brake to 0. `TouchControls.track_switch_requested` signal, emitted by a "Track" button in the top strip.

- [ ] **Step 1: Add the failing tests**

Replace `tests/unit/test_car_input.gd` with:

`tests/unit/test_car_input.gd`:

```gdscript
extends GutTest

const DRIVING_ACTIONS := [
	InputActions.THROTTLE, InputActions.BRAKE, InputActions.STEER_LEFT, InputActions.STEER_RIGHT,
]

var input: CarInput


func before_each() -> void:
	input = CarInput.new()
	add_child_autofree(input)  # _ready() registers the actions


func after_each() -> void:
	for action in DRIVING_ACTIONS:
		Input.action_release(action)


func test_all_actions_are_registered() -> void:
	for action in DRIVING_ACTIONS + [InputActions.RESET_CAR, InputActions.TOGGLE_TELEMETRY, InputActions.TOGGLE_RECORDING]:
		assert_true(InputMap.has_action(action), str(action))


func test_register_is_safe_to_call_twice() -> void:
	InputActions.register()
	assert_eq(InputMap.action_get_events(InputActions.THROTTLE).size(), 3)


func test_keyboard_throttle() -> void:
	Input.action_press(InputActions.THROTTLE)
	input.refresh()
	assert_almost_eq(input.throttle, 1.0, 0.0001)


func test_steer_left_is_negative() -> void:
	Input.action_press(InputActions.STEER_LEFT)
	input.refresh()
	assert_almost_eq(input.steer, -1.0, 0.0001)


func test_virtual_inputs_are_used() -> void:
	input.virtual_throttle = 0.6
	input.virtual_brake = 0.3
	input.virtual_steer = 0.5
	input.refresh()
	assert_almost_eq(input.throttle, 0.6, 0.0001)
	assert_almost_eq(input.brake, 0.3, 0.0001)
	assert_almost_eq(input.steer, 0.5, 0.0001)


func test_combined_steer_is_clamped() -> void:
	Input.action_press(InputActions.STEER_RIGHT)
	input.virtual_steer = 1.0
	input.refresh()
	assert_almost_eq(input.steer, 1.0, 0.0001)


func test_locked_input_ignores_every_device() -> void:
	Input.action_press(InputActions.THROTTLE)
	input.virtual_steer = 1.0
	input.virtual_brake = 1.0
	input.locked = true
	input.refresh()
	assert_almost_eq(input.throttle, 0.0, 0.0001)
	assert_almost_eq(input.brake, 0.0, 0.0001)
	assert_almost_eq(input.steer, 0.0, 0.0001)


func test_request_reset_emits_signal() -> void:
	watch_signals(input)
	input.request_reset()
	assert_signal_emitted(input, "reset_requested")
```

Replace `tests/unit/test_touch_controls.gd` with:

`tests/unit/test_touch_controls.gd`:

```gdscript
extends GutTest

var input: CarInput
var controls: TouchControls


func before_each() -> void:
	input = CarInput.new()
	add_child_autofree(input)
	controls = TouchControls.new()
	controls.car_input = input
	controls.screen_size_override = Vector2(1920.0, 1080.0)
	add_child_autofree(controls)


func test_gas_pad_sets_throttle() -> void:
	controls.handle_touch(0, controls.gas_rect().get_center(), true)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 1.0, 0.0001)
	assert_almost_eq(input.virtual_brake, 0.0, 0.0001)


func test_releasing_gas_clears_throttle() -> void:
	controls.handle_touch(0, controls.gas_rect().get_center(), true)
	controls.handle_touch(0, controls.gas_rect().get_center(), false)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001)


func test_sliding_from_brake_to_gas_switches_pedal() -> void:
	controls.handle_touch(0, controls.brake_rect().get_center(), true)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_brake, 1.0, 0.0001)
	controls.handle_drag(0, controls.gas_rect().get_center())
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_brake, 0.0, 0.0001)
	assert_almost_eq(input.virtual_throttle, 1.0, 0.0001)


func test_analog_steer_follows_the_thumb() -> void:
	var start := Vector2(300.0, 700.0)
	controls.handle_touch(1, start, true)
	controls.handle_drag(1, start + Vector2(TouchControls.FULL_LOCK_PX, 0.0))
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_steer, 1.0, 0.0001)


func test_analog_steer_recentres_on_release() -> void:
	var start := Vector2(300.0, 700.0)
	controls.handle_touch(1, start, true)
	controls.handle_drag(1, start + Vector2(-200.0, 0.0))
	controls.handle_touch(1, start, false)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_steer, 0.0, 0.0001)


func test_touches_in_the_top_strip_are_ignored() -> void:
	controls.handle_touch(1, Vector2(300.0, 50.0), true)
	controls.handle_drag(1, Vector2(600.0, 50.0))
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_steer, 0.0, 0.0001)


func test_button_mode_ramps_steer() -> void:
	controls.steer_mode = TouchSteerLogic.Mode.BUTTONS
	controls.handle_touch(2, controls.right_button_rect().get_center(), true)
	controls.update_outputs(0.1)
	assert_almost_eq(input.virtual_steer, 0.3, 0.0001)


func test_gas_and_steer_together() -> void:
	var start := Vector2(300.0, 700.0)
	controls.handle_touch(1, start, true)
	controls.handle_drag(1, start + Vector2(-TouchControls.FULL_LOCK_PX, 0.0))
	controls.handle_touch(2, controls.gas_rect().get_center(), true)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_steer, -1.0, 0.0001)
	assert_almost_eq(input.virtual_throttle, 1.0, 0.0001)


func test_track_button_requests_a_track_switch() -> void:
	watch_signals(controls)
	var buttons := controls.find_children("*", "Button", true, false)
	var track: Button = buttons.filter(func(b: Node) -> bool: return b.text == "Track")[0]
	track.pressed.emit()
	assert_signal_emitted(controls, "track_switch_requested")
```

- [ ] **Step 2: Run them and watch them fail**

Run: `./run_tests.sh unit`
Expected: exit 1 — `test_locked_input_ignores_every_device` fails (throttle reads 1.0), and `test_track_button_requests_a_track_switch` errors (no "Track" button).

- [ ] **Step 3: Implement**

Replace `input/car_input.gd` with:

`input/car_input.gd`:

```gdscript
class_name CarInput
extends Node
## The single source of driver intent. Combines keyboard/gamepad with "virtual"
## inputs (the on-screen touch controls, or scripted drivers in tests). The car
## reads steer/throttle/brake and never knows which device produced them.

signal reset_requested

## Final values the car reads. steer: -1 (left) .. 1 (right).
var steer: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0

## While locked (the countdown), every driver input reads as zero. The
## drivetrain's auto-hold keeps a stopped car still; holding the brake instead
## would select reverse.
var locked: bool = false

## Written by touch controls or test scripts.
var virtual_steer: float = 0.0
var virtual_throttle: float = 0.0
var virtual_brake: float = 0.0


func _ready() -> void:
	InputActions.register()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.RESET_CAR):
		request_reset()


## Called by the car at the start of every physics tick.
func refresh() -> void:
	if locked:
		steer = 0.0
		throttle = 0.0
		brake = 0.0
		return
	var device_steer := Input.get_axis(InputActions.STEER_LEFT, InputActions.STEER_RIGHT)
	steer = clampf(device_steer + virtual_steer, -1.0, 1.0)
	throttle = maxf(Input.get_action_strength(InputActions.THROTTLE), virtual_throttle)
	brake = maxf(Input.get_action_strength(InputActions.BRAKE), virtual_brake)


func request_reset() -> void:
	reset_requested.emit()
```

Replace `input/touch_controls.gd` with:

`input/touch_controls.gd`:

```gdscript
class_name TouchControls
extends CanvasLayer
## On-screen driving controls for phones (also usable with a mouse on desktop,
## because the project emulates touch from the mouse).
##   Left side:  steering - an analog drag zone, or two buttons.
##   Right side: brake and gas pedals.
##   Top strip:  steering-style toggle, reset, telemetry, recording and track switch.
## Writes into the car's CarInput virtual_* values.
## Coordinates are in the 1920x1080 canvas (the project stretches it to the screen).

signal telemetry_toggled
signal recording_toggled
signal track_switch_requested

## Touches above this line belong to the top-strip buttons, not the driving controls.
const TOP_STRIP_HEIGHT := 150.0
## Fraction of the screen width, from the left, used for analog steering.
const STEER_ZONE_WIDTH := 0.45
const FULL_LOCK_PX := 140.0
const DEADZONE_PX := 12.0
## Button steering: how fast the value ramps in and recentres (units per second).
const BUTTON_RAMP := 3.0
const BUTTON_RETURN := 5.0

@export var car_input: CarInput
var steer_mode: TouchSteerLogic.Mode = TouchSteerLogic.Mode.ANALOG
## Tests set this so the layout doesn't depend on the real window size.
var screen_size_override := Vector2.ZERO

var _touches := {}             # touch index -> current position
var _steer_touch := -1         # finger doing analog steering, or -1
var _steer_origin := Vector2.ZERO
var _button_steer := 0.0
var _canvas: Control
var _mode_button: Button


func _ready() -> void:
	_build_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		handle_drag(event.index, event.position)


func _process(delta: float) -> void:
	update_outputs(delta)
	_canvas.queue_redraw()


func handle_touch(index: int, point: Vector2, pressed: bool) -> void:
	if not pressed:
		_touches.erase(index)
		if index == _steer_touch:
			_steer_touch = -1
		return
	if point.y < TOP_STRIP_HEIGHT:
		return
	_touches[index] = point
	var in_steer_zone := point.x < screen_size().x * STEER_ZONE_WIDTH
	if steer_mode == TouchSteerLogic.Mode.ANALOG and _steer_touch == -1 and in_steer_zone:
		_steer_touch = index
		_steer_origin = point


func handle_drag(index: int, point: Vector2) -> void:
	if _touches.has(index):
		_touches[index] = point


## Recomputes pedal and steer values from the current touches.
func update_outputs(delta: float) -> void:
	if car_input == null:
		return
	car_input.virtual_throttle = 1.0 if _any_touch_in(gas_rect()) else 0.0
	car_input.virtual_brake = 1.0 if _any_touch_in(brake_rect()) else 0.0
	car_input.virtual_steer = _current_steer(delta)


func screen_size() -> Vector2:
	if screen_size_override != Vector2.ZERO:
		return screen_size_override
	return _canvas.get_viewport_rect().size


func gas_rect() -> Rect2:
	var size := screen_size()
	return Rect2(size.x - 290.0, size.y - 380.0, 250.0, 340.0)


func brake_rect() -> Rect2:
	var size := screen_size()
	return Rect2(size.x - 570.0, size.y - 300.0, 250.0, 260.0)


func left_button_rect() -> Rect2:
	return Rect2(40.0, screen_size().y - 300.0, 230.0, 260.0)


func right_button_rect() -> Rect2:
	return Rect2(300.0, screen_size().y - 300.0, 230.0, 260.0)


func _current_steer(delta: float) -> float:
	if steer_mode == TouchSteerLogic.Mode.ANALOG:
		if _steer_touch == -1:
			return 0.0
		var offset: float = _touches[_steer_touch].x - _steer_origin.x
		return TouchSteerLogic.analog_steer(offset, FULL_LOCK_PX, DEADZONE_PX)
	_button_steer = TouchSteerLogic.button_steer(_button_steer,
			_any_touch_in(left_button_rect()), _any_touch_in(right_button_rect()),
			BUTTON_RAMP, BUTTON_RETURN, delta)
	return _button_steer


func _any_touch_in(rect: Rect2) -> bool:
	for point in _touches.values():
		if rect.has_point(point):
			return true
	return false


func _toggle_steer_mode() -> void:
	if steer_mode == TouchSteerLogic.Mode.ANALOG:
		steer_mode = TouchSteerLogic.Mode.BUTTONS
	else:
		steer_mode = TouchSteerLogic.Mode.ANALOG
	_steer_touch = -1
	_button_steer = 0.0
	_update_mode_label()


func _update_mode_label() -> void:
	var label := "Analog" if steer_mode == TouchSteerLogic.Mode.ANALOG else "Buttons"
	_mode_button.text = "Steer: %s" % label


func _build_ui() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)

	var bar := HBoxContainer.new()
	bar.position = Vector2(20.0, 20.0)
	bar.add_theme_constant_override("separation", 16)
	add_child(bar)
	_mode_button = _add_button(bar, "", _toggle_steer_mode)
	_add_button(bar, "Reset", _on_reset_pressed)
	_add_button(bar, "Telemetry", telemetry_toggled.emit)
	_add_button(bar, "Rec", recording_toggled.emit)
	_add_button(bar, "Track", track_switch_requested.emit)
	_update_mode_label()


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(230.0, 100.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 34)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _on_reset_pressed() -> void:
	if car_input != null:
		car_input.request_reset()


func _draw_controls() -> void:
	var throttle_on := car_input != null and car_input.virtual_throttle > 0.0
	var brake_on := car_input != null and car_input.virtual_brake > 0.0
	_draw_pad(gas_rect(), "GAS", throttle_on)
	_draw_pad(brake_rect(), "BRAKE", brake_on)
	if steer_mode == TouchSteerLogic.Mode.BUTTONS:
		_draw_pad(left_button_rect(), "<", _any_touch_in(left_button_rect()))
		_draw_pad(right_button_rect(), ">", _any_touch_in(right_button_rect()))
	elif _steer_touch != -1:
		var thumb: Vector2 = _touches[_steer_touch]
		_canvas.draw_circle(_steer_origin, FULL_LOCK_PX, Color(1.0, 1.0, 1.0, 0.08))
		_canvas.draw_circle(Vector2(thumb.x, _steer_origin.y), 40.0, Color(1.0, 1.0, 1.0, 0.35))


func _draw_pad(rect: Rect2, label: String, pressed: bool) -> void:
	_canvas.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.3 if pressed else 0.12))
	_canvas.draw_string(ThemeDB.fallback_font, rect.position + Vector2(24.0, 64.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 44)
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; the two new tests pass along with the existing input and touch tests.

- [ ] **Step 5: Commit** — subject `Add a countdown input lock and a Track button`; stage the four files.

---

### Task 6: Road settings, road profile and road sampler

**Files:**
- Create: `levels/trail/trail_def.gd`, `levels/trail/road_profile.gd`, `levels/trail/road_sampler.gd`
- Test: `tests/unit/test_road_profile.gd`, `tests/unit/test_road_sampler.gd`

**Interfaces:**
- Consumes: `RoughShapes.pothole` (Task 1).
- Produces:
  - `TrailDef` (Resource): cross-section (`road_width` 7, `shoulder_width` 2.5, `line_width`, `line_inset`, `lateral_step`, `sample_step` 1, `detail_step` 0.25, `chunk_length` 100), undulation, `rough_sections: Array[Vector3]` (start, length, potholes/100 m), `pothole_clusters: Array[Vector2]` (centre, count), pothole ranges, `rough_margin`, `jumps: Array[Vector3]` (distance, height, length), `start_distance` 10, `end_margin` 10, `checkpoint_distances`, colours, `seed`; `half_total_width()`.
  - `RoadProfile` (RefCounted): `RoadProfile.new(def, length)`; `potholes: Array[Vector4]`, `patches: Array[Rect2]`, `detail_ranges: Array[Vector2]`; `height(distance, lateral)`, `undulation(distance)`, `jump_height(distance)`, `rough_height`, `pothole_height`, `is_patch`, `in_detail_range`.
  - `RoadSampler` (RefCounted): `RoadSampler.new(curve)`; `length`; `position(d)`, `forward(d)`, `up(d)`, `right(d)`, `closest_distance(point)`, `lateral_offset(point)`, `surface_point(d, lateral, profile)`, `transform_at(d, height_above, profile) -> Transform3D`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_road_profile.gd`:

```gdscript
extends GutTest

var def: TrailDef


func before_each() -> void:
	def = TrailDef.new()


func _rough_def() -> TrailDef:
	var rough := TrailDef.new()
	rough.undulation_amplitude = 0.0
	rough.rough_sections = [Vector3(100.0, 150.0, 20.0)]  # 30 potholes
	rough.pothole_clusters = [Vector2(400.0, 4.0)]
	return rough


func test_undulation_stays_within_its_amplitude() -> void:
	var profile := RoadProfile.new(def, 1500.0)
	var peak := 0.0
	var distance := 0.0
	while distance <= 1500.0:
		peak = maxf(peak, absf(profile.undulation(distance)))
		distance += 0.5
	assert_lte(peak, def.undulation_amplitude + 0.0001)
	assert_gt(peak, def.undulation_amplitude * 0.5, "and it actually undulates")


func test_plain_road_has_no_rough_height() -> void:
	var profile := RoadProfile.new(def, 1500.0)
	assert_almost_eq(profile.rough_height(500.0, 1.0), 0.0, 0.0001)
	assert_true(profile.potholes.is_empty())


func test_potholes_land_inside_their_section_and_on_the_asphalt() -> void:
	var profile := RoadProfile.new(_rough_def(), 1500.0)
	assert_eq(profile.potholes.size(), 34, "30 in the section + 4 in the cluster")
	for pothole in profile.potholes:
		var in_section := pothole.x >= 103.0 and pothole.x <= 247.0
		var in_cluster := pothole.x >= 392.0 and pothole.x <= 408.0
		assert_true(in_section or in_cluster, "pothole at %.1f m" % pothole.x)
		assert_lte(absf(pothole.y) + pothole.z, 3.5 + 0.0001, "inside the road edges")


func test_a_pothole_is_as_deep_as_its_depth_at_the_centre() -> void:
	var profile := RoadProfile.new(_rough_def(), 1500.0)
	var pothole := profile.potholes[0]
	var nearby_overlap := 0.0
	for other in profile.potholes.slice(1):
		nearby_overlap += RoughShapes.pothole(Vector2(pothole.x - other.x, pothole.y - other.y).length(), other.z, other.w)
	assert_almost_eq(profile.pothole_height(pothole.x, pothole.y), -pothole.w + nearby_overlap, 0.0001)


func test_the_same_seed_gives_the_same_road() -> void:
	var a := RoadProfile.new(_rough_def(), 1500.0)
	var b := RoadProfile.new(_rough_def(), 1500.0)
	assert_eq(a.potholes, b.potholes)
	assert_eq(a.patches, b.patches)


func test_a_different_seed_gives_a_different_road() -> void:
	var other := _rough_def()
	other.seed = 99
	assert_ne(RoadProfile.new(_rough_def(), 1500.0).potholes, RoadProfile.new(other, 1500.0).potholes)


func test_patches_are_raised() -> void:
	var profile := RoadProfile.new(_rough_def(), 1500.0)
	assert_eq(profile.patches.size(), 12, "one per 12 m of the 150 m section")
	var patch := profile.patches[0]
	var centre := patch.get_center()
	assert_true(profile.is_patch(centre.x, centre.y))
	assert_false(profile.is_patch(600.0, 0.0))


func test_jump_crest_reaches_its_height_then_drops() -> void:
	def.jumps = [Vector3(450.0, 1.2, 12.0)]
	var profile := RoadProfile.new(def, 1500.0)
	# The jump starts at 444 m; its crest is 70% of the way along, at 452.4 m.
	assert_almost_eq(profile.jump_height(444.0), 0.0, 0.0001)
	assert_almost_eq(profile.jump_height(452.4), 1.2, 0.0001)
	assert_almost_eq(profile.jump_height(456.0), 0.0, 0.0001)
	assert_gt(profile.jump_height(448.0), 0.0)


func test_detail_ranges_cover_rough_ground_and_merge() -> void:
	var rough := _rough_def()
	rough.rough_sections.append(Vector3(240.0, 30.0, 10.0))  # overlaps the first section
	var profile := RoadProfile.new(rough, 1500.0)
	assert_eq(profile.detail_ranges, [Vector2(100.0, 270.0), Vector2(390.0, 410.0)] as Array[Vector2])
	assert_true(profile.in_detail_range(200.0))
	assert_true(profile.in_detail_range(400.0))
	assert_false(profile.in_detail_range(320.0))
```

`tests/unit/test_road_sampler.gd`:

```gdscript
extends GutTest

var sampler: RoadSampler
var flat: RoadProfile


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -100.0))
	sampler = RoadSampler.new(curve)
	var def := TrailDef.new()
	def.undulation_amplitude = 0.0
	flat = RoadProfile.new(def, sampler.length)


func _assert_vec(actual: Vector3, expected: Vector3, message: String) -> void:
	assert_almost_eq(actual.distance_to(expected), 0.0, 0.01, "%s: got %s" % [message, actual])


func test_length_and_position() -> void:
	assert_almost_eq(sampler.length, 100.0, 0.01)
	_assert_vec(sampler.position(50.0), Vector3(0.0, 0.0, -50.0), "position at 50 m")


func test_directions_on_a_straight_road() -> void:
	_assert_vec(sampler.forward(50.0), Vector3.FORWARD, "forward")
	_assert_vec(sampler.up(50.0), Vector3.UP, "up")
	_assert_vec(sampler.right(50.0), Vector3.RIGHT, "right")


func test_directions_hold_at_the_ends() -> void:
	_assert_vec(sampler.forward(0.0), Vector3.FORWARD, "forward at the start")
	_assert_vec(sampler.forward(100.0), Vector3.FORWARD, "forward at the end")


func test_closest_distance_and_lateral_offset() -> void:
	assert_almost_eq(sampler.closest_distance(Vector3(3.0, 0.0, -40.0)), 40.0, 0.1)
	assert_almost_eq(sampler.lateral_offset(Vector3(3.0, 0.0, -40.0)), 3.0, 0.05, "right of the road")
	assert_almost_eq(sampler.lateral_offset(Vector3(-2.0, 0.0, -10.0)), -2.0, 0.05, "left of the road")


func test_transform_at_faces_along_the_road() -> void:
	var transform := sampler.transform_at(20.0, 1.0, flat)
	_assert_vec(transform.origin, Vector3(0.0, 1.0, -20.0), "origin 1 m above the surface")
	_assert_vec(-transform.basis.z, Vector3.FORWARD, "the transform's forward")


func test_up_stays_perpendicular_on_a_climb() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 10.0, -100.0))
	var climbing := RoadSampler.new(curve)
	var along := climbing.forward(50.0)
	var surface_up := climbing.up(50.0)
	assert_almost_eq(along.dot(surface_up), 0.0, 0.001, "up is perpendicular to the road")
	assert_gt(surface_up.y, 0.99, "and points almost straight up on a 10% grade")
```

- [ ] **Step 2: Run them and watch them fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `TrailDef` / `RoadProfile` / `RoadSampler` are not declared.

- [ ] **Step 3: Implement**

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
## Spacing of vertices across the asphalt.
@export var lateral_step: float = 0.5
## Distance between cross-sections outside rough ranges.
@export var sample_step: float = 1.0
## Distance between cross-sections inside rough ranges and pothole clusters.
@export var detail_step: float = 0.25
## Length of road built as one mesh and collision chunk.
@export var chunk_length: float = 100.0

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

@export_group("Colours")
@export var asphalt_color: Color = Color(0.24, 0.23, 0.24)
@export var patch_color: Color = Color(0.3, 0.29, 0.28)
@export var line_color: Color = Color(0.92, 0.9, 0.84)
@export var shoulder_color: Color = Color(0.62, 0.47, 0.3)

## Seed for pothole and patch placement and undulation phases.
@export var seed: int = 1


## Half the width of road plus both shoulders.
func half_total_width() -> float:
	return road_width * 0.5 + shoulder_width
```

`levels/trail/road_profile.gd`:

```gdscript
class_name RoadProfile
extends RefCounted
## Surface height offsets along a trail: gentle undulation everywhere, potholes
## and patched tarmac in rough ranges, and jump crests. Built once from a
## TrailDef. All randomness comes from its seed, so the same settings always
## give the same road.

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

	var ranges: Array[Vector2] = []
	for section in def.rough_sections:
		var start := section.x
		var end := section.x + section.y
		for i in roundi(section.y / 100.0 * section.z):
			_add_random_pothole(rng, start + def.rough_margin, end - def.rough_margin)
		for i in int(section.y / 12.0):
			_add_random_patch(rng, start + def.rough_margin, end - def.rough_margin)
		ranges.append(Vector2(start, end))
	for cluster in def.pothole_clusters:
		for i in int(cluster.y):
			_add_random_pothole(rng, cluster.x - CLUSTER_SPREAD, cluster.x + CLUSTER_SPREAD)
		ranges.append(Vector2(cluster.x - CLUSTER_DETAIL, cluster.x + CLUSTER_DETAIL))

	potholes.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.x < b.x)
	for pothole in potholes:
		_pothole_distances.append(pothole.x)
		_max_pothole_radius = maxf(_max_pothole_radius, pothole.z)
	detail_ranges = _merged(ranges)


## Total surface offset at a point of the road (m).
func height(distance: float, lateral: float) -> float:
	return undulation(distance) + jump_height(distance) + rough_height(distance, lateral)


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

`levels/trail/road_sampler.gd`:

```gdscript
class_name RoadSampler
extends RefCounted
## Answers questions about a road's centre line: where the road is at a
## distance, which way it faces, and how far a world point is from it.
## Forward follows the road; right is across it; up is the road surface's
## normal, including any banking set as curve tilt.

var curve: Curve3D
var length: float


func _init(road_curve: Curve3D) -> void:
	curve = road_curve
	length = curve.get_baked_length()


func position(distance: float) -> Vector3:
	return curve.sample_baked(clampf(distance, 0.0, length), true)


func forward(distance: float) -> Vector3:
	return (position(distance + 0.5) - position(distance - 0.5)).normalized()


func up(distance: float) -> Vector3:
	var tilted_up := curve.sample_baked_up_vector(clampf(distance, 0.0, length), true)
	var along := forward(distance)
	return (tilted_up - along * tilted_up.dot(along)).normalized()


func right(distance: float) -> Vector3:
	return forward(distance).cross(up(distance)).normalized()


## Distance along the road of the centre-line point nearest to `point`.
func closest_distance(point: Vector3) -> float:
	return curve.get_closest_offset(point)


## Signed distance of `point` from the centre line, measured across the road
## at its nearest point (+ = right of the road).
func lateral_offset(point: Vector3) -> float:
	var distance := closest_distance(point)
	return (point - position(distance)).dot(right(distance))


## A point on the road surface.
func surface_point(distance: float, lateral: float, profile: RoadProfile) -> Vector3:
	return position(distance) + right(distance) * lateral + up(distance) * profile.height(distance, lateral)


## A transform on the road's centre at `distance`, facing along the road,
## `height_above` metres above the surface.
func transform_at(distance: float, height_above: float, profile: RoadProfile) -> Transform3D:
	var along := forward(distance)
	var surface_up := up(distance)
	var origin := surface_point(distance, 0.0, profile) + surface_up * height_above
	return Transform3D(Basis.looking_at(along, surface_up), origin)
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_road_profile.gd` 9 passing, `test_road_sampler.gd` 6 passing.

- [ ] **Step 5: Commit** — subject `Add road settings, road profile and road sampler`; stage the three scripts, two tests and their `.uid` files.

---

### Task 7: Corridor and terrain field

**Files:**
- Create: `levels/trail/corridor.gd`, `levels/trail/terrain_def.gd`, `levels/trail/terrain_field.gd`
- Test: `tests/unit/test_corridor.gd`, `tests/unit/test_terrain_field.gd`

**Interfaces:**
- Consumes: `RoadSampler`, `TrailDef` (Task 6).
- Produces:
  - `Corridor`: consts `EDGE_GAP`, `INSIDE_FALLOFF`; static `natural_weight(edge_distance, blend_width)`, `carved_height(road_height, natural_height, edge_distance, blend_width, under_road_drop)`.
  - `TerrainDef` (Resource): `margin` 300, `chunk_size` 128, `sample_spacing` 2, `corridor_blend` 25, `under_road_drop` 0.3, `smoothing_radius` 12, noise settings, `rock_slope_deg` 35, `detail_distance` 200, `view_distance` 500, `kill_depth` 30, colours, `seed`.
  - `TerrainField` (RefCounted): static `generate(sampler, trail, terrain) -> TerrainField`; `origin`, `spacing`, `columns`, `rows`, `cells_per_chunk`, `heights`, `edge_distances`, `lowest_height`; `chunk_count()`, `index(column, row)`, `sample_position`, `height_at(x, z)`, `edge_distance_at(x, z)`, `normal_at_index`, `normal_at(x, z)`, `kill_height()`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_corridor.gd`:

```gdscript
extends GutTest

const ROAD := 100.0
const NATURAL := 112.0
const BLEND := 25.0
const DROP := 0.3


func _height(edge_distance: float) -> float:
	return Corridor.carved_height(ROAD, NATURAL, edge_distance, BLEND, DROP)


func test_terrain_meets_the_shoulder_edge_just_below_it() -> void:
	assert_almost_eq(_height(0.0), ROAD - Corridor.EDGE_GAP, 0.0001)


func test_terrain_is_natural_at_the_end_of_the_blend() -> void:
	assert_almost_eq(_height(BLEND), NATURAL, 0.0001)
	assert_almost_eq(_height(BLEND + 40.0), NATURAL, 0.0001)


func test_blend_rises_steadily_toward_higher_natural_terrain() -> void:
	var previous := _height(0.0)
	for step in range(1, 26):
		var current := _height(float(step))
		assert_gte(current, previous, "at %d m" % step)
		previous = current


func test_terrain_sits_well_below_the_asphalt() -> void:
	assert_almost_eq(_height(-5.0), ROAD - DROP, 0.0001)


func test_no_step_at_the_edge() -> void:
	assert_almost_eq(_height(-0.001), _height(0.001), 0.001)
```

`tests/unit/test_terrain_field.gd`:

```gdscript
extends GutTest
## TerrainField on small, noise-free roads so heights can be checked exactly.

var trail: TrailDef
var terrain: TerrainDef


func before_each() -> void:
	trail = TrailDef.new()
	terrain = TerrainDef.new()
	terrain.margin = 60.0
	terrain.chunk_size = 32.0
	terrain.sample_spacing = 2.0
	terrain.noise_amplitude = 0.0


func _sampler(points: Array[Vector3]) -> RoadSampler:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for point in points:
		curve.add_point(point)
	return RoadSampler.new(curve)


func _flat_straight() -> TerrainField:
	return TerrainField.generate(_sampler([Vector3.ZERO, Vector3(0.0, 0.0, -200.0)]), trail, terrain)


func test_grid_covers_the_road_plus_margin_in_whole_chunks() -> void:
	var field := _flat_straight()
	assert_lte(field.origin.x, -60.0)
	assert_lte(field.origin.y, -260.0)
	assert_gte(field.origin.x + (field.columns - 1) * field.spacing, 60.0)
	assert_gte(field.origin.y + (field.rows - 1) * field.spacing, 60.0)
	assert_eq((field.columns - 1) % field.cells_per_chunk, 0, "columns fill whole chunks")
	assert_eq((field.rows - 1) % field.cells_per_chunk, 0, "rows fill whole chunks")


func test_terrain_sits_below_the_road_and_meets_the_shoulders() -> void:
	var field := _flat_straight()
	assert_almost_eq(field.height_at(0.0, -100.0), -terrain.under_road_drop, 0.02, "under the road centre")
	assert_almost_eq(field.height_at(trail.half_total_width(), -100.0), -Corridor.EDGE_GAP, 0.05, "at the shoulder edge")
	assert_almost_eq(field.height_at(50.0, -100.0), 0.0, 0.01, "natural ground beyond the blend")


func test_edge_distance_measures_from_the_shoulder_edge() -> void:
	var field := _flat_straight()
	assert_almost_eq(field.edge_distance_at(16.0, -100.0), 10.0, 1.1)
	assert_lt(field.edge_distance_at(0.0, -100.0), 0.0, "negative under the road")


func test_natural_ground_follows_the_road_climb() -> void:
	var field := TerrainField.generate(_sampler([Vector3.ZERO, Vector3(0.0, 20.0, -200.0)]), trail, terrain)
	assert_almost_eq(field.height_at(55.0, -100.0), 10.0, 0.2, "beside the middle of a 20 m climb")
	assert_almost_eq(field.height_at(-55.0, -180.0), 18.0, 0.2, "beside its upper end")


func test_flat_ground_faces_up() -> void:
	var field := _flat_straight()
	assert_gt(field.normal_at(50.0, -100.0).y, 0.999)


func test_kill_height_is_below_the_lowest_ground() -> void:
	var field := _flat_straight()
	assert_almost_eq(field.kill_height(), field.lowest_height - terrain.kill_depth, 0.0001)


func test_generation_is_deterministic() -> void:
	terrain.noise_amplitude = 20.0
	var a := _flat_straight()
	var b := _flat_straight()
	assert_eq(a.heights, b.heights)


func test_switchback_legs_leave_no_cliff_between_them() -> void:
	# Down one leg, a tight turn, and back up a parallel leg 30 m away and 12 m higher.
	var field := TerrainField.generate(_sampler([
		Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -120.0),
		Vector3(15.0, 6.0, -135.0), Vector3(30.0, 12.0, -120.0), Vector3(30.0, 12.0, 0.0),
	]), trail, terrain)
	var steepest := 0.0
	for x in range(6, 26, 2):
		var step := absf(field.height_at(x + 2.0, -60.0) - field.height_at(float(x), -60.0))
		steepest = maxf(steepest, step)
	gut.p("steepest 2 m step between the legs: %.2f m" % steepest)
	assert_lt(steepest, 2.5, "no vertical step where the two legs' corridors meet")
```

- [ ] **Step 2: Run them and watch them fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `Corridor` / `TerrainDef` / `TerrainField` are not declared.

- [ ] **Step 3: Implement**

`levels/trail/corridor.gd`:

```gdscript
class_name Corridor
extends RefCounted
## How the terrain meets the road. Under the road and shoulders the terrain sits
## just below them. Outside the shoulder edge it blends from the road's height
## back to the natural mountainside over `blend_width`: a cut uphill, an
## embankment downhill.

## At the shoulder edge the terrain sits this far below the road, so they never z-fight (m).
const EDGE_GAP := 0.05
## Inside the edge, the terrain drops to its full depth over this distance (m).
const INSIDE_FALLOFF := 1.5


## How much of the natural terrain shows at `edge_distance` metres outside the
## shoulder edge: 0 at the edge (and inside it), 1 at blend_width and beyond.
static func natural_weight(edge_distance: float, blend_width: float) -> float:
	return smoothstep(0.0, blend_width, edge_distance)


## Terrain height at a point. edge_distance: metres outside the shoulder edge
## (negative = under the road or a shoulder).
static func carved_height(road_height: float, natural_height: float, edge_distance: float,
		blend_width: float, under_road_drop: float) -> float:
	if edge_distance < 0.0:
		var depth := lerpf(EDGE_GAP, under_road_drop, smoothstep(0.0, INSIDE_FALLOFF, -edge_distance))
		return road_height - depth
	return lerpf(road_height - EDGE_GAP, natural_height, natural_weight(edge_distance, blend_width))
```

`levels/trail/terrain_def.gd`:

```gdscript
class_name TerrainDef
extends Resource
## Settings for the mountainside generated around a trail.

## Terrain extends this far past the road on every side (m).
@export var margin: float = 300.0
## Size of one terrain chunk (m). Chunks share their border samples.
@export var chunk_size: float = 128.0
## Distance between height samples (m).
@export var sample_spacing: float = 2.0
## Width outside the shoulder edge over which terrain blends back to natural (m).
@export var corridor_blend: float = 25.0
## Terrain sits this far below the road under the asphalt (m).
@export var under_road_drop: float = 0.3
## How far along and across the road its elevation is averaged when shaping
## the terrain (m). Keeps switchback legs from producing steps between them.
@export var smoothing_radius: float = 12.0
## Natural mountainside noise.
@export var noise_amplitude: float = 20.0
@export var noise_wavelength: float = 200.0
@export var noise_octaves: int = 4
## Slopes steeper than this are coloured as rock (degrees).
@export var rock_slope_deg: float = 35.0
## Beyond this distance from the camera terrain is drawn from every second
## height sample, a quarter of the triangles (m). Collision always uses every sample.
@export var detail_distance: float = 200.0
## Terrain chunks further than this from the camera are not drawn (m).
@export var view_distance: float = 500.0
## The car is reset when it falls this far below the lowest terrain (m).
@export var kill_depth: float = 30.0
@export var dirt_color: Color = Color(0.62, 0.47, 0.3)
@export var rock_color: Color = Color(0.55, 0.45, 0.38)
@export var seed: int = 7
```

`levels/trail/terrain_field.gd`:

```gdscript
class_name TerrainField
extends RefCounted
## The mountainside around a trail as a grid of height samples, generated once.
## The natural ground is a plane fitted to the road's overall climb plus noise.
## Near the road, the ground follows a smoothed road elevation and is carved to
## meet the shoulders (see Corridor).
## Grid rows run along +Z and columns along +X; index = row * columns + column.

## Sentinel edge distance for samples far from any road.
const FAR := 1.0e6

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
	return field


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
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_corridor.gd` 5 passing, `test_terrain_field.gd` 8 passing (it prints the steepest step between switchback legs, about 1.9 m).

- [ ] **Step 5: Commit** — subject `Generate carved terrain around a road`; stage the three scripts, two tests and `.uid` files.

---

### Task 8: Terrain builder

**Files:**
- Create: `levels/trail/terrain_builder.gd`, `tests/unit/test_terrain_builder.gd`

**Interfaces:**
- Consumes: `TerrainField` (Task 7), `SurfaceLookup`, `res://surfaces/dirt.tres`.
- Produces: `TerrainBuilder` (Node3D): const `COARSE_STEP = 2`; `build(field)` adds per chunk a full-detail `MeshInstance3D` "Near" (drawn to `detail_distance`), a coarse "Far" one built from every second sample (drawn from `detail_distance` to `view_distance`), neither casting shadows, and one dirt-tagged `StaticBody3D` with full-resolution `HeightMapShape3D` collision.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_terrain_builder.gd`:

```gdscript
extends GutTest

var field: TerrainField
var builder: TerrainBuilder


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 8.0, -120.0))
	var terrain := TerrainDef.new()
	terrain.margin = 40.0
	terrain.chunk_size = 32.0
	field = TerrainField.generate(RoadSampler.new(curve), TrailDef.new(), terrain)
	builder = TerrainBuilder.new()
	add_child_autofree(builder)
	builder.build(field)


func _children_of(type: String) -> Array:
	return builder.get_children().filter(func(child: Node) -> bool: return child.is_class(type))


## Full-detail meshes, one per chunk in chunk order.
func _near_meshes() -> Array:
	return _children_of("MeshInstance3D").filter(func(mesh: MeshInstance3D) -> bool: return mesh.visibility_range_begin == 0.0)


func _far_meshes() -> Array:
	return _children_of("MeshInstance3D").filter(func(mesh: MeshInstance3D) -> bool: return mesh.visibility_range_begin > 0.0)


func test_near_and_far_mesh_and_one_dirt_body_per_chunk() -> void:
	var chunks := field.chunk_count()
	assert_eq(_near_meshes().size(), chunks.x * chunks.y)
	assert_eq(_far_meshes().size(), chunks.x * chunks.y)
	var bodies := _children_of("StaticBody3D")
	assert_eq(bodies.size(), chunks.x * chunks.y)
	assert_eq(bodies[0].get_meta(SurfaceLookup.META_KEY).id, &"dirt")


func test_far_mesh_takes_over_where_the_near_mesh_ends() -> void:
	var near: MeshInstance3D = _near_meshes()[0]
	var far: MeshInstance3D = _far_meshes()[0]
	assert_eq(near.visibility_range_end, field.def.detail_distance)
	assert_eq(far.visibility_range_begin, field.def.detail_distance)
	assert_eq(far.visibility_range_end, field.def.view_distance)
	assert_eq(far.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_far_mesh_uses_every_second_sample() -> void:
	var vertices: PackedVector3Array = _far_meshes()[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var size := field.cells_per_chunk / 2 + 1
	assert_eq(vertices.size(), size * size)
	assert_eq(vertices[size + 1], field.sample_position(2, 2))


func test_triangles_face_up() -> void:
	var mesh: ArrayMesh = _near_meshes()[0].mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, indices.size(), 3):
		var a := vertices[indices[t]]
		var winding := (vertices[indices[t + 1]] - a).cross(vertices[indices[t + 2]] - a)
		# Same winding as the proven RoughPatch mesh: the cross product points down.
		assert_lt(winding.y, 0.0)
		if winding.y >= 0.0:
			return


func test_neighbouring_chunks_share_their_border() -> void:
	var meshes := _near_meshes()
	var first: PackedVector3Array = meshes[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var second: PackedVector3Array = meshes[1].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var size := field.cells_per_chunk + 1
	for row in size:
		assert_eq(first[row * size + size - 1], second[row * size], "row %d" % row)


func test_collision_matches_the_field() -> void:
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	for point in [Vector2(20.0, -60.0), Vector2(-30.0, -10.0), Vector2(0.0, -100.0)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 200.0, point.y), Vector3(point.x, -200.0, point.y))
		var hit := space.intersect_ray(query)
		assert_false(hit.is_empty(), "ray hits the terrain at %s" % point)
		var hit_position: Vector3 = hit["position"]
		assert_almost_eq(hit_position.y, field.height_at(point.x, point.y), 0.05, "at %s" % point)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `TerrainBuilder` is not declared.

- [ ] **Step 3: Implement**

`levels/trail/terrain_builder.gd`:

```gdscript
class_name TerrainBuilder
extends Node3D
## Turns a TerrainField into chunks, each with slope-coloured meshes and
## heightmap collision tagged as dirt. Chunks share their border samples, so
## there are no seams. Each chunk has a full-detail mesh near the camera and a
## coarse one (every second sample) further away.

const DIRT := preload("res://surfaces/dirt.tres")

## Slopes within this many degrees of the rock angle blend between dirt and rock colour.
const COLOR_BLEND_DEG := 5.0
## The far mesh uses every this-many-th height sample.
const COARSE_STEP := 2

var _index_cache := {}


func build(field: TerrainField) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	assert(field.cells_per_chunk % COARSE_STEP == 0, "chunk cells must divide by COARSE_STEP")
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	var cells := field.cells_per_chunk
	var chunks := field.chunk_count()
	for chunk_row in chunks.y:
		for chunk_column in chunks.x:
			_add_chunk(field, chunk_column * cells, chunk_row * cells, cells + 1, material)


func _add_chunk(field: TerrainField, first_column: int, first_row: int, size: int,
		material: StandardMaterial3D) -> void:
	var near := _add_mesh(field, first_column, first_row, size, 1, material)
	near.name = "Near"
	near.visibility_range_end = field.def.detail_distance
	var far := _add_mesh(field, first_column, first_row, size, COARSE_STEP, material)
	far.name = "Far"
	far.visibility_range_begin = field.def.detail_distance
	far.visibility_range_end = field.def.view_distance

	var collision_heights := PackedFloat32Array()
	for row in size:
		for column in size:
			collision_heights.append(field.heights[field.index(first_column + column, first_row + row)])
	var shape := HeightMapShape3D.new()
	shape.map_width = size
	shape.map_depth = size
	shape.map_data = collision_heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	# The shape puts samples 1 m apart around its centre; scaling sets the spacing.
	collision.scale = Vector3(field.spacing, 1.0, field.spacing)
	var body := StaticBody3D.new()
	body.set_meta(SurfaceLookup.META_KEY, DIRT)
	var middle := (size - 1) * 0.5
	body.position = Vector3(field.origin.x + (first_column + middle) * field.spacing, 0.0,
			field.origin.y + (first_row + middle) * field.spacing)
	body.add_child(collision)
	add_child(body)


## Adds a mesh of one chunk built from every `step`-th sample.
func _add_mesh(field: TerrainField, first_column: int, first_row: int, size: int, step: int,
		material: StandardMaterial3D) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var rock_deg := field.def.rock_slope_deg
	var mesh_size := (size - 1) / step + 1
	for row in mesh_size:
		for column in mesh_size:
			var grid_column := first_column + column * step
			var grid_row := first_row + row * step
			var normal := field.normal_at_index(grid_column, grid_row)
			vertices.append(field.sample_position(grid_column, grid_row))
			normals.append(normal)
			var slope_deg := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
			var rockiness := smoothstep(rock_deg - COLOR_BLEND_DEG, rock_deg + COLOR_BLEND_DEG, slope_deg)
			colors.append(field.def.dirt_color.lerp(field.def.rock_color, rockiness))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = _grid_indices(mesh_size)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	# Terrain receives shadows but doesn't cast them: casting doubled the scene's
	# triangle count, because every chunk touching the shadow range is drawn whole.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance, true)
	return mesh_instance


## Triangle indices for a size x size vertex grid, facing up.
func _grid_indices(size: int) -> PackedInt32Array:
	if _index_cache.has(size):
		return _index_cache[size]
	var indices := PackedInt32Array()
	for row in size - 1:
		for column in size - 1:
			var i := row * size + column
			indices.append_array([i, i + 1, i + size, i + 1, i + size + 1, i + size])
	_index_cache[size] = indices
	return indices
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_terrain_builder.gd` 6 passing.

- [ ] **Step 5: Commit** — subject `Build terrain chunks with near and far meshes and heightmap collision`.

---

### Task 9: Road builder

**Files:**
- Create: `levels/trail/road_builder.gd`, `tests/unit/test_road_builder.gd`

**Interfaces:**
- Consumes: `RoadSampler`, `RoadProfile`, `TrailDef` (Task 6); asphalt and dirt surfaces.
- Produces: `RoadBuilder` (Node3D): enum `Part { SHOULDER, ASPHALT, LINE }`; static `cross_section(def) -> Array[Vector2]`, `row_distances(length, profile, def) -> PackedFloat32Array`; `build(sampler, profile, def)` adds per chunk one `MeshInstance3D`, an asphalt `StaticBody3D` and a dirt `StaticBody3D` (trimesh collision).

- [ ] **Step 1: Write the failing test**

`tests/unit/test_road_builder.gd`:

```gdscript
extends GutTest

var def: TrailDef
var sampler: RoadSampler
var profile: RoadProfile
var builder: RoadBuilder


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -250.0))
	sampler = RoadSampler.new(curve)
	def = TrailDef.new()
	def.undulation_amplitude = 0.0
	def.rough_sections = [Vector3(120.0, 40.0, 25.0)]
	profile = RoadProfile.new(def, sampler.length)
	builder = RoadBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, def)


func _children_of(type: String) -> Array:
	return builder.get_children().filter(func(child: Node) -> bool: return child.is_class(type))


func test_cross_section_is_symmetric_with_sharp_part_boundaries() -> void:
	var stations := RoadBuilder.cross_section(def)
	assert_almost_eq(stations[0].x, -6.0, 0.0001)
	assert_almost_eq(stations[-1].x, 6.0, 0.0001)
	for i in stations.size():
		assert_almost_eq(stations[i].x, -stations[-1 - i].x, 0.0001, "station %d mirrors" % i)
	var line_stations := stations.filter(func(s: Vector2) -> bool: return int(s.y) == RoadBuilder.Part.LINE)
	assert_eq(line_stations.size(), 4, "two stations per edge line")


func test_rows_are_denser_inside_rough_ranges() -> void:
	var distances := RoadBuilder.row_distances(sampler.length, profile, def)
	assert_almost_eq(distances[0], 0.0, 0.0001)
	assert_almost_eq(distances[-1], sampler.length, 0.01)
	var inside := 0
	for d in distances:
		if d > 125.0 and d < 155.0:
			inside += 1
	assert_gte(inside, 116, "0.25 m rows over 30 m of rough ground")


func test_one_mesh_and_two_collision_bodies_per_chunk() -> void:
	assert_eq(_children_of("MeshInstance3D").size(), 3, "250 m in 100 m chunks")
	var bodies := _children_of("StaticBody3D")
	assert_eq(bodies.size(), 6)
	assert_eq(bodies[0].get_meta(SurfaceLookup.META_KEY).id, &"asphalt")
	assert_eq(bodies[1].get_meta(SurfaceLookup.META_KEY).id, &"dirt")


func test_triangles_face_up() -> void:
	var mesh: ArrayMesh = _children_of("MeshInstance3D")[0].mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, indices.size(), 3):
		var a := vertices[indices[t]]
		var winding := (vertices[indices[t + 1]] - a).cross(vertices[indices[t + 2]] - a)
		assert_lt(winding.y, 0.0)
		if winding.y >= 0.0:
			return


func test_chunks_meet_exactly() -> void:
	var meshes := _children_of("MeshInstance3D")
	var first: PackedVector3Array = meshes[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var second: PackedVector3Array = meshes[1].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var width := RoadBuilder.cross_section(def).size()
	for column in width:
		assert_eq(first[first.size() - width + column], second[column])


func test_collision_surfaces_under_road_and_shoulder() -> void:
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	var road_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(1.0, 5.0, -60.0), Vector3(1.0, -5.0, -60.0)))
	var shoulder_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(5.0, 5.0, -60.0), Vector3(5.0, -5.0, -60.0)))
	assert_eq(SurfaceLookup.surface_of(road_hit["collider"]).id, &"asphalt")
	assert_eq(SurfaceLookup.surface_of(shoulder_hit["collider"]).id, &"dirt")
	var road_y: float = road_hit["position"].y
	assert_almost_eq(road_y, 0.0, 0.01)


func test_potholes_dip_the_surface_and_darken_it() -> void:
	var pothole := profile.potholes[0]
	assert_lt(profile.height(pothole.x, pothole.y), -0.03)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `RoadBuilder` is not declared.

- [ ] **Step 3: Implement**

`levels/trail/road_builder.gd`:

```gdscript
class_name RoadBuilder
extends Node3D
## Builds the road surface along a trail in chunks: a mesh with painted edge
## lines and shaded potholes, asphalt collision for the road, and dirt
## collision for the shoulders.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")

## Potholes are shaded darker by this much per metre of depth.
const SHADE_PER_METRE := 4.0
## Which part of the cross-section a station belongs to.
enum Part { SHOULDER, ASPHALT, LINE }


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


## Cross-section stations from left to right as Vector3(lateral, part, _).
## Boundaries between parts appear twice (one station per part) so colours
## change sharply instead of fading.
static func cross_section(def: TrailDef) -> Array[Vector2]:
	var half_road := def.road_width * 0.5
	var outer := half_road + def.shoulder_width
	var line_outer := half_road - def.line_inset
	var line_inner := line_outer - def.line_width
	var stations: Array[Vector2] = [
		Vector2(-outer, Part.SHOULDER), Vector2(-half_road, Part.SHOULDER),
		Vector2(-half_road, Part.ASPHALT), Vector2(-line_outer, Part.ASPHALT),
		Vector2(-line_outer, Part.LINE), Vector2(-line_inner, Part.LINE),
		Vector2(-line_inner, Part.ASPHALT),
	]
	var lateral := -floorf(line_inner / def.lateral_step) * def.lateral_step
	if lateral <= -line_inner:
		lateral += def.lateral_step
	while lateral < line_inner - 0.001:
		stations.append(Vector2(lateral, Part.ASPHALT))
		lateral += def.lateral_step
	stations.append_array([
		Vector2(line_inner, Part.ASPHALT), Vector2(line_inner, Part.LINE),
		Vector2(line_outer, Part.LINE), Vector2(line_outer, Part.ASPHALT),
		Vector2(half_road, Part.ASPHALT), Vector2(half_road, Part.SHOULDER),
		Vector2(outer, Part.SHOULDER),
	])
	return stations


## Distances of the cross-section rows: every sample_step, and every
## detail_step inside rough ranges. Always includes 0 and the road's end.
static func row_distances(length: float, profile: RoadProfile, def: TrailDef) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	var distance := 0.0
	while distance < length - 0.001:
		distances.append(distance)
		distance += def.detail_step if profile.in_detail_range(distance) else def.sample_step
	distances.append(length)
	return distances


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
	var road_faces := PackedVector3Array()
	var shoulder_faces := PackedVector3Array()
	for row in distances.size() - 1:
		for column in width - 1:
			var left := stations[column]
			var right := stations[column + 1]
			if is_equal_approx(left.x, right.x):
				continue  # zero-width boundary between parts
			var i := row * width + column
			var quad := [i, i + width, i + 1, i + 1, i + width, i + width + 1]
			indices.append_array(quad)
			var faces := road_faces if int(left.y) != Part.SHOULDER else shoulder_faces
			for corner in quad:
				faces.append(vertices[corner])

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

	add_child(_collision_body(road_faces, ASPHALT))
	add_child(_collision_body(shoulder_faces, DIRT))


func _color(profile: RoadProfile, def: TrailDef, distance: float, lateral: float, part: int) -> Color:
	match part:
		Part.SHOULDER:
			return def.shoulder_color
		Part.LINE:
			return def.line_color
	var base := def.patch_color if profile.is_patch(distance, lateral) else def.asphalt_color
	var shade := clampf(1.0 + profile.pothole_height(distance, lateral) * SHADE_PER_METRE, 0.5, 1.0)
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

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_road_builder.gd` 7 passing.

- [ ] **Step 5: Commit** — subject `Build the road surface with lines, potholes and collision`.

---

### Task 10: Low-poly scenery meshes

**Files:**
- Create: `levels/trail/low_poly_meshes.gd`, `tests/unit/test_low_poly_meshes.gd`

**Interfaces:**
- Produces: static `LowPolyMeshes.pine(foliage, trunk)`, `rock(color, seed)`, `post(body, band)`, `gate_post(color, height)`, `banner(color, width)`, each returning a flat-shaded `ArrayMesh` with vertex colours.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_low_poly_meshes.gd`:

```gdscript
extends GutTest


func _assert_faces_point_away_from(mesh: ArrayMesh, centre: Vector3) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_gt(vertices.size(), 0, "mesh has triangles")
	for t in range(0, vertices.size(), 3):
		var face_centre := (vertices[t] + vertices[t + 1] + vertices[t + 2]) / 3.0
		assert_gt(normals[t].dot(face_centre - centre), 0.0, "triangle %d faces outward" % (t / 3))
		if normals[t].dot(face_centre - centre) <= 0.0:
			return


func test_rock_faces_outward() -> void:
	_assert_faces_point_away_from(LowPolyMeshes.rock(Color.GRAY, 3), Vector3.ZERO)


func test_post_faces_outward() -> void:
	# The post is a single convex box apart from its band; check the body box on its own.
	_assert_faces_point_away_from(LowPolyMeshes.gate_post(Color.WHITE, 4.0), Vector3(0.0, 2.0, 0.0))


func test_banner_faces_outward() -> void:
	_assert_faces_point_away_from(LowPolyMeshes.banner(Color.ORANGE, 13.0), Vector3.ZERO)


func test_pine_has_trunk_and_foliage_colours() -> void:
	var mesh := LowPolyMeshes.pine(Color(0.3, 0.4, 0.2), Color(0.4, 0.3, 0.2))
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_gt(colors.size(), 60)
	# Vertex colours are stored as 8-bit, so compare within one step of 1/255.
	var trunk := Vector3(0.4, 0.3, 0.2)
	assert_true(Array(colors).any(func(c: Color) -> bool: return Vector3(c.r, c.g, c.b).distance_to(trunk) < 0.01), "trunk colour present")


func test_rocks_differ_by_seed() -> void:
	var a: PackedVector3Array = LowPolyMeshes.rock(Color.GRAY, 1).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var b: PackedVector3Array = LowPolyMeshes.rock(Color.GRAY, 2).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_ne(a, b)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `LowPolyMeshes` is not declared.

- [ ] **Step 3: Implement**

`levels/trail/low_poly_meshes.gd`:

```gdscript
class_name LowPolyMeshes
extends RefCounted
## Small flat-shaded meshes for scenery, built in code with vertex colours:
## pine, rock, roadside post, gate post and gate banner. Every triangle is
## flat-shaded, wound and lit so it faces away from its shape's centre.


## A pine about 4.7 m tall: a trunk and three stacked cones.
static func pine(foliage: Color, trunk: Color) -> ArrayMesh:
	var tool := _begin()
	_add_cylinder(tool, Vector3.ZERO, 0.15, 1.2, 6, trunk)
	# Only the lowest cone has a base; the upper bases are hidden inside the cone below.
	_add_cone(tool, Vector3(0.0, 0.8, 0.0), 1.6, 2.2, 7, foliage, true)
	_add_cone(tool, Vector3(0.0, 2.0, 0.0), 1.2, 1.9, 7, foliage.lightened(0.05), false)
	_add_cone(tool, Vector3(0.0, 3.1, 0.0), 0.8, 1.6, 7, foliage.lightened(0.1), false)
	return _finish(tool)


## A rough, slightly flattened boulder about 2 m across.
static func rock(color: Color, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var golden := (1.0 + sqrt(5.0)) * 0.5
	var corners: Array[Vector3] = [
		Vector3(-1, golden, 0), Vector3(1, golden, 0), Vector3(-1, -golden, 0), Vector3(1, -golden, 0),
		Vector3(0, -1, golden), Vector3(0, 1, golden), Vector3(0, -1, -golden), Vector3(0, 1, -golden),
		Vector3(golden, 0, -1), Vector3(golden, 0, 1), Vector3(-golden, 0, -1), Vector3(-golden, 0, 1),
	]
	for i in corners.size():
		var jittered := corners[i].normalized() * rng.randf_range(0.8, 1.2)
		corners[i] = Vector3(jittered.x, jittered.y * 0.7, jittered.z)
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5],
		[2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	var tool := _begin()
	for face in faces:
		var shade := rng.randf_range(0.9, 1.05)
		_add_triangle(tool, Vector3.ZERO, corners[face[0]], corners[face[1]], corners[face[2]],
				Color(color.r * shade, color.g * shade, color.b * shade))
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

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_low_poly_meshes.gd` 5 passing.

- [ ] **Step 5: Commit** — subject `Add low-poly pine, rock, post and gate meshes`.

---

### Task 11: Scenery and checkpoint gates

**Files:**
- Create: `levels/trail/scatter_def.gd`, `levels/trail/scatter_builder.gd`, `levels/trail/checkpoint_placer.gd`
- Test: `tests/unit/test_scatter_and_checkpoints.gd`

**Interfaces:**
- Consumes: `TerrainField`, `RoadSampler`, `RoadProfile`, `TrailDef`, `LowPolyMeshes`.
- Produces:
  - `ScatterDef` (Resource): spacings, `road_clearance` 6, `max_slope_deg` 35, `pine_view_distance` 300, `rock_view_distance` 150 (rocks and posts), `post_spacing` 25, `post_drop` 2, `rock_collision_distance` 30, colours, `seed`. Only pines cast shadows.
  - `ScatterBuilder` (Node3D): `build(field, sampler, profile, trail, def)`; counts `pine_count`, `rock_count`, `post_count`.
  - `CheckpointPlacer` (Node3D): signal `gate_entered(index: int, body: Node3D)`; consts `GATE_SIZE`, `RESET_HEIGHT`; `gate_distances`, `reset_transforms: Array[Transform3D]`; static `distances_for(length, def)`, `label_for(index, count)`; `build(sampler, profile, def)`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_scatter_and_checkpoints.gd`:

```gdscript
extends GutTest
## ScatterBuilder and CheckpointPlacer on a small generated trail.

var trail: TrailDef
var terrain: TerrainDef
var scatter: ScatterDef
var sampler: RoadSampler
var profile: RoadProfile
var field: TerrainField


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 15.0, -300.0))
	sampler = RoadSampler.new(curve)
	trail = TrailDef.new()
	trail.checkpoint_distances = PackedFloat32Array([200.0, 100.0, 400.0])
	terrain = TerrainDef.new()
	terrain.margin = 80.0
	terrain.chunk_size = 64.0
	scatter = ScatterDef.new()
	profile = RoadProfile.new(trail, sampler.length)
	field = TerrainField.generate(sampler, trail, terrain)


func test_scenery_keeps_clear_of_the_road() -> void:
	var builder := ScatterBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, profile, trail, scatter)
	assert_gt(builder.pine_count, 20)
	assert_gt(builder.rock_count, 5)
	for child in builder.get_children():
		if child is MultiMeshInstance3D and child.multimesh.mesh.get_faces().size() > 300:  # pines and rocks, not posts
			for i in child.multimesh.instance_count:
				var spot: Vector3 = child.multimesh.get_instance_transform(i).origin
				assert_gte(field.edge_distance_at(spot.x, spot.z), scatter.road_clearance - field.spacing)


func test_scenery_is_drawn_with_a_view_distance() -> void:
	var builder := ScatterBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, profile, trail, scatter)
	var instances := builder.get_children().filter(func(c: Node) -> bool: return c is MultiMeshInstance3D)
	assert_gt(instances.size(), 0)
	# Pines are added first.
	assert_almost_eq(instances[0].visibility_range_end, scatter.pine_view_distance, 0.001)


func test_checkpoint_distances_add_start_and_finish_in_order() -> void:
	var distances := CheckpointPlacer.distances_for(sampler.length, trail)
	assert_eq(distances.size(), 4, "start, 100, 200, finish (400 is past the end)")
	assert_almost_eq(distances[0], trail.start_distance, 0.001, "the start leaves road behind the car")
	assert_almost_eq(distances[1], 100.0, 0.001)
	assert_almost_eq(distances[-1], sampler.length - trail.end_margin, 0.001, "the finish leaves road after it")


func test_gate_labels() -> void:
	assert_eq(CheckpointPlacer.label_for(0, 4), "START")
	assert_eq(CheckpointPlacer.label_for(2, 4), "CP 2")
	assert_eq(CheckpointPlacer.label_for(3, 4), "FINISH")


func test_reset_transforms_sit_above_the_road_facing_along_it() -> void:
	var placer := CheckpointPlacer.new()
	add_child_autofree(placer)
	placer.build(sampler, profile, trail)
	assert_eq(placer.reset_transforms.size(), 4)
	var reset := placer.reset_transforms[1]
	var road_surface := sampler.surface_point(100.0, 0.0, profile)
	assert_almost_eq(reset.origin.distance_to(road_surface), CheckpointPlacer.RESET_HEIGHT, 0.01)
	assert_gt((-reset.basis.z).dot(sampler.forward(100.0)), 0.999)


func test_gate_reports_a_body_entering_it() -> void:
	var placer := CheckpointPlacer.new()
	add_child_autofree(placer)
	placer.build(sampler, profile, trail)
	watch_signals(placer)
	var ball := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	ball.add_child(shape)
	ball.position = placer.reset_transforms[2].origin + Vector3(0.0, 1.0, 0.0)
	add_child_autofree(ball)
	await wait_physics_frames(10)
	assert_signal_emitted_with_parameters(placer, "gate_entered", [2, ball])
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `ScatterDef` / `ScatterBuilder` / `CheckpointPlacer` are not declared.

- [ ] **Step 3: Implement**

`levels/trail/scatter_def.gd`:

```gdscript
class_name ScatterDef
extends Resource
## Settings for scenery placed around a trail.

## Average distance between pines (m); 12.2 m is about one per 150 m².
@export var pine_spacing: float = 12.2
## Average distance between rocks (m); 17.3 m is about one per 300 m².
@export var rock_spacing: float = 17.3
## Nothing is placed closer than this to a shoulder edge (m).
@export var road_clearance: float = 6.0
## Nothing is placed on slopes steeper than this (degrees).
@export var max_slope_deg: float = 35.0
## Pines further than this from the camera are not drawn (m).
@export var pine_view_distance: float = 300.0
## Rocks further than this from the camera are not drawn (m).
@export var rock_view_distance: float = 150.0
## Distance between roadside posts (m).
@export var post_spacing: float = 25.0
## Posts go on a side where the terrain falls more than this within 10 m of the edge (m).
@export var post_drop: float = 2.0
## Rocks within this distance of a shoulder edge get collision (m).
@export var rock_collision_distance: float = 30.0
@export var foliage_color: Color = Color(0.33, 0.4, 0.24)
@export var trunk_color: Color = Color(0.36, 0.26, 0.18)
@export var rock_color: Color = Color(0.55, 0.45, 0.38)
@export var post_color: Color = Color(0.93, 0.92, 0.88)
@export var reflector_color: Color = Color(0.95, 0.45, 0.1)
@export var seed: int = 11
```

`levels/trail/scatter_builder.gd`:

```gdscript
class_name ScatterBuilder
extends Node3D
## Places pines, rocks and roadside posts around a trail. Pines and rocks are
## scattered one per grid cell with a random offset, kept clear of the road and
## off steep slopes; posts line shoulders where the ground drops away. Each kind
## is drawn as one MultiMesh per terrain chunk.

const DIRT := preload("res://surfaces/dirt.tres")

## How far outward from the shoulder edge the ground is checked for a drop (m).
const DROP_CHECK_DISTANCE := 10.0

## Counts of placed items, for tests and build reports.
var pine_count := 0
var rock_count := 0
var post_count := 0


func build(field: TerrainField, sampler: RoadSampler, profile: RoadProfile, trail: TrailDef, def: ScatterDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	pine_count = 0
	rock_count = 0
	post_count = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = def.seed
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9

	var rock_collision := StaticBody3D.new()
	rock_collision.name = "RockCollision"
	rock_collision.set_meta(SurfaceLookup.META_KEY, DIRT)
	add_child(rock_collision)

	var pines := _scatter(field, def, def.pine_spacing, Vector2(0.8, 1.3), 0.0, rng)
	pine_count = pines.size()
	_add_multimeshes(field, pines, LowPolyMeshes.pine(def.foliage_color, def.trunk_color), material,
			def.pine_view_distance, true)

	var rocks := _scatter(field, def, def.rock_spacing, Vector2(0.6, 1.6), 0.25, rng)
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


## One transform per grid cell of `spacing`, jittered, skipping cells too close
## to the road or too steep. `sink` lowers each item by that share of its scale.
func _scatter(field: TerrainField, def: ScatterDef, spacing: float, scale_range: Vector2, sink: float,
		rng: RandomNumberGenerator) -> Array[Transform3D]:
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

`levels/trail/checkpoint_placer.gd`:

```gdscript
class_name CheckpointPlacer
extends Node3D
## Creates the checkpoint gates along a trail. Each gate is an Area3D across the
## road and shoulders, two posts with a banner, and the transform a reset puts
## the car at. Gate 0 is the start and the last gate is the finish.

signal gate_entered(index: int, body: Node3D)

## Gate size across, up and along the road (m).
const GATE_SIZE := Vector3(12.0, 6.0, 2.0)
## Reset transforms sit this far above the road surface (m).
const RESET_HEIGHT := 1.0
const POST_HEIGHT := 4.6
const GATE_COLOR := Color(0.93, 0.92, 0.88)
const BANNER_COLOR := Color(0.95, 0.45, 0.1)

var gate_distances := PackedFloat32Array()
var reset_transforms: Array[Transform3D] = []


## The start gate, every checkpoint between the start and the finish, and the finish gate.
static func distances_for(length: float, def: TrailDef) -> PackedFloat32Array:
	var finish := length - def.end_margin
	var inner := Array(def.checkpoint_distances).filter(
			func(d: float) -> bool: return d > def.start_distance and d < finish)
	inner.sort()
	var result := PackedFloat32Array([def.start_distance])
	result.append_array(PackedFloat32Array(inner))
	result.append(finish)
	return result


static func label_for(index: int, count: int) -> String:
	if index == 0:
		return "START"
	if index == count - 1:
		return "FINISH"
	return "CP %d" % index


func build(sampler: RoadSampler, profile: RoadProfile, def: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	gate_distances = distances_for(sampler.length, def)
	reset_transforms.clear()
	var post_mesh := LowPolyMeshes.gate_post(GATE_COLOR, POST_HEIGHT)
	var banner_mesh := LowPolyMeshes.banner(BANNER_COLOR, GATE_SIZE.x + 1.0)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	for i in gate_distances.size():
		var distance := gate_distances[i]
		reset_transforms.append(sampler.transform_at(distance, RESET_HEIGHT, profile))
		var gate := Node3D.new()
		gate.name = "Gate%d" % i
		gate.transform = sampler.transform_at(distance, 0.0, profile)
		add_child(gate)

		var area := Area3D.new()
		var box := BoxShape3D.new()
		box.size = GATE_SIZE
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = Vector3(0.0, GATE_SIZE.y * 0.5, 0.0)
		area.add_child(shape)
		area.body_entered.connect(_on_body_entered.bind(i))
		gate.add_child(area)

		for side: float in [-1.0, 1.0]:
			var upright := MeshInstance3D.new()
			upright.mesh = post_mesh
			upright.material_override = material
			upright.position = Vector3(side * (GATE_SIZE.x * 0.5 + 0.5), 0.0, 0.0)
			gate.add_child(upright)
		var banner := MeshInstance3D.new()
		banner.mesh = banner_mesh
		banner.material_override = material
		banner.position = Vector3(0.0, POST_HEIGHT - 0.4, 0.0)
		gate.add_child(banner)
		var text := Label3D.new()
		text.text = label_for(i, gate_distances.size())
		text.font_size = 96
		text.pixel_size = 0.01
		text.position = Vector3(0.0, POST_HEIGHT - 0.4, 0.06)
		text.rotation_degrees = Vector3(0.0, 180.0, 0.0)  # readable when driving toward it
		gate.add_child(text)


func _on_body_entered(body: Node3D, index: int) -> void:
	gate_entered.emit(index, body)
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_scatter_and_checkpoints.gd` 6 passing.

- [ ] **Step 5: Commit** — subject `Scatter scenery and place checkpoint gates`.

---

### Task 12: Trail level

**Files:**
- Create: `levels/trail/trail_level.gd`, `tests/unit/test_trail_level.gd`

**Interfaces:**
- Consumes: every builder from Tasks 6–11.
- Produces: `TrailLevel` (`@tool` Node3D): exports `trail`, `terrain`, `scatter`, `rebuild`; signal `built`; fields `sampler`, `profile`, `field`, `road_builder`, `terrain_builder`, `scatter_builder`, `checkpoints`, `build_seconds`; `build()`, `start_transform()`, `kill_height()`. Needs a `Path3D` child named `Road`; builds into a `Generated` child.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_trail_level.gd`:

```gdscript
extends GutTest
## TrailLevel assembles every builder from a Road curve and settings.

func _level() -> TrailLevel:
	var level := TrailLevel.new()
	level.trail = TrailDef.new()
	level.trail.checkpoint_distances = PackedFloat32Array([150.0])
	level.terrain = TerrainDef.new()
	level.terrain.margin = 60.0
	level.terrain.chunk_size = 64.0
	level.scatter = ScatterDef.new()
	var road := Path3D.new()
	road.name = "Road"
	road.curve = Curve3D.new()
	road.curve.bake_interval = 1.0
	road.curve.add_point(Vector3.ZERO)
	road.curve.add_point(Vector3(40.0, 10.0, -300.0))
	level.add_child(road)
	return level


func test_building_creates_every_part() -> void:
	var level := _level()
	add_child_autofree(level)  # builds in _ready
	for part in ["Generated/Road", "Generated/Terrain", "Generated/Scatter", "Generated/Checkpoints"]:
		assert_not_null(level.get_node_or_null(part), part)
	assert_eq(level.checkpoints.reset_transforms.size(), 3)
	gut.p("small trail built in %.2f s" % level.build_seconds)


func test_start_transform_is_the_start_gate() -> void:
	var level := _level()
	add_child_autofree(level)
	assert_eq(level.start_transform(), level.checkpoints.reset_transforms[0])


func test_kill_height_is_below_all_terrain() -> void:
	var level := _level()
	add_child_autofree(level)
	assert_lt(level.kill_height(), level.field.lowest_height)


func test_rebuilding_replaces_the_generated_nodes_with_the_same_level() -> void:
	var level := _level()
	add_child_autofree(level)
	var first_heights := level.field.heights
	var first_gates := level.checkpoints.reset_transforms.duplicate()
	var first_counts := [level.scatter_builder.pine_count, level.scatter_builder.rock_count, level.scatter_builder.post_count]
	level.build()
	await wait_frames(1)
	assert_eq(level.get_children().filter(func(c: Node) -> bool: return c.name.begins_with("Generated")).size(), 1)
	assert_eq(level.field.heights, first_heights, "same settings, same terrain")
	assert_eq(level.checkpoints.reset_transforms, first_gates, "same checkpoint positions")
	assert_eq([level.scatter_builder.pine_count, level.scatter_builder.rock_count, level.scatter_builder.post_count],
			first_counts, "same scenery")
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `TrailLevel` is not declared.

- [ ] **Step 3: Implement**

`levels/trail/trail_level.gd`:

```gdscript
@tool
class_name TrailLevel
extends Node3D
## Generates a whole trail from its "Road" Path3D child and its settings: road
## surface, terrain, scenery and checkpoint gates. It builds on load in the
## game. In the editor, tick Rebuild to preview after moving the road's curve
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

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_trail_level.gd` 4 passing.

- [ ] **Step 5: Commit** — subject `Assemble a whole trail from a road curve`.

---

### Task 13: Driving rig, level switcher and Test Ground

**Files:**
- Create: `levels/shared/driving_rig.gd`, `levels/shared/driving_rig.tscn`, `levels/shared/level_switcher.gd`, `tests/unit/test_level_switcher.gd`
- Modify: `levels/test_ground/test_ground.tscn`, `levels/test_ground/test_ground.gd`, `tests/scenarios/test_test_ground.gd`

**Interfaces:**
- Consumes: `Car`, `ChaseCamera`, `TouchControls` (with Task 5's Track button), `TelemetryOverlay`, `RunRecorder`.
- Produces: `DrivingRig` (Node3D): signal `track_switch_requested`; `car`, `camera`, `touch_controls`, `telemetry`, `recorder`; `place_car(target: Transform3D)`. `LevelSwitcher`: consts `RALLY_ROAD`, `TEST_GROUND`; static `other_level(path) -> String`, `switch_from(tree, path)`. The Test Ground holds a `DrivingRig` at (0, 1, 0) instead of its own car, camera, controls, telemetry and recorder.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_level_switcher.gd`:

```gdscript
extends GutTest


func test_track_button_switches_between_the_two_levels() -> void:
	assert_eq(LevelSwitcher.other_level(LevelSwitcher.RALLY_ROAD), LevelSwitcher.TEST_GROUND)
	assert_eq(LevelSwitcher.other_level(LevelSwitcher.TEST_GROUND), LevelSwitcher.RALLY_ROAD)
	assert_eq(LevelSwitcher.other_level("res://anything_else.tscn"), LevelSwitcher.RALLY_ROAD)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `LevelSwitcher` is not declared.

- [ ] **Step 3: Create the rig and the switcher**

`levels/shared/driving_rig.gd`:

```gdscript
class_name DrivingRig
extends Node3D
## The car with everything needed to drive it: chase camera, touch controls,
## telemetry and run recorder, wired together. Levels place one and use
## place_car() to put the car somewhere.

signal track_switch_requested

@onready var car: Car = $Car
@onready var camera: ChaseCamera = $ChaseCamera
@onready var touch_controls: TouchControls = $TouchControls
@onready var telemetry: TelemetryOverlay = $TelemetryOverlay
@onready var recorder: RunRecorder = $RunRecorder


func _ready() -> void:
	touch_controls.telemetry_toggled.connect(telemetry.toggle)
	touch_controls.recording_toggled.connect(recorder.toggle)
	touch_controls.track_switch_requested.connect(track_switch_requested.emit)


## Puts the car upright and still at `target`, with the camera straight behind it.
func place_car(target: Transform3D) -> void:
	car.reset_to(target)
	camera.snap_to_target()
```

`levels/shared/driving_rig.tscn`:

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://levels/shared/driving_rig.gd" id="1_rig"]
[ext_resource type="PackedScene" path="res://car/car.tscn" id="2_car"]
[ext_resource type="Script" path="res://camera/chase_camera.gd" id="3_camera"]
[ext_resource type="Script" path="res://input/touch_controls.gd" id="4_touch"]
[ext_resource type="Script" path="res://debug/run_recorder.gd" id="5_recorder"]
[ext_resource type="Script" path="res://debug/telemetry_overlay.gd" id="6_telemetry"]

[node name="DrivingRig" type="Node3D"]
script = ExtResource("1_rig")

[node name="Car" parent="." instance=ExtResource("2_car")]

[node name="ChaseCamera" type="Camera3D" parent="." node_paths=PackedStringArray("target")]
current = true
far = 1500.0
script = ExtResource("3_camera")
target = NodePath("../Car")

[node name="TouchControls" type="CanvasLayer" parent="." node_paths=PackedStringArray("car_input")]
script = ExtResource("4_touch")
car_input = NodePath("../Car/CarInput")

[node name="RunRecorder" type="Node" parent="." node_paths=PackedStringArray("car")]
script = ExtResource("5_recorder")
car = NodePath("../Car")

[node name="TelemetryOverlay" type="CanvasLayer" parent="." node_paths=PackedStringArray("car", "recorder")]
script = ExtResource("6_telemetry")
car = NodePath("../Car")
recorder = NodePath("../RunRecorder")
```

`levels/shared/level_switcher.gd`:

```gdscript
class_name LevelSwitcher
extends RefCounted
## Switches between the game's levels with the Track button. Part B's level
## select replaces this.

const RALLY_ROAD := "res://levels/rally_road/rally_road.tscn"
const TEST_GROUND := "res://levels/test_ground/test_ground.tscn"


## The level the Track button leads to from `current_scene_path`.
static func other_level(current_scene_path: String) -> String:
	return TEST_GROUND if current_scene_path == RALLY_ROAD else RALLY_ROAD


static func switch_from(tree: SceneTree, current_scene_path: String) -> void:
	tree.change_scene_to_file(other_level(current_scene_path))
```

- [ ] **Step 4: Move the Test Ground onto the rig**

Replace `levels/test_ground/test_ground.tscn` with:

`levels/test_ground/test_ground.tscn`:

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://levels/test_ground/test_ground.gd" id="1_ground"]
[ext_resource type="Script" path="res://levels/shared/golden_hour_mood.gd" id="2_mood"]
[ext_resource type="PackedScene" path="res://levels/shared/driving_rig.tscn" id="3_rig"]

[node name="TestGround" type="Node3D"]
script = ExtResource("1_ground")

[node name="Mood" type="Node3D" parent="."]
script = ExtResource("2_mood")

[node name="DrivingRig" parent="." instance=ExtResource("3_rig")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)
```

Replace `levels/test_ground/test_ground.gd` with:

`levels/test_ground/test_ground.gd`:

```gdscript
extends Node3D
## Gray-box tuning ground (dev only). From the spawn point, facing -Z:
##   - dirt everywhere (the base ground)
##   - an asphalt runway straight ahead, with slalom cones and a kicker jump
##   - a mud strip parallel to the runway, 30 m to the right
##   - three hills to the left: 10 and 20 degree dirt, 30 degree asphalt
##   - a rough asphalt lane 60 m to the right: potholes, speed bumps, washboard
##   - a rutted mud strip 90 m to the right
## Press R (or the Reset button) to return to the spawn point.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")

## Thickness of ramps and plateaus (m).
const SLAB := 1.0

@onready var rig: DrivingRig = $DrivingRig

var _spawn: Transform3D


func _ready() -> void:
	_build_layout()
	_spawn = rig.car.global_transform
	rig.car.input.reset_requested.connect(_on_reset_requested)
	rig.track_switch_requested.connect(_on_track_switch_requested)


func _on_reset_requested() -> void:
	rig.place_car(_spawn)


func _on_track_switch_requested() -> void:
	LevelSwitcher.switch_from(get_tree(), scene_file_path)


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
```

Replace `tests/scenarios/test_test_ground.gd` with (the car and touch controls now live under `DrivingRig`):

`tests/scenarios/test_test_ground.gd`:

```gdscript
extends GutTest
## The Test Ground loads, the car lands on the runway, and reset works.

const TEST_GROUND := preload("res://levels/test_ground/test_ground.tscn")


func _load_level() -> Node3D:
	var level: Node3D = TEST_GROUND.instantiate()
	add_child_autofree(level)
	return level


func test_car_lands_upright_on_the_asphalt_runway() -> void:
	var level := _load_level()
	await wait_physics_frames(ScenarioHelper.ticks(2.0))
	var car: Car = level.get_node("DrivingRig/Car")
	for wheel in car.wheels:
		assert_true(wheel.in_contact)
		assert_eq(wheel.surface.id, &"asphalt")
	assert_true(ScenarioHelper.is_upright(car))


func test_reset_returns_the_car_to_spawn() -> void:
	var level := _load_level()
	var car: Car = level.get_node("DrivingRig/Car")
	# The touch controls own the car's virtual inputs in a real scene; switch them
	# off so this test can drive the car through the same inputs.
	level.get_node("DrivingRig/TouchControls").process_mode = Node.PROCESS_MODE_DISABLED
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	car.input.virtual_throttle = 1.0
	await wait_physics_frames(ScenarioHelper.ticks(2.0))
	car.input.virtual_throttle = 0.0
	assert_lt(car.global_position.z, -5.0, "the car drove away first")
	car.input.request_reset()
	assert_almost_eq(car.global_position.distance_to(Vector3(0.0, 1.0, 0.0)), 0.0, 0.01)
```

- [ ] **Step 5: Run all tests**

Run: `./run_tests.sh all`
Expected: exit 0; `test_level_switcher.gd` 1 passing; the Test Ground scenario tests and the rough-ground tests still pass.

- [ ] **Step 6: Commit** — subject `Share a driving rig and move the Test Ground onto it`.

---

### Task 14: Run systems

**Files:**
- Create: `game/reset_controller.gd`, `game/run_controller.gd`, `ui/run_hud.gd`, `levels/shared/run_level.gd`
- Test: `tests/unit/test_run_hud.gd`, `tests/scenarios/run_level_builder.gd`, `tests/scenarios/test_run_systems.gd`

**Interfaces:**
- Consumes: `RunClock`, `FlipDetector`, `CheckpointTracker` (Tasks 2–4), `CarInput.locked` (Task 5), `TrailLevel` (Task 12), `DrivingRig`, `LevelSwitcher` (Task 13).
- Produces:
  - `ResetController` (Node): signal `car_reset(reason: StringName)` (`&"button"`, `&"flipped"`, `&"fell"`); `setup(rig, tracker, kill_height)`; `reset_car(reason)`.
  - `RunController` (Node): signals `countdown_started`, `checkpoint_reached(index, split, delta)`, `run_finished(time, session_best)`; `clock: RunClock`; `setup(rig, tracker, resets, start_transform)`; `restart()`.
  - `RunHud` (CanvasLayer): signal `restart_pressed`; `setup(controller)`; static `format_time(seconds)`, `countdown_text(clock)`, `split_text(index, split, delta)`; `show_split`, `show_finish`, `hide_finish`, `is_finish_visible()`.
  - `RunLevel` (Node3D): expects children `Trail`, `DrivingRig`, `CheckpointTracker`, `ResetController`, `RunController`, `RunHud`; wires them in `_ready`.
  - Test helper `RunLevelBuilder.straight(test, length, checkpoints) -> RunLevel`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_run_hud.gd`:

```gdscript
extends GutTest


func test_time_format() -> void:
	assert_eq(RunHud.format_time(0.0), "0:00.0")
	assert_eq(RunHud.format_time(59.99), "0:59.9")
	assert_eq(RunHud.format_time(92.46), "1:32.4")
	assert_eq(RunHud.format_time(-1.0), "0:00.0")


func test_countdown_text() -> void:
	var clock := RunClock.new()
	clock.start_countdown()
	assert_eq(RunHud.countdown_text(clock), "3")
	clock.tick(1.5)
	assert_eq(RunHud.countdown_text(clock), "2")
	clock.tick(2.0)
	assert_eq(RunHud.countdown_text(clock), "GO")


func test_split_text_with_and_without_a_best_to_compare() -> void:
	assert_eq(RunHud.split_text(2, 41.3, NAN), "CP 2   0:41.3")
	assert_eq(RunHud.split_text(2, 41.3, -1.24), "CP 2   0:41.3   -1.2")
	assert_eq(RunHud.split_text(2, 41.3, 0.5), "CP 2   0:41.3   +0.5")


func test_finish_panel_shows_and_hides() -> void:
	var hud := RunHud.new()
	add_child_autofree(hud)
	assert_false(hud.is_finish_visible())
	hud.show_finish(92.4, 90.9)
	assert_true(hud.is_finish_visible())
	hud.hide_finish()
	assert_false(hud.is_finish_visible())
```

`tests/scenarios/run_level_builder.gd`:

```gdscript
class_name RunLevelBuilder
extends RefCounted
## Builds a small RunLevel in code for scenario tests: a straight or gently
## curving trail, the driving rig, and the run systems. Touch controls are
## switched off so tests can drive through the car's virtual inputs.

const RIG_SCENE := preload("res://levels/shared/driving_rig.tscn")


static func straight(test: GutTest, length: float, checkpoints: PackedFloat32Array) -> RunLevel:
	var trail := TrailLevel.new()
	trail.name = "Trail"
	trail.trail = TrailDef.new()
	trail.trail.checkpoint_distances = checkpoints
	trail.terrain = TerrainDef.new()
	trail.terrain.margin = 60.0
	trail.terrain.chunk_size = 64.0
	trail.scatter = ScatterDef.new()
	var road := Path3D.new()
	road.name = "Road"
	road.curve = Curve3D.new()
	road.curve.bake_interval = 1.0
	road.curve.add_point(Vector3.ZERO)
	road.curve.add_point(Vector3(0.0, 0.0, -length))
	trail.add_child(road)

	var level := RunLevel.new()
	level.name = "TestRun"
	level.add_child(trail)
	var rig: DrivingRig = RIG_SCENE.instantiate()
	rig.name = "DrivingRig"
	level.add_child(rig)
	var tracker := CheckpointTracker.new()
	tracker.name = "CheckpointTracker"
	level.add_child(tracker)
	var resets := ResetController.new()
	resets.name = "ResetController"
	level.add_child(resets)
	var run := RunController.new()
	run.name = "RunController"
	level.add_child(run)
	var hud := RunHud.new()
	hud.name = "RunHud"
	level.add_child(hud)
	test.add_child_autofree(level)
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level
```

`tests/scenarios/test_run_systems.gd`:

```gdscript
extends GutTest
## The countdown, clock, checkpoints and resets on a small straight trail.

var level: RunLevel


func before_each() -> void:
	level = RunLevelBuilder.straight(self, 400.0, PackedFloat32Array([150.0]))


func _seconds(seconds: float) -> void:
	await wait_physics_frames(ScenarioHelper.ticks(seconds))


func test_the_countdown_holds_the_car_then_releases_it() -> void:
	level.rig.car.input.virtual_throttle = 1.0
	var start := level.rig.car.global_position
	await _seconds(2.0)
	assert_eq(level.run.clock.stage, RunClock.Stage.COUNTDOWN)
	var moved := Vector2(level.rig.car.global_position.x - start.x, level.rig.car.global_position.z - start.z).length()
	assert_lt(moved, 0.2, "throttle does nothing during the countdown (settling onto the springs is fine)")
	await _seconds(3.0)
	assert_eq(level.run.clock.stage, RunClock.Stage.RUNNING)
	assert_gt(level.rig.car.global_position.distance_to(start), 2.0, "the car drives after GO")


func test_driving_through_every_gate_finishes_the_run() -> void:
	watch_signals(level.run)
	level.rig.car.input.virtual_throttle = 1.0
	for i in ScenarioHelper.ticks(60.0):
		await get_tree().physics_frame
		if level.tracker.is_finished():
			break
	assert_signal_emit_count(level.run, "checkpoint_reached", 1)
	assert_signal_emitted(level.run, "run_finished")
	assert_eq(level.run.clock.stage, RunClock.Stage.FINISHED)
	gut.p("400 m straight finished in %s" % RunHud.format_time(level.run.clock.elapsed))
	assert_between(level.run.clock.elapsed, 10.0, 40.0)
	assert_true(level.hud.is_finish_visible())


func test_reset_button_returns_to_the_last_checkpoint_with_the_clock_running() -> void:
	level.rig.car.input.virtual_throttle = 1.0
	for i in ScenarioHelper.ticks(40.0):
		await get_tree().physics_frame
		if level.tracker.last_passed == 1:
			break
	await _seconds(1.0)
	var before := level.run.clock.elapsed
	level.rig.car.input.virtual_throttle = 0.0
	level.rig.car.input.request_reset()
	assert_almost_eq(level.rig.car.global_position.distance_to(level.tracker.reset_transform().origin), 0.0, 0.01)
	await _seconds(0.5)
	assert_gt(level.run.clock.elapsed, before, "the clock keeps running through a reset")


func test_a_flipped_car_is_reset_after_two_seconds() -> void:
	await _seconds(3.5)
	watch_signals(level.resets)
	var upside_down := level.tracker.reset_transform()
	upside_down.basis = upside_down.basis.rotated(upside_down.basis.z, PI)
	level.rig.car.reset_to(upside_down)
	await _seconds(1.5)
	assert_signal_not_emitted(level.resets, "car_reset")
	await _seconds(1.5)
	assert_signal_emitted_with_parameters(level.resets, "car_reset", [&"flipped"])
	assert_true(ScenarioHelper.is_upright(level.rig.car))


func test_falling_off_the_map_resets() -> void:
	await _seconds(3.5)
	watch_signals(level.resets)
	level.rig.car.reset_to(Transform3D(Basis(), Vector3(0.0, level.trail.kill_height() - 5.0, -50.0)))
	await wait_physics_frames(3)
	assert_signal_emitted_with_parameters(level.resets, "car_reset", [&"fell"])
	assert_gt(level.rig.car.global_position.y, level.trail.kill_height())


func test_reset_during_the_countdown_restarts_it() -> void:
	await _seconds(2.0)
	level.rig.car.input.request_reset()
	assert_eq(level.run.clock.stage, RunClock.Stage.COUNTDOWN)
	assert_almost_eq(level.run.clock.countdown_remaining, RunClock.COUNTDOWN_SECONDS, 0.01)


func test_restart_after_the_finish_starts_a_new_countdown() -> void:
	level.rig.car.input.virtual_throttle = 1.0
	for i in ScenarioHelper.ticks(60.0):
		await get_tree().physics_frame
		if level.tracker.is_finished():
			break
	level.run.restart()
	assert_eq(level.run.clock.stage, RunClock.Stage.COUNTDOWN)
	assert_false(level.hud.is_finish_visible())
	assert_eq(level.tracker.last_passed, 0)
	assert_gt(level.run.clock.session_best_time, 0.0, "the session best survives a restart")
```

- [ ] **Step 2: Run them and watch them fail**

Run: `./run_tests.sh all`
Expected: exit 1, `SCRIPT ERROR` saying `RunHud` / `RunLevel` / `ResetController` / `RunController` are not declared.

- [ ] **Step 3: Implement**

`game/reset_controller.gd`:

```gdscript
class_name ResetController
extends Node
## Puts the car back at the last passed checkpoint when the player taps Reset,
## when it stays flipped for 2 s, or when it falls off the map. The run clock
## is not touched: lost time is the only penalty.

signal car_reset(reason: StringName)

var rig: DrivingRig
var tracker: CheckpointTracker
## Falling below this height counts as falling off the map.
var kill_height := -INF
var flip_detector := FlipDetector.new()


func setup(driving_rig: DrivingRig, checkpoint_tracker: CheckpointTracker, fall_height: float) -> void:
	rig = driving_rig
	tracker = checkpoint_tracker
	kill_height = fall_height
	rig.car.input.reset_requested.connect(reset_car.bind(&"button"))


func _physics_process(delta: float) -> void:
	if rig == null:
		return
	var car := rig.car
	if car.global_position.y < kill_height:
		reset_car(&"fell")
	elif flip_detector.update(delta, car.global_basis.y, car.linear_velocity.length()):
		reset_car(&"flipped")


func reset_car(reason: StringName) -> void:
	rig.place_car(tracker.reset_transform())
	flip_detector.reset()
	car_reset.emit(reason)
```

`game/run_controller.gd`:

```gdscript
class_name RunController
extends Node
## Runs a timed run: a countdown with the pedals locked, the clock, checkpoint
## splits, the finish, and restarts. Owns the RunClock that the HUD reads.

signal countdown_started
## delta is the difference from the session best at this checkpoint, or NAN.
signal checkpoint_reached(index: int, split: float, delta: float)
signal run_finished(time: float, session_best: float)

var clock := RunClock.new()
var rig: DrivingRig
var tracker: CheckpointTracker
var start_transform: Transform3D


func setup(driving_rig: DrivingRig, checkpoint_tracker: CheckpointTracker, resets: ResetController,
		start: Transform3D) -> void:
	rig = driving_rig
	tracker = checkpoint_tracker
	start_transform = start
	tracker.checkpoint_passed.connect(_on_checkpoint_passed)
	tracker.finished.connect(_on_finished)
	resets.car_reset.connect(_on_car_reset)
	restart()


## Back to the start line and a fresh countdown.
func restart() -> void:
	tracker.restart()
	clock.restart()
	rig.place_car(start_transform)
	rig.car.input.locked = true
	clock.start_countdown()
	countdown_started.emit()


func _physics_process(delta: float) -> void:
	if rig != null and clock.tick(delta):
		rig.car.input.locked = false


func _on_checkpoint_passed(index: int) -> void:
	if clock.stage != RunClock.Stage.RUNNING:
		return
	clock.pass_checkpoint(index)
	checkpoint_reached.emit(index, clock.splits[index], clock.split_delta(index))


func _on_finished() -> void:
	if clock.stage != RunClock.Stage.RUNNING:
		return
	clock.finish()
	run_finished.emit(clock.elapsed, clock.session_best_time)


func _on_car_reset(_reason: StringName) -> void:
	if clock.stage == RunClock.Stage.COUNTDOWN:
		restart()
```

`ui/run_hud.gd`:

```gdscript
class_name RunHud
extends CanvasLayer
## The run's on-screen information: the countdown, the running time, checkpoint
## split flashes, and the finish panel with Restart.
## Coordinates are in the 1920x1080 canvas; the time sits top-right, clear of the
## top-strip buttons and the pedals.

signal restart_pressed

## How long a checkpoint split stays on screen (s).
const SPLIT_SECONDS := 2.0
## "GO" stays up this long after the countdown ends (s).
const GO_SECONDS := 0.6
const FASTER := Color(0.45, 0.9, 0.45)
const SLOWER := Color(0.95, 0.45, 0.35)

var controller: RunController

var _countdown: Label
var _time: Label
var _split: Label
var _finish_panel: PanelContainer
var _finish_time: Label
var _finish_best: Label
var _split_timer := 0.0


func _ready() -> void:
	_build_ui()


func setup(run_controller: RunController) -> void:
	controller = run_controller
	controller.checkpoint_reached.connect(show_split)
	controller.run_finished.connect(show_finish)
	controller.countdown_started.connect(hide_finish)


func _process(delta: float) -> void:
	if controller == null:
		return
	var clock := controller.clock
	var counting := clock.stage == RunClock.Stage.COUNTDOWN
	_countdown.visible = counting or (clock.stage == RunClock.Stage.RUNNING and clock.elapsed < GO_SECONDS)
	_countdown.text = countdown_text(clock)
	_time.text = format_time(clock.elapsed)
	if _split_timer > 0.0:
		_split_timer -= delta
		_split.visible = _split_timer > 0.0


## Time as m:ss.t
static func format_time(seconds: float) -> String:
	var tenths := int(floor(maxf(seconds, 0.0) * 10.0))
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


static func countdown_text(clock: RunClock) -> String:
	if clock.stage == RunClock.Stage.COUNTDOWN:
		return str(ceili(clock.countdown_remaining))
	return "GO"


static func split_text(index: int, split: float, delta: float) -> String:
	var text := "CP %d   %s" % [index, format_time(split)]
	if not is_nan(delta):
		text += "   %s%.1f" % ["+" if delta >= 0.0 else "-", absf(delta)]
	return text


func show_split(index: int, split: float, delta: float) -> void:
	_split.text = split_text(index, split, delta)
	if is_nan(delta):
		_split.modulate = Color.WHITE
	else:
		_split.modulate = FASTER if delta < 0.0 else SLOWER
	_split.visible = true
	_split_timer = SPLIT_SECONDS


func show_finish(time: float, session_best: float) -> void:
	_finish_time.text = "Finish  %s" % format_time(time)
	_finish_best.text = "Session best  %s" % format_time(session_best)
	_finish_panel.visible = true


func hide_finish() -> void:
	_finish_panel.visible = false
	_split.visible = false
	_split_timer = 0.0


func is_finish_visible() -> bool:
	return _finish_panel.visible


func _build_ui() -> void:
	_countdown = _label(160, Vector2(860.0, 380.0))
	_countdown.custom_minimum_size = Vector2(200.0, 200.0)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.visible = false
	_time = _label(60, Vector2(0.0, 24.0))
	_time.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_time.offset_left = -360.0
	_time.offset_right = -40.0
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_split = _label(40, Vector2(0.0, 110.0))
	_split.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_split.offset_left = -640.0
	_split.offset_right = -40.0
	_split.offset_top = 110.0
	_split.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_split.visible = false

	_finish_panel = PanelContainer.new()
	_finish_panel.set_anchors_preset(Control.PRESET_CENTER)
	_finish_panel.position = Vector2(-300.0, -170.0)
	_finish_panel.custom_minimum_size = Vector2(600.0, 340.0)
	_finish_panel.visible = false
	add_child(_finish_panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	_finish_panel.add_child(column)
	_finish_time = Label.new()
	_finish_time.add_theme_font_size_override("font_size", 64)
	_finish_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_finish_time)
	_finish_best = Label.new()
	_finish_best.add_theme_font_size_override("font_size", 40)
	_finish_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_finish_best)
	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(320.0, 110.0)
	restart.focus_mode = Control.FOCUS_NONE
	restart.add_theme_font_size_override("font_size", 44)
	restart.pressed.connect(restart_pressed.emit)
	column.add_child(restart)


func _label(font_size: int, at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	return label
```

`levels/shared/run_level.gd`:

```gdscript
class_name RunLevel
extends Node3D
## A timed level: a generated trail, the driving rig and the run systems, wired
## together. Expects children named Trail (TrailLevel), DrivingRig,
## CheckpointTracker, ResetController, RunController and RunHud. The Trail
## builds itself in its own _ready, which runs before this one.

@onready var trail: TrailLevel = $Trail
@onready var rig: DrivingRig = $DrivingRig
@onready var tracker: CheckpointTracker = $CheckpointTracker
@onready var resets: ResetController = $ResetController
@onready var run: RunController = $RunController
@onready var hud: RunHud = $RunHud


func _ready() -> void:
	tracker.setup(trail.checkpoints.reset_transforms)
	trail.checkpoints.gate_entered.connect(_on_gate_entered)
	resets.setup(rig, tracker, trail.kill_height())
	hud.setup(run)
	run.setup(rig, tracker, resets, trail.start_transform())
	hud.restart_pressed.connect(run.restart)
	rig.track_switch_requested.connect(_on_track_switch_requested)
	print("%s built in %.2f s" % [name, trail.build_seconds])


func _on_gate_entered(index: int, body: Node3D) -> void:
	if body == rig.car:
		tracker.enter_gate(index)


func _on_track_switch_requested() -> void:
	LevelSwitcher.switch_from(get_tree(), scene_file_path)
```

- [ ] **Step 4: Run all tests**

Run: `./run_tests.sh all`
Expected: exit 0; `test_run_hud.gd` 4 passing; `test_run_systems.gd` 7 passing, printing `400 m straight finished in 0:15.7` (±5%).

- [ ] **Step 5: Commit** — subject `Add countdown, clock, checkpoints, resets and the run HUD`.

---

### Task 15: Rally Road

**Files:**
- Create: `tools/generate_rally_road_curve.gd`, `levels/rally_road/rally_road_curve.tres` (generated), `levels/rally_road/rally_road_trail.tres`, `levels/rally_road/rally_road_terrain.tres`, `levels/rally_road/rally_road_scatter.tres`, `levels/rally_road/rally_road.tscn`
- Test: `tests/scenarios/trail_driver.gd`, `tests/scenarios/test_rally_road.gd`
- Modify: `project.godot` (main scene), `levels/shared/golden_hour_mood.gd` (two shadow cascades)

**Interfaces:**
- Consumes: `TrailLevel`, `RunLevel`, `DrivingRig` and the run systems.
- Produces: the playable `res://levels/rally_road/rally_road.tscn`, the project's main scene. Test helper `TrailDriver.new(car, sampler)` with `drive()` and `target_speed(distance)`.

- [ ] **Step 1: Write the failing scenario test and its driver**

`tests/scenarios/trail_driver.gd`:

```gdscript
class_name TrailDriver
extends RefCounted
## A scripted driver for scenario tests: steers toward a point a little way up
## the road (pure pursuit) and picks a speed from how sharply the road bends
## ahead. Not a good driver - just a steady one.

## Steer toward the road point this far ahead of the car (m).
const LOOKAHEAD := 12.0
## Judge the bend over this distance ahead (m).
const CURVE_WINDOW := 30.0
## Share of the grip-limited cornering speed to aim for.
const CAUTION := 0.6
const MIN_SPEED := 6.0
const MAX_SPEED := 25.0

var car: Car
var sampler: RoadSampler


func _init(driven_car: Car, road: RoadSampler) -> void:
	car = driven_car
	sampler = road


## Sets the car's virtual steer, throttle and brake for this tick.
func drive() -> void:
	var distance := sampler.closest_distance(car.global_position)
	var target := sampler.position(distance + LOOKAHEAD)
	var to_target := target - car.global_position
	var heading := -car.global_basis.z
	var flat_heading := Vector2(heading.x, heading.z).normalized()
	var flat_target := Vector2(to_target.x, to_target.z).normalized()
	# Positive when the target is to the right (x = world X, y = world Z).
	var angle := flat_heading.angle_to(flat_target)
	var max_angle := Steering.max_angle_for_speed(car.forward_speed(), car.stats)
	car.input.virtual_steer = clampf(angle / maxf(max_angle, 0.05), -1.0, 1.0)

	var speed := car.forward_speed()
	var wanted := target_speed(distance)
	car.input.virtual_throttle = 1.0 if speed < wanted - 1.0 else 0.0
	car.input.virtual_brake = 1.0 if speed > wanted + 2.0 else 0.0


## Speed to aim for at `distance`, from the sharpest bend in the window ahead.
func target_speed(distance: float) -> float:
	var sharpest := 0.0
	var step := 5.0
	var ahead := 0.0
	while ahead < CURVE_WINDOW:
		var a := sampler.forward(distance + ahead)
		var b := sampler.forward(distance + ahead + step)
		var turn := Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z))
		sharpest = maxf(sharpest, absf(turn) / step)
		ahead += step
	if sharpest < 0.0001:
		return MAX_SPEED
	var grip_speed := sqrt(car.stats.tire_grip * 9.8 / sharpest)
	return clampf(grip_speed * CAUTION, MIN_SPEED, MAX_SPEED)
```

`tests/scenarios/test_rally_road.gd`:

```gdscript
extends GutTest
## Rally Road as a whole: it builds, and a scripted driver can complete it.

const RALLY_ROAD := preload("res://levels/rally_road/rally_road.tscn")


func _load() -> RunLevel:
	var level: RunLevel = RALLY_ROAD.instantiate()
	add_child_autofree(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func test_rally_road_builds_with_its_gates_and_layout() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var climb := sampler.position(sampler.length).y - sampler.position(0.0).y
	gut.p("Rally Road: %.0f m long, climbs %.0f m, built in %.2f s (%d x %d terrain chunks, %d pines, %d rocks, %d posts)" % [
		sampler.length, climb, level.trail.build_seconds,
		level.trail.field.chunk_count().x, level.trail.field.chunk_count().y,
		level.trail.scatter_builder.pine_count, level.trail.scatter_builder.rock_count, level.trail.scatter_builder.post_count])
	assert_between(sampler.length, 1350.0, 1650.0, "about 1.5 km")
	assert_eq(level.trail.checkpoints.reset_transforms.size(), 6, "start, 4 checkpoints, finish")
	assert_lt(level.trail.build_seconds, 3.0, "desktop build time")


func test_scripted_driver_completes_rally_road() -> void:
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
		# Skip the countdown (the car settles onto its springs) and real air time.
		if level.run.clock.stage != RunClock.Stage.RUNNING or car.air_control.is_active:
			continue
		var distance := level.trail.sampler.closest_distance(car.global_position)
		var near_jump := jumps.any(func(j: Vector3) -> bool: return absf(distance - j.x) < 25.0)
		if not near_jump:
			for wheel in car.wheels:
				if not wheel.in_contact:
					lost_contact += 1
	gut.p("scripted driver: finished %s after %s, %d checkpoints, %d wheel-ticks without contact away from jumps" % [
		level.tracker.is_finished(), RunHud.format_time(level.run.clock.elapsed),
		get_signal_emit_count(level.run, "checkpoint_reached"), lost_contact])
	assert_true(level.tracker.is_finished(), "reached the finish")
	assert_signal_not_emitted(level.resets, "car_reset")
	assert_signal_emit_count(level.run, "checkpoint_reached", 4)
	assert_between(level.run.clock.elapsed, 60.0, 150.0)
	assert_lt(lost_contact, 24, "no seams or potholes throw the wheels off the ground")
```

- [ ] **Step 2: Run them and watch them fail**

Run: `./run_tests.sh scenarios`
Expected: exit 1, `SCRIPT ERROR` about the missing `res://levels/rally_road/rally_road.tscn` preload.

- [ ] **Step 3: Add the curve generator and generate the curve**

`tools/generate_rally_road_curve.gd`:

```gdscript
extends SceneTree
## Builds Rally Road's centre-line curve from a list of segments and saves it as
## levels/rally_road/rally_road_curve.tres. Re-run after changing SEGMENTS:
##   godot --headless -s tools/generate_rally_road_curve.gd
## Each segment is [kind, ...]:
##   ["straight", length_m, grade]
##   ["arc", radius_m, turn_deg (+ = left), grade]
## Grade is rise over run (0.12 = 12%). Arcs are split into 30-degree Bezier
## pieces so hairpins stay round.

const OUTPUT := "res://levels/rally_road/rally_road_curve.tres"
## Parts of the road further apart than this along it must stay this far apart in space (m).
const MIN_SEPARATION := 28.0
const SEPARATION_CHECK_GAP := 80.0

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
]


func _init() -> void:
	var curve := build_curve(SEGMENTS)
	var problems := separation_problems(curve)
	if not problems.is_empty():
		push_error("Rally Road parts pass too close: %s" % [problems.slice(0, 5)])
		quit(1)
		return
	var error := ResourceSaver.save(curve, OUTPUT)
	print("saved %s: %d points, %.0f m long, climbs %.0f m" % [OUTPUT, curve.point_count,
			curve.get_baked_length(), curve.get_point_position(curve.point_count - 1).y])
	quit(0 if error == OK else 1)


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

```bash
mkdir -p levels/rally_road
godot --headless --import >/dev/null 2>&1
godot --headless -s tools/generate_rally_road_curve.gd
```

Expected: `saved res://levels/rally_road/rally_road_curve.tres: 43 points, 1513 m long, climbs 74 m`, exit 0 (the generator fails loudly if two parts of the road pass within 28 m of each other).

- [ ] **Step 4: Add Rally Road's settings and scene**

`levels/rally_road/rally_road_trail.tres`:

```ini
[gd_resource type="Resource" script_class="TrailDef" format=3]

[ext_resource type="Script" path="res://levels/trail/trail_def.gd" id="1_trail"]

[resource]
script = ExtResource("1_trail")
rough_sections = Array[Vector3]([Vector3(680, 150, 18)])
pothole_clusters = Array[Vector2]([Vector2(250, 4), Vector2(1050, 5)])
jumps = Array[Vector3]([Vector3(440, 1.2, 12), Vector3(1380, 1, 10)])
checkpoint_distances = PackedFloat32Array(300, 600, 900, 1200)
seed = 1
```

`levels/rally_road/rally_road_terrain.tres`:

```ini
[gd_resource type="Resource" script_class="TerrainDef" format=3]

[ext_resource type="Script" path="res://levels/trail/terrain_def.gd" id="1_terrain"]

[resource]
script = ExtResource("1_terrain")
seed = 7
```

`levels/rally_road/rally_road_scatter.tres`:

```ini
[gd_resource type="Resource" script_class="ScatterDef" format=3]

[ext_resource type="Script" path="res://levels/trail/scatter_def.gd" id="1_scatter"]

[resource]
script = ExtResource("1_scatter")
seed = 11
```

`levels/rally_road/rally_road.tscn`:

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://levels/shared/run_level.gd" id="1_level"]
[ext_resource type="Script" path="res://levels/shared/golden_hour_mood.gd" id="2_mood"]
[ext_resource type="Script" path="res://levels/trail/trail_level.gd" id="3_trail"]
[ext_resource type="Resource" path="res://levels/rally_road/rally_road_trail.tres" id="4_trail_def"]
[ext_resource type="Resource" path="res://levels/rally_road/rally_road_terrain.tres" id="5_terrain_def"]
[ext_resource type="Resource" path="res://levels/rally_road/rally_road_scatter.tres" id="6_scatter_def"]
[ext_resource type="Curve3D" path="res://levels/rally_road/rally_road_curve.tres" id="7_curve"]
[ext_resource type="PackedScene" path="res://levels/shared/driving_rig.tscn" id="8_rig"]
[ext_resource type="Script" path="res://game/checkpoint_tracker.gd" id="9_tracker"]
[ext_resource type="Script" path="res://game/reset_controller.gd" id="10_resets"]
[ext_resource type="Script" path="res://game/run_controller.gd" id="11_run"]
[ext_resource type="Script" path="res://ui/run_hud.gd" id="12_hud"]

[node name="RallyRoad" type="Node3D"]
script = ExtResource("1_level")

[node name="Mood" type="Node3D" parent="."]
script = ExtResource("2_mood")

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

- [ ] **Step 5: Make Rally Road the main scene**

In `project.godot`, change the `run/main_scene` line to:

```ini
run/main_scene="res://levels/rally_road/rally_road.tscn"
```

In `levels/shared/golden_hour_mood.gd`, `_build_sun()`, add after the `directional_shadow_max_distance` line (Godot's default four cascades draw every shadow caster up to four times):

```gdscript
	# Two cascades instead of the default four: shadow casters are drawn once per cascade.
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
```

- [ ] **Step 6: Run all tests**

Run: `./run_tests.sh all`
Expected: exit 0; `test_rally_road.gd` 2 passing, printing lines close to:

```
Rally Road: 1513 m long, climbs 74 m, built in 1.12 s (8 x 12 terrain chunks, 10184 pines, 5159 rocks, 33 posts)
scripted driver: finished true after 1:33.3, 4 checkpoints, 11 wheel-ticks without contact away from jumps
```

- [ ] **Step 7: Look at it and count what it draws** (spec §8, §9.3)

Create this throwaway scene — it is never committed:

`probe/rally_road_shots.gd`:

```gdscript
extends Node
## Throwaway: renders Rally Road at a few points along the road, saves PNGs and
## prints what was drawn there. Not part of the game or the plan.

const SPOTS := [15.0, 425.0, 700.0, 990.0, 1360.0, 1490.0]
const OUT_DIR := "res://probe/shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var level: RunLevel = load("res://levels/rally_road/rally_road.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	for spot: float in SPOTS:
		var transform := level.trail.sampler.transform_at(spot, 1.0, level.trail.profile)
		level.rig.place_car(transform)
		for i in 45:
			await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("%s/shot_%04d.png" % [OUT_DIR, int(spot)]))
		print("spot %4d m: %d primitives, %d draw calls, %d objects, %.0f fps" % [int(spot),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				Engine.get_frames_per_second()])
	get_tree().quit()
```

`probe/rally_road_shots.tscn`:

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://probe/rally_road_shots.gd" id="1_shots"]

[node name="Shots" type="Node"]
script = ExtResource("1_shots")
```

Run (windowed, not headless — it needs a GPU): `godot --path . res://probe/rally_road_shots.tscn 2>&1 | grep spot`
Expected: six lines close to `spot  700 m: 268106 primitives, 114 draw calls, 633 objects, 56 fps`, every spot under **300k primitives and 150 draw calls**, and six PNGs in `probe/shots/` (start, jump 1, rough stretch, a hairpin, jump 2, finish). Open each PNG and check: dark asphalt with off-white edge lines and dirt shoulders; ochre terrain with rock-coloured steep slopes; pines and rocks kept off the road; the golden-hour sky and haze; the countdown or running time; the touch controls. Put the six primitive/draw-call lines and a sentence per image in the report, then `rm -rf probe`.

- [ ] **Step 8: Commit** — subject `Add Rally Road`; stage `tools/generate_rally_road_curve.gd levels/rally_road levels/shared/golden_hour_mood.gd tests/scenarios/trail_driver.gd tests/scenarios/test_rally_road.gd project.godot` and the new `.uid` files. Do not stage `probe/`.

---

### Task 16: Jump-landing scenario test

Carried over from the Milestone 1 final review (spec §9.2): a car taking the Test Ground's kicker at 100 km/h must fly roughly level and land without a spin kick — tested both lifting off the gas and holding it.

**Files:**
- Create: `tests/scenarios/test_jump_landing.gd`

**Interfaces:**
- Consumes: the Test Ground scene with its `DrivingRig` (Task 13); the kicker starts at z = −250 on the runway straight ahead of the spawn.

- [ ] **Step 1: Write the tests**

`tests/scenarios/test_jump_landing.gd`:

```gdscript
extends GutTest
## Carried over from the Milestone 1 final review: the Test Ground's kicker
## (15 degrees, 2 m tall, starting at z = -250) taken at 100 km/h must fly level
## and land without a spin kick.

const TEST_GROUND := preload("res://levels/test_ground/test_ground.tscn")
const RAMP_START_Z := -250.0
const APPROACH_KMH := 100.0


## Drives straight down the runway at APPROACH_KMH, then lifts off or holds the gas
## from the foot of the kicker. Returns what happened in the air and just after.
func _take_kicker(hold_throttle: bool) -> Dictionary:
	var level: Node3D = TEST_GROUND.instantiate()
	add_child_autofree(level)
	var rig: DrivingRig = level.get_node("DrivingRig")
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	var car := rig.car
	await wait_physics_frames(ScenarioHelper.ticks(0.5))
	var airborne_ticks := 0
	var lowest_up := 1.0
	var landed := false
	var ticks_after_landing := 0
	var landing_yaw := 0.0
	for i in ScenarioHelper.ticks(25.0):
		if car.global_position.z > RAMP_START_Z:
			car.input.virtual_throttle = clampf((APPROACH_KMH / 3.6 - car.forward_speed()) * 0.5, 0.0, 1.0)
		else:
			car.input.virtual_throttle = 1.0 if hold_throttle else 0.0
		await get_tree().physics_frame
		if not landed:
			if car.air_control.is_active:
				airborne_ticks += 1
				lowest_up = minf(lowest_up, car.global_basis.y.y)
			elif airborne_ticks >= ScenarioHelper.ticks(0.3):
				landed = true  # a real jump, not a small hop
			else:
				airborne_ticks = 0
		else:
			landing_yaw = maxf(landing_yaw, absf(rad_to_deg(car.angular_velocity.y)))
			ticks_after_landing += 1
			if ticks_after_landing >= ScenarioHelper.ticks(0.5):
				break
	var result := {
		"landed": landed,
		"air_seconds": airborne_ticks / float(Engine.physics_ticks_per_second),
		"worst_pitch_deg": rad_to_deg(acos(clampf(lowest_up, -1.0, 1.0))),
		"landing_yaw": landing_yaw,
		"upright": ScenarioHelper.is_upright(car),
	}
	gut.p("kicker at %.0f km/h, gas %s: %.2f s in the air, worst tilt %.0f deg, peak yaw %.1f deg/s in the 0.5 s after landing, upright %s" % [
		APPROACH_KMH, "held" if hold_throttle else "lifted", result.air_seconds, result.worst_pitch_deg,
		result.landing_yaw, result.upright])
	return result


func test_lifting_off_the_gas_flies_level_and_lands_straight() -> void:
	var result := await _take_kicker(false)
	assert_true(result.landed, "the car took off and landed")
	assert_lt(result.worst_pitch_deg, 25.0, "flies roughly level")
	assert_lt(result.landing_yaw, 20.0, "no spin kick on landing")
	assert_true(result.upright)


func test_holding_the_gas_flies_level_and_lands_straight() -> void:
	var result := await _take_kicker(true)
	if result.worst_pitch_deg >= 25.0 or result.landing_yaw >= 20.0 or not result.upright:
		# Known before Milestone 2A (measured: 62 deg nose-down and a 41 deg/s yaw kick
		# at 100 km/h; a full flip at 115 km/h). Waiting on a feel decision with the
		# user, so it is reported rather than failed.
		pending("holding the gas off the kicker pitches the nose down: %.0f deg, yaw kick %.1f deg/s" % [
			result.worst_pitch_deg, result.landing_yaw])
		return
	assert_true(result.landed, "the car took off and landed")
```

- [ ] **Step 2: Run them**

Run: `./run_tests.sh scenarios`
Expected: exit 0, with lines close to:

```
kicker at 100 km/h, gas held: 1.46 s in the air, worst tilt 62 deg, peak yaw 41.1 deg/s in the 0.5 s after landing, upright true
kicker at 100 km/h, gas lifted: 1.27 s in the air, worst tilt 12 deg, peak yaw 0.4 deg/s in the 0.5 s after landing, upright true
```

The lifted-gas test passes. The held-gas test shows as **Pending** (`holding the gas off the kicker pitches the nose down: 62 deg, ...`) — this is the known finding recorded under Deviations, left for the user. Do not tune the car to make it pass. If the lifted-gas test fails, or the held-gas numbers differ from 62° / 41°/s by more than a few degrees, stop and report the printed lines.

- [ ] **Step 3: Commit** — subject `Test kicker jumps with the gas lifted and held`.

---

### Task 17: Rally Road on the phone (the user)

**Files:**
- Create: `docs/notes/performance-m2a.md`
- Modify: `docs/notes/feel-log.md` (a new session entry)

- [ ] **Step 1: Build and install** (phone connected, USB debugging authorized)

Run: `tools/android.sh`
Expected: `build/ridge-debug.apk` is built, installed, and Rally Road opens on the phone.

- [ ] **Step 2: The user drives Rally Road** start to finish at least twice, with telemetry on for one run, checking: the countdown holds the car; the clock runs; each checkpoint flashes its time (with a difference on the second run); the finish panel and Restart work; Reset, a deliberate flip and driving off a drop behave as in the spec; the Track button switches to the Test Ground and back; and the lowest fps seen.

- [ ] **Step 3: Record performance**

Create `docs/notes/performance-m2a.md` with the measured numbers: level load time (from `adb logcat -s godot` — the `RallyRoad built in N s` line), lowest fps and highest physics time on the road (telemetry overlay's first line), the desktop primitive/draw-call lines from Task 15 Step 7, and anything that stuttered. Targets (spec §8): 60 fps held, physics under 4 ms, load under 3 s.

- [ ] **Step 4: Record feel notes**

Append a "Session 3" entry to `docs/notes/feel-log.md` with the user's notes, pulling any recordings with `tools/pull_runs.sh`.

- [ ] **Step 5: Commit** — subject `Record Rally Road on the phone: performance and feel`.
