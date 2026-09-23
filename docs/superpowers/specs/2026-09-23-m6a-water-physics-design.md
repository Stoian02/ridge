# Ridge Milestone 6A — Water Physics: Design Spec

**Date:** 2026-09-23

**Status:** Draft for the owner's written review; not an implementation approval.

**Builds on:** `master` at `a3dbee4`, after the reviewed build-speed refactor and AWD tuning.

**Branch:** `m6a-water-physics`. No merge or push.

**Handover:** `docs/notes/handover-codex-2026-09-23-m6.md`.

**Parent:** `docs/superpowers/specs/2026-09-11-ridge-design.md`; supersedes the visual-only-water restriction in Milestone 5, not its accepted level geometry.

The behaviour decisions in §2 were approved in conversation. **The exact numbers,
data layout and integration details below are proposed starting values for this
review.** They are not measured results or real-world wading ratings. Approval of
this written spec authorizes planning these water-specific changes; existing car
tuning and surface values remain protected. Later tuning changes need the owner's
approval and must be recorded, not hidden by weakening tests.

**Owner review guide:** §2 records the agreed choices; §3 describes play; §6
contains the proposed car limits/timers; §9 shows the test area; §10 covers its
look, sound and warnings. The other sections constrain implementation and checks.

## 1. Summary

Give all reachable water one consistent vehicle interaction: progressive drag,
buoyancy, steady currents, recoverable engine stalls and gradual sinking after
sustained deep immersion. Add readable translucent water, splashes, sound and
small status warnings. Prove it first on a three-area Test Ground course, then
on Rock Canyon's ford and rut puddles and Muddy Valley's creek.

Water is a layer over the existing solid bed, **not a new tyre-contact surface**.
The wheels still touch rock, mud, dirt or asphalt underneath it. The water itself
has no solid collision. On dry ground the original force path must be unchanged.

This is a bounded game model, not a fluid simulation. No waves, tides,
aquaplaning, speed-generated skimming lift, floating debris or permanent damage.
Do not design or build Coastal Highway here. Stop after Part A for Claude's
review, the owner's phone playtest and any corrections. Part B starts only after
the owner authorizes merging A, from that merged master on its own branch.

## 2. Approved decisions

| Subject | Decision |
| --- | --- |
| Depth | Shallow driveable crossings and genuinely deep, hazardous water |
| Resistance | Smoothly stronger with immersion and water-relative speed; no artificial speed cap |
| Grip | Retain the underlying surface; buoyancy unloads the tyres, without a blanket grip multiplier |
| Engine | Stall only after sustained intake submersion; restart after the intake clears for a short delay |
| Failure/recovery | No water-triggered automatic reset or failure screen; the player can press Reset |
| Buoyancy | Temporary flotation, followed by progressive flooding and sinking |
| Propulsion afloat | Momentum and current, not boat-like thrust from spinning tyres |
| Current | Calm water plus optional, authored steady currents |
| Scope | Test Ground, Rock Canyon's ford **and rut puddles**, and Muddy Valley's creek |
| Appearance | Translucent shallows, darker/less transparent deep water; readable bottom and shoreline |
| Colour | Clear blue-green test pools; cloudier river water, with the shallow bed still readable |
| Feedback | Depth/speed-dependent splashes and sound, engine-state audio, small HUD warnings |
| Test course | Shallow lane, gradual calm depth pool, comparable sideways-current crossing |
| 4×4 snorkel | Reserve a higher intake point; the visible snorkel is a later styling task and must match that point |
| Aquaplaning and skimming | Optional future experiments, dependent on cost and value; neither is promised or implemented in A |
| Milestone boundary | Review and phone acceptance of A before any Coastal Highway design or implementation |

## 3. Driving and recovery contract

- A small puddle makes a splash and adds modest resistance. Entering it must not
  snap the car's speed or steering to a preset value.
- Deeper/faster entries produce greater resistance. As the body enters, buoyancy
  changes suspension loading and therefore the available tyre force. Slow,
  deliberate wading remains useful.
- A floating car can coast, yaw and drift. It gets neither thrust from freely
  spinning wheels nor the existing airborne pitch/roll assist. More horizontal
  speed does **not** provide extra upward lift.
- Prolonged deep immersion reduces buoyancy. A high snorkel can keep the engine
  running while the tyres have no purchase; it does not prevent sinking.
- Intake clearance is measured at an oriented point on the actual car, not from
  a level-wide depth threshold. Pitch, roll and suspension height matter.
- Clearing the intake can restart the engine even before all flooding has
  drained. Regaining the bed restores ordinary wheel contact. No persistent
  engine damage, save penalty or repair menu is introduced.
- Reset clears flooding, intake timers, stall/restart state, force/effect history
  and water warnings. It keeps the existing destination and clock rules: spawn
  in Free Drive, checkpoint on a timed run; elapsed run time is not refunded.
