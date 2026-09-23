# Handover to Codex — Milestone 6: water, then Coastal Highway (2026-09-23)

Written by Claude for Codex. This one is **design as well as build**: the owner
wants you to brainstorm each part with them, write its spec, plan it and
implement it.

**The milestone is split in two, and you stop between them.**

- **Part A — water physics.** The car's behaviour in water: buoyancy or its
  absence, depth-dependent drag, what it costs to go in, spray and sound. Landed
  and validated on the Test Ground and on Rock Canyon's existing ford.
- **Part B — Coastal Highway.** The sixth level and the fifth timed one, designed
  around what water actually does.

**Stop at the end of Part A.** Claude reviews the branch, the owner playtests on
the phone, corrections are made, it merges — and only then does Part B start,
from the merged master. Do not begin Part B while Part A is unreviewed.

The owner chose this order because Part A already has somewhere to prove itself:
Rock Canyon's ford was built to accept real water later (its spec §9.3: no
buoyancy, no depth drag, slick rock plus a visual ribbon), and the Test Ground
takes a water area as easily as it took the clearance logs. It also keeps the
car-physics-adjacent work isolated, where it is far easier to review.

Read `docs/notes/handover-2026-09-17-rock-canyon.md` for the repo rules and
tooling, which still apply in full, then this.

## 1. Where things stand

- **Branch:** `master`, at `eda6b6f`. The full suite is green: **654 passing,
  1 pending, no `SCRIPT ERROR`**, about 5.5 minutes.
- **Five levels ship:** Rally Road (asphalt), Muddy Valley (dirt and mud),
  Frozen Pass (snow, ice, a tunnel and a log bridge), Rock Canyon (deep mud,
  rock, scree, a ford and a loose-rock shelf), plus the Test Ground as Free
  Drive. **Three cars:** Rally Car, Rally Car Tuned, Off-road 4x4.
- **`project.godot` is modified** in the working tree and always has been — an
  editor re-save. Leave it alone. **`tmux-session.sh` is the owner's.** Never
  touch either.
- Just merged: the build-speed refactor (yours) and the AWD balance tuning.
  `docs/notes/codex-report-build-speed.md` and feel-log Session 9 have both.

## 2. How to run each part

The same loop for A and then, after review and merge, for B:

1. **Brainstorm with the owner.** Ask questions one at a time, prefer multiple
   choice, and get each section of the design approved before moving on. The
   owner is decisive and likes concrete options with a recommendation and a
   reason. They care most about how the driving feels, and they will tell you
   when something is wrong — believe them and measure before theorising.
2. **Write the spec** to
   `docs/superpowers/specs/YYYY-MM-DD-m6a-water-physics-design.md` (then
   `...-m6b-coastal-highway-design.md`), following the shape of the Rock Canyon
   and Frozen Pass specs: decisions table, the data and builders with exact
   field values, surfaces, look, sound, performance, tests, out of scope, risks.
   For Part B add a route table with distances. Commit it and ask the owner to
   review the written file before you plan.
3. **Plan it** into `docs/superpowers/plans/`, then implement on branch
   `m6a-water-physics` (then `m6b-coastal-highway`), task by task, with tests
   alongside. Stop for review at the end of the part.

## 3. Part A — water physics

The car currently has no idea what water is. Wading through Rock Canyon's ford
is driving on a slick surface (`wet_rock`: grip 0.5, drag 20) under a flat
translucent ribbon with no collision. Part A decides what water really does and
builds it.

**The owner has already decided one thing:** when water physics lands, **Rock
Canyon's ford gets real water**. Leaving the game with two kinds of water would
be worse than changing a crossing they have already accepted. Expect that level's
feel to shift, re-check its ford scenario test, and put it in front of them on
the phone before claiming it is done. Its star times may need revisiting.

Questions worth putting to them:

- **How deep does it go?** Shallow fords only, or water deep enough to float or
  drown a car? That decides whether buoyancy exists at all.
- **What does water cost you?** Drag that scales with depth, grip loss, spray on
  the windscreen, a stalled engine past some depth, or simply slower going.
- **Is falling in a failure?** Today, falling into Rock Canyon's gorge is *not*
  an automatic reset — the player presses Reset. Deep water could follow that
  rule, or become the game's first "you are out" condition.
- **Does it move?** Still water is a height plane. Waves, tide or a current that
  pushes the car are each a separate, larger piece of work.
- **How does it look and sound**, given the project has no shaders to speak of.

**This part touches car physics**, so every value needs the owner's approval, and
`tests/scenarios/test_car_balance.gd` must still pass unchanged — water must not
quietly retune the cars. The wheels' contact path already handles movable
supports (`car/wheel.gd`, approved 2026-09-19); read it before adding forces.

## 4. Part B — Coastal Highway

The sixth level, named in the PRD list in
`docs/superpowers/specs/2026-09-11-ridge-design.md` §6.3 with no description —
the design is genuinely open, and that is the point: **the owner decides it.**

Questions worth putting to the owner, once Part A has told everyone what water
does. Not a script — your own will be better after you have talked to them — but
these are the ones whose answers change the architecture:

- **Route.** A cliff road above the sea, a road at sea level with waves washing
  over it, or a climb between the two. Whether it is fast (it is the only
  asphalt-dominant level besides Rally Road) or technical.
- **What makes it different.** Every level so far owns a mechanic: mud, snow and
  ice, rock crawling. Wet asphalt and standing water would be the natural one,
  and there is no rain in the game yet.
- **Length and pace**, and which car it suits. Rally Road is 1.5 km at about
  1:30; Rock Canyon is 2.1 km at about 2:20.
