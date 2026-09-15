# Ridge Milestone 3, Part B — Surface Feedback and Sound: Design Spec

**Date:** 2026-09-15
**Status:** Approved to build (the owner chose "go end to end": spec, plan and build, stopping before the merge for a phone test)
**Parent spec:** `docs/superpowers/specs/2026-09-11-ridge-design.md` (binding). It refines §5 Surfaces ("each surface gets its own particles and tire audio"), §7 Game systems (audio settings) and §11 (particles and audio).
**Builds on:** `master` at 3a0c067 (Milestone 3 Part A merged, README added)

---

## 1. Summary

Part B makes the ground readable by eye and ear:
- **Wheel spray:** mud clods on mud, dust on dirt, and tyre smoke when tyres slide or spin on asphalt.
- **Car sound:**
  - an engine whose pitch follows the revs and whose loudness follows the throttle
  - tyre and surface sound: gravel crunch on dirt, squelch in mud, a squeal when sliding on asphalt
  - thumps on hard landings and big hits
- **Level ambience:** a quiet outdoor bed of wind and birds.
- **A Sound setting** in the pause menu, saved with the other settings.

Every sound is **synthesized in code** at startup. There are no sound files. The car's physics are untouched: every lap time and scenario number stays exactly as it is today.

## 2. Decisions from the design conversation

| Question | Decision |
|---|---|
| How to proceed | End to end on its own branch; stop before the merge; the owner tests on the phone |
| Where the sounds come from | Synthesized in code; recordings may replace them later |
| Visual effects | Mud spray, dirt dust, asphalt tyre smoke. No camera shake. |
| Sounds | Engine; tyres and surfaces; impacts and landings; ambience plus a volume setting |

**Rulings made while the owner was away** (each can be changed after the phone test):
- **The surface files stay untouched.** How each surface looks and sounds lives in a separate table keyed by surface id, like the grip table. `AGENTS.md` asks for the owner before changing `surfaces/*.tres`.
- **One emitter per wheel.** It switches between clods, dust and smoke with the surface under the wheel, and hides itself when idle. It costs at most 4 draw calls while spraying and none when idle.
- **Engine sound is two blended layers.** A low loop and a high loop are pitched and cross-faded by rpm, so the pitch never stretches far enough to sound broken.
- **The volume setting is a button** that steps through 100 / 75 / 50 / 25 % / Off. Buttons already work well on the phone and fit the pause menu.
- **Sound plays without positioning.** Players are non-positional, because the camera always follows the player's car. That is cheaper and just as clear.

## 3. How each surface looks and sounds

### 3.1 The table
- **`SurfaceFeel`** (`effects/surface_feel.gd`, `Resource`) holds:
  - `spray: SprayKind`: `NONE`, `CLODS`, `DUST` or `SMOKE`
  - `spray_color: Color`
  - `rolling: RollingSound`: `NONE`, `ROAD`, `GRAVEL` or `MUD`
  - `skids: bool`: whether sliding tyres squeal and smoke here
- **`SurfaceFeelTable`** (`effects/surface_feel_table.gd`; data in `effects/surface_feel_table.tres`):
  - `feels: Dictionary`, from surface id (`StringName`) to `SurfaceFeel`
  - `fallback: SurfaceFeel`
  - `feel_for(surface: SurfaceDef) -> SurfaceFeel`: the entry for the surface's id, the fallback for an unknown id, and `null` for no surface (in the air)

### 3.2 Entries
| Surface ids | Spray | Colour | Rolling | Skids |
|---|---|---|---|---|
| `asphalt` | smoke (sliding only) | light grey (0.82, 0.82, 0.8) | road | yes |
| `dirt`, `damp_dirt` | dust | tan (0.62, 0.52, 0.38) | gravel | no |
| `mud`, `soft_mud` | clods | dark brown (0.24, 0.17, 0.11) | mud | no |
| fallback (unknown ids) | dust | tan | gravel | no |

## 4. Wheel spray

### 4.1 The rule (`SprayLogic`, `effects/spray_logic.gd`, static and pure)
`SprayLogic.intensity(kind, ground_speed, slip_speed, sliding) -> float`, from 0 to 1, where:
- `ground_speed` is how fast the wheel's contact point moves over the ground (m/s)
- `slip_speed` is the difference between the tread speed and the ground speed (m/s)
- `sliding` is true when the tyre is past its grip: `|slip_ratio| > 0.6` or `|slip_angle| > 12°`, with `ground_speed > 3`
  - The slip-ratio limit sits well above traction control's 0.3 target. The Rally Car's rear tyres slip 0.2–0.55 for about 2.5 s on a full-throttle asphalt launch, and at 0.25 that alone poured smoke from every wheel. With 0.6, a hard launch gives only a short puff.

