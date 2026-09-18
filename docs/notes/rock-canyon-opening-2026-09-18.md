# Rock Canyon — technical opening pass (2026-09-18)

Owner requested a Grand Canyon/valley-like opening, gradually deteriorating
asphalt with mixed-size/depth potholes, then very uneven dirt leading into mud.
The follow-up extended this pass through a twisting, progressively steeper muddy
climb with overlapping wheel paths, ending in a clearing. Stop here for playtest.
Implemented on `m5-rock-canyon`; not merged or pushed. Awaiting PC playtest.
Implementation commit: `e47ff10`.
This supplements the full [M5 completion notes](m5-rock-canyon-notes.md).

## Scope and tuning

- The start is enclosed by red sandstone walls on both sides, approximately
  58–83 m above the road at their full height. Broad, independent recesses,
  three rock ledges and subtle sediment bands break up the walls. They taper
  into the existing mud gully by 360 m. No added meshes or draw calls for bands.
- First 30 m remain clear for the starting gate. From 30–220 m asphalt damage
  gets denser, larger and deeper: authored density 8→62 holes/100 m, radius
  0.45–1.5 m, depth 0.035–0.32 m, with a gradually increasing upper size limit.
  Small holes remain mixed among the large ones. Full-width bumps grow from
  3.5 cm to 20 cm toward the dirt.
- Dirt at 220–300 m has density 80→100 holes/100 m, radius 0.5–1.65 m and
  depth 0.09–0.42 m, plus irregularly spaced 22–34 cm raised bumps. Hole centres
  cannot stack into accidental deep pits. The last 9 m ease hole depths into mud.
- Asphalt colour fades into dirt over 10 m; the existing 12 m mud colour/surface
  transition is retained. Hole depressions are darkened by the existing shading.
- Mud at 300–560 m now climbs through four opposing arcs, with radii 48/36/32/42 m
  and turns -65/+90/-80/+50 degrees. Grades build from 2.5% through 4%, 5.5%,
  7.5%, 8.5%, and 10%, then ease to 5.5% over the brow. The climb gains about
  15.6 m before the clearing. Regenerate with `tools/generate_rock_canyon_curve.gd`.
- Three pairs of mud wheel tracks share the road: the original centre pair and
  two weaving lines. They cross and overlap without adding their depths together.
  Ruts are now 18 cm deep. There are additional shallow holes (4–17 cm authored
  range) and 10–20 cm raised bumps. Existing pools remain shallow and level, so
  the steeper ground naturally holds shorter patches of water.
- At 560–650 m the climb eases to 0.5%, the road widens to 12 m with 4 m shoulders,
  and the canyon walls end: a broad dirt clearing with room to catch your breath.
  Width eases back by 660 m and the existing rock wash begins at 700 m.
- Later obstacle definitions and route segments are preserved. Regenerating the
  curve carries the rest of the route forward from the new, higher exit; total
  length stays about 2,174 m and overall rise changes from 84 m to 96 m. No car
  code or values in `surfaces/*.tres` changed.

Tuning lives in `levels/rock_canyon/rock_canyon_trail.tres`:
`BrokenAsphalt`, `RoughDirt`, `ChurnedMud`, and the `rollers` array. Radii are **radii**, not
diameters. `initial_severity` controls the starting upper size/depth limit;
`density` controls the beginning/end hole frequency. Each section has its own
seed, so editing the opening never shuffles the old wash's potholes. Canyon
heights and ledge coverage live in `rock_canyon_terrain.tres`. The mud stretch's
`extra_rut_paths` vectors are (lateral offset, weave amplitude, wavelength, phase
in radians), each describing one pair of wheel tracks.

## Implementation safeguards

- Optional `RoadDamageDef` resources feed the existing road mesh/collision
  builders. Both serial and threaded builders use the same generated holes.
- Local earthworks lower all grid corners underneath each new depression,
  including the full interpolation footprint and overlapping depths. This
  prevents terrain collision from filling the holes invisibly.
