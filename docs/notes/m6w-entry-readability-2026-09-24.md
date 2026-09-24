# M6W — entry-wave readability correction (2026-09-24)

## Authority and stopping point

The owner approved another **Test Ground-only** iteration after finding ambient
waves sufficient but vehicle entry barely visible. Ambient strength/appearance
without vehicle disturbances stays unchanged. GTA IV remains an experiential
reference, not a claim of equivalent simulation or newly authorized reflections.

The owner also approved tracking the intermittent hitch as **unresolved but
non-blocking for this iteration**. Two traced delays were dominated by off-CPU
scheduling; that is not a universal explanation for older 46–79 ms tails. Keep
waves-Off diagnostics and revisit in phone testing before final acceptance,
sooner if reproducible/noticeable in ordinary driving. No gate is marked passed,
and no speculative stall/audio/physics patch was made.

Branch remains `m6-water-waves`; no merge/push or timed-level rollout. Stop for
renewed owner feel feedback after this correction. Phone connection/installation
and any measured results are recorded separately below, not inferred from PC.
Feature commit: **`78bb1b8`**. Runtime/tests were frozen before the final complete
regression; master stays `a3dbee4`, M6A stays `4d5bd21`.

## What changed and why

The original natural entry **was being emitted**, reaching about 5 cm in the
tested accelerating 4×4 approaches. The earliest crest was largely hidden under
the car, and exposed portions lacked visible contrast except at particular
lighting angles. Shore/depth limits were not the sole explanation, so they were
not weakened, and the amplitude was not simply increased.

- A natural entry now starts at a **hull-sized soft radius** rather than a point:
  `clamp(0.5 * body_width, 0.6, 1.5)` metres in the existing softened radial
  coordinate. It still expands at 2 m/s with the same onset, four-second life,
  coefficients and spatial safety cap. This spreads the physical response beside
  the car earlier; it does not simulate conserved displaced water volume.
- Radius is carried in the existing packed direction field. CPU and GPU use
  the same changed equation; ordinary wake packets are unchanged. Fixed packet
  capacity, cache/baked mesh, bed queries and car force/state code are unchanged.
- A pale crest highlight follows **actual drawn vehicle-wave displacement**,
  excluding ambient-only displacement. It changes colour/roughness only on the
  existing top; original transparency remains. No extra sheet, draw call,
  particle system or invisible force. Bow/wake crests benefit from the same
  readability treatment without changing their physical coefficients.
- `debug/water_wave_entry_check.tscn` provides event-aligned chase/side captures
  and an entry-only mesh measurement. `--slow` uses ordinary pedal inputs to
  maintain about 3 m/s. Default cases start at 3/8/14 m/s **then accelerate**;
  these labels are launch speeds, not held approach speeds.

No changes under `car/`, `surfaces/`, the course geometry builder, protected
fixtures, water forces/state/profiles, ambient profile or packaged geometry.

## PC evidence

Godot 4.7.2, Vulkan Forward Mobile, AMD Radeon 880M, 1280×720; isolated saves,
one Godot at a time. Rendered diagnostics run normal 120 Hz/60 FPS, not fixed-fps
acceleration. Captures pause the scene; packet ages are printed separately.

In matched original/final launch cases, entry occurs at approximately 8.54,
11.44 and 14.37 m/s respectively. At the first capture (packet age ~0.242 s):

| Launch speed | Original / new exposed crest peak | Original / new exposed vertices >15 mm |
| --- | --- | --- |
| 3 m/s, accelerating | 12.1 / 48.9 mm | 0 / 20 |
| 8 m/s, accelerating | 50.6 / 49.1 mm | 3 / 22 |
| 14 m/s, accelerating | 53.1 / 49.5 mm | 6 / 22 |

“Exposed” excludes the hull footprint plus a 30 cm margin; it is not a complete
camera-occlusion calculation. The improvement is primarily *where the wave is*
and its contrast, not greater peak height. Chase/side screenshots were inspected;
the expanding crest is now distinguishable around the car. Final feel is still
the owner's decision. Existing square spray particles remain unchanged.

The paced slow case crosses at **2.99 m/s**, generating an initial coefficient
of 0.0415 m; the exposed crest reaches **29.3 mm**, with 14 exposed vertices over
15 mm at the first capture. It is smaller than the faster entries, as intended.

