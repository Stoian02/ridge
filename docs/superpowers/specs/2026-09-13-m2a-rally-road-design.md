# Ridge Milestone 2, Part A — Rally Road: Design Spec

**Date:** 2026-09-13
**Status:** Draft for review
**Parent spec:** `docs/superpowers/specs/2026-09-11-ridge-design.md` (binding; this document refines its Milestone 2 for Part A)
**Builds on:** Milestone 1 (merged to `master`, signed off 2026-09-13); feel carry-overs in `docs/notes/feel-log.md`

---

## 1. Summary

Part A turns the Test Ground prototype into a real track. It adds a **trail builder** that generates a road, mountain terrain, scenery and checkpoints from a single road curve, and uses it to build **Rally Road**: a ~1.5 km asphalt mountain climb. It also adds the systems a timed run needs: countdown, run clock, ordered checkpoints, and resets. The goal is a track the user can practise and tune the car on, on the phone.

Milestone 2 is split in two:
- **Part A (this spec):** trail builder, Rally Road, checkpoints, resets, run clock, run HUD, shared driving rig, Track switch.
- **Part B (later spec):** Muddy Valley, stars and results screen, level select, pause menu, save data.

## 2. Decisions from the design conversation

| Question | Decision |
|---|---|
| How to split Milestone 2 | Track first: Part A = trail builder + Rally Road + checkpoints + resets + run clock |
| Rally Road character | Mountain climb: sweeping bends low, 2–3 hairpins near the top, two small jumps, rock cuts uphill, drop-offs downhill, golden-hour valley view |
| Road edges | Soft: dirt shoulders and drivable terrain beyond |
| Automatic resets | Only when the car falls off the map, or stays flipped for 2 s; otherwise the Reset button |
| Asphalt roughness | Mostly smooth with gentle undulation, occasional pothole/patch clusters, one rougher stretch |
| Who builds the track | Claude builds all of it; the user may adjust road curve points in the Godot editor if needed |
| Visual polish | Stylized basics: sculpted terrain, road with painted edge lines, low-poly pines, rocks and roadside posts in the Over the Hill palette |
| Build approach | Generate everything from the road curve (approach A); reusable for every later level |
| Phone testing | At the end of Part A; development is verified by headless tests and desktop screenshots |

## 3. Player experience

### 3.1 A run
1. The car waits on the start line, held by its brakes.
2. A **3-2-1** countdown shows; the pedals do nothing until **GO**, when the clock starts.
3. The car passes checkpoint gates in order. Each shows the run time briefly, with the difference from the session-best time at that gate.
4. The finish gate stops the clock and shows a **finish panel**: run time, session best, and **Restart**.
5. **Restart** puts the car back on the start line and runs the countdown again.
6. After the finish the car can keep driving with the clock stopped.

### 3.2 Resets
Every reset places the car upright and stopped at the **last passed checkpoint** (the start line is checkpoint 0), snaps the camera behind it, and **leaves the clock running**. Triggers:
- **Reset button** (top strip, and R / gamepad Y as in Milestone 1).
- **Flipped:** the car's up direction is more than **70°** from world up, and its speed is below **2 m/s**, continuously for **2 s**. Wheel contact is not required (a car on its side often has a wheel touching).
- **Fell off the map:** the car's height is below the level's **kill height** (lowest terrain height − 30 m).

A reset during the countdown returns the car to the start line and restarts the countdown. A reset after the finish returns the car to the finish gate.

### 3.3 Soft edges
The road has **dirt shoulders**, and the terrain beyond them is drivable. The player can run wide, cut across, or slide down a slope; nothing resets them for leaving the road.

### 3.4 Track switching
A **Track** button in the top strip switches between Rally Road and the Test Ground (the tuning ground stays one tap away). Rally Road becomes the project's main scene. Part B's level select replaces this button.

## 4. Architecture

Everything is generated from **one road curve** and a few small resources, with a fixed seed, so the same inputs always build the same level.

