# Frozen Pass — desktop measurements, 2026-09-16

Branch: `m4-frozen-pass`, based on `947a17d`. Godot 4.7.2, Jolt at 120 Hz,
Mobile renderer, desktop AMD Radeon 880M (RADV GFX1150). Render captures use a
1280 × 720 window. Headless tests use `--fixed-fps 120 --max-fps 0`.

The owner explicitly deferred Android installation and measurements until after
their PC playtest. None of the following desktop numbers establish phone FPS,
phone load time, thermal behaviour, or sound quality.

## Loads

Isolated final benchmark, three successive rounds in one application session:

| Level | Round 1 total | Round 2 total | Round 3 total | Generated-level build range |
|---|---:|---:|---:|---:|
| Rally Road | 0.65 s | 0.35 s | 0.35 s | 0.34–0.36 s |
| Muddy Valley | 0.66 s | 0.66 s | 0.64 s | 0.64–0.65 s |
| Frozen Pass | 0.57 s | 0.56 s | 0.58 s | 0.56–0.57 s |

Rally Road is loaded first: its first total includes 0.20 s of resource loading
and first-use setup, including sound synthesis. Frozen Pass is not the first
resource load in this benchmark. Its fresh graphical-process build was 0.64 s
in the portal verification capture; a later capture during test execution was
0.73 s. These are build timings, not first-launch-to-play timings.

Typical generated-level phases in the final headless benchmark:

| Phase | Rally Road | Muddy Valley | Frozen Pass |
|---|---:|---:|---:|
| Field | 0.13–0.15 s | 0.16 s | 0.26–0.27 s |
| Road | 0.07 s | 0.12 s | 0.08–0.09 s |
| Shortcut | — | 0.18–0.19 s | — |
| Terrain arrays, meshes and collision | 0.09 s | 0.11–0.12 s | 0.17–0.18 s |
| Tunnel, portals and caps | — | — | 0.01 s |
| Bridge | — | — | < 0.01 s |
| Scatter | 0.05 s | 0.06 s | 0.03 s |

The earlier recorded desktop baseline in `performance-m3b.md` was 0.62 s for
Rally Road and 1.04 s for Muddy Valley. The remaining road/field work is now
parallelized. Road tests compare actual mesh/collision arrays against the
retained original serial builder, including Muddy Valley's curved, rutted road;
field tests require exact packed-array equality, preserving stamp accumulation
order. Three rounds show no progressive desktop reload slowdown. Android thermal
behaviour still needs measuring separately.

Reproduce from the project root:

```sh
godot --headless --path . -- --benchmark
```

Final local log: `/tmp/ridge-m4-load-final.log`.

## Render counts and screenshots

Frozen Pass, off-road 4x4, stationary captures after visibility/camera settling:

| Distance | Scene | Primitives | Draw calls |
|---|---|---:|---:|
| 15 m | Snow valley | 174,332 | 118 |
| 350 m | Climb approach | 199,155 | 128 |
| 450 m | First hairpin/checkpoint | 201,003 | 132 |
| 540 m | First ice patch | 121,408 | 93 |
| 755 m | Upper hairpin ice | 199,459 | 133 |
| 835 m | Bridge entrance | 183,563 | 120 |
| 850 m | Broken bridge midpoint | 186,743 | 122 |
| 870 m | Bridge recovery ramp | 194,575 | 127 |
| 1000 m | Upper climb | 158,607 | 112 |
| 1135 m | Tunnel portal | 154,980 | 111 |
| 1200 m | Inside tunnel | 148,076 | 107 |
| 1300 m | Tunnel S-bend | 140,462 | 107 |
| 1420 m | Icy tunnel exit | 120,130 | 102 |
| 1555 m | Descent ice | 106,500 | 89 |
| 1750 m | Descent hairpin | 58,100 | 65 |
| 1800 m | Lower descent | 96,300 | 75 |
| 1960 m | Final ice strip | 89,572 | 77 |
| 2050 m | Finish meadow | 101,892 | 78 |

All sampled Frozen Pass views are below 300k primitives and 150 draw calls.
These are spot checks, not a maximum over every moving frame. Snow spray can add
up to four draw calls while driving, as on the existing trails.

The Test Ground view between the snow/ice entrances (x = 52.5 m) initially drew
432,660 primitives. Dense neighbouring rough-ground strips were also being
drawn into the shadow map. They now receive shadows without casting their own,
as trail terrain already does; their geometry, closed sides and collision are
unchanged. Final result: **240,660 primitives, 92 draw calls**.

