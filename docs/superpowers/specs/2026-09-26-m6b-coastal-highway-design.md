# Milestone 6B — Coastal Highway design

2026-09-26. Written by Codex from the owner's section-by-section design approval.

## 1. Status and authority

**The design direction is approved; this written spec is awaiting owner review.**
Exact dimensions, surface coefficients, resource interfaces and acceptance
proposals below are starting points for that review, not measured or already
approved tuning. Nothing in this document claims the jump is proven driveable.

The owner postponed phone hitch testing and explicitly asked to brainstorm
Coastal Highway meanwhile. This permits design/documentation ahead of the
original merge-first prerequisite, **not level construction or timed-level wave
rollout**. This document lives on `m6b-coastal-design`, branched from `m6-hitch`
at `c84bc29`; only documentation is changed. The later implementation branch
remains `m6b-coastal-highway`, from accepted, owner-merged master. Carry the
reviewed design forward without merging this branch's unaccepted ancestors.

M6A/M6W acceptance, the historical hitch and their failed measurements remain
open. Owner approval of phone feel is not performance acceptance. No merge,
push, car retune, protected-fixture change or budget waiver follows from this
spec. Next stop: owner reviews the written spec before an implementation plan.

Context:

- [M6 handover](../../notes/handover-codex-2026-09-23-m6.md).
- [M6W review package](../../notes/codex-report-m6w-waves.md).
- [Test Ground-only budget amendment](../../notes/m6w-budget-amendment-2026-09-25.md).
- [Deferred hitch investigation](../../notes/codex-report-hitch.md).

## 2. Approved experience

A coastal journey after rain: pale cliffs, blue-green sea, a headland tunnel,
one large mandatory jump, technical turns down to a sandy cove, water to read
and cross, a short stone bridge and an uphill run to a sunny headland finish.
Flowing and varied, with difficult corners rather than continuous rock crawling.

| Decision | Owner-approved direction |
| --- | --- |
| Length and pace | About 3 km; roughly 3–4 minutes is a pacing intention, not a star target or measured time. |
| Surfaces | About 70% asphalt, 30% unpaved: predominantly firm coastal sand, occasional softer patches. |
| Road condition | Mostly even; local potholes, shallow ruts, worn edges, dips and occasional unevenness. No constant battering. |
| Corners | Flowing sections plus genuinely technical linked bends, descent hairpins and sandy uphill S-bends. |
| Tunnel | One through a headland, followed by an open run-up to the jump. |
| Jump | Larger than existing jumps, mandatory for every car and every future route. Visible landing and ample recovery room. |
| Bridge | One short stone-arch bridge only; no wooden/log bridge. Separate from the jump. |
| Main water challenges | A shallow flooded asphalt dip and a technical sandy crossing with an uneven bed and gentle lateral current. |
| Other wetness | Small and larger puddles and damp patches throughout; readable line choices, seamless joins. |
| Wet grip | Damp asphalt is moderately less grippy, clearly darker, not ice-like. Aquaplaning remains deferred. |
| Weather | Clearing after rain, sunlight through clouds; no active rain simulation. |
| Rainbow | A soft distant arc across the bay, seen from selected open sections and the finish. |
| Edge protection | Selective guardrails/low walls on faster exposed bends, open edges in some slower technical sections. |
| Car access | Main route passable with all three existing cars, without retuning them. |
| Future shortcuts | Reserve space for 4x4-oriented deep-mud/rock routes; build none until the main track has been driven and approved. |

## 3. Route and pacing

Distances are nominal stations along the generated main-route curve. Paved
allocation includes the jump's missing span; it does not assert asphalt exists
across the gap. The two unpaved stretches total 900 m, the paved allocations
2,100 m. Small wet/soft patches do not change this overall 70/30 identity.

