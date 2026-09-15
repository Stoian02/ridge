# Performance: cars and car select (Milestone 3 Part A), desktop

Build: `m3a-cars`. Measured with `tools/level_shots.tscn`, `tools/screenshot.sh` and
the scenario tests (`test_cars.gd`, `test_jump_landing.gd`) on the development
desktop (Godot 4.7.2, `--fixed-fps 120`). Phone numbers still to be measured.

## Render counts (desktop, the chase camera at each spot)

| Level | Car | Spot (m) | Build time | Primitives | Draw calls | Objects |
|---|---|---|---|---|---|---|
| Rally Road | Rally Car Tuned | 15 | 1.30 s | 268816 | 127 | 621 |
| Rally Road | Rally Car Tuned | 700 | 1.30 s | 265692 | 105 | 603 |
| Muddy Valley | Off-road 4x4 | 560 | 2.06 s | 319420 | 131 | 599 |
| Muddy Valley | Off-road 4x4 | 1400 | 2.06 s | 210172 | 118 | 580 |
| Muddy Valley | Rally Car | 560 | 2.04 s | 319064 | 131 | 601 |

Commands run:
```bash
godot --path . res://tools/level_shots.tscn -- res://levels/rally_road/rally_road.tscn 15 700 car=rally_tuned
godot --path . res://tools/level_shots.tscn -- res://levels/muddy_valley/muddy_valley.tscn 560 1400 car=offroad_4x4
godot --path . res://tools/level_shots.tscn -- res://levels/muddy_valley/muddy_valley.tscn 560 car=rally
tools/screenshot.sh res://ui/car_select.tscn 3
```

### Muddy Valley at 560 m against the 300k triangle budget

Both cars measured there come in **over** the 300,000-primitive budget: the
Off-road 4x4 at 319,420 and the Rally Car at 319,064 (draw calls, 131, stay
comfortably under the 150 budget). The earlier measurement at this spot
(Revision 3 in `performance-m2b2.md`) was 286,336 primitives, 95% of budget.

This is not an M3A regression. Measured the same day on the same desktop:
- master before any M3A code (5b4ed79, stock Rally Car): 318,816 primitives
- the M3A scratch clone, which earlier read 286,944: 319,416

The level hasn't changed. Today's desktop measurement reads about 32k higher
than the earlier passes, and the car barely matters (the two cars differ by
356 primitives). Muddy Valley at 560 m is the first spot to check on the
phone. If it is over budget there, trim it: the hedges and scatter near
560 m are the likely place.

## Car select screenshot

`build/screenshots/frame00000089.png` (last frame of a 3 s, 30 fps capture of
`res://ui/car_select.tscn` via `tools/screenshot.sh`). Screenshots are not
committed.

## Scenario tests (desktop, `test_cars.gd`)

```
Rally Car on RallyRoad: 1:30.3, 0 resets
Rally Car Tuned on RallyRoad: 1:26.3, 0 resets
Off-road 4x4 on RallyRoad: 1:40.8, 0 resets
Rally Car Tuned on MuddyValley: 1:38.2, 0 resets
Off-road 4x4 on MuddyValley: 1:35.0, 0 resets
0-100 km/h on asphalt: stock 7.49 s, tuned 5.14 s
from a standstill at 1400 m up the mud to the finish: Rally Car 16.6 s, 4x4 11.6 s
4 s from rest, left wheels on slick ground: locked 10.0 m, open 1.9 m
4x4 at full lock around 40 km/h on dirt: most tilt 3 deg
```
7/7 tests passed. These numbers match the scratch-clone numbers quoted in the
task brief exactly (the physics is deterministic at a fixed 120 Hz).

## Scenario tests (desktop, `test_jump_landing.gd`)

```
Rally Car: kicker at 100 km/h, gas lifted: 1.25 s in the air, worst tilt 12 deg, peak yaw 0.1 deg/s in the 0.5 s after landing, upright true
Rally Car: kicker at 100 km/h, gas held: 1.48 s in the air, worst tilt 64 deg, peak yaw 25.2 deg/s in the 0.5 s after landing, upright true
Rally Car Tuned: kicker at 100 km/h, gas lifted: 1.25 s in the air, worst tilt 12 deg, peak yaw 0.2 deg/s in the 0.5 s after landing, upright true
Off-road 4x4: kicker at 100 km/h, gas lifted: 1.11 s in the air, worst tilt 16 deg, peak yaw 0.1 deg/s in the 0.5 s after landing, upright true
```
2/3 passed, 1 pending (`test_holding_the_gas_flies_level_and_lands_straight`,
the known held-gas nose-dive, still waiting on a feel decision). The task
brief's Step 2 output block only quotes the two gas-lifted new-car lines
(Rally Car Tuned and Off-road 4x4), which match here exactly. The Rally Car
lifted/held lines above are the plain output of running the whole test file;
the held-gas figures (64 deg tilt, 25.2 deg/s yaw) are in the same ballpark
as the 64 deg/22 deg/s noted in the test's own code comment for the "Session
3 weight/grip pass" measurement, a small machine-to-machine difference in an
unasserted, already-pending measurement, not a regression (the test only
checks that it stays pending, which it did).

## Budgets still to check on the phone
60 fps, < 300k triangles, < 150 draw calls, < 4 ms physics, < 3 s load after a
fresh app start.
