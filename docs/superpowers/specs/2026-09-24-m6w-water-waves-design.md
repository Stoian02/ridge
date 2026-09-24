# M6W — gentle waves and vehicle-generated water motion

**Date:** 2026-09-24. **Status: complete review draft; not approved for implementation.**

Companion execution plan: `../plans/2026-09-24-m6w-water-waves.md`.
Conversation record: `../../notes/water-waves-followup.md`.
Baseline: M6A through `4fc79ab`, including the owner's three-second intake
amendment (`9a05499`). M6A is not yet accepted or merged.

The owner requested a finished plan to review **before any wave implementation**.
Behaviour choices below are agreed; the algorithm, numerical starting values,
shader, prototype controls and budgets are proposals presented for that review.
No wave code, shader, scene, build or benchmark has been created for this draft.

## 1. Owner review summary

The first version makes the existing Test Ground water react visibly to a car:
an entry wave spreads out, a small bow wave forms ahead of motion, and a wake
remains behind. Gentle background waves can be switched on separately. The
larger surface movements slightly affect flotation and intake submersion.

- Start with ordinary crests a few centimetres high. Bound the combined surface
  offset to **less than 12 cm above/below mean level**, and much less in shallow
  water. This is a safety ceiling, not the usual wave size or a promised amount
  of car movement. Codex chooses the initial strength; the owner judges its feel.
- Keep **3 continuous seconds of intake submersion** before stalling. Any clear
  intake sample resets that timer. Restart and flooding rules stay unchanged.
- Preserve translucency, depth readability, the existing bed and bank geometry,
  car tuning and underlying tyre-contact surfaces.
- **No wall/rock reflections yet.** Disturbances fade near the water boundary.
  No obstacle diffraction, breaking surf, overflow, tides or floating debris.
- Use a bounded travelling-wave approximation, not a full fluid-volume solver.
  This does not conserve displaced litres or permanently raise a pool's level.
- Propose one new water shader and denser, opt-in **water-top meshes only**.
  Drawn height and physical sampled height must use the same triangulated field.
- Provide **Off / Car waves / Full** comparison modes on the Test Ground only.
  Default Off; no persistent setting or changes to timed levels in this part.
- Measure on the phone early. A good-looking desktop demo is not acceptance.

Suggested order: close M6A's review/acceptance, owner authorizes its merge,
build this separate Test Ground prototype, owner/Claude review it, then decide
rollout/reflections and Coastal Highway. Approving this draft would approve
that order, not waive M6A's existing failures or authorize a merge.

## 2. Decisions and authority

| Subject | Status and decision |
| --- | --- |
| Entry, bow wave, wake, settling | Agreed by owner |
| Gentle background waves | Agreed starting scope, not hazardous swell |
| Larger car-generated waves affect flotation | Agreed; strength delegated to Codex |
| Waves affect intake submersion | Agreed; cosmetic splashes do not |
| Intake delay | Already implemented: 3.00 s for all three cars |
| Wall/rock wave reflection | Explicitly deferred until after basic tests |
| Test Ground first | Agreed prototype location |
| Analytic travelling-wave model | Proposed in this draft |
| New ShaderMaterial and refined water-top meshes | Proposed, explicit exception to M6A's no-new-shader approach |
| Test Ground comparison controls and numeric budgets | Proposed in this draft |
| Timed-level rollout, Coastal Highway design, later reflections | Not authorized here |

No changes under `car/` or to `surfaces/*.tres` are planned. Existing water
samples already feed flotation, wheel immersion, flooding, intake state and
feedback. If implementation proves that car-side changes are needed, stop and
ask before making them; spec approval is not a blanket car-tuning authorization.

## 3. Entry conditions and stopping point

Before creating runtime work on proposed branch `m6-water-waves`:

1. Owner reviews this spec and its companion plan, then explicitly approves
   implementation. Do not infer that from approval of an individual behaviour.
