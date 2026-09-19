# CP4–CP5 loose-rock shelf — owner playtest handoff

**Follow-up:** the owner has passed this shelf by driving carefully and accepted
its difficulty. See `shelf-surface-fix-2026-09-19.md` for the subsequent visible
road/collision and natural-cliff fixes. This document retains the original
implementation measurements and scripted failures as historical evidence;
the old pending-owner-playtest gate below is superseded.

Work stays on `m5-rock-canyon`. Not merged or pushed. Earlier canyon/crawl/tree/
waterfall work and the centre-line curve are unchanged. `project.godot` and
untracked `tmux-session.sh` belong to the owner and are untouched.
Implementation commits: `89e4709` (fragment interaction/updates), `ab05b50`
(steep shelf and provisional driving checks).

## Owner direction — do not reduce the difficulty

The owner tested the loose-rock Test Ground prototype, found movement hard to
see, and approved integration with many more stones covering the entire shelf.
They supplied a recorded attempt for analysis. During tuning, a provisional
5–10° shelf was tried because the scripted driver slid off steeper banks.
The owner explicitly rejected that easing: **keep it unforgiving**, then stop
for their PC test. The final resource restores **12°, 14°, and 13° peaks**.
Do not change the level to accommodate the automated driver without new feedback.

**This is a playtest work-in-progress, not a fully passing release.** Remaining
driving-test failures are recorded below, not hidden by weakening assertions.

## Recording reviewed

Owner file, read only:
`~/.local/share/godot/app_userdata/Ridge/runs/run_2026-09-19T12-42-31_offroad_4x4.csv`.
The 4×4 recording contains 3,908 physics samples / **32.567 s**, moving back and
forth on the Test Ground flat patch. Along-lane range **11.45–33.18 m**, lateral
offset **−3.51 to +1.32 m**. It only touches the bank's smooth entry (32 m), never
the banked stone field starting at 38 m. Maximum forward speed **19.89 km/h**, reverse
**11.65 km/h**, no airborne samples. At least one tyre is on rock in **865 frames
(22.13%)**; 985 of 15,632 wheel samples are rock (6.30%). Thus the owner did hit
stones, but the CSV has no stone transforms or IDs and cannot establish how far
any individual stone moved. It is telemetry, not a video recording.

## What changed

- `rock_canyon_trail.tres`: CP4 **1500 m** to CP5 **1900 m**, still 4.5 m wide
  with no shoulders after the existing entry taper. Ten contiguous 40 m fields,
  480 candidates each, **4,747 placed movable stones** after gate/overlap checks.
  Every tested 10 m × lateral-third bin contains at least 27 stones. Gate centres
  retain 1.5 m clearance. The existing shelf slabs and boulder squeeze remain.
- `TrailDef.bank_profile` / `RoadSampler.up`: gravity-relative outward bank with
  smooth knots. Peaks 12° at 1580, 14° at 1685, 13° at 1790; relief to 5–7° in
  between. The curve's transported up vector already carries inward roll, so
  merely adding angles is incorrect. Entry/exit blend to the original road over
  25/20 m inside the shelf. Outside 1500–1900, sampler positions/up are unchanged.
- `ShelfBuilder`: rock cut directly against the left edge (20 cm toe setback),
  ~10 m face merging into the existing hillside 24 m back. Closed faces/caps/base,
  matching rock collision, 40 m render chunks. No global terrain-wall clearance
  rules were weakened. The ground-level fine-gravel shader fills gaps between
  real fragments; that fine texture is not thousands of additional rigid bodies.
- Loose fragments have radii **0.075–0.125 m**, height scale **0.45**, masses
  **6–16 kg**, convex hulls matching their visuals, CCD, contact friction **0.20**.
  Safe span checks stay below 30 cm even when tipped. No car code, car stats,
  existing surface values or grip-table entries changed. The shelf's ground uses
  the existing scree surface except for the retained rock slab stretch.
