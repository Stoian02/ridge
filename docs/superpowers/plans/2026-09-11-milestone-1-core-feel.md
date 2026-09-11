# Milestone 1 — Core Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A drivable Rally Car with custom raycast physics on a gray-box Test Ground, controlled by keyboard/gamepad and touch, with telemetry, run recording and automated tests, running as a debug build on the user's Xiaomi 13, and ending with the user signing off on the feel.

**Architecture:** One `RigidBody3D` (Jolt) car with four sphere-cast wheels. Pure-math modules (`TireModel`, `SuspensionModel`, `Drivetrain`, `Steering`, `AirControl`) hold all the physics logic and are unit-tested in isolation; `Wheel` and `Car` wire them into the scene tree. Every tuning number lives in `.tres` resources (`CarStats`, `SurfaceDef`, `GripTable`). Scenario tests drive the real car headless on flat ground to guard its behaviour.

**Tech Stack:** Godot 4.7.2 stable (standard build, `godot` on PATH), typed GDScript, Jolt Physics, GUT 9.7.1, Mobile renderer (Vulkan), Android debug export (JDK 17 and Android SDK already installed on this machine).

**Spec:** `docs/superpowers/specs/2026-09-11-ridge-design.md`, Milestone 1 (§11), drawing on §2 (gameplay), §3 (cars), §4 (vehicle physics), §5 (surfaces), §8 (visuals), §9 (structure) and §10 (testing).

## Global Constraints

- Godot **4.7.2 stable**; GDScript only, statically typed; no C#.
- Physics engine `"Jolt Physics"`; physics at **120 ticks/s**; rendering capped at **60 FPS**.
- `threading/worker_pool/max_threads=4`. Required: with the default thread count, Jolt intermittently fails tests with "job system exceeded the maximum number of jobs" on this 20-thread machine (measured: 2 of 30 runs failed by default, 0 of 30 with the cap).
- Renderer: Mobile (`rendering/renderer/rendering_method="mobile"`). Orientation: sensor landscape (`display/window/handheld/orientation=4`).
- All tunable numbers live in resources (`CarStats`, `SurfaceDef`, `GripTable`), never hard-coded in physics scripts.
- Axes: forward = −Z, right = +X, up = +Y. Units: SI (m, kg, s, N, Nm); degrees only in names ending `_deg`.
- Wheel arrays are always ordered `[FL, FR, RL, RR]`.
- Readable over clever; small single-purpose files; feature folders (`car/`, `surfaces/`, `input/`, `camera/`, `debug/`, `levels/`, `tests/`, `tools/`).
- GDScript is tab-indented. Copy code blocks verbatim.
- Tests: GUT 9.7.1 vendored at `addons/gut/`; run with `./run_tests.sh unit|scenarios|all`. Unit tests hold pure logic; scenario tests drive the real car with headless physics. Scenario pass ranges live only in `tests/scenarios/feel_baseline.gd`.
- Cars get fictional names and no real badges (spec §3.1). Android package id: `com.ridge.game`.
- Commit at the end of every task with the message given, followed by the commit trailer lines required by the session executing the plan.

## Verified Before Writing

Every code block in Tasks 1–17 was built and run in a throwaway copy of this project on this machine (Godot 4.7.2). The result was **123 passing tests** and a rendered Test Ground. The measured behaviour, which the "Expected" lines below refer to (differences of ±5% are fine):

| Check | Measured |
|---|---|
| 0–100 km/h (asphalt) | 7.7 s |
| Braking 100–0 km/h (asphalt) | 36.6 m |
| Creep when parked, 3 s | 0.2 mm |
| Tire slip in a 50 km/h full-lock turn | asphalt 12.1°, mud 13.0° |
| Yaw rate in the same turn | asphalt 26.0°/s, mud 14.8°/s |

Two problems found and fixed during that run are already reflected in this plan:
- **Gearbox hunting.** Shifting on wheel spin made wheelspin trigger 1↔2 shift loops. The gearbox now shifts on road speed.
- **Runaway wheelspin.** The touch pedals are on/off, so full throttle meant runaway wheelspin. Traction control was added (a `CarStats` flag, on by default).

Tasks 18–20 need the export templates, the phone and the user, so they could not be pre-run.

## Additions and Deferrals Relative to the Spec

- **Added:** traction control, simple ABS, and auto-hold at standstill. These are mobile-friendly assists; each is a `CarStats` setting.
- **Deferred:** `SurfaceDef` particle and audio fields move to the milestone that builds particles and audio. Locked differentials arrive with the 4x4. Automatic flip and out-of-bounds resets are Milestone 2; Milestone 1 has the manual Reset only.

## File Map

| File | Responsibility |
|---|---|
| `project.godot` | Engine settings (Jolt, 120 Hz physics, 60 FPS cap, Mobile renderer, landscape, thread cap) |
| `run_tests.sh` | Runs GUT headless; fails on test failures or script errors |
| `surfaces/surface_def.gd` | `SurfaceDef` resource: grip, rolling resistance, sink, drag, debug colour |
| `surfaces/grip_table.gd` | `GripTable` resource: car archetype × surface grip multipliers |
| `surfaces/surface_lookup.gd` | Finds a collider's `SurfaceDef` via its `surface` meta; falls back to dirt |
| `surfaces/{asphalt,dirt,mud,grip_table}.tres` | Surface and grip-table data |
| `car/tire_model.gd` | Pure tire math: grip curve, slip, combined force, anti-overshoot limits |
| `car/suspension_model.gd` | Pure suspension math: spring/damper, bump stop, anti-roll |
| `car/car_stats.gd`, `car/rally_car.tres` | `CarStats` resource and the Rally Car's numbers |
| `car/drivetrain.gd` | Engine, auto gearbox, reverse logic, traction control, torque/brake split |
| `car/steering.gd` | Speed-sensitive, rate-limited front-wheel angle |
| `car/air_control.gd` | Airborne detection with grace period; pitch/roll torque |
| `car/wheel.gd` | One wheel: sphere cast contact, suspension + tire forces, wheel spin, visuals |
| `car/car.gd`, `car/car.tscn` | The car body: runs the per-tick pipeline, reset, telemetry snapshot |
| `input/input_actions.gd` | Registers keyboard/gamepad actions in code |
| `input/car_input.gd` | Single source of steer/throttle/brake; merges devices and virtual inputs |
| `input/touch_steer_logic.gd` | Pure maths for analog and button touch steering |
| `input/touch_controls.gd` | On-screen pedals, steering, and top-strip buttons |
| `camera/chase_camera.gd` | Smoothed chase camera with terrain avoidance |
| `debug/telemetry_overlay.gd` | On-screen performance, car and per-wheel numbers |
| `debug/run_recorder.gd` | Per-tick CSV recording to `user://runs/` |
| `levels/shared/golden_hour_mood.gd` | Over the Hill-style sky, sun, fog and grade |
| `levels/test_ground/test_ground.gd`, `.tscn` | Gray-box tuning ground and the Milestone 1 main scene |
| `tests/unit/*`, `tests/scenarios/*` | GUT tests, scenario helpers, feel baseline |
| `tools/screenshot.sh`, `tools/android.sh`, `tools/pull_runs.sh` | Screenshots, phone builds, pulling runs off the phone |
| `export_presets.cfg` | Android debug export preset |

---

### Task 1: Project scaffold and test runner

**Files:**
- Create: `project.godot`, `.gitignore`, `run_tests.sh`, `addons/gut/` (vendored), `tests/unit/test_smoke.gd`

**Interfaces:**
- Produces: `./run_tests.sh [unit|scenarios|all]`, which exits non-zero on any failing test or script error. (`all` works once `tests/scenarios/` exists, from Task 11.)

- [ ] **Step 1: Create `project.godot`**

The main scene is added in Task 17, once it exists.

```ini
; Engine configuration file.
; Edit with care: keep sections and keys in the format Godot writes.

config_version=5

[application]

config/name="Ridge"
config/features=PackedStringArray("4.7", "Mobile")
run/max_fps=60

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=4

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[input_devices]

pointing/emulate_touch_from_mouse=true

[physics]

3d/physics_engine="Jolt Physics"
common/physics_ticks_per_second=120

[rendering]

renderer/rendering_method="mobile"
textures/vram_compression/import_etc2_astc=true

[threading]

worker_pool/max_threads=4
```

- [ ] **Step 2: Create `.gitignore`**

`.gitignore`:

```
# Godot cache and generated Android project
.godot/
/android/

# Local build output and runs pulled from the phone
/build/
/runs/
```

- [ ] **Step 3: Vendor GUT 9.7.1** (the release built for Godot 4.7)

```bash
git clone -q --depth 1 --branch v9.7.1 https://github.com/bitwes/Gut.git /tmp/gut-9.7.1
cp -r /tmp/gut-9.7.1/addons/gut addons/
rm -rf /tmp/gut-9.7.1
ls addons/gut/gut_cmdln.gd
```

Expected: `addons/gut/gut_cmdln.gd` is listed.

- [ ] **Step 4: Create the test runner and make it executable**

`run_tests.sh`:

```bash
#!/usr/bin/env bash
# Runs the GUT test suites headless.
# Usage: ./run_tests.sh [unit|scenarios|all]   (default: all)
# Exits non-zero if any test fails OR any script fails to load. GUT itself exits 0
# when a test file has a parse error, so the log is checked for script errors too.
set -uo pipefail
cd "$(dirname "$0")"

suite="${1:-all}"
case "$suite" in
  unit) dirs="res://tests/unit" ;;
  scenarios) dirs="res://tests/scenarios" ;;
  all) dirs="res://tests/unit,res://tests/scenarios" ;;
  *) echo "Unknown suite: $suite (use unit, scenarios or all)"; exit 2 ;;
esac

# Import first so newly added class_name scripts are registered.
godot --headless --import >/dev/null 2>&1

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# --fixed-fps 120 runs physics as fast as the CPU allows instead of in real time.
# --max-fps 0 lifts the project's 60 FPS cap for the test run.
godot --headless --fixed-fps 120 --max-fps 0 \
  -s addons/gut/gut_cmdln.gd -gdir="$dirs" -ginclude_subdirs -gexit 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

if grep -q "SCRIPT ERROR" "$log"; then
  echo "run_tests.sh: script errors found (see above) - failing the run."
  exit 1
fi
exit "$status"
```

```bash
chmod +x run_tests.sh
```

- [ ] **Step 5: Write the smoke test**

`tests/unit/test_smoke.gd`:

```gdscript
extends GutTest
## Guards the project settings everything else depends on.


func test_uses_jolt_physics() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")


func test_physics_runs_at_120_hz() -> void:
	assert_eq(Engine.physics_ticks_per_second, 120)


func test_worker_threads_are_capped() -> void:
	# Jolt's job system intermittently overflows with many worker threads.
	assert_eq(ProjectSettings.get_setting("threading/worker_pool/max_threads"), 4)
```

- [ ] **Step 6: Run the unit suite**

Run: `./run_tests.sh unit`
Expected: `Passing Tests 3`, exit code 0.

- [ ] **Step 7: Prove the runner catches broken test files**

GUT on its own exits 0 when a test file fails to parse.

```bash
printf 'extends GutTest\n\nfunc test_x() -> void:\n\tassert_eq(NotYetWritten.answer(), 42)\n' > tests/unit/test_runner_check.gd
./run_tests.sh unit; echo "exit=$?"
rm -f tests/unit/test_runner_check.gd tests/unit/test_runner_check.gd.uid
```

Expected: `SCRIPT ERROR: Parse Error: Identifier "NotYetWritten" not declared in the current scope.`, then `run_tests.sh: script errors found`, then `exit=1`.

- [ ] **Step 8: Commit**

```bash
git add project.godot .gitignore run_tests.sh addons tests
git commit -m "Set up Godot project, GUT and test runner"
```

---

### Task 2: Surface definitions

**Files:**
- Create: `surfaces/surface_def.gd`, `surfaces/grip_table.gd`, `surfaces/surface_lookup.gd`, `surfaces/asphalt.tres`, `surfaces/dirt.tres`, `surfaces/mud.tres`, `surfaces/grip_table.tres`
- Test: `tests/unit/test_surfaces.gd`

**Interfaces:**
- Produces:
  - `SurfaceDef` (Resource) with `id: StringName`, `display_name: String`, `grip: float`, `rolling_resistance: float`, `sink_depth: float`, `drag: float`, `debug_color: Color`.
  - `GripTable` (Resource) with `multipliers: Dictionary` and `multiplier(archetype: StringName, surface_id: StringName) -> float` (1.0 when missing).
  - `SurfaceLookup.META_KEY` (`&"surface"`) and `static SurfaceLookup.surface_of(collider: Object) -> SurfaceDef`. Untagged, null or wrong meta falls back to `res://surfaces/dirt.tres`.
  - Data: `res://surfaces/asphalt.tres`, `dirt.tres`, `mud.tres`, `grip_table.tres`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_surfaces.gd`:

```gdscript
extends GutTest

const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")
const GRIP_TABLE := preload("res://surfaces/grip_table.tres")


func test_surface_files_have_ids() -> void:
	assert_eq(ASPHALT.id, &"asphalt")
	assert_eq(DIRT.id, &"dirt")
	assert_eq(MUD.id, &"mud")


func test_grip_order_is_asphalt_then_dirt_then_mud() -> void:
	assert_gt(ASPHALT.grip, DIRT.grip)
	assert_gt(DIRT.grip, MUD.grip)


func test_mud_sinks_and_resists_more_than_asphalt() -> void:
	assert_gt(MUD.sink_depth, ASPHALT.sink_depth)
	assert_gt(MUD.rolling_resistance, ASPHALT.rolling_resistance)
	assert_gt(MUD.drag, ASPHALT.drag)


func test_lookup_returns_tagged_surface() -> void:
	var body: StaticBody3D = autofree(StaticBody3D.new())
	body.set_meta(SurfaceLookup.META_KEY, MUD)
	assert_eq(SurfaceLookup.surface_of(body), MUD)


func test_lookup_falls_back_to_dirt_when_untagged() -> void:
	var body: StaticBody3D = autofree(StaticBody3D.new())
	assert_eq(SurfaceLookup.surface_of(body).id, &"dirt")


func test_lookup_falls_back_for_null_and_wrong_meta() -> void:
	assert_eq(SurfaceLookup.surface_of(null).id, &"dirt")
	var body: StaticBody3D = autofree(StaticBody3D.new())
	body.set_meta(SurfaceLookup.META_KEY, "not a surface")
	assert_eq(SurfaceLookup.surface_of(body).id, &"dirt")


func test_grip_table_lookup_and_default() -> void:
	assert_almost_eq(GRIP_TABLE.multiplier(&"rally", &"mud"), 1.1, 0.0001)
	assert_almost_eq(GRIP_TABLE.multiplier(&"unknown", &"mud"), 1.0, 0.0001)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1 with a `SCRIPT ERROR` about the missing `res://surfaces/asphalt.tres` preload or `SurfaceLookup`.

- [ ] **Step 3: Write the surface scripts**

`surfaces/surface_def.gd`:

```gdscript
class_name SurfaceDef
extends Resource
## Physical properties of a ground surface (asphalt, mud, ...).
## Ground collision bodies point at one of these through their "surface" meta entry.

## Short identifier, also used as the GripTable key ("asphalt", "mud", ...).
@export var id: StringName = &""
@export var display_name: String = ""
## Base tire friction. 1.0 = dry asphalt.
@export_range(0.0, 2.0) var grip: float = 1.0
## Rolling resistance: resisting force = rolling_resistance x wheel load.
@export_range(0.0, 0.5) var rolling_resistance: float = 0.015
## How far wheels sink into the surface, in metres.
@export_range(0.0, 0.2) var sink_depth: float = 0.0
## Extra drag per wheel in contact: force = drag x speed (N per m/s).
@export var drag: float = 0.0
## Colour used for gray-box geometry.
@export var debug_color: Color = Color.GRAY
```

`surfaces/grip_table.gd`:

```gdscript
class_name GripTable
extends Resource
## Car archetype x surface grip multipliers: the main tool for making the right
## car suit the right terrain. Missing entries mean 1.0 (no change).

## Keys are "archetype/surface", for example "rally/mud".
@export var multipliers: Dictionary = {}


func multiplier(archetype: StringName, surface_id: StringName) -> float:
	return float(multipliers.get("%s/%s" % [archetype, surface_id], 1.0))
```

`surfaces/surface_lookup.gd`:

```gdscript
class_name SurfaceLookup
extends RefCounted
## Finds out which SurfaceDef a collider is made of.
## Ground bodies carry a "surface" meta entry holding a SurfaceDef. Anything
## untagged counts as dirt, so no ground is ever surface-less.

const META_KEY := &"surface"
const FALLBACK_PATH := "res://surfaces/dirt.tres"

static var _fallback: SurfaceDef


static func surface_of(collider: Object) -> SurfaceDef:
	if collider != null and collider.has_meta(META_KEY):
		var value: Variant = collider.get_meta(META_KEY)
		if value is SurfaceDef:
			return value
	return fallback()


static func fallback() -> SurfaceDef:
	if _fallback == null:
		_fallback = load(FALLBACK_PATH)
	return _fallback
```

- [ ] **Step 4: Write the surface data files**

`surfaces/asphalt.tres`:

```ini
[gd_resource type="Resource" script_class="SurfaceDef" format=3]

[ext_resource type="Script" path="res://surfaces/surface_def.gd" id="1_surface"]

[resource]
script = ExtResource("1_surface")
id = &"asphalt"
display_name = "Asphalt"
grip = 1.0
rolling_resistance = 0.015
sink_depth = 0.0
drag = 0.0
debug_color = Color(0.25, 0.25, 0.27, 1)
```

`surfaces/dirt.tres`:

```ini
[gd_resource type="Resource" script_class="SurfaceDef" format=3]

[ext_resource type="Script" path="res://surfaces/surface_def.gd" id="1_surface"]

[resource]
script = ExtResource("1_surface")
id = &"dirt"
display_name = "Dirt"
grip = 0.8
rolling_resistance = 0.04
sink_depth = 0.01
drag = 0.0
debug_color = Color(0.55, 0.42, 0.28, 1)
```

`surfaces/mud.tres`:

```ini
[gd_resource type="Resource" script_class="SurfaceDef" format=3]

[ext_resource type="Script" path="res://surfaces/surface_def.gd" id="1_surface"]

[resource]
script = ExtResource("1_surface")
id = &"mud"
display_name = "Mud"
grip = 0.5
rolling_resistance = 0.1
sink_depth = 0.06
drag = 40.0
debug_color = Color(0.33, 0.24, 0.15, 1)
```

`surfaces/grip_table.tres`:

```ini
[gd_resource type="Resource" script_class="GripTable" format=3]

[ext_resource type="Script" path="res://surfaces/grip_table.gd" id="1_grip"]

[resource]
script = ExtResource("1_grip")
multipliers = {
"rally/asphalt": 1.0,
"rally/dirt": 1.05,
"rally/mud": 1.1
}
```

- [ ] **Step 5: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_surfaces.gd` 7 passing.

- [ ] **Step 6: Commit**

```bash
git add surfaces tests/unit/test_surfaces.gd
git commit -m "Add surface definitions, grip table and surface lookup"
```

---

### Task 3: Tire model

**Files:**
- Create: `car/tire_model.gd`
- Test: `tests/unit/test_tire_model.gd`

**Interfaces:**
- Produces (all static, on `TireModel`):
  - `grip_curve(normalized_slip: float, slide_grip: float) -> float`
  - `slip_ratio(tread_speed: float, ground_speed: float, min_reference_speed: float) -> float`
  - `slip_angle(forward_speed: float, sideways_speed: float, min_reference_speed: float) -> float`
  - `contact_force(ratio: float, angle: float, grip_force: float, peak_ratio: float, peak_angle: float, slide_grip: float) -> Vector2`, where x = along the heading (+ forward) and y = across it (+ right).
  - `max_longitudinal_force(slip_speed: float, wheel_radius: float, wheel_inertia: float, corner_mass: float, wheel_held: bool, delta: float) -> float`
  - `max_lateral_force(sideways_speed: float, corner_mass: float, delta: float) -> float`

- [ ] **Step 1: Write the failing test**

`tests/unit/test_tire_model.gd`:

```gdscript
extends GutTest

const SLIDE := 0.75


func test_grip_curve_is_zero_without_slip() -> void:
	assert_almost_eq(TireModel.grip_curve(0.0, SLIDE), 0.0, 0.0001)


func test_grip_curve_peaks_at_one() -> void:
	assert_almost_eq(TireModel.grip_curve(1.0, SLIDE), 1.0, 0.0001)


func test_grip_curve_rises_smoothly_before_peak() -> void:
	assert_almost_eq(TireModel.grip_curve(0.5, SLIDE), 0.75, 0.0001)


func test_grip_curve_fades_to_slide_grip() -> void:
	assert_almost_eq(TireModel.grip_curve(2.0, SLIDE), 0.875, 0.0001)
	assert_almost_eq(TireModel.grip_curve(3.0, SLIDE), SLIDE, 0.0001)
	assert_almost_eq(TireModel.grip_curve(10.0, SLIDE), SLIDE, 0.0001)


func test_grip_curve_ignores_sign() -> void:
	assert_almost_eq(TireModel.grip_curve(-0.5, SLIDE), TireModel.grip_curve(0.5, SLIDE), 0.0001)


func test_slip_ratio_uses_min_reference_when_stopped() -> void:
	# Tread moving at 1.5 m/s on a stopped car: 1.5 / 3.0
	assert_almost_eq(TireModel.slip_ratio(1.5, 0.0, 3.0), 0.5, 0.0001)


func test_slip_ratio_at_speed() -> void:
	assert_almost_eq(TireModel.slip_ratio(22.0, 20.0, 3.0), 0.1, 0.0001)
	assert_almost_eq(TireModel.slip_ratio(0.0, 20.0, 3.0), -1.0, 0.0001)


func test_slip_angle_is_zero_when_rolling_straight() -> void:
	assert_almost_eq(TireModel.slip_angle(20.0, 0.0, 3.0), 0.0, 0.0001)


func test_slip_angle_sign_follows_sideways_speed() -> void:
	assert_gt(TireModel.slip_angle(20.0, 2.0, 3.0), 0.0)
	assert_lt(TireModel.slip_angle(20.0, -2.0, 3.0), 0.0)
	assert_almost_eq(TireModel.slip_angle(10.0, 10.0, 3.0), PI / 4.0, 0.0001)


func test_contact_force_is_zero_without_slip() -> void:
	var force := TireModel.contact_force(0.0, 0.0, 3000.0, 0.1, 0.14, SLIDE)
	assert_almost_eq(force.length(), 0.0, 0.0001)


func test_spinning_tire_pushes_forward_with_full_grip_at_peak() -> void:
	var force := TireModel.contact_force(0.1, 0.0, 3000.0, 0.1, 0.14, SLIDE)
	assert_almost_eq(force.x, 3000.0, 0.01)
	assert_almost_eq(force.y, 0.0, 0.01)


func test_braking_tire_pushes_backward() -> void:
	var force := TireModel.contact_force(-0.05, 0.0, 3000.0, 0.1, 0.14, SLIDE)
	assert_lt(force.x, 0.0)


func test_tire_sliding_right_pushes_left() -> void:
	var force := TireModel.contact_force(0.0, 0.14, 3000.0, 0.1, 0.14, SLIDE)
	assert_almost_eq(force.y, -3000.0, 0.01)


func test_combined_slip_shares_one_grip_budget() -> void:
	# At peak slip in both directions the combined slip is sqrt(2) x the peak,
	# so the total force is below the grip force (the friction circle).
	var force := TireModel.contact_force(0.1, 0.14, 3000.0, 0.1, 0.14, SLIDE)
	var expected := TireModel.grip_curve(sqrt(2.0), SLIDE) * 3000.0
	assert_almost_eq(force.length(), expected, 0.01)
	assert_lt(force.length(), 3000.0)


func test_max_longitudinal_force_for_free_wheel_is_limited_by_wheel_inertia() -> void:
	# compliance = 1/300 + 0.3^2 / 1.0 = 0.09333 -> 1.0 / (0.09333 * 0.01) = 1071.43
	var force := TireModel.max_longitudinal_force(1.0, 0.3, 1.0, 300.0, false, 0.01)
	assert_almost_eq(force, 1071.43, 0.1)


func test_max_longitudinal_force_for_held_wheel_is_limited_by_car_mass() -> void:
	var force := TireModel.max_longitudinal_force(1.0, 0.3, 1.0, 300.0, true, 0.01)
	assert_almost_eq(force, 30000.0, 0.1)


func test_max_lateral_force_cancels_sideways_speed_in_one_tick() -> void:
	assert_almost_eq(TireModel.max_lateral_force(-0.5, 300.0, 0.01), 15000.0, 0.1)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR: Parse Error: Identifier "TireModel" not declared in the current scope.`

- [ ] **Step 3: Implement**

`car/tire_model.gd`:

```gdscript
class_name TireModel
extends RefCounted
## Pure tire math: no nodes and no state, so every function is easy to test.
##
## A tire only grips when it slips a little. Slip is measured two ways:
##   slip ratio - how much faster (or slower) the tread moves than the ground,
##                along the wheel's heading. + = spinning faster (accelerating).
##   slip angle - the angle between where the wheel points and where it moves.
##                + = the wheel is sliding to its right.
## Each is divided by its "peak" value (the slip where grip is highest), then the
## two are combined into one vector and fed through a single grip curve. Doing it
## this way makes braking/accelerating and cornering share one grip budget (the
## "friction circle"), which is where weight transfer and catchable slides come from.


## Grip as a fraction of the maximum, for a normalised slip (1.0 = at the peak).
## Rises smoothly to 1.0 at the peak, then fades to slide_grip at 3x the peak and
## stays there. The sign of the slip is ignored.
static func grip_curve(normalized_slip: float, slide_grip: float) -> float:
	var s := absf(normalized_slip)
	if s <= 1.0:
		return s * (2.0 - s)
	var fade := clampf((s - 1.0) / 2.0, 0.0, 1.0)
	return lerpf(1.0, slide_grip, fade)


## Longitudinal slip ratio. The ground speed is floored at min_reference_speed so
## the ratio stays finite when the car is nearly stopped.
static func slip_ratio(tread_speed: float, ground_speed: float, min_reference_speed: float) -> float:
	var reference := maxf(absf(ground_speed), min_reference_speed)
	return (tread_speed - ground_speed) / reference


## Slip angle in radians, from the contact patch velocity split into the part
## along the wheel heading and the part across it (+ = moving to the right).
static func slip_angle(forward_speed: float, sideways_speed: float, min_reference_speed: float) -> float:
	return atan2(sideways_speed, maxf(absf(forward_speed), min_reference_speed))


## Tire force in the contact patch frame:
##   x = along the wheel heading (+ = forward), y = across it (+ = right).
## grip_force: the most force this tire can make right now (friction x load).
static func contact_force(ratio: float, angle: float, grip_force: float,
		peak_ratio: float, peak_angle: float, slide_grip: float) -> Vector2:
	var slip := Vector2(ratio / peak_ratio, angle / peak_angle)
	var amount := slip.length()
	if amount < 0.000001:
		return Vector2.ZERO
	var direction := slip / amount
	var force := grip_curve(amount, slide_grip) * grip_force
	# Longitudinal force pushes along the slip; lateral force pushes against it.
	return Vector2(direction.x * force, -direction.y * force)


## Largest longitudinal force that will not overshoot within one tick, i.e. will
## not flip the sign of the slip speed (tread speed - ground speed). Without this
## limit the explicit integration jitters violently at low speed.
## wheel_held: true when the brake holds the wheel still, so the tire force can
## only change the car's speed, not the wheel's.
static func max_longitudinal_force(slip_speed: float, wheel_radius: float, wheel_inertia: float,
		corner_mass: float, wheel_held: bool, delta: float) -> float:
	var compliance := 1.0 / corner_mass
	if not wheel_held:
		compliance += wheel_radius * wheel_radius / wheel_inertia
	return absf(slip_speed) / (compliance * delta)


## Largest lateral force that will not overshoot within one tick: the force that
## would exactly cancel this corner's sideways speed.
static func max_lateral_force(sideways_speed: float, corner_mass: float, delta: float) -> float:
	return absf(sideways_speed) * corner_mass / delta
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_tire_model.gd` 17 passing.

- [ ] **Step 5: Commit**

```bash
git add car/tire_model.gd car/tire_model.gd.uid tests/unit/test_tire_model.gd
git commit -m "Add pure tire model with friction circle and anti-overshoot limits"
```

---

### Task 4: Suspension model

**Files:**
- Create: `car/suspension_model.gd`
- Test: `tests/unit/test_suspension_model.gd`

**Interfaces:**
- Produces (all static, on `SuspensionModel`):
  - `spring_damper_force(compression: float, compression_speed: float, stiffness: float, compress_damping: float, rebound_damping: float) -> float` (never negative)
  - `bump_stop_force(compression: float, travel: float, stiffness: float) -> float` (active over the last 15% of travel)
  - `anti_roll_force(left_compression: float, right_compression: float, stiffness: float) -> float` (the left wheel's share; the right wheel gets the negative)

- [ ] **Step 1: Write the failing test**

`tests/unit/test_suspension_model.gd`:

```gdscript
extends GutTest


func test_no_force_at_full_extension() -> void:
	assert_almost_eq(SuspensionModel.spring_damper_force(0.0, 0.0, 30000.0, 2000.0, 3000.0), 0.0, 0.001)


func test_spring_force_is_stiffness_times_compression() -> void:
	assert_almost_eq(SuspensionModel.spring_damper_force(0.1, 0.0, 30000.0, 2000.0, 3000.0), 3000.0, 0.001)


func test_compress_damping_used_while_compressing() -> void:
	# 0.1 * 30000 + 0.5 * 2000
	assert_almost_eq(SuspensionModel.spring_damper_force(0.1, 0.5, 30000.0, 2000.0, 3000.0), 4000.0, 0.001)


func test_rebound_damping_used_while_extending() -> void:
	# 0.1 * 30000 - 0.5 * 3000
	assert_almost_eq(SuspensionModel.spring_damper_force(0.1, -0.5, 30000.0, 2000.0, 3000.0), 1500.0, 0.001)


func test_force_never_pulls_the_car_down() -> void:
	assert_almost_eq(SuspensionModel.spring_damper_force(0.01, -2.0, 30000.0, 2000.0, 3000.0), 0.0, 0.001)


func test_bump_stop_inactive_before_last_15_percent() -> void:
	assert_almost_eq(SuspensionModel.bump_stop_force(0.25, 0.35, 200000.0), 0.0, 0.001)


func test_bump_stop_pushes_hard_near_full_compression() -> void:
	# Starts at 0.2975: (0.35 - 0.2975) * 200000 = 10500
	assert_almost_eq(SuspensionModel.bump_stop_force(0.35, 0.35, 200000.0), 10500.0, 0.01)


func test_anti_roll_pushes_the_compressed_side_up() -> void:
	assert_almost_eq(SuspensionModel.anti_roll_force(0.2, 0.1, 8000.0), 800.0, 0.001)
	assert_almost_eq(SuspensionModel.anti_roll_force(0.1, 0.2, 8000.0), -800.0, 0.001)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `SuspensionModel` is not declared.

- [ ] **Step 3: Implement**

`car/suspension_model.gd`:

```gdscript
class_name SuspensionModel
extends RefCounted
## Pure suspension math. "Compression" is how far the spring is squeezed from
## fully extended, in metres (0 = wheel hanging at full droop).


## Spring + damper force pushing the car up. Never negative: a suspension can push
## the car away from the ground but can't pull it down onto it.
## compression_speed: m/s, + while compressing.
static func spring_damper_force(compression: float, compression_speed: float, stiffness: float,
		compress_damping: float, rebound_damping: float) -> float:
	var damping := compress_damping if compression_speed > 0.0 else rebound_damping
	return maxf(0.0, compression * stiffness + compression_speed * damping)


## A very stiff extra spring over the last 15% of travel, so a hard landing can't
## drive the wheel up through the body.
static func bump_stop_force(compression: float, travel: float, stiffness: float) -> float:
	var start := travel * 0.85
	return maxf(0.0, compression - start) * stiffness


## Anti-roll bar: pushes the more compressed side up and the other side down by the
## same amount. Returns the force for the LEFT wheel; the right wheel gets the negative.
static func anti_roll_force(left_compression: float, right_compression: float, stiffness: float) -> float:
	return (left_compression - right_compression) * stiffness
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_suspension_model.gd` 8 passing.

- [ ] **Step 5: Commit**

```bash
git add car/suspension_model.gd car/suspension_model.gd.uid tests/unit/test_suspension_model.gd
git commit -m "Add pure suspension model"
```

---

### Task 5: Car stats resource and the Rally Car

**Files:**
- Create: `car/car_stats.gd`, `car/rally_car.tres`
- Test: `tests/unit/test_car_stats.gd`

**Interfaces:**
- Produces: `CarStats` (Resource), with enum `CarStats.DriveType { FWD, RWD, AWD }`, every exported field shown below, and `wheel_mount_position(is_front: bool, is_left: bool) -> Vector3`. Data: `res://car/rally_car.tres`, the AWD Rally Car inspired by the Impreza WRX STI.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_car_stats.gd`:

```gdscript
extends GutTest

const RALLY := preload("res://car/rally_car.tres")


func test_rally_car_file_loads_as_awd_rally_archetype() -> void:
	assert_eq(RALLY.archetype, &"rally")
	assert_eq(RALLY.drive_type, CarStats.DriveType.AWD)


func test_torque_curve_arrays_match() -> void:
	assert_eq(RALLY.torque_curve_rpm.size(), RALLY.torque_curve_nm.size())
	for i in range(1, RALLY.torque_curve_rpm.size()):
		assert_gt(RALLY.torque_curve_rpm[i], RALLY.torque_curve_rpm[i - 1], "rpm points ascend")


func test_wheel_mount_positions() -> void:
	var stats := CarStats.new()
	# Front-left: left is -X, front is -Z.
	assert_eq(stats.wheel_mount_position(true, true), Vector3(-0.76, 0.1, -1.26))
	assert_eq(stats.wheel_mount_position(false, false), Vector3(0.76, 0.1, 1.26))


func test_static_sag_leaves_suspension_travel_both_ways() -> void:
	# At rest each spring carries a quarter of the weight. It should sit roughly in
	# the middle third of its travel, so it can both compress and extend.
	var sag := RALLY.mass * 9.8 / 4.0 / RALLY.spring_stiffness
	assert_between(sag / RALLY.suspension_length, 0.25, 0.5)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` about `res://car/rally_car.tres` or `CarStats`.

