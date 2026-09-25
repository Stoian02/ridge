# M6W — Test Ground waves completion and review

## Final verification and review handoff — 2026-09-25

The requested implementation/verification pass is complete and the tested APK
is installed. **Ready for owner/Claude review, not performance acceptance or
merge.** The earlier stage reports below are retained history, not the current
implementation boundary. No merge/push or Coastal Highway work.

| Check | Final result |
| --- | --- |
| Desktop correctness/regression | **799 passing, one inherited pending, no SCRIPT ERROR; exit 0** |
| Phone coverage | **48 complete timing cases**, all cars; 27 matched replays, 9 saturation/controls, 9 live cases, 3 five-minute Full soaks |
| Actual-control lifecycle | **342 checks / 9 scene-car cycles pass, twice**; cleanup and save preserved |
| CPU/drawn-GPU agreement | Desktop and Android pass; Android maximum 0.000000085 m, against 0.001 m |
| Whole-frame numerical gates | All 48 cases pass average FPS and frame p95/p99; about 60 FPS throughout |
| Total-water CPU 6/7 ms | **FAIL in 19/48 cases**: 16 replay + 3 saturation; live/soak cases pass |
| Matched GPU increment <=0.50 ms | **FAIL**: +0.638–0.706 ms replay, +0.909–0.924 ms saturation |
| Preparation / memory / drawing | Pass measured subchecks; all-top view is close to 300k primitives |
| Hitches | **Open**: three untraced >33.3 ms frames; none reproduced in the 15 measured minutes of traced soaking |

The owner-approved wave feel, car/surface tuning and protected geometry/balance
fixtures are unchanged. This final pass adds verification infrastructure and
evidence, not new wave strengths or a speculative hitch fix. Full evidence and
reproduction instructions: [`m6w-completion-data/README.md`](m6w-completion-data/README.md).

### Delivered feature scope

- Test Ground-only Off / Car waves / Full controls, default Off on each scene
  entry; mode changes use the normal Reset path and show a loading cover.
- Natural hull entry waves, curved bow/shoulder crests following relative motion
  (including reverse), alternating trailing wake and directional entry spray.
  Ambient waves retain the strength/look the owner approved.
- Gentle physical response uses the **drawn triangle height**, not a separate
  smooth function. Buoyancy and intake sample the same surface. The M6A
  three-continuous-second intake timer, flooding and restart remain unchanged.
- Bounded history: 16 travelling slots, one bow, two ambient components per
  eligible body; shoreline/depth caps, body isolation, pause and reset semantics.
- Exact packaged topology with source/profile validation and covered first use.
  No runtime geometry fallback or silent reduction of water detail.
- Exact CPU query hardening: height-only evaluation without unused gradients,
  conservative zero-contribution culling, original-order triangle lookup,
  within-tick observation reuse and unchanged-only uniform submission avoidance.
  No across-tick stale-height cache, native extension, or changed wave strengths.

The earlier owner feel checkpoints and Claude's wake/splash work are recorded in
`m6w-entry-readability-2026-09-24.md`, `m6w-bow-refinement-2026-09-24.md` and
`m6w-wake-and-splash-2026-09-24.md`. Final owner/reviewer acceptance is separate
from those iterative approvals and from automated correctness checks.

### Performance policy and measurement corrections

The owner-approved **provisional Test Ground** total-water CPU ceiling is
**6 ms/frame p95 / 7 ms/frame p99**. See
`m6w-budget-amendment-2026-09-25.md` for the explicit headroom trade-off and the
original failed 4/5 ms samples. Incremental CPU 0.50/1.0 ms figures are reported
optimization targets, not blocking gates. GPU, whole-frame, hitch, drawing,
memory and setup gates are unchanged; neither M6A nor later levels inherit a
blanket budget increase.

`WaterTotalMeasurement` groups actual completed physics ticks by process frame
and sums non-overlapping controller/runtime/emitter/coordinator/feedback/audio/
HUD/flat-animation regions. Wave queries are already inside the controller and
are never added twice. Recorded script timings are elapsed wall times (including
preemption), not a thread-running-time profiler. Rendering, audio workers and
Jolt are represented by separate GPU/full-frame observations, not falsely added
to the script sum.