| Station | Surface | Character and landmarks |
| --- | --- | --- |
| 0–600 m | Asphalt | Cliff opening, broad sweepers, gentle crests, shallow flooded dip. |
| 600–1000 m | Asphalt | Headland tunnel, open straight run-up, mandatory big jump, generous landing recovery. |
| 1000–1350 m | Asphalt | Technical descent, linked tightening bends and two hairpins. |
| 1350–1950 m | Firm sand | Sandy cove, tightening turns, uneven water crossing. |
| 1950–2250 m | Asphalt | Short stone bridge and shoreline bends. |
| 2250–2550 m | Firm sand | Climbing S-bends, occasional shallow ruts and softer patches. |
| 2550–3000 m | Asphalt | Return to the headland, bends opening toward the finish and rainbow view. |

### Proposed layout values

- Base `road_width = 7.0`, `shoulder_width = 1.25`, `width_blend = 12.0` m.
  Shoulders follow the setting: pale gravel by asphalt, slightly darker sand
  around the cove. No exposed raised ribbon hiding the actual support edge.
- Width stretches `(start, length, road width, shoulder width)`, in metres:
  `(865, 105, 9.0, 1.25)` landing/recovery;
  `(1020, 280, 5.8, 1.0)` descent;
  `(1350, 600, 6.0, 1.0)` cove;
  `(2250, 300, 6.0, 1.0)` sandy climb.
  Width changes must blend and never overlap ambiguously.
- Main grades usually 0–6%; short descent/climb sections may reach 8%.
  Bank gently through fast bends (about 2–4 degrees), not Rock Canyon's
  off-camber shelf. Jump ramp geometry is specified separately.
- Start with sweepers of at least 55 m centre-line radius, technical bends
  around 18–30 m and hairpins around 14–18 m. Adjust from all-car driving and
  camera sightlines; these are not certified minimum turning radii.
- Set sea level at world Y = 0. Cove roads sit roughly 0.6–2 m above it;
  the upper road roughly 18–30 m. Final anchors must make the descent and
  climb fit without unrealistic road grades or self-intersecting terrain.
- Keep `sample_step = 1.0`, `detail_step = 0.25`, `lateral_step = 0.5`,
  `chunk_length = 100.0`; add exact rows at structure/surface boundaries.
  Prefer local detail over raising the sampling density of the whole level.
- Starting ordinary-road undulation amplitude 0.025 m; isolated rough patches
  up to 0.06 m. Pothole radius 0.3–0.8 m, depth 0.025–0.08 m, mostly away
  from the ideal line. Sandy rut depth 0.02–0.05 m. Do not spread these maxima
  over the whole road or compromise the jump's approach/landing.
- Paint restrained edge/centre markings on asphalt where useful; fade them
  before sand. Blend surface colour across roughly 8 m and height continuously;
  the sand may get gradually rougher without a raised seam.

Curve anchors belong in `tools/generate_coastal_highway_curve.gd`, using the
existing curve generator. Do not hand-edit the generated `.tres`. Store these
settings in `levels/coastal_highway/`, with a scene, curve, trail, terrain,
scatter and level resources. Initial anchor coordinates follow in the reviewed
implementation plan; refine them during the jump/sightline greybox before
committing to the final surrounding terrain.

## 4. Structures and the mandatory jump

### Tunnel

Reuse `TunnelDef`/`TunnelBuilder`: proposed start 610 m, length 100 m,
`inner_width = 10.5`, `height = 6.0`, `lamp_spacing = 12.0`, `cover = 8.0`,
`portal_length = 12.0`. Dry, continuous asphalt floor; no hidden wet patch at
the exit. Merge the shell and batch emissive lamps, without per-lamp lights.
Keep the chase camera inside the shell, the terrain above it and portals closed
against daylight leaks. The driver sees the jump well after leaving the tunnel.

### Large jump over a washed-out inlet

Starting prototype, **to be resized around measured all-car trajectories**:

