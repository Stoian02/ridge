# Milestone 5 — Rock Canyon: build notes (2026-09-18)

Implemented and desktop-validated on `m5-rock-canyon`, based on master `cb20c09`.
Not merged or pushed. Ready for the owner's PC playtest; phone performance,
touch comfort and final star times remain acceptance work, not completed claims.

## What was built

- Tasks 1–5 were completed by Claude: width profile and existing-level geometry
  fingerprints; four surfaces and their feedback/sounds; canyon walls; rock
  steps; fixed boulder fields.
- Task 6 is completed in `13ae422`: sleeping loose stones, deterministic placement,
  convex rock collision, one MultiMesh per field, and awake-body visual updates.
- Task 7 is completed in `e83c7ee`: ford/waterfall, riverbed earthworks, mist,
  positional audio and road collision integration.
- Task 8 is completed in `4d5fca4`: saved Pedal/Lever control choice, absolute
  throttle with immediate release and exclusive finger capture.
- Task 9 is completed in `74ac7b7`: informational car recommendations and a
  two-by-two level-card grid once the catalog grows past three entries.
- Task 10 is completed in `c6b5f10`: the fourth catalog level, full route and
  obstacles, protected canyon-wall corridors and water-filled mud ruts.
- Task 11 is completed: six driving scenarios, obstacle/narrow-road driver
  caution, the approved fixed-rock fallback, full regression and measurements.
  The fallback is committed separately as `9087e11`.

## Corrections and deviations

Carry-forward rulings from the latest handover take precedence over older plan
examples:

- Rock-step faces are 60% vertical with a sloping lip. Their face jitter stays
  non-positive so the rock collider remains in front of the road's step quad.
- The second step's face spans +1.0…+3.5 m, leaving both centre-line wheels on
  the ramp. Partial-face edges follow the road's 0.5 m station grid.
- `BoulderBuilder.BURY = 0.0`: a 0.45 m radius boulder stands approximately
  0.21–0.32 m above the ground. The old plan's bury-height arithmetic is obsolete.
- Slabs reuse a stretched/tilted rock mesh to retain one MultiMesh per field.
- Checkpoint gates follow tapering widths but never exceed the existing 12 m.
- Talus rest height now uses the actual hull's lowest vertex plus a 5 mm gap,
  instead of the draft's fixed radius multiplier, which left stones floating.
- Task 6 uses a follow-up commit rather than rewriting the WIP ancestor and the
  handover commit that followed it.
- Ford terrain, water and waterfall share a floor height including previous
  rock steps and undulation. The plan's raw-curve calculation omitted those.
- Low off-road terrain is supported beneath the river, with banks and an
  upstream waterfall ledge; one additional rock mesh closes the waterfall's
  face and sides. Water has no collision and no buoyancy.
- Waterfall loops stop on rebuild as well as exit. The small streak texture is
  generated synchronously, with no background texture worker surviving teardown.
- A captured lever finger cannot activate another driving pad through horizontal
  drift. Changing control mode clears old touches; Pedal remains the default.
- The first shelf arc turns -30° rather than the plan's +30°. The planned route
  crossed itself twice; this changes direction without shifting obstacle distances,
  grades or segment lengths. Generated length is about 2,174 m and rise 84 m.
- Canyon walls protect every nearby road corridor and its grid-cell interpolation
  footprint. Before this correction, the shelf wall buried the ford and shelf
  road in dirt; a graded hairpin regression covers both raised walls and drops.
- The wet-rock stretch is 1,278–1,302 m, with 4 m rock transition bands outside
  the complete 1,282–1,298 m ford channel.
- Shelf washout 1 contains both rubble and real tilted slabs (40% authored slab
  fraction), rather than relying only on the road's rock surface colour.
- The squeeze uses a 0.1 m placement span, radii 1.1–1.2 m, and lateral offsets
  2.5–2.6 m. Its actual hulls have a 3.12 m gap and 1.87 m longitudinal overlap;
  the original 4 m scatter span did not guarantee a paired squeeze.
- Deep mud opts into shallow standing-water geometry via
  `SurfaceStretch.water_rut_depth = 0.09`. Seeded, separated pools sit inside
  the existing ruts, below both lips, with horizontal water levels and faded
  ends. Default zero leaves every earlier level unchanged; no water collision
  or physics change is added.
- The scenario driver treats authored road widths of 5 m or less as cautious
  zones, using its 4.5 m/s crawl target from 20 m before the section. Initially
  it accelerated to 19.4 m/s on the narrow shelf and braked too late for the
  washout, leaving the road. The normal driver behavior on the original three
  levels is unchanged; no car physics or road width was changed to fix this.
- The approved §8.3 talus fallback is active: 40 fixed rocks on the existing
  scree replace the level's dynamic-stone entry. See the acceptance decision
  below. The reusable `TalusDef`/`TalusBuilder` and their tests remain available.

