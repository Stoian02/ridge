# M6W review follow-up — hitch trace and preparation (2026-09-24)

## Outcome and boundary

Continues Claude's review of `e37620d`, on **`m6-water-waves`**. The review
independently confirmed 760 passing tests, unchanged protected fixtures,
CPU/GPU agreement and isolation from gameplay. This pass followed its priority:
trace the waves-Off hitch first, profile preparation, then check preparation and
numerical agreement directly on the phone.

Feature commits: `ff9f046` (bounded hitch diagnostics) and `e9edc1d`
(exact packaged topology and covered lab). Runtime/test files were unchanged
between the final regression and these commits.

- **Preparation problem addressed without reducing geometry:** exact static
  topology/masks are generated offline and loaded as validated packaged assets.
  Three phone launches took **27.092 / 37.652 / 34.227 ms CPU** to prepare the
  six wave tops, versus the proposed 250 ms allowance.
- **Captured hitch evidence points to scheduling, not a stall-transition bug.**
  Two long frames were dominated by time when the game thread was runnable but
  not executing. This is an attribution of these captured frames, **not a fix
  or blanket explanation of the older 46–79 ms observations**.
- **765 desktop tests passed, one inherited pending**, exit 0, no SCRIPT ERROR.
  Geometry fingerprints and car balance passed unchanged.
- Phone GPU evaluator and drawn-triangle sampling checks passed three times.
  **The complete Task 4 total-water/CPU/GPU/frame-time gate is NOT complete.**
  Setup/parity checks are not a substitute for it or M6A acceptance.

No live car-wave binding, natural entry/wake source, water-force change, dry
tuning, timed-level activation, merge or push. Master stays `a3dbee4`, M6A
stays `4d5bd21`. The 3-second intake delay remains unchanged. Review the hitch
classification before treating the integration prerequisite as closed; do not
invent a physics patch to compensate for off-CPU time.

## 1. Waves-Off hitch investigation

### Measurement changes

`WaterHitchTrace` brackets physics/process callbacks and stores bounded,
preallocated tick/frame arrays, starting at placement rather than after the
usual one-second warm-up. It records body/wheel/force wall times, nested query
cost/counts, contacts, immersion/flooding/intake/stall state, actual ticks per
frame, effects/audio/status callback wall times, real audio-loop starts,
entry/thump counters, emitters and object/node/resource/memory monitors.

Capture performs no CSV writes or prints. It stops **before** the normal CSV
export and screenshot, so those waits cannot masquerade as gameplay hitches.
Per-case engine-tick/UNIX anchors connect these samples to a system scheduling
trace. Instrumentation is opt-in; normal gameplay leaves it disabled.

These are **wall-clock** durations, not on-CPU execution times. The full effects
and audio callbacks include dry work and are diagnostic context, not precisely
scoped water-only categories. Course/material callbacks and GPU time are not
fully covered here. Do not reuse these columns as a passed total-water gate.

`tools/analyze_water_hitch.py` selects cases from the batch's `summary.json`,
rejects non-finite samples, missing/duplicate interior ticks, non-consecutive
frames and incorrect frame/tick water sums, and permits only a final partial
frame. All detailed captures validated, with no recorder overflow. The five
Python validator tests passed using `python3 tools/test_analyze_water_hitch.py`.
An extra attempted `python3 -m unittest tools/test_analyze_water_hitch.py` failed
module import because the sibling module is not on that invocation's path; it
was not a test pass. The documented direct-script invocation passed again.

### Protocol and unsuccessful/limited attempts

Xiaomi 13, Adreno 740, Godot 4.7.2 Forward Mobile/Vulkan 1.3.128, 2400×1080,
normal **120 Hz physics / 60 FPS cap**. No fixed-fps acceleration. No concurrent
desktop Godot. The owner save was byte-identical before/after every batch.

1. Three rally calm-pool cases on diagnostic APK
   `3433f2e464c1aa90f7990281b2d6ff3e458011f6b592321c7cda224198639824`.
   A JSON-number/string flag bug prevented detailed capture: retain these as
   **ordinary baseline measurements only**, maxima 25.220 / 20.049 / 22.967 ms.
   Its ring-buffer system trace also lost the beginning (only 36.76 s retained
   of 70 s); it is not used for hitch attribution.
2. Fixed option parsing, added its unit test, rebuilt diagnostic APK
   `a785cf9f590030df95b360b96687c056c5663c349e867687569fd0f77c970c8b`.
   Three detailed rally calm-pool cases: no severe warmed hitch. Early placement
   frames of 32.575 / 59.453 / 57.281 ms occurred about 0.04–0.06 s after placement,
   **before stalling**. They remain in raw traces, separate from warmed results.