| Part | Proposed station/dimension |
| --- | --- |
| Reset and approach | Reset at 730 m; open straight approach from there to 835 m. |
| Takeoff | 835–853 m; smoothly shaped ramp, about 2.0 m rise over 18 m. |
| Missing span | 853–869 m, initially 16 m. No road, shoulder or hidden ground support. |
| Landing | Starts at 869 m, initially about 1.5 m below the takeoff lip, broad and slightly downhill. |
| Recovery | Landing/recovery continues to 990 m; first demanding bend no earlier than 1020 m. |

The current `TrailDef.jumps` are shaped humps, not true gaps. This feature needs
an opt-in gap definition plus matched ramp/landing profiles, not simply a
larger hump. Taper widths before the lip; the wide landing must already be
available where a car can first touch down. Blend ramp and landing slopes to
avoid a sharp chassis strike. The jump must feel clearly larger than Rally
Road's existing 1.2 m / 12 m jump, without prescribing an untested launch speed.

Remove road, paint, shoulders, earth joins and terrain support through the
opening; close the exposed ground sides. Water below is real water. A failed
jump uses existing water/Reset behaviour, not an invisible floor or a scripted
launch. Show the ramp edge, opposite bank and route clearly; do not hide them
behind spray, a crest, foliage, a checkpoint banner or the tunnel portal.

No puddles, slippery surprise or pothole on takeoff/landing. Preserve a usable
braking/recovery distance. Reset must restore the entire approach, not strand
the car on the lip. The inlet geometry and ordered gates must prevent driving
under/around the jump and still completing the course; verify this physically,
not by assuming an ordered checkpoint automatically proves a jump occurred.
Future shortcuts cannot bypass this section.

**Feasibility gate:** all three cars must clear the prototype reliably from
that reset with a good approach and normal controls, without changing physics,
grip or adding assistance. Record approach speed, airborne distance, landing
position and recovery. Test the owner's usual traction-control setting plus
0%/100% to expose an accidental setup requirement. If the weakest approach
fails, adjust the gap/ramp/landing before building surrounding scenery. Get
owner feedback before polishing it.

### Short stone bridge

Proposed station 2055–2073 m, 18 m long, 7 m clear roadway, low stone parapets
around 0.7 m high outside that width. One arch over the outlet channel; a gentle
deck crest around 0.15 m, no missing logs or dropped half. Proposed deck finish:
asphalt over the stone structure, preserving the approved surface split.

The existing `BridgeDef`/`BridgeBuilder` specifically build logs and a dropped
span. Add an independent `StoneBridgeDef`/builder; do not change those defaults.
The deck, parapets, visible arch and abutments need matching collision where
reachable, sealed sides and no terrain slab plugging the channel. Do not leave
a second road collider under the deck. Keep an unobstructed approach, with no
forced mid-bridge jump. Channel water below must not affect a car on the deck.

## 5. Surfaces, puddles and main water challenges

### Proposed new surface tuning — requires written review

Existing car files, asphalt/dirt/mud values and all existing grip-table entries
stay unchanged. New surface IDs have matching feedback entries; the numbers
below are modest starting values, not a physics change already authorized by
the general design approval.

| New ID | Grip | Rolling resistance | Sink (m) | Drag | Rally multiplier | Off-road multiplier |
| --- | --- | --- | --- | --- | --- | --- |
| `wet_asphalt` | 0.90 | 0.015 | 0.000 | 0 | 1.10 | 0.95 |
| `coastal_sand` | 0.80 | 0.045 | 0.010 | 0 | 1.05 | 1.10 |
| `soft_sand` | 0.70 | 0.070 | 0.025 | 0 | 1.05 | 1.10 |

Wet asphalt retains each tyre type's existing asphalt multiplier, so the
proposed base change is a 10% grip reduction for both. Firm sand starts near
dirt, with a little more rolling resistance; softer sand costs some speed but
must not make the main route a 4x4 clearance test. New IDs add new grip entries,
not edits to existing pairs. Revise new tuning only with the owner's approval.

