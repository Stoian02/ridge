# Milestone 3 Part B — Surface Feedback and Sound Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the ground readable by eye and ear:
- wheel spray: mud clods, dirt dust, asphalt tyre smoke
- synthesized car sound: engine, tyres and surfaces, impacts
- level ambience
- a Sound setting

The car's physics must not change.

**Architecture:**
- **Look and sound per surface:** a `SurfaceFeelTable` resource maps each surface id to a `SurfaceFeel`, like the grip table. The surface files stay untouched.
- **Pure rules:** small static classes (`SprayLogic`, `EngineSoundLogic`, `TyreSoundLogic`, `ImpactLogic`, `WheelMotion`) turn wheel state into spray strengths and sound levels.
- **Sounds:** `SoundSynth` builds every sound in code once per session.
- **Nodes:** `DrivingRig` adds a `CarEffects` node (one `WheelSpray` per wheel) and a `CarAudio` node. Levels get a `LevelAmbience` node. Both only read the car.

**Tech Stack:** Godot 4.7.2 (Mobile renderer, Jolt physics at 120 ticks/s), typed GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-09-15-m3b-surface-feedback-and-sound-design.md`

## Global Constraints

- **Typed GDScript:** every variable has a type or is inferred with `:=`. A value read out of a Dictionary has no type, so give its variable one (`var off: float = layers["low_volume"]`). A loop over an array literal names its type (`for side: float in [...]`). Indent with tabs. Doc comments use `##`.
- **No physics changes:**
  - never edit anything under `car/` or `surfaces/`
  - effects run in `_process` and only read the car
  - every existing test and scenario number must stay the same
- **No sound files:** every sound is synthesized by `SoundSynth`.
- **Tests:**
  - Run `./run_tests.sh unit`, `./run_tests.sh scenarios` or `./run_tests.sh all`. A run fails on any failing test or any `SCRIPT ERROR`.
  - After adding a file with a new `class_name`, run `godot --headless --import` once before running tests.
  - Headless runs that play sound end with a "leaked at exit" WARNING. That is expected and is not a failure (spec §9.2).
  - The shell is zsh: write commands out in full.
- **Budgets:** < 150 draw calls on screen (Muddy Valley is at 131), level load < 3 s, building the sounds < 100 ms (spec §8).
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

The code below was written and run in a scratch clone before this plan was written. These choices refine the spec, which has been updated to match:

- **A tyre slides at 0.6 slip ratio, not 0.25.** Traction control lets the Rally Car's rear tyres slip 0.2–0.55 for about 2.5 s on a full-throttle asphalt launch. At 0.25 every start poured smoke from all four wheels and squealed. Sideways sliding still starts at 12°.
- **Spray strength scales opacity and throw speed.** `CPUParticles3D` has no `amount_ratio` in 4.7, and changing `amount` restarts the emitter.
- **Sounds build in about 68 ms,** so the build limit is 100 ms. This runs once per session.
- **Players pause with the game.** A probe showed that `AudioStreamPlayer`s under a paused tree pause and resume by themselves, so the pause menu needs no sound code.
- **An idle spray costs no draw call.** A probe showed that a `CPUParticles3D` keeps its draw call after its particles die, until it is hidden. `WheelSpray` hides itself once it has been idle for longer than its particle lifetime.
- **The "leaked at exit" warning is not ours.** Freeing a playing sound and quitting one frame later leaks the same way in a bare probe with no project code. Stopping players in `_exit_tree` did not change that warning. **But the stops are needed:** without them the full suite hung twice at the same point, at the start of the new cars' Muddy Valley test in `test_cars.gd`. With them it passes (435 + 1 pending after Task 4). The Task 4 code below predates this finding; the stops were added in a fix commit after Task 4.

## Verified results (scratch clone, desktop)

| Check | Result |
|---|---|
| Full suite (`./run_tests.sh all`) | 440 passing, 1 pending (the known held-gas jump test) |
| Physics unchanged | Rally Road 1:30.3 / 1:26.3 / 1:40.5 and Muddy Valley 1:38.2 / 1:34.9, as on master; mud climb 16.6 s alone, 16.5 s in the full suite, on both |
| Mud from rest, full throttle | 4 wheels throw clods; mud sound 0.53 |
| Dirt at speed | 4 wheels throw dust; gravel sound 0.80 |
| Asphalt, steady 56 km/h cruise | no smoke, road sound 0.72, no squeal |
| Asphalt at full lock | 4 wheels smoke; squeal 0.69 |
| Engine | idle 1000 rpm, low-layer pitch 0.67; 7200 rpm, high-layer pitch 1.60 |
| Landings | a 2.5 m drop thumps; a reset does not |
| Building every sound | about 68 ms, once per session |
| Render (car at rest) | Muddy Valley 560 m: 131 draw calls, 319,060 primitives, build 2.10 s; Rally Road 15 m: 127 draw calls, build 1.35 s (draw calls unchanged, builds +0.05 s) |

## File map

| File | Task | What it is |
|---|---|---|
| `effects/surface_feel.gd`, `effects/surface_feel_table.gd`, `effects/surface_feel_table.tres` | 1 | How each surface looks and sounds |
| `effects/spray_logic.gd`, `effects/engine_sound_logic.gd`, `effects/tyre_sound_logic.gd`, `effects/impact_logic.gd`, `effects/wheel_motion.gd` | 1 | Pure rules |
| `tests/unit/test_surface_feels.gd` | 1 | Tests for the table and the rules |
| `effects/sound_synth.gd`, `tests/unit/test_sound_synth.gd` | 2 | Every sound, synthesized |
| `game/progress.gd`, `game/game_state.gd`, `ui/pause_menu.gd` and their tests | 3 | The Sound setting |
| `effects/wheel_spray.gd`, `effects/car_effects.gd`, `effects/car_audio.gd`, `effects/level_ambience.gd`, `levels/shared/driving_rig.gd`, the three level scenes, `tests/unit/test_car_feedback.gd` | 4 | The nodes, wired into the rig and levels |
| `tests/scenarios/test_car_feedback.gd`, `docs/notes/performance-m3b.md` | 5 | A real car on the Test Ground, and measured notes |

---

### Task 1: How surfaces look and sound, and the pure rules

**Files:**
- Create: `effects/surface_feel.gd`, `effects/surface_feel_table.gd`, `effects/surface_feel_table.tres`, `effects/spray_logic.gd`, `effects/engine_sound_logic.gd`, `effects/tyre_sound_logic.gd`, `effects/impact_logic.gd`, `effects/wheel_motion.gd`
- Test: `tests/unit/test_surface_feels.gd`

**Interfaces:**
- Consumes: `SurfaceDef.id`; `Wheel` (`in_contact`, `contact_point`, `contact_normal`, `steer_angle`, `spin_speed`, `slip_ratio`, `slip_angle`, `stats.wheel_radius`); `Car` (`linear_velocity`, `angular_velocity`, `global_basis`, `global_position`).
- Produces:
  - `SurfaceFeel` with enums `SprayKind { NONE, CLODS, DUST, SMOKE }` and `RollingSound { NONE, ROAD, GRAVEL, MUD }`, and fields `spray`, `spray_color`, `rolling`, `skids`
  - `SurfaceFeelTable.feel_for(surface: SurfaceDef) -> SurfaceFeel`, and `fallback`
  - `SprayLogic.intensity(kind, ground_speed, slip_speed, sliding) -> float`, and `SprayLogic.THRESHOLD`
  - `EngineSoundLogic.layers(rpm, throttle, shifting) -> Dictionary` (`low_pitch`, `low_volume`, `high_pitch`, `high_volume`)
  - `TyreSoundLogic.mix(wheels: Array[Dictionary]) -> Dictionary` (`road`, `gravel`, `mud`, `skid`)
  - `ImpactLogic.strength(compression_speed, bottomed_out) -> float`, and `ImpactLogic.is_bottomed_out(compression, travel) -> bool`
  - `WheelMotion.of(wheel, car) -> Dictionary` and `WheelMotion.motion(in_contact, velocity, normal, forward, tread_speed, slip_ratio, slip_angle) -> Dictionary`, both with keys `in_contact`, `ground_speed`, `slip_speed`, `sliding`

- [ ] **Step 1: Write the failing tests.**

`tests/unit/test_surface_feels.gd`:

```gdscript
extends GutTest
## How each surface looks and sounds (spec §3), and the pure rules for spray,
## engine, tyres and impacts (spec §4.1, §5.2-5.4).

const FEELS := preload("res://effects/surface_feel_table.tres")
const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")
const DAMP_DIRT := preload("res://levels/muddy_valley/damp_dirt.tres")
const SOFT_MUD := preload("res://levels/muddy_valley/soft_mud.tres")


func _feel(surface: SurfaceDef) -> SurfaceFeel:
	return FEELS.feel_for(surface)


func test_every_shipped_surface_has_its_feel() -> void:
	assert_eq(_feel(ASPHALT).spray, SurfaceFeel.SprayKind.SMOKE)
	assert_eq(_feel(ASPHALT).rolling, SurfaceFeel.RollingSound.ROAD)
	assert_true(_feel(ASPHALT).skids, "tyres squeal on asphalt")
	for surface: SurfaceDef in [DIRT, DAMP_DIRT]:
		assert_eq(_feel(surface).spray, SurfaceFeel.SprayKind.DUST, surface.id)
		assert_eq(_feel(surface).rolling, SurfaceFeel.RollingSound.GRAVEL, surface.id)
		assert_false(_feel(surface).skids, surface.id)
	for surface: SurfaceDef in [MUD, SOFT_MUD]:
		assert_eq(_feel(surface).spray, SurfaceFeel.SprayKind.CLODS, surface.id)
		assert_eq(_feel(surface).rolling, SurfaceFeel.RollingSound.MUD, surface.id)


func test_an_unknown_surface_gets_the_fallback_and_the_air_gets_none() -> void:
	var gravel := SurfaceDef.new()
	gravel.id = &"gravel_pit"
	assert_eq(_feel(gravel), FEELS.fallback)
	assert_null(_feel(null))


func test_clods_grow_with_wheelspin_and_speed() -> void:
	var kind := SurfaceFeel.SprayKind.CLODS
	assert_eq(SprayLogic.intensity(kind, 0.0, 0.0, false), 0.0, "a still wheel throws nothing")
	assert_gt(SprayLogic.intensity(kind, 0.0, 3.0, false), 0.4, "wheelspin alone throws mud")
	assert_gt(SprayLogic.intensity(kind, 0.0, 6.0, false), SprayLogic.intensity(kind, 0.0, 3.0, false))
	assert_gt(SprayLogic.intensity(kind, 15.0, 0.0, false), 0.4, "speed alone throws some")
	assert_eq(SprayLogic.intensity(kind, 40.0, 40.0, true), 1.0, "capped at 1")


func test_dust_needs_speed_and_smoke_needs_a_slide() -> void:
	assert_eq(SprayLogic.intensity(SurfaceFeel.SprayKind.DUST, 2.0, 0.0, false), 0.0, "no dust at a walking pace")
	assert_gt(SprayLogic.intensity(SurfaceFeel.SprayKind.DUST, 15.0, 0.0, false),
			SprayLogic.intensity(SurfaceFeel.SprayKind.DUST, 8.0, 0.0, false))
	assert_eq(SprayLogic.intensity(SurfaceFeel.SprayKind.SMOKE, 20.0, 5.0, false), 0.0, "no smoke without a slide")
	assert_gt(SprayLogic.intensity(SurfaceFeel.SprayKind.SMOKE, 20.0, 5.0, true), 0.5)
	assert_eq(SprayLogic.intensity(SurfaceFeel.SprayKind.NONE, 20.0, 5.0, true), 0.0)


func test_engine_pitch_follows_rpm_and_the_layers_cross_fade() -> void:
	var idle := EngineSoundLogic.layers(900.0, 0.0, false)
	var high := EngineSoundLogic.layers(6000.0, 1.0, false)
	assert_gt(high["low_pitch"], idle["low_pitch"])
	assert_gt(high["high_pitch"], idle["high_pitch"])
	assert_gt(idle["low_volume"], 0.3, "the low layer carries idle")
	assert_almost_eq(idle["high_volume"], 0.0, 0.001)
	assert_almost_eq(high["low_volume"], 0.0, 0.001)
	assert_gt(high["high_volume"], 0.9, "the high layer carries a full-throttle redline")
	for key: String in ["low_pitch", "high_pitch"]:
		assert_between(EngineSoundLogic.layers(300.0, 0.0, false)[key], 0.5, 2.0)
		assert_between(EngineSoundLogic.layers(9000.0, 0.0, false)[key], 0.5, 2.0)


func test_throttle_makes_the_engine_louder_and_a_shift_dips_it() -> void:
	var off: float = EngineSoundLogic.layers(1500.0, 0.0, false)["low_volume"]
	var on: float = EngineSoundLogic.layers(1500.0, 1.0, false)["low_volume"]
	var shifting: float = EngineSoundLogic.layers(1500.0, 1.0, true)["low_volume"]
	assert_gt(on, off)
	assert_lt(shifting, on)


func _wheel(surface: SurfaceDef, ground_speed: float, slip_speed := 0.0, sliding := false) -> Dictionary:
	return {"feel": _feel(surface), "ground_speed": ground_speed, "slip_speed": slip_speed, "sliding": sliding}


func test_each_surface_feeds_its_own_rolling_sound() -> void:
	var dirt_mix := TyreSoundLogic.mix([_wheel(DIRT, 20.0), _wheel(DIRT, 20.0), _wheel(DIRT, 20.0), _wheel(DIRT, 20.0)])
	assert_gt(dirt_mix["gravel"], 0.7)
	assert_eq(dirt_mix["mud"], 0.0)
	assert_eq(dirt_mix["road"], 0.0)
	var mud_mix := TyreSoundLogic.mix([_wheel(MUD, 2.0, 6.0), _wheel(MUD, 2.0, 6.0)])
	assert_gt(mud_mix["mud"], 0.3, "wheelspin in mud squelches even when slow")
	var air: Array[Dictionary] = [{"feel": null, "ground_speed": 30.0, "slip_speed": 10.0, "sliding": true}]
	assert_eq(TyreSoundLogic.mix(air), {"road": 0.0, "gravel": 0.0, "mud": 0.0, "skid": 0.0})


func test_only_sliding_on_asphalt_squeals_and_totals_are_capped() -> void:
	assert_eq(TyreSoundLogic.mix([_wheel(ASPHALT, 20.0, 1.0, false)])["skid"], 0.0)
	assert_gt(TyreSoundLogic.mix([_wheel(ASPHALT, 20.0, 4.0, true)])["skid"], 0.1)
	assert_eq(TyreSoundLogic.mix([_wheel(DIRT, 20.0, 4.0, true)])["skid"], 0.0, "no squeal on dirt")
	var eight: Array[Dictionary] = []
	for i in 8:
		eight.append(_wheel(MUD, 40.0, 40.0, true))
	assert_eq(TyreSoundLogic.mix(eight)["mud"], 1.0)


func test_impacts_count_only_hard_hits_and_the_bump_stop() -> void:
	assert_eq(ImpactLogic.strength(0.5, false), 0.0, "an ordinary bump is silent")
	assert_gt(ImpactLogic.strength(3.0, false), ImpactLogic.strength(2.0, false))
	assert_eq(ImpactLogic.strength(10.0, false), 1.0)
	assert_gte(ImpactLogic.strength(0.0, true), 0.6, "bottoming out always thumps")
	assert_true(ImpactLogic.is_bottomed_out(0.32, 0.35))
	assert_false(ImpactLogic.is_bottomed_out(0.2, 0.35))


func test_wheel_motion_tells_rolling_from_spinning_and_sliding() -> void:
	var forward := Vector3(0.0, 0.0, -1.0)
	var rolling := WheelMotion.motion(true, Vector3(0.0, 0.0, -10.0), Vector3.UP, forward, 10.0, 0.0, 0.0)
	assert_almost_eq(rolling["ground_speed"], 10.0, 0.001)
	assert_almost_eq(rolling["slip_speed"], 0.0, 0.001)
	assert_false(rolling["sliding"])
	var spinning := WheelMotion.motion(true, Vector3.ZERO, Vector3.UP, forward, 8.0, 1.0, 0.0)
	assert_almost_eq(spinning["slip_speed"], 8.0, 0.001)
	assert_false(spinning["sliding"], "a burnout from rest isn't a slide")
	var sideways := WheelMotion.motion(true, Vector3(4.0, 0.0, -9.0), Vector3.UP, forward, 9.0, 0.0, deg_to_rad(20.0))
	assert_true(sideways["sliding"])
	var air := WheelMotion.motion(false, Vector3(0.0, 0.0, -10.0), Vector3.UP, forward, 10.0, 0.0, 0.0)
	assert_eq(air, {"in_contact": false, "ground_speed": 0.0, "slip_speed": 0.0, "sliding": false})
```

- [ ] **Step 2: Run them and see them fail.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_surface_feels.gd -gexit`
  Expected: SCRIPT ERROR (`SurfaceFeel`, `SprayLogic` and the other classes don't exist yet).

- [ ] **Step 3: Write the feel resource, its table and its data.**

`effects/surface_feel.gd`:

```gdscript
class_name SurfaceFeel
extends Resource
## How a surface looks and sounds under a wheel (spec §3): which spray it throws,
## in which colour, which rolling sound it makes, and whether sliding tyres squeal
## and smoke on it. Kept apart from SurfaceDef, whose values are physics.

enum SprayKind { NONE, CLODS, DUST, SMOKE }
enum RollingSound { NONE, ROAD, GRAVEL, MUD }

@export var spray: SprayKind = SprayKind.NONE
@export var spray_color: Color = Color(0.62, 0.52, 0.38)
@export var rolling: RollingSound = RollingSound.NONE
## Sliding tyres squeal (and, with SMOKE spray, smoke) on this surface.
@export var skids: bool = false
```

`effects/surface_feel_table.gd`:

```gdscript
class_name SurfaceFeelTable
extends Resource
## Surface id -> SurfaceFeel (spec §3.1), like GripTable does for grip. Surfaces
## without an entry use the fallback.

## StringName surface id -> SurfaceFeel.
@export var feels: Dictionary = {}
@export var fallback: SurfaceFeel


## The feel for `surface`: its entry, the fallback for an unknown id, or null with
## no surface (a wheel in the air).
func feel_for(surface: SurfaceDef) -> SurfaceFeel:
	if surface == null:
		return null
	var feel: SurfaceFeel = feels.get(surface.id)
	return feel if feel != null else fallback
```

`effects/surface_feel_table.tres`:

```ini
[gd_resource type="Resource" script_class="SurfaceFeelTable" format=3]

[ext_resource type="Script" path="res://effects/surface_feel_table.gd" id="1_table"]
[ext_resource type="Script" path="res://effects/surface_feel.gd" id="2_feel"]

[sub_resource type="Resource" id="Resource_asphalt"]
script = ExtResource("2_feel")
spray = 3
spray_color = Color(0.82, 0.82, 0.8, 1)
rolling = 1
skids = true

[sub_resource type="Resource" id="Resource_dirt"]
script = ExtResource("2_feel")
spray = 2
spray_color = Color(0.62, 0.52, 0.38, 1)
rolling = 2

[sub_resource type="Resource" id="Resource_mud"]
script = ExtResource("2_feel")
spray = 1
spray_color = Color(0.24, 0.17, 0.11, 1)
rolling = 3

[resource]
script = ExtResource("1_table")
feels = {
&"asphalt": SubResource("Resource_asphalt"),
&"damp_dirt": SubResource("Resource_dirt"),
&"dirt": SubResource("Resource_dirt"),
&"mud": SubResource("Resource_mud"),
&"soft_mud": SubResource("Resource_mud")
}
fallback = SubResource("Resource_dirt")
```

- [ ] **Step 4: Write the pure rules.**

`effects/spray_logic.gd`:

```gdscript
class_name SprayLogic
extends RefCounted
## How hard a wheel sprays (spec §4.1), from 0 to 1: mud clods from wheelspin and
## speed, dust from speed, and tyre smoke only while the tyre slides.

