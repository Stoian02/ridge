# Coastal B1: first-delivery jump checkpoint

2026-10-06. Branch `m6b-coastal-highway`, starting from `84cd2a6`;
delivered implementation source `203d2b7`.
This is **Tasks 0–3 only**, not completed Coastal B1. Owner jump-feel approval
and phone measurements are still pending. No tunnel, bridge or scenery work
may begin before that owner checkpoint.

## What is playable

A generated, dry **3,001.354 m** route, with 900 m of existing dirt standing in
for future firm sand. The generator reproduces the resource and passes its
unchanged separation check. Checkpoints are at 730, 980, 1330, 1600, 1970,
2240 and 2570 m. The opening/tunnel reservation and run-up are straight;
descent hairpins, cove bends, the reserved bridge straight, uphill S-bends and
headland finish are laid out but not accepted as a finished drive.

The mandatory jump is a genuine missing span: road, paint, shoulders and earth
joins are absent, the terrain is cut down, and exposed banks have matching
visible collision. There is no invisible deck or scripted launch. The dry cut
extends across the greybox's available land so grass is not a bypass. Its very
plain silhouette is temporary, not the final inlet/headland art.

The scene is deliberately uncatalogued: no invented star times or progression
entry. No Coastal water bodies, wave runtime, wet patches, sea plane, new grip
resources, shortcuts or car tuning were added. Existing `car/`, `surfaces/`,
geometry/build-details fixtures and car-balance fixture remain hash-identical.

## Drive it on PC

From the project directory:

```sh
godot --path . res://debug/coastal_playcheck.tscn
```

Or open that scene in Godot and press F6. It starts at the real 730 m approach
checkpoint. Use the usual driving controls; Pause provides car selection and
traction control, and Reset returns to a full run-up. Your confirmed usual TC
is **15–20%**. The unqualified command uses your normal selected car/settings;
explicit test overrides do not write to the save:

```sh
godot --path . res://debug/coastal_playcheck.tscn -- car=offroad_4x4 tc=0.20
godot --path . res://debug/coastal_playcheck.tscn -- start=course
```

An explicit `car=` pins that launch's car (including scene reloads); omit it
when testing Pause → Change car. Ordinary user-initiated settings changes in
the pause menu retain their normal persistence.

Please judge the jump's size, approach readability and especially landing
harshness in the Tuned Rally with the accelerator held. Brief chassis contacts
are **not hidden** by the tests. Letting go at the lip gives a flatter flight;
held throttle is tested separately and is not marked pending or assisted.

## Geometry iterations and discovered defects

| Parameter | Initial proposal | Current greybox |
| --- | ---: | ---: |
| Reset station | 730 m | 730 m |
| Ramp begins | 835 m | 815 m |
| Lip / height rise | 853 m / 2 m | unchanged |
| Lip angle | 14° | 10° |
| Landing begins / missing span | 869 m / 16 m | 867 m / 14 m |
| Landing below lip | 1.5 m | 1.0 m |
| Landing grade | −2% | −6% |
| Landing end / recovery end | 929 / 990 m | unchanged |
| Fully widened landing | 9 m at 869 m | 9 m at 867 m |

The longer ramp reduces curvature/compression; the gentler lip reduces time
available for held-throttle pitch. Moving the far bank 2 m closer adds margin
for the slowest car rather than increasing its power. The acceleration distance
from reset to lip remains 123 m, with 85 m before the ramp starts.

Retained unsuccessful work is part of the evidence:

- `gap-unit-1.log`: coarse ground supported the car above the late, lowered
  landing. Fixed by lowering all terrain grid corners under the solid gap
  profile, not just under the shoulders. Unit rays now agree with visible road.
- `gap-drive-1.log`: setup hung because the pre-existing post loop did not
  honour its documented zero-spacing disabled state. Stopped only our test PID;
  added an early return and extended the scatter regression test.
- `gap-drive-2.log`: the first driver's settling brake input requested reverse
  at rest. Those starts are invalid evidence of a stationary approach. Corrected
  to both pedals released, using existing auto-hold; subsequent starts are
  measured at rest. This run also exposed the initial ramp's harder landing.