```
Path3D (road centreline)  ─┐
TrailDef, TerrainDef,      │
ScatterDef (resources)    ─┼─► RoadSampler ─► RoadBuilder ────► road chunks (mesh + collision)
                           │        │
                           │        ├──────► TerrainBuilder ──► terrain chunks (mesh + collision)
                           │        ├──────► ScatterBuilder ──► pines, rocks, posts (MultiMesh)
                           │        └──────► CheckpointPlacer ► gates (Area3D + visuals + reset transforms)
                           │
Level root (rally_road.gd) ┴─► DrivingRig (Car, ChaseCamera, TouchControls, TelemetryOverlay, RunRecorder)
                              RunController (RunClock) ◄─► CheckpointTracker ◄─► ResetController ─► RunHud
```

### 4.1 Files and responsibilities

Folders follow the parent spec §9, extended with `levels/trail/`.

| File | Kind | Responsibility |
|---|---|---|
| `levels/trail/trail_def.gd` | Resource | Road settings: widths, sample step, undulation, rough sections, pothole clusters, jumps, checkpoint distances, road palette |
| `levels/trail/terrain_def.gd` | Resource | Terrain settings: extent past the road, chunk size, sample spacing, base elevation shape, noise, corridor blend width, seed, palette |
| `levels/trail/scatter_def.gd` | Resource | Scenery settings: densities, exclusion distance, max slope, post spacing, seed |
| `levels/trail/road_sampler.gd` | RefCounted | Position, heading, right and up vectors at a distance along the road; nearest road distance and lateral offset for a world point (grid-accelerated) |
| `levels/trail/road_profile.gd` | Pure static | Road surface height offset at (distance, lateral): undulation + rough detail + jumps |
| `levels/trail/corridor.gd` | Pure static | Terrain carving blend toward shoulder height as a function of lateral distance |
| `levels/trail/road_builder.gd` | Node3D | Builds road chunks: mesh with edge lines, collision, surface tags |
| `levels/trail/terrain_builder.gd` | Node3D | Builds terrain chunks: heightmap collision + mesh, carved to the road |
| `levels/trail/scatter_builder.gd` | Node3D | Places pines, rocks and posts as MultiMesh instances |
| `levels/trail/checkpoint_placer.gd` | Node3D | Creates checkpoint gates at road distances, with reset transforms |
| `levels/trail/low_poly_meshes.gd` | Pure static | Generates low-poly pine, rock, post and gate meshes with vertex colours |
| `levels/shared/rough_shapes.gd` | Pure static | The pothole bowl, speed-bump and washboard shape functions, shared by `RoughPatch` and `RoadProfile` |
| `levels/trail/trail_level.gd` | Node3D | Runs the builders in order on load; editor rebuild button (`@tool`) |
| `game/run_clock.gd` | RefCounted | Run stages, elapsed time, checkpoint splits, session best |
| `game/checkpoint_tracker.gd` | Node | Ordered gate progress, reset transform, checkpoint and finish signals |
| `game/flip_detector.gd` | RefCounted | Flipped-for-2-s detection from tilt, speed and time |
| `game/reset_controller.gd` | Node | Watches for Reset button, flip, fall; performs resets |
| `game/run_controller.gd` | Node | Countdown, pedal lock, clock updates, restart |
| `ui/run_hud.gd` | CanvasLayer | Countdown, running time, checkpoint flash, finish panel |
| `levels/shared/driving_rig.tscn` | Scene | Car, ChaseCamera, TouchControls, TelemetryOverlay, RunRecorder, pre-wired |
| `levels/shared/level_switcher.gd` | Static helper | Switch between the Rally Road and Test Ground scenes (uses the scene tree) |
| `levels/rally_road/rally_road.tscn`, `.gd` | Scene | Rally Road: mood, road curve, resources, builders, rig, run systems |
| `levels/rally_road/rally_road_trail.tres`, `_terrain.tres`, `_scatter.tres` | Resources | Rally Road's settings |