- **Existing flipped/off-map safety resets are unchanged.** No new reset is
  triggered by depth, a stall or sinking. Free Drive retains its existing manual
  reset behaviour. Do not change `ResetController`'s safety thresholds.

## 4. Data and ownership

Use typed, tab-indented GDScript and the repository's data-plus-builder pattern.
The names below describe proposed responsibilities, not new global autoloads.

| Component | Responsibility |
| --- | --- |
| `water/water_body_def.gd` (`WaterBodyDef`) | Stable ID, current, appearance, sampling defaults; zero current by default |
| `water/water_body.gd` (`WaterBody`) | One bounded body's immutable top triangles and solid-bed sampling data, with its world transform |
| `water/water_world.gd` (`WaterWorld`) | Level-owned spatial index and reusable query results; no physics bodies for water |
| `water/vehicle_water_profile.gd` (`VehicleWaterProfile`) | Water-only car parameters and intake point; shared read-only resource |
| `water/vehicle_water_state.gd` (`VehicleWaterState`) | Per-car immersion, flooding, timers and engine state; never stored in a shared resource |
| `water/water_forces.gd` (`WaterForces`) | Testable immersion/force calculations and stability limits |
| `water/vehicle_water_controller.gd` (`VehicleWaterController`) | Explicitly stepped by `Car`, before/after the existing wheel work as specified in §7 |
| `levels/test_ground/water_course.gd` (`WaterCourse`) | New basins, static beds, ramps, depth marks and water registrations |
| `effects/water_effects.gd` | Bounded body-entry/wake feedback; reuses wheel spray where possible |
| `ui/water_status.gd` | Small shared warning overlay on `DrivingRig`, so Free Drive also gets it |

Add an optional `CarStats.water_profile` reference, default `null`. Wire new
`water/profiles/rally_water.tres` into both rally stats resources and
`water/profiles/offroad_water.tres` into the 4×4. This adds water configuration;
do not edit any existing mass, inertia, suspension, torque, gearing, differential,
assist or tyre value. A car with a null profile or no water world follows the
old dry path. Water tests use explicitly configured cars, not an accidental null
profile that silently disables the feature.

`TrailLevel` owns its `WaterWorld`; `RunLevel` binds it to its rig before placing
the car. The Test Ground binds its world after building the new course. Tests
can inject a small world directly. Scene exit and builder rebuild unregister all
bodies; no stale global group lookup, registry or query cache survives reload.

Do not add project settings, collision layers, physics-threading changes or an
autoload. Do not touch the owner's `project.godot` or `tmux-session.sh`.

## 5. Water geometry, depth and current queries

### 5.1 A bounded water volume, not an infinite height plane

- Start from the **actual drawn triangles**: the ford ribbon, each connected
  creek strip, each laid rut-puddle piece, and the new pool surfaces. Preserve
  gaps; two disconnected puddles never create water between them.
- Query X/Z inside the triangle footprint, interpolating its surface Y. This
  matters for the creek: its existing ribbon can change elevation along its
  length. Do not replace it with one flat plane or round to a road station.
- Use solid-bed data matching the road/terrain collision triangles beneath the
  water. In particular, terrain rendering uses triangle interpolation; do not
  substitute a bilinear height or the nominal ford depth where a road is higher.
  Index only relevant static road/terrain/course triangles or their equivalent
  exact samplers, not copies of the entire level's mesh data.
- A point where solid ground reaches or exceeds the surface is dry. Clip probe
  immersion against the bed as well as the surface; a ribbon extending under a
  bank must not create invisible water through that bank or below its floor.
- New water must not appear on dry land, on top of rocks, across unlaid rut gaps,
  or on a bridge deck merely because a broad-phase bound contains the car.
- Rigid translation and rotation of a level are supported. Validate/reject
  unsupported non-uniform scale rather than returning mismatched water heights.

Suggested broad phase: **16 m X/Z grid cells**, with immutable triangle IDs in
each cell and cached nearby candidates per car. Query only nearby bodies. Select
one containing volume per sample: the highest valid surface, then the stable
body ID for equal-height ties. Never sum duplicate water forces at seams or
overlaps. Bodies need finite lower bounds; an off-map car must not remain wet
because it shares the river's X/Z coordinates.

Use preallocated samples for eight body probes, four wheels and the intake
(13 principal queries per physics tick), with a dry broad-phase early-out.
Probe/bed boundary clipping may need additional local samples; count and profile
them. Do not add a separate physics collider or `Area3D` for every puddle/triangle,
or scan all level nodes or terrain cells each frame.

### 5.2 Proposed water-body defaults and shipped integrations

