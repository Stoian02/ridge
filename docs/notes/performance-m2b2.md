# Performance: Muddy Valley (Milestone 2 Part B2), desktop

Build: `m2b2-muddy-valley` with the approved mud-skip fix. Measured with
`tools/level_shots.tscn` and the scenario tests. Phone numbers come from the
user's session after merge.

## Build time (desktop)
| Level | Build time | Terrain chunks | Pines | Broadleaf | Rocks | Posts |
|---|---|---|---|---|---|---|
| Rally Road | 1.20 s | 8 x 12 | 10188 | — | 5141 | 32 |
| Muddy Valley | 1.72 s | 11 x 11 | 2140 | 7507 | 6533 | 53 |

With the mud-skip fix, Muddy Valley builds in 1.46–1.60 s on the same desktop.
The hedges contain 651 bushes in 8 terrain-chunk batches.

## Render counts (desktop, the chase camera at each spot)
| Level | Spot (m) | Primitives | Draw calls | Objects |
|---|---|---|---|---|
| Muddy Valley | 15 | 261432 | 133 | 601 |
| Muddy Valley | 320 | 273964 | 125 | 597 |
| Muddy Valley | 560 | 261684 | 127 | 595 |
| Muddy Valley | 760 | 242292 | 119 | 589 |
| Muddy Valley | 1000 | 259288 | 110 | 574 |
| Muddy Valley | 1250 | 209632 | 111 | 581 |
| Muddy Valley | 1450 | 150648 | 96 | 562 |
| Rally Road | 15 | 268464 | 129 | 627 |
| Rally Road | 700 | 261232 | 103 | 601 |
| Rally Road | 1490 | 190076 | 99 | 593 |

The direct screenshot rerun for the mud-skip fix could not run in the handover
environment: it has no X11 or Wayland display, while Godot's headless display
uses the dummy renderer and cannot capture a frame. A conservative bound still
keeps the change within budget. Each bush has 20 triangles, so all 651 bushes
together add 13,020 primitives; all hedge batches together add 8 draw calls.
Adding every hedge at once to the previous sampled maxima gives 286,984
primitives and 141 draw calls, below the 300,000/150 budgets. The scenario test
enforces the bush and batch bounds. The displayed screenshots still need a
visual review on a machine with a display.

## Scripted driver and mud (desktop)
- Scripted driver: 1:39.8, no resets, 151 wheel-ticks without contact away from the jump.
- Standstill in the mud climb at 1400 m to the finish: 16.5 s.
- 3 s from rest: 8.6 m on mud, 13.9 m on dirt.
- Out of the creek: 6.0 s.
- Run-off: Muddy Valley crossed the finish at 29 km/h and stopped 4 m past it (road ends 70 m past it); Rally Road crossed the finish at 95 km/h and stopped 30 m past it (road ends 70 m past it).

## Mud-skip fix (desktop scenarios)

- Mud collision covers both shoulders inside every stretch and returns to dirt
  outside it.
- Scripted driver: completes in 1:32–1:41 with no resets.
- Direct outside-line attempt at the second stretch: stopped at 972 m before
  the 980 m mud, without touching mud.
- Hidden final-climb shortcut: enters near 1390 m, exits near 1475 m and reaches
  the road again at about 1487 m.
- Hedge render cost: 651 bushes × 20 triangles in 8 draw batches.

## Budgets still to check on the phone
60 fps, < 300k triangles, < 150 draw calls, < 4 ms physics, < 3 s load after a fresh app start.
