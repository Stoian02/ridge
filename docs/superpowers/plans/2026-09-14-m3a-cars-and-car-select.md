# Milestone 3 Part A — Cars and Car Select Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a car select screen and two unlockable cars, an Off-road 4x4 and a Rally Car Tuned, with differential locks and low-poly bodies. The stock Rally Car must drive exactly as it does today.

**Architecture:**
- A `CarDef` resource per car in a `CarCatalog`. `GameState` knows the selected car and the scene car select will start, and the `DrivingRig` puts the chosen car's stats and body into the one shared `car.tscn` before the car sets itself up.
- Differential locks are a pure `Drivetrain.lock_transfer` that `Car` applies to the per-wheel drive torque; all locks default to 0.
- Bodies are built in code by `CarBodyBuilder` from a `CarBodyDef`.

**Tech Stack:** Godot 4.7.2 (Mobile renderer, Jolt physics at 120 ticks/s), typed GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-09-14-m3a-cars-and-car-select-design.md`

## Global Constraints

- **Typed GDScript:** every variable has a type or is inferred with `:=`. A loop over an array literal names its type (`for side: float in [...]`). Indent with tabs. Doc comments use `##`.
- **The stock Rally Car stays exactly as it is:**
  - `car/rally_car.tres` is never edited, and its differential locks stay at the default 0.
  - Every existing car and level test keeps passing. The only existing tests that change are those whose screen flow changes: the level select and Free Drive routing in `test_menus.gd`, Next level in `test_rally_road.gd`, and the kicker helper gaining a car parameter.
- **Car physics:** the only car-physics changes are the ones in spec §4, which the owner approved: the differential locks and the two new cars' stats.
- **Font:** the menu font has no ★ character, so write "stars" in text.
- **Tests:** `./run_tests.sh unit`, `./run_tests.sh scenarios` or `./run_tests.sh all`. A run fails on any failing test or any `SCRIPT ERROR`. After adding a file with a new `class_name`, run `godot --headless --import` once before running tests. The shell is zsh: write commands out in full.
- **Budgets:** (spec §7, M2 notes) 60 fps; < 300k triangles and < 150 draw calls on screen; < 3 s level load. Muddy Valley's current peak is 286,336 primitives.
- **Commits:**
  - Stage files by name. Never `git add -A` or `git add .`.
  - Never stage or change `tmux-session.sh`.
  - Commit the `.uid` files Godot creates next to new scripts.
  - Every commit message ends with a blank line and then these two lines, using the name of the model that wrote the commit:
    ```
    Co-Authored-By: Claude <model name> <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_01RhfJavT34eWyW3enLLKWgH
    ```

## Decisions made while verifying this plan

The code below was written and run in a scratch clone before this plan was written. These choices refine the spec:

- **Lock strength scales the lock's torque limit, not its rate.** `lock_transfer` returns the torque that would equalise the two sides within the tick, capped at `lock × diff_lock_max_torque`. Scaling the rate instead would make even a 0.3 limited-slip lock close 30% of the gap every tick, which is effectively locked at 120 Hz.
- **Why the locked-pair stability test allows a 10 rad/s gap:** a lock acts on last tick's wheel speeds, so each tick's difference in tire force opens a small, bounded gap before it closes.
- **The lower body tapers only over the first and last 22% of its length,** so it keeps the car's full width in the middle. The shared triangle helper lights each part's faces away from that part's own centre, which is already tested in `test_low_poly_meshes.gd`. So the body tests check for real triangle area and unit normals, not whole-mesh outwardness, since the cabin's hidden bottom faces point inward.
- **Extras may extend up to 0.4 m past the footprint:** the 4x4's bull bar and spare wheel reach about 0.38 m.
- **Locked cars read "Earn 3 stars to unlock (you have 2)":** the menu font has no ★.
- **Change car in a level built by a test** (with no scene path) just restarts the run.
- **The tuned car keeps stock's 0.35 m suspension travel (the spec proposed 0.30 m).** At 0.30 m its body touched Muddy Valley's rutted mud on 16,947 ticks of one scripted lap; at 0.35 m it touched on 63. It still sits lower through its centre of mass (−0.18 m against −0.15 m), with stiffer springs, dampers and anti-roll bars.
- **The tuned car has no differential locks for now (the spec proposed 0.15 front and 0.35 rear).**
  - **With them:** on Muddy Valley the tuned car ran wide out of the first mud stretch and stopped nose-down against the creek's road-side bank at 891 m, 9.5 m right of the road, at full throttle.
  - **Measured without them:** it finishes in 1:38.2 and is never stuck. Putting stock springs, dampers and anti-roll bars back as well changed little (1:38.5).
  - **Revisit:** limited-slip locks come back when the owner tunes the car on the phone.
