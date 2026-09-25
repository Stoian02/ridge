# M6W — phone ambient-cost diagnosis (2026-09-25)

## Verdict and scope

**The slow Full case reproduces, but the claimed ambient-specific cost does
not survive controlled comparison.** Reversing mode order makes Full fast and
Off slow. Ambient arithmetic is a small part of the measured sampler cost;
the slowdown affects triangle lookup, packets, bounds and source updates too.
Do not cut the approved ambient waves or call the total-water gate passed.

Diagnostic work only, from `m6-water-waves` at `de50ab5`. Reviewed Claude's
`135c33f` wake/entry-kick/spray changes and `de50ab5` phone launcher/report.
Those features are preserved. No changes under `water/`, `car/`, `surfaces/`,
`effects/`, `levels/` or to protected fixtures; no changed wave equations,
strength, geometry, timing, cache semantics, physics or optimization.

Added an **opt-in diagnostic sampler** under `debug/`, a bounded tick recorder,
same-input replay and a read-only CSV summarizer. Ordinary gameplay never
instantiates them. The existing playcheck remains unchanged in its default
measurement path; optional flags select instrumentation/reversed order.

## First correction: these are not total-water measurements

`WaterMeasurement` records `car.water.water_time_usec` and sums it per rendered
frame. This includes the wave queries inside the controller, but excludes the
wave runtime/snapshot uploads, emitter, effects/audio/status and other work.
The playcheck explicitly prints **controller-only**. The prior phone note's
"total water CPU" label and categorical Car-waves acceptance are therefore too
strong. A controller value above 4 ms already exceeds that ceiling; a value
below it does not establish the all-water gate, especially without its p99.

The old/new desktop and phone p95 differences are not direct measurements of
ambient work. In particular, subtracting separately sampled percentiles does
not produce the percentile cost of a component.

## Device and reproduction

Owner's Xiaomi 13 / `41374bac`, Godot 4.7.2, Vulkan Mobile / Adreno 740,
2400×1080, 120 Hz physics, 60 FPS cap. Real 4×4, original playcheck route and
600 ticks per mode; no concurrent owner play. Desktop regression ran separately
on the PC during the instrumented phone checks, not as phone timing evidence.

The original retained phone CSVs were copied before running anything. A fresh
**unchanged** `de50ab5` export was built and installed first:
APK SHA256 `d66b5301466385861d80bfec88cd7ff6bfe2fedb5ba8a564621929e2a897abb9`.
The diagnostic APK is
`dcc628fb156d602b2d0aee0003fb1610d77bc8d8de17f3b36436d1e33186b523`.
These are local export hashes, not separately verified installed-file hashes.

