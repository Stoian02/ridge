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

## Revision 2: Smoother Mud and Full-Length Shortcut

**Status:** Approved by the owner on 2026-09-14

### Mud transition

Each end of a mud stretch gets two 4 m physical stages, mirrored on exit. The
existing dirt, mud and car resources are unchanged.

| Surface | Grip | Rolling resistance | Sink | Drag |
|---|---:|---:|---:|---:|
| Damp dirt | 0.70 | 0.06 | 0.025 m | 12 |
| Soft mud | 0.60 | 0.08 | 0.04 m | 25 |
| Existing mud | 0.50 | 0.10 | 0.06 m | 40 |

Road and shoulder colour, and the rut depth, fade continuously over 12 m at
each end. Collision changes from dirt to damp dirt to soft mud to mud in smaller
steps instead of one abrupt change.

### Shortcut revision

The old entry around 1390 m is removed. A 4 m-wide worn track branches from the
left half of the road around 1275 m, passes behind the beginning of the final
left hedge at 1295 m, follows it, and rejoins through the opening around 1475 m.
The final left hedge has no start return because entering behind it is now the
intended shortcut.

The track is a slightly lighter, yellow-green version of the grass, with edges
blended back to the terrain colour. Its eased entry and exit make the route
readable and driveable. Muddy Valley's shoulders widen from 2.5 m to 3 m so the
main route and the shortcut join have enough recovery room without moving the
hedges closer to the car. It uses dirt traction, but frequent 12–22 cm potholes,
8 cm washboard and broader undulation make it substantially bumpier than the
mud route. The roughness fades at the entry and exit so the joins stay smooth.

## Revision 3: Seamless Joins and a Natural, Rocky Shortcut

**Status:** Approved by the owner on 2026-09-14

The owner found the shortcut's joins looked pasted on: the green path ribbon was drawn over the dirt road, leaving hard, jagged green shapes. The path also looked artificial, holding a constant 12 m offset and 4 m width with smooth waves. Its exit was hard to get through.

### Joins that blend into the road and grass
- **Mesh:** starts at the shoulder edge. Any point that would lie over the road is pulled back to the edge, so nothing is drawn on the road. Its height changes fade to zero over the first metre past the edge, so it meets the shoulder exactly.
- **Road shoulder:** on the path's side it is road-dirt coloured along each join (the entry and exit lengths) and fades back to grass over 6 m.
- **Worn middle:** fades from road dirt to worn grass over 15 m from each end.
- **Edges:** fade into the ground over 1.5 m each side.
- **Terrain:** the ground around the path is tinted toward the path colour, up to 50%, fading out 4 m past the worn middle. The mesh edge uses the same tint, so there is no visible ribbon edge.
- **Scenery:** trees and rocks are not placed on tinted ground.

### A more natural path
- It wanders around its offset (two summed waves, 47 m and 83 m); its worn middle varies around its width (31 m wave).
- In Muddy Valley the path sits 13.5 m out (was 12 m), wanders ±1.2 m, and is 4.0 m wide ±0.5 m.
- **Why not further out:** 17 m was tried first. Left of the final climb the ground is gentle only to about 14 m from the road centre, then falls away at 30–35°. At 1450–1485 m it lies 2–3.5 m below the road at 17 m and 4–6 m below at 20 m. A path out there tilted the scenario car up to 33° sideways, and near the exit it slid down the slope and stalled instead of climbing back to the road. At 13.5 m ±1.2 m the path stays on the gentle band. Its inner edge keeps at least about 0.1 m clear of the hedge's collision wall (at 9.05–9.95 m), so it runs close to the hedge, as the previous path did.

### Rocky, not wavy
- Washboard 1.5 cm (was 8 cm) and undulation 3 cm (was 10 cm).
- Potholes every ~18 m (was ~9 m).
- **Stones:** short, sharp bumps 8–15 cm high with a 0.2–0.4 m radius, about every 1.2 m. They sit within the middle 60% of the width, where the path is fully rough. About a third show a half-buried rock.
- Dirt traction. Roughness still fades in over 20 m from each end.
- The mesh uses 0.33 m rows and up to 0.4 m across its middle, so stones keep their shape.

### A wider exit
- The final left hedge opening is 1463–1487 m, 24 m (was 1470–1484 m).
- The path rejoins over 30 m (was 20 m), so the angle back onto the road is shallower.

### Tests
- The path eases from and back to the road, wanders within its amplitude, and varies its width.
- The mesh's nearest vertices sit on the shoulder edge; none are over the road.
- It is rough in the middle, and level with the road where it branches off and rejoins.
- Stones stand up from the path, and some show a rock.
- The ground beside the path is tinted and kept clear of scenery.
- The road shoulder is road dirt along each join and unchanged elsewhere.
- The existing scenarios (shortcut drive-through, blocked bypass, scripted driver) and Rally Road's regression still pass.