2. M6A review and phone acceptance are resolved, including an explicit decision
   on its timing/setup gates, the unexplained long pool frame intervals and
   inherited load misses. A revised gate or an accepted exception must be
   recorded; this spec supplies neither automatically.
3. Owner authorizes the M6A merge. Start the new branch from that merged master;
   never merge/push master as a normal implementation step.
4. Rebuild/install the three-second-delay baseline before new phone comparisons.
   The APK installed during the earlier performance audit still has 0.60 s.

Current evidence: `../../notes/m6a-query-fixes-2026-09-24.md` records phone ford
p95 about 1.6 ms/tick after optimization, course p95 up to 1.376 ms/tick, and
one current-pool case with intervals up to 79.459 ms. Original timing/setup gates
remain missed. `../../notes/codex-report-m6a-water.md` records the later
736-passing / one-pending desktop suite, not new phone acceptance.

End this part with the Test Ground prototype, all verification and a report;
stop for review. Do not enable waves in Muddy Valley, Rock Canyon, other timed
levels or a new Coastal Highway. Their flat M6A water remains unchanged during
this explicitly isolated prototype; later rollout is a separate approval.

## 4. What the player should see and feel

### 4.1 Entry and exit

A physical entry into water creates one spreading, short-lived surface pulse.
Entry strength responds to translation, downward entry speed, hull size and
available depth. Slow entry is quieter; faster entry is more visible. Existing
spray and entry audio remain supporting feedback, not the surface simulation.

Normal bobbing, Reset, car replacement and spawning underwater must not keep
creating entry pulses. Leaving stops new hull disturbances once the hull is
clear; existing waves continue to spread and fade. No separate exit splash
generator is required for this version.

### 4.2 Motion and stopping

A low ridge forms ahead of the car's **water-relative direction of travel**,
including reverse and sideways motion. Short travelling pulses are deposited
behind it to suggest a spreading wake. This is a readable game approximation,
not an exact boat wake or a fixed physical wake angle.

At rest relative to the water, the attached bow wave fades and wake emission
stops; previous disturbances expire. A stationary car in a steady current can
still disturb passing water. Spinning wheels alone do not create physical waves
or thrust. Deeply submerged cars do not emit a large wake at the distant surface.

### 4.3 Car response

The changing water height changes the existing distributed probe immersions.
That supplies gentle bobbing/pitch/roll through existing buoyancy; do not add
a separate rocking torque, a wave shove, orbital-flow drag or speed-lift force.
Keep buoyancy ratios, force caps, currents, drag, tyres and dry handling intact.
Fully flooded cars still sink; waves are not flotation equipment.

The visible moving surface also determines intake clearance and wet feedback.
Keep the implemented 3.00 s continuous stall timer, 5 cm restart clearance,
1.00 s clear-before-restart and 0.50 s torque ramp. Body flooding keeps its own
3.00 s accumulated deep-immersion grace and subsequent fill/drain rules.
The two three-second timers are different and must not be coupled.

## 5. Proposed architecture

Use two low-frequency ambient components, one attached bow disturbance for the
single player car, and at most **16 travelling disturbance packets per world**.
All are evaluated as height offsets over each body's existing mean water top.
XZ positions and water footprints stay fixed; there is no horizontal vertex
displacement, ocean FFT, compute-fluid solver, mesh rebuild per tick or GPU
readback in gameplay.

This choice fits the explicitly deferred reflections: packets travel and fade,
but do not solve wall interaction or water flowing around obstacles. Do not
present it as a reflection-capable fluid solver awaiting a simple toggle.
If later reflections require a different field model, they receive a new design.

Small sums of analytic geometric waves are an established rendering technique;
the shared physical sampling, packet rules and limits here are Ridge-specific
design proposals, not performance conclusions from that reference.
[GPU Gems: effective water simulation](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models).

### 5.1 Ownership and file layout

