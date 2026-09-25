# M6W — gentle waves and vehicle-generated water motion

**Current CPU budget amendment (2026-09-25):** owner approved provisional
**Test Ground** total-water CPU ceilings of **6 ms/frame p95 / 7 ms/frame p99**.
The earlier incremental CPU 0.50/1.0 ms figures are now reported optimization
targets, not blocking gates. Whole-frame, GPU, setup, memory, drawing and hitch
checks remain unchanged. See §9 and
`../../notes/m6w-budget-amendment-2026-09-25.md` for evidence and rationale.
Defer native/C++ work; preserve wave look, strength and physical response. This
does not accept M6A/M6W or approve timed-level rollout, Coastal Highway or merge.

**Current completion approval (2026-09-25):** the owner authorized correcting
the measurement harness and finishing M6W for a whole-milestone review, with
focused commits/evidence. See `../../notes/m6w-completion-plan-2026-09-25.md`.
The older step-only stops below are historical; accepted ambient/vehicle wave
feel remains unchanged. Use the amended CPU policy above. Test Ground only;
no timed-level rollout, Coastal Highway, merge or push. Historical M6A hitch
acceptance remains separate.

**Bow-only iteration approved (2026-09-24):** the owner likes the entry and
selected step 1 of the proposed next pass: refine the leading bow crest around
the car's sides, including reverse, on the Test Ground before phone tests.
Trailing wake/splash work (steps 2/3) is not approved here. Preserve ambient,
entry, coefficients, car tuning, depth/shore limits and all deferred gates;
stop for another owner feel check after PC verification.

**Entry-feel iteration approved (2026-09-24):** the owner finds ambient waves
sufficient but entry almost invisible. Improve entry readability on the Test
Ground and stop for another feel check; phone testing follows when connected.
The owner explicitly accepts tracking the intermittent hitch as unresolved but
non-blocking for this iteration, retaining Off-mode diagnostics and a phone
recheck before final acceptance. This supersedes the older hitch-fix prerequisite
for this work, not the all-water budgets or merge/rollout restrictions.

**Latest owner exception (2026-09-24):** a live, experimental **Test Ground-only
PC driving prototype** is now approved before the outstanding hitch review and
full phone gate. Connect the already specified height sampling and natural
sources, expose Off / Car waves / Full (default Off), verify on PC and stop for
Task 5a owner feedback. This limited sequencing change supersedes older blocked
integration language below; it does not accept M6A, phone budgets or historic
hitches, authorize timed-level waves, car tuning, polish, merge or push.

**Date:** 2026-09-24. **Status: experimental Test Ground PC prototype implemented;
awaiting Task 5a owner driving feedback. Phone/hitch acceptance remains open.**

**Original isolated-start approval (superseded in scope by the PC exception):**
approved the limited maths/mesh/shader start on
`m6-water-waves` from unmerged M6A `4d5bd21`, with **total water CPU <=4 ms/frame
p95 and <=5 ms/frame p99**. This supersedes earlier merge-first/unset-ceiling
language only for isolated work. Do not bind waves to a live car, change existing
physics, merge master or declare M6A accepted. Synthetic fixtures and standalone
height sampling are permitted; full integration waits for the hitch fix/retest.

Companion execution plan: `../plans/2026-09-24-m6w-water-waves.md`.
Conversation record: `../../notes/water-waves-followup.md`.
Branch baseline: M6A `4d5bd21`, including the owner's three-second intake
amendment (`9a05499`). M6A is not yet accepted or merged.

The owner reviewed the plan before implementation and approved the limited start
above. The algorithm, starting values and shader are being exercised in isolated
fixtures; this does not yet approve activating the whole gameplay prototype.
Owner-requested review corrections: gate total water cost before allocating the
wave increment, and stop for an early owner driving-feel test after Task 5,
before Task 6 polish. The latest limited-start amendment defines runtime scope.

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
- Gate **absolute total-water CPU per frame**, not just the wave increment.
  The current provisional Test Ground ceiling is **6 ms/frame p95 and
  7 ms/frame p99**; report incremental CPU as an optimization target. The
  historical 4/5 ms approval remains recorded below, not a pass for old runs.