- `TalusBuilder`: non-overlapping dense placement via metre-sized spatial bins;
  excludes conservative existing-boulder footprints; bank-aligned stone poses.
  Awake/sleep signals maintain an active set, rather than polling all 4,747 bodies
  at 120 Hz. Visuals update when awake and once on sleep. Restart resets original
  stone poses after moving the car back to the start; ordinary driving preserves
  displaced stones. Chunked MultiMeshes still have 160 m visibility.
- Test Ground remains available at x=210. Its 120-stone layout stays unchanged;
  fragments are flatter (0.45), mass ranges doubled to 2–8 / 8–20 kg, and use the
  same 0.20 hull friction. This improved movement and resolved the reproduced
  reverse-out failure without editing wheel/car physics. Focused prototype
  scenarios passed all five in `/tmp/ridge-shelf-focused4.log`.

## Ground collision fix

Thin road triangles and the heightmap could lose small stones pushed under tyre
loads. One escaped stone reached y=−4389 m and 97.6 m/s falling under the map;
this was not intended loose-rock difficulty. The shelf now has buried solid
subgrade beneath its road and extruded terrain triangles nearby. Top faces stay
2 cm beneath the existing surfaces. These do not raise the road, lift the car,
or add an invisible retaining wall. Off-road terrain triangles use the same
diagonal as TerrainBuilder. Ground collision is grouped into bounded compounds.
Build each compound off-tree, then add it once: adding thousands of children to
an already-live body repeatedly rebuilt its physics shape and cost ~2.8 seconds.
Final shelf build phase is ~0.08 s.

## Validation and known failures

Final `./run_tests.sh unit`: **558/558 passed**, 75 scripts, 79,844 assertions,
19.745 s, exit 0, no `SCRIPT ERROR`. Log: `/tmp/ridge-shelf-final-unit.log`.

All four focused shelf geometry checks pass: absolute outward banking, unchanged
earlier/finish geometry, full-width/full-length density, safe hull spans/rest
placement, road/cliff collision, and sleeping-on-build behaviour.

Latest steep-shelf driving diagnostics before the final compound-grouping
optimization: `/tmp/ridge-shelf-subsoil.log`. Ground penetration is **false**,
peak stone speed **25.17 m/s**. The driver moves **922 stones** over 10 cm, but
slides off around **1670.7 m**; peak awake stones **288** exceeds the provisional
150-body acceptance bound. Starting at rest at ~1678 m also slides off. Both new
driving tests remain failing. The ordinary full-run driver may fail here too;
the full suite has NOT been rerun or claimed green. Tests retain their assertions.
The test-only driver uses a nearer/uphill target and slower input on steep banks;
these are not player assists. Owner judgement comes before further difficulty
tuning. A release still needs the full suite passing (no SCRIPT ERROR), a suitable
successful full-run driving line, and phone performance/awake-body checks.

Desktop visual captures: 1280×720, Forward Mobile, AMD Radeon 880M. Final corrected
gravel palette screenshot: `build/level_shots/rock_canyon_offroad_4x4_1670.png`.
Build **1.52 s**, **157,268 primitives / 110 draw calls** at 1670 m. Earlier same
geometry views: 1515 m **235,802 / 127**, 1575 m **252,444 / 115**, 1850 m
**137,152 / 89**. Within the existing 300k/150 budgets; no budget increase. These
are captures, not sustained-FPS or phone results. The known X11 input-method
warning remains. No phone installation in this turn.

## Resume

Stop here for the owner's PC run. In particular ask about the 14° bank, choosing
an uphill line, ability to recover after stopping, and visible stone movement.
Do not soften it pre-emptively. Keep CP5 to finish as it is. Before any later
test/capture, check host Godot processes: sandbox `ps`/`kill` can see a different
PID namespace. Never start a second Godot or kill the owner's game. All tests and
captures use isolated `/tmp/ridge-m5-data` / `/tmp/ridge-m5-config` saves.