## Below this intensity a spray stops emitting.
const THRESHOLD := 0.05
const CLODS_SLIP := 6.0
const CLODS_SPEED_FROM := 3.0
const CLODS_SPEED_RANGE := 15.0
const CLODS_SPEED_SHARE := 0.5
const DUST_SPEED_FROM := 4.0
const DUST_SPEED_RANGE := 16.0
const DUST_SLIP := 10.0
const DUST_SLIP_SHARE := 0.4
const SMOKE_BASE := 0.3
const SMOKE_SLIP := 8.0


## ground_speed: how fast the contact point moves over the ground (m/s).
## slip_speed: the gap between tread speed and ground speed (m/s).
static func intensity(kind: SurfaceFeel.SprayKind, ground_speed: float, slip_speed: float, sliding: bool) -> float:
	match kind:
		SurfaceFeel.SprayKind.CLODS:
			return minf(clampf(slip_speed / CLODS_SLIP, 0.0, 1.0)
					+ clampf((ground_speed - CLODS_SPEED_FROM) / CLODS_SPEED_RANGE, 0.0, CLODS_SPEED_SHARE), 1.0)
		SurfaceFeel.SprayKind.DUST:
			return minf(clampf((ground_speed - DUST_SPEED_FROM) / DUST_SPEED_RANGE, 0.0, 1.0)
					+ clampf(slip_speed / DUST_SLIP, 0.0, DUST_SLIP_SHARE), 1.0)
		SurfaceFeel.SprayKind.SMOKE:
			return clampf(SMOKE_BASE + slip_speed / SMOKE_SLIP, 0.0, 1.0) if sliding else 0.0
	return 0.0
```

`effects/engine_sound_logic.gd`:

```gdscript
class_name EngineSoundLogic
extends RefCounted
## The engine sound's two layers (spec §5.2): a low loop recorded at 1500 rpm and a
## high loop at 4500 rpm, each pitched by rpm and cross-faded between 2000 and
## 4000 rpm. Throttle makes it louder; a gear shift dips it.

const LOW_RPM := 1500.0
const HIGH_RPM := 4500.0
const PITCH_MIN := 0.5
const PITCH_MAX := 2.0
const BLEND_FROM := 2000.0
const BLEND_TO := 4000.0
const BASE_VOLUME := 0.45
const THROTTLE_VOLUME := 0.55
const SHIFT_DIP := 0.6


## Returns {"low_pitch", "low_volume", "high_pitch", "high_volume"}; volumes are linear 0-1.
static func layers(rpm: float, throttle: float, shifting: bool) -> Dictionary:
	var blend := smoothstep(BLEND_FROM, BLEND_TO, rpm)
	var loudness := (BASE_VOLUME + THROTTLE_VOLUME * clampf(throttle, 0.0, 1.0)) * (SHIFT_DIP if shifting else 1.0)
	return {
		"low_pitch": clampf(rpm / LOW_RPM, PITCH_MIN, PITCH_MAX),
		"low_volume": (1.0 - blend) * loudness,
		"high_pitch": clampf(rpm / HIGH_RPM, PITCH_MIN, PITCH_MAX),
		"high_volume": blend * loudness,
	}
```

`effects/tyre_sound_logic.gd`:

```gdscript
class_name TyreSoundLogic
extends RefCounted
## How loud the tyre and surface sounds are (spec §5.3), from the four wheels:
## each wheel on the ground adds to its surface's rolling sound, mud also by
## wheelspin, and a sliding tyre on a skidding surface adds to the squeal.

## One wheel's share of each sound.
const WHEEL_SHARE := 0.25
const ROLL_SPEED := 25.0
const MUD_SLIP := 8.0
const SKID_BASE := 0.3
const SKID_SLIP := 10.0


## wheels: one Dictionary per wheel with "feel" (SurfaceFeel or null in the air),
## "ground_speed", "slip_speed" and "sliding". Returns {"road", "gravel", "mud", "skid"}, each 0-1.
static func mix(wheels: Array[Dictionary]) -> Dictionary:
	var result := {"road": 0.0, "gravel": 0.0, "mud": 0.0, "skid": 0.0}
	for wheel in wheels:
		var feel: SurfaceFeel = wheel["feel"]
		if feel == null:
			continue
		var ground_speed: float = wheel["ground_speed"]
		var slip_speed: float = wheel["slip_speed"]
		var rolling := clampf(ground_speed / ROLL_SPEED, 0.0, 1.0) * WHEEL_SHARE
		match feel.rolling:
			SurfaceFeel.RollingSound.ROAD:
				result["road"] += rolling
			SurfaceFeel.RollingSound.GRAVEL:
				result["gravel"] += rolling
			SurfaceFeel.RollingSound.MUD:
				result["mud"] += rolling + clampf(slip_speed / MUD_SLIP, 0.0, 1.0) * WHEEL_SHARE
		if feel.skids and wheel["sliding"]:
			result["skid"] += clampf(SKID_BASE + slip_speed / SKID_SLIP, 0.0, 1.0) * WHEEL_SHARE
	for key: String in result:
		result[key] = minf(result[key], 1.0)
	return result
```

`effects/impact_logic.gd`:

```gdscript
class_name ImpactLogic
extends RefCounted
## How hard a wheel hit something (spec §5.4), from 0 to 1: the suspension
## compressing fast, or reaching the bump stop.

const SOFT_SPEED := 1.2
const SPEED_RANGE := 3.0
const BOTTOMED_SHARE := 0.85
const BOTTOMED_STRENGTH := 0.6


## compression_speed: m/s, + while compressing.
static func strength(compression_speed: float, bottomed_out: bool) -> float:
	var hit := clampf((compression_speed - SOFT_SPEED) / SPEED_RANGE, 0.0, 1.0)
	return maxf(hit, BOTTOMED_STRENGTH) if bottomed_out else hit


## True when the wheel is within the last 15% of its travel.
static func is_bottomed_out(compression: float, travel: float) -> bool:
	return travel > 0.0 and compression > travel * BOTTOMED_SHARE
```

`effects/wheel_motion.gd`:

```gdscript
class_name WheelMotion
extends RefCounted
## How a wheel moves over the ground, for effects (spec §6.1). It only reads the
## wheel and the car; it never changes them.

## Tyres count as sliding only above this ground speed (m/s).
const SLIDE_MIN_SPEED := 3.0
## Well above traction control's 0.3 target: a full-throttle launch slips 0.2-0.55
## for a couple of seconds, and only clear wheelspin past this counts as a slide.
const SLIDE_SLIP_RATIO := 0.6
const SLIDE_SLIP_ANGLE_DEG := 12.0


## Returns {"in_contact", "ground_speed", "slip_speed", "sliding"} for a wheel of `car`.
static func of(wheel: Wheel, car: Car) -> Dictionary:
	if not wheel.in_contact:
		return motion(false, Vector3.ZERO, Vector3.UP, Vector3.FORWARD, 0.0, 0.0, 0.0)
	var velocity := car.linear_velocity + car.angular_velocity.cross(wheel.contact_point - car.global_position)
	var forward := (-car.global_basis.z).rotated(car.global_basis.y, -wheel.steer_angle)
	return motion(true, velocity, wheel.contact_normal, forward, wheel.spin_speed * wheel.stats.wheel_radius,
			wheel.slip_ratio, wheel.slip_angle)


## The same from plain values. velocity: of the contact point; forward: the wheel's heading;
## tread_speed: spin x radius (m/s); slip_angle in radians.
static func motion(in_contact: bool, velocity: Vector3, normal: Vector3, forward: Vector3, tread_speed: float,
		slip_ratio: float, slip_angle: float) -> Dictionary:
	if not in_contact:
		return {"in_contact": false, "ground_speed": 0.0, "slip_speed": 0.0, "sliding": false}
	var along_ground := velocity - normal * velocity.dot(normal)
	var ground_speed := along_ground.length()
	var heading := (forward - normal * forward.dot(normal)).normalized()
	var slip_speed := absf(tread_speed - along_ground.dot(heading))
	var sliding := ground_speed > SLIDE_MIN_SPEED and (absf(slip_ratio) > SLIDE_SLIP_RATIO
			or absf(slip_angle) > deg_to_rad(SLIDE_SLIP_ANGLE_DEG))
	return {"in_contact": true, "ground_speed": ground_speed, "slip_speed": slip_speed, "sliding": sliding}
```

- [ ] **Step 5: Run the tests.**
  Run: `godot --headless --import`, then the Step 2 command. Expected: 10 passing.
  Run: `./run_tests.sh unit`. Expected: exit 0.

- [ ] **Step 6: Commit.**
  ```bash
  git add effects/surface_feel.gd effects/surface_feel.gd.uid effects/surface_feel_table.gd effects/surface_feel_table.gd.uid effects/surface_feel_table.tres effects/spray_logic.gd effects/spray_logic.gd.uid effects/engine_sound_logic.gd effects/engine_sound_logic.gd.uid effects/tyre_sound_logic.gd effects/tyre_sound_logic.gd.uid effects/impact_logic.gd effects/impact_logic.gd.uid effects/wheel_motion.gd effects/wheel_motion.gd.uid tests/unit/test_surface_feels.gd tests/unit/test_surface_feels.gd.uid
  git commit -m "Describe how each surface looks and sounds, and the rules for spray and sound levels" -m "Co-Authored-By: Claude <model name> <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RhfJavT34eWyW3enLLKWgH"
  ```

---

### Task 2: Every sound, synthesized

**Files:**
- Create: `effects/sound_synth.gd`
- Test: `tests/unit/test_sound_synth.gd`

**Interfaces:**
- Produces:
  - `SoundSynth.sound(sound_name: StringName) -> AudioStreamWAV`
  - `SoundSynth.NAMES`: `engine_low`, `engine_high`, `road`, `gravel`, `mud`, `skid`, `wind`, `bird`, `thump`
  - `SoundSynth.RATE` (22050) and `SoundSynth.clear_cache()`

- [ ] **Step 1: Write the failing tests.**

`tests/unit/test_sound_synth.gd`:

```gdscript
extends GutTest
## Every synthesized sound (spec §5.1): right length and loop mode, audible but
## not clipped, loops that join without a click, cached, and quick to build.

