# M6A: ford query fix, creek attribution and frame-budget review

Owner-approved priority: diagnose/fix the ford, establish/fix the creek rendering
debt, then revisit the water timing gate. Waves remain a separate brainstorming
task. Branch: `m6a-water-physics`, starting at `1527e9e`; no merge or push.
Feature commits: `b341177` (water-bed query refinement), `8976e00` (Muddy
Valley road-shadow policy and audit). Measurement tools, this report and raw
evidence follow in a separate commit. The owner's `project.godot` re-save and
untracked `tmux-session.sh` are excluded and untouched.

**Phone retested; acceptance remains open:** the owner initially disconnected
the phone for personal use, then reconnected it during the final desktop suite.
The fresh build is installed; device measurements appear separately below.
The ford query fix reduces phone controller p95 by 62.2%, and all three creek
views meet the drawing budgets. The strict water/setup gates still fail, and
whole-frame p95 did not improve in the ford A/B. Desktop results are not used
as a substitute for device acceptance.
The earlier failed phone measurements remain evidence for the pre-fix build.
Water forces, car files, surface values, accepted geometry and protected
fixtures are unchanged. The setup/load misses are not declared resolved.

## 1. Diagnose before optimizing

The world has 16 m body bins, but each body already has 2 m triangle bins.
The ford did not test all 9,014 registered bed triangles at every probe.
Nevertheless, its dense road bed filled the local bins with 146–198 triangles
plus four water-top triangles. At all 13 measured probe positions only **two**
bed triangles actually contained the point (four triangle bounding boxes did).
A prospective 0.5 m cell contained only 20–26 bed candidates.

Three normal-paced headless desktop rounds before editing production queries:

| Location | Triangle tests/query | Water controller p95/tick | Water summed per process-frame interval p95 |
| --- | ---: | ---: | ---: |
| Canyon ruts, 340 m | 39.308 | 0.554–0.569 ms | 0.929–1.024 ms |
| Ford, 1290 m | 177.538 | 1.585–1.597 ms | 2.714–2.756 ms |

Headless intervals are scheduling diagnostics, **not rendered FPS acceptance**.
Each location/round has 1,200 consecutive completed physics ticks after 120
warm-up ticks; 15,600 queries per case (exactly 13 per tick). Same 4x4, static
initial placement, normal 120 Hz physics / 60 FPS cap; no fixed-fps acceleration.
The real car is simulated, not frozen. It settles at these placements; this
timing fixture is not a high-speed traversal or a worst-case sweep.

### Fix

`WaterBody` subdivides only crowded bed cells (>32 candidates), and only beneath
possible top cells, into 0.5 m bins. Sparse pool/terrain cells keep the original
path. The fine bins preserve candidate order, highest-bed selection, original
triangle interpolation and boundary tolerance. There is no cached answer based
on the car being stationary, no coarser bed and no altered water force.

Same three-round test after the fix:

| Location | Triangle tests/query | Water controller p95/tick | Water summed per interval p95 |
| --- | ---: | ---: | ---: |
| Canyon ruts | 8.846 | 0.269–0.300 ms | 0.490–0.518 ms |
| Ford | 27.077 | 0.471–0.497 ms | 0.801–0.842 ms |

These headless measurements are the initial refinement build, before widening
its conservative edge padding to cover the full barycentric-tolerance corner
case. Final-code rendered measurements are reported separately; do not mix
the two modes or treat this table as a phone result.

Ford candidate work falls **84.7%**; median case p95 falls **70.0%**. Ford query
time summed over 1,200 ticks falls from about 1.30 s to 0.28–0.31 s. This is an
actual reduction in query work, not a change of pacing or a desktop-to-phone
projection. Absolute timings differ from the previous session, so comparisons
use this session's matched runs rather than mixing headline numbers.

Tradeoff: ford index construction rises from roughly 0.007 to 0.015 s on this
desktop; total Canyon water phase goes from about 0.05 to 0.06 s. The phone
water-phase retest below still misses the existing 0.10 s limit.

