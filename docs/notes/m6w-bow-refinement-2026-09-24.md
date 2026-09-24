# M6W — bow-wave-only refinement (2026-09-24)

## Scope

The owner likes the more visible entry and approved **step 1 only** of the next
proposal: water piling up ahead of the car and spreading around its sides,
responding to water-relative speed/direction including reverse. Work remains on
`m6-water-waves`, Test Ground only, with another PC feel stop before phone work.
Trailing-wake redesign and splash-particle polish (steps 2/3) are not included.
Feature commit: **`2ba1096`**, from turn baseline `cf5999a`.

Ambient, entry and wake source rules, coefficients/cadence, existing crest
colouring, water-depth/shore caps, course/baked geometry, car/surface tuning and
three-second stall delay remain unchanged. No new forces, reflections, fluid
solver, timed-level hookup, merge or push. The intermittent hitch remains
unresolved but non-blocking for this iteration; phone acceptance still needs
its full measurements and review.

## Change

Previously the attached bow was a narrow straight ridge; the 4×4 fixture had
three exposed mesh vertices over 4 mm, none at its sides. Now:

- The ridge curves backward toward the shoulders, with a broad smooth lateral
  envelope rather than fading steeply at the car's corners.
- Its width uses the car's **projected cross-flow span**, not always body width.
  Reverse leads from the rear; oblique/sideways motion presents a wider front.
- Its centre sits 25 cm beyond the projected leading hull extent. The original
  footprint validity and static depth/shore masks still apply.
- Same 5 cm input-coefficient cap, speed/immersion/deep fade and amplitude
  rise/fall timing. One attached bow; no extra packet, mesh, draw or bed query.
- CPU/GPU equations and derivatives match. Physical sampling still interpolates
  the actual displaced triangles; unchanged highlighting follows that surface.

The shape uses half-span `max(1.5, 0.5*cross_span + 1.0)` m and sweep
`clamp(0.75*longitudinal_reach, 0.6, 2.0)` m. In travel-aligned coordinates:
`v=lateral/half_span`, `u=(longitudinal+sweep*v*v)/1.5`,
`height=coefficient*pulse(u)*(1-v^4)^2` inside `abs(u),abs(v)<1`, then the original
combined depth/shore limiter. Sweep occupies the previously unused
`bow_direction.w`. This is an attached approximation, not water flowing around
arbitrary solid obstacles.

## Focused checks and comparison

`debug/water_wave_bow_check.tscn` places an **unfrozen real 4×4** on the original
pool ramp, seeds forward/reverse/oblique/slow velocity and wheel spin, then lets
ordinary physics run with no throttle. Numeric checks isolate the bow; captures
retain normal particles/wake. Placement is not a new natural-entry test, and
reversing is a backward coasting fixture, not a full reverse-gear acceleration run.

Godot 4.7.2, Vulkan Forward Mobile, AMD Radeon 880M, 1280×720, 120 Hz / 60 FPS.
Before/after use the same starting inputs; subsequent physical motion can differ.
At about one-third second after release:

| Case | Old / new exposed vertices >4 mm | Old / new exposed peak | Old / new side peak |
| --- | ---: | ---: | ---: |
| Forward (~6.7 m/s at capture) | 3 / 7 | 28.85 / 40.31 mm | 0 / 13.33 mm |
| Reverse (~6.7 m/s at capture) | 3 / 7 | 28.85 / 40.31 mm | 0 / 13.33 mm |
| Oblique (~6.2 m/s at capture) | 2 / 9 | 17.89 / 36.05 mm | 0.47 / 28.41 mm |
| Slow (~2.75 m/s at capture) | 1 / 3 | 6.20 / 7.82 mm | 0 / 2.79 mm |

Exposed means outside the hull footprint plus 20 cm, not a complete camera
visibility calculation. Side metric uses the car's nominal width for consistent
before/after reporting, not an oblique projected-footprint acceptance test.
Chase/front-side views were inspected. The crest extends to the shoulders while
remaining modest in slow motion; the owner's next drive decides final feel.
Diagnostic whole-mesh sampling and screenshot readbacks contaminate on-screen
timings; these images/logs are **not a performance benchmark**.