| Parameter | Initial value |
| --- | --- |
| `current_velocity` | `Vector3.ZERO`, metres/second in the body's local horizontal frame |
| `shore_probe_blend` | 0.10 m inward-only footprint weighting for finite body probes; never expands the footprint |
| `depth_epsilon` | 0.002 m; no water force below this available depth |
| `appearance` | Explicit palette from §10, separate from ground `SurfaceDef` |

| Place | Geometry retained | Proposed steady current |
| --- | --- | --- |
| Rock Canyon ford | Existing 1290 m crossing, 0.30 m nominal water depth; original road dip, bank, waterfall and ribbon positions | **0.50 m/s**, from waterfall toward `river_reach`, horizontally across the road |
| Rock Canyon rut puddles | Existing seeded pools and gaps, configured fill up to **0.09 m**; use each actual clipped depth | **0 m/s** |
| Muddy Valley creek | Existing **745–895 m** reach, 17 m lateral offset, variable drawn water height; the 0.70 m channel cut is not the actual water depth | **0.35 m/s**, following the ribbon toward its lower end, with a consistent horizontal tangent per segment |
| Test Ground shallow/calm areas | New geometry in §9 | **0 m/s** |
| Test Ground current pool | Same new bed/depth profile as the calm pool | **0.75 m/s** across the lane toward +X |

Add explicit water settings to the respective defs (`FordDef`, creek settings on
`TrailDef`, water-bearing `SurfaceStretch`) rather than hard-coding scene names
in the car. Derive query footprints from builder output without changing seeds,
sampling intervals or mesh positions. A rebuilding builder replaces, rather
than appends, its water entries.

Only liquid volumes affect the car. The waterfall sheet and airborne mist remain
visual/audio effects, not vertical walls of buoyancy or high-force jets. Frozen
Pass's ice remains solid ice; this does not introduce melting or water below it.
Existing scenery objects and loose stones do not gain flotation or water forces.

## 6. Vehicle parameters — proposed for approval

### 6.1 Intake positions and water force coefficients

Coordinates are metres relative to the car body origin: +X right, +Y up,
forward −Z. An intake's world position is recomputed from the car transform.

| Parameter | Rally Car / Rally Car Tuned | Off-road 4×4 |
| --- | --- | --- |
| `intake_local_position` | `(0.45, 0.15, -1.50)` | `(0.95, 1.10, -0.90)` |
| Approximate intake height above flat dry ground | **0.61 / 0.63 m** | **1.72 m** |
| `body_linear_drag` (side/up/forward), N per m/s at full immersion | `(50, 80, 40)` | `(65, 105, 55)` |
| `body_quadratic_drag` (side/up/forward), N per (m/s)² at full immersion | `(350, 500, 220)` | `(450, 650, 300)` |
| `wheel_quadratic_drag`, N per (m/s)² per fully immersed wheel | **8** | **10** |
| `fresh_buoyancy_ratio` | **1.15** | **1.15** |
| `flooded_buoyancy_ratio` | **0.35** | **0.35** |

The ground-relative intake estimates use the current `wheel_rest_height()` and
wheel radius. They are explanatory numbers, **not hard-coded wading limits**:
suspension loading, attitude, loss of bed contact and flooding can stop the car
earlier. The 4×4's point is just above its current roof at the right-front cabin
corner, reserved for a later snorkel. Do not add the visual snorkel in A; show its
location in debug view so the higher intake is inspectable before the art exists.

### 6.2 Immersion and buoyancy approximation

Use eight equal-weight spherical body probes: two at each of four plan-view
corners. With body size `(W, H, L)`, their centres are the combinations:

`x = ±0.35W`, `z = ±0.32L`, `y = -0.20H or +0.40H`; radius `r = 0.30H`.

Each has an assigned share of the total effective buoyancy capacity; the small
probe spheres are sampling shapes, **not a claim about the car's real displaced
volume**. For a plane above an unclipped sphere, use the continuous cap fraction
`h²(3r-h)/(4r³)`, with `h = clamp(surface_y - centre_y + r, 0, 2r)`.
Subtract the cap below the bed and account for the bounded horizontal footprint;
clamp the final submerged fraction to [0, 1]. The approximation must stay finite
when rolled, pitched or inverted, and must not push through a dry bank.

Let `flooding` be [0, 1]. Each probe's upward force is:

`mass × gravity × lerp(1.15, 0.35, flooding) × submerged_fraction / 8`.

Apply at the probe position, respecting the rigid body's centre-of-mass offset.
Gravity remains the project's gravity. Do not change vehicle mass/inertia as it
floods: reducing effective buoyancy represents flooding in this bounded model.
There is no buoyancy hard switch on contact loss and no scripted hover period.

This gives a fresh, fully immersed car positive net buoyancy and a flooded car
negative net buoyancy. Actual time afloat depends on entry, attitude, drag and
depth; the timers below are not a guarantee of an exact number of seconds afloat.