const LOOP_SECONDS := {&"engine_low": 0.4, &"engine_high": 0.4, &"road": 1.0, &"gravel": 1.0, &"mud": 1.5,
		&"skid": 0.8, &"wind": 4.0}
const ONE_SHOT_SECONDS := {&"bird": 0.35, &"thump": 0.3}


func _samples(wav: AudioStreamWAV) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(wav.data.size() / 2)
	for i in samples.size():
		samples[i] = wav.data.decode_s16(i * 2) / 32767.0
	return samples


func test_every_sound_builds_quickly_from_scratch() -> void:
	SoundSynth.clear_cache()
	var started := Time.get_ticks_usec()
	for sound_name in SoundSynth.NAMES:
		assert_not_null(SoundSynth.sound(sound_name), sound_name)
	var milliseconds := (Time.get_ticks_usec() - started) / 1000.0
	gut.p("building every sound: %.1f ms" % milliseconds)
	assert_lt(milliseconds, 300.0, "spec §8 aims for 60 ms on desktop; this bound only catches runaways")


func test_sounds_have_their_length_and_loop_mode() -> void:
	for sound_name: StringName in LOOP_SECONDS:
		var wav := SoundSynth.sound(sound_name)
		assert_eq(wav.mix_rate, SoundSynth.RATE, sound_name)
		assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS, sound_name)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, sound_name)
		assert_almost_eq(wav.get_length(), LOOP_SECONDS[sound_name], 0.01, sound_name)
		assert_eq(wav.loop_end, wav.data.size() / 2, sound_name)
	for sound_name: StringName in ONE_SHOT_SECONDS:
		var wav := SoundSynth.sound(sound_name)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, sound_name)
		assert_almost_eq(wav.get_length(), ONE_SHOT_SECONDS[sound_name], 0.01, sound_name)


func test_sounds_are_audible_and_not_clipped() -> void:
	for sound_name in SoundSynth.NAMES:
		var samples := _samples(SoundSynth.sound(sound_name))
		var peak := 0.0
		var energy := 0.0
		for value in samples:
			peak = maxf(peak, absf(value))
			energy += value * value
		var rms := sqrt(energy / samples.size())
		assert_between(peak, 0.5, 0.95, "%s peak" % sound_name)
		assert_gt(rms, 0.03, "%s is audible" % sound_name)


func test_loops_join_without_a_click() -> void:
	for sound_name: StringName in LOOP_SECONDS:
		var samples := _samples(SoundSynth.sound(sound_name))
		var biggest_step := 0.0
		for i in range(1, samples.size()):
			biggest_step = maxf(biggest_step, absf(samples[i] - samples[i - 1]))
		var join := absf(samples[0] - samples[samples.size() - 1])
		assert_lte(join, biggest_step * 1.05, "%s: the join is no bigger a step than the loop's own" % sound_name)


func test_a_sound_is_built_once() -> void:
	assert_same(SoundSynth.sound(&"road"), SoundSynth.sound(&"road"))
