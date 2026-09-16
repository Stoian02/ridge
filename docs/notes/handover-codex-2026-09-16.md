# Handover to Codex — 2026-09-16: build Milestone 4, Frozen Pass

Ridge is a 3D sim-cade off-road hill-climb for Android (Xiaomi 13), built with Godot 4.7.2, typed GDScript and Jolt physics at 120 Hz. Driving feel matters most. The owner tunes feel on the phone and there is no deadline.

## Where things stand
- **`master` at 2769b97.** Milestones 1–3 are merged and pushed to GitHub (`origin`, Stoian02/ridge).
- **Full suite:** `./run_tests.sh all` is green, with 458 passing and 1 known pending test (the held-gas jump nose-dive).
- **Uncommitted `project.godot`:** only the editor re-ordered its keys. Leave it alone.
- **The owner approved the Milestone 4 design** on 2026-09-16: `docs/superpowers/specs/2026-09-15-m4-frozen-pass-design.md`. Read it in full; it is the binding requirement. There is no implementation plan document yet.
- **Why you're doing this:** the owner wants to see how you implement this milestone. Claude Code will review the result against the spec afterwards. If it doesn't hold up, the branch will be dropped and the milestone rebuilt.

## The task
Implement the whole spec on a **new branch `m4-frozen-pass` from `master` (2769b97)**. Never commit to `master`, and never merge; the owner decides later.

In spec order:
1. **Surfaces (§6).**
   - Mud grip goes to 0.6 and soft mud to 0.7; nothing else in those files changes.
   - New `surfaces/snow.tres`, `ice.tres` and `logs.tres`.
   - New grip-table entries.
   - `TerrainDef.surface`, which `TerrainBuilder` uses to tag its collision.
   - Feel-table entries for snow, ice and logs, a `snow` sound loop in `SoundSynth`, and a snow output in `TyreSoundLogic`.
   - These surface value changes are pre-approved by the owner. Nothing else under `car/` or `surfaces/` may change.
2. **Build speed (§7).** `RoadBuilder` on worker threads, then `TerrainField.generate`'s carve loop. Results must be identical to the one-thread versions, with tests proving it. Read "Threads" below first.
3. **Tunnel (§4).** `TunnelDef`, `TrailDef.tunnels`, `TunnelBuilder` (shell, collision, portals, lamps as a MultiMesh), and the ridge and portal terrain in `TerrainField`. The chase camera must stay below the ceiling.
4. **Log bridge (§5).**
   - `BridgeDef`, `TrailDef.bridges`, and `BridgeBuilder` (logs as a MultiMesh with per-log collision tagged logs, posts, rails).
   - The step and ramp in `RoadProfile`.
   - `RoadBuilder` skipping the span.
   - The gorge cut in `TerrainField`.
   - No automatic reset in the gorge.
5. **Frozen Pass (§3).**
   - `tools/generate_frozen_pass_curve.gd` generates the curve; add it to `tests/unit/test_curve_generator.gd` like the others.
   - The rest of `levels/frozen_pass/`: scene, `LevelDef`, trail, terrain and scatter defs, and the mood and ambience values.
   - Add it as the third catalog level.
   - Add it to `debug/load_benchmark.gd`.
6. **Test Ground (§8).** Snow and ice strips, with the rough lane moved right, and signs.
7. **Tests and measurements (§9).** Every unit and scenario test the spec lists, plus the render counts, screenshots and phone load times below. Record them in `docs/notes/performance-m4.md`.

Work test-first, and commit in small, named steps.

## How to work in this repo
- **Tests:**
  - `./run_tests.sh unit|scenarios|all` imports first, and fails on any failing test or any `SCRIPT ERROR`. A full run takes about 2 minutes now.
  - Focused test: `godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<file>.gd -gexit`.
  - Run `godot --headless --import` after adding a new `class_name`.
  - A "N ObjectDB instances were leaked at exit" WARNING at the end of runs that play sound is expected. It's not a failure.
- **Typed GDScript:**
  - Every variable is typed or inferred with `:=`.
  - Values read out of a Dictionary, or chosen with an inline `a if c else b`, need an explicit type (`var x: float = ...`).
  - A loop over an array literal names its type (`for x: float in [...]`).
  - Tabs for indentation, `##` for doc comments.