Wheel immersion is measured at the **current wheel centre**, including suspension
extension, not the suspension mount. Use the tyre's vertical extent for its wet
fraction. Wheel spin affects spray, not translational thrust in water. Tyre
buoyancy is included in the body approximation, not added a second time.

### 6.3 Stall, flooding and recovery settings (all cars)

| Parameter | Starting value and meaning |
| --- | --- |
| `stall_submerged_seconds` | **0.60 s** of continuous intake submersion |
| `restart_clearance` | Intake at least **0.05 m** above water, or outside every volume |
| `restart_clear_seconds` | **1.00 s** continuously clear before restart |
| `restart_torque_ramp_seconds` | **0.50 s** to restore requested engine torque smoothly |
| `intake_warning_clearance` | **0.12 m** above the local surface |
| `deep_immersion_threshold` | Mean body-probe immersion **0.65** |
| `flood_grace_seconds` | **3.00 s** accumulated deep immersion before flooding starts |
| `flood_fill_seconds` | **8.00 s** additional deep immersion to go from empty to fully flooded |
| `body_dry_threshold` | Mean body immersion at most **0.02** |
| `drain_clear_seconds` | **1.00 s** continuously body-dry before draining/grace reset |
| `flood_drain_seconds` | **12.00 s** body-dry to drain a fully flooded car |

Before stalling, any dry intake sample breaks continuous intake exposure. After
stalling, the 5 cm restart clearance is the hysteresis band: less clearance resets
the restart timer. Splash particles never count as intake submersion. The ramp
does not override throttle release, TC, the rev limiter, a gear shift or another
stall; it only limits available engine torque during that first half-second.

Deep exposure accumulates only at/above 0.65 mean immersion and otherwise pauses;
it resets after the body-dry clear delay. Once the grace is spent, flooding rises
at 1/8 per deep-immersion second, pauses in shallower water, and drains at 1/12
per dry second after the clear delay. Briefly bobbing up does not empty the car.
Intake state and flooding are independent; a snorkel does not delay flooding.

Pause freezes all timers. Reset/restart/car replacement fully clears them. None
of this state is saved between runs or modifies `CarStats` resources at runtime.

## 7. Car integration and stability

1. After input refresh, sample current body/intake immersion and advance the
   water state. Update contacts as before; obtain wheel immersion using this
   tick's suspension state. Apply water forces once, not from both the car and
   an independently processing water node.
2. Preserve the old drivetrain path exactly when not stalled/restarting. In the
   water-stalled branch, disengage engine drive and engine braking, report zero
   engine RPM and pause automatic shifting. Keep the selected gear. Steering
   remains available and the brake input operates the service brakes even at
   low speed/in reverse; it must not disappear into the current brake-to-reverse
   selection logic. Mechanical differential coupling remains, without an engine
   torque source. Normal direction selection resumes after restart.
3. Leave suspension, tyre friction/load calculation and movable-support reaction
   forces intact. Buoyancy lifts the body and lets the springs unload naturally;
   do not also subtract buoyancy from each tyre load or scale friction globally.
4. Evaluate drag against **point velocity minus local current**, including the
   body's angular velocity about its centre of mass. Distribute body drag by
   the eight probe wet fractions and wheel drag by four wheel wet fractions.
   Body coefficients above describe the total fully immersed body, not each
   probe. Keep bed rolling resistance; water drag is an additional term.
5. Resolve drag along horizontal car-forward, horizontal sideways and world-up
   axes (with a deterministic fallback when the car is vertical). Per axis use
   `-linear_coefficient × v - quadratic_coefficient × abs(v) × v`, weighted by
   immersion. Wheel drag opposes water-relative horizontal translation. Do not
   turn forward velocity into upward force by using a tilted body axis: that
   would accidentally introduce the deferred skimming mechanic.
6. Bound damping impulses against translational and rotational effective mass
   and the physics step. Multiple probe contributions must be stable together,
   not merely clamped independently. No one-tick velocity reversal or artificial
   energy gain in still-water drag tests; never directly set the car velocity to
   the current. Current transfers energy through drag, with no extra constant
   shove layered on top.
7. If any body probe has immersion above **0.01**, reset/suppress `AirControl`.
   When the body leaves water, normal airborne-grace counting begins again.
   Touching a puddle with only the tyres does not disable genuine jump controls.
   Airborne telemetry must distinguish floating from active air control.

No force code may modify the water surface or run expensive terrain generation.
The ordinary zero-water path must avoid new calculations in the protected wheel
maths. Unit tests cover pure maths; actual driving/float tests prove integration.

## 8. Existing levels and geometry safeguards