| Kind | Intensity |
|---|---|
| `CLODS` | `clamp(slip_speed / 6, 0, 1)` plus `clamp((ground_speed - 3) / 15, 0, 0.5)`, capped at 1 |
| `DUST` | `clamp((ground_speed - 4) / 16, 0, 1)` plus `clamp(slip_speed / 10, 0, 0.4)`, capped at 1 |
| `SMOKE` | when sliding: `clamp(0.3 + slip_speed / 8, 0, 1)`; otherwise 0 |
| `NONE` | 0 |

A wheel in the air sprays nothing.

### 4.2 The emitter (`WheelSpray`, `effects/wheel_spray.gd`, `CPUParticles3D`)
- **Placement:** one per wheel, sitting at that wheel's contact point, created by `CarEffects` (§6).
- **Settings:** `amount` 24, with particles in world coordinates (they stay where they were thrown), and lifetimes of 0.7 s for clods, 1.2 s for dust and 1.4 s for smoke. The mesh is a small camera-facing quad with an unshaded, vertex-coloured, alpha-blended material, shared by all emitters.
- **Per kind:**
  - *Clods:* thrown backward and upward from behind the tyre, heavy gravity, small, opaque.
  - *Dust:* slow, rising a little, larger and growing, fading out.
  - *Smoke:* slower and larger still, drifting up, fading out.
- **Each frame:** `update(feel, intensity)`:
  - it emits while intensity is above 0.05; intensity scales the particles' opacity (0.35–0.9) and their throw speed (50–100% of the kind's), while the particle count stays fixed, since changing it restarts the emitter
  - when the kind changes it switches its settings
- **When idle:** once it has stopped emitting for longer than its lifetime, it sets `visible = false`, which frees its draw call.

## 5. Sound

### 5.1 Synthesis (`SoundSynth`, `effects/sound_synth.gd`, static)
All sounds are 16-bit mono `AudioStreamWAV` at 22 050 Hz. They are built the first time they are asked for and cached for the rest of the app session. Loops loop seamlessly: tones use whole cycles, and noise loops cross-fade their end into their start.

| Name | Kind | What it is |
|---|---|---|
| `engine_low` | loop, 0.4 s | Four-cylinder firing tone for 1500 rpm (50 Hz) with harmonics 2–4, a half-order rumble and a slight per-cycle roughness |
| `engine_high` | loop, 0.4 s | The same for 4500 rpm (150 Hz), brighter |
| `road` | loop, 1.0 s | Tyres rolling on asphalt: a low rumble with a soft 110 Hz tread note (changed after the phone test, where the first filtered-noise version hissed and got obnoxious at speed) |
| `gravel` | loop, 1.0 s | Band-passed noise with random crackle clicks |
| `mud` | loop, 1.5 s | Low-passed noise with slow wet "bubble" swells |
| `skid` | loop, 0.8 s | A ~900 Hz squeal with vibrato, over noise |
| `wind` | loop, 4.0 s | Very low-passed noise with slow swells |
| `bird` | one-shot, 0.35 s | Two quick rising chirps |
| `thump` | one-shot, 0.3 s | A falling 70 → 40 Hz tone with a noise burst, fast decay |

**Cost:** building all of them must take under 100 ms on the desktop, once per app session. The first full build measured 68 ms; the sounds come to about 10 s of audio.

### 5.2 Engine (`EngineSoundLogic`, `effects/engine_sound_logic.gd`, static and pure)
`EngineSoundLogic.layers(rpm, throttle, shifting) -> Dictionary` returns `low_pitch`, `low_volume`, `high_pitch`, `high_volume` (linear 0–1):
- **Pitch:** low `rpm / 1500`, high `rpm / 4500`, each clamped to 0.5–2.0.
- **Crossfade:** `blend = smoothstep(2000, 4000, rpm)`. The low layer gets `1 - blend` and the high layer gets `blend`.
- **Loudness:** `0.45 + 0.55 × throttle`, times 0.6 while `shifting`.

### 5.3 Tyres and surfaces (`TyreSoundLogic`, `effects/tyre_sound_logic.gd`, static and pure)
`TyreSoundLogic.mix(wheels: Array[Dictionary]) -> Dictionary` returns `road`, `gravel`, `mud` and `skid`, each from 0 to 1. Each wheel's Dictionary holds `feel`, `ground_speed`, `slip_speed` and `sliding`:
- **Rolling sounds:** each wheel on the ground adds `clamp(ground_speed / 25, 0, 1) × 0.25` to its surface's rolling sound. Mud also adds `clamp(slip_speed / 8, 0, 1) × 0.25`.
  - Asphalt is the exception: each wheel adds `clamp(ground_speed / 35, 0, 1) × 0.25 × 0.35`. That caps the road hum at 0.35 and reaches it only at 126 km/h, because at full loudness it drowned out the car on the phone.