- [ ] **Step 3: Implement the resource script**

`car/car_stats.gd`:

```gdscript
class_name CarStats
extends Resource
## Every tunable number for one car. Tune in the Inspector - no code changes.
## Units: metres, kilograms, seconds, newtons, newton-metres; degrees where named.
## Axes: forward is -Z, right is +X, up is +Y.

enum DriveType { FWD, RWD, AWD }

@export_group("Identity")
@export var display_name: String = "Rally Car"
## Key into the GripTable ("rally", "truck", ...).
@export var archetype: StringName = &"rally"

@export_group("Body")
@export var mass: float = 1300.0
## Centre of mass relative to the body origin. Lower = harder to roll over.
@export var center_of_mass: Vector3 = Vector3(0.0, -0.15, 0.0)
## Size of the gray-box body (collision box and mesh).
@export var body_size: Vector3 = Vector3(1.6, 0.5, 4.2)
## Aerodynamic drag: force = aero_drag x speed^2.
@export var aero_drag: float = 0.42

@export_group("Wheels")
@export var wheel_radius: float = 0.33
@export var wheel_width: float = 0.24
## Distance between left and right wheel centres.
@export var track_width: float = 1.52
## Distance between front and rear axles.
@export var wheelbase: float = 2.52
## Height of the suspension top mounts relative to the body origin.
@export var wheel_mount_height: float = 0.1
## Rotational inertia of one wheel (tire, rim, brake, axle), kg*m^2.
@export var wheel_inertia: float = 1.2

@export_group("Suspension")
## Wheel travel from fully extended to fully compressed.
@export var suspension_length: float = 0.35
@export var spring_stiffness: float = 26500.0
@export var compress_damping: float = 2000.0
@export var rebound_damping: float = 3000.0
@export var bump_stop_stiffness: float = 200000.0
@export var anti_roll_front: float = 8000.0
@export var anti_roll_rear: float = 5000.0

@export_group("Tires")
## The car's own tire friction, multiplied with the surface grip.
@export var tire_grip: float = 1.1
## Slip ratio where forward/backward grip peaks.
@export var peak_slip_ratio: float = 0.12
## Slip angle (degrees) where sideways grip peaks.
@export var peak_slip_angle_deg: float = 8.0
## Grip left when fully sliding, as a fraction of peak grip.
@export_range(0.0, 1.0) var slide_grip: float = 0.75
## Slip maths treats speeds below this as this (m/s), for low-speed stability.
@export var low_speed_reference: float = 3.0

@export_group("Engine")
## Torque curve: rpm points and the torque (Nm) at each. Same length, ascending rpm.
@export var torque_curve_rpm: PackedFloat32Array = PackedFloat32Array([1000, 2500, 4000, 5500, 6500, 7200])
@export var torque_curve_nm: PackedFloat32Array = PackedFloat32Array([220, 320, 390, 380, 340, 280])
@export var idle_rpm: float = 1000.0
@export var redline_rpm: float = 7200.0
## Simulated clutch slip: pulling away, the engine may rev up to this rpm.
@export var launch_rpm: float = 3500.0
## Engine braking torque (Nm at the engine) when off the throttle.
@export var engine_braking_nm: float = 50.0

@export_group("Gearbox")
@export var gear_ratios: PackedFloat32Array = PackedFloat32Array([3.3, 2.1, 1.5, 1.15, 0.92, 0.76])
@export var reverse_ratio: float = 3.3
@export var final_drive: float = 4.4
@export var upshift_rpm: float = 6800.0
@export var downshift_rpm: float = 3000.0
## Seconds with no drive torque during a gear change.
@export var shift_time: float = 0.18
@export_range(0.0, 1.0) var drivetrain_efficiency: float = 0.85

@export_group("Drivetrain")
@export var drive_type: DriveType = DriveType.AWD
## AWD only: share of drive torque sent to the front axle.
@export_range(0.0, 1.0) var front_torque_split: float = 0.45

@export_group("Brakes")
## Total brake torque for the whole car at full pedal (Nm).
@export var brake_torque: float = 10000.0
## Share of brake torque on the front axle.
@export_range(0.0, 1.0) var brake_front_bias: float = 0.65
## Simple ABS: eases the brake when a wheel starts to lock.
@export var abs_enabled: bool = true
## Below this speed (m/s) with no pedal pressed, the brakes hold the car.
@export var auto_hold_speed: float = 0.5

@export_group("Assists")
## Traction control: trims engine torque while the driven wheels spin. Touch
## pedals are on/off, so without it full throttle usually means wheelspin.
@export var traction_control: bool = true
## Slip ratio the traction control allows before it starts trimming torque.
@export var traction_slip_target: float = 0.2

@export_group("Steering")
@export var max_steer_deg: float = 32.0
## Steering lock at and above steer_limit_speed.
@export var min_steer_deg: float = 8.0
@export var steer_limit_speed: float = 40.0
## How fast the front wheels turn, degrees per second.
@export var steer_rate_deg: float = 180.0

@export_group("Air control")
## Seconds all four wheels must be off the ground before air control activates.
@export var airborne_grace: float = 0.1
@export var air_pitch_torque: float = 3000.0
## Set to 0 to turn off steer-to-roll in the air.
@export var air_roll_torque: float = 1500.0


## Suspension top-mount position of a wheel, relative to the body origin.
func wheel_mount_position(is_front: bool, is_left: bool) -> Vector3:
	var x := -track_width * 0.5 if is_left else track_width * 0.5
	var z := -wheelbase * 0.5 if is_front else wheelbase * 0.5
	return Vector3(x, wheel_mount_height, z)
```

- [ ] **Step 4: Write the Rally Car data file**

`car/rally_car.tres`:

```ini
[gd_resource type="Resource" script_class="CarStats" format=3]

[ext_resource type="Script" path="res://car/car_stats.gd" id="1_stats"]

[resource]
script = ExtResource("1_stats")
display_name = "Rally Car"
archetype = &"rally"
mass = 1300.0
center_of_mass = Vector3(0, -0.15, 0)
body_size = Vector3(1.6, 0.5, 4.2)
aero_drag = 0.42
wheel_radius = 0.33
wheel_width = 0.24
track_width = 1.52
wheelbase = 2.52
wheel_mount_height = 0.1
wheel_inertia = 1.2
suspension_length = 0.35
spring_stiffness = 26500.0
compress_damping = 2000.0
rebound_damping = 3000.0
bump_stop_stiffness = 200000.0
anti_roll_front = 8000.0
anti_roll_rear = 5000.0
tire_grip = 1.1
peak_slip_ratio = 0.12
peak_slip_angle_deg = 8.0
slide_grip = 0.75
low_speed_reference = 3.0
torque_curve_rpm = PackedFloat32Array(1000, 2500, 4000, 5500, 6500, 7200)
torque_curve_nm = PackedFloat32Array(220, 320, 390, 380, 340, 280)
idle_rpm = 1000.0
redline_rpm = 7200.0
launch_rpm = 3500.0
engine_braking_nm = 50.0
gear_ratios = PackedFloat32Array(3.3, 2.1, 1.5, 1.15, 0.92, 0.76)
reverse_ratio = 3.3
final_drive = 4.4
upshift_rpm = 6800.0
downshift_rpm = 3000.0
shift_time = 0.18
drivetrain_efficiency = 0.85
drive_type = 2
front_torque_split = 0.45
brake_torque = 10000.0
brake_front_bias = 0.65
abs_enabled = true
auto_hold_speed = 0.5
traction_control = true
traction_slip_target = 0.2
max_steer_deg = 32.0
min_steer_deg = 8.0
steer_limit_speed = 40.0
steer_rate_deg = 180.0
airborne_grace = 0.1
air_pitch_torque = 3000.0
air_roll_torque = 1500.0
```

- [ ] **Step 5: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_car_stats.gd` 4 passing.

- [ ] **Step 6: Commit**

```bash
git add car/car_stats.gd car/car_stats.gd.uid car/rally_car.tres tests/unit/test_car_stats.gd
git commit -m "Add CarStats resource and Rally Car tuning file"
```

---

### Task 6: Drivetrain

**Files:**
- Create: `car/drivetrain.gd`
- Test: `tests/unit/test_drivetrain.gd`

**Interfaces:**
- Consumes: `CarStats` (Task 5).
- Produces: `Drivetrain` (RefCounted):
  - `Drivetrain.new(stats: CarStats)`
  - Fields: `gear: int` (−1 = reverse), `rpm: float`, `drive_torque: float`, `brake_input: float`
  - `update(delta: float, throttle: float, brake: float, driven_wheel_speed: float, forward_speed: float, driven_slip: float) -> void`
  - `reset()`, `is_shifting() -> bool`, `overall_ratio() -> float`
  - Static: `torque_at(engine_rpm, rpm_points, torque_points) -> float`, `traction_factor(driven_slip, target_slip, enabled) -> float`, `split_torque(total, drive_type, front_split) -> PackedFloat32Array`, `split_brake(total, front_bias) -> PackedFloat32Array` (both split functions are ordered `[FL, FR, RL, RR]`)
  - Constant: `RPM_PER_RAD_PER_SEC`

- [ ] **Step 1: Write the failing test**

`tests/unit/test_drivetrain.gd`:

```gdscript
extends GutTest

var stats: CarStats
var drivetrain: Drivetrain


func before_each() -> void:
	stats = CarStats.new()
	drivetrain = Drivetrain.new(stats)


## One tick with the wheels rolling (no slip) at the speed that turns the engine
## at engine_rpm in the current gear.
func _update_at_rpm(engine_rpm: float, throttle: float, brake: float, driven_slip := 0.0) -> void:
	var wheel_speed := engine_rpm / Drivetrain.RPM_PER_RAD_PER_SEC / absf(drivetrain.overall_ratio())
	drivetrain.update(0.01, throttle, brake, wheel_speed, wheel_speed * stats.wheel_radius, driven_slip)


func _assert_wheels(actual: PackedFloat32Array, expected: Array) -> void:
	assert_eq(actual.size(), expected.size())
	for i in expected.size():
		assert_almost_eq(actual[i], float(expected[i]), 0.01, "wheel %d" % i)


func test_torque_curve_hits_points_exactly() -> void:
	assert_almost_eq(Drivetrain.torque_at(4000.0, stats.torque_curve_rpm, stats.torque_curve_nm), 390.0, 0.01)


func test_torque_curve_interpolates_between_points() -> void:
	# Halfway between 2500 rpm (320 Nm) and 4000 rpm (390 Nm).
	assert_almost_eq(Drivetrain.torque_at(3250.0, stats.torque_curve_rpm, stats.torque_curve_nm), 355.0, 0.01)


func test_torque_curve_holds_flat_beyond_the_ends() -> void:
	assert_almost_eq(Drivetrain.torque_at(0.0, stats.torque_curve_rpm, stats.torque_curve_nm), 220.0, 0.01)
	assert_almost_eq(Drivetrain.torque_at(9000.0, stats.torque_curve_rpm, stats.torque_curve_nm), 280.0, 0.01)


func test_traction_factor() -> void:
	assert_almost_eq(Drivetrain.traction_factor(0.1, 0.2, true), 1.0, 0.0001, "below target: full torque")
	assert_almost_eq(Drivetrain.traction_factor(0.3, 0.2, true), 0.5, 0.0001, "halfway to 2x target")
	assert_almost_eq(Drivetrain.traction_factor(5.0, 0.2, true), 0.2, 0.0001, "never below 20%")
	assert_almost_eq(Drivetrain.traction_factor(5.0, 0.2, false), 1.0, 0.0001, "switched off")


func test_first_gear_ratio_includes_final_drive() -> void:
	assert_almost_eq(drivetrain.overall_ratio(), 3.3 * 4.4, 0.001)


func test_throttle_from_standstill_pulls_away_with_clutch_slip() -> void:
	drivetrain.update(0.01, 1.0, 0.0, 0.0, 0.0, 0.0)
	assert_eq(drivetrain.gear, 1)
	assert_almost_eq(drivetrain.rpm, stats.launch_rpm, 0.01)
	assert_gt(drivetrain.drive_torque, 0.0)
	assert_almost_eq(drivetrain.brake_input, 0.0, 0.0001)


func test_upshifts_above_upshift_rpm_and_cuts_torque_while_shifting() -> void:
	_update_at_rpm(7000.0, 1.0, 0.0)
	assert_eq(drivetrain.gear, 2)
	assert_true(drivetrain.is_shifting())
	assert_almost_eq(drivetrain.drive_torque, 0.0, 0.0001)


func test_torque_returns_after_the_shift() -> void:
	_update_at_rpm(7000.0, 1.0, 0.0)
	for i in 20:  # 0.2 s, longer than shift_time
		_update_at_rpm(5000.0, 1.0, 0.0)
	assert_eq(drivetrain.gear, 2)
	assert_false(drivetrain.is_shifting())
	assert_gt(drivetrain.drive_torque, 0.0)


func test_wheelspin_alone_does_not_upshift() -> void:
	# Wheels spinning at 7000 rpm-worth while the car barely moves.
	var spinning := 7000.0 / Drivetrain.RPM_PER_RAD_PER_SEC / absf(drivetrain.overall_ratio())
	drivetrain.update(0.01, 1.0, 0.0, spinning, 2.0, 3.0)
	assert_eq(drivetrain.gear, 1)


func test_downshifts_below_downshift_rpm() -> void:
	drivetrain.gear = 3
	_update_at_rpm(2000.0, 0.5, 0.0)
	assert_eq(drivetrain.gear, 2)


func test_traction_control_trims_torque_while_wheels_spin() -> void:
	_update_at_rpm(4000.0, 1.0, 0.0, 0.0)
	var gripping := drivetrain.drive_torque
	_update_at_rpm(4000.0, 1.0, 0.0, 0.3)
	assert_almost_eq(drivetrain.drive_torque, gripping * 0.5, 1.0)


func test_brake_at_standstill_selects_reverse_and_drives_backwards() -> void:
	drivetrain.update(0.01, 0.0, 1.0, 0.0, 0.0, 0.0)
	assert_eq(drivetrain.gear, -1)
	assert_lt(drivetrain.drive_torque, 0.0)
	assert_almost_eq(drivetrain.brake_input, 0.0, 0.0001)


func test_gas_brakes_while_reversing() -> void:
	drivetrain.update(0.01, 0.0, 1.0, 0.0, 0.0, 0.0)       # into reverse
	drivetrain.update(0.01, 1.0, 0.0, -10.0, -3.0, 0.0)    # gas while rolling back at 3 m/s
	assert_eq(drivetrain.gear, -1)
	assert_almost_eq(drivetrain.brake_input, 1.0, 0.0001)


func test_gas_near_standstill_returns_to_first_gear() -> void:
	drivetrain.update(0.01, 0.0, 1.0, 0.0, 0.0, 0.0)
	drivetrain.update(0.01, 1.0, 0.0, 0.0, -0.2, 0.0)
	assert_eq(drivetrain.gear, 1)


func test_brake_at_speed_does_not_select_reverse() -> void:
	_update_at_rpm(4000.0, 0.0, 1.0)
	assert_eq(drivetrain.gear, 1)
	assert_almost_eq(drivetrain.brake_input, 1.0, 0.0001)


func test_auto_hold_when_stopped_without_pedals() -> void:
	drivetrain.update(0.01, 0.0, 0.0, 0.0, 0.1, 0.0)
	assert_almost_eq(drivetrain.brake_input, 1.0, 0.0001)


func test_no_auto_hold_while_rolling() -> void:
	drivetrain.update(0.01, 0.0, 0.0, 0.0, 5.0, 0.0)
	assert_almost_eq(drivetrain.brake_input, 0.0, 0.0001)


func test_rev_limiter_cuts_torque_at_redline() -> void:
	drivetrain.gear = 6
	_update_at_rpm(7300.0, 1.0, 0.0)
	assert_almost_eq(drivetrain.drive_torque, 0.0, 0.0001)


func test_engine_braking_opposes_rolling_when_off_throttle() -> void:
	_update_at_rpm(4000.0, 0.0, 0.0)
	assert_lt(drivetrain.drive_torque, 0.0)


func test_split_torque_awd() -> void:
	_assert_wheels(Drivetrain.split_torque(1000.0, CarStats.DriveType.AWD, 0.4), [200, 200, 300, 300])


func test_split_torque_fwd_and_rwd() -> void:
	_assert_wheels(Drivetrain.split_torque(1000.0, CarStats.DriveType.FWD, 0.4), [500, 500, 0, 0])
	_assert_wheels(Drivetrain.split_torque(1000.0, CarStats.DriveType.RWD, 0.4), [0, 0, 500, 500])


func test_split_brake_uses_front_bias() -> void:
	_assert_wheels(Drivetrain.split_brake(1000.0, 0.65), [325, 325, 175, 175])
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `Drivetrain` is not declared.

- [ ] **Step 3: Implement**

Two design points are covered by tests:
- The gearbox shifts on **road speed** (`test_wheelspin_alone_does_not_upshift`). Shifting on wheel spin makes wheelspin cause 1↔2 shift loops.
- **Traction control** trims torque while the driven wheels spin.

`car/drivetrain.gd`:

```gdscript
class_name Drivetrain
extends RefCounted
## Engine, automatic gearbox, reverse logic, traction control and torque split.
## Knows nothing about nodes: each tick the car feeds it pedal inputs and wheel
## state, then reads back drive_torque, brake_input, gear and rpm.

const RPM_PER_RAD_PER_SEC := 60.0 / TAU
## Below this speed (m/s) the brake pedal selects reverse and gas selects drive.
const DIRECTION_CHANGE_SPEED := 1.0

var stats: CarStats
## -1 = reverse, 1..N = forward gears.
var gear: int = 1
var rpm: float = 0.0
## Total torque at the driven wheels this tick (Nm, + = forward).
var drive_torque: float = 0.0
## Brake demand 0..1 after reverse handling and auto-hold.
var brake_input: float = 0.0

var _shift_timer: float = 0.0


func _init(car_stats: CarStats) -> void:
	stats = car_stats
	reset()


func reset() -> void:
	gear = 1
	rpm = stats.idle_rpm
	drive_torque = 0.0
	brake_input = 0.0
	_shift_timer = 0.0


func is_shifting() -> bool:
	return _shift_timer > 0.0


## Engine torque (Nm) at an rpm: linear between curve points, flat beyond the ends.
static func torque_at(engine_rpm: float, rpm_points: PackedFloat32Array, torque_points: PackedFloat32Array) -> float:
	if engine_rpm <= rpm_points[0]:
		return torque_points[0]
	for i in range(1, rpm_points.size()):
		if engine_rpm <= rpm_points[i]:
			var t := inverse_lerp(rpm_points[i - 1], rpm_points[i], engine_rpm)
			return lerpf(torque_points[i - 1], torque_points[i], t)
	return torque_points[torque_points.size() - 1]


## Traction control: the share of engine torque to keep when the driven wheels
## slip by driven_slip. Full torque up to target_slip, then fading to a 20%
## floor at twice the target.
static func traction_factor(driven_slip: float, target_slip: float, enabled: bool) -> float:
	if not enabled or driven_slip <= target_slip:
		return 1.0
	return clampf(1.0 - (driven_slip - target_slip) / target_slip, 0.2, 1.0)


## Ratio from engine to wheels in the current gear, including the final drive.
## Negative in reverse.
func overall_ratio() -> float:
	if gear < 0:
		return -stats.reverse_ratio * stats.final_drive
	return stats.gear_ratios[gear - 1] * stats.final_drive


## Advance one tick.
## throttle, brake: raw pedals 0..1.
## driven_wheel_speed: average spin of the driven wheels (rad/s, + = forward).
## forward_speed: car speed along its heading (m/s, + = forward).
## driven_slip: largest slip ratio (absolute) among the driven wheels.
func update(delta: float, throttle: float, brake: float, driven_wheel_speed: float,
		forward_speed: float, driven_slip: float) -> void:
	_choose_direction(throttle, brake, forward_speed)
	# In reverse the pedals swap roles: brake drives backwards, gas brakes.
	var gas := throttle if gear > 0 else brake
	brake_input = brake if gear > 0 else throttle
	if throttle == 0.0 and brake == 0.0 and absf(forward_speed) < stats.auto_hold_speed:
		brake_input = 1.0

	var ratio := overall_ratio()
	var wheel_rpm := absf(driven_wheel_speed * ratio) * RPM_PER_RAD_PER_SEC
	# Simulated clutch slip: at low speed the engine can rev above what the wheels
	# allow, so the car pulls away with useful torque.
	var clutch_rpm := lerpf(stats.idle_rpm, stats.launch_rpm, gas)
	rpm = clampf(maxf(wheel_rpm, clutch_rpm), stats.idle_rpm, stats.redline_rpm)

	if gear > 0:
		# Shift on road speed, not wheel spin, so wheelspin can't make the box hunt.
		var road_rpm := absf(forward_speed) / stats.wheel_radius * absf(ratio) * RPM_PER_RAD_PER_SEC
		_auto_shift(road_rpm)
	if _shift_timer > 0.0:
		_shift_timer -= delta
		drive_torque = 0.0
		return

	var engine_torque := 0.0
	if gas > 0.0:
		if wheel_rpm < stats.redline_rpm:  # rev limiter
			engine_torque = gas * torque_at(rpm, stats.torque_curve_rpm, stats.torque_curve_nm) \
					* traction_factor(driven_slip, stats.traction_slip_target, stats.traction_control)
	else:
		# Engine braking resists the direction the wheels are turning.
		engine_torque = -stats.engine_braking_nm * (rpm / stats.redline_rpm) \
				* signf(driven_wheel_speed) * signf(ratio)
	drive_torque = engine_torque * ratio * stats.drivetrain_efficiency


## Splits total drive torque over the wheels, ordered [FL, FR, RL, RR].
## Each axle shares its torque equally left/right (a simple open differential).
static func split_torque(total: float, drive_type: CarStats.DriveType, front_split: float) -> PackedFloat32Array:
	var front := 0.0
	match drive_type:
		CarStats.DriveType.FWD:
			front = total
		CarStats.DriveType.RWD:
			front = 0.0
		CarStats.DriveType.AWD:
			front = total * front_split
	var rear := total - front
	return PackedFloat32Array([front * 0.5, front * 0.5, rear * 0.5, rear * 0.5])


## Splits total brake torque over the wheels, ordered [FL, FR, RL, RR].
static func split_brake(total: float, front_bias: float) -> PackedFloat32Array:
	var front := total * front_bias
	var rear := total - front
	return PackedFloat32Array([front * 0.5, front * 0.5, rear * 0.5, rear * 0.5])


func _choose_direction(throttle: float, brake: float, forward_speed: float) -> void:
	if absf(forward_speed) > DIRECTION_CHANGE_SPEED:
		return
	if gear > 0 and brake > 0.0 and throttle == 0.0:
		gear = -1
	elif gear < 0 and throttle > 0.0 and brake == 0.0:
		gear = 1


func _auto_shift(road_rpm: float) -> void:
	if _shift_timer > 0.0:
		return
	if road_rpm > stats.upshift_rpm and gear < stats.gear_ratios.size():
		gear += 1
		_shift_timer = stats.shift_time
	elif road_rpm < stats.downshift_rpm and gear > 1:
		gear -= 1
		_shift_timer = stats.shift_time
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_drivetrain.gd` 22 passing.

- [ ] **Step 5: Commit**

```bash
git add car/drivetrain.gd car/drivetrain.gd.uid tests/unit/test_drivetrain.gd
git commit -m "Add drivetrain: engine, auto gearbox, reverse, traction control"
```

---

### Task 7: Steering

**Files:**
- Create: `car/steering.gd`
- Test: `tests/unit/test_steering.gd`

**Interfaces:**
- Consumes: `CarStats`.
- Produces: `Steering` (RefCounted): `Steering.new(stats)`, `angle: float` (radians, + = right), `update(delta: float, steer_input: float, speed: float) -> float`, and static `max_angle_for_speed(speed: float, car_stats: CarStats) -> float`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_steering.gd`:

```gdscript
extends GutTest

var stats: CarStats
var steering: Steering


func before_each() -> void:
	stats = CarStats.new()
	steering = Steering.new(stats)


func test_full_lock_when_stopped() -> void:
	assert_almost_eq(rad_to_deg(Steering.max_angle_for_speed(0.0, stats)), 32.0, 0.001)


func test_lock_shrinks_with_speed() -> void:
	assert_almost_eq(rad_to_deg(Steering.max_angle_for_speed(20.0, stats)), 20.0, 0.001)
	assert_almost_eq(rad_to_deg(Steering.max_angle_for_speed(40.0, stats)), 8.0, 0.001)
	assert_almost_eq(rad_to_deg(Steering.max_angle_for_speed(80.0, stats)), 8.0, 0.001)


func test_wheels_turn_at_a_limited_rate() -> void:
	# 180 deg/s for 1/120 s = 1.5 degrees.
	steering.update(1.0 / 120.0, 1.0, 0.0)
	assert_almost_eq(rad_to_deg(steering.angle), 1.5, 0.001)


func test_reaches_full_lock_after_enough_time() -> void:
	for i in 120:
		steering.update(1.0 / 120.0, 1.0, 0.0)
	assert_almost_eq(rad_to_deg(steering.angle), 32.0, 0.001)


func test_left_input_turns_left() -> void:
	steering.update(1.0, -1.0, 0.0)
	assert_almost_eq(rad_to_deg(steering.angle), -32.0, 0.001)


func test_recentres_when_released() -> void:
	steering.update(1.0, 1.0, 0.0)
	steering.update(1.0, 0.0, 0.0)
	assert_almost_eq(steering.angle, 0.0, 0.0001)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `Steering` is not declared.

- [ ] **Step 3: Implement**

`car/steering.gd`:

```gdscript
class_name Steering
extends RefCounted
## Turns steering input into a front-wheel angle. The lock shrinks with speed and
## the wheels turn at a limited rate, so the car can't snap sideways.

var stats: CarStats
## Current front-wheel angle in radians. + = right.
var angle: float = 0.0


func _init(car_stats: CarStats) -> void:
	stats = car_stats


## Largest wheel angle (radians) allowed at a given speed (m/s).
static func max_angle_for_speed(speed: float, car_stats: CarStats) -> float:
	var t := clampf(absf(speed) / car_stats.steer_limit_speed, 0.0, 1.0)
	return deg_to_rad(lerpf(car_stats.max_steer_deg, car_stats.min_steer_deg, t))


## steer_input: -1 (full left) .. 1 (full right). Returns the new angle.
func update(delta: float, steer_input: float, speed: float) -> float:
	var target := clampf(steer_input, -1.0, 1.0) * max_angle_for_speed(speed, stats)
	angle = move_toward(angle, target, deg_to_rad(stats.steer_rate_deg) * delta)
	return angle
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_steering.gd` 6 passing.

- [ ] **Step 5: Commit**

```bash
git add car/steering.gd car/steering.gd.uid tests/unit/test_steering.gd
git commit -m "Add speed-sensitive, rate-limited steering"
```

---

### Task 8: Air control

**Files:**
- Create: `car/air_control.gd`
- Test: `tests/unit/test_air_control.gd`

**Interfaces:**
- Consumes: `CarStats` (`airborne_grace`, `air_pitch_torque`, `air_roll_torque`).
- Produces: `AirControl` (RefCounted): `AirControl.new(stats)`, `airborne_time: float`, `is_active: bool`, `update(delta: float, wheels_in_contact: int)`, `local_torque(throttle: float, brake: float, steer: float) -> Vector3` (x = pitch, + nose up; z = roll, + left side down), `reset()`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_air_control.gd`:

```gdscript
extends GutTest

var stats: CarStats
var air: AirControl


func before_each() -> void:
	stats = CarStats.new()
	air = AirControl.new(stats)


func test_inactive_while_any_wheel_touches() -> void:
	air.update(0.5, 1)
	assert_false(air.is_active)


func test_activates_only_after_the_grace_period() -> void:
	air.update(0.05, 0)
	assert_false(air.is_active, "0.05 s airborne is still a bump")
	air.update(0.06, 0)
	assert_true(air.is_active, "0.11 s airborne is a real jump")


func test_one_wheel_touching_turns_it_off_immediately() -> void:
	air.update(0.2, 0)
	air.update(0.01, 1)
	assert_false(air.is_active)
	assert_almost_eq(air.airborne_time, 0.0, 0.0001)


func test_no_torque_while_inactive() -> void:
	assert_eq(air.local_torque(1.0, 0.0, 1.0), Vector3.ZERO)


func test_gas_pitches_nose_up_and_brake_pitches_it_down() -> void:
	air.update(0.2, 0)
	assert_gt(air.local_torque(1.0, 0.0, 0.0).x, 0.0)
	assert_lt(air.local_torque(0.0, 1.0, 0.0).x, 0.0)


func test_steering_right_rolls_right() -> void:
	air.update(0.2, 0)
	# Rolling right = right side down = negative rotation about +Z.
	assert_lt(air.local_torque(0.0, 0.0, 1.0).z, 0.0)


func test_reset_clears_state() -> void:
	air.update(0.2, 0)
	air.reset()
	assert_false(air.is_active)
	assert_almost_eq(air.airborne_time, 0.0, 0.0001)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `AirControl` is not declared.

- [ ] **Step 3: Implement**

`car/air_control.gd`:

```gdscript
class_name AirControl
extends RefCounted
## Lets the player adjust the car's attitude, but only when it is fully airborne:
## all four wheels off the ground for at least airborne_grace seconds (so small
## bumps don't count). Gas pitches the nose up, brake pitches it down, and
## steering rolls the car (GTA-style).

var stats: CarStats
var airborne_time: float = 0.0
var is_active: bool = false


func _init(car_stats: CarStats) -> void:
	stats = car_stats


func reset() -> void:
	airborne_time = 0.0
	is_active = false


## wheels_in_contact: how many wheels touched the ground this tick.
func update(delta: float, wheels_in_contact: int) -> void:
	if wheels_in_contact > 0:
		airborne_time = 0.0
	else:
		airborne_time += delta
	is_active = airborne_time >= stats.airborne_grace


## Torque in the car's local frame: x = pitch (+ = nose up), z = roll
## (+ = left side down). Zero unless air control is active.
func local_torque(throttle: float, brake: float, steer: float) -> Vector3:
	if not is_active:
		return Vector3.ZERO
	var pitch := (throttle - brake) * stats.air_pitch_torque
	var roll := -steer * stats.air_roll_torque
	return Vector3(pitch, 0.0, roll)
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_air_control.gd` 7 passing.

- [ ] **Step 5: Commit**

```bash
git add car/air_control.gd car/air_control.gd.uid tests/unit/test_air_control.gd
git commit -m "Add airborne-only air control with grace period"
```

---

### Task 9: Input actions and CarInput

**Files:**
- Create: `input/input_actions.gd`, `input/car_input.gd`
- Test: `tests/unit/test_car_input.gd`

**Interfaces:**
- Produces:
  - `InputActions` constants: `THROTTLE`, `BRAKE`, `STEER_LEFT`, `STEER_RIGHT`, `RESET_CAR`, `TOGGLE_TELEMETRY`, `TOGGLE_RECORDING`, plus `static register()` (idempotent).
  - `CarInput` (Node):
    - Signal `reset_requested`.
    - Fields read by the car: `steer`, `throttle`, `brake`.
    - Fields written by the touch controls or tests: `virtual_steer`, `virtual_throttle`, `virtual_brake`.
    - Methods: `refresh()` (the car calls it every tick) and `request_reset()`.

- [ ] **Step 1: Write the failing test**

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


func test_request_reset_emits_signal() -> void:
	watch_signals(input)
	input.request_reset()
	assert_signal_emitted(input, "reset_requested")
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `InputActions`/`CarInput` are not declared.

- [ ] **Step 3: Implement**

`input/input_actions.gd`:

```gdscript
class_name InputActions
extends RefCounted
## The game's input actions, registered in code so project.godot stays readable.
## Desktop: WASD / arrow keys, R reset, F1 telemetry, F2 record.
## Gamepad: triggers for gas/brake, left stick to steer, Y reset, Back telemetry.

const THROTTLE := &"throttle"
const BRAKE := &"brake"
const STEER_LEFT := &"steer_left"
const STEER_RIGHT := &"steer_right"
const RESET_CAR := &"reset_car"
const TOGGLE_TELEMETRY := &"toggle_telemetry"
const TOGGLE_RECORDING := &"toggle_recording"

const DEADZONE := 0.15


## Adds any missing actions. Safe to call more than once.
static func register() -> void:
	_add(THROTTLE, [_key(KEY_W), _key(KEY_UP), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add(BRAKE, [_key(KEY_S), _key(KEY_DOWN), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add(STEER_LEFT, [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add(STEER_RIGHT, [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add(RESET_CAR, [_key(KEY_R), _joy_button(JOY_BUTTON_Y)])
	_add(TOGGLE_TELEMETRY, [_key(KEY_F1), _joy_button(JOY_BUTTON_BACK)])
	_add(TOGGLE_RECORDING, [_key(KEY_F2)])


static func _add(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, DEADZONE)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _joy_axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event
```

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
	var device_steer := Input.get_axis(InputActions.STEER_LEFT, InputActions.STEER_RIGHT)
	steer = clampf(device_steer + virtual_steer, -1.0, 1.0)
	throttle = maxf(Input.get_action_strength(InputActions.THROTTLE), virtual_throttle)
	brake = maxf(Input.get_action_strength(InputActions.BRAKE), virtual_brake)


func request_reset() -> void:
	reset_requested.emit()
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_car_input.gd` 7 passing.

- [ ] **Step 5: Commit**

```bash
git add input tests/unit/test_car_input.gd
git commit -m "Add input actions and CarInput"
```

---

### Task 10: Wheel

**Files:**
- Create: `car/wheel.gd`
- Test: `tests/unit/test_wheel_contact.gd`

**Interfaces:**
- Consumes: `CarStats`, `GripTable`, `SurfaceDef`, `SurfaceLookup`, `TireModel`, `SuspensionModel`.
- Produces: `Wheel` (Node3D):
  - Exports: `is_front`, `is_left`.
  - Methods:
    - `setup(car_stats: CarStats, table: GripTable, car_body: CollisionObject3D)` places the wheel at its mount.
    - `update_contact(delta: float)`
    - `compute_force(delta: float, anti_roll: float, body: RigidBody3D) -> Vector3` (global force for `contact_point`)
    - `update_visual(delta: float)`
    - `reset()`
  - State the car reads: `in_contact`, `contact_point`, `contact_normal`, `surface`, `compression`, `compression_speed`, `spin_speed`, `tire_load`, `slip_ratio`, `slip_angle`.
  - State the car writes: `steer_angle`, `drive_torque`, `brake_torque`.

`compute_force` needs a real car body, so the Task 11 scenario tests cover it. This task tests ground detection.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_wheel_contact.gd`:

```gdscript
extends GutTest
## Wheel ground detection against real collision shapes (no car body needed).

const ASPHALT := preload("res://surfaces/asphalt.tres")
const MUD := preload("res://surfaces/mud.tres")

var stats: CarStats


func before_each() -> void:
	stats = CarStats.new()


func _add_ground(surface: SurfaceDef) -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	shape.position.y = -0.5  # top face at y = 0
	ground.add_child(shape)
	if surface != null:
		ground.set_meta(SurfaceLookup.META_KEY, surface)
	add_child_autofree(ground)


## A wheel whose suspension mount sits at mount_height above the ground.
func _add_wheel(mount_height: float) -> Wheel:
	var holder := StaticBody3D.new()  # stands in for the car body
	holder.position.y = mount_height - stats.wheel_mount_height
	add_child_autofree(holder)
	var wheel := Wheel.new()
	holder.add_child(wheel)
	wheel.setup(stats, GripTable.new(), holder)
	return wheel


func test_detects_ground_and_measures_compression() -> void:
	_add_ground(ASPHALT)
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	# Sphere (r = 0.33) touches when its centre is 0.33 up: 0.17 m below the
	# mount, so the spring is squeezed 0.35 - 0.17 = 0.18 m.
	assert_true(wheel.in_contact)
	assert_almost_eq(wheel.compression, 0.18, 0.01)
	assert_eq(wheel.surface, ASPHALT)


func test_no_contact_when_the_ground_is_out_of_reach() -> void:
	_add_ground(ASPHALT)
	var wheel := _add_wheel(2.0)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	assert_false(wheel.in_contact)
	assert_almost_eq(wheel.compression, 0.0, 0.0001)


func test_untagged_ground_counts_as_dirt() -> void:
	_add_ground(null)
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	assert_eq(wheel.surface.id, &"dirt")


func test_mud_lets_the_wheel_sink() -> void:
	_add_ground(MUD)
	var wheel := _add_wheel(0.5)
	await wait_physics_frames(2)
	wheel.update_contact(1.0 / 120.0)
	# 0.18 m on hard ground, minus the 0.06 m the wheel sinks into mud.
	assert_almost_eq(wheel.compression, 0.12, 0.01)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `Wheel` is not declared.

- [ ] **Step 3: Implement**

`car/wheel.gd`:

```gdscript
class_name Wheel
extends Node3D
## One wheel. Sits at the suspension top mount. Each tick it finds the ground with
## a sphere cast, runs the suspension and tire maths, and returns the force the car
## should apply at the contact point. It also moves and spins its visual mesh.

@export var is_front: bool = false
@export var is_left: bool = false

var stats: CarStats
var grip_table: GripTable

# --- Contact, refreshed by update_contact() ---
var in_contact: bool = false
## Global position where the tire touches the ground.
var contact_point: Vector3 = Vector3.ZERO
## Global ground normal at the contact point.
var contact_normal: Vector3 = Vector3.UP
var surface: SurfaceDef = null
## Metres squeezed from full extension (0 = hanging at full droop).
var compression: float = 0.0
## m/s, + while compressing.
var compression_speed: float = 0.0

# --- Tire state ---
## Front-wheel angle in radians, + = right. Set by the car.
var steer_angle: float = 0.0
## Wheel spin in rad/s, + = rolling forward.
var spin_speed: float = 0.0
## Set by the car each tick (Nm).
var drive_torque: float = 0.0
var brake_torque: float = 0.0
## Vertical load this wheel carries (N).
var tire_load: float = 0.0
var slip_ratio: float = 0.0
var slip_angle: float = 0.0

var _cast: ShapeCast3D
var _steer_pivot: Node3D
var _spin_pivot: Node3D
var _spin_visual_angle: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


## Called once by the car in its _ready().
func setup(car_stats: CarStats, table: GripTable, car_body: CollisionObject3D) -> void:
	stats = car_stats
	grip_table = table
	position = stats.wheel_mount_position(is_front, is_left)
	_cast = ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = stats.wheel_radius
	_cast.shape = sphere
	_cast.target_position = Vector3(0.0, -stats.suspension_length, 0.0)
	_cast.enabled = false  # updated manually once per tick, in update_contact()
	_cast.add_exception(car_body)
	add_child(_cast)
	_build_visual()


func reset() -> void:
	spin_speed = 0.0
	compression = 0.0
	compression_speed = 0.0
	tire_load = 0.0
	slip_ratio = 0.0
	slip_angle = 0.0


## Step 1 of a tick: find the ground and measure the suspension.
func update_contact(delta: float) -> void:
	var previous_compression := compression
	_cast.force_shapecast_update()
	in_contact = _cast.is_colliding()
	if not in_contact:
		compression = 0.0
		compression_speed = 0.0
		surface = null
		return
	contact_point = _cast.get_collision_point(0)
	contact_normal = _cast.get_collision_normal(0)
	surface = SurfaceLookup.surface_of(_cast.get_collider(0))
	# How far the wheel centre travelled down from the mount before touching.
	# Soft surfaces let the wheel sink a little further.
	var hit_distance := _cast.get_closest_collision_safe_fraction() * stats.suspension_length
	var wheel_distance := minf(hit_distance + surface.sink_depth, stats.suspension_length)
	compression = stats.suspension_length - wheel_distance
	compression_speed = (compression - previous_compression) / delta


## Step 2 of a tick: returns the global force to apply at contact_point (zero in
## the air). anti_roll: extra suspension force from the anti-roll bar (N, + = up).
func compute_force(delta: float, anti_roll: float, body: RigidBody3D) -> Vector3:
	if not in_contact:
		tire_load = 0.0
		slip_ratio = 0.0
		slip_angle = 0.0
		_spin_freely(delta)
		return Vector3.ZERO

	var suspension := SuspensionModel.spring_damper_force(compression, compression_speed,
			stats.spring_stiffness, stats.compress_damping, stats.rebound_damping)
	suspension += SuspensionModel.bump_stop_force(compression, stats.suspension_length,
			stats.bump_stop_stiffness)
	tire_load = maxf(0.0, suspension + anti_roll)

	# The wheel's heading, flattened onto the ground plane.
	var car_up := body.global_basis.y
	var heading := (-body.global_basis.z).rotated(car_up, -steer_angle)
	var forward := (heading - contact_normal * heading.dot(contact_normal)).normalized()
	var right := forward.cross(contact_normal).normalized()

	# How the contact patch moves over the ground.
	var patch_velocity := body.linear_velocity \
			+ body.angular_velocity.cross(contact_point - body.global_position)
	var forward_speed := patch_velocity.dot(forward)
	var sideways_speed := patch_velocity.dot(right)
	var tread_speed := spin_speed * stats.wheel_radius

	slip_ratio = TireModel.slip_ratio(tread_speed, forward_speed, stats.low_speed_reference)
	slip_angle = TireModel.slip_angle(forward_speed, sideways_speed, stats.low_speed_reference)
	var friction := surface.grip * stats.tire_grip * grip_table.multiplier(stats.archetype, surface.id)
	var tire := TireModel.contact_force(slip_ratio, slip_angle, friction * tire_load,
			stats.peak_slip_ratio, deg_to_rad(stats.peak_slip_angle_deg), stats.slide_grip)

	# Never let a force overshoot within one tick: this is what stops low-speed jitter.
	var corner_mass := maxf(tire_load / _gravity, 1.0)
	var wheel_held := brake_torque > 0.0 and is_zero_approx(spin_speed)
	var long_limit := TireModel.max_longitudinal_force(tread_speed - forward_speed,
			stats.wheel_radius, stats.wheel_inertia, corner_mass, wheel_held, delta)
	var longitudinal := clampf(tire.x, -long_limit, long_limit)
	var lateral_limit := TireModel.max_lateral_force(sideways_speed, corner_mass, delta)
	var lateral := clampf(tire.y, -lateral_limit, lateral_limit)

	_update_spin(delta, longitudinal)

	# Rolling resistance and surface drag slow the car down but never reverse it.
	var resistance := surface.rolling_resistance * tire_load + surface.drag * absf(forward_speed)
	resistance = minf(resistance, absf(forward_speed) * corner_mass / delta)
	longitudinal -= signf(forward_speed) * resistance

	return car_up * tire_load + forward * longitudinal + right * lateral


## Step 3 of a tick: place and spin the visual wheel.
func update_visual(delta: float) -> void:
	var wheel_distance := stats.suspension_length - compression
	_steer_pivot.position = Vector3(0.0, -wheel_distance, 0.0)
	_steer_pivot.rotation.y = -steer_angle
	# Rolling forward (-Z) is a negative rotation about +X.
	_spin_visual_angle = wrapf(_spin_visual_angle - spin_speed * delta, -PI, PI)
	_spin_pivot.rotation.x = _spin_visual_angle


func _update_spin(delta: float, tire_force: float) -> void:
	# The road pushes back on the tread with the opposite of the tire force.
	spin_speed += (drive_torque - tire_force * stats.wheel_radius) / stats.wheel_inertia * delta
	_apply_brakes(delta)


func _spin_freely(delta: float) -> void:
	spin_speed += drive_torque / stats.wheel_inertia * delta
	_apply_brakes(delta)


func _apply_brakes(delta: float) -> void:
	var torque := brake_torque
	# Simple ABS: ease off when the wheel turns much slower than the ground.
	if stats.abs_enabled and in_contact and slip_ratio < -stats.peak_slip_ratio * 1.5:
		torque *= 0.3
	spin_speed = move_toward(spin_speed, 0.0, torque / stats.wheel_inertia * delta)


func _build_visual() -> void:
	_steer_pivot = Node3D.new()
	add_child(_steer_pivot)
	_spin_pivot = Node3D.new()
	_steer_pivot.add_child(_spin_pivot)

	var tire := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = stats.wheel_radius
	cylinder.bottom_radius = stats.wheel_radius
	cylinder.height = stats.wheel_width
	tire.mesh = cylinder
	tire.rotation_degrees.z = 90.0  # cylinder axis (Y) -> axle axis (X)
	tire.material_override = _flat_material(Color(0.12, 0.12, 0.12))
	_spin_pivot.add_child(tire)

	# A bar across the wheel face, so you can see it spin.
	var hub := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(stats.wheel_width + 0.02, stats.wheel_radius * 1.6, 0.08)
	hub.mesh = bar
	hub.material_override = _flat_material(Color(0.75, 0.75, 0.78))
	_spin_pivot.add_child(hub)


static func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_wheel_contact.gd` 4 passing.

- [ ] **Step 5: Commit**

```bash
git add car/wheel.gd car/wheel.gd.uid tests/unit/test_wheel_contact.gd
git commit -m "Add raycast wheel: contact, suspension and tire forces"
```

---

### Task 11: Car scene and scenario tests

**Files:**
- Create: `car/car.gd`, `car/car.tscn`, `tests/scenarios/scenario_helper.gd`, `tests/scenarios/feel_baseline.gd`, `tests/scenarios/test_car_scenarios.gd`, `tests/unit/telemetry_sample.gd`

**Interfaces:**
- Consumes: everything from Tasks 2–10.
- Produces:
  - `Car` (RigidBody3D, scene `res://car/car.tscn`):
    - Exports: `stats: CarStats`, `grip_table: GripTable`.
    - Fields: `input: CarInput`, `wheels: Array[Wheel]` (`[FL, FR, RL, RR]`), `steering`, `drivetrain`, `air_control`.
    - Methods: `forward_speed() -> float` (m/s), `reset_to(target: Transform3D)`, `get_telemetry() -> Dictionary` (keys exactly as in `TelemetrySample.make()`).
  - `ScenarioHelper.ticks(seconds) -> int`, `make_flat_ground(surface, center := Vector3.ZERO, size := 600.0) -> StaticBody3D`, `spawn_car(test: GutTest, at: Vector3) -> Car`, `is_upright(car) -> bool`.
  - `FeelBaseline` constants (wide ranges until the Task 20 sign-off).
  - `TelemetrySample.make() -> Dictionary`, the documented telemetry shape.

- [ ] **Step 1: Write the scenario helpers and the telemetry sample**

`tests/scenarios/scenario_helper.gd`:

```gdscript
class_name ScenarioHelper
extends RefCounted
## Builds minimal worlds for scenario tests, independent of the Test Ground layout
## (which will keep changing as we tune).

const CAR_SCENE := preload("res://car/car.tscn")


static func ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


## A flat square of one surface, top face at center.y.
static func make_flat_ground(surface: SurfaceDef, center := Vector3.ZERO, size := 600.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.set_meta(SurfaceLookup.META_KEY, surface)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0, size)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	return body


static func spawn_car(test: GutTest, at: Vector3) -> Car:
	var car: Car = CAR_SCENE.instantiate()
	car.position = at
	test.add_child_autofree(car)
	return car


static func is_upright(car: Car) -> bool:
	return car.global_basis.y.dot(Vector3.UP) > 0.8
```

`tests/scenarios/feel_baseline.gd`:

```gdscript
class_name FeelBaseline
extends RefCounted
## Acceptable ranges for the scenario tests. Deliberately wide until the first
## tune is approved on the phone; then they are narrowed around measured values
## so later changes can't silently break an approved feel.

const RIDE_HEIGHT_TOLERANCE := 0.02      # m, per wheel, vs. static sag
const MAX_PARKED_CREEP := 0.02           # m, over 3 s on flat asphalt
const ZERO_TO_HUNDRED_MIN := 3.5         # s
const ZERO_TO_HUNDRED_MAX := 10.0        # s
const BRAKING_FROM_HUNDRED_MIN := 25.0   # m
const BRAKING_FROM_HUNDRED_MAX := 60.0   # m
```

`tests/unit/telemetry_sample.gd`:

```gdscript
class_name TelemetrySample
extends RefCounted
## A realistic telemetry dictionary for tests: same shape as Car.get_telemetry().


static func make() -> Dictionary:
	var wheel := {
		"contact": true,
		"surface": &"mud",
		"load": 3200.0,
		"compression": 0.12,
		"slip_ratio": 0.05,
		"slip_angle_deg": -2.5,
		"spin": 30.0,
	}
	return {
		"speed_kmh": 42.5,
		"rpm": 4100.0,
		"gear": -1,
		"throttle": 0.0,
		"brake": 1.0,
		"steer": -0.25,
		"airborne": false,
		"position": Vector3(1.0, 2.0, 3.0),
		"rotation_deg": Vector3(0.0, 90.0, 0.0),
		"wheels": [wheel, wheel.duplicate(), wheel.duplicate(), wheel.duplicate()],
	}
```

- [ ] **Step 2: Write the failing scenario tests**

`tests/scenarios/test_car_scenarios.gd`:

```gdscript
extends GutTest
## Scripted-driver checks on flat ground. They catch accidental breakage of the
## car's behaviour; they do not judge feel. Ranges live in FeelBaseline.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const MUD := preload("res://surfaces/mud.tres")

var car: Car


func _spawn_on(surface: SurfaceDef) -> void:
	add_child_autofree(ScenarioHelper.make_flat_ground(surface))
	car = ScenarioHelper.spawn_car(self, Vector3(0.0, 1.0, 0.0))


func _run(seconds: float) -> void:
	await wait_physics_frames(ScenarioHelper.ticks(seconds))


## Full throttle until the car reaches target_kmh. Returns seconds taken, or -1.
func _accelerate_to(target_kmh: float, timeout: float) -> float:
	car.input.virtual_throttle = 1.0
	var ticks := 0
	while car.forward_speed() * 3.6 < target_kmh:
		await get_tree().physics_frame
		ticks += 1
		if ticks > ScenarioHelper.ticks(timeout):
			return -1.0
	return ticks / float(Engine.physics_ticks_per_second)


func test_settles_at_ride_height() -> void:
	_spawn_on(ASPHALT)
	await _run(3.0)
	var expected_sag := car.stats.mass * 9.8 / 4.0 / car.stats.spring_stiffness
	for wheel in car.wheels:
		assert_true(wheel.in_contact, "every wheel on the ground")
		assert_almost_eq(wheel.compression, expected_sag, FeelBaseline.RIDE_HEIGHT_TOLERANCE)
	assert_lt(car.linear_velocity.length(), 0.05)


func test_does_not_creep_when_parked() -> void:
	_spawn_on(ASPHALT)
	await _run(2.0)
	var start := car.global_position
	await _run(3.0)
	var creep := (car.global_position - start).length()
	gut.p("parked creep: %.4f m" % creep)
	assert_lt(creep, FeelBaseline.MAX_PARKED_CREEP)


func test_zero_to_hundred() -> void:
	_spawn_on(ASPHALT)
	await _run(1.0)
	var seconds := await _accelerate_to(100.0, 20.0)
	gut.p("0-100 km/h: %.2f s" % seconds)
	assert_between(seconds, FeelBaseline.ZERO_TO_HUNDRED_MIN, FeelBaseline.ZERO_TO_HUNDRED_MAX)
	assert_true(ScenarioHelper.is_upright(car))


func test_braking_distance_from_hundred() -> void:
	_spawn_on(ASPHALT)
	await _run(1.0)
	await _accelerate_to(100.0, 20.0)
	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 1.0
	var start := car.global_position
	var ticks := 0
	while car.forward_speed() > 0.5 and ticks < ScenarioHelper.ticks(15.0):
		await get_tree().physics_frame
		ticks += 1
	var distance := (car.global_position - start).length()
	gut.p("braking 100-0 km/h: %.1f m" % distance)
	assert_between(distance, FeelBaseline.BRAKING_FROM_HUNDRED_MIN, FeelBaseline.BRAKING_FROM_HUNDRED_MAX)
	assert_true(ScenarioHelper.is_upright(car))


func test_mud_slides_more_and_turns_wider_than_asphalt() -> void:
	# Two cars side by side, one on each surface, doing the same manoeuvre.
	add_child_autofree(ScenarioHelper.make_flat_ground(ASPHALT, Vector3.ZERO))
	add_child_autofree(ScenarioHelper.make_flat_ground(MUD, Vector3(1000.0, 0.0, 0.0)))
	var on_asphalt := ScenarioHelper.spawn_car(self, Vector3(0.0, 1.0, 0.0))
	var on_mud := ScenarioHelper.spawn_car(self, Vector3(1000.0, 1.0, 0.0))
	var cars: Array[Car] = [on_asphalt, on_mud]
	await _run(1.0)
	for each in cars:
		each.input.virtual_throttle = 1.0
	for i in ScenarioHelper.ticks(15.0):
		await get_tree().physics_frame
		for each in cars:
			if each.forward_speed() * 3.6 >= 50.0:
				each.input.virtual_throttle = 0.3
		if on_asphalt.forward_speed() * 3.6 >= 50.0 and on_mud.forward_speed() * 3.6 >= 50.0:
			break
	for each in cars:
		each.input.virtual_steer = 1.0
	# Low grip shows up as bigger tire slip angles and a lazier turn (the front
	# tires wash out), not necessarily as the body moving sideways.
	var tire_slip_deg := [0.0, 0.0]
	var yaw_rate_deg := [0.0, 0.0]
	var turn_ticks := ScenarioHelper.ticks(1.5)
	for i in turn_ticks:
		await get_tree().physics_frame
		for c in cars.size():
			for wheel in cars[c].wheels:
				tire_slip_deg[c] += absf(rad_to_deg(wheel.slip_angle)) / (4.0 * turn_ticks)
			yaw_rate_deg[c] += absf(rad_to_deg(cars[c].angular_velocity.y)) / turn_ticks
	gut.p("tire slip: asphalt %.1f deg, mud %.1f deg | yaw rate: asphalt %.1f deg/s, mud %.1f deg/s"
			% [tire_slip_deg[0], tire_slip_deg[1], yaw_rate_deg[0], yaw_rate_deg[1]])
	assert_gt(tire_slip_deg[1], tire_slip_deg[0], "tires slide more on mud")
	assert_lt(yaw_rate_deg[1], yaw_rate_deg[0], "the car turns less sharply on mud")


func test_air_control_pitches_nose_up_only_when_airborne() -> void:
	_spawn_on(ASPHALT)
	car.position.y = 30.0
	car.input.virtual_throttle = 1.0
	await wait_physics_frames(3)
	assert_false(car.air_control.is_active, "not active before the grace period")
	await _run(0.3)
	assert_true(car.air_control.is_active)
	var local_spin := car.global_basis.inverse() * car.angular_velocity
	assert_gt(local_spin.x, 0.0, "gas pitches the nose up")


func test_reset_puts_the_car_back_upright_and_still() -> void:
	_spawn_on(ASPHALT)
	await _run(1.0)
	await _accelerate_to(40.0, 10.0)
	car.input.virtual_throttle = 0.0
	var target := Transform3D(Basis(Vector3.UP, 0.5), Vector3(5.0, 1.0, 5.0))
	car.reset_to(target)
	assert_almost_eq(car.global_position.distance_to(target.origin), 0.0, 0.001)
	assert_almost_eq(car.linear_velocity.length(), 0.0, 0.001)
	assert_eq(car.drivetrain.gear, 1)
	await _run(1.0)
	assert_true(ScenarioHelper.is_upright(car))


func test_telemetry_has_the_documented_shape() -> void:
	_spawn_on(ASPHALT)
	await _run(0.5)
	var telemetry := car.get_telemetry()
	var expected := TelemetrySample.make()
	assert_eq_deep(telemetry.keys(), expected.keys())
	assert_eq(telemetry.wheels.size(), 4)
	assert_eq_deep(telemetry.wheels[0].keys(), expected.wheels[0].keys())
```

- [ ] **Step 3: Run them and watch them fail**

Run: `./run_tests.sh scenarios`
Expected: exit 1, a `SCRIPT ERROR` about `res://car/car.tscn` or `Car`.

- [ ] **Step 4: Implement the car script**

`car/car.gd`:

```gdscript
class_name Car
extends RigidBody3D
## The drivable car: one rigid body with four raycast wheels.
## Every physics tick: read input -> steering and drivetrain -> wheels -> forces.

@export var stats: CarStats
@export var grip_table: GripTable

@onready var input: CarInput = $CarInput
## Always ordered front-left, front-right, rear-left, rear-right.
@onready var wheels: Array[Wheel] = [$WheelFL, $WheelFR, $WheelRL, $WheelRR]

var steering: Steering
var drivetrain: Drivetrain
var air_control: AirControl


func _ready() -> void:
	_apply_stats()
	for wheel in wheels:
		wheel.setup(stats, grip_table, self)
	steering = Steering.new(stats)
	drivetrain = Drivetrain.new(stats)
	air_control = AirControl.new(stats)


func _physics_process(delta: float) -> void:
	input.refresh()
	var speed := forward_speed()

	var angle := steering.update(delta, input.steer, speed)
	wheels[0].steer_angle = angle
	wheels[1].steer_angle = angle

	drivetrain.update(delta, input.throttle, input.brake, _driven_wheel_speed(), speed, _driven_slip())
	var drive := Drivetrain.split_torque(drivetrain.drive_torque, stats.drive_type, stats.front_torque_split)
	var brakes := Drivetrain.split_brake(drivetrain.brake_input * stats.brake_torque, stats.brake_front_bias)

	var wheels_in_contact := 0
	for i in wheels.size():
		wheels[i].drive_torque = drive[i]
		wheels[i].brake_torque = brakes[i]
		wheels[i].update_contact(delta)
		if wheels[i].in_contact:
			wheels_in_contact += 1

	var front_bar := SuspensionModel.anti_roll_force(wheels[0].compression, wheels[1].compression, stats.anti_roll_front)
	var rear_bar := SuspensionModel.anti_roll_force(wheels[2].compression, wheels[3].compression, stats.anti_roll_rear)
	var anti_roll := [front_bar, -front_bar, rear_bar, -rear_bar]
	for i in wheels.size():
		var force := wheels[i].compute_force(delta, anti_roll[i], self)
		if wheels[i].in_contact:
			apply_force(force, wheels[i].contact_point - global_position)
		wheels[i].update_visual(delta)

	air_control.update(delta, wheels_in_contact)
	var air_torque := air_control.local_torque(input.throttle, input.brake, input.steer)
	apply_torque(global_basis * air_torque)

	apply_central_force(-linear_velocity * linear_velocity.length() * stats.aero_drag)


## Speed along the car's heading in m/s (+ = forward).
func forward_speed() -> float:
	return linear_velocity.dot(-global_basis.z)


## Teleports the car, upright and stopped, to a new transform.
func reset_to(target: Transform3D) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = target
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, target)
	for wheel in wheels:
		wheel.reset()
	steering.angle = 0.0
	drivetrain.reset()
	air_control.reset()


## Snapshot for the telemetry overlay and the run recorder.
func get_telemetry() -> Dictionary:
	var wheel_data: Array[Dictionary] = []
	for wheel in wheels:
		wheel_data.append({
			"contact": wheel.in_contact,
			"surface": wheel.surface.id if wheel.surface != null else &"air",
			"load": wheel.tire_load,
			"compression": wheel.compression,
			"slip_ratio": wheel.slip_ratio,
			"slip_angle_deg": rad_to_deg(wheel.slip_angle),
			"spin": wheel.spin_speed,
		})
	return {
		"speed_kmh": forward_speed() * 3.6,
		"rpm": drivetrain.rpm,
		"gear": drivetrain.gear,
		"throttle": input.throttle,
		"brake": input.brake,
		"steer": input.steer,
		"airborne": air_control.is_active,
		"position": global_position,
		"rotation_deg": global_rotation_degrees,
		"wheels": wheel_data,
	}


func _apply_stats() -> void:
	mass = stats.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = stats.center_of_mass

	var body_box := BoxShape3D.new()
	body_box.size = stats.body_size
	$BodyShape.shape = body_box

	var body_mesh := BoxMesh.new()
	body_mesh.size = stats.body_size
	$BodyMesh.mesh = body_mesh

	# Gray-box cabin, set back a little so the front of the car is obvious.
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(stats.body_size.x * 0.85, stats.body_size.y * 0.8, stats.body_size.z * 0.45)
	$CabinMesh.mesh = cabin_mesh
	$CabinMesh.position = Vector3(0.0, (stats.body_size.y + cabin_mesh.size.y) * 0.5, stats.body_size.z * 0.08)


func _is_driven(wheel_index: int) -> bool:
	match stats.drive_type:
		CarStats.DriveType.FWD:
			return wheel_index < 2
		CarStats.DriveType.RWD:
			return wheel_index >= 2
		_:
			return true


func _driven_wheel_speed() -> float:
	var total := 0.0
	var count := 0
	for i in wheels.size():
		if _is_driven(i):
			total += wheels[i].spin_speed
			count += 1
	return total / count


## Largest slip among the driven wheels last tick, for traction control.
func _driven_slip() -> float:
	var slip := 0.0
	for i in wheels.size():
		if _is_driven(i):
			slip = maxf(slip, absf(wheels[i].slip_ratio))
	return slip
```

- [ ] **Step 5: Create the car scene**