- **Ford:** keep its 0.30 m nominal depth and all bed/bank geometry. The 4×4 must
  still cross under normal controlled driving without a water stall or a launch.
  Do not deepen it to showcase sinking; that is the Test Ground's job.
- **Ruts:** preserve the existing seed, water rows, gaps, colours/vertex data and
  collision. Add the common water query/feedback, not another mud slowdown or
  a forced minimum depth. Recheck the deep-mud climb for accidental double drag.
- **Creek:** preserve the channel and ribbon positions. Make the material
  translucent and register its actual connected water pieces. Test driving off
  the road into it, staying on the bank, and returning out where the existing
  geometry permits. Do not reshape the banks to ensure recovery.
- **Other levels and dry routes:** no generated geometry changes. Do not touch
  Rock Canyon's CP4–CP5 banking, gradient, line, loose-stone count/settings or
  activation window. No changes to existing `surfaces/*.tres` or grip-table values.
- Keep `test_geometry_fingerprints.gd`, `test_build_details.gd` and
  `test_car_balance.gd` assertions/fixtures unchanged. Add separate baseline
  assertions for water vertex/index arrays before modifying the adapters.

Water is expected to change times in the affected sections. Keep the current
authored star times; do not revert to values from old conversations or invent
new targets. The owner decides any timing adjustment from new runs. Coastal
Highway has no star targets in this spec.

## 9. Test Ground course

### 9.1 Placement and construction

The existing ground is a solid 600 × 600 m slab. **Do not excavate it or move the
runway, skidpad, spawn, slopes, logs or loose rocks.** Build closed raised basins
on the unused positive-Z ground, behind/right of spawn. The old courses mostly
extend toward negative Z; the skidpad stays at `(0, 0, 70)`.

| Area | Centre X | Width | Start Z | Along direction | Total length |
| --- | ---: | ---: | ---: | --- | ---: |
| Shallow lane | 60 m | 8 m | 30 m | +Z | 100 m |
| Calm depth pool | 105 m | 32 m including side exit banks | 30 m | +Z | 192 m |
| Current pool | 155 m | 32 m including side exit banks | 30 m | +Z | 192 m |

Floors sit no lower than **Y = 0.02 m**, above the unchanged slab. All new
driveable surfaces use existing asphalt for a consistent bed comparison. Static
collision must match the visible ramps/floors and close the outside faces of
the raised ground. Batch drawing and collision per course section, not per tile.
Allow dry approach/turning space; add a direction sign near spawn and signs at
the three entrances. Normal Reset still returns to the original spawn.

### 9.2 Shallow-water lane

Water height **Y = 0.37 m**. Four independent 12 m bays start at local distances
20, 40, 60 and 80 m. Each has a 3 m entry ramp, 6 m constant-depth bed and 3 m
exit ramp. Their plateau depths are **0.05, 0.15, 0.30 and 0.35 m**. Water stops
at each bay's dry lips; no hidden connection across the gaps. Dry connecting
deck is Y = 0.37 m, with 8 m approach/exit ramps at the lane ends.

Mark depth on the bank rather than floating text over the driving line. These
are comparison bays, not a promise that every car stays grounded at every speed.

### 9.3 Calm and current pools

Identical solid geometry, water height **Y = 2.82 m**, maximum depth **2.80 m**.
The following points define the longitudinal centre-line bed profile. Ease slope
changes over **2 m** while retaining those floor/depth plateaus and matching
collision; no sharp lip intended to launch a car.

| Distance from entrance | Bed Y | Purpose |
| ---: | ---: | --- |
| 0 m | 0.02 m | Ground-level dry approach |
| 24 m | 2.92 m | Dry rim |
| 28 m | 2.82 m | Water entry |
| 84 m | 0.02 m | End of gentle descent; deepest bed |
| 108 m | 0.02 m | End of deep plateau |
| 164 m | 2.82 m | Far water exit |
| 168 m | 2.92 m | Far dry rim |
| 192 m | 0.02 m | Return to ground level |

At each station the central **12 m** is flat across; **10 m side banks** on both
sides rise from the bed to the dry rim. They offer a shallower escape route as
the current pushes sideways; they are not a guarantee of rescue once floating.
Keep the calm/current bed shapes identical. Water is clipped to the bed/rim
intersection, with no surface drawn outside the containing basin.

Use merged depth ticks every **0.25 m**, with nearby text at 0.25, 0.5, 1.0,
1.5, 2.0, 2.5 and 2.8 m on one entry bank. Show a fixed flow-direction arrow on
the current pool. No live current/depth sliders or extra control scheme in A.

The telemetry toggle exposes immersion, wheel wetness, intake clearance, local
current, water-relative speed, buoyancy/weight ratio, flood fraction and timers.
An optional debug intake marker shows the reserved snorkel point. Neither marker
nor numerical water gauges appear in the ordinary HUD.

