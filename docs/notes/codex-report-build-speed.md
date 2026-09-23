# Build-speed refactor — Codex report

Branch: `build-speed`, based on `master` at `9d21b78`. Not merged or pushed.
The owner approved the plan and explicitly prioritized exact geometry over the
suggested coarser canyon-wall sampling.

Implementation commits: `16d5c08` (exact sample reuse and parallel earth joins),
`9fb34c5` (terrain bands and local-array earthworks).

## Scope and implementation

- Main-thread build-lifetime caches retain exact road position/frame samples,
  longitudinal heights, per-row height inputs/results and surface colour weights.
  Keys are the original distances/laterals, not rounded approximations. All
  caches are cleared before gameplay; height caches are released after the shelf
  so one-off stone/scatter queries do not create thousands of unused snapshots.
- `RoadHeightData` snapshots the row's profile into value arrays, preserving
  float64 intermediates and the original sum order for potholes, cross-ruts,
  patches, wheel tracks and rock steps. This avoids repeated shared-resource
  sampling in terrain clearance and shelf support rows.
- `RoadBlendData` builds independent shoulder-join chunks from value snapshots.
  Terrain triangle sampling, ground normals/colours, winding and surface tags
  match the serial reference. Workers own their output and ground-vertex cache;
  mesh/physics resources and scene nodes are still assembled on the main thread.
- Canyon wall painting and road-clearance calculations run in independent
  terrain row bands. **Every original 1 m wall stamp remains.** Per-cell stamp
  order, strict comparisons, float32 stores and overlap tie behaviour remain.
  There is a separate unchanged serial reference, not a larger `WALL_STEP`.
- Natural terrain noise uses private noise generators and flat row-band inputs;
  the fitted plane and noise arithmetic are unchanged. Earthworks use local
  height arrays and grid values instead of repeated field method/property calls.
- Phase diagnostics now distinguish snapshot/data/node costs for the road and
  shoulder joins, and sampling/hull costs within the shelf. The load benchmark
  also measures Test Ground and reports post-cleanup node/resource counts.

No level resources, car code, surface stats, stone activation/damping/density,
banking, gradients, seeds, mesh resolution or physics project settings changed.
The owner's `project.godot` changes and `tmux-session.sh` remain untouched.

## Geometry safety

The existing `test_geometry_fingerprints.gd` and car-balance assertions are
untouched. Before changing builders, additional fixtures were captured from
`9d21b78` for all four timed levels: complete shelf and shoulder-join mesh arrays,
ordered collision faces/hulls and transforms, terrain mesh appearance, and wall
strata. These live in `test_build_details.gd`; they were not refreshed afterward.

Additional parity checks compare threaded joins to the retained serial builder
including rebuilding, exact cached/uncached heights and colours across every
authored road row, cache release/edit behaviour, and overlapping terraced walls
on 1/2/3 m terrain grids. The grid-spacing tests change only their test fixtures,
not the shipped terrain or its 1 m wall sampling.
An additional test compares boulder transforms, all loose-stone rest transforms,
scales, masses and hull points against uncached reference placement.

## Measurements and verification

Baseline unit suite: **567 passed**, exit 0. Initial optimization checkpoint:
**571 passed**, exit 0. Expanded row-height/colour and wall parity checks:
**10 passed**, 162,060 assertions, exit 0. No `SCRIPT ERROR` in those runs.
**Final `./run_tests.sh all`: 654 passed, 1 existing pending, 0 failed**, 655 tests
in 96 scripts, 289,066 assertions, 378.037 s, **exit 0**, no `SCRIPT ERROR` or
engine `ERROR:` lines. All 574 unit tests pass. The existing jump-landing check
remains pending. Log: `/tmp/ridge-buildspeed-final-all.log`.
Tests use isolated `/tmp/ridge-buildspeed-data` and
`/tmp/ridge-buildspeed-config` saves.

First full-suite attempt: **652 passed, 1 failed, 1 pending**, exit 1,
376.043 s, no `SCRIPT ERROR`. The car crossed the whole shelf, but its
below-terrain-stone guard failed. The full Rock Canyon drive still finished.
Unchanged master (`9d21b78`, isolated temporary checkout) and this branch then
both passed the two standalone shelf tests with **identical** results: 232.267 s,
1,236 stones moved, peak awake 192, peak speed 11.462 m/s, no penetration.
This is evidence of suite/order-dependent simulation behaviour, not proof that
the full-suite failure predates this work. No driving assertion was relaxed;
only a diagnostic for the first below-terrain stone was added. Logs:
`/tmp/ridge-buildspeed-all.log`, `/tmp/ridge-buildspeed-reference-shelf.log`,
`/tmp/ridge-buildspeed-focused-shelf.log`.
The final full-suite repeat passed the shelf checks as well. That does not
establish the root cause of the earlier intermittent failure. The added exact
stone/boulder placement test passes, including all rest transforms, masses and
hull points; `/tmp/ridge-buildspeed-placement-tests.log` has 3 passing tests,
4,786 assertions, no engine/script errors. Its initial off-tree test setup was
corrected because TalusBuilder requires live nodes for force_update_transform;
no production physics change or assertion relaxation was made.

