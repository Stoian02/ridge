# Handover to Codex — 2026-09-14

Ridge is a 3D sim-cade off-road hill-climb for Android (Xiaomi 13), built with Godot 4.7.2, typed GDScript and Jolt physics at 120 Hz. Driving feel matters most. The owner tunes feel on real tracks and there is no deadline.

## Where things stand
- **Branch `m2b2-muddy-valley`** at d30a4b2 is **not merged**. It is 9 commits on top of `master` (bd56188) and adds Milestone 2 Part B2, Muddy Valley.
  - Spec: `docs/superpowers/specs/2026-09-14-m2b2-muddy-valley-design.md`
  - Plan: `docs/superpowers/plans/2026-09-14-m2b2-muddy-valley.md`
  - Performance notes: `docs/notes/performance-m2b2.md`
- `./run_tests.sh all` is green on the branch: 349 passing, 1 known pending test (held-gas jump nose-dive).
- Every task passed its review, and a final whole-branch review found one issue, which has been fixed. The deferred minor findings are listed at the end of this note.
- The owner drove two desktop runs: "the track is amazing, very bumpy, a lot harder to control the car, which is what I wanted". Everything else "feels and looks very good".

## Open request (do this first, then ask the owner about merging)
**Players can skip the mud.**
- In run `~/.local/share/godot/app_userdata/Ridge/runs/run_2026-09-14T18-54-18.csv` the car drove round every mud stretch on the left: first on the 2.5 m dirt shoulder (−4.5 to −7 m from the centre line), then on the grass, out to −9.4 m on the final climb.
- Its wheels were on mud 4 of 324 wheel-samples on 760–850 m, 8 of 252 on 980–1050 m, and 109 of 740 on 1300–1500 m.
- It finished in 75.7 s, against 95.1 s for the run that went through the mud (18:52).
- Re-run the analysis with `python3 tools/mud_skip.py levels/muddy_valley/muddy_valley_curve.tres <run.csv>...`.

**Why:**
- `RoadBuilder` always gives the shoulders dirt collision.
- The terrain beyond them is dirt too.
- There's nothing to stop a car driving beside a mud stretch.

**The owner asked for** a fence and/or bushes that can't be driven through beside the mud, "maybe leave like a part you actually can go through, like a hidden shortcut".

**Draft design (not yet approved by the owner — present it and get a yes before building):**
1. **Mud verges:** inside a surface stretch, the shoulder rows take the stretch's surface (mud collision, mud-blended colour) instead of dirt. Change `RoadBuilder._add_chunk`/`_faces` so shoulder faces are grouped by row surface too. Rally Road has no stretches, so `tests/unit/test_rally_road_regression.gd` must stay green unchanged.
2. **Hedges:**
   - A new `TrailDef.hedges: Array[Vector3]` holds (start distance, length, side −1 left / +1 right).
   - A new `HedgeBuilder` places low bushes just outside the shoulder edge: lumpy balls from `LowPolyMeshes._add_lumpy_ball`, dark green, about 1.2 m, every ~1.6 m, one MultiMesh per terrain chunk.
   - Collision is a continuous thin box wall per ~10 m segment following the road, tagged dirt, so a car can't squeeze between bushes.
   - `TrailLevel` builds it after the terrain.
   - Scatter already keeps trees and rocks 6 m from the shoulder edge.
3. **Muddy Valley hedges:**
   - Both sides of 760–850 m and 980–1050 m, a few metres past each end. On the right of 760–850 m the creek is 17 m out, so the hedge sits between the road and the creek.
   - Both sides of the final climb, 1300–1500 m.
4. **Hidden shortcut:**
   - On the left of the final climb, leave an entry gap at ~1390 m and an exit gap at ~1475 m, with overlapping bushes offset outward so the gap isn't obvious from the road.
   - The grass strip behind the hedge is clear of scenery and drivable (run 2 did 79 km/h there).
   - It should save part of the climb, not all of it. Tune the gap positions by driving it.
5. **Tests:**
   - Unit:
     - shoulder collision is mud inside a stretch and dirt outside it
     - hedge bushes and wall are placed along the section only
     - there's no wall at a gap
   - Scenario: a car placed on the left verge before 980 m and driven along the road can't avoid mud (a wheel on mud, or the hedge stops it).
   - Scenario: the scripted driver still finishes with no resets.
   - Scenario: a car through the shortcut's entry gap reaches the exit gap.
   - Re-measure render counts with `godot --path . res://tools/level_shots.tscn -- res://levels/muddy_valley/muddy_valley.tscn 15 320 560 760 1000 1250 1450`. Budget: < 300k primitives, < 150 draw calls. Muddy Valley currently peaks at 273,964.

