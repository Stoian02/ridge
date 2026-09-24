# M6W — Test Ground PC driving prototype (2026-09-24)

**Subsequent owner-approved entry correction:** see
`m6w-entry-readability-2026-09-24.md`. This report preserves the initial delivery
and first feedback; the newer note records the hitch deferral and follow-up work.

## Scope and playtest

The owner explicitly approved bringing the **Test Ground-only PC feel test**
forward before the outstanding hitch review and full phone performance gate.
This is that rough playable checkpoint, not final M6W/M6A acceptance. Work stays
on `m6-water-waves`; no merge/push, car/surface tuning, timed-level rollout,
reflections or Coastal Highway work.

Feature commits: `5c28b7a` (optional query binding), `9c8aa14` (natural sources),
`0b88f97` (Test Ground controls/lifecycle and PC checks). Runtime/tests were
frozen before both regression attempts; committing did not alter the tested
files. Master stays `a3dbee4`, M6A stays `4d5bd21`.

To drive it, after automated tests have stopped:

1. Start the game on PC and choose **Free Drive**, preferably with the 4×4 first.
2. Open **Pause → Water waves — PC prototype**, choose **Car waves** or **Full**,
   then Resume. Changing mode resets the car to its normal spawn. **Off** restores
   the original flat water. The mode is never saved; each new scene starts Off.
3. Turn around from spawn: the three water areas are behind the starting section.
   Drive up the **calm pool** entry ramp first; then try the current pool and
   shallow bays. No new water area or shortcut to it was added.
4. Compare slow/faster entry, turning/reversing, stopping and letting the wake
   settle. Compare Car waves against Full to separate car-generated waves from
   background waves. R/Reset clears wave history as well as the car's water state.
5. Try the rally cars too. Changing car reloads Free Drive with waves Off, so
   select the mode again. Deep water still floods/sinks the car; the **3-second
   continuous intake-submersion rule** is unchanged.

Please judge **entry/wake visibility, bobbing strength, control, and how clearly
the intake/stall behaviour reads**. Car-generated deformation is subtle in the
normal camera and the existing square spray particles can dominate it. The
prototype does not add foam/highlight polish to conceal that question. Your
driving feedback, not these screenshots, decides whether the strength/readability
is right. **Stop here for Task 5a; no Task 6 polish without owner feedback.**

## First owner feedback (2026-09-24)

- Ambient/normal waves are visible and sufficient; preserve their current
  strength unless the owner later requests otherwise.
- Entering a water body is barely visible, or not visible at all. The entry
  response has not passed the owner-readability checkpoint.
- The owner named **GTA IV** as a reference for the eventual physical behaviour
  of water, while accepting a more animated/stylized visual presentation.
  This records the owner's desired experience, not a verified comparison with
  that game's implementation or a promise of equivalent simulation.
- No separate approval of flotation strength, wake readability, or the complete
  Task 5a feel gate was given. The request is to note this and discuss direction,
  not to implement further changes now.

Recommended next discussion: make the car's interaction clearly readable from
the driving camera—entry pushing a travelling wave out, a bow ridge and wake
while moving, and disturbance settling afterwards—while retaining agreement
between visible height and flotation. Inspect entry timing, shore/depth fading
and visibility before assuming that a larger coefficient alone is the fix.
Supporting spray/foam must not substitute for the requested physical response.

The current bounded height-field approximation is not a volume-conserving
displacement solver and does not simulate water flowing around arbitrary
obstacles. Matching the reference's overall feel is an aspiration to validate
by playtesting, not an accepted capability. Reflections and other deferred
behaviours stay deferred; phone budgets and the separate physics-change approval
remain in force. No code, tuning, tests or game runs changed for this feedback.

## Implementation

- `WaterWorld` has explicit optional, translation-only wave bindings. Static
  body/top/bed indices remain intact. A valid query samples the current drawn
  triangle before overlap selection; invalid/dry points stay invalid. Rest
  height is a new diagnostic/source field; all existing physics/feedback uses
  the animated `surface_y`. Unbinding returns the exact original values.
