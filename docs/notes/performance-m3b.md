# Performance: surface feedback and sound (Milestone 3 Part B), desktop

Build: `m3b-feedback`, desktop (Godot 4.7.2, Mobile renderer, `--fixed-fps 120` for tests). Phone numbers are still to be measured, and sound can only be judged on the phone.

## Render counts (desktop, `tools/level_shots.tscn`, car at rest)

| Level | Spot (m) | Build time | Primitives | Draw calls | Objects |
|---|---|---|---|---|---|
| Muddy Valley | 560 | 1.82 s | 319,180 | 131 | 605 |
| Rally Road | 15 | 1.15 s | 268,816 | 127 | 621 |

- **Draw calls** are unchanged from master: 131 and 127.
- **Sprays cost nothing when idle.** A probe showed each `CPUParticles3D` adds one draw call once it has emitted and keeps it until hidden, and `WheelSpray` hides itself after its particles die. At most 4 more draw calls while all four wheels spray.
- **Build time** measured on this branch: Muddy Valley 1.82 s, Rally Road 1.15 s.

## Sounds
- Building all nine synthesized sounds takes about 68 ms, once per app session (`test_sound_synth.gd` prints it).
- Headless test runs use Godot's Dummy audio driver, which still reports players as playing.

## CPU per frame
- **`CarEffects` + `CarAudio`**, measured by `test_effects_and_audio_stay_under_the_cpu_budget` (Test Ground, Rally Car, full throttle on mud for 3 s): average 0.027 ms, worst 0.054 ms, against the spec §8 budget of 0.3 ms. `WheelMotion` is now computed once per wheel per frame (`CarEffects` fills a shared `wheels` array that `CarAudio` reads) instead of twice.

## Scenario tests (desktop, `test_car_feedback.gd`)

```
mud: 4 wheels throwing clods, loudest mud 0.53, skid 0.0
dirt: 4 wheels throwing dust, loudest gravel 0.80, mud 0.0
asphalt straight at 56 km/h: 0 smoking, loudest road 0.72, skid 0.0
asphalt at full lock: 4 smoking, loudest skid 0.69
engine: idle 1000 rpm pitch 0.67, top 7200 rpm high-layer pitch 1.60
thumps from a 2.5 m drop: 1 (and none for a reset)
```

## Physics unchanged
- Lap times and scenario numbers match master: Rally Road 1:30.3 / 1:26.3 / 1:40.5, Muddy Valley 1:38.2 / 1:34.9, 0–100 km/h 7.49 / 5.14 s, diff locks 9.9 / 1.9 m, 4x4 clearance 32 cm.
- The standstill mud climb reads 16.6 s when run alone and 16.5 s inside the full suite, on both master and this branch.

## Test-run warning
Headless runs that play sound end with "N ObjectDB instances were leaked at exit". Godot prints it whenever a playing sound is freed just before quitting, as GUT does after a test. A two-node probe with no project code prints the same. It is a warning, not a script error.

## Still to check on the phone
- 60 fps with all four wheels spraying.
- Sound: loudness balance, engine pitch, whether the loops sound seamless.
- Load time after a fresh app start (< 3 s).

## Level load time on the phone (2026-09-15)

**Tool.** `debug/load_benchmark.tscn` loads Rally Road and Muddy Valley three times in a row and prints each load. `TrailLevel.build` now records each phase, and the "built in" line prints them.
- **Phone:** Android doesn't pass launch arguments on to the game, so the main menu runs the benchmark when a `benchmark` file is in `user://` (debug builds only):
  ```
  adb shell run-as com.ridge.game touch files/benchmark
  adb shell am start -n com.ridge.game/com.godot.game.GodotAppLauncher
  adb logcat -v time -s godot
  ```
- **Desktop:** `godot --path . -- --benchmark`

| Load | Rally Road (phone) | Muddy Valley (phone) | Desktop |
|---|---|---|---|
| 1st (phone cool, CPU 42 °C) | 2.86 s | 4.66 s | RR 1.12 s, MV 1.80 s |
| 2nd | 3.42 s | 5.30 s | same |
| 3rd (CPU 53.5 °C after) | 3.54 s | 8.21 s | same |

Muddy Valley phases on the phone, 1st → 3rd load:

| Phase | 1st load | 3rd load |
|---|---|---|
| terrain | 2.45 s | 4.24 s |
| road | 0.98 s | 1.81 s |
| field | 0.65 s | 1.04 s |
| shortcut | 0.39 s | 0.76 s |
| scatter | 0.17 s | 0.33 s |

**Findings:**
- **Uniform slowdown.** Every phase slows together from load to load, so it is the CPU getting slower as the phone heats up (frequency scaling), not one phase or memory. Memory available stayed at 2.1–2.6 GB. The earlier 8–9 s loads were a warm phone.
- **Over budget even when cool.** A cool phone builds 2.6× slower than the desktop. Muddy Valley (4.7 s) is over the 3 s budget; Rally Road (2.9 s) only just makes it.
- **Single-threaded.** Terrain mesh and collision generation is over half of every build, and all of it runs on the main thread on one core (the phone has 8).