```

- [ ] **Step 2: Run them and see them fail.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_sound_synth.gd -gexit`
  Expected: SCRIPT ERROR (`SoundSynth` doesn't exist yet).

- [ ] **Step 3: Write the synthesizer.**

`effects/sound_synth.gd`:

```gdscript
class_name SoundSynth
extends RefCounted
## Every sound in the game, synthesized in code (spec §5.1): 16-bit mono at
## 22 050 Hz, built the first time it is asked for and kept for the session.
## Tone loops hold whole cycles; noise loops cross-fade their end into their start,
## so every loop repeats without a click.

const RATE := 22050
## Loops are normalized to this peak, one-shots to ONE_SHOT_PEAK.
const LOOP_PEAK := 0.7
const ONE_SHOT_PEAK := 0.9
## Noise loops cross-fade over this long (s).
const FADE_SECONDS := 0.1
const NAMES: Array[StringName] = [&"engine_low", &"engine_high", &"road", &"gravel", &"mud", &"skid", &"wind",
		&"bird", &"thump"]

static var _cache := {}


## The sound called `sound_name` (one of NAMES).
static func sound(sound_name: StringName) -> AudioStreamWAV:
	if not _cache.has(sound_name):
		_cache[sound_name] = _build(sound_name)
	return _cache[sound_name]


## Forgets every built sound, so the next request builds it again (tests time the build).
static func clear_cache() -> void:
	_cache.clear()


static func _build(sound_name: StringName) -> AudioStreamWAV:
	match sound_name:
		&"engine_low":
			return _wav(_normalized(_engine(50.0, 0.7, 11), LOOP_PEAK), true)
		&"engine_high":
			return _wav(_normalized(_engine(150.0, 1.0, 12), LOOP_PEAK), true)
		&"road":
			return _wav(_normalized(_seamless(_road(1.0)), LOOP_PEAK), true)
		&"gravel":
			return _wav(_normalized(_seamless(_gravel(1.0)), LOOP_PEAK), true)
		&"mud":
			return _wav(_normalized(_seamless(_mud(1.5)), LOOP_PEAK), true)
		&"skid":
			return _wav(_normalized(_seamless(_skid(0.8)), LOOP_PEAK), true)
		&"wind":
			return _wav(_normalized(_seamless(_wind(4.0)), LOOP_PEAK), true)
		&"bird":
			return _wav(_normalized(_bird(), ONE_SHOT_PEAK), false)
		&"thump":
			return _wav(_normalized(_thump(), ONE_SHOT_PEAK), false)
	push_error("SoundSynth: no sound called %s" % sound_name)
	return null


## A four-cylinder engine tone: firing frequency with harmonics, a half-order rumble,
## and a little roughness that changes cycle to cycle. Holds 0.4 s of whole cycles.
static func _engine(firing_hz: float, brightness: float, seed: int) -> PackedFloat32Array:
	var cycle := roundi(RATE / firing_hz)
	var cycles := roundi(0.4 * firing_hz / 2.0) * 2
	var rng := _rng(seed)
	var roughness := PackedFloat32Array()
	for c in cycles:
		roughness.append(1.0 + rng.randf_range(-0.15, 0.15))
	var samples := PackedFloat32Array()
	samples.resize(cycle * cycles)
	for i in samples.size():
		var phase := float(i) / cycle
		var index := int(phase)
		var amplitude := lerpf(roughness[index], roughness[(index + 1) % cycles], phase - index)
		var w := TAU * phase
		samples[i] = amplitude * (sin(w) + 0.6 * brightness * sin(2.0 * w) + 0.35 * brightness * sin(3.0 * w)
				+ 0.2 * brightness * brightness * sin(4.0 * w) + 0.45 * sin(0.5 * w))
	return samples


static func _road(seconds: float) -> PackedFloat32Array:
	var rng := _rng(21)
	var samples := _padded(seconds)
	var low := 0.0
	for i in samples.size():
		low += 0.08 * (rng.randf_range(-1.0, 1.0) - low)
		samples[i] = low
	return samples


static func _gravel(seconds: float) -> PackedFloat32Array:
	var rng := _rng(22)
	var samples := _padded(seconds)
	var low := 0.0
	var smooth := 0.0
	for i in samples.size():
		var noise := rng.randf_range(-1.0, 1.0)
		low += 0.3 * (noise - low)
		smooth += 0.5 * ((noise - low) - smooth)
		samples[i] = smooth
	# Crackles, kept clear of the cross-faded ends.
	var fade := _fade_samples()
	for click in 70:
		var at := rng.randi_range(fade, samples.size() - fade * 2)
		var sign := 1.0 if rng.randf() < 0.5 else -1.0
		for k in 50:
			samples[at + k] += sign * 0.9 * exp(-k / 8.0) * (1.0 if k % 2 == 0 else -0.6)
	return samples


static func _mud(seconds: float) -> PackedFloat32Array:
	var rng := _rng(23)
	var samples := _padded(seconds)
	var bubbles := PackedFloat32Array()
	for b in 16:
		bubbles.append(rng.randf_range(0.0, seconds))
	var low := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var swell := 0.35
		for at in bubbles:
			swell += exp(-pow((t - at) / 0.05, 2.0))
		low += 0.035 * (rng.randf_range(-1.0, 1.0) - low)
		samples[i] = low * swell + 0.25 * sin(TAU * 38.0 * t) * (swell - 0.35)
	return samples


static func _skid(seconds: float) -> PackedFloat32Array:
	var rng := _rng(24)
	var samples := _padded(seconds)
	var phase := 0.0
	var low := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += TAU * (900.0 + 45.0 * sin(TAU * 7.0 * t)) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += 0.4 * (noise - low)
		samples[i] = sin(phase) * 0.8 + sin(phase * 2.0) * 0.2 + (noise - low) * 0.3
	return samples


static func _wind(seconds: float) -> PackedFloat32Array:
	var rng := _rng(25)
	var samples := _padded(seconds)
	var low := 0.0
	var lower := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		low += 0.02 * (rng.randf_range(-1.0, 1.0) - low)
		lower += 0.05 * (low - lower)
		samples[i] = lower * (0.65 + 0.35 * sin(TAU * t / seconds))
	return samples


static func _bird() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.35 * RATE))
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		for start: float in [0.0, 0.17]:
			var u := (t - start) / 0.12
			if u >= 0.0 and u <= 1.0:
				phase += TAU * lerpf(2500.0, 4200.0, u) / RATE
				samples[i] += sin(phase) * sin(PI * u)
	return samples


static func _thump() -> PackedFloat32Array:
	var rng := _rng(26)
	var samples := PackedFloat32Array()
	samples.resize(int(0.3 * RATE))
	var phase := 0.0
	var low := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(70.0, 40.0, t / 0.3) / RATE
		low += 0.2 * (rng.randf_range(-1.0, 1.0) - low)
		samples[i] = sin(phase) * exp(-t * 14.0) + low * 0.8 * exp(-t * 40.0)
	return samples


static func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


static func _fade_samples() -> int:
	return int(FADE_SECONDS * RATE)


## Room for `seconds` of loop plus the cross-fade tail.
static func _padded(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE) + _fade_samples())
	return samples


## Folds the tail past the loop length into the start, so the end runs straight on into the start.
static func _seamless(samples: PackedFloat32Array) -> PackedFloat32Array:
	var fade := _fade_samples()
	var length := samples.size() - fade
	var result := samples.slice(0, length)
	for i in fade:
		result[i] = lerpf(samples[length + i], samples[i], float(i) / fade)
	return result


static func _normalized(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var loudest := 0.0
	for value in samples:
		loudest = maxf(loudest, absf(value))
	if loudest <= 0.0:
		return samples
	var result := samples.duplicate()
	for i in result.size():
		result[i] = samples[i] * peak / loudest
	return result


static func _wav(samples: PackedFloat32Array, looping: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
```

- [ ] **Step 4: Run the tests.**
  Run: `godot --headless --import`, then the Step 2 command.
  Expected: 5 passing. It prints "building every sound: … ms"; the scratch clone measured about 68 ms.
  Run: `./run_tests.sh unit`. Expected: exit 0.

- [ ] **Step 5: Commit.**
  ```bash
  git add effects/sound_synth.gd effects/sound_synth.gd.uid tests/unit/test_sound_synth.gd tests/unit/test_sound_synth.gd.uid
  git commit -m "Synthesize the engine, tyre, surface, ambience and impact sounds in code" -m "Co-Authored-By: Claude <model name> <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RhfJavT34eWyW3enLLKWgH"
  ```

---

### Task 3: The Sound setting

**Files:**
- Modify: `game/progress.gd`, `game/game_state.gd`, `ui/pause_menu.gd`
- Test: `tests/unit/test_progress.gd`, `tests/unit/test_game_state.gd`, `tests/unit/test_pause_menu.gd` (append a test to each)

**Interfaces:**
- Produces:
  - `Progress.sound_volume: float` (default 1.0), saved as `settings.sound_volume`
  - `Progress.SOUND_STEPS: Array[float]` = `[1.0, 0.75, 0.5, 0.25, 0.0]`
  - `GameState.set_sound_volume(value: float)` and `GameState.apply_sound_volume()`; `reload()` applies the setting
  - a pause menu button whose text starts with "Sound"

- [ ] **Step 1: Write the failing tests.** Append to the end of `tests/unit/test_progress.gd`:

```gdscript


func test_the_sound_setting_is_saved_and_only_takes_its_steps() -> void:
	assert_eq(progress.sound_volume, 1.0)
	progress.sound_volume = 0.25
	assert_eq(Progress.from_dictionary(progress.to_dictionary()).sound_volume, 0.25)
	assert_eq(Progress.from_dictionary({"settings": {"sound_volume": 0}}).sound_volume, 0.0, "JSON may give an int")
	assert_eq(Progress.from_dictionary({"settings": {"sound_volume": 0.3}}).sound_volume, 1.0, "not a step")
	assert_eq(Progress.from_dictionary({"settings": {"sound_volume": "loud"}}).sound_volume, 1.0)
	assert_eq(Progress.from_dictionary({"settings": {"steer_mode": "analog"}}).sound_volume, 1.0, "an older save")
```

  Append to the end of `tests/unit/test_game_state.gd`:

```gdscript


func test_the_sound_setting_sets_the_master_bus_and_is_saved() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	state.set_sound_volume(0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(master), linear_to_db(0.5), 0.01)
	assert_false(AudioServer.is_bus_mute(master))
	assert_eq(SaveSystem.read(SaveSandbox.PATH)["settings"]["sound_volume"], 0.5)
	state.set_sound_volume(0.0)
	assert_true(AudioServer.is_bus_mute(master), "Off mutes")
	state.reload()
	assert_true(AudioServer.is_bus_mute(master), "a reload applies the saved setting")
	state.set_sound_volume(1.0)
	assert_false(AudioServer.is_bus_mute(master))
```

  In `tests/unit/test_pause_menu.gd`, insert this directly above the line `func test_telemetry_and_rec_show_their_state() -> void:`:

```gdscript
func test_sound_steps_down_to_off_and_back_and_saves() -> void:
	_add_menu()
	menu.open()
	var sound := _button_starting("Sound")
	assert_eq(sound.text, "Sound: 100%")
	var labels: Array[String] = []
	for i in 5:
		sound.pressed.emit()
		labels.append(sound.text)
	assert_eq(labels, ["Sound: 75%", "Sound: 50%", "Sound: 25%", "Sound: Off", "Sound: 100%"])
	sound.pressed.emit()
	assert_eq(SaveSystem.read(SaveSandbox.PATH)["settings"]["sound_volume"], 0.75)
```

- [ ] **Step 2: Run them and see them fail.**
  Run the three files with `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<file>.gd -gexit`.
  Expected: the three new tests fail with SCRIPT ERRORs (no `sound_volume`, no `set_sound_volume`, no Sound button).

- [ ] **Step 3: Progress.**
  - In `game/progress.gd`, directly below the line `var selected_car: String = DEFAULT_CAR`, add:

```gdscript
## The Sound setting (M3B spec §7): one of SOUND_STEPS, 0 = off.
var sound_volume: float = 1.0

## The values the Sound setting steps through, loudest first.
const SOUND_STEPS: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]
```

  - Replace the `return {"version": VERSION, "settings": ...}` line at the end of `to_dictionary()` with:

```gdscript
	return {"version": VERSION, "settings": {"steer_mode": steer_mode, "selected_car": selected_car,
			"sound_volume": sound_volume}, "levels": levels}
```

  - In `from_dictionary`, directly below the two lines `if car_id is String and car_id != "":` and `progress.selected_car = car_id`, add:

```gdscript
	var volume = settings.get("sound_volume") if settings is Dictionary else null
	if _is_number(volume) and SOUND_STEPS.has(float(volume)):
		progress.sound_volume = float(volume)
```

- [ ] **Step 4: GameState.**
  - In `game/game_state.gd`, replace the doc comment and body of `reload()` with:

```gdscript
## Reads progress from save_path, replacing what is in memory, and applies its Sound setting.
func reload() -> void:
	progress = Progress.from_dictionary(SaveSystem.read(save_path))
	apply_sound_volume()
```

  - Directly below `set_steer_mode()` (after its `save()` line), add:

```gdscript


## The Sound setting (M3B spec §7): stores, applies and saves it.
func set_sound_volume(value: float) -> void:
	progress.sound_volume = clampf(value, 0.0, 1.0)
	apply_sound_volume()
	save()


## Sets the Master bus from the Sound setting; 0 mutes it.
func apply_sound_volume() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(master, progress.sound_volume <= 0.0)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(progress.sound_volume, 0.0001)))
```

- [ ] **Step 5: Pause menu.**
  - In `ui/pause_menu.gd`, directly below `var _steering: Button`, add:

```gdscript
var _sound: Button
```

  - Directly above `func _on_telemetry() -> void:`, add:

```gdscript
## Steps the Sound setting to the next quieter step, wrapping from Off to 100%.
func _on_sound() -> void:
	var steps := Progress.SOUND_STEPS
	var index := steps.find(GameState.progress.sound_volume)
	GameState.set_sound_volume(steps[(index + 1) % steps.size()])
	_refresh_labels()
```

  - At the start of `_refresh_labels()`, above its `if rig == null:` line, add:

```gdscript
	var volume := GameState.progress.sound_volume
	_sound.text = "Sound: %s" % ("Off" if volume <= 0.0 else "%d%%" % roundi(volume * 100.0))
```

  - In `_build_ui()`, directly below `column.add_child(_steering)`, add:

```gdscript
	_sound = UiKit.button("Sound", _on_sound)
	column.add_child(_sound)
```

- [ ] **Step 6: Run the tests.**
  Run the Step 2 commands. Expected: `test_progress` 14 passing, `test_game_state` 11, `test_pause_menu` 10.
  Run: `./run_tests.sh unit`. Expected: exit 0.

- [ ] **Step 7: Commit.**
  ```bash
  git add game/progress.gd game/game_state.gd ui/pause_menu.gd tests/unit/test_progress.gd tests/unit/test_game_state.gd tests/unit/test_pause_menu.gd
  git commit -m "Add a Sound setting to the pause menu, saved with the other settings" -m "Co-Authored-By: Claude <model name> <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RhfJavT34eWyW3enLLKWgH"
  ```

---

### Task 4: Sprays and sound on the car, and level ambience

**Files:**
- Create: `effects/wheel_spray.gd`, `effects/car_effects.gd`, `effects/car_audio.gd`, `effects/level_ambience.gd`
- Modify: `levels/shared/driving_rig.gd`, `levels/rally_road/rally_road.tscn`, `levels/muddy_valley/muddy_valley.tscn`, `levels/test_ground/test_ground.tscn`
- Test: `tests/unit/test_car_feedback.gd`

**Interfaces:**
- Consumes: everything from Tasks 1 and 2.
- Produces:
  - `WheelSpray` (`CPUParticles3D`): `update(feel, strength, delta)`, `stop_now()`, `kind`
  - `CarEffects` (`Node3D`): `setup(car)`, `sprays: Array[WheelSpray]`, `notify_reset()`
  - `CarAudio` (`Node`): `setup(car)`, `LOOPS`, `players`, `volume(sound_name) -> float`, `thumps_played`, `notify_reset()`, `impacts_muted() -> bool`
  - `LevelAmbience` (`Node`): exports `wind_volume`, `birds`, `bird_interval`, `seed`; `wind`, `bird`, `birds_played`
  - `DrivingRig.effects` and `DrivingRig.audio`

- [ ] **Step 1: Write the failing tests.**

`tests/unit/test_car_feedback.gd`:

```gdscript
extends GutTest
## The spray and sound nodes (M3B spec §4.2, §5.5, §5.6, §6): a wheel spray
## switches and hides itself, the driving rig carries the car's effects and sound,
## a reset quiets them, and a level's ambience plays wind and birds.

const RIG_SCENE := preload("res://levels/shared/driving_rig.tscn")
const FEELS := preload("res://effects/surface_feel_table.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func test_a_spray_emits_switches_kind_and_hides_when_idle() -> void:
	var spray := WheelSpray.new()
	add_child_autofree(spray)
	assert_false(spray.visible, "idle sprays start hidden")
	spray.update(FEELS.feel_for(DIRT), 0.8, 0.016)
	assert_true(spray.emitting)
	assert_true(spray.visible)
	assert_eq(spray.kind, SurfaceFeel.SprayKind.DUST)
	assert_almost_eq(spray.lifetime, 1.2, 0.001)
	spray.update(FEELS.feel_for(MUD), 0.8, 0.016)
	assert_eq(spray.kind, SurfaceFeel.SprayKind.CLODS)
	assert_almost_eq(spray.lifetime, 0.7, 0.001)
	spray.update(FEELS.feel_for(MUD), 0.01, 0.5)
	assert_false(spray.emitting, "below the threshold it stops")
	assert_true(spray.visible, "its last particles are still flying")
	spray.update(null, 0.0, 0.5)
	assert_false(spray.visible, "hidden once idle longer than its particles live")


func test_a_reset_stops_a_spray_at_once() -> void:
	var spray := WheelSpray.new()
	add_child_autofree(spray)
	spray.update(FEELS.feel_for(MUD), 1.0, 0.016)
	spray.stop_now()
	assert_false(spray.emitting)
	assert_false(spray.visible)


func test_the_rig_carries_sprays_and_sound_and_a_reset_quiets_them() -> void:
	var rig: DrivingRig = RIG_SCENE.instantiate()
	add_child_autofree(rig)
	assert_eq(rig.effects.sprays.size(), 4, "one spray per wheel")
	assert_eq(rig.audio.players.size(), 7)
	for sound_name in CarAudio.LOOPS:
		assert_true((rig.audio.players[sound_name] as AudioStreamPlayer).playing, sound_name)
	rig.effects.sprays[2].update(FEELS.feel_for(MUD), 1.0, 0.016)
	rig.place_car(Transform3D(Basis(), Vector3(0.0, 2.0, 0.0)))
	assert_false(rig.effects.sprays[2].visible, "the reset stopped the spray")
	assert_true(rig.audio.impacts_muted(), "and holds back thumps for a moment")


func test_a_car_on_its_own_makes_no_sound() -> void:
	var car: Car = load("res://car/car.tscn").instantiate()
	add_child_autofree(car)
	assert_true(car.find_children("*", "AudioStreamPlayer", true, false).is_empty())


func test_ambience_plays_wind_and_birds_now_and_then() -> void:
	var ambience := LevelAmbience.new()
	ambience.bird_interval = Vector2(0.05, 0.1)
	add_child_autofree(ambience)
	assert_true(ambience.wind.playing)
	await wait_seconds(0.5)
	assert_gt(ambience.birds_played, 1)
	var quiet := LevelAmbience.new()
	quiet.birds = false
	quiet.bird_interval = Vector2(0.05, 0.1)
	add_child_autofree(quiet)
	await wait_seconds(0.3)
	assert_eq(quiet.birds_played, 0)
```

- [ ] **Step 2: Run them and see them fail.**
  Run: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_car_feedback.gd -gexit`
  Expected: SCRIPT ERROR (`WheelSpray`, `LevelAmbience` and `DrivingRig.effects` don't exist yet).

- [ ] **Step 3: Write the nodes.**

`effects/wheel_spray.gd`:

```gdscript
class_name WheelSpray
extends CPUParticles3D
## One wheel's spray (spec §4.2): mud clods, dust or tyre smoke. Its particles stay
## in the world where they were thrown. It hides once it has been idle for longer
## than its particles live, so an idle spray costs no draw call.
## Forward is -Z, so "behind the tyre" is +Z of the transform the car gives it.

const AMOUNT := 24
const QUAD_SIZE := 0.22
const MIN_ALPHA := 0.35
const MAX_ALPHA := 0.9
## A barely-there spray is thrown at this share of its kind's full speed.
const MIN_SPEED_SHARE := 0.5

static var _quad: QuadMesh

var kind: SurfaceFeel.SprayKind = SurfaceFeel.SprayKind.NONE
var _idle_seconds := 0.0
## The current kind's full throw speed, as Vector2(min, max) (m/s).
var _base_velocity := Vector2.ZERO


func _init() -> void:
	amount = AMOUNT
	emitting = false
	visible = false
	local_coords = false
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _shared_quad()
	randomness = 0.4


## Sprays `feel`'s kind at `strength` (0-1), or stops below the threshold.
func update(feel: SurfaceFeel, strength: float, delta: float) -> void:
	var wanted := SurfaceFeel.SprayKind.NONE
	if feel != null and strength > SprayLogic.THRESHOLD:
		wanted = feel.spray
	if wanted == SurfaceFeel.SprayKind.NONE:
		emitting = false
		if visible:
			_idle_seconds += delta
			if _idle_seconds > lifetime:
				visible = false
		return
	if wanted != kind:
		_configure(wanted)
	color = Color(feel.spray_color, lerpf(MIN_ALPHA, MAX_ALPHA, strength))
	# Stronger spray is thrown faster; the particle count stays put, since changing it restarts the emitter.
	var speed := lerpf(MIN_SPEED_SHARE, 1.0, clampf(strength, 0.0, 1.0))
	initial_velocity_min = _base_velocity.x * speed
	initial_velocity_max = _base_velocity.y * speed
	_idle_seconds = 0.0
	visible = true
	emitting = true


## Stops at once and hides, leaving no trail (a car reset).
func stop_now() -> void:
	emitting = false
	visible = false
	_idle_seconds = 0.0


func _configure(new_kind: SurfaceFeel.SprayKind) -> void:
	kind = new_kind
	match new_kind:
		SurfaceFeel.SprayKind.CLODS:
			lifetime = 0.7
			direction = Vector3(0.0, 0.7, 1.0)
			spread = 25.0
			initial_velocity_min = 3.0
			initial_velocity_max = 6.0
			gravity = Vector3(0.0, -12.0, 0.0)
			damping_min = 0.0
			damping_max = 0.5
			scale_amount_min = 0.35
			scale_amount_max = 0.7
			scale_amount_curve = null
			color_ramp = null
		SurfaceFeel.SprayKind.DUST:
			lifetime = 1.2
			direction = Vector3(0.0, 0.5, 1.0)
			spread = 40.0
			initial_velocity_min = 0.5
			initial_velocity_max = 2.0
			gravity = Vector3(0.0, 0.3, 0.0)
			damping_min = 1.0
			damping_max = 2.0
			scale_amount_min = 1.2
			scale_amount_max = 2.2
			scale_amount_curve = _growing_curve(3.0)
			color_ramp = _fading_ramp()
		SurfaceFeel.SprayKind.SMOKE:
			lifetime = 1.4
			direction = Vector3(0.0, 1.0, 0.3)
			spread = 30.0
			initial_velocity_min = 0.5
			initial_velocity_max = 1.5
			gravity = Vector3(0.0, 0.6, 0.0)
			damping_min = 0.5
			damping_max = 1.0
			scale_amount_min = 1.5
			scale_amount_max = 2.5
			scale_amount_curve = _growing_curve(3.5)
			color_ramp = _fading_ramp()
	_base_velocity = Vector2(initial_velocity_min, initial_velocity_max)


static func _shared_quad() -> QuadMesh:
	if _quad == null:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		_quad = QuadMesh.new()
		_quad.size = Vector2(QUAD_SIZE, QUAD_SIZE)
		_quad.material = material
	return _quad


static func _growing_curve(to: float) -> Curve:
	var curve := Curve.new()
	curve.max_value = to
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, to))
	return curve


