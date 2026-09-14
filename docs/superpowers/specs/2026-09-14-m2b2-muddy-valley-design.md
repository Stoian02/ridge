# Ridge Milestone 2, Part B2 — Muddy Valley: Design Spec

**Date:** 2026-09-14
**Status:** Draft for review
**Parent specs:** `docs/superpowers/specs/2026-09-11-ridge-design.md` (binding), `docs/superpowers/specs/2026-09-13-m2a-rally-road-design.md` (the trail builder this extends), `docs/superpowers/specs/2026-09-13-m2b1-game-flow-design.md` (catalog, stars, unlocks)
**Builds on:** `master` at b349da9 (Milestone 2 Parts A and B1 merged, Rally Road star times set)

---

## 1. Summary

Part B2 adds the second level, **Muddy Valley**: a ~1.5 km dirt trail that starts on a ridge, runs a fast winding descent into a green valley, crosses muddy stretches beside a creek, and climbs out through mud to the finish. To build it, the trail builder learns **surface sections**: each level names a base surface, whether it has painted lines, and stretches of another surface (mud with ruts). Scenery gains broadleaf trees and a creek. Muddy Valley is second in the catalog and unlocks when Rally Road is finished.

## 2. Decisions from the design conversation

| Question | Decision |
|---|---|
| How mud behaves | Slow but always drivable: mud slows and slides the car, the final climb rewards momentum, but a stopped car can always crawl out. No car-physics changes. |
| Layout | Down, across, and back up: ridge start, fast winding descent with one small jump, valley floor with mud and a creek beside the road, long final mud climb. ~1.5 km, 1–1.5 min. |
| Look | Green valley, late afternoon: same low sun as Rally Road, green grass slopes, dark wet earth, broadleaf trees mixed with pines, a creek, soft valley haze. |
| Track | Dirt, **9 m wide** (user asked for 8–10 m), no painted lines, grassy verges. Mud stretches cover the full width with two wheel ruts. **Rougher** than Rally Road: more potholes of varied sizes, bumpier overall. |
| Creek | Beside the road only; a water crossing is a later milestone. |
| Build approach | Surface sections in `TrailDef`; one `RoadBuilder` for every level, collision split by surface. Rally Road must keep working unchanged. |

## 3. Player experience

### 3.1 A run
Level select shows Muddy Valley under Rally Road, locked until Rally Road has been finished once. After a Rally Road finish, the results screen's **Next level** button opens Muddy Valley. The run itself works exactly like Rally Road: countdown, clock, 4 checkpoints with split comparison, resets, pause, results with stars and the saved best.

### 3.2 Mud
Driving onto mud, the car loses grip and speed (the existing mud `SurfaceDef`: grip 0.5, rolling resistance 0.1, sink 0.06, drag 40). Two ruts about a car-track apart pull at the wheels. Carrying speed into the final climb matters; stopping on it costs time but never strands the car.

### 3.3 Off the road
The verges are dirt underfoot (grass-coloured). The creek channel is shallow with a normal ground floor: a car that slides in can drive back out. Falling-off and flip resets work as on Rally Road.

### 3.4 Past the finish
The road carries on 60 m past the finish gate on both levels, so a finishing car no longer drives off the end of the road.

## 4. Architecture

### 4.1 Surface sections
- **`SurfaceStretch`** (new `Resource`, `levels/trail/surface_stretch.gd`): `start: float`, `length: float`, `surface: SurfaceDef`, `color: Color`, `rut_depth: float`, `rut_spacing: float`, `blend_length: float` (colour and rut fade at each end, default 2 m).
- **`TrailDef`** gains:
  - `base_surface: SurfaceDef` (default: asphalt)
  - `painted_lines: bool` (default: true)
  - `surface_stretches: Array[SurfaceStretch]` (default: empty)
  - The creek settings (§4.4).
  - Existing defaults keep Rally Road's resource valid without edits.
- **`RoadProfile`**:
  - Adds rut grooves inside stretches with `rut_depth > 0`. It uses the rut shape from `RoughShapes`, fading over `blend_length` at each end.
  - Asphalt patches are only generated when the base surface is asphalt.
  - Stretch start and end distances are added to the detail ranges, so ruts get detailed cross-sections.
- **`RoadBuilder`**:
  - The cross-section omits `LINE` parts when `painted_lines` is false.
  - Each chunk gets a row of cross-sections exactly at every stretch start and end inside it.
  - Road faces are grouped by the surface at each row pair's midpoint: the stretch surface inside a stretch, otherwise the base surface. There is one `StaticBody3D` per surface per chunk; shoulders stay dirt.
  - Road colour blends from the base road colour to the stretch colour over `blend_length`.
  - With no stretches, lines on and an asphalt base, the output is identical to today's.

### 4.2 Run-off past the finish
Both levels set `end_margin = 70` and their curves end with a 60 m straight after the old finish, so the finish gate stays 10 m from where the road used to end. Rally Road's gate positions and road up to the finish do not change. The terrain's fitted ground plane includes the new run-off, so terrain and scenery placement across Rally Road may shift slightly. That is accepted, and the screenshots are re-checked.