Parity tests compare refined and original-bin queries at 2,500 synthetic
positions (sub-cell seams, negative coordinates, uneven/overlapping beds,
vertical faces and finite-bottom rejection), plus 500 positions per actual
water body in shipped Rock Canyon and Muddy Valley. Validity, top/bed height,
current and shoreline weight must match exactly. The old interpolation remains
the independent path; no expected geometry or car-balance data was rewritten.
An additional long-triangle test covers barycentric tolerance extending beyond
a vertex into the next sub-cell. Fine-bin padding includes the full accepted
`u/v` region, not only the unexpanded triangle's bounding box.

## 2. Creek: inherited debt, not new water geometry

A detached worktree at pre-water master `a3dbee4` and the current branch ran the
same `tools/creek_render_audit.tscn` fixture. Camera matrices match exactly.
The rally car is frozen, effects processing and HUD disabled, same ground-ray
placement at +17 m lateral offset. Vulkan Mobile, AMD Radeon 880M, Godot 4.7.2.
The requested 2400×1080 window was constrained by the desktop to **1920×1050**
in both runs; these are matched desktop views, not a claimed phone A/B.

| Creek position | Pre-water primitives / calls | M6A before fix | Shadow experiment |
| --- | ---: | ---: | ---: |
| 780 m | 314,656 / 106 | 314,656 / 106 | 250,424 / 101 |
| 820 m | 287,380 / 104 | 287,380 / 104 | 239,276 / 100 |
| 860 m | 322,316 / 105 | 322,316 / 105 | 251,868 / 100 |

The two over-budget views exist **before water physics**, with exactly the same
counts. Diagnostic passes hiding terrain, scatter and road independently show
the road contributes 117k–141k submitted primitives including shadow passes.

Use the existing `TrailDef.shadowless_sections` option for Muddy Valley's
ground-supported road (0–1600 m, including the post-finish run-out). It no longer submits that road to shadow maps,
but still receives tree/car shadows. Road triangles, collision, material colours,
terrain detail/draw distance, vegetation and creek geometry remain unchanged.
This removes about 48k–70k primitives and 4–5 draw calls at these views. Side-by-
side captures were visually inspected; this is not a blanket switch disabling
all scene shadows. Other levels and the raised Canyon shelf are untouched.

Actual car/effect/HUD phone recaptures are recorded below. The old
319,036 / 294,232 / 325,960 phone maxima are not replaced by these static
desktop counts.

Development checks caught two issues, retained in the evidence rather than
hidden: the first full suite's only failure was a new assertion incorrectly
requiring a candidate-count reduction even for sparse creek samples (6,959
tests in both paths, with exact result parity). It now requires no increase,
and still requires a reduction in Canyon. The first live render run also caught
the authored shadow property appearing before `script` in the resource file,
so Godot ignored it. That run was stopped, the property reordered, and a new
real-level test asserts every generated Valley road mesh has casting disabled
while its collision bodies remain present. The diagnostic toggle alone was
not accepted as verification of the saved level.
That test also caught the last post-finish run-out chunk beyond the initial
1500 m range. Coverage now extends through 1600 m; the targeted real-level test
passes all 19 assertions. A fresh, override-free fixed-camera capture reproduces
the shadow-experiment counts exactly at all three views. The intermediate suite
with the uncovered run-out assertion was stopped and retained separately.

### Final-code rendered checks

Normal Vulkan Mobile rendering at actual **1600×720**, same 20:9 aspect ratio
as the phone but not its resolution or hardware. The coarse query A/B switch
uses the same final geometry/forces and simply disables refined-bin lookup;
it still builds the index, so this is not a setup-time comparison. Coarse batch:
three Canyon rounds; refined batch: three rounds of Creek then Canyon. Both use
the same placements, warm-up, 4x4 in Canyon and 1,200 measured ticks per case.

| Ford, three case p95s | Original query path | Final query path |
| --- | ---: | ---: |
| Controller ms/tick | 1.174 / 1.398 / 1.135 | 0.369 / 0.362 / 0.340 |
| Sum of water ms/process frame | 2.347 / 2.753 / 2.227 | 0.690 / 0.687 / 0.688 |
| Whole process-frame interval ms | 17.934 / 17.875 / 17.983 | 17.839 / 17.858 / 17.871 |