static func _fading_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	return ramp
```

`effects/car_effects.gd`:

```gdscript
class_name CarEffects
extends Node3D
## The car's wheel sprays (spec §6): one WheelSpray per wheel, fed each frame from
## the wheel's surface and motion. Only reads the car.

const FEELS := preload("res://effects/surface_feel_table.tres")
## Sprays start this far above the contact point (m), so they don't clip into the ground.
const LIFT := 0.05

var car: Car
var sprays: Array[WheelSpray] = []


func setup(driven: Car) -> void:
	car = driven
	for wheel in car.wheels:
		var spray := WheelSpray.new()
		spray.name = "Spray%s" % wheel.name.trim_prefix("Wheel")
		add_child(spray)
		sprays.append(spray)


func _process(delta: float) -> void:
	if car == null:
		return
	for i in car.wheels.size():
		var wheel := car.wheels[i]
		var motion := WheelMotion.of(wheel, car)
		var feel: SurfaceFeel = FEELS.feel_for(wheel.surface) if motion["in_contact"] else null
		var strength := 0.0
		if feel != null:
			strength = SprayLogic.intensity(feel.spray, motion["ground_speed"], motion["slip_speed"], motion["sliding"])
			sprays[i].global_transform = Transform3D(car.global_basis, wheel.contact_point + wheel.contact_normal * LIFT)
		sprays[i].update(feel, strength, delta)


## A car reset: every spray stops at once.
func notify_reset() -> void:
	for spray in sprays:
		spray.stop_now()
```

`effects/car_audio.gd`:

```gdscript
class_name CarAudio
extends Node
## The car's sound (spec §5.5): two engine layers, the road, gravel, mud and skid
## loops, and a thump for hard hits. Each frame it reads the car and sets every
## player's pitch and volume. Its players pause with the game.

const FEELS := preload("res://effects/surface_feel_table.tres")
const LOOPS: Array[StringName] = [&"engine_low", &"engine_high", &"road", &"gravel", &"mud", &"skid"]
## Volumes move toward their targets this fast (linear units per second), so nothing clicks.
const EASE_PER_SECOND := 4.0
const SILENT := 0.01
const SILENT_DB := -80.0
const IMPACT_COOLDOWN := 0.25
const RESET_MUTE := 0.5
const THUMP_BASE := 0.35
const THUMP_RANGE := 0.65
const ROLL_PITCH_BASE := 0.8
const ROLL_PITCH_RANGE := 0.4
const ROLL_PITCH_SPEED := 30.0

var car: Car
## StringName sound -> AudioStreamPlayer (the loops and the thump).
var players := {}
var thumps_played := 0

## StringName loop -> current linear volume.
var _volumes := {}
var _impact_wait := 0.0


func setup(driven: Car) -> void:
	car = driven
	for sound_name in LOOPS:
		var player := _add_player(sound_name)
		player.volume_db = SILENT_DB
		player.play()
		_volumes[sound_name] = 0.0
	_add_player(&"thump")


## The loop's current linear volume (0-1).
func volume(sound_name: StringName) -> float:
	return _volumes[sound_name]