- **The scripted driver gains an opt-in surface-aware mode** (`TrailDriver.new(car, sampler, profile)`). Given the road profile, it slows for the lowest surface grip in the window ahead, as the car feels it (the surface's grip times its grip-table multiplier), on straights as well as bends.
  - Without a profile it behaves exactly as before, so the existing stock-car scenarios and their times are unchanged.
  - The new cars use it on Muddy Valley. The plain driver judges speed by tire grip alone, so the grippier tuned car reached the hedged mud too fast, slid into a hedge and stayed pinned: it never reverses.
- **Found while verifying, left for the owner:** on Muddy Valley's final mud climb, the undulation (±9 cm) and the 8 cm ruts combine into wheel-track dips 15–17 cm deep and about 6 m long (1380–1383 m, 1405–1408 m). Driving out of one is like a short 13% ramp in mud, which can stop a car and roll it back. The owner saw this on the phone. It is a level change, so it is not part of this plan.

## Verified results (scratch clone, desktop)

| Check | Result |
|---|---|
| Unit suite | 360 passing (before Task 7's scenario file) |
| Stock Rally Car unchanged | Rally Road 1:30.3 and Muddy Valley 1:41.7 with the scripted driver, as on master |
| Scripted driver, Rally Road | Rally Car 1:30.3 · Rally Car Tuned 1:26.3 · Off-road 4x4 1:40.8 (no resets) |
| Scripted driver, Muddy Valley (surface-aware for the new cars) | Rally Car Tuned 1:38.2 · Off-road 4x4 1:35.0 (no resets) |
| 0–100 km/h on flat asphalt | stock 7.49 s, tuned 5.14 s |
| Mud climb from a standstill at 1400 m | Rally Car 16.6 s, 4x4 11.6 s |
| Left wheels on slick ground, 4 s from rest | 4x4 with locks 10.0 m, with open diffs 1.9 m |
| 4x4 at full lock, ~40 km/h, flat dirt | most tilt 3° |
| Test Ground kicker at 100 km/h, gas lifted | tuned and 4x4 both land upright (worst tilt 12° and 16°) |
| Render counts (desktop, chase camera) | Rally Road with the tuned car 268,816 prims / 127 draws at 15 m; Muddy Valley at 560 m 286,944 (4x4) and 286,588 (Rally Car), 128 draws |
| Desktop build time | Rally Road 1.20 s, Muddy Valley 1.86 s |

## File map

| File | Task | Responsibility |
|---|---|---|
| `car/car_stats.gd`, `car/drivetrain.gd`, `car/car.gd` | 1 | differential lock settings, `lock_transfer`, applying it |
| `car/car_body_def.gd`, `car/car_body_builder.gd`, `car/car.gd`, `car/wheel.gd` | 2 | new: body look and builder; the car wears it; rim colour |
| `car/car_def.gd`, `car/car_catalog.gd`, `car/cars/*.tres`, `car/car_catalog.tres`, `car/offroad_4x4.tres`, `car/rally_car_tuned.tres`, `surfaces/grip_table.tres` | 3 | new: the three cars as data |
| `game/progress.gd`, `game/game_state.gd`, `tests/scenarios/save_sandbox.gd` | 3 | selected car, unlocks, `choose_car_for` |
| `levels/shared/driving_rig.gd`, `debug/run_recorder.gd` | 4 | the rig drives the chosen car; recordings named after it |
| `game/level_def.gd`, level `.tres`, `ui/car_preview.gd`, `ui/car_select.gd`, `ui/car_select.tscn`, `ui/level_select.gd`, `ui/main_menu.gd` | 5 | car select screen and routing into it |
| `ui/pause_menu.gd`, `ui/results_screen.gd`, `levels/shared/run_level.gd`, `levels/test_ground/test_ground.gd` | 6 | Change car, the unlock notice, Next level through car select |
| `tests/scenarios/trail_driver.gd`, `tests/scenarios/test_cars.gd`, `tests/scenarios/test_jump_landing.gd`, `tools/level_shots.gd`, `docs/notes/performance-m3a.md` | 7 | surface-aware scripted driver, whole-car scenarios, screenshots and notes |

---

### Task 1: Differential locks

**Files:**
- Modify: `car/car_stats.gd`, `car/drivetrain.gd`, `car/car.gd`
- Test: `tests/unit/test_drivetrain.gd` (append)

**Interfaces:**
- Produces:
  - `CarStats`: `front_diff_lock`, `rear_diff_lock`, `centre_diff_lock` (each 0–1, default 0); `diff_lock_max_torque` (3000).
  - `static Drivetrain.lock_transfer(a_speed: float, b_speed: float, lock: float, max_torque: float, side_inertia: float, delta: float) -> float`: torque to move from side A to side B; negative moves it from B to A.
  - `Car._apply_diff_locks(drive: PackedFloat32Array, delta: float) -> PackedFloat32Array`: applied to driven axles left/right, and front/rear on AWD.

- [ ] **Step 1: Write the failing tests.** Append to the end of `tests/unit/test_drivetrain.gd`:

```gdscript
func test_an_open_differential_moves_no_torque() -> void:
	assert_eq(Drivetrain.lock_transfer(30.0, 10.0, 0.0, 3000.0, 1.2, 1.0 / 120.0), 0.0)


func test_a_lock_moves_torque_from_the_faster_side_to_the_slower() -> void:
	var delta := 1.0 / 120.0
	assert_gt(Drivetrain.lock_transfer(12.0, 10.0, 1.0, 3000.0, 1.2, delta), 0.0, "A faster: from A to B")
	assert_lt(Drivetrain.lock_transfer(10.0, 12.0, 1.0, 3000.0, 1.2, delta), 0.0, "B faster: from B to A")
	assert_almost_eq(Drivetrain.lock_transfer(10.0, 10.0, 1.0, 3000.0, 1.2, delta), 0.0, 0.0001, "equal speeds")


func test_a_lock_moves_at_most_its_share_of_the_limit() -> void:
	var delta := 1.0 / 120.0
	assert_almost_eq(Drivetrain.lock_transfer(60.0, 0.0, 1.0, 3000.0, 2.0, delta), 3000.0, 0.001, "locked")
	assert_almost_eq(Drivetrain.lock_transfer(60.0, 0.0, 0.3, 3000.0, 2.0, delta), 900.0, 0.001, "limited slip")


func test_a_lock_never_reverses_the_speed_difference_in_one_tick() -> void:
	var delta := 1.0 / 120.0
	var inertia := 2.0
	for gap: float in [0.01, 0.5, 3.0, 40.0]:
		var transfer := Drivetrain.lock_transfer(10.0 + gap, 10.0, 1.0, 3000.0, inertia, delta)
		var a := 10.0 + gap - transfer * delta / inertia
		var b := 10.0 + transfer * delta / inertia
		assert_gte(a - b, -0.0001, "a gap of %.2f rad/s closes without reversing" % gap)


func test_a_locked_pair_stays_stable_when_only_one_side_grips() -> void:
	# Both sides get the same drive torque; side B's tire pushes back in proportion
	# to its speed, side A has no grip. A full lock must hold them close together,
	# and the gap must not grow over 1,000 ticks.
	var delta := 1.0 / 120.0
	var inertia := 2.0
	var a := 0.0
	var b := 0.0
	var early_gap := 0.0
	var late_gap := 0.0
	for tick in 1000:
		var transfer := Drivetrain.lock_transfer(a, b, 1.0, 3000.0, inertia, delta)
		a += (800.0 - transfer) / inertia * delta
		b += (800.0 + transfer - b * 60.0) / inertia * delta
		if tick >= 100 and tick < 500:
			early_gap = maxf(early_gap, absf(a - b))
		elif tick >= 500:
			late_gap = maxf(late_gap, absf(a - b))
	gut.p("locked pair: gap up to %.3f rad/s, then %.3f rad/s; speeds %.1f and %.1f rad/s" % [early_gap, late_gap, a, b])
	assert_true(is_finite(a) and is_finite(b))
	# A lock acts on last tick's speeds, so each tick's difference in tire force
	# opens a small gap before it closes; the gap must stay bounded, not grow.
	assert_lt(early_gap, 10.0, "the sides stay together")
	assert_lte(late_gap, early_gap + 0.001, "the gap does not grow")
```

- [ ] **Step 2: Run them to see them fail.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_drivetrain.gd -gexit`
  Expected: SCRIPT ERROR, because `Drivetrain.lock_transfer` doesn't exist.

- [ ] **Step 3: Add the settings.** In `car/car_stats.gd`, directly after the line `@export_range(0.0, 1.0) var front_torque_split: float = 0.35`, add:

```gdscript
@export_group("Differentials")
## How strongly each differential ties its two sides together: 0 = open, each
## wheel spins freely (the default); about 0.3-0.6 = limited slip; 1 = locked.
## A lock moves up to lock x diff_lock_max_torque from the faster side to the slower.
@export_range(0.0, 1.0) var front_diff_lock: float = 0.0
@export_range(0.0, 1.0) var rear_diff_lock: float = 0.0
## AWD only: ties the front axle to the rear axle.
@export_range(0.0, 1.0) var centre_diff_lock: float = 0.0
## Torque a fully locked differential can move between its sides (Nm).
@export var diff_lock_max_torque: float = 3000.0
```

- [ ] **Step 4: Add `lock_transfer`.** In `car/drivetrain.gd`, directly above `func _choose_direction(`, add:

```gdscript
## Differential lock (spec §4.1): the torque (Nm) to move from side A to side B this
## tick; negative moves it from B to A. It is the torque that would bring both sides
## to the same speed within the tick, limited to lock x max_torque, so it never
## reverses their difference and stays stable at any physics rate.
## side_inertia: the rotational inertia of each side (kg*m^2).
static func lock_transfer(a_speed: float, b_speed: float, lock: float, max_torque: float,
		side_inertia: float, delta: float) -> float:
	if lock <= 0.0 or delta <= 0.0:
		return 0.0
	# Moving T from A to B changes each side by T * delta / I in opposite
	# directions, so the gap closes by 2 * T * delta / I.
	var equalising := (a_speed - b_speed) * side_inertia / (2.0 * delta)
	var limit := max_torque * lock
	return clampf(equalising, -limit, limit)
```

- [ ] **Step 5: Apply the locks in the car.** In `car/car.gd`, in `_physics_process`, directly after the line `var drive := Drivetrain.split_torque(drivetrain.drive_torque, stats.drive_type, stats.front_torque_split)`, add:
  ```gdscript
  	drive = _apply_diff_locks(drive, delta)
  ```
  and directly above `func _is_driven(wheel_index: int) -> bool:` add:

```gdscript
## Moves drive torque between the wheels each differential lock ties together
## (spec §4.1): left and right on a driven axle, and front and rear on AWD. With
## every lock at 0 the torques come back unchanged.
func _apply_diff_locks(drive: PackedFloat32Array, delta: float) -> PackedFloat32Array:
	var limit := stats.diff_lock_max_torque
	var inertia := stats.wheel_inertia
	var axle_locks: Array[float] = [stats.front_diff_lock, stats.rear_diff_lock]
	for axle in 2:
		var left := axle * 2
		if axle_locks[axle] <= 0.0 or not _is_driven(left):
			continue
		var transfer := Drivetrain.lock_transfer(wheels[left].spin_speed, wheels[left + 1].spin_speed,
				axle_locks[axle], limit, inertia, delta)
		drive[left] -= transfer
		drive[left + 1] += transfer
	if stats.drive_type == CarStats.DriveType.AWD and stats.centre_diff_lock > 0.0:
		var front := (wheels[0].spin_speed + wheels[1].spin_speed) * 0.5
		var rear := (wheels[2].spin_speed + wheels[3].spin_speed) * 0.5
		# Each axle is two wheels: twice the inertia, and its torque shared between them.
		var transfer := Drivetrain.lock_transfer(front, rear, stats.centre_diff_lock, limit, inertia * 2.0, delta) * 0.5
		drive[0] -= transfer
		drive[1] -= transfer
		drive[2] += transfer
		drive[3] += transfer
	return drive
```

- [ ] **Step 6: Run the tests.**
  Run the Step 2 command. Expected: all pass. The stability test prints `locked pair: gap up to 6.667 rad/s, then 6.667 rad/s; …`.
  Run: `./run_tests.sh all`. Expected: exit 0, since the stock car's locks are all 0.

- [ ] **Step 7: Commit.**
  ```bash
  git add car/car_stats.gd car/drivetrain.gd car/car.gd tests/unit/test_drivetrain.gd
  git commit -m "Add differential locks to the car physics"
  ```

---

### Task 2: Low-poly car bodies

**Files:**
- Create: `car/car_body_def.gd`, `car/car_body_builder.gd`, `tests/unit/test_car_body_builder.gd`
- Modify: `car/car.gd`, `car/wheel.gd`

**Interfaces:**
- Consumes: `LowPolyMeshes._add_triangle(tool, centre, a, b, c, color)` and `LowPolyMeshes._add_box(tool, centre, size, color)`.
- Produces:
  - `CarBodyDef` (Resource): colours `body_color`, `window_color`, `trim_color`, `rim_color`; shape `hood_length`, `cabin_length`, `cabin_height`, `windscreen_slope`, `rear_window_slope`, `nose_taper`, `tail_taper`, `bevel`; extras `rear_spoiler`, `big_wing`, `hood_scoop`, `roof_rack`, `bull_bar`, `spare_wheel`, `fender_flares`.
  - `static CarBodyBuilder.build(body: CarBodyDef, stats: CarStats) -> ArrayMesh`; `static CarBodyBuilder.material() -> StandardMaterial3D`.
  - `Car.body_def: CarBodyDef` (export). When set, the body mesh is built, `CabinMesh` is freed and the wheels take `rim_color`. When null, the grey boxes stay.
  - `Wheel.rim_color: Color`.

- [ ] **Step 1: Write the failing tests.** Create `tests/unit/test_car_body_builder.gd`:

`tests/unit/test_car_body_builder.gd`:

```gdscript
extends GutTest
## CarBodyBuilder's low-poly bodies, and a car wearing one (spec §6).

const CAR_SCENE := preload("res://car/car.tscn")
const RALLY_STATS := preload("res://car/rally_car.tres")


func _every_extra() -> CarBodyDef:
	var body := CarBodyDef.new()
	body.rear_spoiler = true
	body.big_wing = true
	body.hood_scoop = true
	body.roof_rack = true
	body.bull_bar = true
	body.spare_wheel = true
	body.fender_flares = true
	return body


func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func _has_color(mesh: ArrayMesh, color: Color) -> bool:
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	# Vertex colours are stored as 8-bit, so compare within a couple of steps.
	return Array(colors).any(func(c: Color) -> bool: return Vector3(c.r, c.g, c.b).distance_to(Vector3(color.r, color.g, color.b)) < 0.02)


func test_a_body_has_triangles_and_its_colours_and_stays_cheap() -> void:
	var body := CarBodyDef.new()
	body.body_color = Color(0.1, 0.5, 0.9)
	body.window_color = Color(0.2, 0.2, 0.25)
	var plain := CarBodyBuilder.build(body, RALLY_STATS)
	assert_between(_vertices(plain).size() / 3, 40, 400)
	assert_true(_has_color(plain, body.body_color), "body colour")
	assert_true(_has_color(plain, body.window_color), "window colour")
	assert_lt(_vertices(CarBodyBuilder.build(_every_extra(), RALLY_STATS)).size() / 3, 400, "with every extra")


func test_a_plain_body_fills_the_footprint_and_rises_by_its_cabin() -> void:
	var body := CarBodyDef.new()
	var bounds := CarBodyBuilder.build(body, RALLY_STATS).get_aabb()
	var size := RALLY_STATS.body_size
	assert_almost_eq(bounds.size.x, size.x, 0.001, "as wide as the body")
	assert_almost_eq(bounds.size.z, size.z, 0.001, "as long as the body")
	assert_almost_eq(bounds.position.y, -size.y * 0.5, 0.001, "starts at the body's bottom")
	assert_almost_eq(bounds.end.y, size.y * 0.5 + body.cabin_height, 0.001, "tops out at the cabin roof")


func test_extras_stay_close_to_the_footprint() -> void:
	var bounds := CarBodyBuilder.build(_every_extra(), RALLY_STATS).get_aabb()
	var size := RALLY_STATS.body_size
	assert_lte(bounds.size.x, size.x + 0.4)
	assert_lte(bounds.size.z, size.z + 0.4)
	assert_gt(bounds.size.z, size.z, "the bull bar and spare wheel stick out")


func test_triangles_have_real_area_and_unit_normals() -> void:
	var arrays := CarBodyBuilder.build(_every_extra(), RALLY_STATS).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var degenerate := 0
	for t in range(0, vertices.size(), 3):
		if (vertices[t + 1] - vertices[t]).cross(vertices[t + 2] - vertices[t]).length() < 0.000001:
			degenerate += 1
		assert_almost_eq(normals[t].length(), 1.0, 0.001)
		if not is_equal_approx(normals[t].length(), 1.0):
			return
	assert_eq(degenerate, 0)


func test_a_car_with_a_body_def_wears_the_built_body_and_keeps_its_collision_box() -> void:
	var car: Car = CAR_SCENE.instantiate()
	car.body_def = CarBodyDef.new()
	car.body_def.rim_color = Color(0.85, 0.68, 0.22)
	add_child_autofree(car)
	assert_is(car.get_node("BodyMesh").mesh, ArrayMesh)
	assert_null(car.get_node_or_null("CabinMesh"), "the cabin is part of the built body")
	assert_eq((car.get_node("BodyShape").shape as BoxShape3D).size, car.stats.body_size)
	for wheel in car.wheels:
		assert_eq(wheel.rim_color, car.body_def.rim_color)


func test_a_car_without_a_body_def_keeps_its_gray_boxes() -> void:
	var car: Car = CAR_SCENE.instantiate()
	add_child_autofree(car)
	assert_is(car.get_node("BodyMesh").mesh, BoxMesh)
	assert_not_null(car.get_node_or_null("CabinMesh"))
```

- [ ] **Step 2: Run them to see them fail.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_car_body_builder.gd -gexit`
  Expected: SCRIPT ERROR, because `CarBodyDef` and `CarBodyBuilder` don't exist.

- [ ] **Step 3: Create `car/car_body_def.gd`:**

`car/car_body_def.gd`:

```gdscript
class_name CarBodyDef
extends Resource
## The look of a car's low-poly body (spec §6.1). Lengths are shares of the body's
## length unless named in metres. It never changes the car's collision box.

@export_group("Colours")
@export var body_color: Color = Color(0.86, 0.32, 0.16)
@export var window_color: Color = Color(0.2, 0.24, 0.3)
@export var trim_color: Color = Color(0.12, 0.12, 0.13)
@export var rim_color: Color = Color(0.75, 0.75, 0.78)

@export_group("Shape")
## Hood in front of the windscreen.
@export_range(0.0, 1.0) var hood_length: float = 0.3
## Cabin roof.
@export_range(0.0, 1.0) var cabin_length: float = 0.35
## Height of the cabin above the body (m).
@export var cabin_height: float = 0.45
## How far the windscreen and rear window lean (0 = upright).
@export_range(0.0, 0.5) var windscreen_slope: float = 0.12
@export_range(0.0, 0.5) var rear_window_slope: float = 0.1
## How much the nose and tail narrow and drop at their ends.
@export_range(0.0, 0.5) var nose_taper: float = 0.2
@export_range(0.0, 0.5) var tail_taper: float = 0.1
## The body's top edges are bevelled by this much (m).
@export var bevel: float = 0.06

@export_group("Extras")
@export var rear_spoiler: bool = false
@export var big_wing: bool = false
@export var hood_scoop: bool = false
@export var roof_rack: bool = false
@export var bull_bar: bool = false
@export var spare_wheel: bool = false
@export var fender_flares: bool = false
```

- [ ] **Step 4: Create `car/car_body_builder.gd`:**

`car/car_body_builder.gd`:

```gdscript
class_name CarBodyBuilder
extends RefCounted
## Builds a car's low-poly body (spec §6.1): one flat-shaded, vertex-coloured mesh
## sized to CarStats.body_size - a lower body with bevelled top edges, narrowed and
## lowered toward its nose and tail; a cabin with sloped windows and a darker window
## band; and the extras its CarBodyDef switches on. Forward is -Z.

## Share of the body's length over which the nose and the tail taper.
const TAPER_LENGTH := 0.22
## Height of the window band as a share of the cabin; the rest is roof.
const WINDOW_SHARE := 0.7
## The cabin's half width at its base and at its roof, as shares of the body's.
const CABIN_BASE_WIDTH := 0.92
const CABIN_ROOF_WIDTH := 0.78
## Faces of an eight-cornered solid whose corners are indexed like a box: bit 0 =
## +X side, bit 1 = top, bit 2 = +Z end.
const SOLID_FACES := [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]


static func build(body: CarBodyDef, stats: CarStats) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size := stats.body_size
	var half := size * 0.5
	var bevel := minf(body.bevel, half.y * 0.5)
	_add_tapered_slab(tool, body, size, -half.y, half.y - bevel, half.x, body.body_color)
	_add_tapered_slab(tool, body, size, half.y - bevel, half.y, half.x - bevel, body.body_color)
	var base := _cabin_outline(body, size, 0.0)
	var band := _cabin_outline(body, size, WINDOW_SHARE)
	var roof := _cabin_outline(body, size, 1.0)
	_add_cabin_section(tool, base, band, half.y, half.y + body.cabin_height * WINDOW_SHARE, body.window_color)
	_add_cabin_section(tool, band, roof, half.y + body.cabin_height * WINDOW_SHARE, half.y + body.cabin_height, body.body_color)
	_add_extras(tool, body, stats)
	return tool.commit()


## The material every car body uses: its vertex colours, lit.
static func material() -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.roughness = 0.6
	return result


## A slab from `bottom` to `top` (m), `half_width` either side, along the body's
## length: full size in the middle, narrowed and lowered over the last TAPER_LENGTH
## toward the nose and the tail by the body's tapers.
static func _add_tapered_slab(tool: SurfaceTool, body: CarBodyDef, size: Vector3, bottom: float, top: float,
		half_width: float, color: Color) -> void:
	var floor := -size.y * 0.5
	var half_length := size.z * 0.5
	var taper_run := size.z * TAPER_LENGTH
	# Stations along the length as Vector2(z, taper): nose, end of nose taper, start of tail taper, tail.
	var stations: Array[Vector2] = [Vector2(-half_length, body.nose_taper), Vector2(-half_length + taper_run, 0.0),
			Vector2(half_length - taper_run, 0.0), Vector2(half_length, body.tail_taper)]
	for piece in 3:
		var corners: Array[Vector3] = []
		for station: Vector2 in [stations[piece], stations[piece + 1]]:
			for y: float in [bottom, top]:
				for side: float in [-1.0, 1.0]:
					corners.append(Vector3(side * half_width * (1.0 - station.y), y - (y - floor) * station.y, station.x))
		_add_solid(tool, corners, color)


## The cabin's outline `share` of the way from its base to its roof, as
## Vector3(front z, rear z, half width).
static func _cabin_outline(body: CarBodyDef, size: Vector3, share: float) -> Vector3:
	var base_front := -size.z * 0.5 + body.hood_length * size.z
	var roof_front := base_front + body.windscreen_slope * size.z
	var roof_rear := roof_front + body.cabin_length * size.z
	var base_rear := roof_rear + body.rear_window_slope * size.z
	return Vector3(lerpf(base_front, roof_front, share), lerpf(base_rear, roof_rear, share),
			size.x * 0.5 * lerpf(CABIN_BASE_WIDTH, CABIN_ROOF_WIDTH, share))


static func _add_cabin_section(tool: SurfaceTool, lower: Vector3, upper: Vector3, lower_y: float, upper_y: float,
		color: Color) -> void:
	var corners: Array[Vector3] = []
	for end in 2:
		for level in 2:
			var outline := lower if level == 0 else upper
			var y := lower_y if level == 0 else upper_y
			for side: float in [-1.0, 1.0]:
				corners.append(Vector3(side * outline.z, y, outline.x if end == 0 else outline.y))
	_add_solid(tool, corners, color)


## Adds a convex eight-cornered solid, each face lit away from its centre.
static func _add_solid(tool: SurfaceTool, corners: Array[Vector3], color: Color) -> void:
	var centre := Vector3.ZERO
	for corner in corners:
		centre += corner
	centre /= corners.size()
	for quad: Array in SOLID_FACES:
		LowPolyMeshes._add_triangle(tool, centre, corners[quad[0]], corners[quad[1]], corners[quad[2]], color)
		LowPolyMeshes._add_triangle(tool, centre, corners[quad[0]], corners[quad[2]], corners[quad[3]], color)


static func _add_extras(tool: SurfaceTool, body: CarBodyDef, stats: CarStats) -> void:
	var size := stats.body_size
	var half := size * 0.5
	var roof_y := half.y + body.cabin_height
	if body.rear_spoiler:
		LowPolyMeshes._add_box(tool, Vector3(0.0, half.y + 0.1, half.z - 0.18), Vector3(size.x * 0.8, 0.05, 0.28), body.body_color)
	if body.big_wing:
		for side: float in [-1.0, 1.0]:
			LowPolyMeshes._add_box(tool, Vector3(side * size.x * 0.32, half.y + 0.16, half.z - 0.22), Vector3(0.06, 0.32, 0.12), body.trim_color)
		LowPolyMeshes._add_box(tool, Vector3(0.0, half.y + 0.34, half.z - 0.24), Vector3(size.x * 0.96, 0.05, 0.38), body.body_color)
	if body.hood_scoop:
		LowPolyMeshes._add_box(tool, Vector3(0.0, half.y + 0.04, -half.z + body.hood_length * size.z * 0.55),
				Vector3(size.x * 0.3, 0.08, 0.36), body.trim_color)
	if body.roof_rack:
		var roof := _cabin_outline(body, size, 1.0)
		var rack_length := (roof.y - roof.x) * 0.9
		var rack_z := (roof.x + roof.y) * 0.5
		for side: float in [-1.0, 1.0]:
			LowPolyMeshes._add_box(tool, Vector3(side * roof.z * 0.8, roof_y + 0.07, rack_z), Vector3(0.05, 0.06, rack_length), body.trim_color)
		for end: float in [-0.35, 0.35]:
			LowPolyMeshes._add_box(tool, Vector3(0.0, roof_y + 0.11, rack_z + end * rack_length), Vector3(roof.z * 1.7, 0.04, 0.05), body.trim_color)
	if body.bull_bar:
		LowPolyMeshes._add_box(tool, Vector3(0.0, -half.y * 0.1, -half.z - 0.1), Vector3(size.x * 0.82, size.y * 0.7, 0.08), body.trim_color)
		LowPolyMeshes._add_box(tool, Vector3(0.0, half.y * 0.55, -half.z - 0.05), Vector3(size.x * 0.6, 0.08, 0.14), body.trim_color)
	if body.spare_wheel:
		LowPolyMeshes._add_box(tool, Vector3(0.0, half.y * 0.2, half.z + 0.12),
				Vector3(stats.wheel_radius * 1.6, stats.wheel_radius * 1.6, 0.24), body.trim_color)
	if body.fender_flares:
		for axle_z: float in [-stats.wheelbase * 0.5, stats.wheelbase * 0.5]:
			for side: float in [-1.0, 1.0]:
				LowPolyMeshes._add_box(tool, Vector3(side * (half.x + 0.05), -half.y * 0.35, axle_z),
						Vector3(0.1, size.y * 0.35, stats.wheel_radius * 2.4), body.trim_color)
```

- [ ] **Step 5: Give the wheel a rim colour.** In `car/wheel.gd`, directly after `var brake_torque: float = 0.0`, add:
  ```gdscript
  ## Colour of the hub bar across the wheel face; the car sets it from its body before setup().
  var rim_color := Color(0.75, 0.75, 0.78)
  ```
  and in `_build_visual`, replace `hub.material_override = _flat_material(Color(0.75, 0.75, 0.78))` with `hub.material_override = _flat_material(rim_color)`.

- [ ] **Step 6: Let the car wear a body.** In `car/car.gd`, directly after `@export var grip_table: GripTable`, add:
  ```gdscript
  ## The car's low-poly look (spec §6); without one it is drawn as gray boxes.
  @export var body_def: CarBodyDef
  ```
  In `_ready`, replace the wheel setup loop with:
  ```gdscript
  	for wheel in wheels:
  		if body_def != null:
  			wheel.rim_color = body_def.rim_color
  		wheel.setup(stats, grip_table, self)
  ```
  In `_apply_stats`, directly after `$BodyShape.shape = body_box`, add:
  ```gdscript

  	if body_def != null:
  		$BodyMesh.mesh = CarBodyBuilder.build(body_def, stats)
  		$BodyMesh.material_override = CarBodyBuilder.material()
  		$CabinMesh.free()  # the cabin is part of the built body
  		return
  ```

- [ ] **Step 7: Import and run the tests.**
  Run: `godot --headless --import`, then the Step 2 command. Expected: all 6 pass.
  Run: `./run_tests.sh unit`. Expected: exit 0.

- [ ] **Step 8: Commit.**
  ```bash
  git add car/car_body_def.gd car/car_body_def.gd.uid car/car_body_builder.gd car/car_body_builder.gd.uid car/car.gd car/wheel.gd tests/unit/test_car_body_builder.gd tests/unit/test_car_body_builder.gd.uid
  git commit -m "Build low-poly car bodies from a body definition"
  ```

---

### Task 3: The three cars as data, and choosing one

**Files:**
- Create: `car/car_def.gd`, `car/car_catalog.gd`, `car/offroad_4x4.tres`, `car/rally_car_tuned.tres`, `car/cars/rally.tres`, `car/cars/offroad_4x4.tres`, `car/cars/rally_tuned.tres`, `car/car_catalog.tres`, `tests/unit/test_car_catalog.gd`
- Modify: `surfaces/grip_table.tres`, `game/progress.gd`, `game/game_state.gd` (replace whole file), `tests/scenarios/save_sandbox.gd` (replace whole file)
- Test: `tests/unit/test_progress.gd` (append), `tests/unit/test_game_state.gd` (append)

**Interfaces:**
- Consumes: `CarStats` (Task 1 locks), `CarBodyDef` (Task 2).
- Produces:
  - `CarDef` (Resource): `id: StringName`, `display_name`, `description`, `best_on`, `stats: CarStats`, `body: CarBodyDef`, `unlock_stars: int`.
  - `CarCatalog` (Resource): `cars: Array[CarDef]`, `find_by_id(id) -> CarDef`, `unlocked(total_stars) -> Array[CarDef]`, `newly_unlocked(stars_before, stars_after) -> Array[CarDef]`.
  - Ids `&"rally"`, `&"offroad_4x4"`, `&"rally_tuned"`, unlocked at 0, 3 and 5 stars.
  - `Progress`: `DEFAULT_CAR := "rally"`; `selected_car: String`, saved under `settings`.
  - `GameState`:
    - `CAR_SELECT := "res://ui/car_select.tscn"`, `car_catalog: CarCatalog`, `pending_scene: String`
    - `selected_car() -> CarDef`, `is_car_unlocked(car) -> bool`, `set_selected_car(id)`, `choose_car_for(scene_path)`
    - `record_finish(...)`'s result gains `"new_cars": Array[CarDef]`
  - `SaveSandbox` also restores `car_catalog` and clears `pending_scene`.

- [ ] **Step 1: Write the failing tests.** Create `tests/unit/test_car_catalog.gd`:

`tests/unit/test_car_catalog.gd`:

```gdscript
extends GutTest
## The car catalog, its unlocks, and the three shipped cars (spec §3).

var catalog: CarCatalog


func _car(id: StringName, stars: int) -> CarDef:
	var car := CarDef.new()
	car.id = id
	car.unlock_stars = stars
	return car


func _ids(cars: Array[CarDef]) -> Array:
	return cars.map(func(car: CarDef) -> StringName: return car.id)


func before_each() -> void:
	catalog = CarCatalog.new()
	catalog.cars = [_car(&"a", 0), _car(&"b", 3), _car(&"c", 5)]


func test_finds_cars_by_id() -> void:
	assert_eq(catalog.find_by_id(&"b"), catalog.cars[1])
	assert_null(catalog.find_by_id(&"missing"))


func test_total_stars_unlock_cars_in_order() -> void:
	assert_eq(_ids(catalog.unlocked(0)), [&"a"])
	assert_eq(_ids(catalog.unlocked(2)), [&"a"])
	assert_eq(_ids(catalog.unlocked(3)), [&"a", &"b"])
	assert_eq(_ids(catalog.unlocked(6)), [&"a", &"b", &"c"])


func test_newly_unlocked_cars_are_the_ones_a_finish_crosses() -> void:
	assert_eq(_ids(catalog.newly_unlocked(2, 3)), [&"b"])
	assert_eq(_ids(catalog.newly_unlocked(2, 6)), [&"b", &"c"])
	assert_eq(_ids(catalog.newly_unlocked(3, 4)), [], "the 3-star car was already unlocked")
	assert_eq(_ids(catalog.newly_unlocked(5, 5)), [], "no new stars")


func test_the_shipped_catalog_has_the_three_cars() -> void:
	var shipped: CarCatalog = load("res://car/car_catalog.tres")
	assert_eq(_ids(shipped.cars), [&"rally", &"offroad_4x4", &"rally_tuned"])
	assert_eq(shipped.cars.map(func(car: CarDef) -> int: return car.unlock_stars), [0, 3, 5])
	for car in shipped.cars:
		assert_not_null(car.stats, "%s has stats" % car.id)
		assert_not_null(car.body, "%s has a body" % car.id)
		assert_false(car.description.is_empty(), "%s has a description" % car.id)
	assert_eq(shipped.cars[0].stats.resource_path, "res://car/rally_car.tres", "the stock Rally Car keeps its stats")


func test_the_new_cars_differ_from_stock_as_designed() -> void:
	var shipped: CarCatalog = load("res://car/car_catalog.tres")
	var stock: CarStats = shipped.cars[0].stats
	var offroad: CarStats = shipped.cars[1].stats
	var tuned: CarStats = shipped.cars[2].stats
	assert_eq([stock.front_diff_lock, stock.rear_diff_lock, stock.centre_diff_lock], [0.0, 0.0, 0.0], "stock stays open")
	for i in stock.torque_curve_nm.size():
		assert_almost_eq(tuned.torque_curve_nm[i], stock.torque_curve_nm[i] * 1.3, 0.6, "tuned torque point %d is +30%%" % i)
	assert_lt(tuned.mass, stock.mass)
	assert_gt(tuned.tire_grip, stock.tire_grip)
	assert_eq(offroad.archetype, &"offroad")
	assert_eq(offroad.centre_diff_lock, 1.0)
	assert_gt(offroad.mass, stock.mass)
	assert_gt(offroad.suspension_length, stock.suspension_length)
	var grip: GripTable = load("res://surfaces/grip_table.tres")
	assert_gt(grip.multiplier(&"offroad", &"mud"), grip.multiplier(&"offroad", &"asphalt"), "the 4x4 prefers mud")
```

  Append to the end of `tests/unit/test_progress.gd`:

```gdscript
func test_the_selected_car_is_saved_and_defaults_to_the_rally_car() -> void:
	assert_eq(progress.selected_car, Progress.DEFAULT_CAR)
	progress.selected_car = "offroad_4x4"
	assert_eq(Progress.from_dictionary(progress.to_dictionary()).selected_car, "offroad_4x4")
	assert_eq(Progress.from_dictionary({"settings": {"steer_mode": "analog"}}).selected_car, "rally", "an older save")
	assert_eq(Progress.from_dictionary({"settings": {"selected_car": 7}}).selected_car, "rally", "a wrongly typed value")
```

  Append to the end of `tests/unit/test_game_state.gd`:

```gdscript
func test_the_selected_car_falls_back_to_the_rally_car_while_locked_or_unknown() -> void:
	assert_eq(state.selected_car().id, &"rally")
	state.set_selected_car(&"offroad_4x4")
	assert_eq(state.selected_car().id, &"rally", "the 4x4 needs 3 stars")
	state.record_finish(state.catalog.levels[0], 60.0, {})
	assert_eq(state.selected_car().id, &"offroad_4x4")
	state.progress.selected_car = "no_such_car"
	assert_eq(state.selected_car().id, &"rally")


func test_choosing_a_car_is_saved() -> void:
	state.set_selected_car(&"rally_tuned")
	var saved := SaveSystem.read(SaveSandbox.PATH)
	assert_eq(saved["settings"]["selected_car"], "rally_tuned")


func test_choose_car_for_remembers_the_scene_and_opens_car_select() -> void:
	state.choose_car_for("res://levels/rally_road/rally_road.tscn")
	assert_eq(state.pending_scene, "res://levels/rally_road/rally_road.tscn")
	assert_eq(SaveSandbox.requested_scenes, [state.CAR_SELECT])


func test_a_finish_reports_the_cars_it_unlocks() -> void:
	var result: Dictionary = state.record_finish(state.catalog.levels[0], 60.0, {})
	assert_eq(result["new_cars"].map(func(car: CarDef) -> StringName: return car.id), [&"offroad_4x4"])
	var again: Dictionary = state.record_finish(state.catalog.levels[0], 59.0, {})
	assert_true(again["new_cars"].is_empty(), "the 4x4 was already unlocked")
```

- [ ] **Step 2: Run them to see them fail.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_car_catalog.gd -gexit`
  Expected: SCRIPT ERROR, because `CarCatalog` doesn't exist.

- [ ] **Step 3: Create the car resources' scripts.**

`car/car_def.gd`:

```gdscript
class_name CarDef
extends Resource
## One selectable car (spec §3.1): its save key, name, how car select describes it,
## its physics stats, its low-poly body, and the total stars needed to unlock it.

## Stable key for save data. Never rename it once players have saves.
@export var id: StringName = &""
@export var display_name: String = ""
## One line for car select, e.g. "Heavy and torquey. Loves mud, slow on asphalt."
@export var description: String = ""
## The surfaces it suits, e.g. "Mud, rough ground".
@export var best_on: String = ""
@export var stats: CarStats
@export var body: CarBodyDef
## Total stars across all levels needed to drive it.
@export var unlock_stars: int = 0
```

`car/car_catalog.gd`:

```gdscript
class_name CarCatalog
extends Resource
## The selectable cars in display order (spec §3.1). The first is the starter car.

@export var cars: Array[CarDef] = []


func find_by_id(id: StringName) -> CarDef:
	for car in cars:
		if car.id == id:
			return car
	return null


## The cars `total_stars` unlocks, in display order.
func unlocked(total_stars: int) -> Array[CarDef]:
	var result: Array[CarDef] = []
	for car in cars:
		if total_stars >= car.unlock_stars:
			result.append(car)
	return result


## The cars that going from `stars_before` to `stars_after` total stars unlocks.
func newly_unlocked(stars_before: int, stars_after: int) -> Array[CarDef]:
	var result: Array[CarDef] = []
	for car in cars:
		if stars_before < car.unlock_stars and stars_after >= car.unlock_stars:
			result.append(car)
	return result
```

- [ ] **Step 4: Create the new cars' stats and grip.**

`car/offroad_4x4.tres`:

```ini
[gd_resource type="Resource" script_class="CarStats" format=3]

[ext_resource type="Script" path="res://car/car_stats.gd" id="1_stats"]

[resource]
script = ExtResource("1_stats")
display_name = "Off-road 4x4"
archetype = &"offroad"
mass = 2150.0
center_of_mass = Vector3(0, -0.05, 0)
inertia = Vector3(3800, 4300, 1000)
body_size = Vector3(1.95, 0.7, 4.6)
aero_drag = 0.6
wheel_radius = 0.4
wheel_width = 0.3
track_width = 1.72
wheelbase = 2.95
wheel_mount_height = 0.2
wheel_inertia = 2.0
suspension_length = 0.5
spring_stiffness = 32000.0
compress_damping = 2800.0
rebound_damping = 4200.0
bump_stop_stiffness = 260000.0
anti_roll_front = 4000.0
anti_roll_rear = 5000.0
tire_grip = 1.05
rear_grip_bias = 1.0
peak_slip_ratio = 0.14
peak_slip_angle_deg = 10.0
slide_grip = 0.8
low_speed_reference = 3.0
torque_curve_rpm = PackedFloat32Array(1000, 2000, 3000, 4000, 5000, 5800)
torque_curve_nm = PackedFloat32Array(480, 560, 580, 540, 470, 380)
idle_rpm = 900.0
redline_rpm = 5800.0
launch_rpm = 2800.0
engine_braking_nm = 90.0
gear_ratios = PackedFloat32Array(4.2, 2.6, 1.75, 1.3, 1.0, 0.8)
reverse_ratio = 3.8
final_drive = 4.1
upshift_rpm = 5400.0
downshift_rpm = 2200.0
shift_time = 0.2
drivetrain_efficiency = 0.8
drive_type = 2
front_torque_split = 0.5
front_diff_lock = 0.3
rear_diff_lock = 0.6
centre_diff_lock = 1.0
brake_torque = 14000.0
brake_front_bias = 0.6
abs_enabled = true
abs_target_slip = 0.15
auto_hold_speed = 0.5
direction_change_speed = 1.0
traction_control = true
traction_slip_target = 0.3
max_steer_deg = 34.0
steer_rate_deg = 120.0
steer_assist_slip = 0.75
airborne_grace = 0.1
air_pitch_torque = 5500.0
air_roll_torque = 4000.0
```

`car/rally_car_tuned.tres`:

```ini
[gd_resource type="Resource" script_class="CarStats" format=3]

[ext_resource type="Script" path="res://car/car_stats.gd" id="1_stats"]

[resource]
script = ExtResource("1_stats")
display_name = "Rally Car Tuned"
archetype = &"rally"
mass = 1380.0
center_of_mass = Vector3(0, -0.18, 0)
inertia = Vector3(2400, 2700, 550)
body_size = Vector3(1.6, 0.5, 4.2)
aero_drag = 0.42
wheel_radius = 0.33
wheel_width = 0.24
track_width = 1.52
wheelbase = 2.52
wheel_mount_height = 0.1
wheel_inertia = 1.2
suspension_length = 0.35
spring_stiffness = 35400.0
compress_damping = 2680.0
rebound_damping = 4020.0
bump_stop_stiffness = 200000.0
anti_roll_front = 6700.0
anti_roll_rear = 10700.0
tire_grip = 1.3
rear_grip_bias = 0.96
peak_slip_ratio = 0.12
peak_slip_angle_deg = 8.0
slide_grip = 0.75
low_speed_reference = 3.0
torque_curve_rpm = PackedFloat32Array(1000, 2500, 4000, 5500, 6500, 7200)
torque_curve_nm = PackedFloat32Array(416, 533, 572, 546, 481, 390)
idle_rpm = 1000.0
redline_rpm = 7200.0
launch_rpm = 4000.0
engine_braking_nm = 50.0
gear_ratios = PackedFloat32Array(3.2, 2.2, 1.65, 1.3, 1.08, 0.92)
reverse_ratio = 3.3
final_drive = 4.8
upshift_rpm = 6800.0
downshift_rpm = 3000.0
shift_time = 0.09
drivetrain_efficiency = 0.85
drive_type = 2
front_torque_split = 0.41
brake_torque = 11000.0
brake_front_bias = 0.6
abs_enabled = true
abs_target_slip = 0.15
auto_hold_speed = 0.5
direction_change_speed = 1.0
traction_control = true
traction_slip_target = 0.3
max_steer_deg = 32.0
steer_rate_deg = 140.0
steer_assist_slip = 0.75
airborne_grace = 0.1
air_pitch_torque = 3700.0
air_roll_torque = 2700.0
```

  Replace `surfaces/grip_table.tres` with:

`surfaces/grip_table.tres`:

```ini
[gd_resource type="Resource" script_class="GripTable" format=3]

[ext_resource type="Script" path="res://surfaces/grip_table.gd" id="1_grip"]

[resource]
script = ExtResource("1_grip")
multipliers = {
"rally/asphalt": 1.1,
"rally/dirt": 1.05,
"rally/mud": 1.1,
"offroad/asphalt": 0.95,
"offroad/dirt": 1.1,
"offroad/mud": 1.35
}
```

- [ ] **Step 5: Create the three cars and the catalog.** Run `mkdir -p car/cars`, then create:

`car/cars/rally.tres`:

```ini
[gd_resource type="Resource" script_class="CarDef" format=3]

[ext_resource type="Script" path="res://car/car_def.gd" id="1_def"]
[ext_resource type="Script" path="res://car/car_body_def.gd" id="2_body"]
[ext_resource type="Resource" path="res://car/rally_car.tres" id="3_stats"]

[sub_resource type="Resource" id="Resource_body"]
script = ExtResource("2_body")
body_color = Color(0.86, 0.32, 0.16, 1)
window_color = Color(0.2, 0.24, 0.3, 1)
trim_color = Color(0.12, 0.12, 0.13, 1)
rim_color = Color(0.75, 0.75, 0.78, 1)
rear_spoiler = true

[resource]
script = ExtResource("1_def")
id = &"rally"
display_name = "Rally Car"
description = "Balanced all-wheel drive. Quick and forgiving everywhere."
best_on = "Asphalt, dirt"
stats = ExtResource("3_stats")
body = SubResource("Resource_body")
unlock_stars = 0
```

`car/cars/offroad_4x4.tres`:

```ini
[gd_resource type="Resource" script_class="CarDef" format=3]

[ext_resource type="Script" path="res://car/car_def.gd" id="1_def"]
[ext_resource type="Script" path="res://car/car_body_def.gd" id="2_body"]
[ext_resource type="Resource" path="res://car/offroad_4x4.tres" id="3_stats"]

[sub_resource type="Resource" id="Resource_body"]
script = ExtResource("2_body")
body_color = Color(0.62, 0.58, 0.4, 1)
window_color = Color(0.18, 0.22, 0.26, 1)
trim_color = Color(0.1, 0.1, 0.1, 1)
rim_color = Color(0.2, 0.2, 0.2, 1)
hood_length = 0.28
cabin_length = 0.42
cabin_height = 0.62
windscreen_slope = 0.05
rear_window_slope = 0.02
nose_taper = 0.06
tail_taper = 0.02
bevel = 0.05
roof_rack = true
bull_bar = true
spare_wheel = true
fender_flares = true

[resource]
script = ExtResource("1_def")
id = &"offroad_4x4"
display_name = "Off-road 4x4"
description = "Heavy and torquey with locked diffs. Loves mud, slow on asphalt."
best_on = "Mud, rough ground"
stats = ExtResource("3_stats")
body = SubResource("Resource_body")
unlock_stars = 3
```

`car/cars/rally_tuned.tres`:

```ini
[gd_resource type="Resource" script_class="CarDef" format=3]

[ext_resource type="Script" path="res://car/car_def.gd" id="1_def"]
[ext_resource type="Script" path="res://car/car_body_def.gd" id="2_body"]
[ext_resource type="Resource" path="res://car/rally_car_tuned.tres" id="3_stats"]

[sub_resource type="Resource" id="Resource_body"]
script = ExtResource("2_body")
body_color = Color(0.1, 0.22, 0.55, 1)
window_color = Color(0.2, 0.24, 0.3, 1)
trim_color = Color(0.08, 0.08, 0.1, 1)
rim_color = Color(0.85, 0.68, 0.22, 1)
cabin_height = 0.42
big_wing = true
hood_scoop = true

[resource]
script = ExtResource("1_def")
id = &"rally_tuned"
display_name = "Rally Car Tuned"
description = "More power, stiffer and grippier. Fast, but less forgiving."
best_on = "Asphalt"
stats = ExtResource("3_stats")
body = SubResource("Resource_body")
unlock_stars = 5
```

`car/car_catalog.tres`:

```ini
[gd_resource type="Resource" script_class="CarCatalog" format=3]

[ext_resource type="Script" path="res://car/car_catalog.gd" id="1_catalog"]
[ext_resource type="Script" path="res://car/car_def.gd" id="2_def"]
[ext_resource type="Resource" path="res://car/cars/rally.tres" id="3_rally"]
[ext_resource type="Resource" path="res://car/cars/offroad_4x4.tres" id="4_offroad"]
[ext_resource type="Resource" path="res://car/cars/rally_tuned.tres" id="5_tuned"]

[resource]
script = ExtResource("1_catalog")
cars = Array[ExtResource("2_def")]([ExtResource("3_rally"), ExtResource("4_offroad"), ExtResource("5_tuned")])
```

- [ ] **Step 6: Save the selected car.** In `game/progress.gd`:
  - Change the class doc's last words "plus the steering style." to "plus the steering style and\n## the last car chosen."
  - After `const STEER_BUTTONS := "buttons"`, add:
    ```gdscript
    ## The starter car's id (see CarCatalog).
    const DEFAULT_CAR := "rally"
    ```
  - After `var steer_mode: String = STEER_ANALOG`, add:
    ```gdscript
    ## Id of the car the player last chose in car select.
    var selected_car: String = DEFAULT_CAR
    ```
  - In `to_dictionary`, change `"settings": {"steer_mode": steer_mode}` to `"settings": {"steer_mode": steer_mode, "selected_car": selected_car}`.
  - In `from_dictionary`, directly after `progress.steer_mode = settings["steer_mode"]`, add (one tab less than that line):
    ```gdscript
    	var car_id = settings.get("selected_car") if settings is Dictionary else null
    	if car_id is String and car_id != "":
    		progress.selected_car = car_id
    ```

- [ ] **Step 7: Replace `game/game_state.gd`:**

`game/game_state.gd`:

```gdscript
extends Node
## The one always-loaded game object (autoload "GameState", spec §5.6): the level
## catalog, the player's progress and its save file, and moving between scenes.

const CATALOG := preload("res://levels/catalog.tres")
const DEFAULT_SAVE_PATH := "user://save.json"
const MAIN_MENU := "res://ui/main_menu.tscn"
const LEVEL_SELECT := "res://ui/level_select.tscn"
const FREE_DRIVE := "res://levels/test_ground/test_ground.tscn"
const CAR_SELECT := "res://ui/car_select.tscn"
const CAR_CATALOG := preload("res://car/car_catalog.tres")

var catalog: LevelCatalog = CATALOG
## Where progress is saved. Tests point this at a throwaway file (see SaveSandbox).
var save_path := DEFAULT_SAVE_PATH
var progress := Progress.new()
## Loads a scene by path. Tests replace it so a menu test records the request
## instead of swapping out the test runner.
var scene_changer: Callable
var car_catalog: CarCatalog = CAR_CATALOG
## The scene car select starts once a car is chosen: a level, or Free Drive.
var pending_scene := ""


func _ready() -> void:
	scene_changer = Callable(get_tree(), "change_scene_to_file")
	reload()


## Reads progress from save_path, replacing what is in memory.
func reload() -> void:
	progress = Progress.from_dictionary(SaveSystem.read(save_path))


func save() -> Error:
	return SaveSystem.write(save_path, progress.to_dictionary())


## The catalog level whose scene is `scene_path`, or null (e.g. Free Drive).
func level_for_scene(scene_path: String) -> LevelDef:
	return catalog.find_by_scene(scene_path)


## Records a finished run and saves. Returns what Progress.record_finish returns,
## plus "new_cars": the cars (Array[CarDef]) this finish unlocked.
func record_finish(level: LevelDef, time: float, splits: Dictionary) -> Dictionary:
	var stars_before := progress.total_stars(catalog)
	var result := progress.record_finish(level, time, splits)
	save()
	result["new_cars"] = car_catalog.newly_unlocked(stars_before, progress.total_stars(catalog))
	return result


func set_steer_mode(mode: String) -> void:
	progress.steer_mode = mode
	save()


## The car to drive: the player's last choice while it exists and is unlocked,
## otherwise the starter car.
func selected_car() -> CarDef:
	var car := car_catalog.find_by_id(StringName(progress.selected_car))
	if car == null or not is_car_unlocked(car):
		return car_catalog.cars[0]
	return car


func is_car_unlocked(car: CarDef) -> bool:
	return progress.total_stars(catalog) >= car.unlock_stars


func set_selected_car(id: StringName) -> void:
	progress.selected_car = String(id)
	save()


## Opens car select, which then starts `scene_path` with the chosen car.
func choose_car_for(scene_path: String) -> void:
	pending_scene = scene_path
	change_scene(CAR_SELECT)


## Leaves the current scene for `path`, unpausing first so the next scene runs.
func change_scene(path: String) -> void:
	get_tree().paused = false
	scene_changer.call(path)
```

- [ ] **Step 8: Replace `tests/scenarios/save_sandbox.gd`:**

`tests/scenarios/save_sandbox.gd`:

```gdscript
class_name SaveSandbox
extends RefCounted
## Points GameState at a throwaway save file and records scene changes instead of
## performing them, so tests never touch the player's real save and never swap out
## the test runner. Tests may also swap GameState's catalog; leave() restores it.
## Call enter() before a test uses GameState and leave() after.

const PATH := "user://test_sandbox/save.json"

## Scene paths requested through GameState.change_scene since enter().
static var requested_scenes: Array[String] = []
static var _real_changer: Callable
static var _real_catalog: LevelCatalog
static var _real_car_catalog: CarCatalog


static func enter() -> void:
	clear_files()
	requested_scenes.clear()
	var state := game_state()
	_real_changer = state.scene_changer
	_real_catalog = state.catalog
	_real_car_catalog = state.car_catalog
	state.pending_scene = ""
	state.save_path = PATH
	state.scene_changer = func(path: String) -> void: requested_scenes.append(path)
	state.reload()


static func leave() -> void:
	var state := game_state()
	state.get_tree().paused = false
	state.scene_changer = _real_changer
	state.catalog = _real_catalog
	state.car_catalog = _real_car_catalog
	state.pending_scene = ""
	state.save_path = state.DEFAULT_SAVE_PATH
	state.reload()
	clear_files()


static func clear_files() -> void:
	for suffix in ["", ".tmp", ".bad"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


## The GameState autoload (it has no class_name, so it is reached through the tree).
static func game_state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
```

- [ ] **Step 9: Import and run the tests.**
  Run: `godot --headless --import`
  Run the `-gtest` commands for `res://tests/unit/test_car_catalog.gd`, `res://tests/unit/test_progress.gd` and `res://tests/unit/test_game_state.gd`. Expected: all pass.
  Run: `./run_tests.sh unit`. Expected: exit 0.

- [ ] **Step 10: Commit.**
  ```bash
  git add car/car_def.gd car/car_def.gd.uid car/car_catalog.gd car/car_catalog.gd.uid car/offroad_4x4.tres car/rally_car_tuned.tres car/cars car/car_catalog.tres surfaces/grip_table.tres game/progress.gd game/game_state.gd tests/scenarios/save_sandbox.gd tests/unit/test_car_catalog.gd tests/unit/test_car_catalog.gd.uid tests/unit/test_progress.gd tests/unit/test_game_state.gd
  git commit -m "Add the Off-road 4x4 and Rally Car Tuned, unlocked by stars"
  ```

---

### Task 4: The driving rig drives the chosen car

**Files:**
- Modify: `levels/shared/driving_rig.gd` (replace whole file), `debug/run_recorder.gd`
- Create: `tests/unit/test_car_selection.gd`

**Interfaces:**
- Consumes (Task 3): `GameState.selected_car()`, `CarDef`.
- Produces:
  - `DrivingRig.car_override: CarDef` (export) and `DrivingRig.car_def: CarDef`, set in `_enter_tree` before the car's `_ready`.
  - `RunRecorder.car_id: String`; recordings are named `run_<time>_<car id>.csv`.

- [ ] **Step 1: Write the failing tests.** Create `tests/unit/test_car_selection.gd`:

`tests/unit/test_car_selection.gd`:

```gdscript
extends GutTest
## The driving rig drives the selected car, or an override (spec §3.4).

const RIG_SCENE := preload("res://levels/shared/driving_rig.tscn")
const RALLY := preload("res://car/cars/rally.tres")
const OFFROAD := preload("res://car/cars/offroad_4x4.tres")

var state: Node


func before_each() -> void:
	SaveSandbox.enter()
	state = SaveSandbox.game_state()


func after_each() -> void:
	SaveSandbox.leave()


func _rig(override: CarDef = null) -> DrivingRig:
	var rig: DrivingRig = RIG_SCENE.instantiate()
	rig.car_override = override
	add_child_autofree(rig)
	return rig


func test_the_rig_drives_the_selected_car() -> void:
	var first := _rig()
	assert_eq(first.car_def, RALLY, "the starter car by default")
	assert_eq(first.car.stats, RALLY.stats)
	assert_eq(first.car.body_def, RALLY.body)
	state.record_finish(state.catalog.levels[0], 60.0, {})
	state.set_selected_car(&"offroad_4x4")
	var second := _rig()
	assert_eq(second.car_def, OFFROAD)
	assert_eq(second.car.stats, OFFROAD.stats)
	assert_almost_eq(second.car.mass, OFFROAD.stats.mass, 0.001, "the car took the 4x4's stats")


func test_an_override_beats_the_selection() -> void:
	var rig := _rig(OFFROAD)
	assert_eq(rig.car_def, OFFROAD, "even while the 4x4 is locked")
	assert_eq(rig.car.body_def, OFFROAD.body)


func test_recordings_are_named_after_the_car() -> void:
	var rig := _rig(OFFROAD)
	var path := rig.recorder.start()
	rig.recorder.stop()
	assert_true(path.ends_with("_offroad_4x4.csv"), path)
	DirAccess.remove_absolute(path)
```

- [ ] **Step 2: Run them to see them fail.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_car_selection.gd -gexit`
  Expected: failures and a SCRIPT ERROR about `car_override`.

- [ ] **Step 3: Replace `levels/shared/driving_rig.gd`:**

`levels/shared/driving_rig.gd`:

```gdscript
class_name DrivingRig
extends Node3D
## The car with everything needed to drive it: chase camera, touch controls,
## telemetry and run recorder. Levels place one, use place_car() to put the car
## somewhere, and listen to pause_requested. The steering style comes from the save.
## The car is the player's selected one (spec §3.4) unless car_override is set.

signal pause_requested

## Drive this car instead of the player's selected one (tests and tools).
@export var car_override: CarDef

## The car this rig drives, chosen as the rig enters the tree.
var car_def: CarDef

@onready var car: Car = $Car
@onready var camera: ChaseCamera = $ChaseCamera
@onready var touch_controls: TouchControls = $TouchControls
@onready var telemetry: TelemetryOverlay = $TelemetryOverlay
@onready var recorder: RunRecorder = $RunRecorder


## Runs before the car's own _ready applies its stats: gives the car the chosen
## car's stats and body, and names recordings after it.
func _enter_tree() -> void:
	car_def = car_override if car_override != null else GameState.selected_car()
	var driven: Car = $Car
	driven.stats = car_def.stats
	driven.body_def = car_def.body
	($RunRecorder as RunRecorder).car_id = String(car_def.id)


func _ready() -> void:
	touch_controls.pause_requested.connect(pause_requested.emit)
	touch_controls.set_steer_mode(TouchControls.mode_from_name(GameState.progress.steer_mode))


## Puts the car upright and still at `target`, with the camera straight behind it.
func place_car(target: Transform3D) -> void:
	car.reset_to(target)
	camera.snap_to_target()
```

- [ ] **Step 4: Name recordings after the car.** In `debug/run_recorder.gd`, directly after `@export var car: Car`, add:
  ```gdscript
  ## Id of the car being recorded; recordings are named after it when set.
  var car_id := ""
  ```
  and in `start`, replace `path = "%s/run_%s.csv" % [RUNS_DIR, stamp]` with:
  ```gdscript
  		var suffix := "_%s" % car_id if not car_id.is_empty() else ""
  		path = "%s/run_%s%s.csv" % [RUNS_DIR, stamp, suffix]
  ```

- [ ] **Step 5: Run the tests.**
  Run the Step 2 command. Expected: all 3 pass.
  Run: `./run_tests.sh all`. Expected: exit 0. Levels now drive the selected car, which is the stock Rally Car in a fresh save.

- [ ] **Step 6: Commit.**
  ```bash
  git add levels/shared/driving_rig.gd debug/run_recorder.gd tests/unit/test_car_selection.gd tests/unit/test_car_selection.gd.uid
  git commit -m "Drive the selected car in every level"
  ```

---

### Task 5: Car select

**Files:**
- Create: `ui/car_preview.gd`, `ui/car_select.gd`, `ui/car_select.tscn`, `tests/unit/test_car_select.gd`
- Modify: `game/level_def.gd`, `levels/rally_road/rally_road_level.tres`, `levels/muddy_valley/muddy_valley_level.tres`, `ui/level_select.gd`, `ui/main_menu.gd`, `tests/unit/test_menus.gd`

**Interfaces:**
- Consumes (Task 3): `GameState.car_catalog`, `pending_scene`, `selected_car()`, `is_car_unlocked()`, `set_selected_car()`, `choose_car_for()`, `CAR_SELECT`, `FREE_DRIVE`, `LEVEL_SELECT`, `MAIN_MENU`, `level_for_scene()`, `progress.total_stars(catalog)`.
- Produces:
  - `LevelDef.surfaces: String`.
  - `CarPreview` (`SubViewportContainer`): `_init(car: CarDef, viewport_size: Vector2i)`, `turntable: Node3D`.
  - The car select scene: one `Button` per car, named by car id.
  - Statics `destination_text(scene_path) -> String` and `locked_text(car, total_stars) -> String`.
  - Level select cards and the main menu's Free Drive call `GameState.choose_car_for`.

- [ ] **Step 1: Write the failing tests.** Create `tests/unit/test_car_select.gd`:

`tests/unit/test_car_select.gd`:

```gdscript
extends GutTest
## Car select (spec §5.2), with GameState in the save sandbox.

const CAR_SELECT := preload("res://ui/car_select.tscn")
const RALLY_ROAD := "res://levels/rally_road/rally_road.tscn"

var state: Node


func before_each() -> void:
	SaveSandbox.enter()
	state = SaveSandbox.game_state()
	state.pending_scene = RALLY_ROAD


func after_each() -> void:
	SaveSandbox.leave()


func _screen() -> Control:
	var screen: Control = CAR_SELECT.instantiate()
	add_child_autofree(screen)
	return screen


func _card(screen: Node, id: StringName) -> Button:
	return screen.find_child(String(id), true, false)


func _labels(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _earn_three_stars() -> void:
	state.record_finish(state.catalog.levels[0], 60.0, {})


func test_one_card_per_car_each_with_a_preview_under_the_destination() -> void:
	var screen := _screen()
	assert_has(_labels(screen), "Rally Road · Asphalt")
	for car in state.car_catalog.cars:
		var card := _card(screen, car.id)
		assert_not_null(card, "a card for %s" % car.id)
		var previews := card.find_children("*", "", true, false).filter(func(node: Node) -> bool: return node is CarPreview)
		assert_eq(previews.size(), 1, "%s has a preview" % car.id)


func test_unlocked_cars_describe_themselves_and_locked_cars_say_what_they_need() -> void:
	var screen := _screen()
	var rally := _card(screen, &"rally")
	assert_false(rally.disabled)
	assert_has(_labels(rally), state.car_catalog.cars[0].description)
	assert_has(_labels(rally), "Best on: Asphalt, dirt")
	var offroad := _card(screen, &"offroad_4x4")
	assert_true(offroad.disabled)
	assert_has(_labels(offroad), "Earn 3 stars to unlock (you have 0)")


func test_the_selected_car_is_highlighted() -> void:
	_earn_three_stars()
	state.set_selected_car(&"offroad_4x4")
	var screen := _screen()
	assert_true(_card(screen, &"offroad_4x4").has_theme_stylebox_override("normal"))
	assert_false(_card(screen, &"rally").has_theme_stylebox_override("normal"))


func test_tapping_a_car_saves_it_and_starts_the_pending_scene() -> void:
	_earn_three_stars()
	var screen := _screen()
	_card(screen, &"offroad_4x4").pressed.emit()
	assert_eq(state.progress.selected_car, "offroad_4x4")
	assert_eq(SaveSandbox.requested_scenes, [RALLY_ROAD])


func test_back_returns_to_level_select_or_to_the_main_menu_from_free_drive() -> void:
	var level_screen := _screen()
	level_screen.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Back")[0].pressed.emit()
	assert_eq(SaveSandbox.requested_scenes, [state.LEVEL_SELECT])
	level_screen.queue_free()
	state.pending_scene = state.FREE_DRIVE
	var free_screen := _screen()
	assert_has(_labels(free_screen), "Free Drive")
	free_screen.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Back")[0].pressed.emit()
	assert_eq(SaveSandbox.requested_scenes[-1], state.MAIN_MENU)


func test_car_select_only_uses_characters_the_font_has() -> void:
	var font := ThemeDB.fallback_font
	state.pending_scene = "res://levels/muddy_valley/muddy_valley.tscn"
	var screen := _screen()
	var texts := _labels(screen)
	texts.append("Earn 5 stars to unlock (you have 3)")
	for car in state.car_catalog.cars:
		texts.append_array([car.display_name, car.description, "Best on: %s" % car.best_on])
	for text: String in texts:
		for character in text:
			assert_true(font.has_char(character.unicode_at(0)), "font has '%s' (in \"%s\")" % [character, text])
```

  In `tests/unit/test_menus.gd`, make these changes:
  - In `test_main_menu_play_and_free_drive_open_their_scenes`, replace `assert_eq(SaveSandbox.requested_scenes, [state.LEVEL_SELECT, state.FREE_DRIVE])` with:
    ```gdscript
    	assert_eq(SaveSandbox.requested_scenes, [state.LEVEL_SELECT, state.CAR_SELECT])
    	assert_eq(state.pending_scene, state.FREE_DRIVE, "car select then starts Free Drive")
    ```
  - Rename `test_level_select_opens_an_unlocked_level` to `test_level_select_opens_car_select_for_an_unlocked_level`, and replace its last line, `assert_eq(SaveSandbox.requested_scenes, ["res://levels/rally_road/rally_road.tscn"])`, with:
    ```gdscript
    	assert_eq(SaveSandbox.requested_scenes, [state.CAR_SELECT])
    	assert_eq(state.pending_scene, "res://levels/rally_road/rally_road.tscn")
    ```

- [ ] **Step 2: Run them to see them fail.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_car_select.gd -gexit`
  Expected: SCRIPT ERROR, because `res://ui/car_select.tscn` doesn't exist.

- [ ] **Step 3: Add level surfaces.** Replace `game/level_def.gd` with:

`game/level_def.gd`:

```gdscript
class_name LevelDef
extends Resource
## One timed level: its save key, name, scene and star targets (spec §5.1).

## Stable key for save data. Never rename it once players have saves.
@export var id: StringName = &""
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
## The level's surfaces in a few words for car select, e.g. "Dirt, mud, creek".
@export var surfaces: String = ""
## Finish under this time for two stars (s).
@export var two_star_time: float = 0.0
## Finish under this time for three stars (s).
@export var three_star_time: float = 0.0
```

  In `levels/rally_road/rally_road_level.tres`, add the line `surfaces = "Asphalt"` directly after its `scene_path` line. In `levels/muddy_valley/muddy_valley_level.tres`, add `surfaces = "Dirt, mud, creek"` directly after its `scene_path` line.

- [ ] **Step 4: Create the preview and the screen.**

`ui/car_preview.gd`:

```gdscript
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
			# Roughly where the wheel rests with the car on its springs.
			wheel.position = stats.wheel_mount_position(is_front, is_left) - Vector3(0.0, stats.suspension_length * 0.6, 0.0)
			wheel.rotation_degrees.z = 90.0
			turntable.add_child(wheel)
```

`ui/car_select.gd`:

```gdscript
extends Control
## Car select (spec §5.2): one card per catalog car with a turning preview, its
## description and what it is best on, or how many stars unlock it. The last car
## chosen is highlighted. Tapping an unlocked card saves it and starts
## GameState.pending_scene. Back, Escape or the back gesture return to level select,
## or to the main menu when heading for Free Drive.

const CARD_SIZE := Vector2(560.0, 640.0)
const PREVIEW_SIZE := Vector2i(480, 280)
const NAME_FONT := 56
const SELECTED_BORDER := Color(0.95, 0.72, 0.3)


func _ready() -> void:
	var column := UiKit.centered_column(self, UiKit.BACKGROUND)
	column.add_child(UiKit.label("Choose your car", UiKit.HEADING_FONT))
	column.add_child(UiKit.label(destination_text(GameState.pending_scene)))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 30)
	column.add_child(cards)
	for car in GameState.car_catalog.cars:
		cards.add_child(_card(car))
	column.add_child(UiKit.button("Back", _back))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


## "Muddy Valley · Dirt, mud, creek", "Free Drive", or the level name alone when it
## lists no surfaces.
static func destination_text(scene_path: String) -> String:
	if scene_path == GameState.FREE_DRIVE:
		return "Free Drive"
	var level := GameState.level_for_scene(scene_path)
	if level == null:
		return ""
	if level.surfaces.is_empty():
		return level.display_name
	return "%s · %s" % [level.display_name, level.surfaces]


## "Earn 3 stars to unlock (you have 2)"
static func locked_text(car: CarDef, total_stars: int) -> String:
	return "Earn %d stars to unlock (you have %d)" % [car.unlock_stars, total_stars]


## The card for one car: a button that chooses it, disabled while locked.
func _card(car: CarDef) -> Button:
	var unlocked := GameState.is_car_unlocked(car)
	var card := Button.new()
	card.name = String(car.id)
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = not unlocked
	card.pressed.connect(_choose.bind(car))
	if unlocked and car == GameState.selected_car():
		for state: String in ["normal", "hover", "pressed"]:
			card.add_theme_stylebox_override(state, _selected_style())
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	var preview_holder := CenterContainer.new()
	preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_holder.add_child(CarPreview.new(car, PREVIEW_SIZE))
	content.add_child(preview_holder)
	content.add_child(UiKit.label(car.display_name, NAME_FONT))
	if unlocked:
		content.add_child(_wrapped(car.description))
		content.add_child(UiKit.label("Best on: %s" % car.best_on))
	else:
		content.add_child(_wrapped(locked_text(car, GameState.progress.total_stars(GameState.catalog))))
	return card


func _wrapped(text: String) -> Label:
	var result := UiKit.label(text)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = CARD_SIZE.x - 60.0
	return result


func _selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.27, 0.21, 0.17)
	style.border_color = SELECTED_BORDER
	style.set_border_width_all(6)
	style.set_corner_radius_all(10)
	return style


func _choose(car: CarDef) -> void:
	GameState.set_selected_car(car.id)
	if GameState.pending_scene.is_empty():
		GameState.change_scene(GameState.LEVEL_SELECT)
	else:
		GameState.change_scene(GameState.pending_scene)


func _back() -> void:
	if GameState.pending_scene == GameState.FREE_DRIVE:
		GameState.change_scene(GameState.MAIN_MENU)
	else:
		GameState.change_scene(GameState.LEVEL_SELECT)
```

`ui/car_select.tscn`:

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://ui/car_select.gd" id="1_select"]

[node name="CarSelect" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_select")
```

- [ ] **Step 5: Route level cards and Free Drive through car select.**
  - In `ui/level_select.gd`, replace `card.pressed.connect(GameState.change_scene.bind(level.scene_path))` with `card.pressed.connect(GameState.choose_car_for.bind(level.scene_path))`. Add to the end of the class doc's first sentence: " A card opens car select for its level."
  - In `ui/main_menu.gd`, replace `GameState.change_scene.bind(GameState.FREE_DRIVE)` with `GameState.choose_car_for.bind(GameState.FREE_DRIVE)`, and change "Free Drive (the Test Ground)" in the class doc to "Free Drive (car select, then the Test Ground)".

- [ ] **Step 6: Import and run the tests.**
  Run: `godot --headless --import`, then the Step 2 command and the same for `res://tests/unit/test_menus.gd`. Expected: all pass.
  Run: `./run_tests.sh unit`. Expected: exit 0.

- [ ] **Step 7: Commit.**
  ```bash
  git add ui/car_preview.gd ui/car_preview.gd.uid ui/car_select.gd ui/car_select.gd.uid ui/car_select.tscn game/level_def.gd levels/rally_road/rally_road_level.tres levels/muddy_valley/muddy_valley_level.tres ui/level_select.gd ui/main_menu.gd tests/unit/test_car_select.gd tests/unit/test_car_select.gd.uid tests/unit/test_menus.gd
  git commit -m "Add car select after picking a level and before Free Drive"
  ```

---

### Task 6: Change car, unlock notice, Next level through car select

**Files:**
- Modify: `ui/pause_menu.gd`, `ui/results_screen.gd` (replace whole file), `levels/shared/run_level.gd` (replace whole file), `levels/test_ground/test_ground.gd`, `tests/scenarios/test_rally_road.gd`
- Test: `tests/unit/test_pause_menu.gd` (append), `tests/unit/test_results_screen.gd` (append)

**Interfaces:**
- Consumes (Tasks 3 and 5): `GameState.choose_car_for`, `CAR_SELECT`; `record_finish` result `"new_cars"`.
- Produces:
  - `PauseMenu.car_select_pressed` signal and a "Change car" button (always shown).
  - `ResultsScreen.show_results(time, earned, level, best_time, new_best, has_next, new_cars: Array[CarDef] = [])`; `static unlocks_text(new_cars) -> String`.
  - `RunLevel._change_car()`; Next level calls `choose_car_for(next.scene_path)`.

- [ ] **Step 1: Write the failing tests.** Append to the end of `tests/unit/test_pause_menu.gd`:

```gdscript
func test_change_car_is_offered_in_levels_and_free_drive() -> void:
	for show_restart: bool in [true, false]:
		_add_menu(show_restart)
		var button := _button_starting("Change car")
		assert_true(button.visible, "shown with show_restart %s" % show_restart)
		watch_signals(menu)
		button.pressed.emit()
		assert_signal_emitted(menu, "car_select_pressed")
		menu.queue_free()
```

  Append to the end of `tests/unit/test_results_screen.gd`:

```gdscript
func test_newly_unlocked_cars_are_announced() -> void:
	screen.show_results(80.0, 2, level, 80.0, true, false)
	assert_false(_label_texts().any(func(text: String) -> bool: return text.begins_with("New car")), "nothing new")
	var car := CarDef.new()
	car.display_name = "Off-road 4x4"
	var new_cars: Array[CarDef] = [car]
	screen.show_results(70.0, 3, level, 70.0, true, false, new_cars)
	assert_has(_label_texts(), "New car unlocked: Off-road 4x4")
```

  In `tests/scenarios/test_rally_road.gd`, replace the line `assert_eq(SaveSandbox.requested_scenes[-1], "res://levels/muddy_valley/muddy_valley.tscn", "Next level opens Muddy Valley")` with:
  ```gdscript
  	assert_eq(SaveSandbox.requested_scenes[-1], SaveSandbox.game_state().CAR_SELECT, "Next level opens car select")
  	assert_eq(SaveSandbox.game_state().pending_scene, "res://levels/muddy_valley/muddy_valley.tscn", "for Muddy Valley")
  ```

- [ ] **Step 2: Run them to see them fail.**
  Run the `-gtest` commands for `res://tests/unit/test_pause_menu.gd` and `res://tests/unit/test_results_screen.gd`.
  Expected: failures, because there's no "Change car" button and no unlock line.

- [ ] **Step 3: Add Change car to the pause menu.** In `ui/pause_menu.gd`:
  - Directly after `signal level_select_pressed`, add:
    ```gdscript
    ## Change car: the level opens car select for itself.
    signal car_select_pressed
    ```
  - In `_build_ui`, directly after `column.add_child(restart)`, add `column.add_child(UiKit.button("Change car", car_select_pressed.emit))`.
  - In the class doc, change "Level select (there is no run to restart)." to "Level select (there is no run to restart). Change car is offered in both."

- [ ] **Step 4: Replace `ui/results_screen.gd`:**

`ui/results_screen.gd`:

```gdscript
class_name ResultsScreen
extends CanvasLayer
## The results overlay after a finish (spec §3.6): the run time, stars earned with the
## targets for each star, the all-time best, and Retry / Next level / Level select.
## A level without star times (one built by a test) shows only the time and best.

signal retry_pressed
signal next_pressed
signal level_select_pressed

## Draw above the HUD and the touch controls, below the pause menu.
const LAYER := 15

var stars: StarRow

var _time: Label
var _targets: Label
var _best: Label
var _unlocks: Label
var _next: Button


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	_build_ui()
	visible = false


## Shows the overlay for a finish in `time` that earned `earned` stars on `level`
## (null for a level without star times).
## `new_cars` are the cars this finish unlocked (spec §5.3).
func show_results(time: float, earned: int, level: LevelDef, best_time: float, new_best: bool,
		has_next: bool, new_cars: Array[CarDef] = []) -> void:
	_time.text = RunHud.format_time(time)
	stars.earned = earned
	stars.visible = level != null
	_targets.text = targets_text(level) if level != null else ""
	_best.text = "New best!" if new_best else "Best  %s" % RunHud.format_time(best_time)
	_next.visible = has_next
	_unlocks.text = unlocks_text(new_cars)
	_unlocks.visible = not new_cars.is_empty()
	visible = true


func hide_results() -> void:
	visible = false


func is_showing() -> bool:
	return visible


## "New car unlocked: Off-road 4x4", one line per car; empty when there are none.
static func unlocks_text(new_cars: Array[CarDef]) -> String:
	var lines := PackedStringArray()
	for car in new_cars:
		lines.append("New car unlocked: %s" % car.display_name)
	return "\n".join(lines)


## "1 star: finish · 2 stars: under 1:25.0 · 3 stars: under 1:14.0"
static func targets_text(level: LevelDef) -> String:
	return "1 star: finish · 2 stars: under %s · 3 stars: under %s" % [
		RunHud.format_time(level.two_star_time), RunHud.format_time(level.three_star_time)]


func _build_ui() -> void:
	var column := UiKit.centered_column(self, UiKit.dim(0.45))
	column.add_child(UiKit.label("Finish", UiKit.HEADING_FONT))
	_time = UiKit.label("", UiKit.TITLE_FONT)
	column.add_child(_time)
	stars = StarRow.new()
	column.add_child(UiKit.centered_stars(stars))
	_targets = UiKit.label("")
	column.add_child(_targets)
	_best = UiKit.label("")
	column.add_child(_best)
	_unlocks = UiKit.label("")
	_unlocks.add_theme_color_override("font_color", Color(0.98, 0.8, 0.35))
	_unlocks.visible = false
	column.add_child(_unlocks)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	row.add_child(UiKit.button("Retry", retry_pressed.emit))
	_next = UiKit.button("Next level", next_pressed.emit)
	row.add_child(_next)
	row.add_child(UiKit.button("Level select", level_select_pressed.emit))
```

- [ ] **Step 5: Replace `levels/shared/run_level.gd`:**

`levels/shared/run_level.gd`:

```gdscript
class_name RunLevel
extends Node3D
## A timed level: a generated trail, the driving rig and the run systems, wired
## together. Expects children named Trail (TrailLevel), DrivingRig,
## CheckpointTracker, ResetController, RunController and RunHud; adds its own
## PauseMenu and ResultsScreen. The Trail builds itself in its own _ready, which
## runs before this one.
## Its LevelDef comes from the catalog by scene path; a level that isn't in the
## catalog (one built by a test) runs without stars or saving.
## At the finish the pedals lock and the results appear straight away. Change car
## and Next level go through car select.

@onready var trail: TrailLevel = $Trail
@onready var rig: DrivingRig = $DrivingRig
@onready var tracker: CheckpointTracker = $CheckpointTracker
@onready var resets: ResetController = $ResetController
@onready var run: RunController = $RunController
@onready var hud: RunHud = $RunHud

var level: LevelDef
var pause_menu: PauseMenu
var results: ResultsScreen


func _ready() -> void:
	level = GameState.level_for_scene(scene_file_path)
	if is_missing_from_catalog(scene_file_path, level):
		push_warning("%s is not in the level catalog, so it runs without stars or saving" % scene_file_path)
	if level != null and GameState.progress.best_time(level.id) > 0.0:
		run.clock.set_reference_best(GameState.progress.best_time(level.id), GameState.progress.best_splits(level.id))
	tracker.setup(trail.checkpoints.reset_transforms)
	trail.checkpoints.gate_entered.connect(_on_gate_entered)
	resets.setup(rig, tracker, trail.kill_height())
	hud.setup(run)
	_add_overlays()
	run.run_finished.connect(_on_run_finished)
	run.countdown_started.connect(results.hide_results)
	run.setup(rig, tracker, resets, trail.start_transform())
	print("%s built in %.2f s" % [name, trail.build_seconds])


## True for a level saved as a scene but not listed in the catalog. Levels built
## in code by tests have no scene path and are expected to be missing.
static func is_missing_from_catalog(scene_path: String, found: LevelDef) -> bool:
	return found == null and not scene_path.is_empty()


func _add_overlays() -> void:
	results = ResultsScreen.new()
	results.name = "ResultsScreen"
	add_child(results)
	results.retry_pressed.connect(_retry)
	results.next_pressed.connect(_next_level)
	results.level_select_pressed.connect(GameState.change_scene.bind(GameState.LEVEL_SELECT))
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.setup(rig)
	pause_menu.restart_pressed.connect(run.restart)
	pause_menu.level_select_pressed.connect(GameState.change_scene.bind(GameState.LEVEL_SELECT))
	pause_menu.main_menu_pressed.connect(GameState.change_scene.bind(GameState.MAIN_MENU))
	pause_menu.back_pressed.connect(_on_back)
	pause_menu.car_select_pressed.connect(_change_car)
	rig.pause_requested.connect(_on_pause_requested)


func _on_gate_entered(index: int, body: Node3D) -> void:
	if body == rig.car:
		tracker.enter_gate(index)


func _on_pause_requested() -> void:
	if not results.is_showing():
		pause_menu.toggle()


## The back gesture or Escape with the pause menu closed.
func _on_back() -> void:
	if results.is_showing():
		GameState.change_scene(GameState.LEVEL_SELECT)
	else:
		pause_menu.open()


func _on_run_finished(time: float, splits: Dictionary) -> void:
	var earned := 0
	var best := time
	var new_best := true
	var has_next := false
	var new_cars: Array[CarDef] = []
	if level != null:
		var result := GameState.record_finish(level, time, splits)
		earned = result["stars"]
		best = result["best_time"]
		new_best = result["new_best"]
		new_cars.assign(result["new_cars"])
		var next := GameState.catalog.next_after(level)
		has_next = next != null and GameState.progress.is_unlocked(GameState.catalog, next)
	results.show_results(time, earned, level, best, new_best, has_next, new_cars)


func _retry() -> void:
	if scene_file_path.is_empty():
		run.restart()
	else:
		GameState.change_scene(scene_file_path)


## Change car: car select for this level, which then restarts it with the new car.
## A level built by a test has no scene to return to, so it just restarts.
func _change_car() -> void:
	if scene_file_path.is_empty():
		pause_menu.close()
		run.restart()
	else:
		GameState.choose_car_for(scene_file_path)


func _next_level() -> void:
	var next := GameState.catalog.next_after(level) if level != null else null
	if next != null:
		GameState.choose_car_for(next.scene_path)
```

- [ ] **Step 6: Change car in Free Drive.** In `levels/test_ground/test_ground.gd`, directly after `pause_menu.main_menu_pressed.connect(GameState.change_scene.bind(GameState.MAIN_MENU))`, add:
  ```gdscript
  	pause_menu.car_select_pressed.connect(GameState.choose_car_for.bind(GameState.FREE_DRIVE))
  ```

- [ ] **Step 7: Run the tests.**
  Run the Step 2 commands, and `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/scenarios/test_rally_road.gd -gexit`. Expected: all pass.
  Run: `./run_tests.sh all`. Expected: exit 0.

- [ ] **Step 8: Commit.**
  ```bash
  git add ui/pause_menu.gd ui/results_screen.gd levels/shared/run_level.gd levels/test_ground/test_ground.gd tests/unit/test_pause_menu.gd tests/unit/test_results_screen.gd tests/scenarios/test_rally_road.gd
  git commit -m "Change car from the pause menu and announce unlocked cars"
  ```

---

### Task 7: The cars on real ground, screenshots and notes

**Files:**
- Create: `tests/scenarios/test_cars.gd`, `docs/notes/performance-m3a.md`
- Modify: `tests/scenarios/trail_driver.gd` (replace whole file), `tests/scenarios/test_jump_landing.gd` (replace whole file), `tools/level_shots.gd` (replace whole file)

**Interfaces:**
- Consumes: everything above; `TrailDriver`, `TrailScenarios`, `ScenarioHelper`.
- Produces:
  - `TrailDriver.new(car, sampler, profile: RoadProfile = null)`: with a profile, speed also allows for the surface ahead.
  - `tools/level_shots.tscn` accepts an optional `car=<id>` argument after the level scene.
  - Measured desktop notes.

- [ ] **Step 1: Give the scripted driver a surface-aware mode.** Replace `tests/scenarios/trail_driver.gd` with:

`tests/scenarios/trail_driver.gd`:

```gdscript
class_name TrailDriver
extends RefCounted
## A scripted driver for scenario tests: steers toward a point a little way up
## the road (pure pursuit) and picks a speed from how sharply the road bends
## ahead. Not a good driver - just a steady one. Given the road's profile, it also
## slows for the grip of the surface ahead (mud, dirt), on straights as in bends.

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
## When set, the speed also allows for the surface ahead; without it (the default)
## the driver judges bends by the car's tire grip alone.
var profile: RoadProfile


func _init(driven_car: Car, road: RoadSampler, road_profile: RoadProfile = null) -> void:
	car = driven_car
	sampler = road
	profile = road_profile


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
	var surface_grip := _lowest_surface_grip(distance) if profile != null else 1.0
	var fastest := MAX_SPEED * sqrt(minf(surface_grip, 1.0))
	if sharpest < 0.0001:
		return fastest
	var grip_speed := sqrt(car.stats.tire_grip * surface_grip * 9.8 / sharpest)
	return clampf(grip_speed * CAUTION, MIN_SPEED, fastest)


## The lowest grip of the road surface over the window ahead, as this car feels it
## (the surface's grip times the car's grip-table multiplier for it).
func _lowest_surface_grip(distance: float) -> float:
	var lowest := INF
	var ahead := 0.0
	while ahead <= CURVE_WINDOW:
		var surface := profile.surface_at(distance + ahead)
		lowest = minf(lowest, surface.grip * car.grip_table.multiplier(car.stats.archetype, surface.id))
		ahead += 5.0
	return lowest
```

  Then write the scenarios. Create `tests/scenarios/test_cars.gd`:

`tests/scenarios/test_cars.gd`:

```gdscript
extends GutTest
## The three cars on real ground (spec §8.2): the new cars finish both levels, the
## tuned car is quicker on asphalt, the 4x4 is quicker up the mud climb and its
## differential locks matter, the 4x4 does not roll at full lock, and a run drives
## the car chosen in car select.

const RALLY_ROAD := preload("res://levels/rally_road/rally_road.tscn")
const MUDDY_VALLEY := preload("res://levels/muddy_valley/muddy_valley.tscn")
const CAR_SCENE := preload("res://car/car.tscn")
const RALLY := preload("res://car/cars/rally.tres")
const TUNED := preload("res://car/cars/rally_tuned.tres")
const OFFROAD := preload("res://car/cars/offroad_4x4.tres")
const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


## A level scene driven by `car_def`, with touch controls off.
func _level(scene: PackedScene, car_def: CarDef) -> RunLevel:
	var level: RunLevel = scene.instantiate()
	(level.get_node("DrivingRig") as DrivingRig).car_override = car_def
	add_child(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func _free(node: Node) -> void:
	remove_child(node)
	node.queue_free()
	await get_tree().process_frame


## Drives a whole level with the scripted driver. Returns the finish time, or -1.0
## without a finish; fails the test on any reset. `surface_aware` makes the driver
## slow for the grip of the surface ahead.
func _scripted_run(scene: PackedScene, car_def: CarDef, surface_aware := false) -> float:
	var level := _level(scene, car_def)
	var driver := TrailDriver.new(level.rig.car, level.trail.sampler, level.trail.profile if surface_aware else null)
	watch_signals(level.resets)
	for tick in ScenarioHelper.ticks(200.0):
		if level.tracker.is_finished():
			break
		driver.drive()
		await get_tree().physics_frame
	var time := level.run.clock.elapsed if level.tracker.is_finished() else -1.0
	var resets: int = get_signal_emit_count(level.resets, "car_reset")
	gut.p("%s on %s: %s, %d resets" % [car_def.display_name, level.name,
			RunHud.format_time(time) if time > 0.0 else "no finish", resets])
	assert_eq(resets, 0, "%s on %s: no resets" % [car_def.display_name, level.name])
	await _free(level)
	return time


func test_every_car_finishes_rally_road_and_the_tuned_car_is_quickest() -> void:
	var times := {}
	for car_def: CarDef in [RALLY, TUNED, OFFROAD]:
		times[car_def.id] = await _scripted_run(RALLY_ROAD, car_def)
		assert_between(times[car_def.id], 60.0, 150.0, car_def.display_name)
	assert_lt(times[&"rally_tuned"], times[&"rally"], "the tuned car beats stock on asphalt")


## The plain scripted driver judges speed by tire grip alone, so the grippier tuned
## car reaches Muddy Valley's hedged mud too fast and slides into a hedge it cannot
## reverse away from. The surface-aware driver slows for mud, as a player would.
func test_the_new_cars_finish_muddy_valley() -> void:
	for car_def: CarDef in [TUNED, OFFROAD]:
		var time := await _scripted_run(MUDDY_VALLEY, car_def, true)
		assert_between(time, 60.0, 150.0, car_def.display_name)


## Seconds from rest to `kmh` at full throttle, straight on flat `surface`; -1.0 if
## not reached in 20 s. `stats` override `car_def`'s own when set.
func _time_to_speed(car_def: CarDef, surface: SurfaceDef, kmh: float) -> float:
	var ground := ScenarioHelper.make_flat_ground(surface)
	add_child(ground)
	var car: Car = CAR_SCENE.instantiate()
	car.stats = car_def.stats
	car.body_def = car_def.body
	car.position = Vector3(0.0, 1.0, 0.0)
	add_child(car)
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	var seconds := -1.0
	for tick in ScenarioHelper.ticks(20.0):
		car.input.virtual_throttle = 1.0
		await get_tree().physics_frame
		if car.forward_speed() * 3.6 >= kmh:
			seconds = tick / float(Engine.physics_ticks_per_second)
			break
	await _free(car)
	await _free(ground)
	return seconds


func test_the_tuned_car_reaches_100_kmh_clearly_sooner_than_stock() -> void:
	var stock := await _time_to_speed(RALLY, ASPHALT, 100.0)
	var tuned := await _time_to_speed(TUNED, ASPHALT, 100.0)
	gut.p("0-100 km/h on asphalt: stock %.2f s, tuned %.2f s" % [stock, tuned])
	assert_gt(stock, 0.0)
	assert_gt(tuned, 0.0)
	assert_lt(tuned, stock * 0.9, "at least 10% sooner")


func test_the_4x4_climbs_out_of_the_mud_sooner_than_the_rally_car() -> void:
	var seconds := {}
	for car_def: CarDef in [RALLY, OFFROAD]:
		var level := _level(MUDDY_VALLEY, car_def)
		await TrailScenarios.wait_for_go(level)
		await TrailScenarios.place_on_road(level, 1400.0)
		var finish := level.trail.checkpoints.gate_distances[-1]
		var car := level.rig.car
		seconds[car_def.id] = await TrailScenarios.full_throttle_until(level, 30.0,
				func() -> bool: return level.trail.sampler.closest_distance(car.global_position) >= finish)
		await _free(level)
	gut.p("from a standstill at 1400 m up the mud to the finish: Rally Car %.1f s, 4x4 %.1f s" % [
			seconds[&"rally"], seconds[&"offroad_4x4"]])
	assert_lt(seconds[&"offroad_4x4"], seconds[&"rally"])


## Metres covered from rest in `seconds` at full throttle, with the left wheels on
## near-frictionless ground and the right wheels on dirt.
func _split_surface_pull(stats: CarStats, seconds: float) -> float:
	var slick := SurfaceDef.new()
	slick.id = &"slick"
	slick.grip = 0.05
	var left := ScenarioHelper.make_flat_ground(slick, Vector3(-150.0, 0.0, 0.0), 300.0)
	var right := ScenarioHelper.make_flat_ground(DIRT, Vector3(150.0, 0.0, 0.0), 300.0)
	add_child(left)
	add_child(right)
	var car: Car = CAR_SCENE.instantiate()
	car.stats = stats
	car.position = Vector3(0.0, 1.2, 0.0)
	add_child(car)
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	var start := car.global_position
	for tick in ScenarioHelper.ticks(seconds):
		car.input.virtual_throttle = 1.0
		await get_tree().physics_frame
	var covered := Vector2(car.global_position.x - start.x, car.global_position.z - start.z).length()
	await _free(car)
	await _free(left)
	await _free(right)
	return covered


func test_the_4x4s_locks_pull_it_away_with_one_side_on_slippery_ground() -> void:
	var open: CarStats = OFFROAD.stats.duplicate()
	open.front_diff_lock = 0.0
	open.rear_diff_lock = 0.0
	open.centre_diff_lock = 0.0
	var locked := await _split_surface_pull(OFFROAD.stats, 4.0)
	var unlocked := await _split_surface_pull(open, 4.0)
	gut.p("4 s from rest, left wheels on slick ground: locked %.1f m, open %.1f m" % [locked, unlocked])
	assert_gt(locked, unlocked * 1.15, "the locks clearly help")


func test_the_4x4_does_not_roll_over_at_full_lock() -> void:
	var ground := ScenarioHelper.make_flat_ground(DIRT)
	add_child(ground)
	var car: Car = CAR_SCENE.instantiate()
	car.stats = OFFROAD.stats
	car.position = Vector3(0.0, 1.2, 0.0)
	add_child(car)
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	var lowest_up := 1.0
	for tick in ScenarioHelper.ticks(12.0):
		var turning := car.forward_speed() * 3.6 >= 40.0 or tick > ScenarioHelper.ticks(8.0)
		car.input.virtual_steer = 1.0 if turning else 0.0
		car.input.virtual_throttle = 1.0 if car.forward_speed() * 3.6 < 40.0 else 0.0
		await get_tree().physics_frame
		if turning:
			lowest_up = minf(lowest_up, car.global_basis.y.y)
	gut.p("4x4 at full lock around 40 km/h on dirt: most tilt %.0f deg" % rad_to_deg(acos(clampf(lowest_up, -1.0, 1.0))))
	assert_true(ScenarioHelper.is_upright(car), "still on its wheels")
	assert_gt(lowest_up, 0.5, "never tipped past 60 degrees")
	await _free(car)
	await _free(ground)


func test_a_run_drives_the_car_chosen_in_car_select() -> void:
	var state := SaveSandbox.game_state()
	state.record_finish(state.catalog.levels[0], 60.0, {})
	state.set_selected_car(&"offroad_4x4")
	var level: RunLevel = RALLY_ROAD.instantiate()
	add_child_autofree(level)
	assert_eq(level.rig.car_def, OFFROAD)
	assert_eq(level.rig.car.stats, OFFROAD.stats)
	level.results.retry_pressed.emit()
	assert_eq(SaveSandbox.requested_scenes, [level.scene_file_path], "Retry reloads the level")
	assert_eq(state.selected_car(), OFFROAD, "with the same car")
	level.pause_menu.car_select_pressed.emit()
	assert_eq(SaveSandbox.requested_scenes[-1], state.CAR_SELECT, "Change car opens car select")
	assert_eq(state.pending_scene, level.scene_file_path, "for this level")
```

  Replace `tests/scenarios/test_jump_landing.gd` with the version whose kicker helper takes a car:

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
## `car` drives instead of the player's selected car when set.
func _take_kicker(hold_throttle: bool, car_def: CarDef = null) -> Dictionary:
	var level: Node3D = TEST_GROUND.instantiate()
	var rig: DrivingRig = level.get_node("DrivingRig")
	rig.car_override = car_def
	add_child_autofree(level)
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
	gut.p("%s: kicker at %.0f km/h, gas %s: %.2f s in the air, worst tilt %.0f deg, peak yaw %.1f deg/s in the 0.5 s after landing, upright %s" % [
		rig.car_def.display_name, APPROACH_KMH, "held" if hold_throttle else "lifted", result.air_seconds, result.worst_pitch_deg,
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
		# Known since Milestone 2A (at 100 km/h: 62 deg nose-down and a 41 deg/s yaw kick
		# with the first tune, 64 deg and 22 deg/s after the Session 3 weight/grip pass;
		# a full flip at 115 km/h). Waiting on a feel decision with the user, so it is
		# reported rather than failed.
		pending("holding the gas off the kicker pitches the nose down: %.0f deg, yaw kick %.1f deg/s" % [
			result.worst_pitch_deg, result.landing_yaw])
		return
	assert_true(result.landed, "the car took off and landed")


func test_the_new_cars_land_the_kicker_upright() -> void:
	for car_def: CarDef in [preload("res://car/cars/rally_tuned.tres"), preload("res://car/cars/offroad_4x4.tres")]:
		var result := await _take_kicker(false, car_def)
		assert_true(result.landed, "%s took off and landed" % car_def.display_name)
		assert_true(result.upright, "%s is upright after landing" % car_def.display_name)
```

- [ ] **Step 2: Run them.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/scenarios/test_cars.gd -gexit` (several minutes), and the same for `res://tests/scenarios/test_jump_landing.gd`.
  Expected: all pass (the known held-gas kicker test stays pending). In the scratch clone they printed:
    ```
  Rally Car on RallyRoad: 1:30.3, 0 resets
  Rally Car Tuned on RallyRoad: 1:26.3, 0 resets
  Off-road 4x4 on RallyRoad: 1:40.8, 0 resets
  Rally Car Tuned on MuddyValley: 1:38.2, 0 resets
  Off-road 4x4 on MuddyValley: 1:35.0, 0 resets
  0-100 km/h on asphalt: stock 7.49 s, tuned 5.14 s
  from a standstill at 1400 m up the mud to the finish: Rally Car 16.6 s, 4x4 11.6 s
  4 s from rest, left wheels on slick ground: locked 10.0 m, open 1.9 m
  4x4 at full lock around 40 km/h on dirt: most tilt 3 deg
  Rally Car Tuned: kicker at 100 km/h, gas lifted: 1.25 s in the air, worst tilt 12 deg, peak yaw 0.2 deg/s in the 0.5 s after landing, upright true
  Off-road 4x4: kicker at 100 km/h, gas lifted: 1.11 s in the air, worst tilt 16 deg, peak yaw 0.1 deg/s in the 0.5 s after landing, upright true
  ```
  Timing lines may differ slightly between machines; the assertions must pass. If an assertion fails, report BLOCKED with the output; don't retune stats.

- [ ] **Step 3: Let the screenshot tool pick a car.** Replace `tools/level_shots.gd` with:

`tools/level_shots.gd`:

```gdscript
extends Node
## Renders a level in a window at points along its road, saves a PNG for each
## and prints the build time and what was drawn there (primitives, draw calls,
## objects). Run from the project root:
##   godot --path . res://tools/level_shots.tscn -- res://levels/muddy_valley/muddy_valley.tscn 15 320 760 car=offroad_4x4
## The first argument after "--" is the level scene; the rest are distances along
## the road (m), plus an optional car=<id> to drive instead of the selected car.
## Shots are saved as build/level_shots/<level>[_<car>]_<distance>.png.

const OUT_DIR := "res://build/level_shots"
## Frames to wait at each spot so the camera and visibility ranges settle.
const SETTLE_FRAMES := 45


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var car_id := ""
	var spots: Array[float] = []
	for arg in args.slice(1):
		if arg.begins_with("car="):
			car_id = arg.trim_prefix("car=")
		else:
			spots.append(float(arg))
	if args.is_empty() or spots.is_empty():
		push_error("usage: -- <level scene> <distance> [distance...] [car=<id>]")
		get_tree().quit(1)
		return
	var level: RunLevel = load(args[0]).instantiate()
	if not car_id.is_empty():
		var car := GameState.car_catalog.find_by_id(StringName(car_id))
		if car == null:
			push_error("unknown car: %s" % car_id)
			get_tree().quit(1)
			return
		(level.get_node("DrivingRig") as DrivingRig).car_override = car
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	add_child(level)
	await get_tree().process_frame
	var tag := args[0].get_file().get_basename()
	if not car_id.is_empty():
		tag += "_" + car_id
	print("%s built in %.2f s" % [tag, level.trail.build_seconds])
	for spot in spots:
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

- [ ] **Step 4: Take the shots and record the notes.**
  Run `godot --headless --import`, then, in a window:
  ```bash
  godot --path . res://tools/level_shots.tscn -- res://levels/rally_road/rally_road.tscn 15 700 car=rally_tuned
  godot --path . res://tools/level_shots.tscn -- res://levels/muddy_valley/muddy_valley.tscn 560 1400 car=offroad_4x4
  godot --path . res://tools/level_shots.tscn -- res://levels/muddy_valley/muddy_valley.tscn 560 car=rally
  tools/screenshot.sh res://ui/car_select.tscn 3
  ```
  Create `docs/notes/performance-m3a.md` with:
  - the render counts printed above
  - the Step 2 scenario lines
  - the car select screenshot path (`build/screenshots/…`)

  Compare Muddy Valley at 560 m with each car against the 300k budget. List the PNG paths in your report; don't commit the images.

- [ ] **Step 5: Run everything and commit.**
  Run: `./run_tests.sh all`. Expected: exit 0.
  ```bash
  git add tests/scenarios/trail_driver.gd tests/scenarios/test_cars.gd tests/scenarios/test_cars.gd.uid tests/scenarios/test_jump_landing.gd tools/level_shots.gd docs/notes/performance-m3a.md
  git commit -m "Check the three cars on real ground and record their numbers"
  ```