`car/car.tscn`:

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://car/car.gd" id="1_car"]
[ext_resource type="Script" path="res://car/wheel.gd" id="2_wheel"]
[ext_resource type="Script" path="res://input/car_input.gd" id="3_input"]
[ext_resource type="Resource" path="res://car/rally_car.tres" id="4_stats"]
[ext_resource type="Resource" path="res://surfaces/grip_table.tres" id="5_grip"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_body"]
albedo_color = Color(0.86, 0.32, 0.16, 1)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_cabin"]
albedo_color = Color(0.2, 0.24, 0.3, 1)

[node name="Car" type="RigidBody3D"]
can_sleep = false
script = ExtResource("1_car")
stats = ExtResource("4_stats")
grip_table = ExtResource("5_grip")

[node name="BodyShape" type="CollisionShape3D" parent="."]

[node name="BodyMesh" type="MeshInstance3D" parent="."]
material_override = SubResource("StandardMaterial3D_body")

[node name="CabinMesh" type="MeshInstance3D" parent="."]
material_override = SubResource("StandardMaterial3D_cabin")

[node name="CarInput" type="Node" parent="."]
script = ExtResource("3_input")

[node name="WheelFL" type="Node3D" parent="."]
script = ExtResource("2_wheel")
is_front = true
is_left = true

[node name="WheelFR" type="Node3D" parent="."]
script = ExtResource("2_wheel")
is_front = true

[node name="WheelRL" type="Node3D" parent="."]
script = ExtResource("2_wheel")
is_left = true

[node name="WheelRR" type="Node3D" parent="."]
script = ExtResource("2_wheel")
```

- [ ] **Step 6: Run all tests**

Run: `./run_tests.sh all`
Expected: exit 0; `test_car_scenarios.gd` 8 passing, with printed lines close to:

```
parked creep: 0.0002 m
0-100 km/h: 7.71 s
braking 100-0 km/h: 36.6 m
tire slip: asphalt 12.1 deg, mud 13.0 deg | yaw rate: asphalt 26.0 deg/s, mud 14.8 deg/s
```

- [ ] **Step 7: Commit**

```bash
git add car tests
git commit -m "Add car scene with scenario tests for ride height, launch, braking, mud and air control"
```

---

### Task 12: Chase camera

**Files:**
- Create: `camera/chase_camera.gd`
- Test: `tests/unit/test_chase_camera.gd`

**Interfaces:**
- Consumes: `Car` (`global_position`, `global_basis`, `get_rid()`).
- Produces: `ChaseCamera` (Camera3D):
  - Exports: `target: Car`, `distance`, `height`, `look_ahead`, `look_height`, `follow_stiffness`, `look_stiffness`.
  - Methods: `snap_to_target()`, and static `damp(current, target_value, stiffness, delta) -> Vector3` and `flat_heading(car_basis, previous) -> Vector3`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_chase_camera.gd`:

```gdscript
extends GutTest


func test_damp_moves_part_way_toward_the_target() -> void:
	var result := ChaseCamera.damp(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 5.0, 0.1)
	# 10 * (1 - e^-0.5) = 3.93
	assert_almost_eq(result.x, 3.935, 0.001)


func test_damp_is_frame_rate_independent() -> void:
	var goal := Vector3(10.0, 4.0, -2.0)
	var one_step := ChaseCamera.damp(Vector3.ZERO, goal, 5.0, 0.1)
	var two_steps := ChaseCamera.damp(ChaseCamera.damp(Vector3.ZERO, goal, 5.0, 0.05), goal, 5.0, 0.05)
	assert_almost_eq(one_step.distance_to(two_steps), 0.0, 0.0001)


func test_damp_arrives_eventually() -> void:
	var result := ChaseCamera.damp(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 5.0, 10.0)
	assert_almost_eq(result.x, 10.0, 0.001)


func test_flat_heading_ignores_pitch() -> void:
	var nose_up := Basis(Vector3.RIGHT, deg_to_rad(30.0))
	var heading := ChaseCamera.flat_heading(nose_up, Vector3.RIGHT)
	assert_almost_eq(heading.distance_to(Vector3.FORWARD), 0.0, 0.0001)


func test_flat_heading_keeps_previous_when_pointing_straight_up() -> void:
	var vertical := Basis(Vector3.RIGHT, deg_to_rad(90.0))
	assert_eq(ChaseCamera.flat_heading(vertical, Vector3.RIGHT), Vector3.RIGHT)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `ChaseCamera` is not declared.

- [ ] **Step 3: Implement**

`camera/chase_camera.gd`:

```gdscript
class_name ChaseCamera
extends Camera3D
## Smooth third-person camera behind and above the car. It follows the car's
## heading flattened to the horizontal, so it doesn't tumble with the car in the air.

@export var target: Car
@export var distance: float = 6.5
@export var height: float = 2.4
## The camera looks at a point this far ahead of the car and this high above it.
@export var look_ahead: float = 3.0
@export var look_height: float = 0.8
## How quickly the camera catches up, per second. Higher = tighter.
@export var follow_stiffness: float = 5.0
@export var look_stiffness: float = 10.0

var _heading := Vector3.FORWARD
var _look_point := Vector3.ZERO


func _ready() -> void:
	if target != null:
		snap_to_target()


func _process(delta: float) -> void:
	if target == null:
		return
	_heading = flat_heading(target.global_basis, _heading)
	var position_now := damp(global_position, _desired_position(), follow_stiffness, delta)
	global_position = _avoid_terrain(position_now)
	_look_point = damp(_look_point, _desired_look_point(), look_stiffness, delta)
	look_at(_look_point, Vector3.UP)


## Jump straight to the resting position, e.g. after a reset.
func snap_to_target() -> void:
	_heading = flat_heading(target.global_basis, _heading)
	global_position = _desired_position()
	_look_point = _desired_look_point()
	look_at(_look_point, Vector3.UP)


## Frame-rate independent exponential smoothing toward target_value.
static func damp(current: Vector3, target_value: Vector3, stiffness: float, delta: float) -> Vector3:
	return target_value + (current - target_value) * exp(-stiffness * delta)


## The car's forward direction flattened onto the horizontal plane. When the car
## points nearly straight up or down, the previous heading is kept.
static func flat_heading(car_basis: Basis, previous: Vector3) -> Vector3:
	var forward := -car_basis.z
	forward.y = 0.0
	if forward.length() < 0.2:
		return previous
	return forward.normalized()


func _desired_position() -> Vector3:
	return target.global_position - _heading * distance + Vector3.UP * height


func _desired_look_point() -> Vector3:
	return target.global_position + _heading * look_ahead + Vector3.UP * look_height


## Pull the camera in front of any terrain between it and the car.
func _avoid_terrain(camera_position: Vector3) -> Vector3:
	var from := target.global_position + Vector3.UP * look_height
	var query := PhysicsRayQueryParameters3D.create(from, camera_position)
	query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return camera_position
	var hit_position: Vector3 = hit["position"]
	return hit_position + (from - camera_position).normalized() * 0.3
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_chase_camera.gd` 5 passing.

- [ ] **Step 5: Commit**

```bash
git add camera tests/unit/test_chase_camera.gd
git commit -m "Add smoothed chase camera"
```

---

### Task 13: Touch controls (both steering styles)

**Files:**
- Create: `input/touch_steer_logic.gd`, `input/touch_controls.gd`
- Test: `tests/unit/test_touch_steer_logic.gd`, `tests/unit/test_touch_controls.gd`

**Interfaces:**
- Consumes: `CarInput` (`virtual_*`, `request_reset()`).
- Produces:
  - `TouchSteerLogic`: enum `Mode { ANALOG, BUTTONS }`, and static `analog_steer(offset_px, full_lock_px, deadzone_px) -> float` and `button_steer(current, left_held, right_held, ramp_per_second, return_per_second, delta) -> float`.
  - `TouchControls` (CanvasLayer):
    - Signals: `telemetry_toggled`, `recording_toggled`.
    - Fields: `car_input: CarInput` (export), `steer_mode`, `screen_size_override`.
    - Methods: `handle_touch(index, point, pressed)`, `handle_drag(index, point)`, `update_outputs(delta)`, `gas_rect()`, `brake_rect()`, `left_button_rect()`, `right_button_rect()`.
    - Constants: `FULL_LOCK_PX`, `TOP_STRIP_HEIGHT`.
  - The touch controls own the car's `virtual_*` inputs in a scene. Tests that drive a car inside a scene must disable them.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_touch_steer_logic.gd`:

```gdscript
extends GutTest


func test_analog_inside_deadzone_is_zero() -> void:
	assert_almost_eq(TouchSteerLogic.analog_steer(10.0, 140.0, 12.0), 0.0, 0.0001)


func test_analog_full_lock() -> void:
	assert_almost_eq(TouchSteerLogic.analog_steer(140.0, 140.0, 12.0), 1.0, 0.0001)
	assert_almost_eq(TouchSteerLogic.analog_steer(-400.0, 140.0, 12.0), -1.0, 0.0001)


func test_analog_is_proportional_past_the_deadzone() -> void:
	# (76 - 12) / (140 - 12) = 0.5
	assert_almost_eq(TouchSteerLogic.analog_steer(76.0, 140.0, 12.0), 0.5, 0.0001)
	assert_almost_eq(TouchSteerLogic.analog_steer(-76.0, 140.0, 12.0), -0.5, 0.0001)


func test_buttons_ramp_toward_the_held_side() -> void:
	assert_almost_eq(TouchSteerLogic.button_steer(0.0, false, true, 3.0, 5.0, 0.1), 0.3, 0.0001)
	assert_almost_eq(TouchSteerLogic.button_steer(0.0, true, false, 3.0, 5.0, 0.1), -0.3, 0.0001)


func test_buttons_recentre_when_released() -> void:
	assert_almost_eq(TouchSteerLogic.button_steer(0.8, false, false, 3.0, 5.0, 0.1), 0.3, 0.0001)


func test_holding_both_buttons_recentres() -> void:
	assert_almost_eq(TouchSteerLogic.button_steer(0.4, true, true, 3.0, 5.0, 0.1), 0.0, 0.0001)
```

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
```

- [ ] **Step 2: Run them and watch them fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `TouchSteerLogic`/`TouchControls` are not declared.

- [ ] **Step 3: Implement the steering maths**

`input/touch_steer_logic.gd`:

```gdscript
class_name TouchSteerLogic
extends RefCounted
## Pure maths for the two touch steering styles.

enum Mode { ANALOG, BUTTONS }


## Analog: how far the thumb slid sideways from where it touched down (pixels).
## Inside the deadzone -> 0. At full_lock_px or beyond -> +/-1.
static func analog_steer(offset_px: float, full_lock_px: float, deadzone_px: float) -> float:
	var magnitude := absf(offset_px)
	if magnitude <= deadzone_px:
		return 0.0
	return signf(offset_px) * minf((magnitude - deadzone_px) / (full_lock_px - deadzone_px), 1.0)


## Buttons: steer ramps toward the held side and recentres when released.
## Holding both sides (or neither) recentres.
static func button_steer(current: float, left_held: bool, right_held: bool,
		ramp_per_second: float, return_per_second: float, delta: float) -> float:
	var target := 0.0
	if left_held != right_held:
		target = -1.0 if left_held else 1.0
	var rate := ramp_per_second if target != 0.0 else return_per_second
	return move_toward(current, target, rate * delta)
```

- [ ] **Step 4: Implement the controls**

`input/touch_controls.gd`:

```gdscript
class_name TouchControls
extends CanvasLayer
## On-screen driving controls for phones (also usable with a mouse on desktop,
## because the project emulates touch from the mouse).
##   Left side:  steering - an analog drag zone, or two buttons.
##   Right side: brake and gas pedals.
##   Top strip:  steering-style toggle, reset, telemetry and recording.
## Writes into the car's CarInput virtual_* values.
## Coordinates are in the 1920x1080 canvas (the project stretches it to the screen).

signal telemetry_toggled
signal recording_toggled

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

- [ ] **Step 5: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_touch_steer_logic.gd` 6 passing and `test_touch_controls.gd` 8 passing.

- [ ] **Step 6: Commit**

```bash
git add input tests/unit/test_touch_steer_logic.gd tests/unit/test_touch_controls.gd
git commit -m "Add touch controls with analog and button steering"
```

---

### Task 14: Run recorder

**Files:**
- Create: `debug/run_recorder.gd`
- Test: `tests/unit/test_run_recorder.gd`

**Interfaces:**
- Consumes: `Car.get_telemetry()`, `InputActions.TOGGLE_RECORDING`, `TelemetrySample` (tests).
- Produces: `RunRecorder` (Node):
  - Signal `recording_changed(is_recording: bool, path: String)`.
  - Export `car: Car`.
  - Methods: `start(path := "") -> String`, `stop() -> String`, `toggle()`, `is_recording() -> bool`, `record(telemetry: Dictionary, time: float)`, and static `csv_header() -> String` and `csv_row(telemetry, time) -> String`.
  - Files are written to `user://runs/run_<timestamp>.csv`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_run_recorder.gd`:

```gdscript
extends GutTest

const TEST_DIR := "user://test_runs"
const TEST_PATH := "user://test_runs/test_run.csv"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_header_has_car_and_wheel_columns() -> void:
	var header := RunRecorder.csv_header()
	assert_string_starts_with(header, "time,speed_kmh,rpm,gear")
	assert_string_contains(header, "fl_slip_ratio")
	assert_string_contains(header, "rr_surface")


func test_row_has_as_many_columns_as_the_header() -> void:
	var row := RunRecorder.csv_row(TelemetrySample.make(), 1.0)
	assert_eq(row.split(",").size(), RunRecorder.csv_header().split(",").size())


func test_row_values() -> void:
	var row := RunRecorder.csv_row(TelemetrySample.make(), 1.5)
	assert_string_starts_with(row, "1.5000,42.50,4100,-1,")
	assert_string_contains(row, ",mud,")


func test_start_record_stop_writes_a_file() -> void:
	var recorder: RunRecorder = add_child_autofree(RunRecorder.new())
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	assert_eq(recorder.start(TEST_PATH), TEST_PATH)
	assert_true(recorder.is_recording())
	recorder.record(TelemetrySample.make(), 0.0)
	recorder.record(TelemetrySample.make(), 0.01)
	recorder.stop()
	assert_false(recorder.is_recording())
	var lines := FileAccess.get_file_as_string(TEST_PATH).strip_edges().split("\n")
	assert_eq(lines.size(), 3, "header + 2 rows")
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `RunRecorder` is not declared.

- [ ] **Step 3: Implement**

`debug/run_recorder.gd`:

```gdscript
class_name RunRecorder
extends Node
## Records the car's telemetry every physics tick into a CSV file under
## user://runs/, so a run on the phone can be analysed afterwards.
## Toggle with F2 or the "Rec" touch button. Copy files off the phone with
## tools/pull_runs.sh.

signal recording_changed(is_recording: bool, path: String)

const RUNS_DIR := "user://runs"
const WHEEL_NAMES := ["fl", "fr", "rl", "rr"]
const WHEEL_FIELDS := ["contact", "surface", "load", "compression", "slip_ratio", "slip_angle_deg", "spin"]

@export var car: Car

var _file: FileAccess
var _path := ""
var _time := 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.TOGGLE_RECORDING):
		toggle()


func _physics_process(delta: float) -> void:
	if is_recording() and car != null:
		_time += delta
		record(car.get_telemetry(), _time)


func is_recording() -> bool:
	return _file != null


func toggle() -> void:
	if is_recording():
		stop()
	else:
		start()


