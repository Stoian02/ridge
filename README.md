# Ridge

A 3D physics-based off-road driving game for Android, made with Godot 4 and Jolt physics.

You drive hand-built trails over asphalt, dirt, mud and creeks, and try to reach the finish fast enough to earn stars. Stars unlock new cars, and each car suits different ground. Driving feel comes first: suspension, traction and weight should feel real, never floaty.

> **Status:** early development. The cars' bodies are simple low-poly test models, and handling is still being tuned on a real phone.

## What's in the game

- **Levels**
  - **Rally Road:** a fast asphalt road. 2 stars under 1:20, 3 stars under 1:12.
  - **Muddy Valley:** a bumpy dirt trail with rutted mud, a creek and a hidden shortcut. 2 stars under 1:35, 3 stars under 1:25.
  - **Test Ground:** free drive on an open test area. It has an asphalt runway with cones and a kicker jump, dirt and asphalt hills up to 30°, mud strips, and a rough lane with potholes and speed bumps.
- **Cars**
  - **Rally Car:** balanced all-wheel drive, quick and forgiving everywhere.
  - **Off-road 4x4:** unlocks at 3 ★. A red, Bronco Raptor-style truck with big tyres, 32 cm of ground clearance and locking differentials. Loves mud, slow on asphalt.
  - **Rally Car Tuned:** unlocks at 5 ★. More power, stiffer and grippier. Fast, but less forgiving.
- **Physics**
  - raycast-wheel car at 120 Hz
  - per-surface grip, with mud that sinks the wheels
  - suspension with anti-roll bars
  - traction control and ABS
  - differential locks
  - air control on jumps
- **Game flow**
  - main menu → level select → car select → run
  - pause menu with Change car
  - results screen with stars and best times
  - saved progress

## Controls

| | Phone | Keyboard | Gamepad |
|---|---|---|---|
| Gas | right pedal | W / ↑ | right trigger |
| Brake / reverse | left pedal | S / ↓ | left trigger |
| Steer | drag on the left side, or two buttons (set in the pause menu) | A D / ← → | left stick |
| Reset car | Reset button | R | Y |
| Telemetry overlay | pause menu | F1 | Back |
| Record a run to CSV | pause menu | F2 | |

## Requirements

- [Godot 4.7.2](https://godotengine.org/), available on the `PATH` as `godot`.
- For phone builds: Godot's Android export templates, the Android SDK, and `adb`.

The [GUT](https://github.com/bitwes/Gut) test framework is included in `addons/gut`.

## Running

Open the folder in the Godot editor and press Play. Or from a terminal:

```bash
godot --path .
```

## Tests

```bash
./run_tests.sh unit        # fast unit tests
./run_tests.sh scenarios   # physics scenarios: full laps with a scripted driver (several minutes)
./run_tests.sh all
```

A run fails on any failing test or any `SCRIPT ERROR`.

## Building for Android

Connect a phone with USB debugging on, then run:

```bash
tools/android.sh           # build a debug APK, install it and launch it
tools/android.sh build     # only build build/ridge-debug.apk
tools/android.sh logs      # follow the game's log
tools/pull_runs.sh         # copy recorded runs from the phone into ./runs/
```

## Project layout

| Folder | What's there |
|---|---|
| `car/` | the car: wheels, suspension, drivetrain, steering, stats and the three cars' data |
| `surfaces/` | surface definitions (grip, sink depth) and the per-car grip table |
| `levels/` | the levels, and `trail/`, which builds terrain, roads, creeks and scenery from data |
| `game/` | runs, checkpoints, stars, progress and saving |
| `ui/` | menus, car select, HUD and results |
| `input/` | keyboard, gamepad and touch controls |
| `camera/`, `debug/` | chase camera, telemetry overlay and run recorder |
| `tests/` | unit tests and physics scenarios |
| `tools/` | Android build, screenshots, level shots and curve generators |
| `docs/` | design specs, implementation plans and performance notes |

`ridge-prd.md` is the original product brief, and `docs/notes/feel-log.md` records the handling tuning so far.