- **Owner drives immediately after entry/bow/wake work (Task 5a)**, before
  polish. Stop for feedback on strength, bobbing and readability; adjust and
  repeat before continuing to Task 6.

Revised order: isolated groundwork may precede M6A acceptance/merge. Fix and
retest the M6A hitch before live-car integration; preserve later review, phone
acceptance and owner merge decisions. No exception accepts existing failures.

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
| Total-water gate before wave allocation | Amended 2026-09-25: Test Ground 6 ms/frame p95, 7 ms/frame p99; not retrospective acceptance |
| Incremental wave CPU | 0.50/1.0 ms p95/p99 retained as reporting/optimization targets, not blocking gates |
| Early owner feel checkpoint | Required after Task 5, before Task 6; delegated initial strength is not feel acceptance |
| Analytic travelling-wave model | Approved for isolated groundwork |
| New ShaderMaterial and refined water-top meshes | Approved for isolated groundwork; explicit exception to M6A's no-new-shader approach |
| Test Ground comparison controls and numeric budgets | Proposed in this draft |
| Timed-level rollout, Coastal Highway design, later reflections | Not authorized here |

No changes under `car/` or to `surfaces/*.tres` are planned. Existing water
samples already feed flotation, wheel immersion, flooding, intake state and
feedback. If implementation proves that car-side changes are needed, stop and
ask before making them; spec approval is not a blanket car-tuning authorization.

## 3. Entry conditions and stopping point

The owner permits Tasks 1–3 in isolated fixtures on `m6-water-waves`, starting
from unmerged M6A `4d5bd21`. Keep the unmodified waves-Off game path; car binding
in Task 2 and live vehicle work in later tasks stay deferred until the hitch
is fixed and retested. No merge/push is authorized by this exception.

Before later integration/acceptance, resolve M6A's remaining hitch, setup/load
and acceptance decisions explicitly. Use the approved all-water CPU limits in
§9; the old 3 ms review trigger is not a replacement. Record the actual build
and three-second intake delay for phone comparisons: the earlier Codex audit
APK used 0.60 s, while Claude's fresh `4d5bd21` build includes 3.00 s. Branch
reconciliation and any merge remain owner decisions, never implicit steps.

Current evidence: `../../notes/m6a-query-fixes-2026-09-24.md` records phone ford
p95 about 1.6 ms/tick after optimization, course p95 up to 1.376 ms/tick, and
one current-pool case with intervals up to 79.459 ms. Original timing/setup gates
remain missed. `../../notes/codex-report-m6a-water.md` records the later
736-passing / one-pending desktop suite, not new phone acceptance.

There is also a mandatory intermediate stop at Task 5a for the owner's live
driving-feel review. Do not proceed to Task 6 polish while awaiting that reply.
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
| `water/waves/water_wave_field.gd` | Pure world-wide 4-entry/12-wake packet store; no Car/WaterWorld dependency |
| `water/waves/water_wave_snapshot.gd` | Reusable per-body float32 CPU/GPU parameter buffers |
| `water/waves/water_wave_sampler.gd` | Standalone drawn-triangle sampling and per-snapshot vertex cache; not bound to gameplay yet |
| `water/waves/water_wave_mesh.gd` | One-time refined top, footprint index, static attenuation metadata |
| `water/waves/water_wave_runtime.gd` | Owns one global field, clock, per-body snapshots/materials and teardown; currently lab-only |
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
cell (therefore every triangle it contains), including bed-triangle breakpoints,
not merely its corner depths. The implementation uses the slightly stronger
whole-cell bound to reuse clipping work across triangles.
Each shared vertex uses the minimum allowed limit of its incident triangles.
Build this from nearby indexed static bed faces once, so a trough cannot cut
through a shallow bank or a raised patch between vertices. The global boundary
vertices have zero displacement. If this preprocessing misses its build budget,
report it and revisit the design; do not substitute unsafe corner-only masking.