Use `SurfaceFeel` for subdued road hiss/squeal on damp asphalt and light sandy
spray with existing gravel-style rolling sound on sand. Real water supplies
splash, drag and water sound: do not add a second submerged-water force or fake
spray solely because a dry patch is labelled wet.

### Local patches, not whole-width surprises

Current `SurfaceStretch` selects a full-width surface by distance. Preserve it
for the two sand stretches; add opt-in local surface regions for wet asphalt
and soft sand. Proposed `RoadSurfacePatchDef` data: station/lateral polygon,
surface resource, colour, colour-feather distance and explicit overlap priority.

Partition the same underlying road triangles for rendering and surface lookup.
Do not overlay an elevated mesh or duplicate collider. Where a visible patch
covers only half the road, the other half must retain its own grip. Include
patch boundaries in tessellation where needed and test the threaded and serial
builders. Colour feathering can hide a hard material boundary; it is not a
claim of continuously interpolated physics. Require visually readable support
and surface correspondence through transitions.

Start with about 12 damp-asphalt regions, 4 local soft-sand patches and 10
additional puddles (6 small, 4 larger), not hundreds of separately ticking
objects. Typical damp patches are 4–12 m long and 2–4 m wide; soft patches
5–10 m long, usually with a firmer alternative line. Avoid forced wet-to-dry
surprises at the jump, tunnel mouth and bridge transitions.

### Water placement proposals

| Feature | Approximate location | Proposed starting shape and depth |
| --- | --- | --- |
| Flooded asphalt dip | Around 350 m | 14 m wet length, intended line about 0.10–0.16 m deep, negligible current; broad smooth entry/exit. |
| Sandy crossing | Around 1700 m | 18 m wet length, 3.5 m or wider readable line around 0.18–0.25 m deep, uneven bed, lateral current initially 0.25 m/s. |
| Small puddles | Selected depressions in all suitable sections | Roughly 1–3 m long, 0.015–0.04 m deep. |
| Larger puddles | Selected asphalt/sand bends and dips | Roughly 4–8 m long, 0.04–0.10 m deep, usually partial-road coverage and a clear alternative. |

These depths are relative to the actual local collision bed, not the curve's
centre alone. Around the sandy crossing, adjacent deeper water penalizes a poor
line without hiding the intended one; begin with 0.35–0.45 m beside it and
verify the bed and intake clearances. Deeper sea/channel areas are off-route,
not compulsory long wading. Use waves' actual height in passability checks.

Build genuine depressions with continuous tyre support into and out of water.
Standing water has a level mean surface, clipped to the actual basin, not a
sheet following a sloping road. Damp margins blend into dry ground. Asphalt
puddles are relatively clear; sandy pools cloudier but readable enough to judge
the main line. No painted water above a dry collider pretending to be depth.

Use shared M6A water bodies/queries, bed indexing, drag, current, flotation,
flooding and recovery everywhere a car can reach water. The continuous
**3.00 s** intake-submersion stall delay stays unchanged. Do not declare a
crossing safe just because it is shorter than the stall delay: prove wheel
contact, controllability, exit and recovery with every car at cautious speed.

The existing ford resource includes waterfall-specific geometry. A quiet
Coastal crossing/puddle needs a small dedicated basin definition and builder,
not an assumed zero-height waterfall hack. Proposed `CoastalWaterAreaDef`:
stable ID, footprint, mean level, basin/depth authoring data, current vector,
water appearance and wave eligibility. It must register with the level's one
`WaterWorld`, sharing the actual bed source rather than making one per puddle.
Avoid overlapping bodies with competing currents or ambiguous surface heights.

### Waves and sea: bounded scope