Both batches average approximately 60 FPS. Lower controller cost buys CPU
headroom, not a claimed FPS increase above the cap. Final ford query count is
about 27.084 triangles/probe after conservative tolerance padding. Ruts' final
controller p95 is 0.216–0.235 ms; creek cases are 0.263–0.380 ms. Whole-frame
maxima across all 15 final cases are ≤19.568 ms. These short fixtures do not
replace a phone session or sustained moving traversal.

Live creek peaks (car/HUD/effects present), identical across three rounds:
**254,796 / 121**, **246,120 / 120**, **255,504 / 117** primitives/draws at
780 / 820 / 860 m. The frozen run clock leaves the GO label visible, as in the
previous audit; telemetry is hidden. This validates the *authored* shadow fix,
not just the earlier diagnostic toggle. This live batch preceded the final
post-finish coverage extension; the subsequent fixed-camera capture verifies
the same creek counts after extending that range. Screenshots were inspected.
Cleanup after all six level instances returns to 9 nodes / 0 orphans / 152
resources. All 18,000 final ticks and frame CSV summaries independently validate;
no `SCRIPT ERROR` appears in the final rendered batch.

## 3. Gate review — proposal, not retroactive acceptance

The approved spec chose ≤0.50 ms p95/tick as an incremental CPU budget. It did
not derive it from a measured loss of 60 FPS. It is a conservative **6% of one
core** at 120 updates/sec, not a demonstrated playability boundary.

At 60 FPS / 120 Hz physics, 1.1 ms per tick is approximately **2.2 ms per frame**
(13.2% of 16.7 ms), not 1.1 ms. The previous ford's 4.27 ms is approximately
8.54 ms/frame (51.2%) before dry car work, Jolt, rendering or effects. Even if
average FPS is 60, that is a genuine headroom problem, especially before waves.
Conversely, a 0.51 ms tick is not automatically a noticeable failure.

Recommendation for owner/reviewer approval:

1. Keep 0.50 ms as an **optimization target/advisory**, not an automatic rejection
   of every otherwise smooth pool case. Continue reporting every case and maximum.
2. Judge acceptance primarily on sustained near-60 FPS, frame-time tails and
   sufficient total CPU/GPU headroom on the phone, with water's contribution
   **summed per actual frame** (including catch-up frames), not 2× a pooled p95.
3. Use **3 ms p95/frame** of measured water-controller work as an initial review
   trigger, not a proven new hard limit: ~18% of the 16.7 ms budget. It leaves
   roughly 13.7 ms for the rest but does not prove the rest fits. Any recurring
   hitch or worse total-frame tail still fails review even below that trigger.
4. Finalize the acceptance envelope only after matched phone runs with rendering,
   effects/audio and all three cars. Include moving crossings and a several-minute
   warm-device run; static averages alone cannot demonstrate smooth play.

The recorder now saves a separate raw `*_frames.csv`: process-frame ID, wall
interval, completed physics-update count and sum of measured water cost. It also
records world query counts, triangle counts and query elapsed time each tick.
The first partial frame and trailing ticks are omitted from interval statistics,
not invented or duplicated. The Python validator independently checks raw frame
and tick summaries. Callback intervals include pacing/preemption; neither they
nor water elapsed timing are a CPU/GPU profiler or display-presentation trace.

The approved spec's numeric gate has **not** been silently changed. Phone
acceptance, course setup misses and the inherited Canyon load miss remain open.

## Final desktop regression

`./run_tests.sh all`: **735 passing, 1 pre-existing pending**, 110 scripts,
356,324 assertions, 425.548 s, exit 0; **no SCRIPT ERROR**. Protected geometry,
build-detail and car-balance fixtures pass unchanged. The pending test remains
gas-on jump pitch, not a new water failure. The final complete log is archived.
`PYTHONDONTWRITEBYTECODE=1 python3 tools/test_check_water_measurements.py`:
**9/9 passing**, including rejection of empty batches and corrupted measurements.
All desktop test/capture saves used isolated temporary XDG directories.

## Evidence and remaining manual checks