| Proposed component | Responsibility |
| --- | --- |
| `water/waves/water_wave_profile.gd` and `.tres` | Immutable proposed numbers; no mutable car state |
| `water/waves/water_wave_math.gd` and GPU include | Pure height/envelope/taper maths; shared GPU evaluator for rendering and diagnostic parity |
| `water/waves/water_wave_field.gd` | Per-body view of assigned packets, triangle sampling, tick-local vertex cache |
| `water/waves/water_wave_mesh.gd` | One-time refined top, footprint index, static attenuation metadata |
| `water/waves/water_wave_runtime.gd` | Level-owned global packet budget, clock, pre-car tick snapshot, teardown and render upload |
| `water/waves/water_wave_emitter.gd` | Post-car observation of existing samples; queue next-tick entry/wake/bow state |
| `water/waves/water_surface.gdshader` | Same height equations; translucent single water surface |
| `ui/water_wave_test_controls.gd` | Optional Test Ground pause-menu controls, not a new global settings screen |
| `debug/water_wave_acceptance.gd` / `.tscn` | Reproducible off/on, stress, parity and live-driving measurements |

Minimal existing-code integration: an optional per-body wave-field registration
in `WaterWorld`, extra rest-height diagnostics in `WaterSample`, and an explicit
binding from Test Ground. `WaterCourse` exposes its top-mesh handles/definitions
without changing the default generation algorithm or its arrays. Keep the
original body registry and adaptive bed index; do not feed the denser drawing
mesh back into the expensive static top/bed query path.

No singleton/autoload, worker-thread calls into a shared script, new dynamic
bodies, or per-frame whole-scene/collision scans. The current prototype supports
the Test Ground's horizontal, non-overlapping bodies; do not silently claim
support for tilted water, arbitrary transformed moving pools or complex islands.

### 5.2 Tick and render order

1. Runtime at physics priority **-50** advances its simulation clock, expires
   packets and commits the previous tick's queued source data. Snapshot is then
   immutable for this physics tick.
2. Existing `Car` processing at priority 0 performs its normal 13 water probes,
   intake decision, wheels and forces. No reordering of that code.
3. Emitter at priority **50** reads completed car samples and queues sources for
   the next tick. It does not change the field just sampled or issue 13 more
   base-bed queries. One tick of source latency is deliberate and bounded.
4. Recorder at priority 100 records the completed work. Rendering receives the
   **last completed physics snapshot**, not an independently advancing clock.

Use an explicit pause-aware phase/packet-age uniform. Godot's shader `TIME` is
not paused with the scene and rolls over; it is unsuitable as the authority for
buoyancy and intake timing. Keep bounded phases/ages and local body coordinates,
using the same float32-packed parameters on CPU and GPU. No render-only phase
extrapolation in this first version.
[Godot spatial-shader built-ins](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).

### 5.3 Physical height must match the drawn triangles

For a valid base query, retain `rest_surface_y`, bed, body ID, current and
shoreline weight. Apply the wave height before `WaterWorld` selects its final
valid result. With no wave binding, return the original result/force path.

The visible refined mesh is a clipped XZ triangulation, not an infinite plane.
Locate the same render triangle at the query point, evaluate its three vertices
at the current snapshot, and barycentrically interpolate their displaced Y.
**Do not** simply evaluate the continuous wave function at the query point:
that would differ from a coarse triangle's actually drawn plane. Cache vertex
heights only for the current tick; never reuse an answer because a car is still.

Use exact existing static bed queries for collision depth. Base-invalid points
remain invalid; waves do not bridge dry gaps, raise the bed, expand a shore or
create a solid water collider. All probe/feedback consumers see the resulting
`surface_y`; `rest_surface_y` is diagnostic/source-generation data, not a second
secret intake height. Sampled-versus-rendered height error must be **<=1 mm**
at matched snapshots, including clipped shore cells and packet saturation.

## 6. Proposed starting values and bounded model

These are initial test values chosen under the owner's delegated strength
decision, not measured results or an approved new difficulty setting.

### 6.1 Ambient and local limits

