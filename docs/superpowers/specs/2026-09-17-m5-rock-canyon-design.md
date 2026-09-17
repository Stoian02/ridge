# Ridge Milestone 5 — Rock Canyon: Design Spec

**Date:** 2026-09-17
**Status:** Draft for the owner's review
**Parent spec:** `docs/superpowers/specs/2026-09-11-ridge-design.md` (binding). It refines §5 Surfaces (deep mud, rock, scree, wet rock), §6 Levels (the fourth level) and §11 "Later" (remaining levels).
**Builds on:** `master` at eb34123 (Milestone 4 merged: Frozen Pass, tunnel and bridge builders, snow/ice, traction-control slider)

---

## 1. Summary

Milestone 5 adds **Rock Canyon**, the fourth level: a slow, technical rock-crawling route about 2.1 km long that takes about 4 minutes 30. It brings:

- **Four new surfaces:** deep mud (meaner than mud), rock (grippier than asphalt), scree (loose stone) and wet rock (the ford bed).
- **Four new trail structures,** each defined as level data with its own builder, following the `TunnelDef`/`BridgeDef` pattern from Milestone 4:
  - **rock steps** — ledges the road climbs over, with a real vertical rock face
  - **boulder fields** — seeded clusters of fixed boulders and tilted slabs on and beside the road
  - **a talus field** — about 40 loose stones that move when you push them
  - **a ford** — the river crossing the road under a waterfall
- **A road width profile,** so the road can narrow to a 4.5 m shelf and widen again. This touches the road builder, the terrain corridor, scatter clearance and checkpoint gates.
- **Canyon walls** in the terrain: per-range height deltas on each side of the road, so the slot canyon has walls and the shelf has a cliff on one side and air on the other.
- **A throttle lever** as an alternative touch control: an absolute vertical slider instead of the on/off gas pad, chosen in settings like the steering style.
- **Two new sounds:** tyres grinding on rock, and a positional waterfall.

The car physics code and every existing car and surface value are unchanged.

## 2. Decisions from the design conversation

| Question | Decision |
|---|---|
| Route | Four segments: asphalt approach → deep mud gully → boulder wash → shelf climb to the rim, with a ford and waterfall near the top |
| Length | About 2.1 km, about 4:30 — the longest level by time |
| Cars | Obstacles sized so the rally cars beach and the 4x4 gets through, but **no car lock**: every car can enter. The level recommends the 4x4. |
| Deep mud | Water-filled ruts in a shaded gully, sinking to about 15 cm, mostly flat: a traction test, not a climb |
| Loose rock | Scree as a surface anywhere it suits; physically loose stones in **one** bounded talus field, confirmed on the phone before it stays |
| Tight section | A narrow shelf with rock cut on one side and an open drop on the other, as the level's climax |
| Water | A ford is in: shallow, visual water plus a slick wet-rock bed. Buoyancy and water physics are **not** in this milestone; the crossing is built so they can be added later. |
| Throttle | New "lever" control mode: an absolute vertical slider, position sets throttle. Default stays the current pedal. |
| Mood | Red desert canyon, hard midday sun |
| Architecture | Data + dedicated builders (the Milestone 4 pattern), including a road width profile |
| Resets | Manual only, as on Frozen Pass. The existing auto-resets (flipped; fallen below the map) are unchanged. |

## 3. The level

### 3.1 Place in the game

- **`levels/rock_canyon/`** holds the scene, `LevelDef`, trail, terrain and scatter definitions, and the generated curve.
- **Catalog:** the fourth level; under the existing rule it unlocks once Frozen Pass has been finished.
- **Surfaces line:** "Deep mud, rock, scree, water".
- **Recommended car:** a new optional `LevelDef.recommended_car: StringName` (empty on the existing three). Level select and car select show "Recommended: Off-road 4x4" when it is set. It is advice only — every unlocked car can still be chosen.
- **Star times:** placeholders of 4:45 (two stars) and 4:15 (three stars), replaced by the owner's real runs, as was done on Frozen Pass.
- **Car unlock thresholds:** unchanged.

### 3.2 Route (about 2.1 km)

