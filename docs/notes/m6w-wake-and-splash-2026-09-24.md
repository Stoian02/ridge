# M6W: trailing wake and a splash that leans with the car (2026-09-24)

Written by Claude, continuing the Test Ground wave prototype on
`m6-water-waves` after the owner approved the refined bow. This covers the
owner's next two asks:

1. refine the trailing wake;
2. "make all done waves feel more connected, for example, the initial splash to
   be bigger towards the car's direction of movement".

Not merged, not pushed. No phone build was made: the owner will connect the
phone and test.

## What changed

**The wake spreads instead of queueing.** Wake packets alternate to either side
of the travel line, offset by `wake_side_fraction` (0.55) of the hull's half
width, so consecutive rings straddle the centre line and read as a widening V
rather than one file of rings behind the car. Cadence (0.30 s and 1 m),
amplitude, life and direction are unchanged.

**An entry now throws water forward.** The symmetric entry ring the owner
already approved is untouched. On top of it, entering water adds a short boost
to the bow crest — which sits ahead of the hull and wraps its sides — so the
splash leans the way the car is travelling. The boost is
`entry_kick_amplitude` (0.045 m) scaled by hull size, depth fade and entry
speed, fading linearly to nothing over `entry_kick_seconds` (0.45 s).

**The spray cone follows the car.** `WaterEffects` aimed its particles straight
up regardless of motion. The cone now tilts toward horizontal travel by up to
`MAXIMUM_LEAN` (0.6 of an upward unit vector, so the vertical component always
dominates and it never becomes a horizontal jet), scaled by speed.

No car code, car tuning, surface values, level geometry, ambient waves, depth
or shore limits, cadence or drawn/physical height coupling changed. The shared
wave maths — `water_wave_math.gd` and `water_wave_math.gdshaderinc` — is
untouched, so the verified CPU/GPU parity is unaffected; it was re-run anyway.

## Two corrections worth recording

**The bow ceiling had to move, deliberately.** `WaterWaveField.set_bow` clamped
its target to `profile.bow_amplitude`, which silently swallowed the entry boost
— the crest asymptoted to exactly the old cap. Rather than bypass a safety
bound, the ceiling is now `bow_amplitude + entry_kick_amplitude`, and
`WaterWaveProfile.is_valid()` additionally requires that sum to stay inside
`maximum_offset`. With the shipped values that is 0.05 + 0.045 = 0.095 m against
a 0.12 m field maximum, so the bound is still real and now covers the boost.

**An existing test caught a design mistake.** The wake's sideways offset was
first derived from `observation.bow_width`, which broke the guarantee in
`test_water_wave_bow.gd` that changing the bow's *shape* cannot move entry, wake
or ambient packets. It now uses `observation.size.x`, the hull's own width, and
that test passes unmodified. The trade is that the straddle ignores a sliding
car's longer across-track span; that isolation is worth more than the nuance.

## Verification

`./run_tests.sh all`: **783 passing, one inherited pending, no `SCRIPT ERROR`**.
GPU parity re-run after the changes, all far inside the 1 mm gate: 576 sampled
points at **0.000000285 m** maximum error, bow parity over 384 points at
**0.000000205 m**, drawn-triangle parity at **0.000000179 m**. The shared
equations did not change; the bow figures move only because the crest's ceiling
now admits the entry boost.

New tests:

- the entry leans the crest forward harder than cruising does, stays inside the
  ceiling, and fades back to the cruising crest;
- consecutive wake packets swap sides of the travel line and none sits on it;
- the spray cone leans further forward with speed while staying upward.

The bow-shape isolation, protected geometry fingerprints and car-balance
fixtures all pass unchanged.

## What this is not

Desktop only. No phone build, no frame-time or total-water measurement, and no
feel acceptance — the owner drives it next. The M6A flooded-and-stalled hitch
remains open and unrelated to these changes; the total water CPU ceilings
(4 ms/frame p95, 5 ms/frame p99) still have to be met on the phone before any
of this can be accepted. Waves remain Test Ground only and default to Off.
