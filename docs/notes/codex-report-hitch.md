# Water hitch investigation — evidence audit, 2026-09-26

## Status: partial; fresh phone reproduction still needed

Work is on **`m6-hitch`**, branched from Claude's committed handover
`7a9fd64` on `m6-water-waves`. This pass changes **offline analysis and
documentation only**. No gameplay/recorder changes, tuning, geometry, acceptance thresholds
or protected fixture edits; no merge or push.

**A scheduling-caused hitch is demonstrated in the archived reproduction.
A flooded/stalled transition defect is not demonstrated. Neither statement
explains every historical long frame.** Do not mark the prerequisite closed.

The Xiaomi was not listed by `adb devices -l` during this pass. The owner has
been asked to reconnect it and leave Ridge closed. No desktop Godot instance
was running, but no new game run, build, install, phone capture or performance
acceptance was attempted. The work below re-analyzes **old captures**, not a
fresh reproduction on the current build.

## 1. Corrections to the handover's interpretation

The useful lead remains the rally cars in deep water, but distinguish final
case state, state on the hitch tick, elapsed water timers and actual CPU work.

| Historical frame | What the retained rows actually establish | Still unknown |
| --- | --- | --- |
| M6A **79.459 ms**, 4×4/current, process frame 2668 | Its frame CSV records **4.181 ms controller wall time over eight physics ticks**. This is narrower than all water work. | Effects/audio, GPU/waits and scheduling were not attributed; individual tick/frame association and a system trace are absent. |
| M6A **67.294 ms**, same case, frame 2404 | **39.936 ms controller wall time**, two ticks. This is a separate event from the 79.459 ms maximum and must also remain in the investigation. | Whether the long controller region was on CPU, descheduled or blocked. |
| M6W **53.558 ms**, refined-flat control | **37.883 ms** in measured water regions: controller 17.385, runtime 20.277 ms. No packets or emitter work; ticks are not stalled. | Disabling sources excludes active emission as necessary, **not the refined-water runtime/shader path or waits inside it**. “Not wave-caused” is too categorical. |
| M6W **35.656 ms**, 4×4/Car waves | Measured water CPU regions cover **2.170 ms**; about 56.5% flooded, not stalled. | Those regions do not dominate the interval; this alone cannot exclude indirect rendering/synchronization costs or identify the remainder. |
| M6W **36.583 ms**, rally/Car waves | **19.378 ms elapsed water regions**: controller 13.360, runtime 2.048, emitter 3.609 ms, remaining feedback/coordinator 0.361 ms. Both ticks are fully flooded but **not stalled**. | A large elapsed region warrants investigation, but does not establish expensive computation. No matching scheduling capture exists. |

The M6A current-case CSV also retains 50.113 and 40.040 ms frames, with 2.636
and 3.664 ms controller time respectively. Nothing is discarded because it
does not fit the proposed stalled-state story. The M6W tick/frame sums above
were checked directly against the archived CSVs; the
M6A format has only per-frame aggregate controller timing, not enough data to
reconstruct individual tick-to-frame assignments.

Claude's **46.657/30.657 ms** observations remain a supplied independent
review, not new raw measurements independently recovered in this pass.
`m6a-independent-review-2026-09-24.md` already cautions that their final
flooded/stalled state does not establish the state on the first long tick.

The handover also combines two separate trace sessions: the demonstrated
**33.801/38.603 ms** scheduling intervals belong to the **September 24
waves-Off all-car trace**, not the September 25 Full soak. The latter's maxima
were below 33.3 ms and cannot retrospectively explain the three M6W tails.

## 2. Full transition audit of the September 24 capture

Revalidated **all 24 cases, 33,096 ticks and 16,468 recorded process frames**,
including placement/warm-up. The 12 deep cases are two rounds × three cars ×
calm/current. No interior missing/duplicate tick, incorrect controller frame
sum or non-finite sample was accepted.

- **36 real state transitions:** 12 stalls, 12 sinking entries and 12 reaching
  full flooding. The initial observed state is not counted as a transition.
