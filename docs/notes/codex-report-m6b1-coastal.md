# Coastal Highway B1 — implementation and acceptance report

2026-10-07. Branch `m6b-coastal-highway`. Runtime source under acceptance:
`b8b182e`, after whole-route checks `fe8848c` and recorder `caa3d8f`. No merge or push.

**Status:** approved driving/presentation implementation and automated B1
acceptance are complete. **The owner explicitly chose to leave it
unscored until B2** on October 7. Owner whole-route phone feedback remains a
separate gate; catalog/scoring work is deferred, not unfinished implementation
within this now-approved preview scope. This report does not
claim B1 is merged, scoring-ready or that B2 fits the remaining budgets.

## What was approved and built

The owner approved the plan, then the larger lift-and-balance jump, tunnel and
bridge, longer/more arched bridge refinement, dry surfaces and finally the
land/presentation. This pass changes no approved geometry or tuning. It adds
end-to-end and phone acceptance instrumentation only.

| Feature | Implementation commits | Delivered shape |
| --- | --- | --- |
| Dry route/true gap | `ff673f4`, `72b3e48`, `203d2b7` | 3,001.354 m; seven checkpoints plus finish; genuinely missing road/shoulder/ground support |
| Owner jump refinement | `0efa994` | 18 m gap (853–871 m), 2 m drop, 10° ramp, 7% landing; reset at 730 m |
| Tunnel / independent stone bridge | `bd3f57d`, `f1e3a45` | Tunnel 610–710 m; stone, not the existing log bridge implementation |
| Owner bridge refinement | `b845a20` | 2054–2074 m, 0.30 m deck crest, 4.5 m arch rise, 6 m dry channel |
| Dry sand / additive surface data | `ac2ea81`, `923a5cf`, `441ff5d` | Firm sand 1350–1950 and 2250–2550 m; matching darker shoulders, shallow ruts, flush transitions |
| Land / selective protection | `1ea9e06` | Independent shoreline/headlands, guardrails 80–250 and 2700–2860 m, wall 440–570 m |
| Scenery / weather | `69f45c7` | Sparse static mixed batches, clearing-weather light, depth-tested rainbow, existing padded wind loop |
| Whole-route / phone tooling | `fe8848c`, `caa3d8f` | Ordinary-input route driver, real checkpoint crossings, lifecycle tests, raw frame and load recorder |

The accepted car tuning, route, jump, bridge and surface values are unchanged
by acceptance work. All historic geometry/balance fixtures remain unchanged.
The new sand/grip additions in Task 5 were separately approved and do not
alter any pre-existing grip-table entry. No shortcut is active.

**B2 deliberately absent:** sea, puddles, flooded dip, current crossing, local
wet/soft patches and timed-level waves. The channel/cove are dry ground, not
fake non-interacting water. Every measured Coastal world must report zero
water bodies and wave bindings. Wet-asphalt/soft-sand files are data only.

## Driving evidence and its limits

The earlier reset-based jump matrix remains unchanged: three repeats for each
car at TC 0%, 15%, 20%, 100%, using ordinary pedal pitch corrections. Off-centre
crossings, too-slow failure and ravine bypass checks remain in the suite.
Held-throttle and uncorrected coasting are retained stress observations, **not
clean-landing passes**. See [the jump report](m6b1-jump-feasibility.md) for the
rejected shapes, harder landings and owner approval history.

The new `CoastalRouteProbe` starts at the actual start, uses steer/gas/brake
only and never writes progress, pose, forces or velocity during the drive.
The tunnel/run-up is uncapped; airborne pitch feedback imitates the owner's
technique; the ordinary test driver brakes after landing for the descent. This
demonstrates available control authority, not human driving skill or an assist
enabled in the game. Only measured gate signals count toward completion.

Initial headless all-car check: one test, 75 assertions, 42.125 s, exit 0,
no script errors. TC 20% throughout:

| Car | Run time | Max centreline offset / half road width | Resets | Gates |
| --- | ---: | ---: | ---: | --- |
| Rally | 169.283 s | 0.886 | 0 | 1–7 then finish 8 |
| Tuned Rally | 162.308 s | 0.886 | 0 | 1–7 then finish 8 |
| 4x4 | 189.692 s | 0.772 | 0 | 1–7 then finish 8 |

All three finished upright and showed the real results screen. The same test
checks restart, manual reset, automatic fall reset, pause/resume, car-select
and menu routing, audio teardown and unchanged sandbox progress. Car-select
and menu routing are verified with the existing scene-change test double,
not claimed as a human touchscreen test. These times do **not** set stars.