## 10. Look and feedback

### 10.1 Materials and shoreline

Use `StandardMaterial3D`, vertex colours and modest UV animation, consistent
with existing builders. No screen-depth/refraction shader, planar reflections,
new post-processing pipeline or physical surface displacement is required.

| Water | Proposed colour/opacity |
| --- | --- |
| Test pool shallows | RGB `(0.28, 0.55, 0.58)`, alpha **0.30** |
| Test pool deep centre | RGB `(0.08, 0.20, 0.25)`, alpha **0.85** |
| Ford | Existing RGB `(0.36, 0.50, 0.55)`, material alpha **0.50** instead of 0.75 |
| Creek | Existing RGB `(0.30, 0.40, 0.42)`, alpha **0.55**, explicitly alpha-transparent |
| Rut puddles | Keep existing brown vertex colours and fades; material alpha **0.80** multiplying the existing vertex alpha |

For new pool meshes, blend shallow to deep colour/opacity with
`smoothstep(0.20, 2.00, depth)`, sampling the new bed on at most a **1 m** visual
grid. Fade the final 0.05 m of depth toward the shoreline. Existing river/rut
mesh vertex and index arrays remain unchanged; use their shallow-water materials
instead of retessellating them to get this new-pool gradient. The short fade is
a rendering transition, not an expanded physical-water boundary.

Roughness **0.18**, metallic **0**, specular **0.65**, no water shadows, visible
from both sides. A low-contrast seamless surface pattern moves with current;
still pools may have subtle UV motion, never physical waves. Cull/chunk drawing
without disabling nearby physical queries. Avoid stacked transparent sheets.

Inspect the bed, submerged tyres, banks and water surface from driving-camera
angles on desktop and phone. Keep the chase camera's existing collision behaviour;
no new underwater camera mode or full-screen tint is added. Check the underside
view during sinking for disappearing/reversed water and sorting artefacts.

### 10.2 Spray, wake and sound

- Reuse the four wheel emitters where possible. Interpolate between the ordinary
  surface spray and water spray according to wheel immersion. Submerged wheels
  do not emit full-strength dry dust/smoke and full-strength splash together.
  Keep a muted underlying rolling sound where a wet tyre is still on the bed.
- Place surface splashes at the sampled waterline, not the buried tyre-contact
  point. Fade wheel splash emission out when the tyre's upper extent is more
  than **0.30 m** below that line; deeply submerged wheels must not throw jets
  through several metres of water. Water-wash sound may continue below it.
- Drive water intensity from depth, water-relative translation and bounded wheel
  slip. A fully submerged wheel may churn water visually but cannot make thrust.
- Add one bounded body-entry/wake emitter, maximum **32 particles**, lifetime
  **0.50 s**, active only near the surface. No rigid-body droplets or persistent
  wake meshes. Initial body-entry splash threshold: downward water-relative
  speed **1.0 m/s**; retrigger cooldown **0.40 s**. Movement wake starts at
  **0.50 m/s** water-relative horizontal speed and fades as the body sinks below
  the surface. Reuse the existing wheel-particle caps rather than doubling them.
- Add synthesized `water_wash` loop and `water_entry` one-shot. Initial maximum
  mix volumes: **0.35** and **0.50** linear, respectively, under the existing
  sound-volume control. Keep the waterfall's positional loop.
- Engine audio fades to silence on stall and returns with actual restart/RPM;
  it must not rev from throttle while the engine is disabled. No new starter
  button or elaborate failure sound set.
- Every loop uses `SoundSynth.LOOP_PAD`. Stop players and emitters on reset and
  scene exit, honour pause, and avoid clicks/duplicate entry splashes on teleport.

### 10.3 Small HUD warnings

One non-interactive label below the top controls, clear of the timer, split text,
telemetry and pedals. It exists on the rig in both timed levels and Free Drive.
Highest-priority applicable message wins:

1. **Sinking — Reset available:** mean body immersion is at least 0.65 and
   flooding has reduced maximum buoyancy below weight (with **0.05** flood-fraction
   hysteresis to avoid flicker).
2. **Engine stalled:** engine disabled and intake not yet clearing for restart.
3. **Restarting…:** the clear-intake countdown is in progress.
4. **Intake at risk:** a nearby water surface is within 0.12 m below the intake,
   or the intake is submerged but the stall delay has not elapsed.

Use amber for risk/restart, red for stall/sinking; text makes meaning independent
of colour. Do not show a misleading sinking warning once the car is out of water.
Reset clears messages immediately. No automatic screen transition or obscuring
spray overlay. Numerical state stays in the existing telemetry toggle.

Append water fields to the run recorder without renaming/reordering its existing
columns. Tests/tools reading old recordings must continue to work. Record enough
state to distinguish real submersion, stall, lost contact and high water drag.