Changes to Milestone 1 code:
- `input/car_input.gd`: a `locked` flag; while set, `refresh()` outputs zero steer/throttle and full brake.
- `input/touch_controls.gd`: a **Track** button and `track_switch_requested` signal.
- `levels/test_ground/test_ground.tscn` / `.gd`: use `driving_rig.tscn` instead of wiring the car, camera, controls, telemetry and recorder itself.
- `levels/test_ground/rough_patch.gd`: its pothole, bump and washboard shape maths move into `levels/shared/rough_shapes.gd` (the Test Ground layout constants stay in `RoughPatch`); behaviour and its tests are unchanged.

## 5. Trail builder

### 5.1 Road curve and sampler
- The road centreline is a `Path3D`; its points carry position and elevation. Curve tilt allows gentle banking, at most 5°.
- `RoadSampler` bakes the curve at `sample_step` (1 m) and answers: position, heading (forward), right, up, and elevation at any distance; and, for a world point, the nearest road distance and signed lateral offset. Nearest-point queries use a 2D grid of baked samples (cell size 16 m) so terrain carving and scatter stay fast.

### 5.2 Road profile (surface height)
`RoadProfile.height(distance, lateral)` returns the offset added to the curve elevation:
- **Undulation along the whole road:** amplitude **±0.05 m**, wavelengths **20–40 m** (two summed sines with fixed phases from the seed).
- **Rough sections** (from `TrailDef.rough_sections`: start, length, profile): high-detail offsets built from the shared `RoughShapes` functions (pothole bowls, patch edges, washboard) placed by the section's own seeded layout, sampled at **0.25 m** only inside those ranges, tapering in and out over 3 m.
- **Pothole clusters** (from `TrailDef.pothole_clusters`): short 10–20 m detail ranges with a few potholes.
- **Jumps** (from `TrailDef.jumps`: distance, height, length): a crest shaped into the road, rising over the first 70% of its length and dropping over the rest.

### 5.3 Road mesh and collision
- Cross-section, left to right: shoulder (2.5 m), road (7 m), shoulder (2.5 m). Painted edge lines are 0.15 m wide, 0.3 m inside each road edge, made with extra vertices and vertex colours.
- Cross-sections every 1 m, and every 0.25 m inside rough sections and pothole clusters.
- Built in **chunks of ~100 m** of road. Each chunk has one mesh and two collision bodies: the road (`ConcavePolygonShape3D`, tagged **asphalt**) and the shoulders (tagged **dirt**).
- Shading: asphalt a dark warm grey, patches slightly different, potholes and bump crests shaded as in `RoughPatch`.

### 5.4 Terrain
- Covers the road's bounding box plus **300 m** on every side.
- **Chunks of 128 m × 128 m**, sample spacing **2 m**, each with `HeightMapShape3D` collision (tagged **dirt**) and a mesh. Chunks share their border samples so there are no seams.
- **Base shape:** a mountainside rising along the road's overall climb direction, plus fractal noise (amplitude 20 m, base wavelength 200 m, 4 octaves) from the seed.
- **Corridor carving:** for samples within `corridor_blend` (**25 m**) of a shoulder edge, the height blends from the shoulder height (at the edge) to the natural terrain height (at 25 m) with a smoothstep. Uphill this cuts a slope; downhill it builds an embankment that falls away to the natural terrain. Under the road itself, terrain sits **0.3 m below** the road surface so it never pokes through.
- Mesh vertex colours by slope: ochre dirt on gentle ground, grey-orange rock on slopes steeper than 35°.
- Each terrain chunk mesh gets a visibility range so distant chunks are skipped; the fog hides the cut-off.
- **Kill height** = lowest terrain sample − 30 m.

### 5.5 Scenery
- **Pines** (1 per ~150 m²) and **rocks** (1 per ~300 m²) scattered with the seed, only on slopes under 35°, and never within **6 m** of a shoulder edge.
- **Roadside posts** every **25 m** along the outer edge of the downhill shoulder, wherever the terrain drops more than 2 m within 10 m of the edge.
- Low-poly meshes generated in code (pine: stacked cones on a trunk; rock: jittered low-subdivision sphere; post: box with a reflector band), drawn as one `MultiMeshInstance3D` per mesh type per terrain chunk. No collision for pines and posts in Part A; rocks near the road get simple sphere collision.

