# Performance: Muddy Valley (Milestone 2 Part B2), desktop

Build: `m2b2-muddy-valley` at `a5b4b6a`. Measured with `tools/level_shots.tscn` and the scenario tests. Phone numbers come from the user's session after merge.

## Build time (desktop)
| Level | Build time | Terrain chunks | Pines | Broadleaf | Rocks | Posts |
|---|---|---|---|---|---|---|
| Rally Road | 1.20 s | 8 x 12 | 10188 | — | 5141 | 32 |
| Muddy Valley | 1.72 s | 11 x 11 | 2140 | 7507 | 6533 | 53 |

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

## Scripted driver and mud (desktop)
- Scripted driver: 1:39.8, no resets, 151 wheel-ticks without contact away from the jump.
- Standstill in the mud climb at 1400 m to the finish: 16.5 s.
- 3 s from rest: 8.6 m on mud, 13.9 m on dirt.
- Out of the creek: 6.0 s.
- Run-off: Muddy Valley crossed the finish at 29 km/h and stopped 4 m past it (road ends 70 m past it); Rally Road crossed the finish at 95 km/h and stopped 30 m past it (road ends 70 m past it).

## Budgets still to check on the phone
60 fps, < 300k triangles, < 150 draw calls, < 4 ms physics, < 3 s load after a fresh app start.