| Field | Initial value |
| --- | --- |
| Ambient components, deep pools only | Two: amplitudes **0.025 / 0.015 m** |
| Wavelengths / periods | **8 / 5 m**, **3.6 / 2.5 s** |
| XZ directions | Normalized `(1, 0.35)` and `(-0.3, 1)` |
| Initial phases | **0 / 1.3 radians**, deterministic on reset |
| Shallow-bay ambient amplitude | **0**; car-generated ripples only |
| Maximum absolute combined offset | **0.12 m**, additionally depth/shore limited |
| Depth limit | At most **20% of conservative local rest depth** |
| Shore attenuation distance | Smoothly rises from zero to full over **1.5 m** |
| Physical wave-front half-width | **1.5 m**; smaller details are visual only |
| Wave-front propagation speed | **2.0 m/s**, a game-model parameter |

At a mesh vertex, sum ambient, bow and travelling packets into `raw`. Bake a
local limit `L = min(0.12, 0.20 * conservative_depth) * shore_weight`. Use the
smooth bounded displacement `raw / sqrt(1 + (raw/L)^2)` when `L > 0`, otherwise
zero. Apply this **at vertices**, identically on CPU/GPU, before interpolation.
The mean level remains the existing level; there is no accumulated pool rise.

Conservative depth includes the maximum solid-bed height over each render
triangle, including bed-triangle breakpoints, not merely its corner depths.
Each shared vertex uses the minimum allowed limit of its incident triangles.
Build this from nearby indexed static bed faces once, so a trough cannot cut
through a shallow bank or a raised patch between vertices. The global boundary
vertices have zero displacement. If this preprocessing misses its build budget,
report it and revisit the design; do not substitute unsafe corner-only masking.

Ambient components are sines with the table's wavelength, period and phase.
These periods are deliberately authored for a gentle game feel, not a claim of
exact depth-dependent wave dispersion.

### 6.2 Entry, bow and wake sources

| Field | Initial value / rule |
| --- | --- |
| Travelling slots | **16 total**: 4 reserved entry slots, 12 wake slots |
| Entry life / wake life | **4.0 / 3.0 s** |
| Packet onset / final fade | **0.12 / 0.75 s**, smoothstep, then expire |
| Entry re-arm | At least **0.5 s** with mean rest-surface body-probe immersion **<=0.02** |
| Entry detection | Mean rest-surface body-probe immersion crosses **0.05** after re-arm |
| Entry coefficient | `clamp(0.02 + 0.004*horizontal_speed + 0.01*downward_speed, 0.02, 0.08)` metres, before size/local limiting |
| Size factor | Hull footprint relative to **7.2 m²**, clamped to **0.8–1.25** |
| Wake / bow start and full-strength speeds | Smoothstep from **0.75 to 8.0 m/s**, water-relative |
| Maximum wake / bow coefficients | **0.03 / 0.05 m**, before local limiting |
| Hull immersion weight | `clamp(rest_body_immersion / 0.35, 0, 1)` |
| Tyre-only shallow wake weight | At most **0.15 × mean rest-wheel immersion**, no large hull-entry pulse |
| New wake cadence | Both **0.30 s** elapsed and **1.0 m** water-relative path travelled |
| Bow response | Exponential rise **0.12 s**, fall **0.40 s** |
| Deep source fade | Fade out as the highest body probe's upper extent goes **0.30–0.60 m** below mean water |

Coefficients are inputs to an enveloped, locally limited field, not guaranteed
crest heights. Clamp size-scaled entry/wake/bow coefficients to **0.08 / 0.03 /
0.05 m**. Use the greater of hull and tyre-only wake weights; do not add them
into a new force or count water twice. Entry uses the crossing event, size and
local depth rather than multiplying by a tiny just-crossed immersion again.

