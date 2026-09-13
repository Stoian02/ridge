# Ridge — Design Spec

**Date:** 2026-09-11
**Status:** Draft for review
**Supersedes:** `ridge-prd.md` wherever the two differ (see "Changes from the PRD" at the end)

---

## 1. Summary

Ridge is a 3D, sim-cade, off-road hill-climb driving game for Android (landscape), built
in Godot 4 with Jolt physics and GDScript. The player drives linear mountain trails of
1–2 minutes against the clock, across surfaces that genuinely change how the car
behaves. The visual target is the stylized, minimalist, warm-lit look of *Over the Hill*
(Funselektor, 2025).

There is no deadline. The goal is driving feel; scope follows feel, not the calendar.

**Test device:** Xiaomi 13 (Snapdragon 8 Gen 2, 8 GB RAM, 120 Hz screen).

---

## 2. Gameplay

### 2.1 Core loop
1. Pick a level (level select), then a car (unlocked cars only).
2. 3-2-1 countdown; the clock starts on "go".
3. Drive the trail through checkpoint gates to the finish gate.
4. Results screen: time, stars earned, best time, Retry / Next.
5. Stars unlock further levels and cars.

There is **no fuel and no damage**. The only pressure is the clock.

### 2.2 Controls (landscape)
- **Left thumb: steering.** Two styles, both built, selectable in settings:
  - *Analog drag zone* — touch anywhere on the left half and slide horizontally;
    displacement from the touch-down point maps to steer −1…1.
  - *Buttons* — ◀ / ▶ hold buttons; steer value ramps toward ±1 over time.
- **Right thumb: gas and brake** buttons. Holding brake while (near-)stationary engages
  reverse. Gearbox is automatic.
- **Reset button** (small, top of screen) — returns the car to the last checkpoint.
- **Desktop:** keyboard and gamepad map to the same steer/throttle/brake values, for
  fast tuning iterations without a phone build.