Recorder v2 retains both the conservative water/shared feedback total and the
older whole mixed dry/wet callback upper bound. Recorder v3 adds a frame-end
timestamp and bracketed clock anchors for independent trace correlation; it
does not change counters, water behaviour or the timing regions. Historical
controller-only and accelerated numbers are not interchangeable with these
totals. No performance claim may be made by summing/subtracting CPU percentiles
or projecting desktop timings onto the phone.

The independent checker validates tick/frame continuity, associations, sums,
percentiles, elapsed duration, GPU-counter availability and complete configured
case counts. The report tool preserves individual cars/rounds and pairs GPU
p95 values by car/round instead of pooling away slow cases. Live trajectories
are explicitly not matched-pose GPU comparisons. A checker exit 0 means valid
evidence, **not** full milestone acceptance.

### Reviewable changes since Claude's phone check

| Commit | Purpose |
| --- | --- |
| `17ccc98` | Balanced-order ambient diagnosis and retained evidence; no production tuning |
| `5203e46` | Complete water-script measurement and independently validated phone cases |
| `3820d43` | Bit-exact height/lookup/observation optimizations |
| `3dcf4eb` | All-car live edges, bounded-source stress fixtures and memory estimate |
| `909f139` | Conservative zero-contribution culling and redundant upload avoidance |
| `f56b62b` | Water/shared feedback regions plus retained original mixed upper bound |
| `18a4d4e` | Explicit owner-approved 6/7 ms policy, old evidence and checker boundaries |
| `f0c033b` | Actual-control lifecycle audit, live shallow/recovery fixtures, trace clocks and independent per-case/GPU reporting |

The current phone pass also adds opt-in lifecycle auditing through the actual
wave controls, frame-clock trace anchors and all-timed-level isolation tests.
Those additions are verification infrastructure, not a water-physics change.
The 27-case matched replay ran on clean `18a4d4e`; later checks use `f0c033b`.
The latter changes only opt-in diagnostics, tests and offline analysis; normal
wave/car/level code is identical. Exact APK hashes and source patches accompany
each run. Recorder v3 does not change the measured regions from recorder v2.

### Balanced replay

Xiaomi 13, Android Vulkan Mobile, 2400×1080, Godot 4.7.2, 120 Hz physics,
60 FPS cap. Each car warms for 60 seconds, each case settles for 10 seconds,
then records 60 seconds. Three Latin-rotated Off / Car waves / Full rounds per
car: **27 complete cases**, independently validated. This is frozen-car
matched-pose replay for cost isolation, **not natural driving or feel approval**.

- **Whole-frame numerical gates pass in all 27 cases**: average 60.00–60.03 FPS,
  process-frame p95 17.050–17.838 ms, p99 17.496–19.031 ms.
- **Total-water CPU gate fails in 16/27 cases** (all are wave-enabled).
  Car waves p95 6.198–6.307 ms; Full p95 5.675–6.340 ms. All p99 values remain
  below 7 ms, maximum 6.611 ms. No pooling or silent rounding to a pass.
- **GPU allocation fails in all 18 paired wave-enabled cases**: increase in
  GPU p95 versus matched Off is +0.638–0.706 ms against +0.50 ms. Absolute GPU
  p95 is 7.607–7.670 ms Off, 8.264–8.360 ms with waves. Car and Full remain
  close; these data do not establish ambient trigonometry as the main cost.
- Wave preparation CPU is 39.984–69.059 ms, within 250 ms. Draw counts and
  primitives at this close view remain within the global limits; the all-top
  stress view is checked separately.
- One **36.583 ms frame** occurs in rally / Car waves / first round. Its two
  associated ticks are fully immersed/flooded but **not stalled**, with 16
  evaluated vertices and 11 packets each. Water regions total 19.378 ms;
  query subtotal 2.657 ms. This untraced interval has no demonstrated cause.
  A later trace cannot retroactively explain it. It remains in raw evidence.