Use existing probe positions, radii, rest heights and steady current to obtain
source data without additional base queries. Mean/rest water is used for source
detection so a wave does not continually create copies of itself. Direction is
horizontal velocity relative to steady current; intensity does not use throttle
or wheel spin. Source locations must be inside their own precomputed footprint.
Initial placement/teleport seeds history without an entry event.

Travelling packet reference: for age `a`, centre `o + current*a`, horizontal
offset `d`, soften the source core with `s = sqrt(dot(d,d) + 0.5*0.5)` and
`r = s - 0.5`. This avoids a radial derivative cusp at the centre. Set
`q = (r - 2*a)/1.5`. Inside `abs(q) < 1`, use the compact crest/trough pulse
`(1-q*q)^2 * cos(PI*q)`, multiplied by the onset/final-age envelope and
`1/(1 + 0.15*r)` attenuation. Outside that support it is zero. Entry pulses are
radial; wake pulses additionally fade the forward-facing sector using the
stored travel direction, so their strongest component spreads behind the car.
Use `smoothstep(-0.2, 0.4, -dot(d/s, travel_direction))`; the same softened core
keeps this directional mask differentiable. No singular normal or NaN at a
source centre. The nominal 2 m/s propagation applies outside that small core.

One attached bow field uses the leading hull point in water-relative travel
direction, longitudinal half-width **1.5 m**, lateral half-width
`max(1.0, 0.65*body_width)`. With normalized longitudinal/lateral coordinates
`u,v`, use `(1-u*u)^2*cos(PI*u)*(1-v*v)^2` inside `abs(u),abs(v) < 1`, zero
outside, multiplied by the smoothed bow coefficient. Losing wet contact fades
its coefficient; it does not leave an invisible attached force behind.

Choose the dominant body from the existing wet samples. On a body change, queue
new sources only to that body and let old travelling packets finish in their
original body. No wave transfer across separate shallow bays or between pools.
When slots fill, skip the new packet and count it; never grow history or replace
a strong live packet abruptly. Normal cadence should not exhaust the cap;
synthetic stress verifies the skip path. All travelling disturbances expire
within four seconds after generation stops; the bow is negligible after 2 s.

## 7. Drawing and mesh construction

M6A merges flat water-top triangles aggressively. Animating only those existing
corners would not produce a readable local wake. Build opt-in wave tops at a
proposed **0.75 m XZ cell pitch**, clipped against the existing drawn footprints,
preserving the mean plane and depth colours. Keep every bed/collider, ramp,
rim, marking, original source array and non-water part of the Test Ground.

Reuse compatible static mesh data between the identical calm/current basins.
Each of the six water bodies gets its own parameters; sharing a ShaderMaterial
must not accidentally share its wave history. Hide the original two deep tops
and combined shallow top when the six wave tops are shown; **never stack flat
and animated transparent sheets**. Off restores the original three tops and
detaches wave sampling. Base `WaterCourse` defaults and tests stay unchanged.

Prototype limits: **<=40,000 additional submitted primitives**, **<=6 additional
draw calls including test UI**, and the existing scene-wide **<300k / <150**.
These are proposed allocations for this new opt-in mode, not a change to M6A's
original 10k course allowance or a measured count. Count both deep instances,
all six bodies, car/effects/labels and every pass. If clipping exceeds the cap,
stop for design review rather than raising it or weakening existing fixtures.

One shared shader program: vertical vertex displacement; correctly updated
normals; existing base colours/alpha, roughness **0.18**, metallic **0**, specular
**0.65**; double-sided, no water shadow casting, depth testing retained. Fine
surface ripples and a restrained light wake highlight may be normal/colour
detail only. Keep sub-centimetre visual detail from pretending to be a separate
large geometric waterline. No refraction, planar reflections, screen-depth
sampling, extra transparent foam sheet or new post-processing pipeline.

Writing alpha uses Godot's transparent pipeline and can introduce sorting
artefacts; inspect from the bank, above the water and underneath while sinking.
Normal equations must include attenuation/saturation derivatives; test against
a finite-difference reference. Shader-displaced bounds include the 12 cm limit,
so visible crests cannot be culled by a flat AABB.
[Godot spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).