- Largest frame containing a transition: **18.494 ms**.
- Largest frame intersecting **±250 ms** around any transition: **19.825 ms**.
- Each deep case contains 720 fully flooded/stalled physics ticks after the
  transition: six simulated seconds at 120 Hz, **72 seconds total**. No >33.3 ms
  frame occurs in those fully flooded holds. These are short, correlated holds,
  not a long-soak guarantee or proof that a rarer defect cannot exist.
- The rally cars stall about **2.92–2.95 s** after the first recorded tick;
  the 4×4 about **9.04–9.06 s**. All reach full flooding around **10.92–10.95 s**.
  The 4×4 is a useful different-intake control, **not a guaranteed non-stalling
  control** at these placements. No tuning was changed to produce those states.

All **12 frames above 33.3 ms** in this archive are retained. Ten occur in the
first 0.061 s after the first recorded tick, around fixture placement/scene
startup, before any stall or flooding. They are a distinct class, not warmed
pool hitches and not silently deleted. Their game-thread CPU/wait breakdowns
are included in the expanded scheduling output; many are sleep-dominated, but
sleeping alone does not identify the reason. One early 47.256 ms interval has
24.552 ms running, 10.011 ms other thread state and a net 826,536-byte memory
increase: this is **not** classified as a scheduler-only frame or diagnosed as
an allocation bug merely from a net monitor delta.

The other two are the already recorded warmed current-pool hitches:

| Case | Wall ms | Running CPU ms | Runnable but off CPU ms | Sleeping ms |
| --- | ---: | ---: | ---: | ---: |
| Tuned rally, frame 7906 | 33.801 | 6.906 | **16.600** | 10.295 |
| 4×4, frame 10680 | 38.603 | 6.805 | **21.485** | 10.314 |
| Slow physics callback inside that 4×4 frame | 10.418 | **1.289** | **9.129** | 0 |

Both cars are already stalled, about 91–92% flooded; neither frame contains
the stall or full-flood transition. No coincident loop-start, entry or thump
counter increase, no object/node/resource count increase, and no active spray
emitter appears in those two frame records. Effects/audio/status callbacks
each stay below 0.5 ms. Static-memory changes are only +504/+368 bytes **net**;
these monitors cannot rule out temporary allocation/free churn.

The 4×4's controller reports a 9.872 ms tick inside the 10.418 ms physics
callback, yet the **entire callback ran for only 1.289 ms on CPU**. Therefore
most of that recorded water spike is not new water computation. The apparent
water cost and a scheduling hitch can be the **same event**, not necessarily
two independent causes.

## 3. Scheduling verification and its limits

The original local trace was decompressed and read again with the official
Perfetto v58.2 binary; its SHA matches the previously recorded reader.
Source CSV/metadata/trace archive hashes match their retained manifests.

Expanded selection covers **69 intervals**: every >33.3 ms frame, each case
maximum, each actual transition's containing frame and every physics callback
over 5 ms. Five milliseconds is a diagnostic selection criterion, not a new
performance gate. No acceptance ceiling was raised.

- Game process **1094**, game-thread **TID 1195 / utid 7758**, independently
  matched to the same logcat clock lines; never selected by `VkThread` name alone.
- **323** REALTIME clock snapshots, offset spread **417 ns**; per-case JSON
  anchors still have only microsecond-scale precision.
- All 69 clipped scheduling windows account for their full wall interval;
  no missing coverage and no positive non-info parser statistics.
- Re-running the original fixed-window SQL reproduces its published values.