### 2.3 Air control
- Active **only when fully airborne**: all four wheels have had no ground contact for
  at least **0.1 s** (grace period so small bumps don't count).
- While active: gas pitches nose up, brake pitches nose down; steering applies a gentle
  roll torque (kept only if it feels good in playtesting — it's a tunable that can be
  set to zero).
- Deactivates the moment any wheel touches ground.

### 2.4 Recovery
- Reset returns the car, upright and stationary, to the last passed checkpoint's
  position and heading (the start line counts as checkpoint 0).
- **Automatic reset** when:
  - the car is flipped — body up-vector past a tunable angle and no wheel contact —
    for **2 s**; or
  - the car enters the level's out-of-bounds volume.
- "Stuck" is handled by the manual Reset button.
- **The clock keeps running** through resets; lost time is the only penalty.

### 2.5 Scoring
- Each level defines three target times. Finishing earns 1 star; beating target 2 earns
  2 stars; beating target 3 earns 3 stars.
- Target times are set from real playtest runs, not guessed.
- Save data keeps best time and best star count per level.

### 2.6 Camera
Smooth chase camera behind and above the car: position and look-at are damped springs,
with a slight look-ahead in the direction of travel. Impact shake and speed-based FOV
are later polish, not milestone 1.

---

## 3. Cars

### 3.1 Design approach
Each car is **inspired by a milestone model** from a manufacturer, chosen to cover the
drivetrain range (FWD / RWD / AWD). Cars are not tied to a particular era.

Cars get **fictional names and no real badges or logos** — a recognisable silhouette and
character, not a replica — so the game can be published without licensing.

### 3.2 Roster
| Slot | Drivetrain | Inspiration | When |
|---|---|---|---|
| Rally Car (starter, all-rounder) | AWD | Subaru Impreza WRX STI | Milestone 1 |
| Sports Car | RWD | BMW E46 M3 CSL | Later |
| Off-road 4x4 | AWD, locking diffs | New Ford Bronco (Bronco DR / Raptor) | Later |
| FWD car | FWD | Hot hatch (e.g. Peugeot 205 GTI / Golf GTI / Civic Type R) | Later |
| Buggy | RWD, rear engine | Dune / trophy buggy | Later |

Only the Rally Car is in scope until the core feel is signed off. The rest of the roster
is decided in detail when each car is added.

---

## 4. Vehicle physics (custom raycast car)

The car is a single `RigidBody3D` (Jolt) with child components. Each component has one
job, a small public interface, and can be tested on its own. **All tunable numbers live
in resources, never in scripts.**

### 4.1 Components
- **`CarInput`** — produces `steer` (−1…1), `throttle` (0…1), `brake` (0…1) from touch,
  keyboard, or gamepad. Physics code never knows which device is in use.
- **`Wheel`** ×4 — per physics tick:
  - Sphere shape-cast down from the wheel mount to find ground contact point, normal,
    and the collider hit.
  - **Suspension:** spring + damper + bump stop, applied at the contact point.
  - **Tire:** longitudinal and lateral slip → forces via a grip curve that rises, peaks,
    and falls off (catchable slides). Forces scale with the wheel's vertical load and are
    limited by a friction circle (combined braking + cornering shares grip — this is where
    weight transfer comes from).
  - **Surface:** reads the `SurfaceDef` from the hit collider; multiplies grip by the
    car × surface value from the grip table; applies rolling resistance, sink depth, and
    drag.
  - Positions and spins the visual wheel mesh from suspension compression and wheel
    angular velocity.
- **`Drivetrain`** — engine torque curve (a `Curve` over RPM), automatic gearbox with
  shift logic, differential (FWD / RWD / AWD with a torque split; open or locked), brakes.
- **`Steering`** — maximum steer angle reduces with speed; wheels turn toward the target
  angle at a limited rate (no snap steering).
- **`AirControl`** — airborne detection (§2.3) and pitch/roll torque.
- **Stability** — anti-roll bars per axle; centre of mass offset from `CarStats`.

### 4.2 Data
- **`CarStats`** (`Resource`, `.tres` per car): mass, centre-of-mass offset, wheel
  positions and radius, suspension (rest length, stiffness, damping, travel), tire grip
  curves, engine torque curve, gear ratios, final drive, drivetrain type and split,
  brake torque, steering limits, anti-roll stiffness, air-control torques.
- **`SurfaceDef`** (`Resource`, `.tres` per surface): base grip, rolling resistance, sink
  depth, drag, particle scene, audio.
- **`GripTable`** (`Resource`): car-archetype × surface grip multipliers. This is the
  main tool for "the right car for the right terrain".

### 4.3 Surface detection
Each ground collision shape carries its surface as metadata pointing at a `SurfaceDef`
(the PRD's "zoned collision" option). Untagged shapes fall back to the Dirt surface so
nothing is ever surface-less.

### 4.4 Simulation rate
- Physics at **120 ticks/s**; rendering locked at **60 FPS** to save battery. Revisit
  after profiling on the Xiaomi 13 (120 FPS rendering is a later experiment).

### 4.5 Tuning tools
- **Telemetry overlay** (toggleable): per-wheel load, slip ratio, slip angle, surface,
  contact; plus RPM, gear, speed, airborne state.
- **Run recorder:** writes a CSV of per-tick car and wheel state for a run to the
  device's user data folder. The player (you) shares the file; the developer (Claude)
  reads it to diagnose feel reports like "it snaps sideways on mud".

---

## 5. Surfaces

| Surface | Milestone | Behaviour |
|---|---|---|
| Asphalt | 1 | High grip, predictable; the baseline all tuning starts from |
| Mud | 1 | Wheels sink a few cm; high rolling resistance; low lateral grip; momentum matters |
| Dirt / grass | 1 | Medium grip; the default off-trail ground and fallback surface |
| Snow / ice | Later | Very low grip, long braking distances |
| Water (shallow) | Later | Drag; prolonged submersion stalls or weakens the engine |

Each surface later gets its own particles (tire smoke, mud spray, dust) and tire audio
layered under the engine.

---

## 6. Levels

### 6.1 Construction
- **Terrain:** heightmap-based mesh with `HeightMapShape3D` collision, tagged Dirt.
- **Trail:** a `Path3D` spline. A trail builder generates the drivable trail mesh along
  the spline in **segments**; each segment is its own collision shape tagged with a
  surface. A mud section is expressed as "these segments are Mud".
- Reshaping a level = moving spline points (editable by hand in the Godot editor).
- **Unevenness:** trails are not flat. Potholes, bumps, washboard, ruts, rocks and
  gentle undulation are authored as height features on the drivable surface (the
  `RoughPatch` heightmap approach proven on the Test Ground in Milestone 1, generalised
  by the trail builder in Milestone 2). Asphalt gets occasional potholes and patches;
  mud gets ruts at wheel-track spacing.
- **Edges:** natural boundaries (rocks, trees, drop-offs) plus an out-of-bounds volume.
- **Checkpoint gates** (`Area3D`) placed along the spline; each stores its reset
  transform. A **finish gate** ends the run.

### 6.2 Level data
**`LevelDef`** (`Resource`): display name, scene path, three star target times,
unlock requirement.

### 6.3 Milestone levels
- **Test Ground** (dev only): flat area, ramps of several angles, a jump, a slalom, and
  side-by-side surface patches (asphalt / dirt / mud) for tuning and scenario tests, plus
  a rough asphalt lane (potholes, speed bumps, washboard) and a rutted mud strip.
- **Rally Road:** asphalt mountain road; gentle climbs, a couple of hairpins, two small
  jumps. Teaches steering, braking, and air control.
- **Muddy Valley:** dirt track dropping into a valley and climbing out; muddy stretches
  and a final steep mud climb that requires carrying momentum.

The remaining PRD levels (Frozen Pass, Coastal Highway, Rock Canyon, Sunset Ridge,
Avalanche Climb, The Gauntlet) follow once their surfaces and cars exist.

---

## 7. Game systems
- **`GameState`** (autoload): selected level and car, access to save data.
- **`SaveSystem`:** local-only file in `user://` — best time and stars per level, unlocked
  levels and cars, settings (steering style, audio). No cloud, no accounts.
- **`RunClock`:** countdown, running time, finish time; pauses only with the pause menu.
- **Progression:** linear level unlock by stars; cars unlock by total stars (thresholds
  set once multiple cars exist).
- **UI (milestone scope):** main menu, level select, HUD (time, checkpoint split,
  reset button, controls), pause menu (resume / restart / quit / steering style),
  results screen. Functional first, polished later.

---

## 8. Visual direction
- **Target:** *Over the Hill* — minimalist, stylized, bold warm palettes, golden-hour
  light, soft atmosphere; lighting and colour carry the look, not texture detail.
- **Mood from day one:** even gray-box scenes get the sun, gradient sky, coloured fog,
  and a colour grade, so the game looks like itself early.
- **Style:** low-poly models with vertex colour and few or no textures; a custom shader
  with soft stepped lighting and subtle rim light; per-level palettes; sky-tinted height
  fog; instanced (`MultiMesh`) foliage.
- **Mobile constraints:** Godot Mobile renderer (Vulkan). No SSAO/SSIL there, so ambient
  occlusion is baked into vertex colours. One directional shadow with a limited distance.
- **Assets:** generated (code or Blender scripts) plus CC0 packs where they fit. The user
  is art director; reference screenshots of *Over the Hill* go in `reference/`.
- **Later polish:** tire tracks, mud splatter decals, impact camera shake, speed FOV.

---

## 9. Project structure
Organised by feature:

```
res://
  car/        car.tscn, car.gd, wheel.gd, drivetrain.gd, steering.gd,
              air_control.gd, car_stats.gd, rally_car.tres
  input/      car_input.gd, touch_controls.tscn
  surfaces/   surface_def.gd, grip_table.gd, asphalt.tres, mud.tres, dirt.tres,
              grip_table.tres
  levels/     level_def.gd, checkpoint.gd, finish_gate.gd, trail_builder.gd,
              test_ground/, rally_road/, muddy_valley/
  camera/     chase_camera.gd
  game/       game_state.gd (autoload), save_system.gd, run_clock.gd
  ui/         main_menu, level_select, hud, pause_menu, results
  debug/      telemetry_overlay, run_recorder
  tests/      unit/, scenarios/
```

Code style: readable over clever; small focused files; typed GDScript.

---

## 10. Testing
- **Unit tests (GUT):** pure logic — tire grip curve, suspension force, gearbox shift
  decisions, airborne detection, flip detection, star calculation, save/load round-trip,
  checkpoint bookkeeping.
- **Scenario tests (headless Godot):** scripted inputs on the Test Ground, asserting:
  - the car settles at ride height and does not creep when parked;
  - 0–100 km/h time within a tolerance of the approved baseline;
  - braking distance from 100 km/h within tolerance;
  - lateral slide on mud exceeds that on asphalt for the same manoeuvre.
  Baseline values are captured from the first tune the user approves, then act as
  regression guards. They catch accidental breakage; they do not judge feel.
- **Feel:** judged by the user on the Xiaomi 13, supported by telemetry and CSV runs.
- **Visual checks:** the developer renders screenshots from Godot to verify scenes.
- **Performance:** profile on the Xiaomi 13 at the end of Milestone 1, then at every
  milestone. Target: locked 60 FPS.

---

## 11. Milestones
1. **Core feel** — project setup, Test Ground (including rough ground), Rally Car with the full custom physics
   stack, desktop + touch controls (both steering styles), chase camera, telemetry and run
   recorder, unit + scenario tests, first Android build on the Xiaomi 13, performance
   profile. *Done when:* the user signs off that the Rally Car feels good on asphalt, dirt,
   and mud on the phone.
2. **First playable** — trail builder, Rally Road and Muddy Valley, checkpoints, resets,
   run clock, stars, results, level select, pause menu, save data, Over the Hill-style
   mood pass on both levels. *Done when:* both levels are playable start to finish on
   the phone with star targets set from real runs.
3. **Later (each planned separately)** — more cars, snow/ice and water, remaining levels,
   car select and unlocks, particles and audio, art pass, UI polish.

---

## 12. Changes from the PRD
- Free 3D steering on linear trails (PRD implied side-scrolling left-to-right).
- Controls: left steering / right gas-brake; tilt replaced by airborne-only gas/brake
  pitch and steer roll.
- Fuel system removed; clock-only pressure; stars by three target times.
- Level length 1–2 minutes (was 30–90 s); every level has checkpoints.
- Custom raycast vehicle instead of `VehicleBody3D`.
- Added Dirt/grass fallback surface.
- Cars inspired by milestone models with drivetrain variety, fictional names.
- Visual target: *Over the Hill*.
- Feature-based folder layout instead of `scenes/` + `scripts/`.
- No fixed timeline; milestone-driven instead of a 4-week plan.

## 13. Deferred decisions
- Fictional car names — chosen during each car's art pass.
- Car unlock star thresholds — set when a second car exists.
- Whether steer-roll air control stays — decided in Milestone 1 playtesting.
- 120 FPS rendering — decided after Milestone 1 profiling.
- Rough terrain along whole trails (Milestone 2, from the M1 final review): `RoughPatch`'s
  per-vertex heightmap (0.25 m spacing, ~33k vertices per 200 m strip) will not scale to full
  trails as-is. Before designing the trail builder, choose between short authored rough strips
  joined to an otherwise flat trail mesh (the proven, cheap approach) and a decimated / LOD
  heightmap along the whole spline.
- Jump landings (from the M1 final review): a driven wheel can spin up to redline in the air and
  meet the ground at a very different speed. Add a scripted jump-landing scenario test before
  the Milestone 1 feel sign-off, and tune from it.