Controller p95 per rendered frame (the original playcheck's frame CSVs):

| Run | Order | Off | Car waves | Full |
| --- | --- | ---: | ---: | ---: |
| Claude's retained last run | Off → Car → Full | 0.677 ms | 1.889 ms | 4.560 ms |
| Fresh unchanged baseline | Off → Car → Full | 0.712 ms | 1.989 ms | 4.057 ms |
| Split-cost diagnostic | Off → Car → Full | 0.695 ms | 2.013 ms | 4.832 ms |
| Same diagnostic, reversed | Full → Car → Off | 2.008 ms | 2.023 ms | 1.936 ms |
| Counters, production raw maths | Off → Car → Full | 0.681 ms | 1.970 ms | 4.364 ms |
| Instrumentation disabled repeat | Off → Car → Full | 0.699 ms | 1.909 ms | 4.684 ms |
| Instrumentation disabled + CPU observations | Off → Car → Full | 0.703 ms | 1.929 ms | 4.673 ms |

The diagnostic changes neither heights nor inputs. It adds clock/counter
overhead, so its absolute cost is **not acceptance timing**. A counters-only
repeat using production `WaterWaveMath.raw` also retained the late Full slowdown.
The reversed run is the crucial control: even water with **no wave queries**
gets expensive when measured last. Full is not intrinsically the 4.6 ms case.
These short runs continued near 60 FPS; that does not waive either water ceiling.

## Requested component and vertex measurements

The diagnostic mirrors only `raw`'s summation order, calling the unchanged
production packet/bow/bounded functions. Tests require **bit-exact** raw vectors,
float32 cached heights, evaluated-vertex counts and snapshot invalidation.
Each actual query still looks up the drawn triangle and interpolates its three
displaced vertices. It never substitutes replay data into the vehicle.

Means per **complete two-tick rendered frame**, rather than differences between
p95s (the CSV analyzer reports p50/p95/p99/max as well):

| Work | Car, normal order | Full, normal order | Full, first | Car, reversed order |
| --- | ---: | ---: | ---: | ---: |
| Newly evaluated vertices | 36.25 | 34.42 | 34.42 | 36.25 |
| Cache hits | 41.24 | 43.08 | 43.07 | 41.24 |
| Triangle lookup + barycentric | 0.284 ms | 0.685 ms | 0.295 ms | 0.299 ms |
| Ambient evaluation | 0.041 ms | 0.097 ms | 0.039 ms | 0.042 ms |
| Packet loop | 0.521 ms | 1.218 ms | 0.505 ms | 0.541 ms |
| Bow evaluation | 0.055 ms | 0.133 ms | — | — |
| Bounding step | 0.037 ms | 0.084 ms | — | — |
| Runtime/snapshot uploads, outside controller | 0.232 ms | 0.488 ms | 0.233 ms | 0.239 ms |
| Source observation/emission, outside controller | 0.210 ms | 0.498 ms | 0.219 ms | 0.223 ms |

There are at most 78 vertex **requests** for 13 queries × three corners × two
ticks, not 78 independent evaluations. The existing per-snapshot cache already
removes many repeats. Full evaluates slightly fewer unique vertices on this
trajectory. About 16.6–17.5 evaluations repeat a vertex from the other physics
tick in the same rendered frame, but with a **new snapshot serial/time**.

The specific ambient-trigonometry hypothesis is contradicted by both code and
measurement: `raw` runs both ambient sine/cosine expressions in **both modes**;
Car waves sets amplitudes to zero but does not skip their evaluation. Enabling
ambient does not control the packet loop's early-outs either.

An untimed-gameplay replay uses the **same points, phase, packets and bow** and
alternates only local ambient amplitudes; the live snapshot is never changed.
In the normal-order split run, 2,048 raw evaluations took about 26.2–26.5 ms
for either amplitude setting after Car waves, and 70.2–71.0 ms for either setting
after Full. With Full first, both settings took 26.3–26.5 ms. This is an
overall execution-speed difference, not new trigonometric work from ambient.

## CPU-frequency observations

The last ordinary, uninstrumented playcheck was accompanied by 61 read-only
samples of the non-main `com.ridge.game` thread (`22357`, process `22275`).
Every sample's last-CPU field was CPU 4. Its reported current frequency was
**2,592,000 kHz** throughout the early samples, then fell at **10:41:59**:
1,920,000 → 1,286,400 → 1,171,200 → 844,800 kHz, fluctuating mostly around
0.84–1.29 GHz through the late case. Car's timing window ended at 10:41:53.710;
Full's was approximately 10:42:02.900–10:42:07.892. This aligns the clock drop
with the slow late case. Most samples catch the thread sleeping between frames;
these are instantaneous frequency/last-CPU observations, **not a scheduler trace
or per-tick frequency-weighted CPU-time measurement**.

The evidence supports a device-frequency/run-age effect. A temporary launch
boost expiring is plausible, but identifying a particular vendor policy would
require another investigation. Thermal service reported status 0 and battery
31.6°C after the tests; that alone does not establish why the clock changed.
`/proc/uptime` was unavailable to the app UID, so that column is empty; correlation
uses the retained epoch seconds and device logcat timestamps instead.

The final Full case still has controller **p95 4.673 ms / p99 5.288 ms**. Those
are real ceiling misses under that device state, not numbers to discard because
the ambient-specific attribution was wrong. General steady-state water cost
still needs the complete measurement and, if necessary, optimization.

## Interpretation and next step

The fixed mode order confounds feature selection with elapsed run/device state.
The observed frequency decline supports this explanation; it is not proof
of a particular Android governor or a thermal throttle. This is **not a finding about the
older flooded-and-stalled M6A hitch**, which remains open and separate.

Recommended next implementation, only after review:

1. Repair the acceptance experiment: equal app-age/warm-up windows, balanced
   mode ordering/repeats, sustained cases and device-state evidence. Include
   every water subsystem and aggregate by actual rendered frame, then report
   both the approved 4 ms p95 and 5 ms p99 ceilings.
2. If steady-state water still needs optimization, target the measured general
   sampler/packet/lookup work, preserving exactly drawn heights and the owner's
   approved ambient appearance. CPU height-only evaluation and shared temporal
   packet terms are candidates to measure, not implemented fixes.
3. Do **not** blindly cache across physics ticks: the serial changes each tick,
   and using the earlier height would change the current exact drawn-surface
   contract. Static lookup/cached topology is safer to investigate first.

## Verification and limitations

Focused diagnostics/mesh tests: **9 passing, 13,542 assertions**, exit 0.
Full suite with frozen code/tests: **785 passing, one inherited pending,
121 scripts, 450,929 assertions, 454.358 s**, exit 0, no SCRIPT ERROR/ERROR/WARNING.
Independent CSV validation reproduces all six new runs' printed summaries
(18 cases / 10,800 ticks); split-cost validation covers another view of 5,400
of those ticks. No acceptance gate was requested from the CSV checker.
Protected geometry and balance fixtures pass unchanged. Shared CPU/GPU maths
was not edited; no new GPU-parity claim is made from this diagnostic pass.

Raw logs retain an Android Vulkan surface-creation failure before the successful
baseline launch; no measurements came from that failed startup. Export logs
retain the existing missing-icon warning. Two CPU-observation attempts did not
produce usable frequency evidence (one-way ADB discarded stdout; the second
expected a GLThread name this build does not use). Do not count them as passes.

No gameplay fix, budget waiver, final phone acceptance, merge or push.
Diagnostic tooling, evidence and notes were initially left uncommitted for review.
The owner's subsequent completion request authorizes a separate diagnostic
checkpoint commit before correction/implementation work. Its source baseline is
`de50ab5`. Pre-existing untracked imports and `tmux-session.sh` are untouched.

Save SHA256 before/after remained
`878845146b3d11fe00678b6fcb86ae2983022b568e74c1a74e623e43a1a83b7c`.
The diagnostic APK remains installed; both one-shot flags were consumed and
the app exited. A normal launch is ordinary gameplay, not another benchmark.
Raw evidence/rerun instructions are in
[`m6w-ambient-diagnosis-data/README.md`](m6w-ambient-diagnosis-data/README.md).