`R/R+` means eligible to execute but not running; `S` means sleeping. This
distinction is supported by the [official Perfetto scheduling documentation](https://perfetto.dev/docs/data-sources/cpu-scheduling).
The trace establishes where the observed delay occurred, not why Android chose
that scheduling policy or which app should be blamed. Sleeping can include
normal frame pacing, synchronization and other waits; it is not automatically
an audio lock. Whole-frame CPU totals are not function call stacks.

**Coverage of the handover's historical frames:** none of the exact untraced
79.459, 67.294, 53.558, 35.656 or 36.583 ms intervals acquires a causal explanation
from this older trace. The independently reported 46.657/30.657 ms pair also
remains untraced here. The demonstrated platform attribution covers the
specific September 24 33.801/38.603 ms reproduction, not all tails by analogy.

## 4. Code inspection and changes

Read-only inspection of `VehicleWaterState`, `VehicleWaterController`,
`CarAudio` and `WaterEffects` found no explicit player creation/resource load
in the stall/full-flood transition. Stall changes scalar engine state; audio
sets engine target volumes to zero. Emitters/players are created at setup.
There are shared per-frame audio/effect operations and engine internals that
this inspection does not profile. Absence of an obvious allocation site is
not an allocation trace or proof of absence of a defect.

Offline tooling commit: **`2f7a8e6`**. Only offline tooling changed:

- `tools/analyze_water_hitch.py`: real transition-frame contexts, overlapping
  nearby windows, state exposure, every long frame and net event/monitor deltas.
  Existing top-eight output is retained but no longer the only tail listing.
  Diagnostic selection now follows the existing exact **>33.300 ms** milestone
  rule instead of the old helper's rounded >33.333 ms; this cannot hide a tail.
- `tools/water_hitch_windows.py`: reproducible SQL from validated CSVs and
  matching clocks, decimal-preserving UNIX conversion, explicit PID/TID,
  clipped running/runnable/sleeping/other time and missing-coverage checks.
- Tests cover initial-state vs real transitions, recovery, final partial frame,
  overlapping windows, retaining more than eight tails, the 33.300 ms boundary,
  clock precision, PID/TID mismatch, duplicate/missing anchors and SQL windows.
- `hitch-investigation-data/historical_rows.py`: repeatable raw archive
  extraction with M6W component/tick sum checks; it does not invent M6A detail.

**Verification:** all **42 Python tool tests pass**. The generated SQL executes
against the actual retained trace, with all interval coverage checks passing.
No GDScript, shader, car/surface/geometry or project settings were edited, so
no new Godot full-suite or GPU-parity run was made. Claude's independent
**799 passing / one inherited pending** result at the handover is historical,
not claimed as a new Codex run.

## 5. Next step once the phone is available

1. Check it is the intended device, Ridge is closed, no other test is running,
   and preserve/check save and installed APK identities. Never kill the owner's
   play session. No forced cache clearing, governor changes or screen recording.
2. Use the existing **waves-Off `WaterHitchTrace`** recorder first. Extend its
   opt-in runner only as needed for longer uninterrupted holds and bounded
   recording; do not introduce physics changes to force the result. Record
   transitions from placement, not only after warm-up, and retain startup tails
   separately from warmed operation.
3. Warm the app, rotate all three cars across calm/current, repeat entries and
   hold each flooded/stalled case longer than the earlier six seconds. Include
   dry/shallow control exposures, and verify actual intake/stall states rather
   than labelling the 4×4 “never stalled”. Run simultaneous streaming Perfetto
   with bracketed clocks, process/TID identity and full trace-coverage checks.
4. Attribute each reproduced tail to on-CPU work, runnable waiting, sleeping or
   a mixture before considering a fix. If Off does not reproduce an on-CPU
   problem, test the **specific** refined-flat and rally/Car-wave fixtures
   separately; no-wave packets do not disable the whole wave runtime.
5. If a costly transition is demonstrated, identify the responsible operation
   and propose its fix. **Ask before touching `car/` or surfaces.** If evidence
   only demonstrates platform waits, report that precisely. If no relevant
   tail recurs, say “not reproduced”; do not declare the historical ones solved.

No M6A/M6W acceptance, performance exception, Coastal Highway work, merge or
push follows automatically from this audit. The phone is the present dependency
for the next meaningful reproduction step.

Reproduction commands, raw/derived evidence and identities:
[`hitch-investigation-data/README.md`](hitch-investigation-data/README.md).