The eventual level should use the approved ambient/entry/bow/wake behaviour,
including slight flotation/intake effects, without changing its strength or
shared CPU/GPU maths. This is a **planned timed-level rollout requiring separate
authorization**, not permission to enable it now. Depth/shore limits naturally
keep small puddles subtle; don't add a new breaking-surf or tide simulation.

Refine playable water areas, not an entire horizon-size sea at 0.75 m pitch.
Use a bounded coastal basin and budgeted near-water meshes; distant sea can
have coarser presentation only with a credible, tested boundary to playable
detail. Any water the car can reach still needs valid depth/forces and queried
heights agreeing with its drawn triangles. Never hide missing physical water
behind a visual ocean. Global phase, continuous appearance and contact at mesh
boundaries need explicit tests; the exact basin extent/LOD solution belongs in
the implementation plan and an early phone feasibility check.

Keep the existing bounded source policy (16 travelling packets plus bow), not
16 new sources per puddle. Bind through a level-specific adapter to shared
water/wave components after final body registration. `WaterWorld.clear()` on
rebuild must invalidate old bindings; Reset, pause, car change and level exit
must leave no stale waves, forces, audio or callbacks. Package/validate topology
ahead of time where applicable, behind the loading cover on first use. No
runtime mid-drive mesh bake or silent lower-quality fallback.

## 6. Coastal terrain, protection and presentation

Shape a recognisable coast independently of the nearest road station: layered
headlands, rounded pale cliffs, coves and a channel outlet. Do not stretch a
mountain sideways to touch the road or let adjacent hairpin stamps fight over
the shoreline. The road follows the land, with believable cuttings, embankments,
closed cliff/bridge/gap faces and continuous road-to-ground joins.

Add an opt-in coastline/basin earthworks resource if existing terrain cannot
express this. Proposed authoring inputs are sea level, shore outline, land/bed
heights and blend widths, followed by local structure cut-outs. Empty/default
data must preserve existing terrain exactly. Preview the wide bay early: long
sightlines can render more terrain than the other levels even with fewer props.

Protection is selective, not a continuous fence. Proposed fast exposed spans
include roughly 80–250 m, 440–570 m and 2700–2860 m, subject to the actual
seaward side and sightlines. Use some stone wall runs for variation. Technical
descent/cove corners may be open, with a visible edge and appropriate sightline.
Bridge parapets remain continuous. No rail across the jump or road; no hooked
rail ends inside the driving width. Visible barriers have simple matching static
collision. Batch repeated pieces; do not make each stone a rigid body.

Proposed look: asphalt RGB `(0.27, 0.28, 0.29)`, damp asphalt
`(0.18, 0.20, 0.21)`, firm sand `(0.72, 0.66, 0.49)`, damp sand
`(0.53, 0.49, 0.37)`, pale rock `(0.69, 0.68, 0.61)`. Tune together under the
actual lighting so colour communicates grip and depth, not just decoration.
Use sparse coastal scrub/grass, occasional wind-shaped trees and static rocks
off the main line. Keep foliage out of water, tunnels, the jump sightline and
future shortcut reservations. No loose-stone simulation in the initial track.

Reuse the existing mood setup with a level-specific resource/configuration:
proposed sun elevation 24 degrees, colour `(1.0, 0.94, 0.83)`, energy 1.15,
sky top `(0.40, 0.58, 0.73)`, horizon `(0.78, 0.83, 0.84)`, fog density 0.0025
and shadow distance 80 m. Add restrained cloud shapes if needed; no volumetric
storm/rain or weather cycle. Test exposure/readability entering and leaving
the tunnel before final colour approval.

Rainbow: one soft procedural arc/mesh across the far bay, behind terrain by
normal depth testing, no collision, shadow or light. Align it opposite the
sun and compose selected road views plus the finish around it. A subtle arc,
not an opaque billboard or a visibility toggle at each checkpoint. Keep its
transparent overdraw small; no simulation is required to explain clearing rain.