### Task 6: sleeping-state investigation

The first fresh unit run completed (no freeze), with 462/463 passing: untouched
stones woke after building. The same failure reproduced when pause-menu tests
preceded talus tests; a standalone pause/resume regression also failed.

The cause was a queued enter-tree transform notification. Flush it with
`force_update_transform()` before the final `sleeping = true`. Remove deferred
sleep assignment: it could cancel an actual first-frame impulse. No frozen-body
mode, proximity activation, velocity heuristic, car change or engine setting was
needed. This matches Godot's [Node3D transform notification flow](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/node_3d.cpp)
and [Jolt transform wake-up handling](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/jolt_physics/objects/jolt_body_3d.cpp).

The earlier reported process freeze was not reproduced in these runs; do not
equate fixing the sleeping-state failure with proving a separate freeze resolved.

## Desktop measurements

Tests use isolated XDG data/config directories, keeping the player's save out of
the test environment. Only one Godot instance runs at a time.

- Task 6 unit suite: 467 passing, 28,253 assertions, 9.111 s; no `SCRIPT ERROR`.
  Log: `/tmp/ridge-m5-unit-talus.log`.
- After adding the final backend sleeping-state regression: 21/21 focused
  pause-menu/talus tests, 230 assertions. Log: `/tmp/ridge-m5-talus-final.log`.
- Task 7: 478/478 unit tests, 28,547 assertions, 9.361 s; no `SCRIPT ERROR`.
  Ford tests: 10/10. Logs: `/tmp/ridge-m5-ford-unit.log`,
  `/tmp/ridge-m5-ford-focused.log`.
- Task 8: 494/494 unit tests, 28,603 assertions, 9.475 s; no `SCRIPT ERROR`.
  Focused controls/menu tests: 41/41; immediate press/drag assertions were then
  tightened and the lever tests rerun successfully. Logs:
  `/tmp/ridge-m5-throttle-unit.log`, `/tmp/ridge-m5-throttle-final.log`.
- Task 9: 500/500 unit tests, 28,632 assertions, 9.498 s; no `SCRIPT ERROR`.
  Log: `/tmp/ridge-m5-recommended-unit.log`.
- Early Task 10 wall/level/fingerprint tests: 14/14, 340 assertions. Whole-road
  probes every 2 m at lateral offsets -1.2/0/+1.2 m remain above the terrain;
  closest clearance is 3.1 cm near 1,332 m. Initial build 0.68 s, including
  0.29 s field, 0.18 s road, 0.11 s terrain and 0.08 s scatter.
- Task 10: 517/517 unit tests, 33,895 assertions, 11.439 s; no `SCRIPT ERROR`.
  Log: `/tmp/ridge-m5-level-unit.log`. The final integrated unit build was 0.74 s,
  including 0.09 s for the visual rut-water phase.
- Desktop visual review confirmed the four-level grid, recommendation on car
  select, pause controls, visible mud pools, shelf geometry and the supported
  waterfall face. Screenshots are in `build/level_shots/` (ignored artifacts);
  `m5_waterfall_side.png`, `m5_mud_lever.png`, `m5_pause.png`,
  `m5_level_select.png` and `m5_car_select.png` cover the new UI/water features.
- Crawl-zone and final level-data checks: 13/13, 190 assertions, 1.401 s.
  Log: `/tmp/ridge-m5-fallback-unit.log`.
- Rock Canyon scenarios: 6/6, 42 assertions, 41.566 s; no `SCRIPT ERROR`.
  Log: `/tmp/ridge-m5-scenarios-fallback.log`. This run includes the engine's
  ObjectDB-at-exit warning (22 instances); it is not described as warning-free.
- Final `./run_tests.sh all`: **591 passing, 1 pre-existing pending**, 86 scripts,
  34,349 assertions, 195.78 s, exit status 0 and no `SCRIPT ERROR`.
  Log: `/tmp/ridge-m5-all.log`. The pending test is
  `test_holding_the_gas_flies_level_and_lands_straight`, reporting the existing
  held-gas kicker nose-down behavior; no car-physics change was attempted.

### Rock Canyon driving measurements

- Default-assist 4x4 completed the full course in **5:49.3**, without resets,
  average 21.6 km/h, minimum upright-axis Y 0.945–0.947 across the focused and
  combined-suite runs. This is the deliberately
  cautious scripted driver, not an owner star-time benchmark. It crosses the
  finish gate with the car's front at a centre-line distance of about 2,101 m.
- Rally Car beached in deep mud at 338.67 m (27.75 s, including the 8 s stall
  detector). Rally Car Tuned beached at 357.71 m (45.87 s). Their failure to
  complete is expected; the level recommends, but does not require, the 4x4.
