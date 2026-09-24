# Milestone 6A — water physics

**2026-09-24 follow-up:** ford query optimization and the inherited creek
rendering fix are documented in `m6a-query-fixes-2026-09-24.md`, with retained
before/after measurements. Car handling/forces and geometry are unchanged.
The owner reconnected the phone and the fresh build is installed. Phone ford
controller p95 fell from about 4.2 to 1.6 ms/tick; all three creek views now meet
the drawing budgets. The strict water/setup gates still fail, and whole-frame
p95 did not improve in the ford A/B. The three-round all-car course retest still
has 34/36 cases above 0.50 ms, plus unexplained long intervals in one current-pool
case (maximum 79.459 ms). **Acceptance remains open.** The frame-budget
recommendation is a proposal, not a retroactive passed gate.

**Performance review reopened (2026-09-23).** The original desktop p95 figures
below came from accelerated uncapped test mode and must not be used to infer
phone headroom. Claude reported higher, repeatable timings. See
`m6a-performance-retest-2026-09-23.md` for the repeated desktop/direct-phone
audit and corrected pre-fix acceptance status: **34/36 course cases exceed 0.50 ms p95;
ford p95 is 4.26–4.28 ms; two creek views exceed 300k primitives; setup limits
are also missed. Performance acceptance fails.** Historical measurements remain
below for traceability; they are not a passed phone gate.

Implemented and ready for PC playtesting / Claude review on `m6a-water-physics`,
based on `master` `a3dbee4`. Phone acceptance is still pending.
The owner approved the written spec on 2026-09-23. No merge or push; Coastal
Highway remains out of scope until this part is reviewed and accepted.

Implementation commits: `3021d5b` volumes/adapters, `9e33cf7` vehicle physics,
`ddda98e` test courses/feedback, followed by the measurement-tools/report commit.
The owner's `project.godot` change and untracked `tmux-session.sh` remain untouched
and excluded from these commits.

## What changed

- Explicit level-owned water volumes sampled from actual visible top triangles
  and static bed geometry: ford, creek, disconnected mud-rut puddles, and three
  new Test Ground areas. No solid water collider or per-puddle Area.
- Approved water-only car profiles, eight-probe buoyancy, current-relative drag,
  progressive flooding/sinking, intake stalls/restarts and water-only air-control
  suppression. Existing dry car/surface values are unchanged.
- Translucent water, depth colouring, bounded wheel/body effects, wash/entry
  audio, a non-blocking warning, debug intake marker and appended CSV fields.
- Raised shallow, calm and current courses behind/right of the original Test
  Ground spawn, with the existing slab and old course positions unchanged.

## Verification baseline

Before runtime edits, `./run_tests.sh all` passed **654 tests**, with the existing
one pending jump test; no `SCRIPT ERROR` (375.8 seconds).

Captured original creek/rut/ford vertex, normal, index, colour and UV arrays in
`tests/unit/test_water_geometry_baseline.gd`. Materials intentionally are not
hashed. Existing geometry/build-detail/balance fixtures were not re-recorded.

## Final desktop verification

`./run_tests.sh all`: **728 passing, 1 existing pending**, 107 scripts,
328,757 assertions, 477.936 seconds, exit 0 and no `SCRIPT ERROR` or test
failures. The pending test remains the gas-on jump's nose-down pitch; it was
already pending in the pre-change baseline. Log: `/tmp/ridge-m6a-all.log`.

Coverage includes all three cars on matched dry/wet beds at 3/8/15 m/s;
temporary flotation then sinking; current direction; intake stall/recovery;
service brakes in either gear; 60/120 Hz tilted stability; and pause, reset,
run restart, car change and scene-exit cleanup. Protected car-balance, geometry,
build-detail and loose-shelf fixtures passed unchanged.

Existing scripted scenarios also passed (single runs, not player star-time
calibration):

| Scenario | Before water | After water |
| --- | ---: | ---: |
| Rock Canyon full 4x4 scripted run | 7:42.1 | 7:45.2 |
| Rock Canyon mud climb from rest | 31.18 s | 31.17 s |
| Muddy Valley full scripted run | 1:34.5 | 1:34.4 |
| Muddy Valley rough shortcut | 24.8 s | 24.8 s |
| Muddy Valley escape from creek | 4.9 s | 6.9 s |