The full-mesh diagnostic evaluation, printing and readbacks are intentionally
expensive. **Ignore FPS/frame timings visible in those screenshots**; they are
not gameplay/performance measurements. Use the separate normally paced smoke
check for timing, and the future complete phone gate for acceptance.

Focused tests: **20 passing**, 60,248 assertions, exit 0. All three cars at
60/120 Hz emit exactly one entry; 14–22 exposed vertices exceed 15 mm at a
quarter-second. New coverage checks signed-radius validation, early crest
placement, finite analytic derivatives, expiry and unchanged depth/shore bounds.
Ambient-only early flotation results are unchanged (max 3.64 cm / 1.61°).

Real-GPU shared evaluator verification: **576 points**, max **0.000000286 m**;
drawn-triangle verification: **21 triangles**, max **0.000000104 m**, versus the
1 mm requirement. Stress inputs now include entry radii 0/0.5/1/1.5 m. This is
numerical evaluator/attribute parity, not rasterized-depth or GPU-normal parity.

### Separate normal-speed smoke check

One real 4×4, 600 ticks / 299 frame intervals per mode, normal 120 Hz physics /
60 FPS cap. Different trajectories are not a matched-pose performance A/B.
All three cases / 1,800 ticks independently validated against the raw CSVs by
`tools/check_water_measurements.py`; no acceptance gate requested.

| Mode | FPS | Frame p95 / max ms | Controller p95/tick / frame ms | Peak draws / primitives |
| --- | ---: | ---: | ---: | ---: |
| Off | 59.998 | 17.584 / 20.488 | 0.435 / 0.747 | 69 / 21,923 |
| Car waves | 60.004 | 17.995 / 20.022 | 1.124 / 1.909 | 70 / 45,343 |
| Full | 60.025 | 17.692 / 18.847 | 1.091 / 1.828 | 70 / 45,343 |

Exactly 13 base-bed queries/tick in each mode. Preparation CPU 16.293 ms.
Drawing counts match the previous prototype, not a claim of unchanged GPU cost.
Controller costs exclude external wave generation/uploads, effects/audio and
engine work; they are **not total water cost**. Even Off timings are higher than
the earlier PC delivery, so cross-session percentile subtraction would not
isolate this correction. Do not extrapolate phone headroom or claim a gate pass
from these short PC checks.

### Final regression and Android handoff

`./run_tests.sh all`: **119 scripts, 775 passing tests, one pre-existing pending,
431,425 assertions, 467.908 s, exit 0**. No SCRIPT ERROR, failed assertion, GUT
error or warning in that final log. Protected car balance/geometry pass unchanged.
The existing kicker/held-gas landing scenario remains pending. This final run
completed on its first attempt; the earlier debug-runner error below is separate.

Fresh `tools/android.sh build` completed with exit 0; signed APK verified by the
exporter. The log contains the existing missing-project-icon error; successful
export is not a claim of a clean export log. APK: `build/ridge-debug.apk`, SHA256:
`87752071c8154c70f20a5ef1bdf50c5e5ca405d1ea6699ed3bd360001f36f107`.
No phone detected at the final check, so **no installation or phone test occurred**.
The old installed phone build is unchanged. Install this freshly exported APK
when connected; do not mistake `install` alone for rebuilding changed sources.

Full all-water CPU/GPU/thermal acceptance remains separate and pending. Owner
phone playtesting does not automatically satisfy that measurement gate.

On PC: Free Drive → Pause → Water waves → Car waves, then compare Full. Keep
Off available. Please judge early entry visibility, bow/wake readability and
whether the highlighted physical crests suit the stylized presentation. Stop
for owner feedback now; no more polish or automated play runs while they drive.

## Retained limitations/attempts

The first slow-entry diagnostic stopped on a typed-array initialization error
in the new **debug runner**. Only that owned instance was terminated (exit 143);
the corrected runner completed the slow-entry check. Preserve both logs.
Some focused/early rendered runs report ObjectDB instances at exit; no claim
of leak-free or sustained performance acceptance is made. XIM warnings are
also retained. No failed/interrupted run is counted as a pass.

Retained raw evidence and replay commands:
[`m6w-entry-readability-data/README.md`](m6w-entry-readability-data/README.md).
