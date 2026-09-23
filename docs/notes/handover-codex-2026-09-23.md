# Handover to Codex — the build-speed refactor (2026-09-23)

Written by Claude for Codex. Read this first, then
`docs/notes/handover-2026-09-17-rock-canyon.md` for the repo rules and tooling,
which still apply in full.

## 1. Where things stand

- **Branch:** `master`, at `5d46399`, pushed by the owner. The full suite is
  green: **648 passing, 1 pending, no `SCRIPT ERROR`.**
- **Milestones 1–5 are merged.** Five levels: Rally Road, Muddy Valley, Frozen
  Pass, Rock Canyon, plus the Test Ground as Free Drive. Three cars.
- **`project.godot` is modified** in the working tree and always has been. It is
  an editor re-save with no meaningful change. Leave it alone.
- **`tmux-session.sh` is untracked and belongs to the owner.** Never stage,
  modify or delete it.

### What shipped since the last handover

**Milestone 5 — Rock Canyon** (fourth timed level, ~2.1 km): asphalt approach,
a deep mud gully with water-filled ruts, a boulder wash with climbable rock
steps, a ford under a waterfall, and a narrow loose-rock shelf with a cliff on
one side and a drop on the other. It brought four surfaces (deep mud, rock,
scree, wet rock), a per-distance road width profile, canyon walls in
`TerrainDef`, a throttle-lever touch control, and a car recommendation on levels.
Built by another Claude session plus Codex; see `docs/notes/m5-rock-canyon-notes.md`
and the dated `rock-canyon-*` notes.

**The loose-rock performance fix** (`docs/notes/performance-m5.md`). The owner's
phone dropped to 8–10 fps where the shelf's stones slide. Measured cause: the
cost of dynamic bodies is sharply non-linear — 313 awake cost 4.4 ms a physics
frame and 478 cost **58.2 ms**, because Jolt merges touching stones into one
contact island and every stone carried swept collision. Fixed with an activation
window (`TalusDef.active_distance`: stones far from the camera are frozen, which
makes them static to Jolt), damping so a shove settles instead of cascading,
swept collision only above `TalusBuilder.CCD_SPEED`, and half the density.
Result: peak awake 485 → 206, physics 58 → 2.5 ms, **60 fps**. Do not undo any
of this; `tests/scenarios/test_loose_shelf.gd` guards it.

**The driving touch-up — AWD balance** (feel log Session 9, commit `f656390`).
The owner: the rally cars "feel a bit too loose on the backend when we get up to
speed, like they feel more rear-wheel drive than all-wheel drive". Measuring
first showed steady-state cornering was fine — both cars understeer — and that
the looseness was a transient on mid-corner throttle changes, where the rear
stepped out by up to 9.7° against the 4x4's 1.3°. The cause was 65% of drive
torque going rearward.

| | Rally Car | Rally Car Tuned |
| --- | --- | --- |
| `front_torque_split` | 0.35 → **0.45** | 0.41 → **0.48** |
| `anti_roll_rear` | 8920 → **7580** | 10700 → **9100** |
| `rally/mud` grip multiplier | 1.1 → **0.95** (both) | |

Power-on oversteer went to −0.7°, lift-off rotation is kept on purpose, and lap
times are unchanged or slightly better. A partly locked centre differential was
tried and **rejected**: it made the cars quick enough on mud to arrive at Muddy
Valley's last bend 5 km/h faster and slide 12–14 m off a 7.5 m road. Every
differential stays open. `tests/scenarios/test_car_balance.gd` guards the
balance; do not change car values to make anything else pass.

## 2. The open request: make the levels build faster

**Rock Canyon takes about 5.7 s to build on the owner's Xiaomi 13**, against a
3 s budget and 1.0 s (Rally Road), 1.7 s (Muddy Valley) and 1.6 s (Frozen Pass).
The owner feels it most when restarting a level. Your job is to get it under the
budget without changing a single vertex of any level.

### The measurement, so you do not repeat it

Phone phases for Rock Canyon: `field` 1.50 s, `road_blend` 1.05 s, `shelf` 1.02 s,
`road` 0.74 s, `talus` 0.56 s, `terrain` 0.30 s, `scatter` 0.22 s. Within `field`
(desktop, whole phase 0.73 s): `earthworks` 0.33, `walls` 0.20, `natural` 0.10,
`carve` 0.06. `TrailLevel.phase_summary()` prints all of this on every build.

**Wrapping these phases in `WorkerThreadPool` will not work, and this is the
whole point of the task.** Instrumenting `RoadBlendBuilder` showed **0.36 s of
its 0.47 s (77%) is sampling**: `sampler.surface_point()`, `profile.height()`
and `field.height_at()`, once per row. `ShelfBuilder` and the earthworks have the
same shape. Milestone 3B established that calling a shared GDScript object's
methods from worker tasks *serializes* them — measured 1.18× on 4 threads against
2.82× for inlined maths.

### The approach that worked before