## A car reset: no thump for a moment, since the car was just put down.
func notify_reset() -> void:
	_impact_wait = RESET_MUTE


## True while a thump would be held back (just after a thump or a reset).
func impacts_muted() -> bool:
	return _impact_wait > 0.0


func _process(delta: float) -> void:
	if car == null or car.drivetrain == null:
		return
	_impact_wait = maxf(0.0, _impact_wait - delta)
	var engine := EngineSoundLogic.layers(car.drivetrain.rpm, car.input.throttle, car.drivetrain.is_shifting())
	_set_loop(&"engine_low", engine["low_volume"], engine["low_pitch"], delta)
	_set_loop(&"engine_high", engine["high_volume"], engine["high_pitch"], delta)

	var wheels: Array[Dictionary] = []
	var hardest := 0.0
	for wheel in car.wheels:
		var motion := WheelMotion.of(wheel, car)
		motion["feel"] = FEELS.feel_for(wheel.surface) if motion["in_contact"] else null
		wheels.append(motion)
		if wheel.in_contact:
			var bottomed := ImpactLogic.is_bottomed_out(wheel.compression, wheel.stats.suspension_length)
			hardest = maxf(hardest, ImpactLogic.strength(wheel.compression_speed, bottomed))
	var tyres := TyreSoundLogic.mix(wheels)
	var roll_pitch := ROLL_PITCH_BASE + ROLL_PITCH_RANGE * clampf(absf(car.forward_speed()) / ROLL_PITCH_SPEED, 0.0, 1.0)
	_set_loop(&"road", tyres["road"], roll_pitch, delta)
	_set_loop(&"gravel", tyres["gravel"], roll_pitch, delta)
	_set_loop(&"mud", tyres["mud"], roll_pitch, delta)
	_set_loop(&"skid", tyres["skid"], 1.0, delta)

	if hardest > 0.0 and _impact_wait <= 0.0:
		var thump: AudioStreamPlayer = players[&"thump"]
		thump.volume_db = linear_to_db(THUMP_BASE + THUMP_RANGE * hardest)
		thump.play()
		thumps_played += 1
		_impact_wait = IMPACT_COOLDOWN


func _set_loop(sound_name: StringName, target: float, pitch: float, delta: float) -> void:
	var level := move_toward(_volumes[sound_name], clampf(target, 0.0, 1.0), EASE_PER_SECOND * delta)
	_volumes[sound_name] = level
	var player: AudioStreamPlayer = players[sound_name]
	player.volume_db = linear_to_db(level) if level > SILENT else SILENT_DB
	player.pitch_scale = maxf(pitch, 0.01)