### 5.6 Checkpoints
- Gates at `TrailDef.checkpoint_distances` (metres along the road, including 0 for the start and the road length for the finish).
- Each gate: an `Area3D` box across the road and both shoulders (12 m wide, 6 m tall, 2 m deep), two low-poly posts with a banner (start, checkpoint number, or finish), and a **reset transform**: on the road centre at that distance, facing along the road, 1 m above the surface.

### 5.7 Build timing and editing
- `TrailLevel` runs the builders in order when the level loads: sampler → road → terrain → scenery → checkpoints.
- In the editor, `TrailLevel` is a `@tool` script with a **Rebuild** checkbox, so after moving curve points the user can preview the result.
- **Load-time budget:** under 3 s on the Xiaomi 13. Development measures desktop build time for every change. If the phone exceeds 3 s at the end of Part A, the fallback is baking the generated chunks into resource files at edit time (a separate follow-up, not built unless needed).

## 6. Run systems

### 6.1 RunClock (pure logic)
- Stages: `READY → COUNTDOWN → RUNNING → FINISHED`. `start_countdown()` goes to COUNTDOWN; after 3 s `tick()` moves to RUNNING (elapsed = 0); `pass_checkpoint(index)` records a split; `finish()` goes to FINISHED and updates the session best; `restart()` returns to READY.
- Exposes: `stage`, `countdown_remaining`, `elapsed`, `splits`, `session_best_time`, `session_best_splits`, and the split delta for the most recent checkpoint.

### 6.2 CheckpointTracker
- Holds the gates in order; `next_index` starts at 1 (the start gate is 0).
- A gate counts only when the car enters it and its index equals `next_index`. Emits `checkpoint_passed(index)`, and `finished()` for the last gate.
- `reset_transform()` returns the transform of the last passed gate; `restart()` returns to gate 0.

### 6.3 FlipDetector and ResetController
- `FlipDetector.update(delta, up_vector, speed) -> bool` accumulates time while tilt > 70° and speed < 2 m/s, and resets the timer otherwise; true once the time reaches 2 s.
- `ResetController` resets the car on: `CarInput.reset_requested`, `FlipDetector` true, or car height below the kill height. A reset calls `car.reset_to(tracker.reset_transform())`, snaps the camera, and clears the flip timer. During COUNTDOWN a reset triggers a restart instead.

### 6.4 RunController
- On level start and on Restart: reset the car to gate 0, set `CarInput.locked = true`, start the countdown.
- At GO: `locked = false`, clock RUNNING.
- Forwards tracker signals into the clock; on finish, the clock stops and the HUD shows the finish panel.

### 6.5 RunHud
- Countdown numbers large and centred (3, 2, 1, GO).
- Running time top-centre (`m:ss.t`).
- On a checkpoint: "CP 2  0:41.3  −1.2" for 2 s, green when faster than the session best at that gate, red when slower, no delta on the first run.
- Finish panel: "Finish 1:32.4", "Session best 1:30.9", and a Restart button.
- Same text style as the telemetry overlay; hidden elements never block touch input.

## 7. Rally Road

### 7.1 Layout
Target length **1500 m (±10%)**, elevation gain **~160 m**, maximum grade **12%**.

| Distance | Section |
|---|---|
| 0–80 m | Start straight in the valley; start gate at 0 m |
| 80–600 m | Long sweeping climb with gentle bends; **pothole cluster** near 250 m; **jump 1** over a crest at ~450 m (height 1.2 m, length 12 m); checkpoint at 300 m |
| 600–850 m | Checkpoint at 600 m; the **rough stretch** (patched and potholed tarmac) from 680 to 830 m |
| 850–1300 m | Steeper esses, then **three hairpins** (centreline radius 14–16 m, banked up to 5°) switching back up the mountainside; checkpoints at 900 and 1200 m; **pothole cluster** near 1050 m |
| 1300–1500 m | Ridge straight with **jump 2** at ~1380 m (height 1.0 m, length 10 m); finish gate at the end, overlooking the valley |