- **Skid:** each sliding wheel on a skidding surface adds `clamp(0.3 + slip_speed / 10, 0, 1) × 0.25`.
- **Result:** every total is capped at 1.
- **Pitch:** `CarAudio` scales the pitch of rolling sounds by `0.8 + 0.4 × clamp(speed / 30, 0, 1)`.

### 5.4 Impacts (`ImpactLogic`, `effects/impact_logic.gd`, static and pure)
`ImpactLogic.strength(compression_speed, bottomed_out) -> float`, from 0 to 1: `clamp((compression_speed - 1.2) / 3.0, 0, 1)`, and at least 0.6 when `bottomed_out`.
- **Bottomed out:** compression is above 85% of travel.
- **Per wheel, each frame:** `CarAudio` plays `thump` when the strongest wheel's strength is above 0, with volume `0.35 + 0.65 × strength`.
- **Limits:**
  - at most one thump every 0.25 s
  - none for 0.5 s after `DrivingRig.place_car`, so resets are silent

### 5.5 The car's players (`CarAudio`, `effects/car_audio.gd`, `Node`)
- **Where it lives:** a child of `DrivingRig`, set up with the rig's car. It is not part of the car scene, so car select previews and bare-car tests stay silent.
- **Players:** plain `AudioStreamPlayer`s on the `Master` bus: `engine_low`, `engine_high`, `road`, `gravel`, `mud`, `skid`, plus one `thump` player.
- **Each frame (`_process`):** it reads the car's drivetrain and wheels, gets the levels from the logic classes above, and sets each player's `pitch_scale` and `volume_db` (`linear_to_db`, with silence below 0.01).
- **Smoothing:** volume changes are eased with `move_toward` at 4 per second, so sounds never click.
- **Pause:** the players are pausable nodes, so sound stops while the game is paused and resumes after, without extra code (verified by a probe).
- **Reset:** `notify_reset()` starts the 0.5 s impact mute.
- **Leaving the scene:** `_exit_tree()` stops every player; `LevelAmbience` does the same for its two. Without this, `./run_tests.sh all` hung twice at the same point, spinning on its main thread at the start of the new cars' Muddy Valley test, after earlier tests had freed many playing players. With it, the suite passes. The exact cause inside the engine is unknown.

### 5.6 Ambience (`LevelAmbience`, `effects/level_ambience.gd`, `Node`)
- **Where it lives:** added to Rally Road, Muddy Valley and the Test Ground scenes.
- **Exports:** `wind_volume` (linear, default 0.35), `birds` (bool, default true), `bird_interval` (Vector2 seconds, default (6, 16)).
- **Wind:** plays the `wind` loop at `wind_volume`.
- **Birds:** when on, a `bird` one-shot plays at a random interval, with random pitch 0.85–1.25 and volume 0.2–0.45. The random numbers are seeded, so tests are repeatable.
- **Per level:**
  - Rally Road: wind 0.4, birds on
  - Muddy Valley: wind 0.3, birds on, interval (4, 12)
  - Test Ground: wind 0.25, birds off

## 6. On the car: `CarEffects`
- **Node:** `CarEffects` (`effects/car_effects.gd`, `Node3D`) is a child of `DrivingRig`, set up with the rig's car.
- **Setup:** creates one `WheelSpray` per wheel.
- **Each frame:**
  - for each wheel, work out `ground_speed`, `slip_speed` and `sliding` from the wheel state (§6.1)
  - get the wheel's `SurfaceFeel` from the table
  - move the wheel's spray to its contact point and update it
- **Reset:** `notify_reset()` stops all sprays at once, so a reset leaves no trail.
- **`DrivingRig`** creates `CarEffects` and `CarAudio` in `_ready`, and `place_car` calls both `notify_reset()`s.

### 6.1 Wheel motion for effects (`WheelMotion`, `effects/wheel_motion.gd`, static and pure)
`WheelMotion.of(wheel: Wheel, car: Car) -> Dictionary` returns `ground_speed`, `slip_speed` and `sliding`. It is computed from the wheel's contact point velocity (`car.linear_velocity + car.angular_velocity × (contact_point - car.global_position)`), its tread speed (`spin_speed × wheel_radius`), `slip_ratio` and `slip_angle`. It only reads state and never changes the car.

## 7. The Sound setting
- **Progress:** `sound_volume: float`, saved under `settings.sound_volume`, default 1.0. Loading accepts only the steps 0.0, 0.25, 0.5, 0.75 and 1.0; anything else keeps the default.
- **`GameState`:**
  - `set_sound_volume(value)` stores the value, applies it and saves
  - `apply_sound_volume()` sets the `Master` bus volume to `linear_to_db(value)` and mutes the bus at 0. It is called after loading.