## Phone method and artifact

Xiaomi 13, serial `41374bac`, 2400×1080, normal speed, project 60 fps cap and
120 Hz physics. Fresh corrected debug APK from `b8b182e`:

`d413f44239382bb241c6fee3f1de36edfd942121b2e888bbe0e7b51602e5cda5`

`adb install -r` preserves progress; Ridge was confirmed closed first. Save
hash before: `efe52f8b43a6a42207f3c3c8433e770ecb429cae116675d607cce643532a0379`.
The initial diagnostic started at 33.0°C; the clean rerun started at 35.6°C,
battery 20%, USB charging.
Per-mode battery/thermal snapshots are retained with results; this is not an
unplugged battery-life or cold-storage-cache experiment.

New opt-in `debug/coastal_acceptance.tscn` modes:

- `loads`: first process-cold load plus three repeats; no forced cache flush.
- `views`: eight views, then reverse order; two seconds settling followed by
  ten seconds measurement each. Frozen car is explicitly a view diagnostic.
- `drive`: all three complete routes, real-time ordinary inputs at TC 20%.
- `soak`: ten seconds settling, then five minutes of the opening scene.

The recorder keeps raw wall-clock frame intervals, actual physics-tick counts,
render-submitted primitives/draws including shadows, station and every interval
over 33.3 ms. Tails are classified within the first 0.10 s of a case or warmed;
neither class is removed from percentiles. Summaries are independently
recomputed from CSV by the archived `analyze.py`. CSV/JSON agreement is not
itself a budget pass. Automated-driver/recorder overhead is included.

Empty-water CPU is reported separately as controller plus existing traced
effects/audio/HUD regions (an upper bound, not Jolt/renderer attribution).
Frozen view cars do not integrate, so stale controller timings are not counted.
It is not the future B2 water allowance.

### Load results

All times below are milliseconds except Trail build seconds. Native resource
load, instantiate and ready are separate; total through ready includes all
three. The cold first case is retained, not replaced with the fastest repeat.

| Case | Resource | Instantiate | Ready | Total through ready | Trail build (s) | Cover | First interactive |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| First load | 10.913 | 29.301 | 2731.823 | 2772.037 | 2.542 | 3053.732 | 5945.780 |
| Repeat 1 | 3.003 | 22.139 | 2670.441 | 2695.583 | 2.649 | 2806.511 | 5700.853 |
| Repeat 2 | 4.315 | 24.482 | 2594.877 | 2623.674 | 2.572 | 2725.092 | 5614.694 |
| Repeat 3 | 3.614 | 22.817 | 2694.897 | 2721.328 | 2.676 | 2832.716 | 5720.574 |
| Rally drive load | 11.946 | 19.377 | 2683.970 | 2715.293 | 2.516 | 2993.875 | 5886.005 |
| Tuned load after Rally drive | 11.328 | 54.563 | 4154.107 | 4219.998 | 4.108 | 4330.568 | 7236.986 |
| 4x4 load after Tuned drive | 25.176 | 56.779 | 4170.615 | 4252.570 | 4.122 | 4378.027 | 7273.388 |
| View-session load | 8.791 | 19.960 | 2786.617 | 2815.368 | 2.590 | 3072.755 | 5965.884 |
| Soak-session load | 11.041 | 26.466 | 2692.886 | 2730.393 | 2.504 | 3039.170 | 5925.606 |

**Corrected-build load gate passes <5 s, with no script errors or deferral.**
Crucially, the post-drive reloads are slower than the rapid four-load sequence.
Use **4.253 s through ready / 4.378 s cover**, not 2.7 s, as the observed load
headline. The warm 4x4 phase leaders are field 1.649 s, terrain 0.966 s, road
0.704 s, road blend 0.467 s. Many phases rise together; no specific cause is
claimed from this capture. Battery temperature rose from 36.3°C before the
three drives to 37.3°C afterward. The 0.747 s remaining build margin is not a
guarantee that B2 will fit; exceeding 5 s later still calls for deferral.
All per-phase values, including tiny phases, remain in JSON. First interactive
includes the normal three-second countdown; it is not a hidden build phase.
Cover timing uses the existing loading-screen component under this harness.
The uncatalogued preview does not yet have a catalog-driven menu loading title;
these are **not** measurements of that future shipping menu transition.

### Rendering, frames and final regression