Compile/use the material and relevant transparent draw configuration behind the
prototype's loading cover before returning control. Keep one bounded shader
variant rather than generating one per packet count. Measure cold-cache and
warm-cache entry; an offscreen warm-up is not proof that first-use hitching has
gone away. Do not clear the owner's application data to manufacture a cold run.
[Godot pipeline compilation guidance](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html).

## 8. Test Ground controls and lifecycle

Add an optional Test Ground-only section to the pause menu, supplied by the
level through a small extension hook. Other levels keep the same menu.

| Mode | Behaviour |
| --- | --- |
| Off (default every scene entry) | Original M6A meshes and water queries; no wave stepping |
| Car waves | Entry/bow/wake and physical response; no ambient motion |
| Full | Car waves plus gentle ambient motion in the two deep pools |

The visible control says **Changing water mode resets the car**. Applying a
mode releases touches, uses the existing Test Ground reset path, clears all wave
history, seeds sources without splash and starts from the fixed phase seed.
First enable may use a brief loading cover while building/warming the optional
tops. Do not save the mode to progress or silently carry it to a timed level.
Retain prepared meshes for later toggles in the same scene; release on exit.

All three existing areas are reused: shallow bays for tyre-sized ripples and
edge clipping; calm pool for entry/wake/settling; current pool for moving-water
relative sources and physical drift. No new wall or obstacle course is built.
The owner can compare the same car in Off, Car waves and Full, then change cars
through the existing menu. A debug-only start option selects mode and fixture
for automated phone runs; it must not alter normal save/progress behaviour.

Pause freezes phases, ages, source queues and rendered wave height. Reset, car
change, world rebuild and scene exit clear queued and live disturbances plus
the attached bow; check world generation and car reset serial before using a
snapshot. Never leave a field bound to a freed world/body. Reuse the existing
audio and particle limits; any loop continues to need padded PCM and explicit
shutdown. No new sounds or particle-system expansion are required.

## 9. Performance plan and provisional acceptance gates

An early synthetic worst-case phone test precedes art polish and natural wake
tuning. Budgets below are **proposed for review**, not automatically substituted
for the unresolved M6A gates. If a gate is missed, retain the result and return
with a measured adjustment proposal; do not silently raise a limit.

| Metric | Proposed gate / reason |
| --- | --- |
| Incremental wave CPU work | **<=0.50 ms p95 per rendered-frame interval**, <=1.0 ms p99; allocates about 3% of a 16.7 ms frame at p95 |
| Incremental measured GPU frame time | **<=0.50 ms p95 increase** in matched fixed-pose views; report absolute GPU time too |
| Complete Test Ground frame pacing | Average >=59 FPS; process-frame p95 <=18.5 ms, p99 <=25 ms in warmed cases |
| Long frames | Retain/analyse every interval >33.3 ms; a reproducible wave-induced hitch or unexplained cluster blocks acceptance regardless of averages |
| New mode preparation | Additional <=0.25 s phone CPU setup, reported separately from shader/first-present wait and inherited setup misses |
| Wave-owned memory | <=16 MiB CPU+GPU estimate, report both and count shared buffers correctly |
| Runtime bounds | 16 travelling packets, one bow, two ambient components/body; no per-tick node, mesh or collision creation |
| Drawing | Section 7 caps plus unchanged global scene limits |

The total-car-water cost is still reported against M6A's agreed final policy.
An incremental pass cannot excuse an already failing baseline. At 120 Hz,
measure the work of **all physics ticks belonging to each frame**, including
catch-up; do not treat one tick as the complete 16.7 ms budget.

Extend `WaterMeasurement`/CSV validation to distinguish:

- Inclusive car-water-controller cost (already includes wave query work).
- Wave-query subtotal **inside** that controller, for attribution only.
- Wave runtime/emitter CPU outside the controller, and render-upload CPU time.
- Total water CPU = inclusive controller + external wave work + upload;
  incremental wave CPU = query subtotal + external wave work + upload.