`TerrainBuilder` had exactly this problem and was fixed by snapshotting the field
data into flat local arrays and inlining the per-point maths, so workers touch
only local values. That alone gave **4.6× before threading even helped**
(0.79 s → 0.17 s serial, then 0.044 s threaded). `levels/trail/terrain_builder.gd`
and `road_chunk_data.gd` are the worked examples — `RoadBuilder` already
snapshots per chunk on the main thread and computes in workers; extend that
pattern outward.

Suggested order, largest first, each independently verifiable:

1. **`RoadBlendBuilder`** (1.05 s on the phone) — the earth joins outside the
   shoulders. Pure mesh plus collision from sampled rows.
2. **`ShelfBuilder`** (1.02 s) — rock walls every 2 m, subsoil, gravel roadbed.
3. **The earthworks** (~0.69 s) — `TrailEarthworks.apply_road_clearance` and
   `apply_road_damage` walk every road row calling `_road_row`, which samples per
   station. They already take the caller's `RoadProfile` rather than building
   their own.
4. **Canyon walls** (~0.42 s) — a cheap independent win: `TerrainField.WALL_STEP`
   is 1 m along and across a 2 m grid, so every cell is painted about four times.
   Tying the step to `spacing` roughly halves it.

`talus` (0.56 s) is node creation, which must stay on the main thread; leave it.

### The hard requirement: identical geometry

`tests/unit/test_geometry_fingerprints.gd` hashes the road meshes, collision
faces, terrain heights, edge distances and gate distances of **all four** timed
levels. Rock Canyon was added to it at `5d46399` specifically for this task.

**These fingerprints must not change.** Re-recording them to make the suite pass
would defeat the entire safety net — the refactor is meant to produce the same
geometry faster. If a fingerprint moves, the refactor has a bug: find it. Float
accumulation order matters, which is why `_carve_parallel` gives each task a band
of rows and visits stamps in the original order; preserve that discipline.

### Done when

- Rock Canyon builds in **under 3 s on the owner's phone**, measured with the
  load benchmark (below), with the other four levels no slower.
- `./run_tests.sh all` is green, with no `SCRIPT ERROR`, and the geometry
  fingerprints are untouched.
- `docs/notes/performance-m5.md` gains the before/after phase numbers.
- You write `docs/notes/codex-report-build-speed.md`: what you changed, the
  measurements, anything you could not do, and anything you are unsure about.

## 3. Rules — these are the owner's, not suggestions

- **Work on branch `build-speed`, from `master`. Do not merge. Do not push.**
  The owner decides both, and Claude reviews your branch first.
- **Stage files by name.** Never `git add -A` or `git add .`.
- **Never touch `tmux-session.sh` or `project.godot`.**
- **Ask before changing anything under `car/` or the values in `surfaces/*.tres`.**
  This task should need no car or surface change at all.
- **Do not soften Rock Canyon's CP4–CP5 shelf** — its bank (peaks 12°, 14°, 13°),
  gradient and line are all deliberate, and the owner explicitly rejected easing
  them.
- **Do not run tests, benchmarks or screenshot captures while the owner is
  playing.** Two Godot instances freeze the second; this cost two long debugging
  detours already. Check with `ps -eo pid,args | grep "godot --path ."` first,
  and never kill the owner's process.
- **Commit messages** end with a blank line then the `Co-Authored-By` and
  `Claude-Session` trailers used on this repo, with your own session link.
- Report honestly. The last handover's report was trusted because it wrote down
  what it had *not* verified; keep that standard. Never claim a green suite you
  did not run.

## 4. Tooling

```bash
./run_tests.sh unit | scenarios | all      # all takes about 5 minutes now
godot --headless --fixed-fps 120 --max-fps 0 -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_geometry_fingerprints.gd -gexit
godot --headless --import                  # after adding a class_name
godot --headless -s tools/record_geometry.gd   # prints fingerprints; do NOT re-record
```

Phone:

```bash
tools/android.sh build|install|run|logs
adb shell run-as com.ridge.game touch files/benchmark      # then launch normally
adb shell run-as com.ridge.game touch files/shelf_stress   # loose-stone cost probe
adb logcat -v time -s godot:V
adb logcat -d -b crash
```

Android drops launch arguments, which is why both probes use a flag file. The
load benchmark loads all four levels three times and prints each phase; the
numbers rise across rounds as the phone heats, so compare like with like.

## 5. Lessons worth not relearning

- Threading: never call a shared object's methods inside a worker task; copy the
  data into locals and inline the maths (this task exists because of that).
- Every looping sound needs `SoundSynth.LOOP_PAD`, or the phone hits SIGSEGV at
  the first loop wrap; players must stop in `_exit_tree()` or the suite hangs.
- Typed GDScript: values out of `Dictionary`, and inline `a if c else b`, need
  explicit types; loop variables over array literals need typing. Tabs, `##` docs.
- Mesh normals are stored compressed — compare with `distance_to(...) < 0.01`.
- Draw calls are the phone budget that bites, not triangles. Budgets: <300k
  primitives, <150 draw calls, 60 fps, <3 s load.
- Desktop hides phone cliffs: 485 awake stones cost 6 ms on desktop and 58 ms on
  the phone. Measure the phone before believing a performance result.
