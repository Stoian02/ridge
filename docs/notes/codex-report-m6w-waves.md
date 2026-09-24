# M6W — isolated wave groundwork (2026-09-24)

## Scope and status

Branch `m6-water-waves`, based on unmerged M6A `4d5bd21`. The owner approved
this limited start and total-water CPU ceilings of **4 ms/frame p95 and
5 ms/frame p99**. No master merge, push, car/surface tuning or gameplay wave
activation is included. The normal game and M6A waves-Off reproduction are
unchanged. The M6A hitch remains unresolved; live-car wave integration must
wait for its fix and retest.

This is groundwork, **not the owner-playable car/water feature**. It implements
the pure model, standalone refined geometry/sampling, shared shader equations
and an explicit car-free lab. Natural entry detection, motion-driven wake
generation, intake/flotation coupling and Test Ground menu controls remain
future work. The owner feel checkpoint after Task 5 still precedes polish.

Feature commits: `e175039` (pure field/snapshots), `3b3b84c` (mesh/sampler),
`d9eb9ee` (shader/runtime/lab). Code was frozen before the final complete run;
committing it during that run did not change the tested files.

## Implemented

- One fixed global source budget: four entry packets and twelve wake packets,
  including queued reservations. Per-body snapshots prevent cross-pool history.
- Gentle ambient terms, compact spreading entry/wake pulses, current advection,
  a bounded bow field, onset/expiry and bounded physics-time phases. Inputs are
  explicit synthetic sources, not live car observations.
- Smooth depth/shore displacement limits, analytic gradients including the
  limiter derivative, finite softened packet centres and float32 shader inputs.
- 0.75 m refined visual tops with a separate triangle index and snapshot-local
  vertex-height cache. Sampled height is interpolated from the drawn triangle,
  not evaluated as a different continuous surface at the query point.
- Conservative whole-cell bed maxima include interior bed breakpoints. Shared
  vertices take the minimum of incident limits. The original WaterBody query
  top, bed, adaptive bins and all protected level geometry remain unchanged.
- Actual footprint union handles the source mesh's clipped T-junction seams.
  Temporary outline snapping is <=0.1 mm; static source arrays never change.
  Unsupported tilted/multiple-loop tops fail closed, rather than pretending to
  support moving pools, islands or arbitrary transforms.
- One new translucent spatial shader, a shared GPU include, per-body materials,
  expanded culling bounds and a pause-aware synthetic runtime with no Car or
  WaterWorld binding. No shader TIME, new collision, audio or particles.

## Verification

All runs were sequential, with isolated desktop save/config paths. No phone
command/build/install was issued for this stage.

| Check | Result |
| --- | --- |
| Unchanged baseline `./run_tests.sh all` | **736 passed, one pre-existing pending; exit 0; no SCRIPT ERROR**, 475.619 s |
| Focused new unit tests on final code | **24/24 passed**, 13,647 assertions, exit 0, no SCRIPT ERROR or GUT error; 0.538 s |
| Final `./run_tests.sh all` | **760 passed, one pre-existing pending**, 113 scripts, 370,525 assertions, exit 0, no SCRIPT ERROR or GUT error; 480.818 s |
| GPU readback encoding calibration | 64 known heights; maximum error **0.0000000147 m** |
| Actual shared shader evaluator vs CPU | 576 samples across onset, max packets, shallow limits, expiry and 600 s phase; maximum error **0.000000286 m** |
| GPU heights from actual mesh attributes vs triangle sampler | 21 triangles, maximum error **0.000000104 m** on final code |

Rendered checks used Godot **4.7.2**, Vulkan **Forward Mobile**, AMD Radeon 880M,
960×540. They are desktop numerical/visual checks, **not** phone parity or
performance acceptance. The verifier rejects the dummy headless backend,
calibrates the LDR encoding first, and shares the actual water shader's height
function. This verifies the shared evaluator and actual mesh inputs, not a
readback of the spatial pass's rasterized depth or a GPU-normal parity test.
Readback is diagnostic-only. The preview was visually inspected;
lighting/readability are unpolished, and there is no owner feel pass yet.

New tests cover global capacity/expiry, body isolation, pending-vs-committed
state, reset/cache invalidation, split timesteps and 60/120 Hz prescribed inputs,
analytic derivatives, boundaries/negative coordinates, bed peaks between mesh
vertices, dry gaps, shared seams, source-array preservation and scene pause.
Source-generation behaviour and real-car scenarios are not claimed tested.

The first new full-suite attempt stopped producing output after the existing
Rock Canyon ledge comparison and was terminated with SIGTERM (exit 143). Its
cause is unknown; do not call it a pass or attribute it to waves/audio without
evidence. No existing test/game code was changed to get past it. A subsequent
focused command used the wrong GUT selector, logged one GUT error, ran the unit
directory and nevertheless returned exit 0; that is also **not** counted as a
clean pass. The corrected focused command and final regression are separate;
the final rerun passed the Rock Canyon ledge and remaining Canyon scenarios
without reproducing that stall.
These logs are retained alongside the successful checks in
[`m6w-groundwork-data/`](m6w-groundwork-data/README.md).

## Counts and unresolved cost

The two deep tops plus four shallow tops contain **31,912 triangles total** in
the final mesh test, counting the shared deep mesh twice and before subtracting
the original flat meshes they would replace. This is a geometry count, not a
phone submitted-primitives or draw-call acceptance result. The old base course
9,300-primitive assertion stays unchanged.

Preparation took **0.319 s elapsed on desktop** in the retained final focused
run and **0.329 s** in the full regression (earlier development checks ranged
0.311–0.348 s), building the shared deep
topology once and all four bays. This already
exceeds the proposed **0.25 s phone** preparation allowance; no phone projection
or pass is claimed. The independent geometry/outline/depth preparation needs
profiling before the phone gate. Do not raise the allowance or weaken masking
to hide it. GPU first-use time, total/incremental water CPU, memory and thermal
behaviour remain unmeasured on the phone.

Protected geometry and car-balance fixtures passed without changes. There are
no implementation edits under `car/`, `surfaces/`, `levels/`, or to existing
water/gameplay scripts. Master remains `a3dbee4`; M6A remains `4d5bd21`. No Godot
process was left running after verification.

The independent M6A review is recorded in
`m6a-independent-review-2026-09-24.md`: roughly 20 ms Rock Canyon frame p95
already exists without water. That inherited scene debt is separate from
water cost. Both the older 4x4 hitch and Claude's newer rally-only observations
remain in the record; a cause has not been established.

## Preview and resume

When no other Godot/game/test is running:

```sh
godot --path . res://debug/water_wave_lab.tscn
```

This is a car-free synthetic preview of the existing calm pool, not normal
Free Drive and not the future feel test. Close the window before starting tests.
The numerical verifier runs a real renderer and exits automatically:

```sh
godot --path . --resolution 960x540 res://debug/water_wave_lab.tscn -- --verify
```

Next: review this isolated work, fix/retest the M6A flooded/stalled hitch with
the waves-Off game path preserved, profile preparation and perform the early
phone feasibility gate. Only then connect live-car sources/queries. Stop again
at Task 5a for owner driving feedback before any Task 6 polish. Do not merge,
enable waves in timed levels or begin Coastal Highway automatically.

Technical references used for shader uniforms/includes and the diagnostic
viewport are the official Godot [shading language](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html),
[shader preprocessor](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shader_preprocessor.html)
and [Viewport API](https://docs.godotengine.org/en/stable/classes/class_viewport.html).
These document interfaces, not Ridge's performance or acceptance.
