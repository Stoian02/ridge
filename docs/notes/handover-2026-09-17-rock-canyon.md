# Handover — Milestone 5, Rock Canyon (2026-09-17)

Written by Claude for the next session. Read this first, then the spec.

## 1. Where things stand

- **Branch:** `master`, at `613ac40` (the Rock Canyon spec commit). Master is **10 commits ahead of `origin/master`** — the owner pushes themselves; do not push.
- **`project.godot` is modified** in the working tree. It is an editor re-save with no meaningful change; it has been deliberately left uncommitted for weeks. Leave it alone.
- **`tmux-session.sh` is untracked and belongs to the owner.** Never stage, modify or delete it.
- **Milestones 1–4 are merged.** Rally Road, Muddy Valley and Frozen Pass all playable; cars, car select, surface feedback and sound, threaded terrain, loading screen, traction-control slider.
- **Test suite on master:** 488 passing, 1 pending. `./run_tests.sh all` takes about 2–2.5 minutes.

## 2. The open request

Build **Milestone 5: Rock Canyon**, per the approved spec:

**`docs/superpowers/specs/2026-09-17-m5-rock-canyon-design.md`**

Every section of it was approved by the owner section by section in the design conversation. Its §2 table records the decisions and their reasons. The owner has **not** yet read the written spec end to end — the first thing to do in the new session is ask them to review it, then proceed.

### The immediate next steps