`m6a-query-fix-data/` retains before/after raw CSV archives and logs, the untimed
per-probe layout, and the matched creek comparison. No failed timing cases are
dropped. The device follow-up below uses a fresh build/install, continuous logcat,
three-round view/course batches, separate pulled summaries and raw frame/tick
validation. Creek captures were inspected. Manual moving ford/deep-pool runs
and a warmed-device driving/frame-time review still remain; automated placement
fixtures do not establish worst-case driving performance.

Waves/displacement are not implemented here. Their scope/order is still a new
design discussion, not an excuse to mix them into these fixes or Coastal Highway.

## Device follow-up after reconnection

The completed-code suite passed before exporting. A fresh debug APK was built
and installed with data preserved. Build SHA-256:
`7e4cf5d572046c99b95d5f6684a4ea20faa5bc97833cf585d948bff31c9aa865`.
The existing missing-project-icon export message remains; export/signing/install
succeeded. Device: Xiaomi 13 (`41374bac`), 2400×1080, Adreno 740, Vulkan Mobile,
120 Hz physics / 60 FPS cap. No power/thermal settings were changed.

The phone was idle in its launcher before installation. Save SHA-256 before
and immediately after installation:
`878845146b3d11fe00678b6fcb86ae2983022b568e74c1a74e623e43a1a83b7c`.
Only hashes, not progress contents, are recorded. Logcat is streamed continuously
for each batch, and raw results pulled before the next batch replaces its summary.

### Matched phone ford A/B

Both batches use the same installed APK, 4x4, geometry, forces and instrumentation;
only the `index=coarse` diagnostic switch changes. Three Canyon rounds per batch,
1,200 ticks each at the ruts and ford. The coarse run reproduces yesterday's ford
cost, rather than relying on a desktop multiplier.

| Ford case p95 | Coarse 1 / 2 / 3 | Refined 1 / 2 / 3 |
| --- | ---: | ---: |
| Controller ms/tick | 4.213 / 4.253 / 4.224 | 1.563 / 1.600 / 1.595 |
| Sum of water ms/process frame | 8.363 / 8.414 / 8.351 | 3.061 / 3.124 / 3.123 |
| Whole process-frame interval ms | 19.590 / 20.010 / 19.578 | 20.867 / 21.100 / 21.089 |
| Maximum process-frame interval ms | 24.051 / 31.849 / 35.336 | 22.026 / 26.830 / 25.578 |

Median controller p95 improves **62.2%**, with triangle work falling from 177.538
to 27.084 tests/probe. Maximum controller tick falls from 6.260 to 2.257 ms;
maximum summed frame water cost from 18.736 to 3.849 ms. Both average near 60 FPS.
**Whole-frame p95 did not improve**; it increased in this sequential A/B, while
the largest observed intervals decreased. Do not label this a demonstrated
overall frame-pacing improvement or infer GPU headroom from the CPU savings.
The elapsed callback intervals are not a display presentation trace.

The original 0.50 ms target still fails. The proposed 3 ms/frame *review trigger*
is also slightly exceeded, not silently rounded down or raised after measuring.
These are substantially smaller costs than before, but the new gate still needs
owner/reviewer approval and the driving/frame-time context described above.

The first rut case after launch was faster in both batches; all cases are retained:
coarse 0.670 / 1.785 / 1.811 ms p95, refined 0.346 / 0.860 / 0.864 ms. No claim is
made about the cause of this launch-to-later variation. Battery temperature rose
25.7→27.0 °C in coarse and 27.3→28.0 °C in refined, Android thermal status stayed
0, and save checksums stayed identical. Cleanup returns to 9 nodes / 0 orphans /
153 resources each round. No SCRIPT ERROR or crash was logged.

Canyon repeat build times remain bad: coarse batch 5.32 / 6.44 / 7.91 s; refined
batch 5.00 / 7.30 / 8.86 s (see logs for exact phases). Both build the same fine
index, even when query lookup is disabled; this is **not** a pre/post setup A/B.
The water phase remains over 0.10 s. These fixtures do not resolve or reattribute
the inherited repeat-load debt, and no load-budget exception is silently granted.

### Phone creek drawing check

Three rounds, 10,800 measured ticks, all raw tick/frame summaries validated:

| View | Previous M6A phone primitives / calls | Fixed phone primitives / calls |
| --- | ---: | ---: |
| 780 m | 319,036 / 130 | **254,804 / 125** |
| 820 m | 294,232 / 128 | **246,128 / 124** |
| 860 m | 325,960 / 126 | **255,512 / 121** |