Corrected-build fixed views: two balanced rounds, 600 frames per view (9,600 total), full phone
HUD/touch controls/telemetry still drawn. All sixteen cases pass average >=59,
frame p95 <=18.5 ms, p99 <=25 ms, <150 draws, <300k primitives. The table takes
the worse result of the two rounds, not a pooled average:

| View | Draws | Primitives | p95 ms | p99 ms | Maximum ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Opening | 136 | 141,632 | 17.355 | 17.711 | 19.302 |
| Tunnel exit | 142 | 187,310 | 17.480 | 18.493 | 20.205 |
| Jump | 129 | 210,574 | 17.402 | 17.875 | 18.893 |
| Landing | 132 | 212,158 | 17.385 | 17.812 | 18.312 |
| Descent | 96 | 172,640 | 17.380 | 17.869 | 18.610 |
| Cove | 126 | 160,786 | 17.412 | 17.737 | 18.456 |
| Bridge | 119 | 156,442 | 17.358 | 18.006 | 20.652 |
| Finish | 76 | 53,866 | 17.347 | 17.905 | 18.272 |

Average fps ranges 60.002–60.019; no >33.3 ms interval in these views. The
142-draw maximum leaves **eight draw calls**, not spare B2 headroom. Phone
tunnel-exit and finish screenshots were inspected: road remains readable in
the tunnel and the depth-tested rainbow is visible without far-plane clipping.
Static view results do not replace moving-camera/active-car measurements.

The live-drive recording includes the driver's explicit three-second restart
countdown, then its entire run to the real finish. Countdown and route are
not accelerated. The runtime driver's computation and the recorder overhead
are included in these frame distributions, not subtracted.

| Phone drive | Run time | Average fps | p95 ms | p99 ms | Maximum ms | Draws | Primitives |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Rally | 169.283 s | 60.002 | 17.666 | 18.310 | 29.287 | 145 | 238,502 |
| Tuned Rally | 162.317 s | 60.004 | 17.698 | 18.228 | 24.243 | 145 | 238,474 |
| 4x4 | 189.658 s | 60.008 | 17.695 | 18.238 | 20.573 | 145 | 238,954 |

All three cars crossed gates 1–7 and finish 8 upright, with zero resets and no
>33.3 ms interval. Empty-water script-region upper bound: Rally 0.547/0.613 ms
per frame p95/p99; Tuned 0.551/0.616 ms; 4x4 0.559/0.620 ms. The 31,817 live-drive
frame rows independently reproduce every JSON summary. Moving views reach
**145 draws**, leaving five, not the static views' eight.

The warmed five-minute opening-scene soak also passes: **18,000 frames,
60.002 fps, p95 17.339 ms, p99 17.828 ms, maximum 22.405 ms**, 136 draws /
141,636 primitives. There were **zero intervals over 33.3 ms across all 59,417
final phone frames** (views, live drives and soak). No tail was trimmed or
threshold raised. Final battery temperature was 37.7°C, 19%, USB charging.
This is a five-minute static-scene soak plus nine minutes of active all-car
driving, not a claim of an hour-long endurance or battery-life test.

All nine final phone builds reported zero water bodies and wave bindings.
The installed APK hash exactly matches the fresh build above. All final phone
process logs are free of `SCRIPT ERROR` / `ERROR:`. The one-shot flags were
consumed, and the before/after save SHA-256 is identical. Automation exits
before the owner's manual drive; no test runs alongside their playtest.

An additional normal-speed PC 4x4 whole-route drive on the same source also
finished without resets: 189.692 s, 60.002 fps, p95 17.209 ms, p99 17.476 ms,
maximum 18.822 ms, 141 draws / 236,898 primitives (1280×720, Radeon 890M,
Vulkan Mobile). This corroborates the functional check, not the phone budget.

Final source `b8b182e`: **843 passing, one inherited pending, 630,382 assertions
across 141 scripts, 707.095 s, exit 0, no `SCRIPT ERROR` or `ERROR:`**. Separate
unit run: 726 passing, 438,684 assertions, 62.630 s, exit 0, no script errors.
The pending test is the pre-existing Test Ground held-gas kicker (61° nose-down
tilt, 13.1°/s yaw); it was neither introduced nor relaxed for Coastal. All
protected geometry/car-balance fixtures and jump/bypass cases pass unchanged.

### Retained Android harness failure