### 4.3 Curve generation
The segment-building and separation check move from `tools/generate_rally_road_curve.gd` into a shared `tools/curve_generator.gd` (a `RefCounted` with static functions). `tools/generate_rally_road_curve.gd` and a new `tools/generate_muddy_valley_curve.gd` each hold only their segment list and output path. Segment format is unchanged: `["straight", length, grade]`, `["arc", radius, turn_deg, grade]`, where a negative grade descends.

### 4.4 The creek
- **`TrailDef`** gains:
  - `creek_start`, `creek_length`: 0 length means no creek.
  - `creek_offset`: signed lateral distance from the road centre to the creek centre, in m; + is right.
  - `creek_width` (4 m), `creek_depth` (0.7 m), `creek_color`.
- **`TerrainField`:** after carving the corridor, it lowers samples within `creek_width / 2 + bank` of the creek centre line into a smooth channel `creek_depth` below the surrounding ground. The bank slope is gentle enough to drive out, and the channel ends taper to nothing.
- **`CreekBuilder`** (new, `levels/trail/creek_builder.gd`): one flat ribbon mesh per terrain chunk the creek crosses, 0.15 m below the channel's rim. The material is glossy blue-grey. The ribbon has no collision.
- **`ScatterBuilder`:** skips any item within `creek_width / 2 + 2 m` of the creek centre line.

### 4.5 Scenery and look
- **`LowPolyMeshes.broadleaf(foliage, trunk, seed)`:** a trunk with two or three lumpy leaf clumps, under ~150 triangles (comparable to a pine).
- **`ScatterDef`** gains `broadleaf_spacing` (0 = none, the default), `broadleaf_color`, `broadleaf_view_distance`. Broadleaf trees are placed like pines, one MultiMesh per chunk. Rally Road's scatter resource is unchanged.
- **Colours come from resources:**
  - `TerrainDef.dirt_color` (gentle ground) is green grass.
  - `TerrainDef.rock_color` (steep ground) is dark wet earth.
  - `TrailDef.asphalt_color` is the base road colour: dark brown dirt.
  - `TrailDef.shoulder_color` is the grass-green verge.
  - Mud stretches are darker brown still.
  - Posts are wooden brown.
- **Mood:** the scene's `GoldenHourMood` node uses its own values: a slightly lower, warmer sun, a softer green-gold horizon and a slightly higher fog density.
- **Valley shape:** the corridor already pulls terrain toward the road elevation. A road that drops well below the fitted ground plane should read as a valley with hills on both sides. This is checked with screenshots during plan writing (§9). If it doesn't read as a valley, `TerrainDef` gains one optional `valley_depth` that lowers the natural ground along the valley floor (Rally Road: 0).

### 4.6 Files

| File | Change |
|---|---|
| `levels/trail/surface_stretch.gd` | new |
| `levels/trail/trail_def.gd` | base surface, painted lines, stretches, creek settings |
| `levels/trail/road_profile.gd` | ruts; patches only on asphalt; stretch detail ranges |
| `levels/trail/road_builder.gd` | optional lines; rows at stretch ends; collision and colour by surface |
| `levels/trail/terrain_field.gd` | creek channel |
| `levels/trail/creek_builder.gd` | new |
| `levels/trail/scatter_def.gd`, `scatter_builder.gd`, `low_poly_meshes.gd` | broadleaf trees; creek clearance |
| `levels/trail/trail_level.gd` | builds the creek |
| `tools/curve_generator.gd` | new, shared |
| `tools/generate_rally_road_curve.gd` | uses the shared generator; 60 m run-off |
| `tools/generate_muddy_valley_curve.gd` | new |
| `levels/rally_road/rally_road_trail.tres`, `rally_road_curve.tres` | `end_margin = 70`; regenerated curve |
| `levels/muddy_valley/*` | new: scene, curve, trail, terrain, scatter, level resources |
| `levels/catalog.tres` | Muddy Valley second |
| `levels/shared/run_level.gd` | `push_warning` when the scene is missing from the catalog |

## 5. Muddy Valley

### 5.1 Layout

| Stretch | Distance | Grade | Content |
|---|---|---|---|
| Ridge start | 0–80 m | ~0% | View over the valley |
| Descent | 80–650 m | −6 to −10% | Sweepers, then tighter esses and one medium hairpin; the jump (~1 m, ~10 m long) on a straight around 350 m |
| Valley floor | 650–1150 m | 0 to +2% | Mud stretch 1 (~70 m); creek beside the road for ~250 m with mud stretch 2 (~90 m) alongside it |
| Final climb | 1150–1500 m | +7 to +9% | The last ~200 m to the finish is mud |
| Run-off | +60 m | ~0% | Past the finish |

Distances are targets. The generated curve's actual stretch and checkpoint distances are fixed during plan writing, and the curve must pass the separation check (28 m).

### 5.2 Roughness (starting values, tuned on the phone)