Fixed peaks repeat exactly in all three rounds. These are live car/HUD/effect
views at 2400×1080, unlike the earlier static desktop attribution fixture.
The pre-water/current *desktop* A/B establishes inheritance; the table above
compares two phone water builds, not a claimed phone pre-water A/B.
All fixed views meet the existing 300k/150 drawing budgets. Whole-frame p95 is
17.025–17.402 ms, maximum 26.183 ms; average FPS remains near 60. Water cost is
not declared under 0.50 ms (most creek cases still exceed it). Cleanup remains
9 nodes / 0 orphans / 153 resources, with no SCRIPT ERROR or crash.

### Phone all-car course check

Three rounds × three cars × four placements: **36 cases / 45,360 measured
ticks**, with every raw tick/frame summary independently validated. These are
real simulated cars placed at the shallow 5/30 cm and deep calm/current test
areas, with an initial 3 m/s velocity, not owner-driven crossings. All 18 deep
cases end flooded and stalled; all 18 shallow cases remain unflooded/unstalled.

| Car, 12 cases each | Controller p95/tick range | Summed water p95/frame range | Whole-frame p95 range | Maximum frame interval |
| --- | ---: | ---: | ---: | ---: |
| Off-road 4x4 | 0.288–1.345 ms | 0.567–2.605 ms | 17.053–17.922 ms | **79.459 ms** |
| Rally | 0.628–1.356 ms | 1.259–2.631 ms | 17.309–17.728 ms | 29.011 ms |
| Rally Tuned | 0.917–1.376 ms | 1.752–2.683 ms | 17.248–17.832 ms | 29.922 ms |

**34/36 cases still exceed 0.50 ms p95/tick**; the validator with the original
gate returns exit 2. Only the first two launch-time shallow cases meet it.
All case averages are approximately 60 FPS (59.635–60.150), but that is not
enough to claim smooth tails. Course drawing peaks are 27,695 primitives /
45 calls. Course construction remains 0.260–0.601 s, over the 0.25 s target in
every build; this was not a construction-time optimization.

The first-round 4x4 current case contains a cluster of long callback intervals,
not just a benign p95 overage. Its largest elapsed water tick is **39.524 ms**
(physics tick 4837; query portion 39.191 ms, normal 13 queries / 52 triangle
tests), within a **67.294 ms** process interval. A later **79.459 ms** interval
contains eight catch-up physics ticks and 4.181 ms of measured water work.
These are different intervals: the largest water tick did not directly account
for the largest frame interval. The case also contains 50.113 and 40.040 ms
intervals. Neither of its later-round repeats exceeds 19.486 ms; no later
course case exceeds 29.922 ms. The entire first case is retained in the data.
Normal triangle counts do not identify the stall's cause: these wall timers
can include scheduling/preemption, and no OS/thread trace was captured. Do not
attribute it to Android, the query algorithm or garbage collection without
further evidence. A warmed moving run with a system/CPU trace is an open
follow-up, not a passed hitch gate or a reason to discard this sample.

Battery temperature rose 29.1→31.2 °C during the roughly eight-minute batch;
Android thermal status remained 0. Every cleanup returns to 9 nodes / 0 orphans /
159 resources, with no SCRIPT ERROR or crash. Save hashes before/after every
phone batch match the original. After completion, the game was confirmed
closed and its one-shot benchmark flag consumed; normal launch is ready for
the owner's playtest. No further automated game runs were started after that
handoff.

## Review outcome

- Ford: the dense local query bottleneck is measured and substantially reduced,
  with exact query parity tests and unchanged car/force/geometry tuning.
- Creek: the primitive overage is inherited, and the fixed phone views pass
  the existing drawing limits with road collision/appearance retained.
- Timing: retain the original failures in the record. The proposed frame-based
  policy needs owner/reviewer approval; ford whole-frame p95 did not improve,
  and the course tail above needs context before claiming hitch-free play.
- Setup/load budgets remain missed. Neither waves nor Coastal Highway begins
  here, and Part A is **not** marked accepted, merged or pushed.