Focused correctness: **25 tests passing, 78,348 assertions, 26.752 s, exit 0**.
New checks cover curved support/shoulders, analytic normals against finite
differences, pending snapshot semantics, invalid sweep rejection, body isolation,
reset, and bit-identical entry/wake/ambient snapshots for prescribed observations
with different bow shapes. Live all-three-car cases at 60/120 Hz exercise forward,
reverse, oblique motion and actual steering through normal input. Existing entry
and early flotation checks pass; ambient-only flotation numbers are unchanged.

Real GPU: 576 mixed-field samples, max **0.000000285 m**; **384 dedicated bow
samples**, max **0.000000205 m**, covering opposite/oblique headings and narrow /
broad cross-flow spans. **21 drawn-triangle samples**, including 16 selected
around the active bow, max **0.000000179 m**. All below the 1 mm gate. This verifies
the shared height evaluator and actual mesh attributes, not rasterized depth or
GPU-normal readback. CPU analytic derivatives have separate finite-difference tests.

## Normally paced PC smoke

The existing playcheck ran sequential Off / Car waves / Full cases with
600 physics ticks and 299 rendered-frame intervals each. The 1,800 tick CSVs
and frame CSVs independently reproduce the printed summaries through
`tools/check_water_measurements.py` (exit 0, no gate requested). Screenshot
readbacks occur outside these timed windows.

| Mode | FPS | Frame p95 / max | Controller p95 per tick | Controller p95 per rendered frame | Draws / primitives peak |
| --- | ---: | ---: | ---: | ---: | ---: |
| Off | 60.01 | 17.540 / 22.819 ms | 0.441 ms | 0.752 ms | 69 / 21,923 |
| Car waves | 60.00 | 17.551 / 18.774 ms | 1.106 ms | 1.767 ms | 70 / 45,343 |
| Full | 60.00 | 17.590 / 18.729 ms | 1.101 ms | 1.791 ms | 70 / 45,343 |

Each mode made 7,800 bed queries / 62,176 triangle tests. Both enabled cases
emitted one entry and 14 wake packets. These are short desktop smoke checks,
not a sustained thermal test or the **all-water** CPU gate: the controller
measurements do not include every water subsystem. No percentile subtraction,
desktop-to-phone extrapolation or acceptance claim is made.

## Final regression and remaining acceptance

`./run_tests.sh all`: **780 passing, one inherited pending, 120 scripts,
449,525 assertions, 481.561 s, exit 0**. No SCRIPT ERROR, ERROR or WARNING lines.
Runtime and test code were frozen for this complete run. The pending case is
the existing held-throttle jump landing; protected geometry and balance checks
pass without changing their fixtures. Car/surface tuning and level files are
unchanged. Master and M6A refs remain untouched; no merge or push.

No Android export/install or phone test is part of this bow-only pass; the previously built
APK contains the earlier entry correction, not this change. Rebuild before a
future phone install. Full water CPU/GPU/thermal/hitch acceptance remains open.

The focused test process reports 18 ObjectDB instances on exit; XIM warnings
appear in graphical logs. These remain in evidence; no leak-free or phone
performance acceptance claim is made.

Raw evidence and rerun instructions:
[`m6w-bow-refinement-data/README.md`](m6w-bow-refinement-data/README.md).

## Owner playtest stop

Free Drive → Pause → **Water waves — PC prototype** → **Car waves** to isolate
the vehicle response, or **Full** to include the already accepted ambient waves.
Scene entry still defaults to **Off**. Try steady slow/medium driving in the
water, steering across it and reversing; look for a leading crest that bends
around the car's sides and follows its motion. Use Off as a comparison.

Stop here for the owner's feedback. Step 2 trailing-wake refinement, step 3
splash polish and phone work are not automatically authorized by this delivery.
Do not start another Godot instance while the owner is playing.