Captures were inspected for road/shoulder contrast, readable ice, the bridge,
portal seams, the curved tunnel, descent and Test Ground signs. The initial
portal gaps were fixed by completing the rock face and replacing removed grid
triangles with exactly clipped snow caps; chunks containing a portal retain
their fine mesh at distance so a coarse mesh cannot reopen those seams.

```sh
godot --path . --resolution 1280x720 res://tools/level_shots.tscn -- res://levels/frozen_pass/frozen_pass.tscn 15 350 450 540 755 835 850 870 1000 1135 1200 1300 1420 1555 1750 1800 1960 2050 car=offroad_4x4
godot --path . --resolution 1280x720 res://tools/level_shots.tscn -- res://levels/test_ground/test_ground.tscn 52.5 car=rally
```

PNGs are in ignored `build/level_shots/`, named
`frozen_pass_offroad_4x4_<distance>.png` and `test_ground_rally_0052.png`.
Additional rally-car portal captures cover 1100, 1135, 1147, 1180, 1390 and 1405 m.
Logs: `/tmp/ridge-m4-render.log`, `/tmp/ridge-m4-shots-3.log`,
`/tmp/ridge-m4-test-ground-render.log`.

## Driving and braking

Final gates: unit **418 passed**; all **479 passed / 1 pre-existing pending**,
27,721 assertions, 155.79 s, exit 0 and no `SCRIPT ERROR`. Final full-suite log:
`/tmp/ridge-m4-all-final.log`. The pending test is the already-known held-gas
jump nose-dive, outside the approved car-physics scope.

Surface-aware scripted runs, all finishing with **zero resets**:

| Car | Frozen Pass | Lowest bridge upright dot | Highest camera above tunnel road |
|---|---:|---:|---:|
| Rally Car | 218.22 s | 0.988 | 3.09 m |
| Rally Car Tuned | 201.01 s | 0.985 | 3.12 m |
| Off-road 4x4 | 191.74 s | 0.988 | 3.25 m |

The scripted driver deliberately slows for low grip; these are regression
numbers, not suggested star targets. Keep the approved 135/120 s placeholders
until the owner's real runs. Tunnel wall clearance, camera clearance and a
manual-only gorge reset are tested too.

Braking from a controlled initial **60 km/h** on the actual Test Ground strips,
measuring until forward speed falls below 0.2 m/s:

| Car | Asphalt | Snow | Ice |
|---|---:|---:|---:|
| Rally Car | 19.6 m | 33.1 m | 65.7 m |
| Rally Car Tuned | 17.0 m | 29.2 m | 60.1 m |
| Off-road 4x4 | 18.9 m | 24.1 m | 57.3 m |

All cars satisfy asphalt < snow < ice, with at least 20% between successive
distances. Initial velocity is set after settling, so acceleration distance does
not enter the measurement.

Existing-track regressions with the approved mud grip:

- Rally Road: stock **90.3 s**, tuned **86.3 s**, 4x4 **100.5 s**, zero resets;
  unchanged from the prior recorded results.
- Muddy Valley: stock **94.7 s**, tuned **88.2 s**, 4x4 **93.4 s**, zero resets.
  Stock now uses the same surface-aware driver as the other cars. The old
  surface-blind driver hit the final hedge at 1399 m, lateral −7.0 m. No finish,
  time, contact-loss or reset assertion was relaxed; no track geometry changed.
- Final mud climb from rest: stock **13.1 s**, 4x4 **11.3 s**.
- Three seconds accelerating from rest: **11.7 m** on mud versus **14.1 m** on dirt.
- Stock/tuned asphalt 0–100 km/h remains **7.49/5.14 s**.

## Deferred phone acceptance

After the owner tests on PC and connects the Xiaomi 13:

1. Build/install with `tools/android.sh build` and `tools/android.sh install`.
2. Measure fresh and repeated loads with the benchmark flag, not launch args:
   `adb shell run-as com.ridge.game touch files/benchmark`, then launch/log as
   described in the handover.
3. Check targets: Frozen Pass ≤ 3.0 s, Muddy Valley ≤ 2.0 s, Rally Road ≤ 1.3 s.
4. Drive the tunnel and snowy sections at 60 fps; check audio balance, seamless
   snow loops, retained audio tail padding, surface feel, and real star times.

No device installation, phone measurements or final star calibration is claimed.