- Fine road rows cover individual holes and bumps, not undamaged gaps.
- Only fully covered road chunks within 0–560 m stop casting shadows. They
  still receive shadows and retain identical collision. All later chunks and
  other tracks retain their original shadow setting.
- Moving rut positions are snapshotted per row before worker tasks start. The
  original two-rut calculation remains unchanged when extra paths are absent.
- Rock Canyon's terrain clearance is 35 cm (previously 30 cm) to maintain the
  road-floor safety margin after the new bends/elevation. Road meshes now stop
  drawing at 400 m, matching the terrain/fog horizon; collision is never culled.
  Terrain LOD stays at 140 m. Other tracks retain unlimited road visibility.
- Terrace shaping and colour bands are opt-in by section, with no effect on
  levels that omit them. The existing protection for every nearby road corridor
  remains active. The extended outer footprint closes the recessed walls.
- Owner changes to `project.godot` and untracked `tmux-session.sh` were untouched.

## Desktop validation

Final full suite:

```sh
XDG_DATA_HOME=/tmp/ridge-m5-data XDG_CONFIG_HOME=/tmp/ridge-m5-config ./run_tests.sh all
```

**601 passed, 1 existing pending** (gas-held rally kicker), 87 scripts, 38,934
assertions, 199.955 s, exit 0, no `SCRIPT ERROR`. Log:
`/tmp/ridge-opening-final-all.log`. The 4×4 finishes in **6:04.6**, without resets,
lowest upright component 0.938. From rest at 320 m it climbs through the mud
and reaches the 620 m clearing in **31.22 s**, without resets. Low rally cars
still beach in deep mud as expected; the 4×4 remains the intended car. Star
times remain the existing placeholders, pending the owner's completed-track runs.

New regression checks cover progressive density/size/depth, seeded stability,
mixed dirt holes and bumps, clearance beneath the real holes, actual road ray
hits, sandstone on both sides from the start, local colour bands, matching LOD
colours, serial/threaded equivalence, shadow changes confined to the opening,
progressive muddy grades, turn count, widening/flattening into the clearing,
six crossing wheel tracks, depth-limited intersections and matching road seams.
The original three tracks' geometry fingerprints remain unchanged.

Screenshots used `tools/level_shots.tscn`, 1280×720, Forward Mobile, Off-road 4×4.
Final log: `/tmp/ridge-opening-accepted-shots.log`; images are in ignored
`build/level_shots/rock_canyon_offroad_4x4_*.png`. Desktop rendered build: **1.02 s**.

| Distance (m) | Primitives | Draw calls |
| --- | ---: | ---: |
| 15 | 126,410 | 94 |
| 100 | 141,522 | 94 |
| 250 | 149,178 | 99 |
| 300 | 131,106 | 102 |
| 350 | 147,232 | 92 |
| 405 | 157,514 | 98 |
| 465 | 155,528 | 96 |
| 505 | 165,032 | 99 |
| 540 | 186,954 | 95 |
| 580 | 183,058 | 95 |
| 620 | 157,226 | 93 |
| 650 | 186,102 | 97 |
| 820 | 209,194 | 84 |
| 1200 | 167,522 | 95 |
| 1290 | 97,392 | 76 |
| 1606 | 154,278 | 93 |
| 1840 | 113,884 | 84 |
| 2000 | 101,184 | 72 |

All sampled views are under 300k primitives / 150 draw calls, with substantial
headroom after removing road draws beyond the terrain horizon. Captures validate
geometry and rendering counts, not sustained phone FPS. No phone install or
performance claim this pass.

## Owner playtest

Drive through the clearing at about 650 m in Rock Canyon with the 4×4. Check the scale of the canyon,
whether the asphalt deterioration builds up clearly, whether holes offer useful
line choices, and whether the dirt is technical enough without becoming a trap.
Then check the muddy bends, steepening, alternate wheel lines, and the opening
into the clearing. Collect that feedback before changing any later section.