## Starts a new file. With no path, a timestamped file in RUNS_DIR is used.
## Returns the path, or "" if the file could not be opened.
func start(path: String = "") -> String:
	if is_recording():
		stop()
	if path.is_empty():
		DirAccess.make_dir_recursive_absolute(RUNS_DIR)
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		path = "%s/run_%s.csv" % [RUNS_DIR, stamp]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("RunRecorder: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return ""
	_path = path
	_time = 0.0
	_file.store_line(csv_header())
	recording_changed.emit(true, _path)
	return _path


## Closes the file. Returns its path.
func stop() -> String:
	if not is_recording():
		return ""
	_file.close()
	_file = null
	print("RunRecorder: saved ", ProjectSettings.globalize_path(_path))
	recording_changed.emit(false, _path)
	return _path


func record(telemetry: Dictionary, time: float) -> void:
	if is_recording():
		_file.store_line(csv_row(telemetry, time))


static func csv_header() -> String:
	var columns := PackedStringArray(["time", "speed_kmh", "rpm", "gear", "throttle", "brake", "steer",
			"airborne", "pos_x", "pos_y", "pos_z", "pitch_deg", "yaw_deg", "roll_deg"])
	for wheel_name in WHEEL_NAMES:
		for field in WHEEL_FIELDS:
			columns.append("%s_%s" % [wheel_name, field])
	return ",".join(columns)


static func csv_row(telemetry: Dictionary, time: float) -> String:
	var pos: Vector3 = telemetry.position
	var rot: Vector3 = telemetry.rotation_deg
	var values := PackedStringArray([
		"%.4f" % time, "%.2f" % telemetry.speed_kmh, "%.0f" % telemetry.rpm, str(telemetry.gear),
		"%.3f" % telemetry.throttle, "%.3f" % telemetry.brake, "%.3f" % telemetry.steer,
		"1" if telemetry.airborne else "0",
		"%.3f" % pos.x, "%.3f" % pos.y, "%.3f" % pos.z,
		"%.2f" % rot.x, "%.2f" % rot.y, "%.2f" % rot.z,
	])
	for wheel: Dictionary in telemetry.wheels:
		values.append("1" if wheel.contact else "0")
		values.append(str(wheel.surface))
		values.append("%.1f" % wheel.load)
		values.append("%.4f" % wheel.compression)
		values.append("%.4f" % wheel.slip_ratio)
		values.append("%.3f" % wheel.slip_angle_deg)
		values.append("%.3f" % wheel.spin)
	return ",".join(values)
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_run_recorder.gd` 4 passing.

- [ ] **Step 5: Commit**

```bash
git add debug/run_recorder.gd debug/run_recorder.gd.uid tests/unit/test_run_recorder.gd
git commit -m "Add CSV run recorder"
```

---

### Task 15: Telemetry overlay

**Files:**
- Create: `debug/telemetry_overlay.gd`
- Test: `tests/unit/test_telemetry_overlay.gd`

**Interfaces:**
- Consumes: `Car.get_telemetry()`, `RunRecorder.is_recording()` (Task 14; the export may be left empty), `InputActions.TOGGLE_TELEMETRY`, `TelemetrySample` (tests).
- Produces: `TelemetryOverlay` (CanvasLayer): exports `car: Car` and `recorder: RunRecorder`; methods `toggle()`, static `format(telemetry: Dictionary, perf: Dictionary) -> String` and static `performance_snapshot() -> Dictionary` (keys `fps`, `process_ms`, `physics_ms`).

- [ ] **Step 1: Write the failing test**

`tests/unit/test_telemetry_overlay.gd`:

```gdscript
extends GutTest

const PERF := {"fps": 60.0, "process_ms": 4.2, "physics_ms": 1.1}


func test_format_shows_performance() -> void:
	var text := TelemetryOverlay.format(TelemetrySample.make(), PERF)
	assert_string_contains(text, "60 fps")
	assert_string_contains(text, "physics 1.1 ms")


func test_format_shows_speed_and_reverse_gear() -> void:
	var text := TelemetryOverlay.format(TelemetrySample.make(), PERF)
	assert_string_contains(text, "42.5 km/h")
	assert_string_contains(text, "gear R")


func test_format_has_a_line_per_wheel() -> void:
	var text := TelemetryOverlay.format(TelemetrySample.make(), PERF)
	for wheel_name in ["FL", "FR", "RL", "RR"]:
		assert_string_contains(text, wheel_name + " mud")
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `TelemetryOverlay` is not declared.

- [ ] **Step 3: Implement**

`debug/telemetry_overlay.gd`:

```gdscript
class_name TelemetryOverlay
extends CanvasLayer
## Live numbers for tuning: performance, car state, and each wheel.
## Toggle with F1, the gamepad Back button, or the "Telemetry" touch button.

const WHEEL_NAMES := ["FL", "FR", "RL", "RR"]

@export var car: Car
@export var recorder: RunRecorder

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(20.0, 150.0)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.TOGGLE_TELEMETRY):
		toggle()


func _process(_delta: float) -> void:
	if not visible or car == null:
		return
	var text := format(car.get_telemetry(), performance_snapshot())
	if recorder != null and recorder.is_recording():
		text = "[REC]\n" + text
	_label.text = text


func toggle() -> void:
	visible = not visible


static func performance_snapshot() -> Dictionary:
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
	}


static func format(telemetry: Dictionary, perf: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("%d fps   frame %.1f ms   physics %.1f ms" % [perf.fps, perf.process_ms, perf.physics_ms])
	lines.append("%.1f km/h   gear %s   %d rpm   %s" % [telemetry.speed_kmh, _gear_name(telemetry.gear),
			telemetry.rpm, "AIR" if telemetry.airborne else ""])
	lines.append("thr %.2f   brk %.2f   steer %+.2f" % [telemetry.throttle, telemetry.brake, telemetry.steer])
	for i in telemetry.wheels.size():
		var wheel: Dictionary = telemetry.wheels[i]
		lines.append("%s %-7s load %5.0f  comp %.2f  slip %+.2f  angle %+5.1f" % [WHEEL_NAMES[i],
				wheel.surface, wheel.load, wheel.compression, wheel.slip_ratio, wheel.slip_angle_deg])
	return "\n".join(lines)


static func _gear_name(gear: int) -> String:
	return "R" if gear < 0 else str(gear)
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_telemetry_overlay.gd` 3 passing.

- [ ] **Step 5: Commit**

```bash
git add debug/telemetry_overlay.gd debug/telemetry_overlay.gd.uid tests/unit/test_telemetry_overlay.gd
git commit -m "Add telemetry overlay"
```

---

### Task 16: Golden-hour mood

**Files:**
- Create: `levels/shared/golden_hour_mood.gd`
- Test: `tests/unit/test_golden_hour_mood.gd`

**Interfaces:**
- Produces: `GoldenHourMood` (Node3D): exports the sun colour/energy/elevation/azimuth, sky top/horizon, ground colour, fog density and shadow distance; fields `environment: Environment` and `sun: DirectionalLight3D`, both built in `_ready()`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_golden_hour_mood.gd`:

```gdscript
extends GutTest


func test_builds_environment_with_fog_and_sky() -> void:
	var mood: GoldenHourMood = add_child_autofree(GoldenHourMood.new())
	assert_not_null(mood.environment)
	assert_true(mood.environment.fog_enabled)
	assert_eq(mood.environment.background_mode, Environment.BG_SKY)


func test_builds_a_low_shadow_casting_sun() -> void:
	var mood: GoldenHourMood = add_child_autofree(GoldenHourMood.new())
	assert_true(mood.sun.shadow_enabled)
	assert_lt(mood.sun.rotation_degrees.x, 0.0, "the sun points down")
	assert_gt(mood.sun.rotation_degrees.x, -45.0, "and sits low, golden-hour style")
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh unit`
Expected: exit 1, `SCRIPT ERROR` saying `GoldenHourMood` is not declared.

- [ ] **Step 3: Implement**

`levels/shared/golden_hour_mood.gd`:

```gdscript
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
```

- [ ] **Step 4: Run the tests**

Run: `./run_tests.sh unit`
Expected: exit 0; `test_golden_hour_mood.gd` 2 passing.

- [ ] **Step 5: Commit**

```bash
git add levels/shared tests/unit/test_golden_hour_mood.gd
git commit -m "Add golden-hour mood (sky, sun, fog, grade)"
```

---

### Task 17: Test Ground scene, main scene and screenshot tool

**Files:**
- Create: `levels/test_ground/test_ground.gd`, `levels/test_ground/test_ground.tscn`, `tests/scenarios/test_test_ground.gd`, `tools/screenshot.sh`
- Modify: `project.godot` (`[application]` section: add the main scene)

**Interfaces:**
- Consumes: `Car`, `ChaseCamera`, `TouchControls`, `TelemetryOverlay`, `RunRecorder`, `GoldenHourMood`, the surfaces, and `ScenarioHelper`.
- Produces:
  - The main scene `res://levels/test_ground/test_ground.tscn`. Its root node has children `Mood`, `Car`, `ChaseCamera`, `TouchControls`, `RunRecorder` and `TelemetryOverlay`; the spawn transform is `(0, 1, 0)` facing −Z.
  - `tools/screenshot.sh [scene] [seconds]`, which prints the path of the last PNG frame.

- [ ] **Step 1: Write the failing scenario test**

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
	var car: Car = level.get_node("Car")
	for wheel in car.wheels:
		assert_true(wheel.in_contact)
		assert_eq(wheel.surface.id, &"asphalt")
	assert_true(ScenarioHelper.is_upright(car))


func test_reset_returns_the_car_to_spawn() -> void:
	var level := _load_level()
	var car: Car = level.get_node("Car")
	# The touch controls own the car's virtual inputs in a real scene; switch them
	# off so this test can drive the car through the same inputs.
	level.get_node("TouchControls").process_mode = Node.PROCESS_MODE_DISABLED
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	car.input.virtual_throttle = 1.0
	await wait_physics_frames(ScenarioHelper.ticks(2.0))
	car.input.virtual_throttle = 0.0
	assert_lt(car.global_position.z, -5.0, "the car drove away first")
	car.input.request_reset()
	assert_almost_eq(car.global_position.distance_to(Vector3(0.0, 1.0, 0.0)), 0.0, 0.01)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `./run_tests.sh scenarios`
Expected: exit 1, a `SCRIPT ERROR` about the missing `res://levels/test_ground/test_ground.tscn` preload.

- [ ] **Step 3: Implement the Test Ground builder**

`levels/test_ground/test_ground.gd`:

```gdscript
extends Node3D
## Gray-box tuning ground (dev only). From the spawn point, facing -Z:
##   - dirt everywhere (the base ground)
##   - an asphalt runway straight ahead, with slalom cones and a kicker jump
##   - a mud strip parallel to the runway, 30 m to the right
##   - three hills to the left: 10 and 20 degree dirt, 30 degree asphalt
## Press R (or the Reset button) to return to the spawn point.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")

## Thickness of ramps and plateaus (m).
const SLAB := 1.0

@onready var car: Car = $Car
@onready var camera: ChaseCamera = $ChaseCamera
@onready var touch_controls: TouchControls = $TouchControls
@onready var telemetry: TelemetryOverlay = $TelemetryOverlay
@onready var recorder: RunRecorder = $RunRecorder

var _spawn: Transform3D


func _ready() -> void:
	_build_layout()
	_spawn = car.global_transform
	car.input.reset_requested.connect(_on_reset_requested)
	touch_controls.telemetry_toggled.connect(telemetry.toggle)
	touch_controls.recording_toggled.connect(recorder.toggle)


func _on_reset_requested() -> void:
	car.reset_to(_spawn)
	camera.snap_to_target()


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

- [ ] **Step 4: Create the scene**

`levels/test_ground/test_ground.tscn`:

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://levels/test_ground/test_ground.gd" id="1_ground"]
[ext_resource type="PackedScene" path="res://car/car.tscn" id="2_car"]
[ext_resource type="Script" path="res://levels/shared/golden_hour_mood.gd" id="3_mood"]
[ext_resource type="Script" path="res://camera/chase_camera.gd" id="4_camera"]
[ext_resource type="Script" path="res://input/touch_controls.gd" id="5_touch"]
[ext_resource type="Script" path="res://debug/telemetry_overlay.gd" id="6_telemetry"]
[ext_resource type="Script" path="res://debug/run_recorder.gd" id="7_recorder"]

[node name="TestGround" type="Node3D"]
script = ExtResource("1_ground")

[node name="Mood" type="Node3D" parent="."]
script = ExtResource("3_mood")

[node name="Car" parent="." instance=ExtResource("2_car")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)

[node name="ChaseCamera" type="Camera3D" parent="." node_paths=PackedStringArray("target")]
current = true
far = 1500.0
script = ExtResource("4_camera")
target = NodePath("../Car")

[node name="TouchControls" type="CanvasLayer" parent="." node_paths=PackedStringArray("car_input")]
script = ExtResource("5_touch")
car_input = NodePath("../Car/CarInput")

[node name="RunRecorder" type="Node" parent="." node_paths=PackedStringArray("car")]
script = ExtResource("7_recorder")
car = NodePath("../Car")

[node name="TelemetryOverlay" type="CanvasLayer" parent="." node_paths=PackedStringArray("car", "recorder")]
script = ExtResource("6_telemetry")
car = NodePath("../Car")
recorder = NodePath("../RunRecorder")
```

- [ ] **Step 5: Make it the main scene**

In `project.godot`, in the `[application]` section, add this line directly after `config/name="Ridge"`:

```ini
run/main_scene="res://levels/test_ground/test_ground.tscn"
```

- [ ] **Step 6: Run all tests**

Run: `./run_tests.sh all`
Expected: exit 0 and **123 passing tests** in total (`test_test_ground.gd` 2 passing).

- [ ] **Step 7: Add the screenshot tool and look at the result**

`tools/screenshot.sh`:

```bash
#!/usr/bin/env bash
# Renders a scene in a real window for a few seconds and saves the frames as PNG.
# Prints the path of the last frame.
# Usage: tools/screenshot.sh [scene] [seconds]
set -euo pipefail
cd "$(dirname "$0")/.."

scene="${1:-res://levels/test_ground/test_ground.tscn}"
seconds="${2:-3}"
out="build/screenshots"

mkdir -p "$out"
rm -f "$out"/frame*.png "$out"/frame.wav
godot --path . --fixed-fps 30 --write-movie "$out/frame.png" --quit-after $((seconds * 30)) "$scene" >/dev/null 2>&1
ls "$out"/frame*.png | tail -1
```

```bash
chmod +x tools/screenshot.sh
tools/screenshot.sh
```

Expected: it prints `build/screenshots/frame00000089.png`. Open that image and check what it shows: warm golden-hour sky and fog, the orange gray-box car on a dark asphalt runway seen from behind and above, orange cones ahead, dirt hills to the left, the GAS/BRAKE pads bottom-right, the top-strip buttons, and telemetry text showing `asphalt load ~3188 comp 0.12` for all four wheels.

- [ ] **Step 8: Desktop drive check (the user, about 5 minutes)**

Run: `godot --path .` (or press F5 in the editor).

Check:
- W/S accelerate and brake.
- Holding S at a standstill reverses.
- A/D steer.
- R resets.
- F1 toggles telemetry.
- F2 starts and stops recording (the overlay shows `[REC]`).
- Clicking and dragging the mouse on the left half steers (analog).
- "Steer: Analog" switches to the ◀ ▶ buttons.
- The GAS and BRAKE pads work with the mouse.
- Hills, the jump, the mud strip and the slalom cones are all reachable.

- [ ] **Step 9: Commit**

```bash
git add levels tests/scenarios/test_test_ground.gd tools/screenshot.sh project.godot
git commit -m "Add gray-box Test Ground as main scene, plus screenshot tool"
```

---

### Task 18: Android debug build on the Xiaomi 13

**Files:**
- Create: `export_presets.cfg`, `tools/android.sh`, `tools/pull_runs.sh`
- Machine setup (outside the repo): the Godot export templates, a debug keystore, and the Android paths in the Godot editor settings

**Interfaces:**
- Produces: `tools/android.sh [build|install|run|logs|all]` builds `build/ridge-debug.apk`; `tools/pull_runs.sh` copies `user://runs/*.csv` from the phone into `./runs/`.

- [ ] **Step 1: Install the Godot 4.7.2 export templates** (about 1.3 GB download)

```bash
mkdir -p ~/.local/share/godot/export_templates/4.7.2.stable
cd /tmp
curl -L -o godot-templates.tpz https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
unzip -q godot-templates.tpz -d godot-templates
mv godot-templates/templates/* ~/.local/share/godot/export_templates/4.7.2.stable/
rm -rf godot-templates godot-templates.tpz
cd -
ls ~/.local/share/godot/export_templates/4.7.2.stable | grep android
```

Expected: `android_debug.apk`, `android_release.apk` and `android_source.zip` are listed.

- [ ] **Step 2: Create the debug keystore (skipped if it already exists)**

```bash
mkdir -p ~/.local/share/godot/keystores
[ -f ~/.local/share/godot/keystores/debug.keystore ] || keytool -genkeypair -v \
  -keystore ~/.local/share/godot/keystores/debug.keystore -storepass android \
  -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US"
```

- [ ] **Step 3: Point Godot at the SDK, the JDK and the keystore**

Close the Godot editor first, because it rewrites this file on exit.

```bash
SETTINGS=~/.config/godot/editor_settings-4.7.tres
grep -q "export/android/android_sdk_path" "$SETTINGS" || cat >> "$SETTINGS" <<'EOF'
export/android/android_sdk_path = "/home/stoyan/Android/Sdk"
export/android/java_sdk_path = "/home/stoyan/tools/jdk-17-current"
export/android/debug_keystore = "/home/stoyan/.local/share/godot/keystores/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
grep "export/android" "$SETTINGS"
```

Expected: the five `export/android/...` lines are printed. If Step 6 still complains about the SDK or JDK, set the same values in the editor under **Editor → Editor Settings → Export → Android** instead.

- [ ] **Step 4: Create the export preset**

`export_presets.cfg`:

```ini
[preset.0]

name="Android"
platform="Android"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*,addons/gut/*,docs/*,tools/*,runs/*,build/*"
export_path="build/ridge-debug.apk"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

gradle_build/use_gradle_build=false
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="0.1.0"
package/unique_name="com.ridge.game"
package/name="Ridge"
package/signed=true
screen/immersive_mode=true
```

- [ ] **Step 5: Add the phone scripts**

`tools/android.sh`:

```bash
#!/usr/bin/env bash
# Debug builds for the phone.
# Usage: tools/android.sh [build|install|run|logs|all]   (default: all = build + install + run)
set -euo pipefail
cd "$(dirname "$0")/.."

PKG="com.ridge.game"
APK="build/ridge-debug.apk"

build() {
  mkdir -p build
  godot --headless --export-debug "Android" "$APK"
  ls -lh "$APK"
}

install() {
  adb install -r "$APK"
}

run() {
  adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
}

logs() {
  adb logcat -s godot:V
}

case "${1:-all}" in
  build) build ;;
  install) install ;;
  run) run ;;
  logs) logs ;;
  all) build; install; run ;;
  *) echo "Usage: $0 [build|install|run|logs|all]"; exit 2 ;;
esac
```

`tools/pull_runs.sh`:

```bash
#!/usr/bin/env bash
# Copies recorded runs (CSV files) from the phone into ./runs/.
# Works with debug builds only (adb run-as needs a debuggable app).
set -euo pipefail
cd "$(dirname "$0")/.."

PKG="com.ridge.game"
REMOTE_DIR="files/runs"   # user://runs, relative to the app's data folder

mkdir -p runs
files=$(adb shell run-as "$PKG" ls "$REMOTE_DIR" 2>/dev/null | tr -d '\r' || true)
if [ -z "$files" ]; then
  echo "No runs found on the phone (record one with the Rec button first)."
  exit 0
fi
for f in $files; do
  adb exec-out run-as "$PKG" cat "$REMOTE_DIR/$f" > "runs/$f"
  echo "runs/$f"
done
```

```bash
chmod +x tools/android.sh tools/pull_runs.sh
```

- [ ] **Step 6: Build the APK**

Run: `tools/android.sh build`
Expected: no export errors, and `ls -lh` shows `build/ridge-debug.apk`. In the verified copy, before the templates were installed, this command failed only on the missing templates, which confirms the preset itself is read correctly.

- [ ] **Step 7: Prepare the phone (the user)**

On the Xiaomi 13:
1. Go to **Settings → About phone** and tap **OS version** 7 times.
2. In **Settings → Additional settings → Developer options**, enable **USB debugging**, **Install via USB** and **USB debugging (Security settings)**. Xiaomi requires a signed-in Mi account for the last two.
3. Connect the USB cable and accept the "Allow USB debugging" prompt.

Run: `adb devices`
Expected: one device listed as `device` (not `unauthorized`).

- [ ] **Step 8: Install and launch**

Run: `tools/android.sh install && tools/android.sh run`
Expected: Ridge opens in landscape on the Test Ground, with the golden-hour sky, the car, touch pads and telemetry.

- [ ] **Step 9: On-phone checks (the user)**

- Touch GAS and BRAKE, and hold BRAKE at a standstill to reverse.
- Steer with an analog drag, then switch to buttons and steer with ◀ ▶.
- Drive while steering (two thumbs).
- Tap Reset, Telemetry and Rec.
- Rec: tap once, drive about 20 s, tap again.

Then run `tools/android.sh logs` in a terminal and look for `RunRecorder: saved /data/.../files/runs/run_....csv`. The path must contain `/files/runs/`; if it doesn't, update `REMOTE_DIR` in `tools/pull_runs.sh` to match. Stop the log with Ctrl+C.

- [ ] **Step 10: Pull the recorded run**

Run: `tools/pull_runs.sh`
Expected: it prints `runs/run_<timestamp>.csv`, and `head -2` of that file shows the header plus one data row.

- [ ] **Step 11: Commit**

```bash
git add export_presets.cfg tools/android.sh tools/pull_runs.sh
git commit -m "Add Android debug export and phone helper scripts"
```

---

### Task 19: Performance profile on the phone

**Files:**
- Create: `docs/notes/performance-m1.md`

- [ ] **Step 1: Measure (the user drives, the developer reads)**

With telemetry on, drive the Test Ground for 2 minutes, including the runway at speed, the mud strip, the jump and the hills. Watch the first telemetry line (`fps`, `frame ms`, `physics ms`) and note the lowest FPS and the highest frame and physics times you see. Targets: a steady **60 FPS**; physics under **4 ms**; frame under **12 ms**.

- [ ] **Step 2: Record the results**

Create `docs/notes/performance-m1.md`, filling each value with the number actually observed:

```markdown
# Milestone 1 performance, Xiaomi 13 (Snapdragon 8 Gen 2)

Date: <date of the measurement>
Build: debug APK, Mobile renderer, physics 120 Hz, max 60 FPS

| Scene | Lowest FPS | Highest frame ms | Highest physics ms |
|---|---|---|---|
| Test Ground, 2-minute drive | ... | ... | ... |

Verdict: <meets / misses the 60 FPS target>
Actions taken: <none, or which lever was used and the new numbers>
```

- [ ] **Step 3: If a target is missed, apply the levers in this order and re-measure after each**

1. In `test_ground.tscn`, set `Mood` → `shadow_distance` = 40.
2. In `project.godot`, set `common/physics_ticks_per_second=90`. This is a physics change: re-run `./run_tests.sh all` and note any shift in the printed scenario numbers.
3. Stop and discuss with the user before going further.

- [ ] **Step 4: Commit**

```bash
git add docs/notes/performance-m1.md
git commit -m "Record Milestone 1 performance on Xiaomi 13"
```

---

### Task 20: Feel tuning loop and sign-off

**Files:**
- Create: `docs/notes/feel-log.md`
- Modify: `car/rally_car.tres`, `surfaces/*.tres` (tuning values), `tests/scenarios/feel_baseline.gd` (at sign-off)

This task repeats until the user signs off. Tuning changes `.tres` values first. Code changes only happen when a behaviour can't be reached by tuning, and those follow TDD like any other change.

- [ ] **Step 1: Create the feel log**

```markdown
# Feel log: Rally Car, Milestone 1

One entry per session. The developer records what changed in response.

## Session 1 (date)
Build: <git short hash>
Checklist:
- [ ] Launch on asphalt (full gas from standstill)
- [ ] Hard braking from speed
- [ ] Slalom through the cones
- [ ] Hill start on the 20 and 30 degree hills
- [ ] Kicker jump: air control pitch (gas / brake) and roll (steer)
- [ ] Mud strip: accelerate, turn, stop
- [ ] Both steering styles
Notes (what I did / what I felt / what I expected):
-
Runs recorded: runs/...
Changes made in response:
-
```

- [ ] **Step 2: Run a session**

1. The user drives the checklist on the phone, writes notes, and records a run for each problem using Rec.
2. The developer runs `tools/pull_runs.sh` and reads the relevant CSV columns, for example `rl_slip_ratio` for wheelspin, `fl_slip_angle_deg` for understeer, `*_compression` for bottoming out, and `airborne` for jumps.
3. The developer maps each note to the `CarStats`/`SurfaceDef` fields involved, changes the values, runs `./run_tests.sh all`, then `tools/android.sh`, and records the change in the log.

- [ ] **Step 3: Decide the two deferred questions** (spec §13)

- Keep steer-to-roll in the air, or set `air_roll_torque = 0.0`.
- Choose the default steering style by changing `steer_mode` in `input/touch_controls.gd` if Buttons wins.

Record both decisions in the feel log.

- [ ] **Step 4: Sign-off**

The user confirms in writing: "The Rally Car feels good on asphalt, dirt and mud on the phone." Add that sentence and the date to the feel log.

- [ ] **Step 5: Lock the approved feel into the scenario tests**

Run: `./run_tests.sh scenarios` and read the printed `0-100 km/h` and `braking 100-0 km/h` values. In `tests/scenarios/feel_baseline.gd`:
- Set `ZERO_TO_HUNDRED_MIN/MAX` to the measured time × 0.9 and × 1.1.
- Set `BRAKING_FROM_HUNDRED_MIN/MAX` to the measured distance × 0.9 and × 1.1.
- Update the comment at the top to: `Narrowed on <date> around the approved tune: 0-100 <t> s, braking <d> m.`

Run: `./run_tests.sh all`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add car surfaces tests/scenarios/feel_baseline.gd docs/notes/feel-log.md
git commit -m "Lock in approved Milestone 1 feel baseline"
```

Milestone 1 is complete. Milestone 2 (trail builder, Rally Road, Muddy Valley, checkpoints and resets, run clock, stars, results, level select, pause menu, save data) gets its own plan.