Rock cuts on the uphill side of the hairpins and esses; drop-offs with posts on the downhill side.

### 7.2 Look
- Golden-hour mood from Milestone 1 (`GoldenHourMood`), with the sun low ahead of the driver in the upper section.
- Palette: asphalt dark warm grey (0.24, 0.23, 0.24); edge lines off-white (0.92, 0.9, 0.84); dirt ochre (0.62, 0.47, 0.3); rock grey-orange (0.55, 0.45, 0.38); pines olive (0.33, 0.4, 0.24); posts white with an orange reflector band.

## 8. Performance budgets (Xiaomi 13, measured at the end of Part A)

| Measure | Budget |
|---|---|
| Frame rate | held 60 fps while driving the whole road |
| Triangles on screen | < 300k |
| Draw calls | < 150 |
| Physics time | < 4 ms |
| Level load | < 3 s |

During development: desktop build time, triangle and draw-call counts (from Godot's rendering monitors) are recorded for Rally Road after each visual change.

## 9. Testing

### 9.1 Unit tests
- `RoadProfile`: undulation amplitude bounds, rough-section taper to zero at range ends, jump crest height and shape.
- `RoadSampler`: distance → position round trip; nearest-distance and lateral offset for points beside the road; heading continuity.
- `Corridor`: blend is shoulder height at the edge, natural height at 25 m, monotonic between.
- `CheckpointPlacer`: gate count and distances; reset transform on the road and facing along it.
- `RunClock`: stage transitions, countdown length, splits, finish, session best, restart.
- `CheckpointTracker`: in-order counting, skipped gates ignored, reset transform follows progress, restart.
- `FlipDetector`: triggers only after 2 s of tilt > 70° at < 2 m/s; resets on recovery or speed.
- `CarInput.locked`: zero steer/throttle and full brake while locked.
- `LowPolyMeshes`: meshes are non-empty with upward-facing normals where expected.

### 9.2 Scenario tests (headless)
- **Drive the whole road:** a pure-pursuit test driver (steer toward a point ~12 m ahead on the road, speed target by curvature) completes Rally Road with every checkpoint in order, **no resets**, in **60–150 s**.
- **Flip reset:** a car placed upside down on the road resets to the last checkpoint within 2.2 s.
- **Fall reset:** a car teleported below the kill height resets.
- **Reset button:** `request_reset()` returns the car to the last checkpoint with the clock still running.
- **Countdown lock:** throttle held during the countdown does not move the car.
- **Jump landing** (carried over from the Milestone 1 final review): on the Test Ground kicker with throttle held, the car lands upright with no yaw spike above 20°/s in the 0.5 s after landing.
- **Seams:** the car drives across road-chunk and terrain-chunk borders without a wheel losing contact.
- **Build determinism and time:** building Rally Road twice gives identical chunk counts and checkpoint positions; desktop build time is printed.

### 9.3 Visual checks
Screenshots (via `tools/screenshot.sh` with a camera placed by a throwaway scene) at the start, jump 1, the rough stretch, a hairpin, jump 2 and the finish; reviewed before hand-off.

## 10. Verified during plan writing (before tasks are dispatched)

- Wheel sphere casts against `ConcavePolygonShape3D` road collision under Jolt (smooth contact, correct surface meta).
- Crossing borders between trimesh road chunks and between `HeightMapShape3D` terrain chunks (no contact loss).
- Desktop build time for a Rally-Road-sized level, and whether the nearest-road grid keeps terrain carving fast.
- `MultiMeshInstance3D` visibility ranges per chunk on the Mobile renderer.

## 11. Out of scope for Part A

Stars and target times, results screen, level select, pause menu, save data, Muddy Valley, particles, audio, and further car tuning. Feel tuning on Rally Road (the Milestone 1 carry-overs) happens in sessions after Part A is on the phone.

## 12. Done when

Rally Road loads on the Xiaomi 13 in under 3 s and holds 60 fps; the user can drive it from countdown to finish, with checkpoints, resets and the clock working as in §3; the Track button switches to the Test Ground and back; all unit and scenario tests pass, including the whole-road drive and the jump-landing test.