| Distance | What happens |
|---|---|
| 0–220 m | Asphalt at the canyon mouth: easy bends, 2% climb. The last tarmac. |
| 220–300 m | Tarmac breaks into dirt and drops 5% into a shaded side-gully |
| 300–560 m | **Deep mud gully** (260 m): water-filled ruts at wheel-track spacing, standing water, flat ground |
| 560–700 m | Climb out of the gully; mud thins to dirt, the first rocks appear |
| 700–1150 m | **Boulder wash** (450 m): dry riverbed between canyon walls, 3–5% climb. Three rock steps (0.25–0.5 m), tilted slabs, boulder clusters to pick lines through, scree patches. |
| 1150–1250 m | **Talus field**: loose stones below a rockfall scar |
| 1250–1330 m | **The ford**: the river crosses the wash under a 14 m waterfall on the left wall; wet rock bed under about 0.3 m of water |
| 1330–1500 m | The wash narrows and steepens to 8–10%; a switchback climbs out |
| 1500–1900 m | **The shelf**: road narrowed to 4.5 m, rock cut on the left, open drop on the right. Off-camber slabs, two rubble washouts, one squeeze between fallen blocks. |
| 1900–2050 m | Final 12% push on loose scree |
| 2050–2100 m | Rim finish, looking back down the canyon |

- **Road shape:** generated by `tools/generate_rock_canyon_curve.gd` from straights and arcs, like the other levels, and checked for parts passing too close. The curve file is never hand-edited.
- **Checkpoints:** 300, 700, 1250, 1500 and 1900 m, then the finish.
- **Banking:** `use_curve_banking` stays on (the canyon is rock, not snow), but authored tilt is used sparingly — off-camber comes from slabs, not from the road twisting.

### 3.3 Look

- **Mood (`GoldenHourMood` values):** `sun_color` (1.0, 0.97, 0.9), `sun_energy` 1.5, `sun_elevation_deg` 62, `sky_top` (0.24, 0.46, 0.85), `sky_horizon` (0.86, 0.82, 0.72), `ground_color` (0.5, 0.3, 0.22), `fog_density` 0.003.
- **Terrain:** `dirt_color` (0.66, 0.34, 0.22), `rock_color` (0.74, 0.44, 0.3), `rock_slope_deg` 30 so the walls read as bare rock, `noise_amplitude` 26, `noise_wavelength` 150.
- **Scatter:** no pines (`pine_spacing` 0). Sparse dead juniper through the broadleaf slot in dry grey-olive (0.42, 0.4, 0.28) at about 35 m spacing, dense rocks at about 9 m, and no roadside posts (`post_drop` set high enough that none are placed).
- **Road colours:** dirt (0.6, 0.42, 0.3); deep mud dark brown (0.22, 0.16, 0.11); rock (0.62, 0.4, 0.31); scree (0.66, 0.5, 0.4); wet rock (0.3, 0.29, 0.28) at low roughness so it reads as wet.

## 4. Surfaces and grip

### 4.1 New surface values (dry asphalt grip = 1.0)

| Surface | File | Grip | Rolling resistance | Drag | Sink |
|---|---|---|---|---|---|
| Deep mud | `surfaces/deep_mud.tres` | 0.5 | 0.14 | 70 | 0.15 |
| Rock | `surfaces/rock.tres` | 1.05 | 0.03 | 0 | 0 |
| Scree | `surfaces/scree.tres` | 0.55 | 0.09 | 5 | 0.04 |
| Wet rock | `surfaces/wet_rock.tres` | 0.5 | 0.05 | 20 | 0.02 |

Existing surfaces (asphalt, dirt, mud, snow, ice, logs) and every car value are **unchanged**.

### 4.2 Grip table (`surfaces/grip_table.tres`)

Added entries: `offroad/deep_mud` 1.35, `rally/deep_mud` 1.0, `offroad/rock` 1.05, `rally/rock` 1.0, `offroad/scree` 1.2, `rally/scree` 0.95, `offroad/wet_rock` 1.1, `rally/wet_rock` 1.0.

### 4.3 Feel (`SurfaceFeel`)