## 11. Performance and load budget

Project goals remain **60 fps**, **under 150 draw calls**, **under 300k rendered
primitives**, and **under 3 s level build** on the owner's Xiaomi 13. These must
be measured, not inferred from desktop timings or the small number of probes.

Proposed incremental limits for A:

- Water sampling, state and forces: **≤0.50 ms p95 per physics tick** on the
  phone during the new course; report maximum as well and separate from Jolt.
- New water setup: **≤0.10 s** added to each existing timed level, **≤0.25 s**
  added for the complete Test Ground course, comparing matched load rounds.
- Additional visible drawing: **≤12 draw calls excluding labels**, **≤10k
  primitives** for the whole new course/effects in a worst relevant view; labels
  count against the overall 150-call limit and need distance culling/batching.
- No added dynamic bodies, broad all-body buoyancy processing, per-tick mesh
  rebuilds, full-world physics scans or unbounded allocation/effect histories.

Rock Canyon's reviewed build is already about **3.9 s**, over the 3 s budget.
This spec does **not** claim water work fixes that or silently raise the budget.
Report the pre-existing miss separately from A's incremental cost. If strict
under-3-second acceptance is required before A can land, it remains a blocker
requiring an owner-approved separate build-speed task; do not sneak deferral or
geometry simplification into this part. Any acceptance with that baseline miss
must be explicit in the review, not described as meeting the load budget.

Measure all five levels for three rounds in the existing benchmark order, and
profile repeated water entry/reset/level exit. Check cleanup counts and audio
shutdown as well as FPS. Preserve the loose-stone activation window. No engine
threading changes, mass changes or terrain-detail reductions to make water fit.

## 12. Verification and acceptance

### 12.1 Before implementation

- Owner reviews this spec, particularly §6 numeric tuning and §9 raised basins.
  Only then write `docs/superpowers/plans/2026-09-23-m6a-water-physics.md`.
- Capture current geometry/water-array baselines and relevant run measurements
  before production changes. Existing protected fixtures are never re-recorded.
- Check for the owner's running game before every test/benchmark/capture. Never
  start a second Godot instance while they are playing, or kill their process.

### 12.2 Unit tests

- Exact footprint/surface agreement for ford, disconnected creek pieces and
  clipped ruts, including sloped creek triangles, dry banks, gaps, overlapping
  bounds, triangle seams, translations and rotations. Bed-above-water is dry;
  below-bed samples produce no unbounded water force.
- Deterministic overlap choice, body removal/rebuild, no stale per-car cache
  after teleport/reload; no collision body/shape masquerading as water.
- Probe wet fractions at dry/partial/full immersion and inverted attitudes;
  zero force when dry, correct fresh/flooded total buoyancy, no horizontal-speed
  lift term, and drag opposing relative motion. Still-water drag must dissipate
  energy, including combined probes and torque. Equal car/current translation
  has zero translational drag. Reverse/current signs and finite zero-speed math.
- Intake threshold and hysteresis boundaries, splash immunity, stalled brake
  operation in both gears, torque/RPM shutdown and bounded restart ramp. TC,
  shift and throttle release retain authority during restarting.
- Flood grace/fill/drain timing, brief bobbing, paused time, independent intake
  and flooding, water-only air-control suppression and unchanged dry grace.
- All configured cars load the intended water profile; no existing car/surface
  tuning value changes. Per-car state cannot leak through shared resources.
- Reset clears controller, HUD, spray/wake and sound histories; dry reset versus
  reset into a volume is sampled correctly next tick without stale forces.
- New course depths, closed side faces, matching collision, disjoint old-course
  footprints, unchanged spawn and identical calm/current bed geometry.
- Material transparency and bounds, status priority/hysteresis, telemetry and
  appended CSV compatibility, valid/padded audio loops and player shutdown.

### 12.3 Driving scenarios

Run each small water fixture with all three cars and explicit profiles. Use
deterministic inputs and log speed, wheel contact/load, intake clearance, force,
flooding, stall/restart timing and resets.

- Dry controls: identical no-water runs and unchanged car-balance suite.
- Shallow bays at **3, 8 and 15 m/s** entry: progressive resistance, greater
  loss at greater immersion under otherwise matched conditions, no instant
  engine cut from spray, no boundary launch or speed reversal. Compare each
  wet fixture with the identical dry bed, not two differently shaped ramps.
- Depth ramp: rally intake submerged before the reserved 4×4 intake for matched
  upright placement; measured world-point thresholds, not exact guessed road
  depths. A gentle existing ford crossing must not become a flotation jump.
- Deep pool: fresh buoyancy can remove wheel contact, no throttle/steer air
  torque or wheel-generated propulsion while afloat, flooding progresses and
  a fully flooded car sinks to the solid bed. No water-triggered automatic reset.