3. Same detailed build, **two rounds × all three cars × four course spots**
   (24 cases). Shallow samples: 600 ticks after warm-up; deep: 1,920. Streaming
   Perfetto capture retained 319.987 s, without non-info error stats. Phone
   battery temperature 34.0→35.5°C, thermal status 0 at both checks. All raw
   cases, including slow ones, are retained.

The all-car run's maximum warmed frame intervals (ms):

| Car / round | 5 cm bay | 30 cm bay | Calm pool | Current pool |
| --- | ---: | ---: | ---: | ---: |
| 4×4 / 1 | 18.256 | 18.949 | 19.811 | 20.175 |
| Rally / 1 | 20.519 | 19.360 | 19.780 | 25.595 |
| Tuned rally / 1 | 20.163 | 29.752 | 22.647 | **33.802** |
| 4×4 / 2 | 19.668 | 20.011 | 19.790 | **38.607** |
| Rally / 2 | 20.751 | 19.518 | 21.725 | 19.923 |
| Tuned rally / 2 | 21.651 | 24.498 | 19.674 | 19.353 |

This reproduces a 4×4 deep-pool hitch too; the earlier rally-only observation
is not universal. The 4×4 eventually stalls/floods in this placement. We did
not change its intake, forces or flooding to obtain that result.

### Correlation with actual thread scheduling

Perfetto v58.2 trace processor, game `VkThread` tid 1195 / trace utid 7758.
REALTIME−BOOTTIME offset: `1789885938447045119 ns`, spread only 417 ns over
323 snapshots. Case clock anchors are in complete logcat; their JSON precision
is about 10 microseconds. Exact intervals and repeatable SQL are in
`tools/water_hitch_trace.sql`; all scheduling output is retained.

| Captured interval | Wall span | Running on CPU | Runnable, off CPU | Sleeping |
| --- | ---: | ---: | ---: | ---: |
| Tuned rally long frame | 33.801 ms | 6.906 ms | **16.599 ms** | 10.295 ms |
| 4×4 long frame | 38.603 ms | 6.805 ms | **21.485 ms** | 10.314 ms |
| Slow physics callback within that 4×4 frame | 10.418 ms | **1.289 ms** | **9.129 ms** | 0 ms |