The first APK (`caa3d8f`) emitted `TrailDriver not declared`: the reusable driver
lived in `tests/scenarios/`, excluded by the existing Android export filter.
Loads and views ran and produced diagnostics, but the actual
drive then failed at `CoastalRouteProbe.new()` and never started. **That artifact
is not accepted; its static results are not a clean phone gate.** The failed
launch/log and initial records are retained in the `phone/` evidence directory.
Its first-load total through ready was 3.665 s (cover 4.071 s); those slower
numbers remain evidence, not a clean acceptance pass. Initial APK SHA-256:
`eb6e726da0474159c6007bd1090cefb1a6ef8c001bdd76fc264449d8ff4cf6f9`.

Correction: relocate the existing `TrailDriver` and its stable UID to `debug/`,
with no control-logic change. This also fixes the earlier sand-preview probe's
same dependency. Keep test/GUT exclusions intact; do not ship the whole test
suite to mask the missing helper. The phone runner now checks the active
process's log for script/engine errors and stops rather than waiting for a
nonexistent drive. All modes are rerun from a fresh APK under `phone-r2/`.
One ADB-daemon disconnection interrupted the first corrected install before
any game case began; its log is retained separately under `phone-install-failed`.

## Remaining owner decisions / boundaries

1. Whole-track phone feel and actual owner run times. The staged jump, bridge,
   surface and presentation approvals do not substitute for this final drive.
2. Scoring/catalog admission is explicitly deferred to B2 by the owner. Future
   thresholds need actual water-inclusive runs. No placeholder/zero shipping
   thresholds, unlock changes or progression writes are introduced in B1.
3. Claude/owner B1 review and explicit merge authorization. B2 does not begin
   before B1 review and merge; no merge/push is performed here.

## Repeating the checks

Evidence: [the acceptance index](m6b1-jump-data/README.md),
`acceptance-2026-10-07.tar.gz` and `acceptance-source.sha256`. The archive SHA-256
is `5a91cf6813aa8ab7b5b1d9879cc5bd46bf8270d6010d20a076d211e1faf108b2`;
the source-manifest SHA-256 is
`c7484ecaf70923fb23b7594d26a567b0b688dfd4880daf0c731d9ced563c22e9`.
The original ignored run directory is
`runs/m6b1-acceptance-2026-10-07.ZTejbD/`. Numeric failed-run diagnostics and
logs are retained in the archive; initial redundant PNGs remain in that raw
directory. No private save backup is included in the evidence.

Do not start a second Godot while the owner is playing. PC headless tests are
functional evidence, not render/performance evidence. Use an isolated save:

```sh
XDG_DATA_HOME=/tmp/ridge-coastal-review-data \
XDG_CONFIG_HOME=/tmp/ridge-coastal-review-config ./run_tests.sh all

# Actual rendered PC check; omit --fixed-fps.
DISPLAY=:1 WAYLAND_DISPLAY=wayland-1 \
XDG_DATA_HOME=/tmp/ridge-coastal-review-data \
XDG_CONFIG_HOME=/tmp/ridge-coastal-review-config \
godot --path . --resolution 1280x720 res://debug/coastal_acceptance.tscn -- mode=drive
```

With Ridge closed on the phone, build before installing (install alone reuses
the existing APK):

```sh
tools/android.sh build
sha256sum build/ridge-debug.apk
adb shell pidof com.ridge.game  # if running, let the owner close it first
tools/android.sh install
printf '%s\n' '{"mode":"drive","tc":0.2}' | \
  adb shell run-as com.ridge.game tee files/coastal_acceptance
tools/android.sh run
# Wait for the app to exit. Check THIS process's log for script/engine errors.
adb exec-out run-as com.ridge.game tar cf - files/coastal_acceptance_results > /tmp/coastal-results.tar
```

Repeat separately with `loads`, `views` and `soak`, retaining each mode's
metadata and completion marker before the next one overwrites them. The
archived runner does this, checks a before/after save hash, refuses to interrupt
a running app and fails on a stale completion marker or script error. APK/source
hashes and raw per-frame CSVs belong with the evidence; a green harness exit
alone does not assert the numerical budgets.

Manual full-course PC preview (no scoring or finish-progress saves; deliberate
settings/car-selection changes still save normally):

```sh
godot --path . res://debug/coastal_playcheck.tscn -- start=course
```

On the phone use `{"start":"course"}` in the separate one-shot
`files/coastal_playcheck` flag, then launch normally. Its default without a
start option remains the jump checkpoint; historical short smoke modes have
not silently become full-course acceptance modes.
Phone preview limitation: the flag is one-shot, so returning through car select
reopens the preview's default jump start. Reapply the course flag for a new
full-course entry with another car. PC `start=course` remains in process launch
arguments. This debug-preview routing is not claimed as final catalog UX.