Quiet coastal wind/sea ambience plus existing vehicle/water feedback is enough.
Avoid one sound player per puddle. Any new synthesized looping audio retains
`SoundSynth.LOOP_PAD = 32`; players stop on exit and respect volume/pause.

## 7. Checkpoints, progression and future shortcuts

Proposed checkpoints: **730, 980, 1330, 1600, 1970, 2240 and 2570 m**.
They give a full jump run-up after Reset, confirm landing after recovery, and
avoid replaying huge sections after a water/corner mistake. Keep the 1600 m
reset on dry sand before the crossing. Gates use actual road/profile height
and width; don't put one in a puddle, under the arch or in the airborne path.

With ordinary start/end margins of 10 m, a nominal 3,000 m curve gives about
2,980 m between start and finish. Reset keeps elapsed time; no new automatic
drowning reset or penalty system. Add Coastal Highway after Rock Canyon in
the timed catalog only for the authorized playable release; preserve existing
IDs, progress and unlock rules. Prototype playtests must not overwrite saves.

**Star thresholds remain unset in this design.** Collect real owner runs before
choosing them. The 3–4 minute pacing intention is not a scoring configuration;
do not ship zero/placeholder thresholds as final stars.

Reserve these possibilities on the layout only, all after the mandatory jump:

| Future corridor | Approximate entry → exit | Later intended obstacle |
| --- | --- | --- |
| Cove bend cut | 1440 → 1560 m | Deeper mud inside a long bend. |
| Sandy ascent cut | 2300 → 2470 m | Short, steep rocky climb skipping turns. |
| Upper gully cut | 2600 → 2720 m | Muddy gully with clearance-demanding rock steps. |

These are candidate spaces, not three promised shortcuts. Ensure there is room
without a driveable accidental cut, and don't place a mandatory checkpoint
inside a future bypassed segment. Initial build includes **no shortcut road,
collision path, mud trench, active stones or entrance signs**. Later, test that
physical traction/clearance obstacles make a genuinely useful 4x4 alternative;
do not promise exclusivity from these labels or add a car-selection lock.

## 8. Data/build boundaries

Reuse the existing level-as-data pipeline. Proposed additions are narrowly
opt-in: a true road-gap definition, stone bridge, local surface patches, quiet
water basins, coastal terrain shape and selective barrier spans. Resource names
above describe contracts for planning; they do not claim these classes exist.
Do not fold log-bridge/ford changes into global defaults to imitate new features.

Their generated geometry must participate in the same road/terrain collision
and water-bed authority. New stone bridge and basin support cannot be omitted
from bed registration; conversely a bridge above water is not the underwater
channel bed. Inspect and test this explicitly when extending `TrailLevel`.

Keep worker inputs as flat snapshots and identical serial/threaded maths; no
calls to one shared GDScript object from worker threads. Create nodes/shapes
on the main thread. Measure build phases separately. New features default to
empty so all existing generated geometry remains identical. Typed GDScript,
tabs, deterministic seeds and unit tests accompany each later feature commit.

## 9. Performance and acceptance policy

These are requirements/proposals, **not results**. No Godot, phone run or new
performance measurement was made while writing this spec.

- Retain the level envelope: **under 300,000 submitted primitives, under 150
  draw calls, 60 FPS on Xiaomi 13, level build under 3 s**. Count shadows and
  water passes, not just unique mesh triangles. Report loading-cover duration,
  first-use preparation and warm/repeat loads separately; moving work behind
  a cover does not erase its cost or accept a load-budget miss.
- Retain numerical whole-frame checks for proposed Coastal validation:
  average >=59 FPS, p95 <=18.5 ms, p99 <=25 ms. Investigate every >33.3 ms
  interval, including dry/control cases. Do not filter maxima or explain all
  spikes by the historical scheduler finding.