Fresh Xiaomi 13 baseline, unchanged builders with Test Ground added to the same
three-round benchmark: Rock Canyon **5.96 / 9.05 / 11.19 s**. First optimized
phone pass, before parallel natural terrain: **4.87 / 7.97 / 8.20 s**. These are
per-level build timings, not resource load + instantiate/ready totals. Repeated
loads get slower, so first and third rounds must not be interchanged.

Final phone pass: **3.81 / 3.79 / 6.29 s** for Rock Canyon's build, improvements
of **36% / 58% / 44%** against the equivalent baseline rounds. The build target
is still missed, including on the first load. The final APK is installed with
`adb install -r`, preserving saves; its automatic benchmark finished and exited.

Full load + instantiate/ready totals, seconds (baseline → final, rounds 1/2/3):

| Level | Round 1 | Round 2 | Round 3 |
| --- | ---: | ---: | ---: |
| Rally Road | 1.90 → 1.56 | 0.92 → 0.73 | 1.26 → 1.08 |
| Muddy Valley | 1.50 → 1.45 | 1.60 → 1.25 | 2.59 → 1.97 |
| Frozen Pass | 1.31 → 1.19 | 1.53 → 1.21 | 2.57 → 1.63 |
| Rock Canyon | 5.99 → 3.83 | 9.10 → 3.82 | 11.26 → 6.35 |
| Test Ground | 1.19 → 1.03 | 1.71 → 1.04 | 2.25 → 1.55 |

No other level was slower in this paired run. This is one three-round comparison,
not a statistical guarantee across battery/temperature states. Test Ground's
generator is unchanged, so its improvement also illustrates device/run effects.
After every final load, cleanup reports **8 nodes and 0 orphan nodes**. Resources
stabilize per level after round 1 (150/156/159/199/146 in both rounds 2 and 3),
not a growing scene/resource count. Log: `/tmp/ridge-buildspeed-final-phone.log`.

Desktop baseline: Rock Canyon **2.31 s** in round 3. Before parallel natural
terrain, the same round is **1.59 s**. Road joins fell from about **0.45 s** to
**0.14 s**, walls **0.22 s** to **0.09 s**, earthworks **0.32 s** to **0.16 s**.
These are headless timing runs, not FPS measurements.
The final desktop round-3 build is **1.52 s** (about **34% faster** than baseline),
with natural terrain **0.09 → 0.02 s**. Final log:
`/tmp/ridge-buildspeed-final-desktop.log`. The export log is
`/tmp/ridge-buildspeed-final-export.log`; export/signing/install succeeded. The
existing missing-project-icon export warning remains unrelated to this work.

Logs: `/tmp/ridge-buildspeed-baseline-unit.log`,
`/tmp/ridge-buildspeed-baseline-desktop.log`,
`/tmp/ridge-buildspeed-baseline-phone.log`,
`/tmp/ridge-buildspeed-stage1-unit.log`,
`/tmp/ridge-buildspeed-stage1-desktop.log`,
`/tmp/ridge-buildspeed-stage1-phone.log`,
`/tmp/ridge-buildspeed-parity-tests.log`.

## Limits and follow-up

The final phone pass **does not meet the under-3-second acceptance target**.
The shelf's remaining cost is predominantly collision shape/node creation and
registration, not road sampling: final round 1 measured 0.014 s sampling versus
0.267 s in the hull loop within a 0.588 s roadbed phase. Road node creation was
0.252 s; loose-stone construction was 0.51 s. These phases include substantial
main-thread engine work, although their timings do not isolate every engine call.

Physics-resource creation was deliberately not moved to workers. Godot's
[thread-safety documentation](https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html)
requires appropriate server threading settings; this project does not enable
separate-thread physics. Changing engine/physics configuration, simplifying
collision or reducing stones is outside this approved geometry-preserving pass.

Do not infer that repeated-load slowdown is solely heat: thermal status was
read after the baseline, not recorded continuously during each load. The final
benchmark adds cleanup counts to detect accumulating scene objects, but that
alone cannot rule out allocator/engine or thermal effects. No sustained FPS
claim is made. Preserve the accepted shelf difficulty and loose-stone window.

## Review handoff

This is a verified improvement, **not completion of the performance request**.
The final APK is installed and its benchmark has exited. All desktop Godot
test/benchmark instances also exited. No merge or push was performed.

Recommended next decision: review this bounded refactor first, then choose
whether to investigate reusing or prebuilding immutable mesh/collision resources.
That would require a separate plan for memory limits, invalidation and unchanged
restart/reset behaviour. It is not implemented here. Do not trade away the
accepted road/collision detail or change physics threading to force the budget.