The few microseconds' difference from the normal harness maxima reflects
different callback timestamps. `R`/`R+` mean ready/preempted, not waiting on an
application lock; sleeping time is separate. This interpretation follows
[Perfetto's scheduling documentation](https://perfetto.dev/docs/data-sources/cpu-scheduling).
The trace does **not** establish whether the sleeping portion is FPS limiting,
VSync or another wait; it does not justify blaming one particular Android app.

The slow 4×4 tick reports 9.872 ms water wall time, with 13 queries / 52 triangle
tests as usual. Yet the **whole physics-callback span** contains only 1.289 ms
of CPU execution. Most of that apparent water spike therefore cannot be new
water computation. The tuned-rally long frame has just 1.543 ms of accumulated
water wall time over three ticks, also insufficient to explain its whole frame.

Both captured long frames occur roughly ten seconds after placement, already
stalled, at flooding about 0.913 / 0.921, not on a new stall/full-flood transition.
Effects/audio/status were sub-millisecond; entry/loop-start/thump and object
counts show no coincident burst, and no spray emitters were active. Other
captured near-30 ms frames and startup transients remain available for review.
There is no measured reason here to change stall logic, sound padding, forces
or buoyancy. We made **no gameplay hitch fix** and did not alter phone CPU policy.

**Remaining uncertainty:** the older untraced 46.657 / 79.459 ms frames may have
other causes. The trace makes a scheduling explanation credible for this
reproduction, not universal. M6A acceptance and the live-wave prerequisite
remain explicit review decisions, not automatically checked boxes.

## 2. Preparation profiling and implementation

Separated static source indexing, outline/shore indexing, bed-limit derivation,
topology/attribute assembly, array/normal creation and native mesh commit.
Three desktop profiling runs (milliseconds):

| Phase | Shared deep mesh | All four shallow bays combined |
| --- | ---: | ---: |
| Total | **298.839–339.904** | **22.852–24.403** |
| Source index | 18.964–23.404 | Included above |
| Outline and shore index | 88.576–117.169 | Included above |
| Conservative depth | 89.808–95.522 | Included above |
| Topology/attributes | 89.672–95.536 | Included above |
| Normals/arrays | 6.123–6.163 | Included above |
| Native mesh commit | **0.350–0.426** | 0.058–0.073 |

The deep mesh is already shared between calm/current. The bays account for
only about 7% and have different footprints/depth masks: sharing them with the
deep geometry would not address the dominant cost while preserving exactness.
Mesh upload is not the expensive phase.

Instead, `tools/bake_water_waves.gd` generates **five compressed packaged
resources (~324 KiB)** from the existing builder: one shared deep top and four
distinct bays. They include mesh arrays, lookup cells and conservative masks.
`WaterWaveCourseCache` loads them only when explicitly requested, validates an
ordered SHA256 of original top/bed/colour arrays, geometry-related profile
values and bake revision, then adopts their data. It is not a user-data cache.
An incompatible/missing bake **fails closed**, with no hidden expensive rebuild,
weaker depth cap or coarser fallback. Regenerate the assets explicitly after
source changes; bump the revision when the derivation algorithm changes.

Tests compare every cached vertex/index/colour/limit/gradient, cell dictionary,
mesh array, bounds and representative sampler outputs against a fresh build.
All five agree exactly; stale geometry/profile/revision and malformed assets
are rejected. Ambient/runtime strength changes need no geometry rebuild.
There are still **31,912 triangles** across the six tops, counting the shared
deep mesh twice. No protected fixture is regenerated.

The lab prepares underneath the existing `LoadingScreen`, actually submits all
six tops, then shows the close-up view. Runtime waves are paused during setup.
No normal Test Ground/course hook or approach-triggered mid-session build was
added. Future live mode enablement must keep this covered, explicit opt-in path.

## 3. Phone preparation and GPU agreement — subchecks only

Fresh final lab APK, installed hash checked against local build:
`a670f2f4307b59fb6c14aa27c0669385ef1be02a7f3d09d0d30280e64e9f8abf`.
Three launches on the same Xiaomi/renderer/resolution, one-shot
`{"mode":"wave_lab"}` routed through the existing acceptance flag. Each exits
automatically. The final save hash remains
`878845146b3d11fe00678b6fcb86ae2983022b568e74c1a74e623e43a1a83b7c`.

| Measurement | Launch 1 | Launch 2 | Launch 3 |
| --- | ---: | ---: | ---: |
| Wave CPU preparation, including cache/view/top creation | **27.092 ms** | **37.652 ms** | **34.227 ms** |
| Cache load/hash/adoption subset | 18.555 ms | 18.019 ms | 15.190 ms |
| Separate car-free course CPU construction | 225.385 ms | 223.939 ms | 220.211 ms |
| Separate covered first-use wait | **753.147 ms** | **196.053 ms** | **153.919 ms** |
| Shared GPU evaluator, 576 points, maximum error | 0.000000078 m | Same | Same |
| Actual mesh attributes / 21 triangle samples, maximum error | 0.000000040 m | Same | Same |

Calibration max error: `0.00000001469538 m`; parity allowance: **0.001 m**.
Readback uses the real GPU, not a dummy backend. This tests the shared height
evaluator and actual triangle attributes, not rasterized spatial depth or GPU
normal parity. The first-use wait is elapsed time after CPU preparation until
two covered all-top draws; it includes setup/render waits and is **not an
isolated shader compilation timer**. Two further close-up draws occur before
uncovering. First launch is first observed use after installation; application
data and shader caches were not cleared, so no forced cold-cache claim.

All-top lab view: 13 draw calls / 33,535 submitted primitives. This is a
car-free lab observation, **not** the matched gameplay incremental drawing
gate. Desktop cache/mesh preparation was 7.917 ms (cache subset 6.661 ms), with
176.021 ms covered first use. Its parity matches the earlier review. The
desktop preview was inspected: geometry is intact; glare/readability remain
unpolished. No owner driving-feel approval is inferred from a synthetic view.

## 4. Regression and remaining gate

Final complete `./run_tests.sh all`: **115 scripts, 765 passed, 1 pre-existing
pending, 370,855 assertions, 479.013 s, exit 0, no SCRIPT ERROR or GUT errors**.
The pending kicker gas/landing scenario is unchanged. New bake tests: 3 passed /
307 assertions. Hitch recorder/option tests: 2 passed / 23 assertions. Runtime
and tests were frozen before this full run; later work only packages evidence
and writes documentation. Android export logs contain tooling socket/ADB
warnings; successful export is not a claim that those logs contain no errors.

What remains before natural-car waves:

1. Review the scheduling evidence and explicitly settle the M6A hitch/acceptance
   prerequisite (or request another targeted trace). Historical tails stay in
   the record; inherited Rock Canyon geometry/load debt is not water headroom.
2. Complete Task 0/4 measurement coverage: water-only external callbacks,
   non-overlapping total-water frame sums, baseline/flat-refined/max-packet
   controls, query workloads, valid GPU times, three 30-second phone repetitions,
   memory, thermal/long-frame analysis and view inspection. **4/5 ms p95/p99
   total-water ceilings and all incremental/frame gates remain unverified.**
3. Only after those gates, integrate live entry/bow/wake and stop at mandatory
   Task 5a so the owner drives before polish. No current driving feature or
   successful feel test is implied by this report.

All automated Godot runs are stopped. The diagnostic lab build is installed;
normal launch still plays the original waves-Off game, and the one-shot flag
has been consumed. Raw evidence, exact limitations and replay instructions:
[`m6w-review-data/README.md`](m6w-review-data/README.md).