Two enum additions:

- `SprayKind.SPLASH` — a wide, fast, translucent water sheet, thrown by `WheelSpray` with the existing strength scaling.
- `RollingSound.ROCK` — a hard, low, irregular grind, distinct from gravel's hiss.

Feel entries:

| Surface | Spray | Spray colour | Rolling sound | Skids |
|---|---|---|---|---|
| Deep mud | CLODS | (0.25, 0.18, 0.12) | MUD | no |
| Rock | NONE | — | ROCK | yes (0.7) |
| Scree | DUST | (0.66, 0.5, 0.4) | GRAVEL | yes (0.6) |
| Wet rock | SPLASH | (0.7, 0.78, 0.8) | ROCK | yes (0.5) |

## 5. Road width profile

### 5.1 Data

- **`TrailDef.width_stretches: Array[Vector4]`** — (start, length, road width, shoulder width), metres.
- **`TrailDef.width_blend: float`** (default 10.0) — the distance over which the width eases at each end of a stretch.
- Stretches must not overlap; outside them the road keeps `road_width`/`shoulder_width`.

### 5.2 Behaviour

- **`RoadSampler.half_width_at(distance)`** and **`road_half_width_at(distance)`** return the eased widths.
- **`TrailDef.half_total_width()`** keeps its current meaning — the widest half-width on the trail — and stays the value used for coarse bounds (terrain search radii, tunnel portals).
- Consumers that must follow the taper: `RoadBuilder` (mesh and collision cross-sections), `TerrainField`'s corridor carve and blend, `ScatterBuilder`'s road clearance, and `CheckpointPlacer`'s gate width.
- Rock Canyon uses one stretch: (1500, 400, 4.5, 0.0) — the shelf, with no shoulders.

### 5.3 Why it lands first

It is the change with the widest blast radius. It is implemented and merged before the new builders, and the existing three levels are re-verified unchanged (their geometry must be bit-identical, since none of them declares a width stretch).

## 6. Rock steps

### 6.1 Data (`RockStepDef`, `levels/trail/rock_step_def.gd`)

- `distance`: where the step's face sits along the road (m)
- `height`: 0.25–0.5 m, how much the road level rises
- `lateral_from`, `lateral_to`: the span across the road the vertical face covers (m from the centre line)
- `face_length`: 0.6 m, the depth of the rock lip
- `ramp_length`: 6.0 m, over which the road climbs to the new level **beside** the face
- `color`, `seed`
- **`TrailDef.rock_steps: Array[RockStepDef]`.**

### 6.2 Road profile

The road's level rises by `height` at each step and stays there for the rest of the trail, but *how* it rises depends on where you are across the road, so `RoadProfile` gains a lateral-aware `step_height(distance, lateral)`, summed into `height()` beside the ruts:

- **Inside `lateral_from`–`lateral_to`:** the rise happens at the face — the road is at the old level right up to `distance` and at the new level immediately after. You climb a vertical ledge.
- **Outside that span:** the rise is a ramp, from the old level at `distance` to the new level `ramp_length` later. Steep, but drivable without lifting a wheel.

Both lines are at the same level `ramp_length` past the face, so the road is flat across its width again by then. A step whose span covers the whole road has no ramp and must be climbed. The steps' ranges (`distance` to `distance + ramp_length`) are added to `detail_ranges`, so the road is sampled at `detail_step` across them.

### 6.3 Builder (`RockStepBuilder`)

- Builds the near-vertical rock face and its lip across `lateral_from`–`lateral_to`, seeded-rough, with rock vertex colours, sitting exactly on the profile's level change.
- Collision is a concave trimesh tagged **rock**.
- Where the face covers only part of the road, its ends are closed with side quads, so no gap shows where the face meets the ramp beside it.
- Drawing: all of a level's steps merge into one mesh — one draw call.

### 6.4 Placement on Rock Canyon

Three steps in the wash:

| Distance | Height | Face span | Choice |
|---|---|---|---|
| 812 m | 0.35 m | whole road | none — everyone climbs it |
| 947 m | 0.5 m | +0.5 to +3.5 m (right) | the ledge, or a steep ramp on the left |
| 1078 m | 0.3 m | whole road | none |

