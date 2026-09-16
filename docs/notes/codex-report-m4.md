# Codex report — Milestone 4, Frozen Pass

2026-09-16. Implemented on **`m4-frozen-pass`**, from master at **`947a17d`**.
Master was not changed or merged. Ready for the owner's PC playtest; phone
acceptance is deliberately deferred at the owner's request.

**Subsequent PC-playtest change:** the owner separately approved a traction-control
strength slider and its drivetrain edit. See [traction-tuning.md](traction-tuning.md)
for that additional scope, behaviour, tests and per-car tyre-tuning locations.
The original M4 implementation report below describes the pre-slider handoff.

## What was built

### Approved surfaces and feedback

- `surfaces/mud.tres`: grip only, 0.5 → 0.6.
- `levels/muddy_valley/soft_mud.tres`: grip only, 0.6 → 0.7.
- `surfaces/snow.tres`, `ice.tres`, `logs.tres`: exactly the approved grip,
  resistance, drag and sink values.
- `surfaces/grip_table.tres`: the six approved rally/off-road winter/log entries.
- `effects/surface_feel.gd`: appended SNOW rolling category and a default-1 skid
  volume multiplier, preserving the existing categories.
- `effects/surface_feel_table.tres`: white snow dust/crunch, silent ice rolling
  with half-volume skid squeal, gravel-like log rolling without spray.
- `effects/tyre_sound_logic.gd`: snow output and per-surface skid volume.
- `effects/sound_synth.gd`: band-passed, gently pulsing crunchy snow loop, using
  the existing loop-tail padding path.
- `effects/car_audio.gd`: snow loop player and mixing; stop it with the other
  players when the level exits.

Nothing under **`car/`** changed. Mud drag, rolling resistance and sink are
unchanged; existing star times and car unlock thresholds are untouched.

### Road and terrain infrastructure

- `levels/trail/terrain_def.gd`: configurable collision surface, default dirt.
- `levels/trail/trail_def.gd`: shoulder surface, material roughness, full-width
  rollers, tunnel/bridge arrays and opt-out from curve banking.
- `levels/trail/surface_stretch.gd`: roughness and `affects_shoulders`, default true
  to preserve Muddy Valley's anti-bypass verges. Frozen Pass keeps snow shoulders
  beside both ice and concrete stretches.
- `levels/trail/road_builder.gd`: main-thread sampling/snapshots, independent
  worker chunk tasks, ordered main-thread mesh/collider creation, original serial
  mode retained; material boundaries and bridge-span omission in both modes.
- `levels/trail/road_chunk_data.gd`: per-chunk value-array calculations without
  per-vertex shared sampler/profile calls; double-precision rut parameters keep
  the original serial floating-point results.
- `levels/trail/terrain_field.gd`: carve tasks partitioned by row bands, original
  stamp/accumulation order within each band, original serial mode retained;
  applies bridge offsets and structure earthworks.
- `levels/trail/terrain_builder.gd`: surface tags, portal collision holes and
  matching mesh holes; fine LOD retained for portal chunks to preserve seams.
- `levels/trail/road_profile.gd`: bridge step/recovery ramp, log surface lookup,
  material roughness lookup and symmetric full-width rollers.
- `levels/trail/road_sampler.gd`: optional world-up cross-section. This is used
  only on Frozen Pass; other tracks keep the previous curve orientation.
- `levels/trail/trail_level.gd`: assembles/times tunnels and bridges and passes
  the banking setting into the sampler.

### Tunnel and broken bridge

- `levels/trail/tunnel_def.gd`: the specified tunnel dimensions, cover, portal
  length, lamp spacing, colours and seed.
- `levels/trail/tunnel_builder.gd`: curved rock arch with collidable shell,
  complete portal faces, retaining sides, precisely clipped snowy bank/roof caps
  and one unshaded ceiling-lamp MultiMesh. No dynamic per-lamp lights.
- `levels/trail/bridge_def.gd`: span, drop, ramp, gorge width/depth, log dimensions
  and seed; shared containment/height helpers.
- `levels/trail/bridge_builder.gd`: transverse varied cylinders in one MultiMesh,
  individual tagged log collision, merged supports and partly broken side rails,
  glossy ice floor with its own tagged collision over the snowy terrain.
- `levels/trail/trail_earthworks.gd`: raised tunnel ridge, bounded portal cuts and
  6 m gorge excavation. Nearest-stamp projection prevents a portal hole from
  accidentally extending by the neighbourhood search radius.
- `levels/trail/structure_mesh.gd`: reusable merged flat-shaded structure mesh and
  optional concave collision.

The 30 m bridge starts at 835 m, steps down 0.7 m at its midpoint and rejoins the
road over 20 m. The tunnel runs 1150–1400 m, is 11 m wide and 6 m high, has at
least 8 m cover, and bends enough to hide its exit. The existing chase-camera
obstacle ray keeps the camera below the ceiling; no camera code change was
needed. The gorge has no new automatic reset trigger.

### The level and Test Ground

- `tools/generate_frozen_pass_curve.gd`: reproducible straight/arc segment list;
  zero-cross-slope snow valley, two climbing hairpins, bridge, upper climb,
  summit S-tunnel and twisting descent. Existing separation validation passes.
- `levels/frozen_pass/frozen_pass_curve.tres`: generated curve, approximately
  2174 m including the 70 m finish run-off.
- `levels/frozen_pass/frozen_pass_trail.tres`: 9 m packed snow road with 2.5 m
  lighter snowy shoulders; six glossy ice stretches, dry asphalt/concrete tunnel
  floor, 0.12 m undulations and six full-width rollers. Checkpoints at 450, 900,
  1420 and 1750 m. No banking, potholes or ruts.
