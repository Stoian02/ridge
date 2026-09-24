# M6A performance retest — 2026-09-23

Follow-up: `m6a-query-fixes-2026-09-24.md` records the subsequent ford query
optimization and creek rendering fix. This file retains the **pre-fix** audit;
its phone results must not be presented as measurements of the fixed build.

Completed following Claude's reproducibility review. **Performance acceptance
fails.** This supersedes the original report's performance interpretation; no
physics, tuning, surface or accepted level geometry changed during this audit.

## Method and timer audit

Runtime under test: `7a074b6` on `m6a-water-physics`. The initial reproduction
runs use the **unchanged** `debug/water_benchmark.tscn` and installed APK.
Later runs add only debug measurement tools and their launcher/tests.

`VehicleWaterController.water_time_usec` is the sum of two same-tick intervals:
`sample_body` (eight probes, intake query and state) and
`sample_wheels_and_apply` (four wheels, relative current and force accumulation
and submission). It excludes unrelated wheel/drivetrain work, Jolt integration,
effects/audio, rendering, and the recorder itself. These exclusions are
intentional for the spec's water sampling/state/force gate, not a whole-frame
performance claim. The original benchmark reads the preceding completed tick
at `physics_frame`; its initial/reset sample is outside the measured warm-up.
The timer measures elapsed wall time, not thread CPU time: OS preemption inside
either interval is included. A high maximum is retained, but cannot on its own
be attributed entirely to water arithmetic without a scheduling/profile trace.

The original report's command used `--headless --fixed-fps 120 --max-fps 0`.
This is an accelerated functional-test mode, not real-time gameplay pacing.
Retesting compares that command against normal-paced headless and windowed
runs, three repetitions for both rally and 4x4 on the same code. The desktop
uses the powersave governor and `balance_performance` energy preference; no
clock, power, thermal or priority settings are changed. Clock scheduling is a
plausible explanation for the timing difference, not an isolated proven cause.

New `debug/water_acceptance.tscn` records completed ticks after the car's physics
priority, nearest-rank p95/max and raw per-tick CSVs, plus real wall-clock frame
intervals and rendering peaks. It measures all three cars repeatedly, extends
deep immersion to 16 seconds after a one-second warm-up, and includes actual
creek/rut/ford views. Instrumentation affects the workload; it is not used to
replace the unchanged-benchmark comparisons silently. Device results, not a
desktop multiplier, determine the phone gate.
The original harness selects `floor((n - 1) * 0.95)`; the new recorder uses
`ceil(n * 0.95) - 1`. For 570 samples that is a one-sample rank difference, not
an explanation for the several-fold timing difference. The original desktop
comparison retains the original calculation unchanged.

Matched load comparisons use a separate detached `a3dbee4` worktree and the
unchanged three-round/five-level load benchmark. The owner save is retained
through replacement installs. The latest water build was restored at the
end and its installed APK hash verified. Master was not checked out, changed,
merged or pushed.

## Results

### Unchanged desktop benchmark

18 processes, four cases per process, same 570 measured ticks per case as the
original. These ranges cover the 24 **per-case p95s** in each mode, not a pooled
percentile across unrelated cases:

| Mode | Case p95 range (ms) | Median case p95 (ms) | Largest single tick (ms) |
| --- | ---: | ---: | ---: |
| Fixed 120 / uncapped / headless | 0.079–0.221 | 0.096 | 0.371 |
| Normal 60 FPS cap / headless | 0.249–0.356 | 0.285 | 0.976 |
| Normal 60 FPS cap / windowed | 0.194–0.351 | 0.291 | 0.717 |

The low number is reproducible in the original command mode, but it is **not
representative of normal game pacing**. These new runs do not reproduce Claude's
exact 0.45–0.55 ms range, so that remaining machine/session difference is not
claimed explained. His objection to using the original number for mobile
headroom is valid. No fixed desktop-to-phone multiplier is justified here.

All six windowed runs logged PulseAudio sink/channel initialization errors.
They still rendered/completed all cases, but are not valid evidence that desktop
audio output worked. The errors and process-exit warnings are preserved.

### First phone reproduction (unchanged installed benchmark)

Installed APK SHA-256 matched the local pre-audit APK:
`62d255836d5ac1364f6183f9e2e8d6689e5582cdce5abae971499c6d8e5d00a2`.

| Area | p95 ms | Maximum ms |
| --- | ---: | ---: |
| 5 cm bay | 0.348 | 1.645 |
| 30 cm bay | 0.412 | 0.589 |
| Calm | 0.323 | 0.530 |
| Current | **0.968** | 1.138 |