## 7. Boulder fields

### 7.1 Data (`BoulderFieldDef`, `levels/trail/boulder_field_def.gd`)

- `start`, `length` along the road (m)
- `count`: how many boulders
- `size_range`: Vector2, the boulders' radii (m)
- `lateral_range`: Vector2, how far from the centre line they may sit (m)
- `slab_fraction`: 0–1, the share built as low tilted slabs instead of rounded boulders
- `color`, `seed`
- **`TrailDef.boulder_fields: Array[BoulderFieldDef]`.**

### 7.2 Builder (`BoulderBuilder`)

- Places boulders on the road surface (using `RoadProfile` height) and on the terrain beyond the shoulders, all from the seed, so the same settings always give the same field.
- Rounded boulders are low-poly icospheres; slabs are flat wedges tilted 8–18°, whose job is to lift one wheel and put the car off-camber.
- Collision: one convex hull per boulder, tagged **rock**.
- Drawing: one `MultiMesh` per field.
- Boulders never sit closer than 1.5 m to a checkpoint gate's centre.

### 7.3 Sizing rule

Rounded boulders on the driving line are 0.30–0.45 m in radius: above the rally cars' clearance, below the 4x4's 32 cm plus suspension travel when climbed at a walking pace. Boulders off the driving line may be larger (up to 1.2 m) as scenery and as walls to the line.

### 7.4 Placement on Rock Canyon

Five fields: two in the wash (720–860 m, 980–1120 m), the two shelf washouts (1596–1618 m, 1744–1762 m, small stones), and the squeeze (1830–1850 m, two large blocks either side leaving a 3 m gap).

## 8. Talus field

### 8.1 Data (`TalusDef`, `levels/trail/talus_def.gd`)

- `start`, `length` (m)
- `count`: 40
- `size_range`: Vector2(0.18, 0.32) m
- `mass_range`: Vector2(30, 120) kg
- `color`, `seed`
- **`TrailDef.talus: Array[TalusDef]`.**

### 8.2 Builder (`TalusBuilder`)

- Creates one `RigidBody3D` per stone, each with a convex-hull collider, resting on the road or terrain surface, **asleep** on build (`sleeping = true`), so untouched stones cost almost nothing.
- Drawing: a single `MultiMesh` whose instance transforms are refreshed each frame from the bodies that are awake. When none are awake, nothing is written.
- Physics material: high friction, near-zero bounce.
- Stones are sized to be shoved aside, not climbed, and their mass is low enough that the 2150 kg 4x4 pushes through without stopping.

### 8.3 Acceptance

The talus field is a **provisional** feature: it ships behind its own data entry, and the phone check decides whether it stays. If it costs frame rate or produces jank (a stone wedging under the chassis, a stone launching the car), the fallback is to drop `TalusDef` from the trail and leave the area as scree with fixed boulders. This decision is recorded in the milestone's notes.

## 9. The ford and waterfall

### 9.1 Data (`FordDef`, `levels/trail/ford_def.gd`)