Ambient components are sines with the table's wavelength, period and phase.
These periods are deliberately authored for a gentle game feel, not a claim of
exact depth-dependent wave dispersion.

### 6.2 Entry, bow and wake sources

**Owner-feedback adjustment:** keep the original coefficients, cadence, ambient
values and all geometric safety limits. A natural entry now begins with soft
radial coordinate `r0 = clamp(0.5 * hull_width, 0.6, 1.5)` metres, rather than
zero, so the crest emerges beside the hull instead of starting under it. Use
`q = (r - r0 - 2*a)/1.5` for entry; ordinary wake retains `r0 = 0`. The actual
distance includes the existing soft-core transform. This is still a bounded
height-field approximation, not conserved fluid volume or a new applied force.
Pack `-r0` in entry direction.w; wake keeps `+1`. Synthetic point-entry fixtures
can still use zero. No extra source, slot, mesh or base-bed query is introduced.

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

**Bow-only refinement:** one attached curved crest uses the water-relative
leading hull extent plus **0.25 m** clearance. Compute both longitudinal reach
and cross-flow hull span from the projected car basis, so reverse follows the
rear and an oblique/sideways car presents a wider front. The lateral half-span
is `max(1.5, 0.5 * cross_span + 1.0)` m; backward sweep is
`clamp(0.75 * longitudinal_reach, 0.6, 2.0)` m. Store sweep in the existing
`bow_direction.w`; no extra field/packet/mesh/query is introduced.

For local lateral coordinate `v = lateral / half_span`, the curved crest lies
at longitudinal position `-sweep*v*v`. Evaluate
`u = (longitudinal + sweep*v*v) / 1.5`, then
`pulse(u) * (1-v^4)^2` inside `abs(u),abs(v) < 1`, otherwise zero, multiplied by
the original smoothed bow coefficient. Include the derivative of that sweep
in CPU/GPU normals. This replaces the narrow straight ridge's quadratic lateral
envelope; it is an attached approximation, not obstacle-aware water flow.
The 5 cm coefficient cap, speed/depth response and rise/fall times are unchanged.
Losing wet contact fades its coefficient; no separate rocking or sideways force.

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

The standalone builder extracts one closed footprint and refines it on the grid,
not each original colour triangle separately. Where clipped source T-junctions
prevent an edge chain closing, union temporary source triangles snapped to a
0.1 mm outline grid; registered source arrays never change. Only horizontal,
single-footprint bodies without islands are supported. Original top/bed indices
are reused locally for source colour and conservative depth during preparation,
then freed; the refined mesh is never registered as a static query top.

**Preparation implementation, following the 2026-09-24 groundwork review:**
perform that static derivation offline with `tools/bake_water_waves.gd`, storing
one shared deep resource and four distinct bay resources. At explicit first
enable, load them under the loading cover, validate an ordered source/top/bed/
colour and geometry-profile fingerprint plus bake revision, and adopt the exact
arrays/index/mesh. Stale/missing assets fail closed; do not silently rebuild
during play, weaken masks or lower detail. Fresh-builder versus packaged-data
tests must remain exact. Bump the bake revision when the derivation changes.
This does not hook waves into the default Off course or authorize live coupling.

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
detail only. The entry-feel iteration adds a crest highlight using the difference
between the drawn bounded height and its ambient-only counterpart, interpolated
over those same triangles. For 4–45 mm positive vehicle displacement, smoothly
mix toward a pale aerated colour (linear RGB 0.72/0.84/0.80, max blend 0.85) and
roughness 0.45. Original alpha is unchanged; zero vehicle disturbance leaves
ambient appearance unchanged. This adds one varying/two ambient sine evaluations
per vertex, not another packet loop, transparent sheet or draw call. Validate
phone cost rather than infer it from the absence of new geometry.
Keep sub-centimetre visual detail from pretending to be a separate
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