The ford crossing still completes with zero airborne ticks. Star times, shelf
difficulty, old car tuning and all existing surface resource values are unchanged.

The final debug launcher addition was followed by **8/8 menu tests** and an
isolated normal-launch smoke test: the one-shot flag was consumed, all four
benchmark areas ran, and the process exited normally. This verifies desktop
launcher wiring, not Android behaviour. Final course signs were recaptured and
visually checked from the driving camera.

Logs for this development session are under `/tmp/ridge-m6a-*`; these local
temporary logs are not committed. Tests and captures used isolated save paths,
not the owner's progress. `git diff --check` passed.

## Implementation findings

- A simplified flat water mesh can introduce T-junctions. Shore-edge extraction
  therefore splits unmatched collinear edges before counting them, avoiding a
  false dry seam inside a pool.
- New pool colours are sampled at <=1 m, then visual-only spans are merged with
  a maximum 0.01 RGBA interpolation-error test. This preserves the planar water
  footprint and real solid bed while limiting triangles. Shoreline fade breaks
  are represented explicitly, rather than stretched over a whole entry cell.
- Physics clips wheel immersion against the bed; that fraction cannot alone
  decide whether a tyre should make dry spray. Feedback also checks its upper
  extent, so fully submerged grounded tyres do not throw smoke through water.
- The new telemetry field required extending one existing telemetry-shape
  assertion. The old CSV columns and legacy telemetry fixture remain intact.
- Audio player-count/length tests now include the two water sounds. Every new
  loop uses the existing padded PCM path; reset/exit cleanup is tested.
- An initial dry-parity fixture compared cars on different X coordinates and
  differed by 0.0042 m/s for the tuned rally car. Sequential runs at exactly the
  same position/physics phase pass the original 0.0001 m/s tolerance on every
  measured tick, with exactly zero water force/torque. No tuning or protected
  assertion was relaxed.
- Comparing `Mesh.get_faces()` to raw collision input introduced 33–46 micrometre
  reconstruction rounding. Comparing the actual unindexed render vertex buffer
  to collision input shows **zero difference**. Course tests check that exact
  buffer equality and retain a separate reconstruction diagnostic.
- Water bed extraction initially cost about 0.17–0.19 s for Rock Canyon. A
  build-only snapshot now gathers candidates once, skips collider subtrees,
  reads original mesh arrays, and reuses relevant transformed vertices. The
  water phase fell to approximately **0.05 s desktop**. Geometry is unchanged.

## Desktop measurements

Headless, fixed 120 Hz, uncapped; same five-level order for three rounds before
and after implementation. Median total load seconds, rounded by the existing
benchmark (includes resource load, instantiation and ready):

| Level | Before | After | Observed difference |
| --- | ---: | ---: | ---: |
| Rally Road | 0.31 | 0.38 | +0.07 |
| Muddy Valley | 0.56 | 0.66 | +0.10 |
| Frozen Pass | 0.49 | 0.58 | +0.09 |
| Rock Canyon | 1.55 | 1.79 | +0.24 |
| Test Ground | 0.40 | 0.55 | +0.15 |

These are separate sequential batches, **not interleaved A/B trials**. Even dry
Frozen Pass slowed, so total deltas do not isolate water. Nevertheless the
observed +0.24 s Rock Canyon delta must not be described as passing the 0.10 s
incremental target. Its isolated new water phase is about 0.05 s; Muddy Valley's
is 0.01–0.02 s. Both need matched phone measurements before acceptance.

The new course alone built in **0.089–0.090 s** in focused runs and **0.147 s**
during the full suite, with **9,211 geometry triangles**
and seven non-label mesh draws. The colour interpolation test's maximum RGBA
error was **0.007992**, below 0.01. Labels/effects remain bounded and culled.

First desktop 4x4 water benchmark, 570 measured ticks per area after 30 warm-up
ticks; controller sampling/state/force cost only, not Jolt or the whole frame:

| Area | p95 ms | Maximum ms |
| --- | ---: | ---: |
| 5 cm bay | 0.104 | 0.125 |
| 30 cm bay | 0.124 | 0.136 |
| Calm deep pool | 0.104 | 0.291 |
| Current deep pool | 0.105 | 0.273 |

Headless draw counts are zero and are not rendering measurements. Desktop GUI
captures (Vulkan Mobile, AMD Radeon 880M, 1280×720 window) measured:

| View | Primitives | Draw calls |
| --- | ---: | ---: |
| Shallow course entry | 27,671 | 40 |
| Calm course entry | 18,319 | 36 |
| Current course entry | 18,303 | 35 |
| Submerged tyres | 18,491 | 39 |
| Underwater stall | 17,670 | 30 |
| Elevated course overview | 25,979 | 44 |
| Rock Canyon ruts, 340 m | 164,846 | 109 |
| Rock Canyon ford, 1290 m | 121,816 | 100 |
| Muddy Valley creek, 820 m / lateral +17 m | 289,524 | 143 |

These are captured views, not a continuous worst-case FPS sweep. The creek
view has little remaining headroom against 300k/150 and deserves particular
phone attention. Test Ground's existing golden-hour fog/lighting strongly tints
water; the bed and submerged parts are visible, and underside culling was checked.

All three load rounds returned to **8 nodes / 0 orphan nodes**. Resource counts
plateaued by round two (Test Ground cleanup: 163 in all three rounds; baseline
145). Process shutdown still reports ObjectDB warnings (baseline load tool 18,
water benchmark 20); no claim is made that every inherited shutdown warning is
resolved. Runtime scene cleanup did not show accumulating nodes/resources.

## How to test on PC

Choose **Free Drive / Test Ground**. The water courses are behind the original
spawn, to the right: shallow lane X=60, calm pool X=105, current pool X=155.
They begin at Z=30 and run toward +Z, opposite the old strips. Follow the new
sign near spawn. Normal Reset still returns to the original spawn.

Try all three cars. Start with the four shallow bays (5, 15, 30, 35 cm), then
descend gradually into the calm pool. The current pool is identical with a
0.75 m/s sideways flow. The 4x4's higher intake is reserved for a later snorkel
model; visible snorkel art is not part of A.

Telemetry exposes wheel/body immersion, intake clearance, current, force ratio,
flooding and timers. CSV records those fields after the old columns. Debug-only
intake marker follows the actual configured intake point.

## Repeatable measurement tools

- `debug/load_benchmark.tscn`: existing three-round, five-level load benchmark.
- `debug/water_benchmark.tscn -- car=offroad_4x4`: real water physics ticks,
  p95/max controller cost, query counts, draw/primitive peaks and cleanup.
  Also accepts `car=rally` or `car=rally_tuned`.
  On a debug phone build, `adb shell run-as com.ridge.game touch files/water_benchmark`
  followed by a normal launch uses the one-shot flag (Android drops scene args).
- `tools/water_shots.tscn`: course entries, visible submerged tyres, overview
  and underwater camera view, saved under `build/water_shots/`.
- Existing `tools/level_shots.tscn`: ford/creek/rut driving-camera captures.

Never run these while the owner is playing; check for their Godot process first.

## Original pending acceptance / limitations (superseded by the retest)

The phone was not connected during initial development. Phone transparency,
audio-loop/repeat-load stability, 60 fps, <150 draws, <300k primitives, water
physics <=0.50 ms p95, timed-level setup <=0.10 s and course setup <=0.25 s must
be measured on the Xiaomi 13. Desktop timings do not pass this gate.

The later connected-phone retest is linked at the top of this report. It now
provides those measurements and records the failures; subjective owner approval
and any performance corrections remain outstanding.

Rock Canyon already missed the overall 3-second phone load target at about
3.9 seconds before water. M6A does not fix or waive that pre-existing miss.
Any acceptance with it outstanding must be explicit; deferred construction is
a separate task, not silently included here.

Owner playtesting, Claude review, phone measurements and an owner-authorized
merge must precede Part B. Aquaplaning, deep-water skimming, waves and a visible
snorkel remain deferred.