- The 9° intermediate shapes and the 10°/16 m shape are retained in individual
  smoke logs and sampled trajectories. `rally-9deg` used a 0.5 m landing drop
  with the original 835 m ramp start; `4x4-9deg-long` moved the start to 815 m.
  Both retained the −2% landing grade and 16 m gap. The `*-10deg` runs used
  815 m / 10° / 1 m drop / −6%, still with the 16 m gap.
  The latter passed 48 crossing attempts (`gap-drive-3.log`),
  but the 4x4's first far-bank contact had less than 1 m margin. The final gap
  is 14 m; no car or traction coefficient changed to make it work.
- `gap-drive-4.log` is a failed parse (a missing explicit `WeakRef` type), not
  a passing empty GUT run.
- `gap-drive-5.log`: all 48 main crossings and off-centre/slow/reset/lifecycle
  checks passed, but an underside assertion used the road edge plus 3 m as the
  terrain-bank bound. The cut intentionally pads whole grid diagonals, so this
  bound was incorrect. The revised test derives the padded bank footprint and
  still requires the car to be physically blocked and unable to pass CP2.
  `ravine-check.log` records cars remaining at heights 14.2–15.1 m, well below
  the roadway, at stations 864.7–871.5; no bank traversal is accepted.

An initial new assertion required **zero chassis-contact ticks**. That was
stricter than the plan's no-roll/no-wedge/recoverable-landing requirement. The
current test explicitly records contacts, limits consecutive contact to 0.4 s,
requires recovery speed above 8 m/s and yaw below 20°/s, and still checks upright
recovery without resets. **This is not proof of a soft landing or owner approval
of a sharp strike.** The held-throttle Tuned Rally is the important feel check.

## Reproducible measurements

The driver uses normal virtual steering/throttle/brake only, with a 12 m pursuit
look-ahead and **no speed cap**. It calls the existing checkpoint Reset path,
settles for one second, then accelerates from rest. Lifted attempts release at
the lip until first wheel landing; held attempts keep full throttle. No injected
velocity, freeze, hidden torque or altered vehicle state is used for successful
crossings. Deliberate ravine tests are explicitly placed on the floor and are
not counted as successful jump attempts.

Matrix: Rally, Tuned Rally and 4x4, each at **0%, 15%, 20%, 100% TC**; three
reset attempts per car/TC for lifted throttle (36), plus one held-throttle case
per combination (12). All first wheel contacts must be at least 2 m past the
867 m landing edge. Metrics include actual start pose/speed, lip speed, wheel-unloaded
duration/distance, wheel-contact station, pitch/up vector, yaw, lateral drift,
chassis contact intervals, retained speed, resets and recovery to 990 m.

Metric precision: the log's `air_seconds`/`air_distance` run from all wheels
leaving the lip to the first wheel landing. **They are not exact body-unsupported
flight duration when the chassis touches first.** Such contacts are recorded
separately by `first_chassis_distance` and contact ticks. `landing` is the car
centre; `landing_contact_distance` is the actual first wheel contact station.
Worst tilt and yaw include landing/recovery, not just flight. The physics rays
independently establish absence of support throughout the real gap.

The final full-suite matrix produced **48/48 successful crossings**:

| Car (16 cases each) | Lip speed | Minimum wheel-contact margin past far edge | Worst tilt through recovery | Longest consecutive chassis contact | Lowest recovery speed |
| --- | --- | ---: | ---: | ---: | ---: |
| Rally | 97.0–97.3 km/h | 14.02 m | 29.0° | 0.175 s | 18.77 m/s |
| Tuned Rally | 108.6–108.7 km/h | 22.47 m | 40.5° | 0.233 s | 20.38 m/s |
| 4x4 | 76.2–76.8 km/h | 3.28 m | 18.0° | 0.058 s | 18.04 m/s |

Peak landing yaw stayed below 3.35°/s in that final matrix. Every case reached
990 m upright, with zero reset events. These numbers describe the controlled
driver strategy, not a guarantee for arbitrary approach speed or steering.

Normal-speed rendered smoke runs use:

```sh
godot --path . --resolution 1280x720 res://debug/coastal_playcheck.tscn -- \
  mode=smoke car=rally_tuned tc=0.20 held=true capture=/tmp/coastal-air.png
```

Do not use `--fixed-fps` when measuring rendering or judging real-time feel.
The automated suite intentionally uses accelerated headless physics for
correctness, not phone performance.

## Verification status

- Fresh unchanged baseline, in a detached `84cd2a6` worktree: **799 passing,
  one inherited pending**, 593.158 s, exit 0, no `SCRIPT ERROR`. The original
  interrupted baseline is retained separately and was not counted as a pass.
- Focused final unit checks: **17/17**, 276 assertions, no script errors.
- Final `./run_tests.sh all`: **813 passing, one inherited pending**, 131 scripts,
  814 tests, 605,477 assertions, 585.128 s; **exit 0, no `SCRIPT ERROR`**.
  The pending Test Ground kicker case measured 61° tilt / 13.1°/s yaw; it was
  neither changed nor used to excuse a Coastal failure. All five new Coastal
  scenarios passed, including the 48-case matrix above. Baseline/final suite
  durations are not a performance A/B: machine load and test workload differ.
- Normal-speed PC (Vulkan Forward Mobile, Radeon 890M, 1280×720): Rally at
  20% held throttle, Tuned Rally at 20% held throttle, and 4x4 at 100% lifted
  throttle all reached 990 m upright without resets. Final peaks were **130
  draws**, **211,494–211,902 primitives**, trail-build **0.722–0.729 s**.
  These are three short desktop smoke runs, not a phone or whole-route gate.
- No phone was connected when checked with `adb devices -l`. No APK was built
  or installed. **Phone build/render/frame-time gates remain unmeasured.**

## Budget issue caught in the greybox

The first rendered Tuned Rally run peaked at **183 draws / 202,250 primitives**
(`pc-tuned.log`), exceeding the 150-draw budget before scenery. Coastal-only
terrain chunks changed from 64 m to 128 m, preserving 2 m height sampling and
all road/collision data. The 4x4 normal-speed check then peaked at
**130 draws / 211,902 primitives**, with 0.729 s reported trail-build time on
this desktop. These are early desktop diagnostics, **not phone acceptance or
promised room for B2 water**. The matched Tuned Rally run (`pc-final-rally_tuned.log`)
confirmed **130 draws / 211,562 primitives**, with 0.723 s reported trail build.
It reproduced the initial run's held-throttle trajectory within millimetres.

The new zero-spacing fix and gap path are opt-in; old roads keep empty gap
arrays. Serial/threaded road and join geometry is compared directly. Rotated,
banked and chunk-boundary fixtures test real support and missing support.
The inherited kicker pending test is not used to waive the Coastal checks.
Uncatalogued-scene warnings are expected for this preview. Some short headless
smokes reported AudioStream/Playback objects at immediate engine shutdown;
`ravine-check.log` retains the verbose types. The full suite exits cleanly,
and the preview teardown test confirms its audio node is freed. No audio
implementation was changed or a new phone result claimed.

## Next gate

**Stop here for the owner to drive.** If the landing is too harsh, adjust the
jump geometry and rerun the matrix; do not change car tuning. Only explicit
owner feel approval unlocks Task 4 (tunnel and short stone bridge), then dry
surfaces and presentation. Full-route scoring, phone acceptance and final B1
review are later work. No merge, push or B2 work is authorized by this report.

## Review map and retained evidence

| Local commit | Review focus |
| --- | --- |
| `6a7f0ba` | Disabled roadside-post loop and regression |
| `ff673f4` | Generic opt-in gap, matching terrain/collision, physics/parity tests |
| `72b3e48` | Generated Coastal route, tuned gap data, dry placeholders and batching |
| `203d2b7` | All-car driver/matrix, manual preview, one-shot options and lifecycle checks |

The subsequent documentation commit contains this checkpoint report, updated
AGENTS/plan status and [the retained evidence package](m6b1-jump-data/README.md).
Source hashes make the tested files identifiable independently of the later
documentation commit. The owner's existing untracked files and `project.godot`
were not staged or modified. Nothing was merged or pushed.