Provide minimal playable Test Ground binding, Off / Car waves / Full selection,
safe Reset/pause and cleanup by Task 5, so the owner can drive at Task 5a without
waiting for UI polish. These can be plain prototype controls. Task 6 finishes
their presentation and lifecycle coverage after feel approval; it must not be
the first point at which the feature is actually drivable.

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
First enable may use a brief loading cover while loading/validating the baked
optional tops and warming their rendering. Do not save the mode to progress or
silently carry it to a timed level.
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

### Absolute total-water gate — prerequisite, not an optional review trigger

On 2026-09-25 the owner approved provisional **Test Ground** ceilings for **all
measured water CPU work per rendered-frame interval**: **6 ms p95 and 7 ms p99**,
replacing the previous 4/5 ms policy in this scope. This allocates about 36% / 42%
of a 16.7 ms frame, as a ceiling rather than a target or proof of spare capacity.
Recent 30-second 4x4 replay/saturation subchecks held about 60 FPS; the owner
accepts reduced headroom instead of pursuing a native rewrite solely for 4 ms.
See `../../notes/m6w-budget-amendment-2026-09-25.md` for the exact evidence,
limitations and remaining verification. The original 4/5 ms approval and
failed results remain historical evidence, not retroactively accepted runs.
Measure the broader scope below; old controller-only results do not demonstrate
a pass. Inherited scene cost remains separate. No budget or acceptance decision
for M6A's timed levels or Coastal Highway is implied by this Test Ground change.

| Required approval record | Current value |
| --- | --- |
| Total-water CPU p95 ceiling, `C95` (ms/frame) | **6.0 — Test Ground amendment approved 2026-09-25** |
| Total-water CPU p99 ceiling, `C99` (ms/frame) | **7.0 — Test Ground amendment approved 2026-09-25** |
| Measurement scope / device | All measured controller + external water CPU, no double counting; Xiaomi 13, real-time 120 Hz physics / 60 FPS target; record exact renderer/build/resolution for each run |

This is a ceiling for baseline water **plus** waves, not an allowance to add to
the baseline. Both waves-Off and waves-On must meet it in each required case;
whole-frame, GPU and other unchanged gates must pass as well. The incremental
CPU figures below are reported optimization targets, no longer another blocking
gate. If baseline water uses the available room, waves have no entitlement to
another 0.50 ms. A baseline exception does not silently transfer to wave-enabled water or a future
timed-level rollout; any exception requires an explicit scoped owner decision.

For budget intuition only, 1.6 ms/tick at two ticks/frame is roughly 3.2 ms/frame;
another 0.5 ms would reach about 22% of 16.7 ms. This is **not** a measured p95
or a justified ceiling. Sum raw costs for each actual frame, including all
catch-up ticks, then compute percentiles. Do not multiply a tick percentile by
two, add component percentiles, or subtract them to claim measured headroom.
The earlier M6A 3 ms/frame **review trigger** remains unapproved and is not a
substitute for the required absolute ceiling.

### Additional allocations and complete-frame gates

The original sequence placed the synthetic worst-case phone test before art
polish/natural wake tuning; the owner later approved the early Test Ground feel
exception. The explicit CPU amendment does not change the other allocations
below or substitute for unresolved M6A gates. If a remaining gate is missed,
retain the result and return with a measured adjustment proposal; do not silently
raise a limit. Incremental CPU misses must still be reported as target misses.

| Metric | Gate / target and reason |
| --- | --- |
| Total water CPU, absolute | **p95 <=6.0 ms; p99 <=7.0 ms**, per rendered-frame interval, baseline plus waves; provisional Test Ground policy |
| Incremental wave CPU work | **0.50 ms p95 / 1.0 ms p99 optimization targets, not blocking gates**; report actual per-frame wave subtotal and misses; never extra allowance above total |
| Incremental measured GPU frame time | **<=0.50 ms p95 increase** in matched fixed-pose views; report absolute GPU time too |
| Complete Test Ground frame pacing | Average >=59 FPS; process-frame p95 <=18.5 ms, p99 <=25 ms in warmed cases |
| Long frames | Retain/analyse every interval >33.3 ms; a reproducible wave-induced hitch or unexplained cluster blocks acceptance regardless of averages |
| New mode preparation | Additional <=0.25 s phone CPU setup, reported separately from shader/first-present wait and inherited setup misses |
| Wave-owned memory | <=16 MiB CPU+GPU estimate, report both and count shared buffers correctly |
| Runtime bounds | 16 travelling packets, one bow, two ambient components/body; no per-tick node, mesh or collision creation |
| Drawing | Section 7 caps plus unchanged global scene limits |