- **Coastal's absolute total-water CPU ceiling needs explicit agreement before
  implementation.** Use the preceding 4 ms/frame p95 / 5 ms/frame p99 policy
  as a conservative planning allocation until then, not a claimed achievable
  result. The owner's 6/7 amendment is Test Ground-only; importing it here
  requires approval. Fit baseline water plus waves, queries, emitters, uniform
  uploads and water-attributable feedback inside the chosen per-frame total,
  summing all physics ticks in each rendered frame without double-counting.
- Preserve the outstanding GPU increment limit of +0.50 ms p95 in matched
  views unless explicitly amended. Report absolute GPU/frame costs too.
  Existing M6W CPU/GPU failures are not accepted headroom for this level.
- Water preparation must stay within the existing 250 ms allowance, with
  asset loads/first-use waits reported separately and inside total load timing.
  Preserve the wave-owned memory limit of 16 MiB (CPU+GPU estimate), source
  bounds and other setup checks, not just the FPS figure.
- Use normal-speed, thermally warmed, balanced/reversed-order comparisons,
  identical scene/camera/car poses and retained build/APK hashes. Separate
  dry baseline, water without waves, Car waves and Full. Match topology when
  attributing GPU cost, and never infer total water from controller-only time
  or by subtracting unrelated percentiles.
- Early worst views: tunnel exit + sea + jump, landing, full cove/crossing,
  stone bridge/channel, and headland finish with rainbow. Measure all cars,
  live driving, source saturation, lifecycle changes and a warmed soak. Reuse
  the existing trace tooling for long frames; preserve failed attempts too.

Use merged/chunked geometry, MultiMeshes, bounded transparent water detail and
visibility ranges appropriate to sightlines. Do not spawn decorative dynamic
bodies or rely on an increased triangle/draw-call allowance. If early phone
checks fail, report the cost split and propose changes; do not silently shrink
approved waves, simplify their queried heights or raise a limit.

## 10. Verification and owner checkpoints

This is the acceptance outline, not the implementation task plan. Once building
is authorized, stop at cheap-to-change driving checkpoints:

1. **Greybox feasibility:** all-car jump approach/landing and reset; wet/firm/
   soft surface samples; shallow crossing bed. Owner tries the jump and surface
   contrast before scenery or the rest of the route is polished.
2. **Opening 0–1000 m:** flowing cliff road, flooded dip, tunnel and jump in
   context. Check sightlines, weather and selective protection with the owner.
3. **Descent/cove/bridge:** technical turns, water depth/current, transitions
   and stone bridge. Owner judges difficulty and line readability before finish
   polish. Run early authorized phone checks here, not after all art is done.
4. **Whole route:** sandy climb, headland and rainbow, checkpoints and normal
   runs with all cars. Then owner star-time choice and final phone/reviewer
   acceptance. Future shortcuts are a separate later design/build pass.

Later automated coverage must include:

- Patch footprint/priority/edge surface identity; no overlapping road collider;
  colour/height joins; exact start/end rows; serial/threaded equivalence.
- Empty new feature arrays leave old roads, terrain, collision and RNG output
  unchanged. Existing geometry/build-details and car-balance fixtures pass
  **without re-recording or relaxing** them.
- True absence of support in the jump gap, correct landing/ramp contact,
  underside/side cut-outs, safe reset and mandatory-route bypass attempts.
- Tunnel shell/floor/portals/camera; stone deck/arch/parapet collision, no
  filled channel or duplicate deck; barrier ends and exposed-edge fidelity.
- Real puddle/crossing depths at multiple lateral samples, no sloping standing
  water, no unintended body overlap, current direction and all-car slow exits.
  Bridge deck stays dry even above a water body.
- Sea and refined-mesh seam correctness; CPU query versus actual GPU/drawn
  triangle height within the existing **1 mm** gate on a real renderer. A
  headless dummy backend is not a GPU parity pass. Re-run the verifier if
  shared wave maths or its integration changes.