- Whole process-frame intervals, p95/p99/max and threshold counts, plus GPU
  frame timings when supported. Do not add the query subtotal twice.
- Snapshot IDs, frame/tick IDs, field mode, active/skipped packets, evaluated
  vertices, maximum offset, query counts, setup phases and cleanup counts.

Use `RenderingServer.viewport_set_measure_render_time` and measured GPU/CPU
render-time accessors where valid on the actual Godot/mobile build; record
unavailable or delayed counters honestly. No zero-valued unsupported counter
counts as a pass. Use a separate diagnostic GPU readback only for parity tests,
never during performance samples.
[Godot RenderingServer timing API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-set-measure-render-time).

### Measurement protocol

1. Freshly build the exact reviewed branch; record commit/dirty status, APK hash,
   Godot version, renderer, actual resolution and save hash. Install only while
   the owner's device/game is available and idle. No other Godot process runs.
2. Record a waves-Off baseline with the three-second stall change, not the old
   0.60 s APK. No accelerated/fixed-fps mode for acceptance timings.
3. Alternate Off/Full order for **three rounds and all three cars**. Use a
   deterministic 60 s matched-pose replay (cost isolation, labelled as such),
   including shallow/deep positions and moving-source histories. Retain complete
   per-case ticks/frames; do not pool away a slow car or a late warm round.
4. Separately run live, un-frozen-car entries/exits at **3, 8 and 15 m/s**, reverse,
   stop, drift, float/sink and intake recovery in all modes. Trajectories may
   differ when waves are on; these are behavioural tests, not identical-pose A/B.
5. Synthetic stress: all 16 packets overlap the sampled/visible area, active bow,
   both ambient components, all water tops visible. Three 30 s phone samples
   with matched Off control. Also record a zero-packet refined-mesh/shader view
   to separate mesh/shader cost from packet cost; this is not the Off baseline.
6. Run at least **five continuous minutes** warmed with Full enabled and cycle
   all three cars. Record battery temperature/thermal status, audio/effects and
   frame tails. Stream logcat from before launch through exit, not a late dump.
7. Capture first-use behaviour and three repeated mode/scene rebuild rounds;
   measure CPU preparation and wall-to-first-present separately. Recheck all
   timed levels with waves unbound; do not start an unrelated load optimization.
8. Independently recompute raw tick/frame/GPU summaries, inspect screenshots,
   preserve failed cases and verify save/cleanup. If a long stall recurs, use a
   CPU/system trace; elapsed wall timing alone cannot identify its cause.

## 10. Verification requirements

No tests listed here have run for waves; this is the future acceptance checklist.

### Pure model and query tests

- Exact Off parity for validity, mean/bed/current/edge weight and car forces;
  new diagnostic fields do not change dry or unbound behaviour.
- Packet support, directions, advection, onset/decay/expiry, slot exhaustion,
  no allocation growth and deterministic replay. Equivalent prescribed paths
  at 60/120 Hz produce the same event count, with event times within 1/60 s;
  do not require different real-car trajectories to be numerically identical.
- No entry on spawn/reset; no repeated entry from ordinary floating/bobbing;
  no physical waves from wheel spin alone; wake stops at water-relative rest.
- All shallow bodies remain separate; no footprints enlarged, ground flooded or
  triangles below the bed at conservative limits. Negative coordinates, clipped
  corners, seams, maximum overlap and water generation changes are covered.
- Query height equals the barycentric GPU-displaced surface within 1 mm at
  matched snapshots. A tiny diagnostic target/readback must call the same GPU
  height evaluator as the actual water shader, not a separately rewritten test
  equation. Use linear float output or a calibrated reversible encoding; verify
  known flat/offset values first so tone mapping or colour conversion cannot
  manufacture a pass. Test mesh interpolation independently. Disable diagnostic
  readback for timing. If unavailable on phone, report it and require an
  alternative measured comparison, not a visual guess.
