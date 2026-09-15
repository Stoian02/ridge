# Ridge Milestone 3, Part A — Cars and Car Select: Design Spec

**Date:** 2026-09-14
**Status:** Draft for review
**Parent spec:** `docs/superpowers/specs/2026-09-11-ridge-design.md` (binding). It refines §3 Cars, §7 Game systems and §11 Milestone 3.
**Builds on:** `master` at 9aee3d5 (Milestone 2 merged, including Muddy Valley's mud-skip fix and shortcut)

---

## 1. Summary

Milestone 3 is split into parts, each with its own spec, plan and build. **Part A** adds more cars and a way to choose them:
- a **car select** screen after picking a level (and before Free Drive)
- two new cars, an **Off-road 4x4** and a **Rally Car Tuned**, unlocked by total stars
- **differential locks** in the car physics, which the 4x4 uses
- **low-poly bodies** for all three cars, each with a preview in car select

The stock Rally Car must drive exactly as it does today.

Later parts (planned separately): more cars (sports car, hot hatch, buggy), snow/ice and water, the remaining levels, particles and audio, the art pass, UI polish.

## 2. Decisions from the design conversation

| Question | Decision |
|---|---|
| First part of Milestone 3 | Cars and car select |
| New car | Off-road 4x4, inspired by the new Ford Bronco (design spec §3.2) |
| Tuned Subaru | A separate unlockable car with more power (about +30% torque), stiffer and slightly lower suspension, grippier tires, a little lighter |
| Car looks | Simple low-poly shapes built in code, one distinct silhouette per car; the full art pass comes later |
| Unlocks | By total stars (as in design spec §7) |
| Where car select sits | After picking a level: level select → car select → run; the last car used is remembered |
| Architecture | Option A: a `CarDef` resource per car in a `CarCatalog`, and one shared car scene that the driving rig configures |
| Free Drive | Also goes through car select (any unlocked car) |
| Scoring | Stars and best times stay per level, whichever car set them |

## 3. Cars as data

### 3.1 Resources
- **`CarDef`** (`car/car_def.gd`, `Resource`) holds:
  - `id: StringName`, `display_name: String`
  - `description: String`: one line, e.g. "Heavy and torquey. Loves mud, slow on asphalt."
  - `best_on: String`: e.g. "Mud, dirt, rough ground"
  - `stats: CarStats`
  - `body: CarBodyDef` (§6)
  - `unlock_stars: int`
- **`CarCatalog`** (`car/car_catalog.gd`, `Resource`; data in `car/car_catalog.tres`):
  - `cars: Array[CarDef]`, in display order
  - `find_by_id(id) -> CarDef`
  - `unlocked(total_stars: int) -> Array[CarDef]`
  - `newly_unlocked(stars_before: int, stars_after: int) -> Array[CarDef]`

### 3.2 The three cars
| id | Name | Stats | Unlock |
|---|---|---|---|
| `rally` | Rally Car | `car/rally_car.tres`, **unchanged** | 0 ★ |
| `offroad_4x4` | Off-road 4x4 | `car/offroad_4x4.tres` (new) | 3 ★ |
| `rally_tuned` | Rally Car Tuned | `car/rally_car_tuned.tres` (new) | 5 ★ (of the 6 available now) |

Unlock thresholds are placeholders until more levels exist. Fictional names come with the art pass (design spec §13).

### 3.3 Saving and choosing
- **`Progress`** gains a `selected_car: String` setting, saved under `settings` next to `steer_mode`, with default `"rally"`. Older save files load unchanged, and the save file's `VERSION` stays 1.
- **`GameState`** gains:
  - `car_catalog: CarCatalog`
  - `selected_car() -> CarDef`: the saved car if it exists and is unlocked, otherwise the Rally Car
  - `set_selected_car(id)`: saves the choice
  - `pending_scene: String`: the scene car select will start
  - `choose_car_for(scene_path)`: sets `pending_scene` and opens car select

### 3.4 Putting the car into a level
- `car/car.tscn` stays the one shared car scene, and `car.gd` does not read `GameState`.
- **`DrivingRig`** gains `@export var car_override: CarDef`.
  - In `_enter_tree`, before the car's own `_ready` applies its stats, the rig gives the car the override if one is set, otherwise `GameState.selected_car()`.
  - It sets both the car's `stats` and its body (`Car.body_def`, a new export on the car).
  - Tests and the Test Ground scene can set `car_override` directly.
- **Run recorder:** each recording notes the car id, so runs can be compared per car.

## 4. Drivetrain: differential locks

### 4.1 Model
Today drive torque is split front/rear (`Drivetrain.split_torque`), then half goes to each wheel on an axle, and each wheel integrates its spin independently (`Wheel._update_spin`). That is an open differential, and it stays the behaviour whenever the locks are 0.

**New `CarStats` group "Differentials":**
- `front_diff_lock`, `rear_diff_lock` and `centre_diff_lock`: each 0–1, default 0. 0 is open, about 0.3–0.6 is a limited-slip differential, 1 is fully locked.
- `diff_lock_max_torque`: the most torque a lock can move (Nm), default 3000.

**New pure function:**

`Drivetrain.lock_transfer(a_speed, b_speed, lock, max_torque, side_inertia, delta) -> float`

It returns the torque to move from side A to side B (negative moves it from B to A):
- the torque that would bring both sides to the same speed within the tick, so it grows with their spin-speed difference and never reverses it, which keeps it stable at 120 Hz
- capped at `lock × max_torque`, so a 0.3 lock can move at most 30% of what a full lock can

**Where it's applied:** in `Car._physics_process`, after `split_torque` and before the wheels update. Each tick it uses the wheels' current spin speeds:
- front pair: left ↔ right, by `front_diff_lock`
- rear pair: left ↔ right, by `rear_diff_lock`
- front axle ↔ rear axle (the average of each pair), by `centre_diff_lock`, for AWD only

The transfer is added to each wheel's `drive_torque`.

**Behaviour:** when a wheel spins in mud or lifts off a rut, the gripping wheels keep pushing. A locked axle resists turning and scrubs its tires in tight corners.

### 4.2 Starting stats (tuned by driving)
**Off-road 4x4** (`archetype = &"offroad"`):
| Group | Values |
|---|---|
| Body | mass 2150 kg; centre of mass (0, −0.05, 0); inertia (3800, 4300, 1000); body 1.95 × 0.6 × 4.6 m; aero drag 0.6 |
| Wheels | radius 0.45 m, width 0.30 m; track 1.72 m; wheelbase 2.95 m; mount height 0.165 m; wheel inertia 2.5 (jeep ground clearance: 32 cm under the body at rest, where the Bronco Raptor has 33 cm; with the first 0.40 m wheels, 0.7 m body and 0.2 m mounts it was 18.6 cm) |
| Suspension | length 0.50 m; springs 32000; damping 2800 compress / 4200 rebound; anti-roll 4000 front / 5000 rear |
| Tires | grip 1.05; rear bias 1.0; peak slip angle 10°; slide grip 0.8 |
| Engine | torque 480, 560, 580, 540, 470, 380 Nm at 1000, 2000, 3000, 4000, 5000, 5800 rpm; redline 5800; launch 2800 |
| Gearbox | 4.2, 2.6, 1.75, 1.3, 1.0, 0.8; final drive 4.6 (4.1 before the bigger wheels; raised to keep the same pull); upshift 5400, downshift 2200; shift time 0.2 s |
| Drivetrain | AWD, front split 0.5; centre lock 1.0, rear 0.6, front 0.3 |
| Brakes / steering | brake torque 14000; max steer 34°; steer rate 120°/s |
| Grip table | `offroad/asphalt` 0.95, `offroad/dirt` 1.1, `offroad/mud` 1.35 |

**Rally Car Tuned** (`archetype = &"rally"`), starting from `rally_car.tres` with these changes:
| Group | Values |
|---|---|
| Body | mass 1380 kg; centre of mass (0, −0.18, 0) |
| Suspension | length 0.35 m, as stock (0.30 m bottomed out on Muddy Valley's rutted mud); springs 35400; damping 2680 / 4020; anti-roll 6700 / 10700 (all about +20%) |
| Tires | grip 1.3 |
| Engine | torque ×1.3: 416, 533, 572, 546, 481, 390 Nm; launch 4000 |
| Gearbox | shift time 0.09 s |
| Drivetrain | front split 0.41; all locks 0, as stock (mild limited-slip locks of 0.15 front and 0.35 rear made it run wide out of Muddy Valley's first mud stretch and wedge against the creek bank; revisit when tuning on the phone) |

The stock Rally Car keeps every current value, with all locks at 0.

## 5. Car select and unlocks

### 5.1 Flow
- **Levels:** Main menu → Play → Level select → tap a level → **Car select** → tap a car → the run starts.
- **Free Drive:** Main menu → Free Drive → **Car select** → Test Ground.
- **Level select:** its cards call `GameState.choose_car_for(level.scene_path)` instead of opening the level.
- **Retry:** reloads the level with the same car.
- **Pause menu:** gains **Change car**, which opens car select for the current level; picking a car restarts the level with it. It is also offered in Free Drive.
- **Results screen:** **Next level** opens car select for the next level.

### 5.2 Screen (`ui/car_select.tscn` + `ui/car_select.gd`, built with `UiKit`)
- **Heading:** "Choose your car", with the destination underneath: the level name and its `LevelDef.surfaces` text (new field, e.g. "Asphalt" or "Dirt, mud, creek"), or "Free Drive".
- **One card (`Button`) per catalog car**, showing:
  - a preview (§6.3)
  - the name and the description
  - "Best on: …"
- **Last car used:** the card of `GameState.selected_car()` has a highlighted border.
- **Locked car:** the card is disabled and shows "Earn N ★ to unlock (you have M)".
- **Tapping an unlocked card:** calls `GameState.set_selected_car(id)`, then `GameState.change_scene(pending_scene)`.
- **Back** (button, Escape, or the Android back gesture) returns to level select, or to the main menu when the pending scene is Free Drive.

### 5.3 Unlock notice
- `GameState.record_finish` compares total stars before and after the finish, using `CarCatalog.newly_unlocked`, and includes the newly unlocked cars in its result.
- The results screen then adds "New car unlocked: <name>" for each.

## 6. Low-poly bodies

### 6.1 Body definition and builder
- **`CarBodyDef`** (`car/car_body_def.gd`, `Resource`) holds:
  - colours: `body_color`, `window_color`, `trim_color`, `rim_color`, `light_color`
  - shape shares of `body_size.z`: `hood_length`, `cabin_length`, `cabin_height` (m), `windscreen_slope`, `rear_window_slope`, `nose_taper`, `tail_taper`
  - on/off extras: `rear_spoiler`, `big_wing`, `hood_scoop`, `roof_rack`, `bull_bar`, `spare_wheel`, `fender_flares` (arches sized to the wheels at rest, from `CarStats.wheel_rest_height()`), `black_roof`, `flat_grille` (with square headlights), `steel_bumpers`, `rock_rails`
- **`CarBodyBuilder.build(body: CarBodyDef, stats: CarStats) -> ArrayMesh`** (`car/car_body_builder.gd`) makes one flat-shaded, vertex-coloured mesh:
  - a lower body: a box with bevelled edges at `stats.body_size`, its nose and tail tapered
  - a cabin: a tapered block on top with sloped windscreen and rear window, and a darker side-window band
  - extras as small boxes and wedges
  - It reuses `LowPolyMeshes`' triangle and box helpers. Budget: under 400 triangles for a shipped car; under 600 with every extra switched on at once.

### 6.2 On the car
- **Mesh:** `Car._apply_stats` sets `$BodyMesh.mesh` from `CarBodyBuilder` when `body_def` is set, and removes `CabinMesh` (the cabin is part of the built mesh). Without a `body_def`, the grey boxes stay, so older tests that build a bare car still work.
- **Collision:** `$BodyShape` stays the box at `body_size`.
- **Wheels:** their visuals are unchanged, sized from the stats, except that the hub bar uses `body_def.rim_color` when set.

### 6.3 The three looks and the car select preview
| Car | Shape | Colours | Extras |
|---|---|---|---|
| Rally Car | Compact four-door saloon, sloped windscreen | Orange (0.86, 0.32, 0.16), dark windows | Rear spoiler |
| Rally Car Tuned | The same saloon, lower | Deep blue, gold rims | Big wing, hood scoop |
| Off-road 4x4 | An early low-poly take on the Ford Bronco Raptor: boxy and tall, flat nose and tail, upright windscreen, long cabin, big tyres | Red (0.72, 0.07, 0.06), black roof and trim, light blue-grey glass, dark grey rims | Flat black grille with square headlights, steel bumpers, rock rails, wraparound fender flares, spare wheel |

**Preview:** each car select card has a `SubViewportContainer` with its own camera and light. It shows the built body and simple wheels, turning slowly. It exists only on the car select screen.

## 7. Performance
- Each car body is under 400 triangles in one draw call, replacing two box meshes, so a run adds no draw calls.
- Previews cost nothing in a run.
- Muddy Valley's peak (286,336 primitives at 560 m, `docs/notes/performance-m2b2.md`) must stay under the 300k budget with any car. It is re-measured with `tools/level_shots.tscn`.

## 8. Testing

### 8.1 Unit tests
- **`CarCatalog`:** `find_by_id`; `unlocked` at 0, 3 and 5 stars; `newly_unlocked` crossing 3 and 5 stars, and not when no threshold is crossed.
- **`Progress`:** `selected_car` saves and loads; old saves without it default to `"rally"`.
- **`GameState.selected_car()`:** falls back to the Rally Car for a locked or unknown id.
- **`Drivetrain.lock_transfer`:**
  - 0 with lock 0 or equal speeds
  - takes from the faster side and gives to the slower
  - never above `max_torque`
  - never reverses the speed difference in one tick
  - stable over 1,000 ticks at lock 1.0 with the 4x4's wheel inertia
- **Car setup:** a car given a `CarDef` uses its stats and its built body mesh; its collision box equals `body_size`; with no `body_def`, the grey boxes remain.
- **`CarBodyBuilder`:** every car's mesh has triangles, faces outward, stays under 400 triangles and uses its colours; the main body stays within the footprint plus an extras allowance; the 4x4's bounds are taller and wider than the Rally Car's.
- **Car select:**
  - one card per car
  - locked cards are disabled and show the star text
  - the selected car is highlighted
  - tapping saves the car and changes to the pending scene
  - back goes to level select or the main menu
  - every card has a preview
- **Level select:** a card calls `choose_car_for` with its scene.
- **Pause menu:** Change car opens car select for the current scene.
- **Results screen:** shows the unlock line only when the result has new cars.

### 8.2 Scenario tests (headless, real physics)
- **Stock unchanged:** every existing car and level scenario passes unchanged, including the Rally Road and Muddy Valley scripted-driver runs.
- **Each car on each level:** Rally Car Tuned and Off-road 4x4 each finish Rally Road and Muddy Valley with the scripted driver, with no resets, in 60–150 s. The times are printed.
- **Tuned vs stock:** the tuned car reaches 100 km/h from rest on flat asphalt at least 10% sooner than stock, and beats stock's scripted time on Rally Road.
- **4x4 in the mud:** from a standstill at 1400 m on Muddy Valley's mud climb, the 4x4 reaches the finish sooner than the Rally Car.
- **Locks matter:** on a Test Ground-style patch with the left wheels on mud and the right wheels lifted over a raised rut, the 4x4 pulls away. An identical 4x4 with all locks at 0 covers clearly less distance in the same time.
- **Stability:**
  - each car lands the Test Ground kicker upright
  - the 4x4 does not roll over at full steering lock on flat dirt at 40 km/h
- **Flow:** level select → car select → the run's car has the chosen car's stats, and Retry keeps the same car.

### 8.3 Visual checks
Screenshots of car select, and of each car on Rally Road and Muddy Valley, reviewed before hand-off.

## 9. Tuning
All new stats are starting values. Before hand-off, desktop checks cover the scenario numbers and look for bouncing, roll-overs or wheel hop in the telemetry. After merge, the owner tunes by driving on the phone and recording runs. The recordings note the car.

## 10. Out of scope for Part A
- other cars: sports car, hot hatch, buggy
- snow, ice and water
- new levels
- particles, audio and the art pass
- fictional names
- per-car best times or stars
- upgrades
- manual differential-lock controls

## 11. Done when
- The three cars are selectable after picking a level and in Free Drive.
- Unlocks work by total stars, with a notice on the results screen.
- Each car has its own low-poly body and car select preview.
- In the scenario tests, the 4x4 is clearly better in mud and the tuned car clearly faster on asphalt.
- The stock Rally Car drives exactly as before.
- All unit and scenario tests pass.
- The screenshots have been reviewed.
- The build is ready for the owner's phone session.