| Setting | Rally Road | Muddy Valley |
|---|---|---|
| `road_width` | 7 m | 9 m |
| `pothole_radius_range` | 0.35–0.65 m | 0.25–1.1 m |
| `pothole_depth_range` | 6–12 cm | 5–18 cm |
| `rough_sections` | 1 | several, covering most of the descent and valley floor, ~25 per 100 m |
| `pothole_clusters` | 2 | 3 |
| `undulation_amplitude` | 5 cm | ~10 cm, shorter wavelengths |
| Ruts in mud | — | 2 grooves, ~8 cm deep, ~1.55 m apart, centred on the road |

### 5.3 Checkpoints and stars
4 checkpoints at about 300, 650, 950 and 1200 m. `LevelDef` id `muddy_valley`, name "Muddy Valley". Placeholder star times come from the scripted driver: 2 stars at driver time × 0.95 and 3 stars at × 0.85, rounded to whole seconds. The user replaces them after phone runs.

## 6. Performance budgets
The same as Rally Road (M2A spec §8): 60 fps held, < 300k triangles on screen, < 150 draw calls, < 4 ms physics, < 3 s level load after a fresh app start. Desktop build time, triangles and draw calls are recorded for Muddy Valley during plan writing and at the end. The repeat-load slowdown (`docs/notes/performance-m2a.md`) is investigated separately, after B2.

## 7. Testing

### 7.1 Unit tests
- `RoadBuilder`:
  - Inside a mud stretch, road collision carries the mud surface meta.
  - Just outside it, road collision carries the base surface.
  - Shoulders stay dirt.
- `RoadBuilder`: `painted_lines = false` builds no line faces or line colours.
- **Rally Road regression:** for every road chunk that ends before the old road end, Rally Road's mesh vertex count and per-surface collision face counts match values recorded from the current `master` build. Pothole and patch counts must match too. Before the run-off is added, the same values must match for the whole road.
- `RoadProfile`:
  - Ruts reach `rut_depth` mid-stretch at ±`rut_spacing / 2`.
  - They are zero outside stretches and fade over `blend_length`.
  - No asphalt patches are generated on a dirt base.
- `TerrainField`: creek channel samples sit below the ground beside them; the channel tapers to nothing at its ends.
- `CreekBuilder`: the water ribbon lies inside the channel, below its rim.
- `ScatterBuilder`: no item within the creek clearance; `broadleaf_spacing = 0` places none.
- `LowPolyMeshes.broadleaf`: non-empty, under the triangle limit, upward-facing leaf tops.
- `CurveGenerator`: produces the same Rally Road curve points as the old tool for the original segments.
- Catalog: Muddy Valley is second and unlocked only after a Rally Road finish.
- `RunLevel`: warns when its scene is missing from the catalog.

### 7.2 Scenario tests (headless, real physics)
- **Drive the whole road:** the pure-pursuit driver completes Muddy Valley with every checkpoint in order, no resets, in 60–150 s.
- **Pull away on the climb:** a car stopped in mud halfway up the final climb reaches the finish at full throttle within 30 s.
- **Mud slows:** over the same distance on the valley floor at full throttle, the car is slower on mud than on dirt.
- **Out of the creek:** a car placed in the creek channel, facing the road, drives back onto the road within 10 s.
- **Run-off:** on both levels, a car that crosses the finish at speed and brakes stays on the road.
- **Build determinism:** building Muddy Valley twice gives identical chunk counts and checkpoint positions; build time is printed.
- **Game flow:** after a Rally Road finish, Next level opens Muddy Valley.

### 7.3 Visual checks
Screenshots of the ridge start, the jump, the valley floor with the creek, a mud stretch and the final climb are reviewed before hand-off.

## 8. Phone session (user, after merge)
Feel on dirt and mud, 60 fps, load time, back gesture into and out of Muddy Valley, and real star times.

## 9. Verified during plan writing (in a scratch clone, before tasks are dispatched)
- Muddy Valley is drivable from a standstill on the steepest mud grade with the current car and mud values. If not, the climb's grade or mud length is reduced; the car is not changed.
- Large potholes (1.1 m radius, 18 cm deep) don't trap a wheel or cause resets for the scripted driver.
- Collision split at stretch boundaries gives smooth contact (no wheel contact loss crossing from dirt to mud).
- The terrain reads as a valley in screenshots, or `valley_depth` is needed.
- The creek channel is drivable out of.
- Desktop build time, triangles and draw calls for Muddy Valley.
- Rally Road regression values recorded from `master` before any change.

## 10. Out of scope
Water crossings, snow and ice, particles (mud spray), audio, deformable mud or getting stuck, car changes, the repeat-load slowdown, and further Rally Road changes beyond the run-off.

## 11. Done when
Muddy Valley unlocks after Rally Road and can be driven from countdown to finish with mud, ruts, rough ground, the jump and the creek as described; Rally Road is unchanged apart from the run-off; all unit and scenario tests pass; screenshots have been reviewed; the build is installed on the phone for the user's session.