- **Curves are generated, never hand-edited:** `godot --headless -s tools/generate_<level>_curve.gd`.
- **Git:**
  - Stage files by name; never `git add -A` or `git add .`.
  - Never commit or change the owner's untracked `tmux-session.sh`.
  - Commit the `.uid` files Godot creates for new scripts.
  - Don't commit `project.godot` unless you really change a setting.
- **Level builder** (`levels/trail/`), in build order inside `TrailLevel.build`:
  - `RoadProfile`: heights, including undulation, potholes, jumps and ruts.
  - `TerrainField.generate`: the height grid, corridor carve and creek cut.
  - `RoadBuilder`: road mesh and per-surface collision.
  - `ShortcutBuilder`, `TerrainBuilder` (threaded; see below), `HedgeBuilder`, `CreekBuilder`, `ScatterBuilder`, `CheckpointPlacer`.
  - Each phase is timed with `_lap()` and printed in the "built in" line; add laps for the tunnel and bridge builders.
- **Game flow:**
  - `GameState` (autoload) shows a `LoadingScreen` for levels. `SaveSandbox` turns it off in tests; keep that working.
  - `DrivingRig` owns `CarEffects` and `CarAudio`.
  - `SurfaceFeelTable` maps surface ids to spray and sound.

## Lessons that will bite you
- **Threads:** calling a shared GDScript object's methods (or even reading many of its members) from `WorkerThreadPool` tasks serializes them. A probe measured 1.18× on 4 threads, against 2.82× for the same maths on locals.
  - **Pattern (see `TerrainBuilder`):** copy the shared data into locals once per task, and do the maths inline.
  - **Per-task results:** give each task its own pre-created Dictionary.
  - **Shared caches:** fill them before the tasks start.
  - **Nodes and meshes:** make them on the main thread, in the same order as before, so results match the one-thread build exactly.
  - `TerrainBuilder.threaded` is the switch its tests use to compare the two builds.
- **Sound:**
  - Synthesized loops must keep `SoundSynth.LOOP_PAD` tail frames after `loop_end`, or the phone's audio thread crashes (SIGSEGV) at the loop's first wrap.
  - `CarAudio` and `LevelAmbience` stop their players in `_exit_tree`; without that, the full suite hangs.
  - Tests run with the Dummy audio driver, so only the phone proves sound works.
- **Mesh normals** come back slightly rounded from an `ArrayMesh`, so compare them with a tolerance.
- **Draw calls:** each `Label3D` and each visible `CPUParticles3D` costs draw calls. Merge static meshes; use `visibility_range_end` for small labels.
- **Side walls:** raised `RoughPatch` strips now have side walls. Keep any new raised geometry closed on its sides, since the owner noticed gaps before.

## Measuring
- **Desktop render counts and screenshots** (needs the display; prefix with `DISPLAY=:1 WAYLAND_DISPLAY=wayland-1` if the shell lacks it):
  ```
  godot --path . res://tools/level_shots.tscn -- res://levels/frozen_pass/frozen_pass.tscn 15 450 850 1200 1300 1420 1800 car=offroad_4x4
  ```
  Budgets: < 300k primitives and < 150 draw calls on screen. PNGs land in `build/`, which is not committed.
- **Desktop load benchmark:** `godot --headless --path . -- --benchmark`.
- **Phone:**
  1. Build and install with `tools/android.sh build` then `tools/android.sh install`.
  2. Close the app (`adb shell am force-stop com.ridge.game`) and drop the benchmark flag: `adb shell run-as com.ridge.game touch files/benchmark`.
  3. Start logging with `adb logcat -v time -s godot:V > /tmp/claude-1000/<log>` (the device log is very busy), then launch with `adb shell am start -n com.ridge.game/com.godot.game.GodotAppLauncher`.
  4. Wait for "benchmark done".

  Android ignores launch arguments for this app, so the flag file is the only trigger. Targets: Frozen Pass ≤ 3.0 s, Muddy Valley ≤ 2.0 s, Rally Road ≤ 1.3 s. Today they are Muddy Valley 2.41–2.63 s and Rally Road 1.38–1.52 s.
- **Crash logs:** `adb logcat -d -b crash`.

## When you are done
1. **Full suite:** it must be green on the branch.
2. **Report:** write `docs/notes/codex-report-m4.md` and commit it on the branch. It should cover:
   - what you built, file by file
   - any place you departed from the spec, and why
   - the test counts
   - the render counts, and desktop and phone load times
   - known issues
3. **Phone:** install the build for the owner to drive.
4. **Stop there.** Don't merge; Claude Code reviews next.
