# Rock Canyon — uneven shelf and surface joins

Work remains on `m5-rock-canyon`, not merged or pushed. The owner accepted the
previous road/collision and natural-cliff fix, then requested a slightly uneven
loose-rock section and seamless, better-grounded surface transitions elsewhere.
This is that follow-up, not permission to reduce the accepted difficulty.

Implementation commit: `666dd0d`.

## Changes

- `TrailDef.undulation_sections`: optional local rises and dips, authored only
  over **1512–1888 m** on Rock Canyon. The maximum added displacement is **14 cm**;
  two unequal wavelengths (17 m and 29.41 m) give irregular spacing, smoothly
  fading over 12 m at both ends. No extra ledges, jumps or changes after CP5.
  Curve, bank knots, road widths, holes, ruts and authored obstacles remain.
- Loose stones align to the local road slope. The same seeds, candidate counts,
  sizes, masses and friction remain; overlap placement on the new surface yields
  **4,749 stones** (previously 4,747). No car code or surface physics values changed.
  Road rendering, road collision, solid subgrade and stone placement use the
  same height profile. Cached subgrade rows avoid repeatedly sampling the same
  curve frame while preserving identical vertex arithmetic.
- `RoadBlendBuilder`: opt-in earth joins outside the existing shoulders, merging
  into the terrain over **2 m** with matching real collision and blended colour.
  The inner edge matches the road exactly; the outer seam is buried 3.5 cm below
  the terrain's rendered triangle, not its bilinear approximation. Mud joins
  retain mud collision rather than adding a dirt bypass. Joins fade away where
  the shelf narrows, and are absent throughout the narrow shelf and ford banks/
  crossing. They do not fill the river or widen the technical shelf.
- Terrain clearance now also protects the opted-in shoulders. The coarse ground
  had protruded through their detailed edges, leaving sawtooth intersections;
  lowering the supporting grid corners fixes the geometry, not just its colour.
  Existing road-interior damage and ford earthworks remain in place. Join colours
  and normals interpolate the actual terrain triangle's vertices, with the outer
  half matching the ground appearance. Both sides have upward-facing winding.
- `TrailDef.surface_color_blend`: two-sided colour fades, minimum **8 m** either
  side of changes. Adjacent stretches mix directly rather than flashing the
  base dirt colour between them. Surface IDs, physical boundaries and rut fades
  remain unchanged. Fine-gravel detail fades at 1500/1900 m; internal 40 m stone
  field boundaries have no texture seam. All appearance settings are opt-in:
  the other tracks retain their original geometry and palette.

## Verification

New checks cover local displacement limits and smoothness, unchanged height
outside the shelf, continuous colours with unchanged physical surfaces/ruts,
gravel endpoint fades, exact road-edge joins, buried outer seams, upward-facing
triangles on both sides, matching collision, mud shoulders, no shelf/ford joins,
and serial/threaded road agreement including UVs. Existing shelf tests still
check sleeping stones, safe hulls, density, banks and actual rendered-road contact.

Final `./run_tests.sh all`: **638 passed, 3 failed, 1 pending**, 93 scripts,
642 tests, 324.180 s, exit 1, **no `SCRIPT ERROR`**. All **564 unit tests** pass.
Log: `/tmp/ridge-polish-final-all.log`. The three failures are the existing two
dedicated shelf-driving tests and the full Rock Canyon driver; the pre-existing
jump-landing check remains pending. Assertions have not been weakened.

The dedicated shelf driver moves 875 stones before leaving the bank near
1670.85 m; peak awake is 196 against the provisional 150 bound, peak fragment
speed 24.55 m/s, and no below-terrain penetration is detected. Relaunch tests
still slide off near 1678–1679 m. The full-run driver falls after its shelf trace
passes 1620 m and resets to CP4 at 313.3 s. Earlier controlled checks still pass:
rock crawl 71.72 s, washed-out S-bend 33.14 s, ford with no airborne frames.

Actual visible shelf support: **2,030 probes**, worst gap **0.0001 m**, zero
terrain hits. The new join tests check real mesh triangles against collision,
both side windings, shoulder clearance and unchanged mud surface tagging.

Final desktop captures: 1280×720, Forward Mobile, Radeon 880M. **2.78 s** level
build (field 0.73 s, earth joins 0.49 s, shelf support 0.39 s). Eleven sampled
views at 208/292/548/698/878/1120/1265/1515/1575/1670/1892 m peak at **280,152
primitives** and **133 draw calls**, below the existing 300k/150 budgets. The
geometry caches preserve exact positions while recovering the extra build cost.
Captures are in ignored `build/level_shots/`; log
`/tmp/ridge-polish-final-shots.log`. These are desktop snapshots, not sustained
FPS or phone measurements. All test/capture Godot processes exited normally
(the test runner returns failure for the documented assertions).

## Resume

Stop for the owner's next PC check of the gentle shelf unevenness and polished
transitions. Preserve the accepted difficulty; do not change car/surface stats,
merge or push. The three previously documented scripted driving failures on the
steep shelf remain separate from the owner's successful playtest. Tests/captures
must not run while the owner is playing. Keep the owner's `project.godot` edits
and untracked `tmux-session.sh` untouched; use isolated temporary saves.