- **Structures.** Tunnels through headlands and bridges over inlets already
  exist as data plus builders and would fit a coastal road almost unchanged.
- **How much water the route actually uses.** A flooded dip, a tidal causeway, a
  beach run, waves washing across the road — each is a different amount of the
  Part A machinery, and the owner should choose it knowing how water feels by
  then.

### What already exists to build on

`TrailDef` plus its builders cover: road with a per-distance **width profile**,
surface stretches with transitions and ruts, potholes, rough sections, rollers,
jumps, **tunnels**, **bridges**, **rock steps**, **boulder fields**, **loose
stone fields**, **fords with waterfalls**, **canyon walls** in the terrain,
hedges, a creek, road damage, cross ruts, fallen trees, earth joins, scatter and
checkpoints. Surfaces: asphalt, dirt, mud, deep mud, snow, ice, logs, rock,
scree, wet rock. Adding a level is mostly data plus a generated curve
(`tools/generate_<level>_curve.gd`); new *mechanics* are what need new builders.

## 5. Constraints that are not up for negotiation

- **Performance budgets:** under 300k primitives, under 150 draw calls, 60 fps
  on the owner's Xiaomi 13, and **level build under 3 s**. Rock Canyon is the
  cautionary tale: it builds in 3.9 s even after your refactor, because it
  carries 2,381 rigid bodies and a great deal of collision geometry. Design
  Coastal Highway to fit the budget rather than planning to optimise it later.
- **Dynamic bodies:** the phone falls off a cliff past roughly 450 awake at
  once — 313 cost 4.4 ms a frame, 478 cost 58 ms. If the design wants floating
  debris, driftwood or loose shingle, bound the *awake* count with
  `TalusDef.active_distance` the way the shelf does, and measure on the phone
  with `debug/shelf_stress.tscn`.
- **Existing levels must not change geometrically.** Part A changes how Rock
  Canyon's ford *drives*, by the owner's decision, but no level's generated
  geometry may move. `tests/unit/test_geometry_fingerprints.gd`
  hashes all four timed levels' geometry; `tests/unit/test_build_details.gd`
  holds finer fixtures. Never re-record either to make something pass.
- **Car physics and surface values need the owner's approval** before you change
  them, including the grip table. A new surface *file* is normal for a new
  level; changing an existing one is not. `tests/scenarios/test_car_balance.gd`
  guards the cars' balance — the rally cars are AWD and must behave like it.
- **Star times** are placeholders until the owner sets them from real runs. Say
  so in the spec rather than inventing targets.
- **Do not soften Rock Canyon's CP4–CP5 shelf** (bank peaks 12°, 14°, 13°), and
  keep its loose stones' activation window.

## 6. Rules

- **Work on branch `m6a-water-physics`, from `master`; Part B later gets
  `m6b-coastal-highway`, from the merged master. Do not merge. Do not push.**
  The owner decides both, after Claude has reviewed the branch.
- **Stop at the end of Part A** and hand over for review. Do not roll on into
  Part B.
- **Stage files by name.** Never `git add -A` or `git add .`.
- **Do not run tests, benchmarks or captures while the owner is playing** — two
  Godot instances freeze the second. Check with
  `ps -eo pid,args | grep "godot --path ."` first, and never kill their process.
- **Commit messages** end with a blank line then the `Co-Authored-By` and
  `Claude-Session` trailers this repo uses, with your own session link.
- **Report honestly.** Your build-speed report was trusted precisely because it
  said plainly that the target was missed and which numbers were single runs.
  Keep that standard: never claim a green suite you did not run, and write down
  what you could not verify. Finish each part with a report:
  `docs/notes/codex-report-m6a-water.md`, then `codex-report-m6b-coastal.md`.

## 7. Tooling

```bash
./run_tests.sh unit | scenarios | all          # all is about 5.5 minutes
godot --headless --import                      # after adding a class_name
godot --headless -s tools/record_geometry.gd   # fingerprints; do NOT re-record
tools/android.sh build|install|run|logs
adb shell run-as com.ridge.game touch files/benchmark      # load times, then launch
adb shell run-as com.ridge.game touch files/shelf_stress   # dynamic-body cost probe
adb logcat -v time -s godot:V
```

Screenshots need `DISPLAY=:1 WAYLAND_DISPLAY=wayland-1`; `tools/level_shots.gd`
renders level views, which the owner likes seeing before they drive.

## 8. Lessons worth not relearning

- Never call a shared object's methods inside a `WorkerThreadPool` task; copy
  the data into flat locals and inline the maths. You have just done this.
- Every looping sound needs `SoundSynth.LOOP_PAD`, or the phone hits SIGSEGV at
  the first loop wrap; players must stop in `_exit_tree()` or the suite hangs.
- Typed GDScript: values out of `Dictionary`, and inline `a if c else b`, need
  explicit types; loop variables over array literals need typing. Tabs, `##` docs.
- Mesh normals are stored compressed — compare with `distance_to(...) < 0.01`.
- Draw calls are the phone budget that bites, not triangles: merge meshes, use
  `MultiMesh`, set `visibility_range_end`.
- Desktop hides phone cliffs. 485 awake stones cost 6 ms on desktop and 58 ms on
  the phone. Measure the phone before believing a performance result.
- The project has no shaders except one gravel material; everything else is
  vertex colours and `StandardMaterial3D`. Animated water has been done with an
  animated `uv1_offset` rather than a shader. Keep that unless the owner agrees
  otherwise, and remember shader compilation can stutter on first sight on
  Android.