1. Ask the owner to review the spec file (the brainstorming skill's user-review gate).
2. Invoke **`superpowers:writing-plans`** to turn it into `docs/superpowers/plans/2026-09-17-m5-rock-canyon.md`.
3. Then go straight to **`superpowers:subagent-driven-development`** on a new branch, `m5-rock-canyon`. The owner has said before: after a plan is approved, do not stop to ask again — start the subagent work.

### Task ordering that the spec assumes

The **road width profile lands first, on its own** (spec §5.3). It touches `RoadBuilder`, `RoadSampler`, `TerrainField`'s corridor, `ScatterBuilder` and `CheckpointPlacer`, and the existing three levels must be proven unchanged before anything else is built on top. After that the new builders (rock steps, boulders, talus, ford, canyon walls) are largely independent of each other, then the level data and curve, then the throttle lever, then tuning.

## 3. Standing rules from the owner

- **Ask before changing car physics** — anything under `car/`, or the values in existing `surfaces/*.tres`. Milestone 5 adds *new* surface files and new grip-table entries, which is approved; it changes no existing value.
- **Work on a branch.** Merge to master only when the owner asks. Never push.
- **Stage files by name.** Never `git add -A` or `git add .`.
- **Commit messages** end with a blank line then:
  ```
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01RhfJavT34eWyW3enLLKWgH
  ```
  (the session line changes per session — use the one in the current attribution reminder).
- **On "stop":** finish the in-flight step, commit it, write resume notes, start nothing new.
- **Do not run Godot tests, benchmarks or screenshot captures while the owner is playing the game.** Two Godot instances freeze the second one — this cost two long debugging detours. Check with `ps -eo pid,args | grep "godot --path ."` first, and never kill the owner's process.

## 4. How to work in this repo

### Tests

```bash
./run_tests.sh unit          # fast
./run_tests.sh scenarios     # driving tests, slower
./run_tests.sh all           # ~2-2.5 min; must be green, with no SCRIPT ERROR
```

One file:

```bash
godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_road_builder.gd -gexit
```

After adding a new `class_name`, run `godot --headless --import` once or the class won't resolve.

### Phone

```bash
tools/android.sh build|install|run|logs
adb logcat -d -b crash                     # after a crash
adb shell run-as com.ridge.game touch files/benchmark   # then launch normally
```

Android drops launch arguments, which is why the benchmark uses a flag file.

### Screenshots

Need `DISPLAY=:1 WAYLAND_DISPLAY=wayland-1` in the environment. `tools/level_shots.gd`/`.tscn` renders level views.

## 5. Hard-won lessons — do not relearn these

- **Threading:** calling a shared GDScript object's methods from `WorkerThreadPool` tasks *serializes* them (measured: 1.18× on 4 threads, versus 2.82× for inlined maths). Copy shared data into locals, inline the maths, pre-create per-task dictionaries, and create nodes on the main thread. This is how terrain build went from 0.79 s to 0.044 s. `terrain_builder.gd` is the worked example.
- **Audio:** every looping sound needs the `LOOP_PAD = 32` frame tail after `loop_end`, or the phone hits SIGSEGV at the first loop wrap. Players must be stopped in `_exit_tree()`, or the test suite hangs. "ObjectDB instances leaked at exit" is an engine exit artifact, not a bug.
- **Typed GDScript:** values out of `Dictionary`, and inline `a if c else b`, need explicit types; loop variables over array literals need typing (`for side: float in [-1.0, 1.0]`). Tabs, `##` doc comments.
- **Mesh normals are stored compressed** — compare with `distance_to(...) < 0.01`, never `is_equal_approx`.
- **`amount_ratio` does not exist on `CPUParticles3D`** in 4.7; scale spray strength through alpha and base velocity instead.
- **Draw calls are the phone budget that bites**, not triangles. Merge meshes, use `MultiMesh`, set `visibility_range_end`. Budgets: <300k primitives, <150 draw calls, 60 fps, <3 s load.
- **zsh eats bare `====`** in `echo` (equals-expansion). Quote separators in shell commands.

## 6. The codebase in one paragraph

Levels are data plus generators. `TrailLevel` (`levels/trail/trail_level.gd`) reads a `TrailDef`, `TerrainDef` and `ScatterDef` plus a generated `Path3D` curve, and runs the builders in order: `RoadSampler` → `RoadProfile` → `TerrainField` → `RoadBuilder` → tunnels → bridges → shortcut → terrain → hedges → creek → scatter → checkpoints, timing each into `build_phases`. Curves are generated by `tools/generate_<level>_curve.gd` on top of `tools/curve_generator.gd` and are never hand-edited. Surfaces are `SurfaceDef` resources (physics) paired with `SurfaceFeel` (looks and sound); `GripTable` multiplies grip per car archetype per surface. Effects and audio live in `effects/`, all sound synthesized in `SoundSynth`. Game flow is the `GameState` autoload plus `Progress` (settings and saves).

`TunnelDef`/`TunnelBuilder` and `BridgeDef`/`BridgeBuilder` (Milestone 4) are the pattern every new Rock Canyon structure should copy: a small resource on `TrailDef`, a builder node that owns its meshes and collision, and its own unit tests.

## 7. Open items, unrelated to Milestone 5

- Frozen Pass star times stay at 135/120 s. The owner's best is 1:59.8 with traction control, corner cuts and a wall-ride; they chose to keep it as the one hard level.
- The Muddy Valley "reversing in the mud" report was never reproduced; the owner asked for it to be marked addressed. Leading hypothesis: on/off pedals 30 px apart plus `_choose_direction` picking reverse below 1 m/s. The throttle lever in Milestone 5 may well make this moot.
- `test_jump_landing` reads the real save's selected car rather than a fixed one.
- `GameState.set_sound_volume` does not enforce `SOUND_STEPS`.
- Further road/field build speed-ups are possible but not needed yet.

## 8. Milestone 5 at a glance

Four segments over 2.1 km, about 4:30: asphalt approach → deep mud gully → boulder wash (rock steps, boulder fields, talus) → ford under a waterfall → narrow shelf climb to the rim. New: four surfaces (deep mud, rock, scree, wet rock), a road width profile, canyon walls in the terrain, a throttle lever control mode, two new sounds. The 4x4 gets through; the rally cars beach, and that is intended and documented rather than prevented. The loose talus field is provisional until the phone check. Water physics, a new car and car locking are all out of scope.