The current case exceeds the 0.50 ms gate. The course built in 0.291611 s,
also above its 0.25 s incremental allowance in this single run. The first
launch logged a Vulkan surface creation failure before a second process started
successfully; this is retained in the evidence, not an error-free startup claim.

### Extended phone audit and matched loads

The audit APK
SHA-256 is `c2a04d6e30cc8db3d027eedf83ec391c34e9071cc018088e0977f9bc10b082e6`.
It runs at the project defaults (60 FPS cap, 120 Hz physics), Vulkan Mobile on
Adreno 740, 2400×1080. It does not change phone power settings. At the course
batch start: USB-connected and charging, battery 74%, battery temperature 27.5°C, Android
thermal status 0. The pre-water baseline APK SHA-256 is
`784b584fa7215f0227723db3544fbdba1104a0e41cb41f990a88f9003648bfa5`.

The course audit completed **36 cases / 45,360 measured physics ticks**. An
independent CSV read recomputed all water-cost p95s and checked sample counts plus consecutive
tick IDs: all matched the JSON summaries. **34 of 36 cases failed the 0.50 ms
gate**. Per-car figures span all four areas and three repeats:

| Car | Per-case p95 range (ms) | Median case p95 (ms) | Maximum tick (ms) |
| --- | ---: | ---: | ---: |
| 4x4 | 0.296–1.324 | 1.124 | 2.507 |
| Rally | 0.953–1.366 | 1.124 | 10.798 |
| Rally tuned | 1.029–1.418 | 1.142 | 2.580 |

All deep cases ended fully flooded/stalled; measurements include the transition
to sinking rather than only five seconds of initial flotation. Case-average
rendering rates were 59.92–60.15 FPS, with up to a 60.308 ms frame. This is near
60 FPS on average, **not a claim that every frame met 16.67 ms**. Peak course
drawing was 27,695 primitives / 45 calls including labels/UI/effects.

Android's log buffer rolled during the course audit; the retained course log
contains only its latter half. The complete on-device JSON and **all 36 raw
CSVs were pulled and archived**, so timing results above are not reconstructed
from that incomplete log. Subsequent batches use continuous log capture. Course
build times visible in retained output include 0.492–0.520 s on repeats, above
0.25 s; the initial first build was 0.231726 s. Do not substitute the initial
fast build for repeat-load acceptance. Battery reached 30°C during the batch;
sampled Android thermal status remained 0.
Frame interval summaries are calculated by the recorder; raw per-render-frame
intervals were not saved, so the independent CSV check validates water timing,
not the frame-interval statistics.

### Real-level phone views

Three repeats, 1,200 measured ticks per placement after one second settling:
**15 cases / 18,000 ticks**, independently checked against the CSVs. These are
placed-car fixtures, not player-driven full runs: the run clock and safety-reset
controller are disabled after countdown, while car physics, water, camera,
effects and audio continue. This leaves the "GO" HUD visible in the captures;
its drawing is included. Telemetry is hidden. The phone's wider viewport and
different HUD state mean its drawing counts are not an exact A/B comparison
with the original desktop screenshots.

| Placement | Water p95 range ms | Max tick ms | Peak primitives | Peak draws |
| --- | ---: | ---: | ---: | ---: |
| Creek 780 m, +17 m lateral | 0.454–1.292 | 1.907 | **319,036** | 130 |
| Creek 820 m, +17 m lateral | 1.279–1.320 | 2.047 | 294,232 | 128 |
| Creek 860 m, +17 m lateral | 0.989–1.007 | 1.615 | **325,960** | 126 |
| Canyon ruts 340 m | 1.819–1.830 | 2.335 | 165,774 | 92 |
| Canyon ford 1290 m | **4.263–4.277** | 6.447 | 122,600 | 83 |

The explicit 0.50 ms incremental water gate was specified for the new course;
the ford is additional evidence of a more expensive existing-water workload,
not a reason to restrict optimization/measurement to the easy pool cases.
Creek 780/860 exceed the global 300k primitive budget. The sampled draw-call
limit passes, but this is not a whole-level worst-view guarantee. This audit
does not establish whether the creek primitive overrun predates M6A.

All case-average rates were near 60 FPS. However, the ruts had 20.9–21.245 ms
p95 frame intervals and the ford 19.638–19.791 ms: visible-frame smoothness is
not guaranteed by the average. No script error or audio-loop crash was logged
in these three view rounds. This is not a listening/subjective-audio acceptance.
Inspected phone captures show submerged car parts and the shallow ford bed;
owner visual/handling approval remains separate. Captures are under
`build/m6a-retest/phone-course/` and `build/m6a-retest/phone-views/`.