func _add_player(sound_name: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = String(sound_name).to_pascal_case()
	player.stream = SoundSynth.sound(sound_name)
	add_child(player)
	players[sound_name] = player
	return player
```

`effects/level_ambience.gd`:

```gdscript
class_name LevelAmbience
extends Node
## A level's outdoor sound bed (spec §5.6): a wind loop, and now and then a bird.
## Its random numbers are seeded, so tests can count on them.

@export_range(0.0, 1.0) var wind_volume: float = 0.35
@export var birds: bool = true
## Seconds between birds, from x to y.
@export var bird_interval: Vector2 = Vector2(6.0, 16.0)
@export var seed: int = 1

const BIRD_PITCH := Vector2(0.85, 1.25)
const BIRD_VOLUME := Vector2(0.2, 0.45)

var wind: AudioStreamPlayer
var bird: AudioStreamPlayer
var birds_played := 0

var _rng := RandomNumberGenerator.new()
var _until_bird := 0.0


func _ready() -> void:
	_rng.seed = seed
	wind = AudioStreamPlayer.new()
	wind.name = "Wind"
	wind.stream = SoundSynth.sound(&"wind")
	wind.volume_db = linear_to_db(maxf(wind_volume, 0.0001))
	add_child(wind)
	wind.play()
	bird = AudioStreamPlayer.new()
	bird.name = "Bird"
	bird.stream = SoundSynth.sound(&"bird")
	add_child(bird)
	_until_bird = _rng.randf_range(bird_interval.x, bird_interval.y)


func _process(delta: float) -> void:
	if not birds:
		return
	_until_bird -= delta
	if _until_bird > 0.0:
		return
	bird.pitch_scale = _rng.randf_range(BIRD_PITCH.x, BIRD_PITCH.y)
	bird.volume_db = linear_to_db(_rng.randf_range(BIRD_VOLUME.x, BIRD_VOLUME.y))
	bird.play()
	birds_played += 1
	_until_bird = _rng.randf_range(bird_interval.x, bird_interval.y)
```

- [ ] **Step 4: Wire them into the driving rig.**
  - In `levels/shared/driving_rig.gd`, directly below `@onready var recorder: RunRecorder = $RunRecorder`, add:

```gdscript

## The car's wheel sprays and sound (M3B spec §5.5, §6), made in _ready.
var effects: CarEffects
var audio: CarAudio
```

  - At the end of `_ready()`, below the `touch_controls.set_steer_mode(...)` line, add:

```gdscript
	effects = CarEffects.new()
	effects.name = "CarEffects"
	add_child(effects)
	effects.setup(car)
	audio = CarAudio.new()
	audio.name = "CarAudio"
	add_child(audio)
	audio.setup(car)
```

  - Replace `place_car()`, with its doc comment, with:

```gdscript
## Puts the car upright and still at `target`, with the camera straight behind it.
## Sprays stop and thumps pause for a moment, so a reset makes no trail or bang.
func place_car(target: Transform3D) -> void:
	car.reset_to(target)
	camera.snap_to_target()
	if effects != null:
		effects.notify_reset()
	if audio != null:
		audio.notify_reset()
```

- [ ] **Step 5: Add ambience to the three levels.** In each of `levels/rally_road/rally_road.tscn`, `levels/muddy_valley/muddy_valley.tscn` and `levels/test_ground/test_ground.tscn`, add this line directly below the last `[ext_resource ...]` line:

```ini
[ext_resource type="Script" path="res://effects/level_ambience.gd" id="20_ambience"]
```

  Then add a node at the very end of each file.

  `rally_road.tscn`:

```ini

[node name="Ambience" type="Node" parent="."]
script = ExtResource("20_ambience")
wind_volume = 0.4
```

  `muddy_valley.tscn`:

```ini

[node name="Ambience" type="Node" parent="."]
script = ExtResource("20_ambience")
wind_volume = 0.3
bird_interval = Vector2(4, 12)
```

  `test_ground.tscn`:

```ini

[node name="Ambience" type="Node" parent="."]
script = ExtResource("20_ambience")
wind_volume = 0.25
birds = false
```

- [ ] **Step 6: Run the tests.**
  Run: `godot --headless --import`, then the Step 2 command. Expected: 5 passing, plus the expected "leaked at exit" warning.
  Run: `./run_tests.sh all`. Expected: exit 0. The lap times printed by `test_cars.gd` stay 1:30.3 / 1:26.3 / 1:40.5 (Rally Road) and 1:38.2 / 1:34.9 (Muddy Valley).

- [ ] **Step 7: Commit.**
  ```bash
  git add effects/wheel_spray.gd effects/wheel_spray.gd.uid effects/car_effects.gd effects/car_effects.gd.uid effects/car_audio.gd effects/car_audio.gd.uid effects/level_ambience.gd effects/level_ambience.gd.uid levels/shared/driving_rig.gd levels/rally_road/rally_road.tscn levels/muddy_valley/muddy_valley.tscn levels/test_ground/test_ground.tscn tests/unit/test_car_feedback.gd tests/unit/test_car_feedback.gd.uid
  git commit -m "Spray mud, dust and smoke from the wheels, give the car its sound, and add level ambience" -m "Co-Authored-By: Claude <model name> <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RhfJavT34eWyW3enLLKWgH"
  ```

---

### Task 5: A real car on the Test Ground, and measured notes

**Files:**
- Create: `tests/scenarios/test_car_feedback.gd`, `docs/notes/performance-m3b.md`

**Interfaces:**
- Consumes: `DrivingRig.effects` and `DrivingRig.audio`; `TrailScenarios.drive_toward`; `ScenarioHelper.ticks`; `SaveSandbox`.

- [ ] **Step 1: Write the scenario tests.**

`tests/scenarios/test_car_feedback.gd`:

```gdscript
extends GutTest
## Spray and sound driven by a real car on the Test Ground (M3B spec §9.2): clods
## and squelch on mud, dust and gravel on dirt, road sound when cruising on asphalt
## with no smoke, smoke and a squeal when sliding there, the engine pitch rising
## with rpm, and a thump for a hard landing but not for a reset.

const TEST_GROUND := preload("res://levels/test_ground/test_ground.tscn")
const RALLY := preload("res://car/cars/rally.tres")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _ground() -> Node3D:
	var ground: Node3D = TEST_GROUND.instantiate()
	(ground.get_node("DrivingRig") as DrivingRig).car_override = RALLY
	add_child_autofree(ground)
	var rig: DrivingRig = ground.get_node("DrivingRig")
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return ground


func _rig(ground: Node3D) -> DrivingRig:
	return ground.get_node("DrivingRig")


## Puts the car at rest facing -Z at `position` and lets it settle.
func _place(rig: DrivingRig, position: Vector3) -> void:
	rig.place_car(Transform3D(Basis(), position))
	for i in ScenarioHelper.ticks(1.0):
		rig.car.input.virtual_throttle = 0.0
		await get_tree().physics_frame


## Drives for `seconds` with the given inputs; returns the most any spray showed of
## `kind` (emitting sprays only) and the loudest each loop got.
func _drive(rig: DrivingRig, seconds: float, throttle: float, steer: float, kind: SurfaceFeel.SprayKind) -> Dictionary:
	var result := {"sprays": 0, "loudest": {}}
	for sound_name in CarAudio.LOOPS:
		result["loudest"][sound_name] = 0.0
	for tick in ScenarioHelper.ticks(seconds):
		rig.car.input.virtual_throttle = throttle
		rig.car.input.virtual_steer = steer
		await get_tree().physics_frame
		var spraying := rig.effects.sprays.filter(func(s: WheelSpray) -> bool: return s.emitting and s.kind == kind).size()
		result["sprays"] = maxi(result["sprays"], spraying)
		for sound_name in CarAudio.LOOPS:
			result["loudest"][sound_name] = maxf(result["loudest"][sound_name], rig.audio.volume(sound_name))
	return result


func test_mud_throws_clods_and_squelches() -> void:
	var rig := _rig(_ground())
	await _place(rig, Vector3(30.0, 0.8, -20.0))
	var run := await _drive(rig, 3.0, 1.0, 0.0, SurfaceFeel.SprayKind.CLODS)
	gut.p("mud: %d wheels throwing clods, loudest %s" % [run["sprays"], run["loudest"]])
	assert_gte(run["sprays"], 2, "the driven wheels throw mud")
	assert_gt(run["loudest"][&"mud"], 0.2)
	assert_eq(run["loudest"][&"skid"], 0.0)


func test_dirt_throws_dust_and_crunches() -> void:
	var rig := _rig(_ground())
	await _place(rig, Vector3(-120.0, 0.8, 0.0))
	var run := await _drive(rig, 5.0, 1.0, 0.0, SurfaceFeel.SprayKind.DUST)
	gut.p("dirt: %d wheels throwing dust, loudest %s" % [run["sprays"], run["loudest"]])
	assert_eq(run["sprays"], 4)
	assert_gt(run["loudest"][&"gravel"], 0.3)
	assert_eq(run["loudest"][&"mud"], 0.0)


func test_asphalt_is_quiet_cruising_and_smokes_and_squeals_sliding() -> void:
	var rig := _rig(_ground())
	await _place(rig, Vector3(0.0, 0.8, -5.0))
	# Get up to speed first: a full-throttle launch may puff a little smoke.
	await _drive(rig, 3.5, 1.0, 0.0, SurfaceFeel.SprayKind.SMOKE)
	var cruise := {"sprays": 0, "loudest": {}}
	for sound_name in CarAudio.LOOPS:
		cruise["loudest"][sound_name] = 0.0
	for tick in ScenarioHelper.ticks(2.0):
		TrailScenarios.drive_toward(rig.car, rig.car.global_position + Vector3(0.0, 0.0, -50.0), 16.0)
		await get_tree().physics_frame
		var smoking := rig.effects.sprays.filter(func(s: WheelSpray) -> bool:
				return s.emitting and s.kind == SurfaceFeel.SprayKind.SMOKE).size()
		cruise["sprays"] = maxi(cruise["sprays"], smoking)
		for sound_name in CarAudio.LOOPS:
			cruise["loudest"][sound_name] = maxf(cruise["loudest"][sound_name], rig.audio.volume(sound_name))
	gut.p("asphalt straight at %.0f km/h: %d smoking, loudest %s" % [rig.car.forward_speed() * 3.6, cruise["sprays"],
			cruise["loudest"]])
	assert_eq(cruise["sprays"], 0, "no smoke driving straight")
	assert_gt(cruise["loudest"][&"road"], 0.1)
	assert_eq(cruise["loudest"][&"skid"], 0.0)
	var slide := await _drive(rig, 1.5, 1.0, 1.0, SurfaceFeel.SprayKind.SMOKE)
	gut.p("asphalt at full lock: %d smoking, loudest skid %.2f" % [slide["sprays"], slide["loudest"][&"skid"]])
	assert_gte(slide["sprays"], 1, "sliding tyres smoke")
	assert_gt(slide["loudest"][&"skid"], 0.05)


func test_the_engine_pitch_rises_with_rpm() -> void:
	var rig := _rig(_ground())
	await _place(rig, Vector3(-120.0, 0.8, 0.0))
	await get_tree().process_frame
	var idle_pitch: float = rig.audio.players[&"engine_low"].pitch_scale
	var idle_rpm := rig.car.drivetrain.rpm
	var highest_pitch := 0.0
	var highest_rpm := 0.0
	for tick in ScenarioHelper.ticks(4.0):
		rig.car.input.virtual_throttle = 1.0
		await get_tree().physics_frame
		if rig.car.drivetrain.rpm > highest_rpm:
			highest_rpm = rig.car.drivetrain.rpm
			highest_pitch = rig.audio.players[&"engine_high"].pitch_scale
	gut.p("engine: idle %.0f rpm pitch %.2f, top %.0f rpm high-layer pitch %.2f" % [idle_rpm, idle_pitch, highest_rpm,
			highest_pitch])
	assert_gt(highest_rpm, idle_rpm + 2000.0)
	assert_gt(highest_pitch, EngineSoundLogic.layers(idle_rpm, 0.0, false)["high_pitch"] * 1.5)
	assert_gt(rig.audio.volume(&"engine_high"), 0.5, "the high layer carries full throttle")


func test_a_hard_landing_thumps_but_a_reset_does_not() -> void:
	var rig := _rig(_ground())
	await _place(rig, Vector3(-120.0, 0.8, 0.0))
	await wait_seconds(0.6)
	var before := rig.audio.thumps_played
	rig.place_car(Transform3D(Basis(), Vector3(-120.0, 0.8, 0.0)))
	await wait_physics_frames(ScenarioHelper.ticks(0.4))
	assert_eq(rig.audio.thumps_played, before, "a reset puts the car down silently")
	await wait_seconds(0.6)
	before = rig.audio.thumps_played
	rig.car.reset_to(Transform3D(Basis(), Vector3(-120.0, 3.0, 0.0)))
	await wait_physics_frames(ScenarioHelper.ticks(1.5))
	gut.p("thumps from a 2.5 m drop: %d" % (rig.audio.thumps_played - before))
	assert_gt(rig.audio.thumps_played, before, "dropping from 2.5 m thumps")
```

- [ ] **Step 2: Run them.**
  Run: `godot --headless --import`, then `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/scenarios/test_car_feedback.gd -gexit`.
  Expected: 5 passing. In the scratch clone they printed:
  ```
  mud: 4 wheels throwing clods, loudest mud 0.53
  dirt: 4 wheels throwing dust, loudest gravel 0.80
  asphalt straight at 56 km/h: 0 smoking, road 0.72, skid 0.0
  asphalt at full lock: 4 smoking, loudest skid 0.69
  engine: idle 1000 rpm pitch 0.67, top 7200 rpm high-layer pitch 1.60
  thumps from a 2.5 m drop: 1
  ```

- [ ] **Step 3: Measure draw calls and build time.** These need a window. If the shell has no display set, prefix each command with `DISPLAY=:1 WAYLAND_DISPLAY=wayland-1`.
  ```bash
  godot --path . res://tools/level_shots.tscn -- res://levels/muddy_valley/muddy_valley.tscn 560
  godot --path . res://tools/level_shots.tscn -- res://levels/rally_road/rally_road.tscn 15
  ```
  Expected: 131 and 127 draw calls, the same as master, and builds within 0.15 s of master's (2.06 s and 1.30 s). Don't commit the PNGs.

- [ ] **Step 4: Write the notes.** Record what you measured. If a number differs from these, write your number and say so in your report.

`docs/notes/performance-m3b.md`:

````
# Performance: surface feedback and sound (Milestone 3 Part B), desktop

Build: `m3b-feedback`, desktop (Godot 4.7.2, Mobile renderer, `--fixed-fps 120` for tests). Phone numbers are still to be measured, and sound can only be judged on the phone.

## Render counts (desktop, `tools/level_shots.tscn`, car at rest)

| Level | Spot (m) | Build time | Primitives | Draw calls | Objects |
|---|---|---|---|---|---|
| Muddy Valley | 560 | 2.10 s | 319,060 | 131 | 599 |
| Rally Road | 15 | 1.35 s | 268,708 | 127 | 621 |

- **Draw calls** are unchanged from master: 131 and 127.
- **Sprays cost nothing when idle.** A probe showed each `CPUParticles3D` adds one draw call once it has emitted and keeps it until hidden, and `WheelSpray` hides itself after its particles die. At most 4 more draw calls while all four wheels spray.
- **Build time** is up about 0.05 s on both levels (2.06 → 2.10 s, 1.30 → 1.35 s).

## Sounds
- Building all nine synthesized sounds takes about 68 ms, once per app session (`test_sound_synth.gd` prints it).
- Headless test runs use Godot's Dummy audio driver, which still reports players as playing.

## Scenario tests (desktop, `test_car_feedback.gd`)

```
mud: 4 wheels throwing clods, loudest mud 0.53, skid 0.0
dirt: 4 wheels throwing dust, loudest gravel 0.80, mud 0.0
asphalt straight at 56 km/h: 0 smoking, loudest road 0.72, skid 0.0
asphalt at full lock: 4 smoking, loudest skid 0.69
engine: idle 1000 rpm pitch 0.67, top 7200 rpm high-layer pitch 1.60
thumps from a 2.5 m drop: 1 (and none for a reset)
```

## Physics unchanged
- Lap times and scenario numbers match master: Rally Road 1:30.3 / 1:26.3 / 1:40.5, Muddy Valley 1:38.2 / 1:34.9, 0–100 km/h 7.49 / 5.14 s, diff locks 9.9 / 1.9 m, 4x4 clearance 32 cm.
- The standstill mud climb reads 16.6 s when run alone and 16.5 s inside the full suite, on both master and this branch.

## Test-run warning
Headless runs that play sound end with "N ObjectDB instances were leaked at exit". Godot prints it whenever a playing sound is freed just before quitting, as GUT does after a test. A two-node probe with no project code prints the same. It is a warning, not a script error.

## Still to check on the phone
- 60 fps with all four wheels spraying.
- Sound: loudness balance, engine pitch, whether the loops sound seamless.
- Load time after a fresh app start (< 3 s).
````

- [ ] **Step 5: Run the full suite.**
  Run: `./run_tests.sh all`. Expected: exit 0, 440 passing and 1 pending.

- [ ] **Step 6: Commit.**
  ```bash
  git add tests/scenarios/test_car_feedback.gd tests/scenarios/test_car_feedback.gd.uid docs/notes/performance-m3b.md
  git commit -m "Check sprays and sound on a real car, and record the desktop numbers" -m "Co-Authored-By: Claude <model name> <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RhfJavT34eWyW3enLLKWgH"
  ```