- 0.4 m ledge: both runs approached at 2.893 m/s with traction control disabled
  only for the comparison. At 40% throttle the obstacle took 1.433 s and mean
  contact slip was 0.5191; at 100%, 1.075 s and 1.4930. Both cleared upright.
  The metric is averaged over actual contact samples in the same obstacle
  window, rather than biased by differing approach speeds or elapsed duration.
- Deep mud from rest at 320 m to 560 m: 23.61–23.62 s, minimum speed after the
  first three launch seconds 22.51–22.60 km/h. Deep-mud wheel contact verified.
- Ford: successful wet-rock crossing, zero airborne ticks (both total and
  longest interval checked).
- Fixed-talus fallback: successful crossing of 40 placed rocks, minimum upright
  Y 0.996, no resets or dynamic stones.

### Desktop rendering and repeat loads

Final capture pass (`/tmp/ridge-m5-final-captures.log`), 1280×720, Forward Mobile
on AMD Radeon 880M, after activating the fixed-rock fallback. Build 0.87 s.
Every sampled view is below the 300k primitive
and 150 draw-call budgets; the approach is close to the primitive limit. These
are representative views, not a worst-case phone performance guarantee.

| Road distance | Primitives | Draw calls |
| --- | ---: | ---: |
| 100 m | 296,098 | 119 |
| 420 m | 271,178 | 109 |
| 780 m | 268,992 | 94 |
| 950 m | 226,508 | 96 |
| 1,200 m | 167,186 | 95 |
| 1,290 m | 97,540 | 76 |
| 1,450 m | 117,920 | 91 |
| 1,606 m | 249,642 | 104 |
| 1,700 m | 166,250 | 100 |
| 1,840 m | 112,452 | 81 |
| 2,000 m | 101,868 | 72 |

Headless benchmark cycled all four levels three times in one process with
teardown between loads. Rock Canyon total load/instantiate/ready was
0.77 / 0.75 / 0.83 s after the fixed-rock fallback. All three remained below
one second; no large or monotonic repeat-load slowdown or script error appeared
in these three rounds. Log: `/tmp/ridge-m5-loads-final.log`. Phone timings remain
unmeasured. Rendered captures still emit an ObjectDB-at-exit warning; these
measurements do not claim that separate warning has been resolved.

## Talus acceptance decision: approved fixed-rock fallback

The loose field failed desktop acceptance before the phone check. The full run
initially passed it, but the isolated slow approach repeatedly stopped at
1,211.94 m, lateral +1.40 m. Two awake stones had moved under the chassis and
were almost motionless; the wheels supported only about 5,974 N of the 4x4's
21,070 N weight. The front wheels carried only 282.5 N each. This is a belly
wedge, not merely traction control or a missing wake-up.

A separate initial-hull diagnostic found zero overlapping stone pairs and
positive road clearances for the involved stones. Stones 15 and 31 moved about
0.79 m and 2.17 m into the eventual wedge. There was no initial placement error
to justify moving seeds or rejecting intersecting stones. Existing wheel casts
apply their calculated force to the car, not a reaction to the dynamic hit body;
changing that would be car physics and was not done.

This matches the spec's explicit fallback condition. Rock Canyon now omits its
`TalusDef` and adds a sixth fixed boulder field on the same 1,150–1,250 m scree
section, with 40 authored rocks of radius 0.18–0.32 m. The sixth driving scenario
explicitly tests that fallback, including no dynamic bodies, real rock collision,
successful passage and uprightness. It does not claim the removed loose field
passed. Failure logs: `/tmp/ridge-m5-scenarios-first.log` and
`/tmp/ridge-m5-scenarios-trace.log`.

## Phone acceptance checklist

- Rock Canyon load under 3 s, with repeat-load timings.
- 60 fps through the wash, fixed talus section and shelf; below 300k primitives and
  150 draw calls in representative views.
- Confirm the fixed-rock fallback feels right; do not re-enable loose stones
  without addressing the recorded chassis-wedge behavior.
- Throttle lever comfortable while steering; default pedal unchanged.
- Replace placeholder star targets (285/255 s) using the owner's real runs.

## Owner playtest and open items

- Start the game normally and choose Rock Canyon, the fourth level (unlocked
  after Frozen Pass), with Off-road 4x4. For a direct editor test, run
  `levels/rock_canyon/rock_canyon.tscn` and choose the 4x4 via Change car.
- Pause → Throttle switches between Pedal and Lever. Pedal remains the default;
  the lever controls throttle by vertical position and releases to zero.
- Phone acceptance and real star targets remain open. No APK was installed as
  part of this handover completion. Merge/push remain the owner's decision.
- `half_total_width()` is a coarse widest bound. Hedge/shortcut builders still
  use it as a local edge; no current level combines those features with width
  stretches, so the deferred limitation does not affect Rock Canyon.
- Water physics, a new rock-crawler car, car locking and reset changes are out
  of scope. Existing car/surface values stay unchanged.