### Matched phone load comparisons

Order **baseline A1 → current B1 → baseline A2 → current B2**. Each process
loads all five levels in the existing order for three rounds: **60 loads total**,
six observations per version per level. Installs preserve data. No phone power
settings were changed. Battery temperature was 31°C at the start and 33°C at
the last batch's end (32.4°C at the later save check). Both versions returned to eight nodes / zero orphans
after every load, with resource counts plateauing by round two.

| Level | Baseline median total s | Current median total s | Median paired-round delta s |
| --- | ---: | ---: | ---: |
| Rally Road | 1.180 | 1.170 | -0.010 |
| Muddy Valley | 1.495 | 1.640 | +0.155 |
| Frozen Pass | 1.370 | 1.335 | +0.020 |
| Rock Canyon | 4.530 | 4.570 | +0.125 |
| Test Ground | 1.570 | 2.835 | +1.060 |

The last column pairs matching round numbers in adjacent A/B batches, then
takes the median of six differences. It is intentionally **not** the difference
of the two marginal medians. Times are rounded to 0.01 s by the old benchmark;
third decimal places above arise from taking medians, not finer measurement.

Rock Canyon totals by round:

- A1: 4.35, 4.53, 6.99 s; B1: 4.46, 4.62, 8.44 s.
- A2: 4.35, 4.53, 7.11 s; B2: 4.49, 4.52, 7.73 s.

Its paired differences were +0.11, +0.09, +1.45, +0.14, -0.01, +0.62 s.
The **pre-water build also slows in round three**, so neither the current total
slowdown nor the difference from the historical 3.9 s figure can all be assigned
to M6A. This is better controlled than separate desktop batches, but still not a
CPU-clock-controlled experiment; dry Frozen Pass also shifts by about +0.3 s in
round three. No fixed phone/desktop multiplier or isolated causal delta is claimed.

The current Rock Canyon's directly recorded new `water` build phase is
**0.17–0.30 s** in these batches, and **0.35 s** in the three view runs. That
phase alone exceeds the 0.10 s incremental limit. Muddy Valley's water phase is
0.06–0.13 s; its paired total changes also do not establish compliance with the
0.10 s limit. Test Ground's +1.06 s paired total difference is not exclusively
course construction; the separately observed repeated course builds near 0.5 s
already exceed the 0.25 s course allowance. **The setup gates are not passed.**

Current cleanup resources plateaued at 217 for Canyon and 164 for Test Ground,
versus baseline 199 and 146. No script error or crash was logged in these four
load batches. Stable counts do not prove there can be no longer-term leak.
The current audit APK was restored by the final batch; the save checksum before
and after matches (`878845146b3d11fe00678b6fcb86ae2983022b568e74c1a74e623e43a1a83b7c`).

## Acceptance and next work

**Performance acceptance fails; do not merge based on the old report.**

1. Optimize water sampling/setup without changing water behaviour or geometry.
   Include the much denser ford/creek beds, not just the simple Test Ground pools.
   Re-run the same real-time phone matrix and retain per-case tails.
2. Investigate the creek primitive overrun with comparable baseline views before
   choosing a visibility/batching fix. Do not silently alter accepted geometry.
3. Treat the inherited overall Rock Canyon load miss and repeat-load variability
   separately from water's incremental miss. Deferring construction is a separate
   owner-approved change, not an automatic part of this audit.

These are recommendations, **not implemented optimizations**. The audit changes
debug measurement tools, a debug-only launcher, tests and documentation only.
No car code, water runtime, surface value, level geometry or protected fixture
was changed. The final `./run_tests.sh all` rerun passed **730 tests, one
pre-existing pending**, 108 scripts / 328,773 assertions, 486.979 seconds,
exit 0, no `SCRIPT ERROR` or test failure. Its accelerated mode is suitable
for these functional checks, not the phone performance gate. The two new tests
check measurement percentiles and after-car, once-per-tick sampling. The existing
geometry/build-detail/car-balance fixtures passed unchanged. `git diff --check`
passed. The compressed full test log is included with the evidence.

Evidence is committed under `docs/notes/m6a-retest-data/`; PNG captures remain
local build artifacts. `tools/check_water_measurements.py` independently checks
the raw water CSVs and returns exit 2 for the failed course gate.

The follow-up waves request is recorded separately in
`docs/notes/water-waves-followup.md`; it does not expand M6A implementation.