- Calm/current comparison: zero-input displacement follows the authored current
  and is more pronounced when ungrounded; reversing the current reverses the
  drift. A shallow grounded crossing remains steerable at controlled speed.
- Recovery: scripted intake-clear/re-submerge transitions and a shallow exit
  restore the engine correctly, drain progressively, and never restore water
  torque through a shared resource. Exercise manual Reset, run Restart, car
  change, pause/resume, scene exit/re-entry and reset underwater in test fixtures.
- Stability: fast entries, sideways entries and upside-down immersion at both
  **60 and 120 physics ticks/s**. No NaNs, energy-generating still-water damping,
  explosive angular velocity or phase-order-dependent one-tick engine burst.
- Real integrations: ford unit/driving tests, Rock Canyon full 4×4 run and deep
  mud/ruts, Muddy Valley normal road/shortcut run plus creek entry/bank checks,
  and the existing loose-shelf tests. Record time changes; do not weaken the
  protected geometry or balance assertions to accommodate them.

If a non-protected visual-water test specifically asserts the old opacity or
absence of water *data*, update only that now-obsolete contract and document why.
Water must still have no solid collision. A failed driving assertion is a finding
to investigate/report, not permission to widen tolerances automatically.

### 12.4 Owner and phone acceptance

- Screenshots: three course entries, depth markings, visible bed/wheels, ford
  banks, creek edges, rut gaps and warnings. Confirm transparency on the phone.
- Owner drives shallow/calm/current areas with all three cars, then the ford,
  mud ruts and creek. Confirm drag is progressive, depth readable, stall/restart
  understandable, and no submerged flight controls or unfair boundary kicks.
- Record phone FPS/draw/primitives/physics/build costs against §11. Check audio
  looping and repeated resets/loads. Desktop-only results cannot pass this gate.
- `./run_tests.sh all` passes with **no `SCRIPT ERROR`**, while the existing
  pending jump check is reported honestly. The handover's 654 passing/1 pending
  is a starting baseline, not a claim that tests ran for this documentation edit.
- Write `docs/notes/codex-report-m6a-water.md`: changes, approved tuning,
  before/after measurements, observed problems, unresolved limits and what was
  not verified. Commit by feature, stage named files only; never merge or push.
- Stop for Claude/owner review and corrections. Part B is not started until A
  is reviewed, accepted and merged with the owner's authorization.

## 13. Out of scope and future ideas

- Coastal Highway route, structures, catalog entry or implementation plan.
- Tyre aquaplaning and whole-car hydrodynamic skimming; both remain optional
  experiments, not promised follow-up work. Existing momentum/buoyancy is not
  labelled aquaplaning.
- Physical waves, tides, fluid displacement/flow simulation, waterfalls pushing
  cars, floating objects, swimming/boat controls, winching or towing.
- Permanent damage, repair systems, engine-intake upgrades, car locks, new cars,
  altered dry handling, grip tables or accepted shelf geometry/difficulty.
- Visible snorkel/art overhaul, new shaders/reflections, underwater camera mode,
  obscuring windscreen effects and a new water-control/settings screen.
- Fixing the inherited Rock Canyon build-budget miss or unrelated flaky tests.

## 14. Risks and safeguards

| Risk | Safeguard |
| --- | --- |
| Water appears safe but its physics boundary differs | Use drawn triangles and actual bed data; test banks, gaps, slopes and depth markers |
| Water doubles the mud penalty | Leave mud values alone, start with modest wheel drag, compare dry/wet matched beds and actual gully runs |
| A floating car behaves like an aircraft or boat | Explicit wet-body air-control gate, no wheel thrust, no speed-lift term |
| Intake stalls flicker or braking stops working | Separate stall/restart hysteresis and a tested stalled braking path, including reverse |
| Simplified buoyancy flips or launches the car | Distributed bounded probes, centre-of-mass-aware drag limits, energy and 60/120 Hz scenarios |
| Higher 4×4 intake is mistaken for guaranteed deep-water capability | Explain loss of traction/flooding, debug intake marker now, matching snorkel art later |
| Transparency hides hazards or costs phone FPS | Simple materials, no stacked surfaces, no shader requirement, screenshots and device profiling |
| Deep pools break the old Test Ground | Raised, closed basins on unused ground; no excavation or relocation of the slab/courses/spawn |
| New water queries undo build-speed gains | Spatially bounded data reuse, measured incremental budgets, no whole-level triangle copies or per-frame generation |
| State/audio survives reset or scene exit | Per-car state, level-owned registry, explicit cleanup and repeated-load tests |
| Baseline load failure gets concealed by a green suite | Separate known 3 s budget miss from new costs; explicit owner review, no completion claim based on tests alone |