- `distance`: where the river crosses the road (m)
- `channel_width`: 16 m, the width of the cut across the road
- `depth`: 0.35 m, how far the road dips below its natural level at the centre
- `water_depth`: 0.3 m, the water surface's height above the channel floor
- `bank_run`: 10 m, the distance over which the road falls into and climbs out of the channel
- `waterfall_height`: 14 m, `waterfall_width`: 3.5 m, `waterfall_offset`: −22 m (its foot's lateral position, on the left wall)
- `water_color`, `foam_color`, `seed`
- **`TrailDef.fords: Array[FordDef]`.**

### 9.2 Behaviour

- **Road:** `RoadProfile` dips the road by `depth` over the channel, easing over `bank_run` either side. The road mesh and collision are continuous across it — you drive the riverbed.
- **Surface:** a `SurfaceStretch` of **wet rock** covers the channel, with dirt-to-wet-rock transitions at its ends.
- **Terrain:** `TerrainField` cuts the river channel through the terrain either side of the road, so the river visibly arrives and leaves.
- **Water:** a flat translucent ribbon at channel floor + `water_depth`, built like `CreekBuilder`'s, crossing the road and running out both sides. No collision.
- **Waterfall:** a vertical strip on the canyon wall, `waterfall_height` tall, unshaded and translucent, whose material's `uv1_offset` scrolls downward each frame — no shader, in keeping with the rest of the project. A `CPUParticles3D` mist at its base.
- **Sound:** an `AudioStreamPlayer3D` at the falls playing a new synthesized `&"waterfall"` sound, `max_distance` 80 m.

### 9.3 Water physics

Out of scope. The car is affected only by the wet-rock surface (grip 0.5, drag 20) and by the sprays it throws. The crossing's data and geometry are shaped so buoyancy and depth-dependent drag can be added later without moving the level's geometry.

## 10. Canyon walls

### 10.1 Data (`TerrainDef.wall_sections: Array[Vector4]`)

(start, length, left delta, right delta) in metres. A positive delta raises that side of the corridor into a wall; a negative delta drops it away. Deltas ease in and out over `TerrainDef.wall_blend` (default 25 m) at each end of a section, and are applied outside the corridor blend, taking the greater of the natural height and the wall height on a rise and the lesser on a drop.

### 10.2 Rock Canyon's sections

| Start | Length | Left | Right | Effect |
|---|---|---|---|---|
| 300 | 260 | +18 | +18 | the shaded mud gully |
| 700 | 450 | +30 | +30 | the slot canyon around the wash |
| 1150 | 180 | +26 | +14 | the talus scar and the ford |
| 1500 | 400 | +25 | −40 | the shelf: cliff left, air right |

## 11. The throttle lever

### 11.1 Setting

- **`Progress.throttle_mode: String`** — `THROTTLE_PEDAL = "pedal"` (default) or `THROTTLE_LEVER = "lever"`, saved with the other settings and validated on load exactly as `steer_mode` is. Unknown values fall back to the default.
- The pause menu gains a "Throttle" row beside "Steering style", with the same widget.

### 11.2 Logic (`TouchThrottleLogic`, `input/touch_throttle_logic.gd`)

A pure class, like `TouchSteerLogic`:

- `value_for(rect: Rect2, point: Vector2) -> float` — absolute position: the bottom of the track is 0, the top is 1, clamped at both ends.
- A dead zone of the bottom 10% returns exactly 0, so resting low means closed.
- No touch means 0. Releasing is immediate; there is no ramp down.

### 11.3 Controls (`TouchControls`)

- In lever mode, `gas_rect()` returns 250×560 at the right edge (today's pedal is 250×340); the brake pad is unchanged.
- Pressing anywhere inside the track sets that value at once and captures the finger, by index. While that finger is held, only its vertical position matters — horizontal drift is ignored, so a thumb sliding sideways mid-climb does not drop the throttle.
- Drawing: the track, a fill bar to the current value, a thumb, quarter ticks and the "GAS" label.
- `release_all_touches()` zeroes it, so resuming from pause never leaves the engine pulling.
- `set_throttle_mode(mode)` mirrors `set_steer_mode`, clearing the captured finger.
- The keyboard path is untouched: `CarInput.throttle` still takes the maximum of the action strength and `virtual_throttle`.

## 12. Sound

Two new synthesized sounds in `SoundSynth`, both built like the existing ones (16-bit mono 22050 Hz, with the mandatory `LOOP_PAD` tail on loops):

- **`&"rock"`** — the `RollingSound.ROCK` bed: a low irregular grind, pitched and mixed by `TyreSoundLogic` from wheel speed, like the other rolling beds. Quieter than gravel at speed, because this level is slow.
- **`&"waterfall"`** — a filtered noise bed with a low rumble, looped, played positionally at the falls.

`LevelAmbience` on Rock Canyon: `wind_volume` 0.3, `birds` off.

## 13. Performance

Budgets are the project's existing ones: under 300k primitives, under 150 draw calls, 60 fps on the phone, level load under 3 s.

- New drawing is `MultiMesh`-shaped: about five boulder fields, one talus field, one merged rock-step mesh, water, waterfall and mist — roughly a dozen draw calls.
- `TerrainDef.view_distance` drops to 350 m (Frozen Pass uses 420), because the canyon walls hide the long view; `detail_distance` stays 140 m.
- Every new builder reports a phase into `TrailLevel.build_phases`, so build-time regressions show up in the phase summary the scenario tests print.
- The talus field's cost is measured explicitly on the phone (§8.3).

## 14. Testing

### 14.1 Unit tests

- **Width profile:** eased widths at stretch ends and middles; `half_total_width()` still returns the maximum; road mesh cross-sections narrow; terrain corridor, scatter clearance and gate width follow; the three existing levels produce unchanged geometry.
- **Rock steps:** the road's level rises by `height` after a step and stays; the face's top edge matches the raised road; collision exists and is tagged rock; beside a partial-width face the road ramps up over `ramp_length` and both lines are level with each other at the end of the ramp.
- **Boulder fields:** the same seed gives the same layout; boulders on the driving line stay inside `size_range`; none sits within 1.5 m of a gate centre; each has a convex collider tagged rock.
- **Talus:** the right count, all asleep on build, each with a convex hull; the `MultiMesh` instance count matches.
- **Ford:** the road dips by `depth` at the centre and is continuous; the wet-rock stretch covers the channel; the water ribbon sits `water_depth` above the floor; the waterfall's height and position match its data.
- **Canyon walls:** height deltas appear at the right distances on the right sides, ease at the ends, and do not disturb the corridor itself.
- **Throttle:** `TouchThrottleLogic` values at the bottom, the dead zone, mid-track, the top and beyond both ends; `TouchControls` in lever mode with `screen_size_override`; finger capture and horizontal drift; `release_all_touches()`.
- **Settings:** `throttle_mode` saves, loads and rejects unknown values; `recommended_car` round-trips on `LevelDef`.
- **Surfaces:** the four new files' values; grip-table entries; feel-table entries for all four.

### 14.2 Scenario tests

- **The 4x4 finishes Rock Canyon** with no automatic resets, staying upright, with its time, distance and average speed printed.
- **The rally cars' runs are recorded, not required:** the test drives each and prints how far it got and where it stopped, so the level documents where a low car beaches. It fails only on a crash or an automatic reset from falling off the map.
- **Ledge climb:** the 4x4 crawls a 0.4 m step at part throttle and clears it, with less wheelspin than the same climb at full throttle.
- **Deep mud:** the 4x4 crosses the gully from a standstill and its time and minimum speed are printed; the surface is confirmed as deep mud under the wheels.
- **Ford:** the car crosses without leaving the ground and the wet-rock surface is read under the wheels.
- **Talus:** driving into the field wakes stones and the car passes through without being stopped or flipped.
- **Build cost:** the phase summary is printed for Rock Canyon, as for Frozen Pass.

### 14.3 Phone acceptance

Frame rate through the wash, the talus field and the shelf; load time under 3 s; the talus verdict (§8.3); a check that the lever is comfortable to hold while steering.

## 15. Out of scope

- Water physics: buoyancy, depth-dependent drag, floating or drowning.
- A new car, including any rock-crawler archetype.
- Locking levels to cars.
- Winch, recovery or auto-righting mechanics.
- Any change to existing car values or existing surface values.
- Changes to the automatic resets.

## 16. Risks

| Risk | Mitigation |
|---|---|
| The width profile regresses the existing levels | It lands first, alone, with the three existing levels proven unchanged before anything else is built |
| Loose talus stones wedge under the car or launch it | Bounded to one field, sized to shove, and provisional until the phone check (§8.3) |
| Rally cars beaching reads as a bug | The level recommends the 4x4 in level and car select, and the scenario tests record the beaching as expected behaviour |
| A 4:30 level slows the test suite | Rock Canyon's full-length run is driven with the 4x4 only; the rally-car runs are capped by distance, not by finishing |
| Obstacle sizing is wrong for the 4x4's clearance | The Test Ground's clearance logs already measure it (the 4x4 clears 35 cm); sizes are checked against that before the level is tuned |