- Freeze/resume and 10-minute clock continuity; finite heights/normals at source
  centres and boundaries; no culling of displaced crests or normals pointing
  through the surface unexpectedly.

### Real-car scenarios and visual checks

- All three cars, both 60/120 Hz: entry/exit, reverse/sideways travel, shallow
  ground contact, fresh flotation, sinking, current drift and reset.
- In a controlled no-current afloat fixture, compare equal-state Off/Full runs
  during the **first 2 s before flooding grace is spent**: proposed extra
  vertical excursion <=0.15 m and extra pitch/roll <=5 degrees. Demonstrate a
  visible response above numerical noise, not only an upper-bound assertion.
  Start at a reproducible equilibrium pose derived from the existing probe
  volumes, with zero flooding; do not change profiles to hold the car afloat.
  These are prototype feel limits, not limits on rough driving or later sinking.
- Ambient disabled, stopped unthrottled car: after packets expire, field offset
  returns to zero within 1 mm; no growing bobbing loop, rising mean level or
  newly generated self-wake. Existing dissipation tests pass unchanged.
- Fixed-pose intake fixture: shorter than 3 s coverage does not stall, exactly
  3 s does at 60/120 Hz, a trough clearing the intake resets the timer, and
  restart/flooding continue independently. Decorative splash never counts.
- Inspect boat-like self-propulsion, unearned launch, oscillation growth,
  invisible/opaque water, bank clipping, foam/spray duplication, underwater
  rendering, LOD/culling and normal shimmer. No acceptance based on numbers
  alone if the owner cannot see the entry wave or wake from the driving camera.
- Pause, all comparison modes, Reset, car change, rebuild and scene exit leave
  no stale histories, resources, playing sounds or broken touch input.

### Regression and handoff

Run `./run_tests.sh all` with no SCRIPT ERROR. Preserve the existing geometry,
water-geometry, build-detail and car-balance fixtures unchanged, including the
base Test Ground's 9,300-primitive assertion. Test opt-in wave drawing under its
own new limits; do not relax that old baseline to make the prototype pass.
Record inherited pending tests separately. Follow with phone measurements and
owner playtest, a feature-separated commit history, and
`docs/notes/codex-report-m6w-waves.md`. No merge/push or automatic rollout.

## 11. Risks, limits and explicit non-goals

| Risk | Required response |
| --- | --- |
| Shader looks cheap on desktop but costs too much on phone | Early worst-case synthetic gate before polishing/expanding |
| CPU/GPU equations, time or triangle interpolation disagree | Shared packed snapshot contract and measured parity test |
| A car pumps energy into its own wake | Mean-level source detection, finite history, no direct force/velocity feedback, stopped-car stability test |
| Shallow trough intersects a raised bed | Conservative triangle-wide depth limit, fixed footprint, bed-intersection tests |
| New surface exaggerates visibility without matching gameplay | Same physical height; normal/foam detail explicitly cosmetic |
| Refined mesh/shader preparation adds more load debt | Optional measured preparation, original Off path intact, explicit gate |
| Prototype turns into a level-wide rewrite | Test Ground-only enablement; stop for review before existing-level rollout |

Deferred: wave reflection/refraction around walls or rocks, moving obstacles,
fluid-volume conservation, flooding land, breaking surf, tides, dynamic currents,
floating debris, aquaplaning/skimming, snorkel art, underwater camera effects,
new car controls, weather, Coastal Highway construction and inherited load fixes.

## 12. Review sign-off

Owner/Claude should review: the first-version scope and postponed reflections;
gentle numeric starting values and physical/intake coupling; the shader and
water-top-only refinement; opt-in comparison/reset behaviour; proposed CPU/GPU,
drawing and setup allocations; and the M6A acceptance/merge prerequisite.

**Current decision: waiting for review. No wave implementation is authorized.**