- Natural sources read the **already completed body/wheel samples** from the
  existing 13-probe controller at priority +50. They issue no additional base-bed
  queries. Rest-level immersion prevents waves triggering copies of themselves.
  Runtime priority −50 commits next-tick inputs; lifecycle priority −60 clears
  reset/rebuild history before the car samples anything.
- One entry after a real dry re-arm/crossing, a smoothed direction-relative bow,
  and time-plus-distance wake cadence. Relative translation/current, hull size,
  shallow wheel weight and deep-source fading follow the written starting rules.
  No throttle/wheel-spin propulsion, new buoyancy force or rocking torque.
- The shared fixed field retains the 4-entry/12-wake cap and body isolation.
  Ordinary crests remain centimetre-scale; conservative depth/shore limits and
  the <12 cm overall offset cap are unchanged. Shader equations and baked
  topology have not been changed to obtain a pass.
- Test Ground-only controls opt in lazily, loading the validated cached meshes
  once, retaining them across mode changes and replacing—not stacking—the flat
  tops. A loading cover actually renders an all-top view before restoring the
  chase camera. Pause/back input is guarded during that asynchronous operation.
- Reset, pause/resume, registry rebuild, mode switches and exit clear history or
  bindings appropriately. A registry change disables waves instead of reusing
  stale geometry. Other pause menus receive no extra controls.

No changes under `car/` or `surfaces/`, to the water force/state/profile files,
the course geometry builder, or any protected geometry/balance fixture. Test
Ground Off loads no optional wave meshes or running emitter/field. The common
query path has only its new rest-height assignment and inactive-binding check.

## Correctness and live physics checks

New focused coverage:

- Exact unbind/Off query restoration, translated drawn-triangle agreement,
  finite footprints, snapshot refresh and stale-body/generation rejection.
- 60/120 Hz pure source cadence, underwater spawn/reset suppression, dry re-arm,
  bobbing chatter, reverse direction, decay at relative rest, deep fade and
  packet body isolation.
- Animated-height intake checks for every stock car profile at 60/120 Hz: no
  stall before three seconds, stall at three seconds, a real wave trough clearing
  the intake resets the timer while body flooding grace continues independently.
- All three real cars, at both physics rates, drive down the existing calm-pool
  ramp: **exactly one entry**, **12–14 wake packets emitted over five seconds**,
  no non-finite motion/cap overflow. Physical body-sample offsets peak at
  **3.96–5.37 cm** in these Car-waves runs.
- First two seconds from analytically derived calm-pool flotation equilibrium,
  with unmodified profiles/forces and no held-up or frozen car: Full produces
  **3.36–3.64 cm maximum vertical excursion**, **1.41–1.60° tilt**, versus near-zero
  flat-water excursion/tilt. Both rates/all cars stay below the proposed extra
  15 cm / 5° feel bounds, with <1 cm horizontal displacement, no flooding yet,
  and no emitted entry/wake from ambient bobbing alone.
- Lifecycle checks for all three cars: Off default, six bindings only when
  enabled, original tops restored, retained cache between modes, pause clock
  freeze, reset seeding, world rebuild fail-closed and zero remaining bindings
  on exit. Rendered UI check also injects Escape during covered preparation.

The first flotation test printed an erroneous ~1 m baseline excursion because
it compared a rig-local car position against a world-space target. That was a
**test measurement bug**, not car motion. Corrected to `global_position`, reran
the live scenarios, and retained both logs. The values above use the corrected
run only; no car tuning or tolerance was changed to make the test pass.