Apply the approved total ceiling at the early synthetic phone gate, after any
material feel adjustment, and at final acceptance. Keep GPU and whole-frame
limits separate: CPU and GPU overlap, so their timings are not simply added
into a purported total-water CPU value. No Test Ground pass authorizes waves
at the ford; later timed-level/Coastal Highway work requires a scoped budget
review and fresh measurements, not automatic inheritance of this higher ceiling.

Extend `WaterMeasurement`/CSV validation to distinguish:

- Inclusive car-water-controller cost (already includes wave query work).
- Wave-query subtotal **inside** that controller, for attribution only.
- Other water-owned CPU outside the controller: field/emitter stepping, existing
  water feedback updates, water-specific material/buffer uploads and any other
  measured water callbacks. Count each region once; document engine-side costs
  not directly attributable, and retain complete-frame/GPU checks for those.
- Total water CPU = sum of inclusive controller costs over all frame ticks +
  non-overlapping external water CPU for that frame. Preserve controller-only
  columns for comparison with historical M6A data; do not relabel that older
  partial measurement as the new all-water total.
- Incremental wave CPU = nested wave-query subtotal + new external wave work
  and wave upload for that frame. This attribution never replaces total gating.
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
   0.60 s APK. Record the approved C95/C99 and compute complete total-water frame
   costs in the agreed scope. Missing limits or an unaccepted baseline stop the
   run sequence. No accelerated/fixed-fps mode for acceptance timings.
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

This is the full-part acceptance checklist. The isolated desktop subset and
remaining gaps are reported in `../../notes/codex-report-m6w-waves.md`; a unit
or synthetic rendering pass is not a live-car or phone acceptance result.

### Early owner driving-feel checkpoint — Task 5a, before polish

After entry, bow and wake are functional and the early phone feasibility gate
has passed, provide a rough but playable Test Ground build. Basic mode selection,
Reset, pause and teardown must work; finishing menu visuals, optional highlights
and telemetry is not a prerequisite. Run focused correctness/safety checks, then
stop all automated testing before handing the game to the owner.

The owner compares Off / Car waves / Full from the ordinary driving camera:
enter slowly and faster, turn/reverse, stop and watch the wake settle, feel early
flotation in the calm pool, then try the current pool and a shallow bay. Start
with the 4x4 and compare the rally cars. Ask whether entry/wake are visible,
whether bobbing feels slight rather than disruptive, and whether control and
the three-second intake rule remain understandable. A screenshot, scripted run
or an upper-bound test does not replace the owner's actual driving feedback.

**Stop and wait for explicit feel approval before Task 6.** Record feedback,
selected values and build ID; tune within the agreed scope and repeat the short
test if requested. Recheck safety and absolute/GPU/frame gates after material
changes; report incremental CPU target misses. If the phone is unavailable,
a PC feel pass may unblock polish only
with the owner's agreement; it does not waive final phone feel/performance
acceptance. No concurrent tests while the owner plays. Task 7 remains the final
regression and confirmation, not the first owner playtest.

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
| Small wave increment hides an expensive water baseline | Gate absolute totals in every case; report incremental CPU and retain independent GPU/frame gates |
| Owner finds the wave strength wrong after polish | Mandatory Task 5a live driving-feel approval before Task 6 |
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
The total-water ceiling and isolated start are approved in the amendment above.
The early Task 5a feel stop remains required. The latest explicit exception
permits live integration only for this experimental Test Ground PC checkpoint;
M6A/phone acceptance, merge and rollout are not granted.

**Current decision: owner drives the Test Ground PC prototype; stop for feedback
before polish. Keep phone/hitch gates pending and all timed levels waves-Off.**