- **Pause menu:** a "Sound: 100%" button under Steering steps through 100 → 75 → 50 → 25 → Off → 100.

## 8. Performance
- **Draw calls:** at most +4 while spraying and none when idle, checked with `tools/level_shots` in both levels. Muddy Valley is at 131 today, against a budget of 150.
- **Particles:** 4 × 24 quads at most.
- **CPU:** `CarEffects` and `CarAudio` together must stay under 0.3 ms a frame on the desktop.
- **Load time:** building the sounds once is under 100 ms. The level build time must not grow by more than 0.15 s.
- **Physics:** unchanged. Effects run in `_process` and only read physics state.

## 9. Testing

### 9.1 Unit tests
- **`SurfaceFeelTable`:**
  - all five shipped surface ids map as in §3.2
  - an unknown id gets the fallback
  - no surface gets `null`
- **`SprayLogic`:**
  - clods grow with slip
  - dust is zero at a walking pace and grows with speed
  - smoke only while sliding
  - `NONE` is always 0
  - results stay within 0–1
- **`EngineSoundLogic`:**
  - pitch rises with rpm
  - the layers cross-fade (low at idle, high near redline)
  - throttle makes it louder
  - shifting dips it
- **`TyreSoundLogic`:**
  - dirt wheels feed gravel and mud wheels feed mud
  - a sliding asphalt wheel feeds skid, but a sliding dirt wheel doesn't
  - airborne wheels feed nothing
  - results are capped at 1
- **`ImpactLogic`:**
  - soft compression gives 0
  - a hard hit gives more
  - bottoming out gives at least 0.6
- **`SoundSynth`:**
  - each sound has the right length and loop mode
  - no sound is silent or clipped
  - the loops join smoothly (first and last samples are close)
  - sounds are cached: a second request returns the same object
- **`WheelMotion`:**
  - a wheel rolling with the car has near-zero slip speed
  - a spinning wheel on a stopped car has slip speed equal to its tread speed
- **`WheelSpray`:**
  - it emits above the threshold and switches settings with the kind
  - it hides once it has been idle longer than its lifetime
- **Progress and `GameState`:**
  - `sound_volume` round-trips
  - bad values keep the default
  - `set_sound_volume` saves and sets the bus volume, muting at 0
- **Pause menu:** the Sound button steps through the values, saves, and updates its label.
- **`DrivingRig`:** it has `CarEffects` and `CarAudio`, and `place_car` notifies both.

### 9.2 Scenario tests (headless, real physics)
Tests run with Godot's Dummy audio driver, which still reports players as playing.
- **Test Ground mud:** full throttle from rest on the mud strip: the driven wheels spray clods, and the mud sound is up.
- **Test Ground asphalt:** a steady straight cruise: no smoke, the road sound is up, no skid. Full lock at speed until the tyres slide: smoke and skid.
- **Test Ground dirt:** at speed, the wheels throw dust and the gravel sound is up.
- **Engine:** the pitch at full throttle near redline is well above the pitch at idle.
- **Kicker jump:** landing plays a thump. A reset right after plays none.
- **Physics unchanged:** the existing scenario numbers (lap times, 0–100, climbs, landings) are identical to master when each test runs the same way.
  - Run alone, the standstill mud climb reads 16.6 s on both master and this branch.
  - Inside a full-suite run it reads 16.5 s on both.

Headless runs that play sound end with a warning like "N ObjectDB instances were leaked at exit". Godot prints it for any sound freed just before quitting, as GUT does at the end of a test; a two-node probe with no project code gives the same warning. It is a warning, not a script error, so `run_tests.sh` still passes.

### 9.3 Checks by eye and ear
- **Draw calls and build time** with `tools/level_shots`, recorded in `docs/notes/performance-m3b.md`.
- **Sprays and sound are judged on the phone.** Sprays only appear while driving, and the screenshot tools show a parked car. Sound can't be heard in this environment. The owner looks and listens during the phone test.

## 10. Tuning
Every number here (intensities, volumes, pitches, colours, lifetimes) is a starting point. The owner tunes by ear and eye on the phone. The logic classes keep these numbers in named constants.

## 11. Out of scope for Part B
- camera shake, tyre tracks and mud splatter decals (parent spec §8 "later polish")
- recorded sounds, music, UI sounds
- snow, ice and water effects (their surfaces don't exist yet)
- engine sound per car beyond what the rpm curves already give

## 12. Done when
- Mud, dirt and asphalt each show their spray, and every sound in §5 plays, driven by the car.
- The Sound setting works, is saved, and silences the game at Off.
- All unit and scenario tests pass, including the unchanged physics numbers.
- The draw-call and load-time budgets in §8 hold on the desktop.
- The branch is ready for the owner's phone test; it is not merged.
