# Performance: Muddy Valley (Milestone 2 Part B2), desktop

Build: `m2b2-muddy-valley` with the approved mud-skip fix. Measured with
`tools/level_shots.tscn` and the scenario tests. Phone numbers come from the
user's session after merge.

## Build time (desktop)
| Level | Build time | Terrain chunks | Pines | Broadleaf | Rocks | Posts |
|---|---|---|---|---|---|---|
| Rally Road | 1.20 s | 8 x 12 | 10188 | — | 5141 | 32 |
| Muddy Valley | 1.72 s | 11 x 11 | 2140 | 7507 | 6533 | 53 |

With the revised mud-skip fix, Muddy Valley builds in 1.55–1.64 s on the same
desktop. The hedges contain 636 bushes in 7 terrain-chunk batches, and the worn
shortcut contains 6,880 triangles in one mesh and one collision body.

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
keeps the change within budget. Each bush has 20 triangles, so all 636 bushes
together add 12,720 primitives. Adding every hedge and shortcut triangle at
once to the previous sampled maxima gives 293,564 primitives and 141 draw
calls, below the 300,000/150 budgets. The scenario test enforces the geometry
and batch bounds. The displayed screenshots still need a visual review on a
machine with a display.

## Scripted driver and mud (desktop)
- Scripted driver: 1:41.7–1:41.8, no resets, 117–131 wheel-ticks without contact away from the jump.
- Standstill in the mud climb at 1400 m to the finish: 16.4–16.6 s.
- 3 s from rest: 10.2 m on mud, 13.5 m on dirt.
- Out of the creek: 5.9 s.
- Run-off: Muddy Valley crossed the finish at 31 km/h and stopped 4 m past it (road ends 70 m past it); Rally Road crossed the finish at 95 km/h and stopped 30 m past it (road ends 70 m past it).

## Mud-skip fix (desktop scenarios)

- Mud collision covers both shoulders inside every stretch and returns to dirt
  outside it.
- Scripted driver: completes in 1:41.7 with no resets after the staged mud and
  widened shoulders.
- Direct outside-line attempt at the second stretch: stopped at 972 m before
  the 980 m mud, without touching mud.
- Hidden final-climb shortcut: branches from the road at 1275 m, passes behind
  the hedge from 1295 m, and reaches the road again at about 1487 m. The real
  car completes it in 29.4–29.5 s with 0.289–0.294 m of
  suspension-compression range.
- New-path render cost: 636 hedge bushes × 20 triangles in 7 draw batches, plus
  6,880 shortcut triangles in one draw call.

## Budgets still to check on the phone
60 fps, < 300k triangles, < 150 draw calls, < 4 ms physics, < 3 s load after a fresh app start.

## Revision 3: seamless joins and a rocky shortcut (desktop, 2026-09-14)

Measured with `tools/level_shots.tscn` after the shortcut rework. The worn middle has 0.33 m rows, so its stones keep their shape. The shortcut mesh is ~20k triangles in one draw call, plus one batch of rocks.

| Level | Spot (m) | Primitives | Draw calls | Objects |
|---|---|---|---|---|
| Muddy Valley | 15 | 263692 | 133 | 605 |
| Muddy Valley | 320 | 276876 | 127 | 597 |
| Muddy Valley | 560 | 286336 | 130 | 602 |
| Muddy Valley | 760 | 273168 | 125 | 621 |
| Muddy Valley | 1000 | 284888 | 113 | 581 |
| Muddy Valley | 1250 | 243468 | 115 | 591 |
| Muddy Valley | 1300 | 242632 | 113 | 609 |
| Muddy Valley | 1400 | 203848 | 115 | 583 |
| Muddy Valley | 1450 | 175236 | 100 | 568 |
| Muddy Valley | 1480 | 177836 | 99 | 567 |

- Build time: 1.83–1.88 s.
- The peak is 286,336 primitives at 560 m, away from the shortcut, beside the hedges; that's 95% of the 300k budget. Check this spot first on the phone.
- With the shortcut in view (1250–1480 m) the peak is 243,468.
- Scenario trace: the car drives the whole shortcut and rejoins the road in 26.7 s. Its sideways tilt stays under 23° at the path's 13.5 m offset. At 17 m it reached 33° and slid down the hillside at the exit.