The first full-regression attempt stopped advancing after all three cars
finished the existing Frozen Pass drive. No assertion failure/SCRIPT ERROR had
been printed, but it was **not a completed pass**. After retaining thread states
and logs, only that owned Godot process was stopped with SIGTERM (exit 143).
Native stack inspection was unavailable (`gdb` is not installed); cause is
unknown, not attributed to waves/audio from the last printed test alone.
The full suite was restarted with unchanged runtime/tests and another isolated
save directory. **Final `./run_tests.sh all`: 119 scripts, 774 passing tests,
one pre-existing pending test, 380,851 assertions, 447.574 s, exit 0; no SCRIPT
ERROR, GUT error, failed assertion or warning in that final log.** Protected
geometry/car-balance fixtures pass unchanged. The pending kicker/gas landing
scenario remains as before. The interrupted first attempt is not counted.
Some focused/early rendered runs print Godot's `18 ObjectDB instances` exit
warning; logs retain it. The final rendered check did not. We do not assert
memory-leak-free acceptance from these short runs.

## Rendered PC smoke check — not the deferred acceptance gate

Final code: Godot **4.7.2**, Vulkan Forward Mobile, AMD Radeon 880M, **1280×720**,
normal **120 Hz physics / 60 FPS cap**, isolated desktop save/config. No concurrent
Godot. A real 4×4 drives the same ramp in each mode; motion can differ, so this is
a behaviour/pacing smoke check, not a matched-pose performance A/B.

Each mode records 600 completed ticks (~5 s); 299 complete frame intervals.
All raw cases were independently checked by `tools/check_water_measurements.py`:
**three cases / 1,800 ticks verified, no gate requested**. Each case makes exactly
7,800 base queries (13/tick), including when sources are active.

| Mode | FPS | Frame p95 / max | Controller p95/tick | Controller p95/frame | Peak draws / primitives |
| --- | ---: | ---: | ---: | ---: | ---: |
| Off | 60.002 | 17.096 / 17.451 ms | 0.246 ms | 0.460 ms | 69 / 21,923 |
| Car waves | 60.006 | 17.342 / 18.105 ms | 0.799 ms | 1.504 ms | 70 / 45,343 |
| Full | 60.009 | 17.378 / 18.181 ms | 0.779 ms | 1.462 ms | 70 / 45,343 |

Optional preparation CPU in this run: **11.114 ms**, separate from covered
render waits. These short single-car runs do not establish long-session thermal
behaviour, max-packet GPU cost, all-view drawing or total-water CPU acceptance.
Controller timings include nested wave queries but exclude external field,
emitter, material uploads, effects/audio and engine costs. Do not relabel them
as all-water totals, subtract their percentiles to claim incremental cost, or
project a phone pass from PC. The increased query cost remains important work
for the deferred phone gate.

Inspected chase, side, pause-menu, settling and underwater views. The top remains
translucent and the menu fits; Full's background motion is more readable than
the small car waves from some angles. No polished-readability or owner feel pass
is claimed. Screenshots happen outside timed windows; a separate untimed entry
replay captures the short-lived pulse before it fades.

Final real-GPU verifier: calibration maximum `0.00000001469538 m`; **576 height
checks, maximum error `0.000000286 m`**, and **21 drawn-triangle checks, maximum
error `0.000000104 m`**, against 1 mm. Same shared evaluator/attribute contract
as the earlier lab, not a readback of rasterized spatial depth/GPU normals.

## Remaining decisions

- **Resolve the owner's entry-visibility feedback and agree the next change**;
  ambient strength is sufficient, but the overall feel checkpoint remains open.
- Full all-water CPU/GPU/whole-frame phone gate, broader shallow/current/reverse
  driving matrix and sustained/repeated-load phone tests remain open. This pass
  adds no phone installation; the phone still has the prior diagnostic build.
- Historic hitch classification and M6A acceptance remain open. No old failures
  or inherited Rock Canyon debt have been reclassified as passes.
- No timed-level rollout, merge/push, wave reflections or Coastal Highway work.

Evidence and commands: [`m6w-pc-prototype-data/README.md`](m6w-pc-prototype-data/README.md).

All automated Godot runs have ended. First owner feedback is recorded above;
await agreement on the next change. No polish or additional automated tests
should start while the owner is playing.
