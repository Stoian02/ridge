# Muddy Valley — Mud-Skip Fix Design

**Date:** 2026-09-14
**Status:** Approved by the owner
**Builds on:** `m2b2-muddy-valley` at 6d9c2a3

## Problem

The three mud stretches can be skipped on the dirt shoulders and grass outside
the road. A recorded run avoided nearly all the mud and finished in 75.7 s,
compared with 95.1 s through the mud.

## Design

### Mud verges

Inside a surface stretch, both shoulder rows use that stretch's collision
surface. Their colour blends from the normal shoulder colour to the stretch
colour using the same end fade as the road. Outside a stretch, shoulders remain
dirt. A trail without surface stretches produces the same road as before.

### Hedgerows

`TrailDef` describes hedge runs as `Vector3(start, length, side)`, where side is
-1 on the left and +1 on the right. It describes openings in the same format,
and explicit outward returns as `Vector3(distance, length, side)`. Explicit
returns let the creek-side hedge meet the bank without crossing the water.

`HedgeBuilder` places a dense row of low, dark-green, lumpy bushes just outside
the shoulder edge. Bushes are instanced in one `MultiMesh` per terrain chunk.
A chain of thin box shapes follows the row beneath the bushes, so the car cannot
squeeze between them. The collision carries the dirt surface tag.

At each end, the hedge turns away from the road into the scenery. These returns
make driving behind the entire hedge a significant detour rather than another
fast mud bypass. They are not intended as a world boundary: a determined player
may still explore beyond them, but doing so must not be the quick racing line.

### Muddy Valley placement

- Both sides of the 760–850 m mud stretch: hedge from 755–855 m.
- Both sides of the 980–1050 m mud stretch: hedge from 975–1055 m.
- Both sides of the 1300–1500 m climb: hedge from 1295–1505 m.
- Returns extend approximately 24 m outward into the scenery. On the creek side
  of the first stretch they extend 4 m to meet the inner bank.

The left hedge on the final climb has narrow openings centred near 1390 m and
1475 m. Offset bushes screen the openings from the road. The clear grass behind
the hedge connects them as a hidden shortcut, skipping only part of the climb.
The gap positions and widths are tuned with the real car.

## Constraints

- No changes under `car/` and no tuning changes in `surfaces/*.tres`.
- Rally Road remains unchanged.
- Existing scenery continues to keep 6 m clear of the shoulder edge.
- The generated hedge stays within the existing render budgets: fewer than
  300,000 visible primitives and 150 draw calls.

## Tests

- Shoulder collision is mud inside a stretch and dirt outside it.
- Shoulder colour blends into a stretch and remains unchanged elsewhere.
- Hedge bushes, walls and returns follow only configured runs.
- No longitudinal wall crosses a configured opening.
- A car attempting the direct left-verge bypass at the second mud stretch is
  stopped by the hedge or puts a wheel on mud.
- A car can enter and leave the final-climb shortcut through its two openings.
- The normal scripted driver still finishes Muddy Valley without a reset.
- Rally Road's recorded regression values remain unchanged.
- Unit, scenario and full suites contain no failure or `SCRIPT ERROR`.
