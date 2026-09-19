# Loose-rock Test Ground prototype (2026-09-19)

The owner accepted the dense-rock canyon pass and requested an outward-banked
shelf against the left hillside, with movable stones, from checkpoint 4 (1500 m)
to checkpoint 5 (1900 m). The easier road after checkpoint 5 is to stay mostly
unchanged.

**Current scope: Test Ground prototype only. Stop for owner PC playtest before
putting these rocks or the new banking into Rock Canyon.** The owner explicitly
approved the focused wheel-to-moving-body physics change. No car stats, existing
surface values, assist settings or race-level resources changed. Work remains on
`m5-rock-canyon`, not merged or pushed.
Implementation commits: `89c2732` (wheel interactions) and `52bea28` (prototype,
stone support, tests and capture tooling).

## Where to try it

- Main menu → Free Drive (Test Ground), preferably with the Off-road 4×4.
- Drive right past the clearance logs to **LOOSE ROCKS - PROTOTYPE**.
  Centre x = 210 m, entry z = 10 m, driving toward -Z.
- The strip is **90 m long, 4.5 m wide**. Flat stones first, then a banked patch
  with the left edge higher. Markers show flat, 12°, 5° and 14°.
- Entry/exit and angle changes are smooth. No cliff or close hill in this prototype.
- R / Reset returns the car to its usual spawn **and restores all stones**.
  Without resetting, stones stay wherever physics leaves them.
- Try crawling, stopping on stones, reversing, crossing the bank, and accelerating
  with different traction-control settings. Low cars are not promised 4×4 clearance.

## Implementation and tuning

`levels/test_ground/loose_rock_course.gd` defines four fields: **36 stones on the
flat patch (12–29 m), 84 on the bank (38–79 m), 120 total**. Small radii are
0.07–0.10 m; larger fragments are 0.11–0.125 m. The procedural shape varies around
that nominal radius. Tests bound the actual maximum span below 30 cm, including
when a stone tips upright. Masses are 1–4 / 4–10 kg. Height scale 0.65 is applied
to both the visible mesh and convex hull. These are small fragments, not movable
versions of the earlier large embedded boulders.

`RoughPatch.loose_rock_angle_deg()` defines flat to 32 m, 12° at 48–54 m, 5° at
64 m, 14° at 74 m, then flat at 84 m. The height function drives the mesh, floor
collision and stone placement. Raised strip sides use the existing closed geometry.

`TalusBuilder.build_patch()` reuses convex rigid bodies and one MultiMesh per
field. It checks the actual footprint against previously placed stones and every
hull vertex against the floor. Small fragments opt into swept collision (CCD),
without changing legacy talus defaults. Local-space instance transforms support translated
patches. Sleeping stones are skipped except for their final pose update on sleep.
Reset clears velocities, restores the original poses, flushes transform notifications
and sleeps stones; it does not defer sleep over a later push.

`car/wheel.gd` now records the contacted body, measures relative contact velocity
including both bodies' rotation and centre of mass, and applies equal/opposite
suspension and tyre forces at the hit. Dynamic inverse mass and inertia enter
the low-speed force limits, so a light stone is not treated as immovable ground.
The complete contact force is also limited to an 8 m/s per-tick change in the
support's velocity: both car/support forces, reported load and tyre-spin reaction
are scaled together. This bounds cast/suspension damping spikes on light bodies;
it is not a global velocity clamp. Static/frozen supports keep the old calculation.
No scripted kick, hidden chassis
lift, collision exception, chassis-shape change or car/surface retuning is used.

## What testing exposed

The first larger-fragment prototype used radii up to 0.30 m. Initial slow runs
passed, but a later run stalled at **16.81 m** for eight seconds, with about
**14.4 kN** supported by the wheels versus **21.1 kN** car weight. This was
consistent with the earlier chassis-support problem. Large fragments can tip
under the chassis; applying wheel reactions alone does not make that geometry safe.

The prototype therefore reduces stone size rather than hiding collision. A new
diameter check also caught the generator's shape variation exceeding nominal
diameters, so the final range is based on actual vertices. This reduces wedge
risk for the 4×4; it does not prove arbitrary piles/lines or lower cars cannot stick.

The full-suite stress run then caught excessive velocities on very light stones
(one finish-frame speed was 173 m/s). CCD prevented floor tunnelling but alone
left large one-tick velocity spikes. The dynamic-contact force bound addresses
those spikes without clamping velocity or applying unmatched reaction forces.
Tests now monitor peak stone speed and minimum ground height throughout a pass,
not only final positions. Final focused runs measured a maximum 10.78 m/s across
the scenarios, with no stone crossing below the ground.

The general scripted driver drifted too far down the narrow bank. A test-only
driver uses nearer look-ahead, lateral-velocity correction and an uphill heading
allowance. It changes steering inputs only, not player physics. Slow tests must
stay within 1.25 m of the centre, so bypassing the strip cannot count as passing.

## Validation

Final `./run_tests.sh all`: **629 passed, 1 existing pending** (gas-held rally
kicker), 90 scripts, 56,367 assertions, **244.302 s**, exit 0, no `SCRIPT ERROR`.
Log: `/tmp/ridge-loose-rocks-validated-all.log`. All five new driving scenarios
pass in the full suite as well as the focused run. Rock Canyon's 4×4 completes
in **5:48.9**, no automatic resets, minimum upright 0.945. Existing level geometry
fingerprints remain unchanged; master remains at `cb20c09`.
The full-suite prototype runs recorded a highest stone speed of **12.01 m/s**,
no ground penetration, and at most **15 awake stones**. These are observed
test results, not guarantees for arbitrary collisions or future larger rock fields.
Tests use isolated `/tmp/ridge-m5-data` and `/tmp/ridge-m5-config`, one Godot
process at a time. Owner `project.godot` and untracked `tmux-session.sh` are untouched.

Focused final tests: **29/29 passed**, 15,691 assertions, 27.159 s, no script error.
Log: `/tmp/ridge-loose-rocks-bounded.log`. Three slow lines clear without resets
or eight-second stalls; maximum lateral offset 0.87 m, minimum upright 0.937.
Checks also cover full throttle with TC disabled, stopping/reversing/relaunching,
pulling away on the bank, and a second pass over already disturbed stones.
Peak awake bodies: 5–7 while crawling, 14 in the full-throttle pass.

Visual checks used 1280×720 Forward Mobile on AMD Radeon 880M. The entry title
was moved beside the lane after its first capture obscured the chase camera.
Final captures are in ignored `build/level_shots/test_ground_offroad_4x4_along_*.png`.

| Along lane | Primitives | Draw calls |
| --- | ---: | ---: |
| 0 m | 209,600 | 78 |
| 15 m | 211,164 | 85 |
| 42 m | 144,332 | 73 |

All sampled views remain within the existing 300k / 150 budgets; no triangle
budget increase. These captures are not sustained-FPS or phone measurements.
The usual X11 input-method warning appears; the bank capture also has the known
ObjectDB-at-exit warning. No claim that unrelated engine-exit warnings were fixed.

`tools/level_shots.gd` accepts `along=<metres>` for Test Ground as well as lane-X
spots; lane 210 with `along=42` captures the prototype's bank approach.

## Next step

Wait for owner feedback on visibility, movement, sideways slip and wedging.
Do not enable dynamic talus on Rock Canyon yet. After prototype acceptance,
build the close left hillside and varying outward bank on CP4–CP5 only; retain
the accepted earlier sections and easier CP5-to-finish drive.