- Bounded source and body counts; Reset, pause, mode/debug controls, car swap,
  level exit/re-entry and repeated loads clear bindings/effects/audio. Save
  data and existing catalog progression remain intact.
- Full `./run_tests.sh all`, no `SCRIPT ERROR`, with output, exit status and
  any inherited pending test recorded. A past M6W suite pass is not a new M6B
  result. Never run it or captures while the owner is playing.

Final implementation report: `docs/notes/codex-report-m6b-coastal.md`, focused
feature commits, reproducible evidence, owner feedback and unresolved gates.
Stop for Claude/owner review, no merge or push.

## 11. Out of scope and decisions still needed

Out of scope: building the reserved shortcuts now, new cars/snorkel art, car
physics changes, active rain, dynamic weather/tides, breaking surf, reflected
waves, aquaplaning/skimming, floating debris, native water rewrite and changes
to existing levels. The historical hitch is a separate deferred investigation,
not something this level fixes or conceals.

Before implementation planning is finalized, review the written proposals for
jump geometry, widths/depths, new surface values, stone-deck finish and the
absolute Coastal water allocation. The principal risks are all-car jump
feasibility, long coastal sightline/sea cost, actual wet-line readability and
new opt-in builders preserving existing geometry. Prototype and measure those
before polish; exact tuning and star times follow actual driving, not estimates.

---

## 12. Reviewer questions for the owner (Claude, 2026-09-27)

Four decisions worth making **before** an implementation plan, because each one
is cheap now and expensive to discover at the end of a build. The owner has
parked them deliberately: finish Milestone 6's outstanding work first, then
return here. None of them disputes the approved design direction.

### 12.1 The 3 s load budget looks unreachable as written

§9 keeps "level build under 3 s". Rock Canyon is **2.1 km and builds in 3.9 s**
on the owner's Xiaomi 13 — already after the build-speed refactor inlined the
sampling path, with only engine-side node and collision creation left. Coastal
is **3 km** plus a tunnel, stone bridge, gap jump, sea, waves, crossings,
puddles and roughly 26 surface patches.

So this level would start against a target its closest relative misses by 30% at
two-thirds the length. Options, in the owner's gift: raise the budget for large
levels; use the **deferral lever** recorded since Milestone 5 and still untried
(Rock Canyon builds its 1500 m shelf, stones and boulders — about 1.45 s — before
the countdown, though the player needs about 90 s to reach them); or make Coastal
shorter. The spec discusses loading covers, which do not remove cost; deferral is
a different idea and would help both this level and Rock Canyon.

### 12.2 Four new subsystems in one milestone

A true gap jump (the existing `TrailDef.jumps` are humps), a stone bridge
builder, `RoadSurfacePatchDef` (which touches road tessellation *and* the
threaded builder), and coastal water with sea and waves. Each is comparable in
size to a Rock Canyon feature; together, at 3 km, the review surface at the end
would be very large. Milestone 6 has already shown what a long unreviewed run
costs.

Suggested split, along the natural seam: **B1 = route, tunnel, jump, bridge**
(the driving), **B2 = water, patches, sea** (the wetness). B1 alone is a
playable level the owner can judge.

### 12.3 Coastal's water ceiling defaults optimistically

§9 correctly declines to assume a figure and asks the owner to set one, but
suggests planning at 4 ms/5 ms meanwhile. The **flat Test Ground needed 6/7**.
Coastal carries far more geometry plus open sea. Setting a number that is
believed now is better than amending it under pressure later, as happened twice
in M6W.

### 12.4 The branch stack is four deep

`m6b-coastal-design` ← `m6-hitch` ← `m6-water-waves` ← `m6a-water-physics` ←
`master`, none merged. This design branch is documentation only, so it costs
nothing; building Coastal on that foundation is the risk, since hitch work could
still move M6A underneath it. The owner has playtested A and W and Claude has
reviewed both. Merging them before building B — or consciously deciding not to —
removes that risk.