The amended 6/7 ms CPU policy and unchanged GPU limits remain in force.
Sixty FPS alone is not a substitute for those gates or resolution of the hitch.

### Final-source desktop verification

`f0c033b`: **799 passing, one inherited pending, 604,581 assertions, 127 test
scripts, exit 0, no SCRIPT ERROR**, 503.811 seconds. The pending jump/landing
case is unchanged. Both protected fixture files and everything under `car/`
and `surfaces/` are unchanged from M6A `4d5bd21`.

Real Vulkan Mobile desktop verifier: 576 evaluator points, maximum error
0.000000285 m; 384 curved-bow points, 0.000000205 m; 21 drawn-triangle samples,
0.000000179 m. All well inside 1 mm. Headless output is not used as GPU proof.

The new focused lifecycle/scenario file passes all three tests; the independent
Python checker/reporter suite passes 16 tests. The first focused attempt caught
two missing explicit `WeakRef` types in the new audit; corrected before the
feature commit and complete rerun. Its failed log is retained, not discarded.
The sandboxed import's socket errors and successful unrestricted rerun are also
retained as environment diagnostics, not a gameplay failure or hidden pass.

### Phone lifecycle and first observed enable

The actual pause-menu wave action, Reset, pause/resume, held-touch release,
mode changes, water-world rebuild and complete level destruction pass **342
checks over nine scene/car cycles** (three per car), twice. The node count
returns to 10 after every cycle; all 11 sound players stop on exit, bindings
clear and runtime/emitter nodes are freed. Car changes use scene recreation
with `car_override`, avoiding mutation of the owner's selected car/save; this
is not a simulated tap through the garage's persistent selection UI.
The unchanged full desktop suite separately verifies the Change car button's
signal/routing and selection persistence; these scopes are not conflated.

First batch: initial CPU preparation 58.049 ms, covered wait 722.616 ms.
Repeated batch: initial CPU preparation 55.716 ms, covered wait 656.629 ms.
Subsequent scene enables are recorded individually in `lifecycle.json`.
These are separate CPU and covered-wall measurements, not additive intervals.
`install -r` preserves application/driver shader caches: **not a forced cold
driver-cache benchmark**. The cover is exercised through the real UI; the
phone screenshot shows all three wave buttons readable and unobstructed.

The first host batch hit a launcher race: Android returned before the app PID
was observable, so the wrapper prematurely tried to fetch. The game still
completed all nine cycles successfully; the complete short log was recovered
from logcat and raw JSON retained. The wrapper now allows app startup before
polling, and the complete audit was repeated with continuous logging. This
was a host test-runner correction, not a game crash or a physics change.

### Phone maximum-source stress

Three rotated 30-second rounds, one 4x4, matched fixed camera showing all water
tops: ordinary Off / Full / debug refined-flat. The latter uses the same refined
topology/shader with ambient, bow and travelling sources zero and emitter stopped;
it is not a fourth player setting or a substitute Off baseline.

| Mode | Total water p95 / p99 ms, range across rounds | GPU p95 ms | Whole-frame result |
| --- | --- | --- | --- |
| Off | 2.709–2.737 / 2.872–2.958 | 8.660–8.695 | Numerical gates pass |
| Full, 16 active packets | **6.990–7.039 / 7.179–7.208: FAIL** | 9.569–9.619 | Numerical gates pass; no >33.3 ms frames |
| Refined flat control | 3.588–4.824 / 3.782–5.002 | 9.442–9.483 | Numerical gates pass; one 53.558 ms frame |

Full GPU p95 is +0.909–0.924 ms above the matched Off case: **fails +0.50 ms**.
The refined-flat control alone adds +0.747–0.823 ms. This points toward the
shared refined-surface/shader path for the next GPU investigation; it does not
separate topology from shader instructions or prove a particular optimization.
There is no reason here to cut the owner's approved ambient strength.

Every Full tick retains all 16 active slots, every control tick zero. Full max
drawing is 84 calls / 293,409 primitives; refined-flat max is 87 / 293,553.
Both meet the global limits, but the all-top view has little primitive margin.
CPU setup is 42.790 ms. Conservative wave-owned memory estimate is 4.855 MiB
(4,244,328 CPU bytes + 846,660 GPU bytes, five unique tops/six views, including
1 MiB reserve), under 16 MiB; this is not measured driver/process RSS.