## After that
1. **Merge:** ask the owner — merge `m2b2-muddy-valley` into `master` locally (they have always chosen that), open a PR (there is no remote), or keep the branch.
2. **Phone session:** reinstall with `tools/android.sh`; the owner tests on the phone.
   - The creek's road-side bank can't be climbed from a standstill; the owner said "leave it like that and I will test".
   - Mud feel.
   - Real star times: placeholders are 95 s (2 stars) and 85 s (3 stars) in `levels/muddy_valley/muddy_valley_level.tres`. Rally Road's are 80/72.
   - Load times with `adb logcat -d -s godot | grep "built in"`.
   - Recordings: `tools/pull_runs.sh` copies them to `./runs`.
3. **Investigate the repeat-load slowdown** (the owner asked for this after B2). Rally Road built in 2.83 s after a fresh app start, but 4.4–5.2 s on later loads in the same session (`docs/notes/performance-m2a.md`). Measure the build phases on repeat loads before choosing a fix. A likely cause is building while the previous level's nodes are still being freed.
4. **Milestone 3** (plan it with the owner first): more cars, including tuned versions of the stock Subaru; snow, ice and water crossings; car select; audio and art. Parked feel items are in `docs/notes/feel-log.md`:
   - slide recovery off the dirt shoulder
   - the held-gas jump nose-dive (pending test)

## How to work in this repo
- **Tests:** `./run_tests.sh unit|scenarios|all`. It imports first and fails on any failing test or `SCRIPT ERROR`. A full run takes ~10–15 min. Focused test: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<file>.gd -gexit`. The shell is zsh: write commands out in full, and don't put multi-word commands in variables.
- **Typed GDScript:** every variable is typed or inferred with `:=`. When a value comes from an untyped array literal, name the loop variable's type (`for x: float in [...]`), or `:=` inference on it fails to compile. Indent with tabs; doc comments use `##`.
- **Curves are generated, never hand-edited:** `godot --headless -s tools/generate_<level>_curve.gd`; segments live in the tool, shared code in `tools/curve_generator.gd`. `tests/unit/test_curve_generator.gd` checks saved curves against their tools.
- **Git:**
  - Work on a branch and merge locally only when the owner says so.
  - Stage files by name. Never `git add -A` or `git add .`.
  - Never commit or change the owner's untracked `tmux-session.sh`.
  - Commit the `.uid` files Godot creates for new scripts.
- **Ask before changing car physics** (anything under `car/`, `surfaces/*.tres` values, or `car/rally_car.tres`).
- **The owner's working style:**
  - Brainstorm → spec → plan, then implement task by task with tests.
  - They want to hear the plan before big changes.
  - When they say "stop", finish the step in progress, commit, and write resume notes.
- **Level builder layout:** `levels/trail/`
  - `TrailDef` holds the settings.
  - `RoadProfile` computes heights: undulation, potholes, jumps, ruts.
  - `RoadBuilder` makes the road mesh and per-surface collision.
  - `TerrainField` and `TerrainBuilder` make the terrain; the creek channel is cut in `TerrainField._cut_creek`.
  - `CreekBuilder` lays the water.
  - `ScatterBuilder` places trees, rocks and posts.
  - `CheckpointPlacer` places the gates.
  - `TrailLevel` builds them all in order.
  - Game flow (catalog, save, stars) lives in `game/` and `levels/catalog.tres`.

## Deferred minors from the B2 reviews (all judged safe to leave)
- `road_profile.gd` repeats the `for end: float in [stretch.start, stretch.end()]` loop in `_init` and `surface_boundaries`.
- `TrailDef`'s "stretches must not overlap" rule is documented but not enforced.
- Two untyped loops over array literals: `road_builder.gd` (`for corner in [...]`) and `tests/unit/test_road_builder.gd` (`for check in [...]`).
- `CurveGenerator.generate()` prints "saved" even when the save fails, and has no unit test.
- In `terrain_field.gd`, the doc comment for `creek_levels` sits above `creek_start`.
- `test_scenery_keeps_out_of_the_creek` doesn't separate creek clearance from road clearance.
- `muddy_valley_trail.tres` repeats the same mud colour and rut depth in its three stretches.
- `tools/level_shots.gd` has no guard for a scene that isn't a `RunLevel`.