- `levels/frozen_pass/frozen_pass_terrain.tres`: snow collision, white/grey terrain
  palette and level-specific view/detail distances.
- `levels/frozen_pass/frozen_pass_scatter.tres`: pale pines, grey rocks and posts,
  orange reflectors, no broadleaf trees.
- `levels/frozen_pass/frozen_pass_level.tres`: third-level identity and approved
  placeholder star times 135/120 s.
- `levels/frozen_pass/frozen_pass.tscn`: normal run/tracker/reset/HUD/rig wiring,
  cold morning sky/sun/haze, wind 0.45 and no birds.
- `levels/trail/scatter_def.gd`, `scatter_builder.gd`: optional altitude thinning
  for pines; normal roadside posts excluded from tunnel/bridge spans. Existing
  levels keep their previous defaults and random-number sequence.
- `levels/catalog.tres`: third entry, unlocked by finishing Muddy Valley.
- `levels/test_ground/test_ground.gd`: signed 14 × 300 m snow and ice lanes at
  x = 45 and 60; rough asphalt moved to x = 105. Dense rough-ground strips receive
  shadows but no longer duplicate themselves in the shadow pass; collision and
  closed side walls are unchanged.
- `debug/load_benchmark.gd`: all three levels, three rounds.
- `tools/level_shots.gd`: also supports Test Ground lane-X captures and waits out
  the countdown on run levels.

New script `.uid` files accompany their scripts.

## Tests and measurements

- Added `tests/unit/test_winter_surfaces.gd`, `test_tunnel.gd`, `test_bridge.gd`
  and `test_frozen_pass.gd`: surface values/multipliers, structure dimensions,
  cover, bounded holes, closed portal banks, hidden tunnel exit, collision tags,
  bridge step/ramp, missing road span, unbanked full-width geometry and glossy ice.
- Extended `test_road_builder.gd`, `test_terrain_field.gd` and
  `test_terrain_builder.gd`: serial/threaded equality and configurable collision.
- Extended `test_surface_feels.gd`, `test_sound_synth.gd`, `test_car_feedback.gd`:
  winter feedback, loop padding and the extra sound player.
- Extended `test_curve_generator.gd`, `test_level_catalog.gd`, `test_menus.gd`,
  `test_trail_level.gd`: generated curve, third-level unlock, nine total stars,
  and structure assembly.
- Added `tests/scenarios/test_frozen_pass.gd`: every car finishes with zero
  resets, crosses the bridge upright, clears the tunnel walls and ceiling,
  brakes in asphalt/snow/ice order on real strips, and waits for manual reset
  after falling into the gorge.
- `tests/scenarios/test_muddy_valley.gd`: stock uses the existing surface-aware
  driver, as tuned/4x4 already do. The old blind driver hit the final hedge after
  the approved grip increase. No numeric test limits were widened. A failed
  finish now reports assertions without then trying to index a nonexistent save.

Final gates: **418/418 unit tests pass**; **479 passing + 1 pre-existing pending**
in `./run_tests.sh all` (480 tests, 69 scripts, 27,721 assertions, 155.79 s).
The all-suite exit code is 0 and its log contains **no `SCRIPT ERROR`**.
The 62 scenario tests are included in that total (61 pass, one pending).
Detailed timings, braking distances, screenshot locations and commands are in
[`performance-m4.md`](performance-m4.md).

Measured Frozen Pass build: **0.56–0.57 s** desktop; sampled render peak:
**201,003 primitives / 133 draw calls** (maxima occur at different spots).
Test Ground new-lane view: **240,660 primitives / 92 draw calls**.

## Implementation choices and departures

1. **Phone work deferred**, explicitly requested by the owner. No APK installation,
   phone timings, phone audio/FPS verification or star calibration is claimed.
2. **Explicitly unbanked sampling:** zero curve tilt alone still accumulates roll
   through Godot's transported curve up vectors. The first build stranded the
   two rally cars on the icy climb. Frozen Pass now opts out of that transport;
   this implements the spec's no-banking requirement, without altering old roads.
3. **Portal representation:** the field retains one height grid and full roof
   cover, but local heightmap triangles are masked at the portal approaches and
   replaced by clipped cap/retaining geometry. Otherwise the sloping heightmap
   would close the driving opening. This is a localized implementation extension
   to the spec's heightmap description, not a general cave/voxel system.
4. **Snow shoulders stay snow** even alongside ice and inside the tunnel, following
   the owner's clarification. They use a lighter tint than the packed road.
5. **Glossy material and roller support** were added as approved. The gorge floor
   uses a thin collidable ice mesh above the snowy height field; integrated ray
   and fall/reset tests verify it, not just a visual overlay.
6. **Test Ground shadow draw reduction** was needed after measuring the new view
   over the primitive limit. It changes only rendering of the dense rough lanes.

## Remaining acceptance and known issues

- Owner PC playtest, then connected-phone load/60 fps/audio/feel checks and real
  star times. The cautious scripted times (218.22/201.01/191.74 s) are not human
  target times; the approved placeholders remain unchanged.
- The already-known held-gas jump nose-dive remains the suite's one pending test.
  Fixing it would require separately approved car-physics work.
- Godot's known ObjectDB audio shutdown warnings still occur in some sound-playing
  headless/capture processes. Players are explicitly stopped and the suite exits;
  no script errors or phone-safety padding removal is accepted.
- Render figures are sampled views, not a guarantee of all-frame phone performance.

For immediate PC testing, open
`levels/frozen_pass/frozen_pass.tscn` and run the current scene (F6), or select
Frozen Pass normally after finishing Muddy Valley. Snow and ice lanes are in
Free Drive. The owner's `project.godot` formatting changes and untracked
`tmux-session.sh` are preserved and excluded from commits. No merge or push.