The refined-flat long frame has zero packets/emitter cost and no stalled state.
It is flooded, with 37.883 ms in measured water regions: controller 17.385 ms,
runtime 20.277 ms, nested query only 0.599 ms. These elapsed wall values include
possible scheduling/lock waits. No matching trace exists for this frame, so
neither allocation, audio, shader submission nor OS preemption is asserted as
its cause. It does show that active wave sources are not required for this tail.

### Phone live driving (unfrozen cars)

Nine 108-second cases: all three cars × Off / Car waves / Full, with a 60-second
app warm-up per car and 10-second settling period per case. All raw cases and
eight trajectory segments per case are retained. Initial entry speeds are
3/8/15 m/s, not enforced constant driving speeds; subsequent motion uses normal
forces and input. Other segments cover reverse, current drift, deep calm water,
an explicitly initialized stalled-engine exit, and shallow water. The fixture
resets at each 12-second boundary; those frame intervals are **not removed**
from the performance/tail results.

- **CPU and numerical whole-frame gates pass in all nine live cases.**
  Car waves water p95 4.948–4.969 ms, Full 4.881–4.905 ms; maximum water p99
  5.173 ms. Frame p95 17.314–17.477 ms, p99 17.739–18.425 ms, average about
  60.00–60.01 FPS. These do not waive the heavier replay/stress failures.
- Every car/mode reaches full immersion and full flooding in the deep segments
  and naturally stalls there. Current-pool sideways travel is 1.57–1.84 m;
  calm-pool horizontal movement stays small. Recovery segments finish unstalled
  and dry for every car/mode. They **initialize** the stalled precondition;
  they do not claim a continuous natural stall-to-exit journey.
- All three initial entry-speed segments, reverse and shallow travel are
  present in each CSV. Car-wave sources reach at most 11 active packets in this
  batch. Detailed per-segment costs/coverage are in `live-coverage.md`; its
  nominal phase classification omits 0.1 s near reset boundaries only for that
  descriptive breakdown, never from the primary measurements.
- Drawing stays at or below 82 calls / 239,837 primitives. GPU timings are
  retained, but trajectories differ: their differences are **not** used as
  matched-view GPU acceptance.
- One **35.656 ms** frame occurs in 4x4 / Car waves. Water regions total only
  2.170 ms; it is fully immersed but only about 56.5% flooded and **not stalled**,
  with one packet. It is not at the fixture's reset boundary. No system trace
  covers this case; CPU/GPU counters do not prove the remainder's cause.

The soak is separately instrumented with a scheduling trace. That does not
retroactively attribute any of the untraced intervals above.

### Warmed Full soak and scheduling trace

Three **continuous 300-second measured cases**, one per car, with Full enabled,
each following 60 seconds of app warm-up and 10 seconds of settling. This is
not a sum of short exported cases. The live eight-segment fixture repeats;
its explicit 12-second car/history resets remain in the timing data. Therefore
this checks sustained phone/process behaviour with repeated driving states,
**not five uninterrupted minutes in one flooded pool or an unreset wave clock**.
Pure lifetime/pause/clock tests and the 16-slot saturation cases are separate.

A 20-minute Perfetto scheduling/process/frequency capture runs alongside this
soak. Its overhead is acknowledged; the untraced replay, stress and live cases
remain separate primary performance evidence. Frame-end timestamps and each
case's bracketed UNIX/uptime anchors permit correlation only to this matching
capture. Trace-derived explanations must not be projected onto earlier runs.

All three soak cases pass CPU and numerical whole-frame gates, at about
60.00–60.01 FPS, with **no >33.3 ms frames**:

| Car | Total water p95 / p99 ms | Frame p95 / p99 ms | Maximum frame |
| --- | --- | --- | --- |
| 4x4 | 4.882 / 5.101 | 17.474 / 18.339 | 25.614 ms |
| Rally | 4.869 / 5.072 | 17.480 / 18.335 | 21.320 ms |
| Tuned rally | 4.888 / 5.105 | 17.507 / 18.355 | 31.116 ms |

The longest frame in each case is selected for trace inspection even though
none meets the 33.3 ms tail threshold; those maxima are not relabelled hitches.
The lack of a reproduced long frame in this capture **does not fix or explain
the earlier untraced tails**.

The matching trace has no positive non-info parser statistics; 1,202 REALTIME
clock snapshots have only 781 ns offset spread. Game-thread TID **14678** is
selected from contemporaneous Godot logcat (PID 14498), not merely by the shared
`VkThread` name. Its clipped scheduling states account for each complete window:

| Selected maximum | Running on CPU | Runnable but off CPU (R/R+) | Sleeping (S) |
| --- | --- | --- | --- |
| 4x4, 25.614 ms | 8.046 ms | 11.655 ms | 5.913 ms |
| Rally, 21.320 ms | 5.360 ms | 0.053 ms | 15.906 ms |
| Tuned rally, 31.116 ms | 12.195 ms | 8.220 ms | 10.701 ms |

R/R+ is scheduler waiting, not active GDScript execution. Sleeping alone does not
identify a lock, normal pacing wait or audio operation. These are **whole-frame
windows**, not instrumented call stacks, so the table does not assign each wait
to a particular water function. For example the tuned maximum contains 14.206
ms of elapsed water regions, greater than the thread's 12.195 ms running time
over the entire frame: wall counters are not interchangeable with CPU execution
time. Numerical alignment also has the JSON clock anchor's microsecond-scale
precision; the nanosecond offset spread is not a claim of nanosecond game-clock
accuracy. [Perfetto scheduling semantics](https://perfetto.dev/docs/data-sources/cpu-scheduling).

The first exploratory query aggregated all three identically named Vulkan
threads and therefore summed three frame durations. It was rejected, retained
with a `NOT-game-thread` filename, and corrected to the observed TID. The final
query explicitly verifies accounted duration equals interval duration. SQL,
generator, outputs and tool/trace hashes are retained. The 232 MiB raw trace is
kept locally (129 MiB gzip) under `runs/m6w-completion-data/`, not committed;
small derived evidence is committed. This is **not a universal explanation of
the historical M6A hitch**, and no gameplay hitch fix is claimed.

### Android GPU parity

The exact installed APK's real Adreno/Vulkan verifier passes: 576 evaluator
points at maximum **0.000000079 m**, 384 curved-bow points at **0.000000085 m**,
21 drawn-triangle samples at **0.000000037 m**. Calibration error is
0.00000001469538 m. This is numerical verification, not a GPU performance pass;
the independently measured GPU allocation failures above remain unchanged.

### Non-blocking wave-work targets

These are percentiles of the **raw per-frame sum** of nested wave queries plus
runtime, emitter and coordinator regions. They are not differences between
component percentiles, nor the counterfactual time saved by disabling waves.
The owner retained 0.50 ms p95 / 1.0 ms p99 as optimization targets only.

| Full workload | Attributed wave work p95, range across cases | Largest p99 |
| --- | --- | --- |
| Matched replay | 2.922–3.278 ms | 3.443 ms |
| 16-slot saturation | 5.092–5.118 ms | 5.270 ms |
| Live driving | 2.504–2.551 ms | 2.727 ms |
| Warmed Full soaks | 2.507–2.554 ms | 2.729 ms |

These targets are missed and remain visible; they are not reintroduced as an
extra acceptance gate. The separate absolute CPU and GPU misses remain real.

### How to reproduce and review

Fresh export first: `tools/android.sh build`, then `tools/android.sh install`.
`install` alone installs the existing APK; it does not compile new source.
The measured `f0c033b` APK SHA-256 is
`08437d1beb642ff58c3b74564ac3834bea67c237a65577043d81d9bc34eb83ca`;
the installed file is checked against it for each batch. Build/launch dirty
patches contain documentation changes only; no post-export runtime edit.
The phone is Xiaomi 13 / model 2211133G, Android 16 (SDK 36), serial 41374bac.
Final save SHA-256 remains
`878845146b3d11fe00678b6fcb86ae2983022b568e74c1a74e623e43a1a83b7c`, identical
to the pre-matrix save. All diagnostic flags are consumed and the app is closed.
Only this run's exported system trace was removed from the phone after matching
its SHA-256 to the retained local raw copy and verifying the gzip; app results,
save and caches were not removed. It can be recovered from the local copy.

Use the retained host scripts/configs in `m6w-completion-data/` archives only
with an idle, owner-authorized phone. They refuse to interrupt a running game,
retain local/installed APK and save hashes, consume one-shot flags, stream logs,
and export raw samples after process exit. Do not run another Godot instance
or a screen recorder alongside timing cases. Rendering readback/PNG export is
outside the measured windows. Charging and sampled thermal/frequency state are
retained; there is no governor override, forced frequency or thermal bypass.

Review the exactness changes (`3820d43`, `909f139`) separately from measurement
scope (`5203e46`, `f56b62b`) and test infrastructure (`f0c033b`). Recompute raw
statistics with `tools/check_wave_acceptance.py` and paired GPU reports with
`tools/report_wave_acceptance.py`. All archives keep failures and exploratory
attempts; see the evidence README for provenance limitations. Numeric checks,
source correctness, owner feel, phone acceptance and merge authority are
different decisions.

### Owner playtest path

Open **Free Drive**, pause, then choose **Water waves — Test Ground → Full**.
The water areas are behind the start. **Car waves** removes only ambient waves;
**Off** is the baseline. Each change resets the car and may briefly show the
loading cover. Re-entering Free Drive starts Off; this is deliberately not a
persistent setting, and the timed levels remain unchanged.

Try a slow and a faster entry, steering/reversing in water, then stopping near
the bank and in deeper water. The engine stalls only after three continuous
seconds with its intake underwater; Reset restores the usual spawn/state.
These checks are for the owner's judgement of visibility and feel, not a request
to accept the documented timing misses. No automated Godot runs should start
while the owner plays.

### Remaining review boundary

The next step is **Claude's whole-milestone review and the owner's playtest**,
not another unapproved budget increase or silent reduction of wave quality.
The measured adjustment proposal is to investigate the refined-surface/shader
baseline first for GPU cost, and preserve exact current-tick sampling when
addressing the heavier CPU cases. No shader/mesh quality change or native/C++
rewrite is included or assumed approved. Review should decide the next scoped
optimization/acceptance action; the current 6/7 ms and +0.50 ms limits stand.

The historical M6A hitch remains open. Scheduling traces explained two specific
earlier long frames, not every historical tail. The later optimized 4x4 run's
39.572 ms frame occurred flooded but not stalled; do not claim the problem is
universally rally-only or caused by a stall transition.

Wave reflection/refraction, obstacle interaction, full fluid-volume conservation,
breaking surf, aquaplaning/skimming, snorkel art, timed-level waves and Coastal
Highway remain outside this milestone. The implementation remains on
`m6-water-waves`, based on unmerged M6A `4d5bd21`. Preserve the car/surface tuning
and protected fixtures; do not merge either branch without owner approval.

## Historical isolated groundwork report — 2026-09-24

**Latest delivery:** the owner-approved
[`PC Test Ground driving prototype`](m6w-pc-prototype-2026-09-24.md) now connects
natural entry/bow/wake, drawn-height physics and Off / Car waves / Full controls.
**774 tests passed, one inherited pending, no SCRIPT ERROR**. Stop for Task 5a
owner feel feedback; phone/hitch acceptance remains deferred, not passed.
Earlier isolated-stage reports below remain historical evidence.

**Later review follow-up:**
[`m6w-review-followup-2026-09-24.md`](m6w-review-followup-2026-09-24.md) records
phone hitch tracing, exact packaged topology, 27–38 ms phone preparation,
phone parity and 765 passing desktop tests. Complete total-water phone
acceptance and live-car integration remain open. The original `e37620d` stage
and its limitations below are retained as history, not silently rewritten.

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
