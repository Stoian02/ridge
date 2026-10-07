# M6B1 — Coastal Highway driving implementation plan

2026-09-27 plan; **owner approved, implementation started 2026-10-06**.

Execution record: [first-delivery jump report](../../notes/m6b1-jump-feasibility.md).
The owner confirmed 15–20% TC; test both endpoints plus 0% and 100%.
Tasks 0–2 are implemented; **the owner approved the revised Task 3 jump on
October 7 and authorized continuing**. Its geometry is now the accepted baseline.
October 6 delivery: 813 passing, one inherited pending, no script errors.
October 7 owner feedback requested more airtime and clarified lift-and-balance
driving. Revision `0efa994` increases the gap to 18 m and landing drop to 2 m;
the approach and cars are unchanged. The test-only driver can now apply ordinary
pedal pitch corrections: 36 controlled and two off-centre cases passed focused
checks. Twelve held-throttle and twelve uncorrected-coast cases remain recorded
stress observations, **not** clean-landing acceptance. Three normal-speed PC
smokes passed. Fresh full regression: **814 passing, one inherited pending,
no script errors**, exit 0. Phone checks remain unmeasured. The report preserves
the changed test scope and rejected geometries.
**Task 4 is implemented and PC-verified; Tasks 5–8 have not started.**
Final structure regression: 823 passing, one inherited pending, no script errors.
The original task detail
below remains the reviewed plan, not a claim that every acceptance check is done.
Geometry iterations are recorded in the report rather than rewriting the
initial proposals into apparent first-try successes.

## Task 4 execution record — 2026-10-07

Owner authorization: “I approve of this part, we may continue.” The accepted
18 m gap, 2 m drop, 7% landing, 10° lip and 730 m reset remain unchanged.
This delivery covers **structures only**, not Tasks 5–8 or completed B1.

- Tunnel at **610–710 m**, 10.5 m inner width, 6 m ceiling, 8 m ground cover,
  eight batched lamps at 12 m spacing and dry portals. Reuses `TunnelBuilder`;
  no individual light nodes or new tunnel subsystem. Commit `bd3f57d` authors
  the tunnel and extends the test driver to traverse it from the actual course
  start, in addition to the accepted stationary-reset matrix.
- Stone bridge at **2055–2073 m**, 7 m clear asphalt deck, 0.7 m parapets,
  0.15 m smooth crest, 12 m clear arch and 3 m solid abutments over a **dry**
  5.5 m-deep channel. `StoneBridgeDef`/`StoneBridgeBuilder` are independent of
  logs. The ordinary road, shoulders and earth joins are omitted across the
  bridge; matching visible collision is supplied by two batched meshes/bodies.
  Earthworks clear grid-corner/diagonal footprints before terrain commit.
  The new phase is reported as `stone_bridges`; rebuild discards its old nodes.
- Rendered inspection caught earth-join strips rising toward the tunnel roof.
  `TunnelDef.omit_earth_joins` is **false by default**, enabled only for Coastal.
  Both join paths omit whole cells through its portals; exact boundary rows and
  colliding floor returns outside the existing shoulders close the opening.
  Frozen Pass retains its original tunnel/log builders and geometry defaults.
- No car/surface tuning, curve change, B2 water/bed registry, sea, local wet
  patches, waves, sand implementation, scenery or scoring was added. No merge
  or push. The greybox terrain/palette around the structures is not final art.

### Driving evidence and control caveat

The reset driver is unchanged from the owner-approved jump: normal gas/brake
pitch correction, no force/velocity injection and no player assist. The new
course-start driver takes the opening bends conservatively (at most 25 m/s),
then accelerates **without a speed cap from 580 m through the tunnel/run-up**.
It tests all three cars at 0%, 15%, 20%, 100% TC. Launch speeds are consequently
higher than Reset: about 117 km/h Rally, 133 km/h Tuned Rally and 93 km/h 4x4.

The first course-start Tuned Rally at 100% TC reached recovery, but its chassis
strike at about 914 m produced **21.7°/s yaw**, failing the unchanged 20°/s gate.
A 0.15 s delay before restoring drive torque did not fix it (21.96°/s) and was
removed. A documented **2° nose-up target bias for course-start tests only**
passed the complete matrix (`tunnel-3.log`, 14 tests / 1,297 assertions). All
camera maxima were under 3.03 m above the floor, with zero tunnel chassis hits.
This is normal pedal control in an automated driver, **not** an automatic game
feature, a soft-landing guarantee, or renewed owner approval of the faster
approach. The initial failure logs remain available; car physics and the
approved jump geometry were not changed to make the test pass.

Bridge tests (`structures-1.log`) cover all three cars at 6 and 20 m/s target
speed plus two ±2 m offset 4x4 approaches, using the real 1970 m checkpoint.
All eight kept four wheels in contact, zero chassis contacts, asphalt surface
IDs, no resets and upright recovery. Rays independently verify flush joints,
the arch aperture/ceiling/floor and parapets; excluding the first hit confirms
there is no duplicate near-deck support. Serial/threaded road/join outputs match.
Rebuild frees the previous bridge mesh. Final focused bridge/preview tests:
**7 passing / 18,424 assertions**, 0.548 s. The corrected tunnel-return selector
ran **one test / 74 assertions**, 0.972 s. Both exit 0 with no script errors.
The final full suite reran this driving after the floor-return correction.

### Retained failures and verification discipline

- `bridge-import.log`: the sandbox blocked editor sockets/ADB; the escalated
  import retry completed. This was not a game failure or phone measurement.
- `bridge-unit-1.log`: a missing explicit `WeakRef` type prevented a new test
  from loading. GUT's green summary for the other tests was **not** a pass.
- `bridge-unit-2.log`: exact mesh/collider array equality failed because drawn
  positions are quantized on mesh storage. The measured maximum was
  **0.000082066 m**; the new test now checks matching vertex counts and a
  **1 mm geometric tolerance**, alongside independent actual physics rays.
  This changes only the new bridge test, not any protected fixture.
- `tunnel-returns.log`: an incorrect GUT selector ran no tests. It is retained
  as invalid evidence, not counted as a pass; `tunnel-returns-valid.log` uses
  `-gunit_test_name=tunnel_cover` and verifies that case.
- `full-suite-failed-aborted.log`: assigning a typed tunnel array through a
  dictionary's dynamic property failed in the expanded parity fixture. The
  already-failing run was stopped by terminating only our identified Godot PID;
  its log and exit 1 are retained. `81f368f` uses an explicit `TrailDef` local;
  focused parity passed before restarting the full suite. No assertion changed.
- `full-suite-teardown-aborted.log`: the next combined run stopped producing
  output after the unchanged Rally Road test printed the 4x4's finish. It stayed
  there for several minutes with its main thread using a CPU core and no other
  Godot process running. Only our identified runner was terminated (exit 143).
  No stack trace was available (`gdb` was not installed), so teardown/audio is
  **not a confirmed cause**. The isolated unchanged Rally Road test then passed
  in 18.941 s (`rally-teardown-repeat.log`, exit 0, no script errors). The final
  combined rerun uses the same source and fresh isolated save/config roots;
  the stalled run is retained, not counted as passing evidence.
- Initial `view-*` captures show the tunnel slivers; `final-view-*` show the
  opt-in correction. Fixed views disable driving, so their draw counts are
  rendering diagnostics only, not driving/frame-time acceptance.

The phone was checked and **no device was attached**. No APK was built or
installed, and no phone budget is claimed.

Final rendered PC checks (Radeon 890M / Vulkan Forward Mobile, 1280×720,
normal speed, isolated saves, TC 20%): **all six drives passed**, three
course-start-to-jump and three bridge crossings. Course peaks were **133 draws /
209,042–209,522 primitives**; bridge peaks **116–118 draws / 141,162–143,894
primitives**. Trail-build times were **0.908–0.937 s**. These short desktop
smokes do not establish whole-frame percentile, five-minute soak, whole-route,
phone or B2 headroom gates. All six reported an empty water world.

The corrected fixed-view capture (`pc-views-2.log`) measured:

| View | Draws | Primitives |
| --- | ---: | ---: |
| Tunnel entry | 98 | 158,302 |
| Tunnel interior | 101 | 168,024 |
| Tunnel exit | 99 | 163,620 |
| Jump | 87 | 186,796 |
| Bridge deck | 73 | 136,380 |
| Bridge arch | 74 | 131,116 |

Review commits: `bd3f57d` tunnel/course-start driver; `f1e3a45` independent
stone builder/collision/join correction and tests; `08ae44b` manual bridge
preview and rendered capture tooling; `81f368f` typed parity-fixture correction.
Final regression on frozen **`81f368f`**: **823 passing, one inherited pending,
624,470 assertions across 133 scripts, 623.793 s, exit 0**, no `SCRIPT ERROR`
or `ERROR:`. The inherited pending case is the existing held-gas kicker landing;
no test was skipped or relaxed for this delivery. The earlier Rally Road stall
did not recur in either its isolated repeat or this complete run. No Godot
process remained afterward. Protected hashes and `git diff --check` passed;
the car files, existing surfaces, protected balance/fingerprint tests and four
existing level directories have no diff from merged master `b075946`.
Documentation/evidence follow in a separate commit.

### Preview and repeat commands

```sh
# Complete opening, tunnel and accepted jump, manual controls:
godot --path . res://debug/coastal_playcheck.tscn -- start=course
# Direct bridge preview from the real 1970 m checkpoint:
godot --path . res://debug/coastal_playcheck.tscn -- start=bridge
# Original jump Reset preview remains the default:
godot --path . res://debug/coastal_playcheck.tscn
```

For automated checks, isolate saves/settings, keep the owner's game closed,
and omit `--fixed-fps` for rendered measurements:

```sh
XDG_DATA_HOME=/tmp/ridge-coastal-review-data \
XDG_CONFIG_HOME=/tmp/ridge-coastal-review-config \
godot --path . --resolution 1280x720 res://debug/coastal_playcheck.tscn -- \
  mode=smoke start=course car=rally_tuned tc=0.20 balance=true
# Substitute start=bridge for its ordinary-input crossing smoke.
# mode=views capture=/tmp/coastal saves six fixed views; headless is refused.
```

Evidence joins the existing `docs/notes/m6b1-jump-data/` package as
`structures-2026-10-07.tar.gz` and `structures-source.sha256`. The older jump
archives/manifests remain immutable. See that directory's README for verification.

## Authority, scope and delivery stops

Follow the approved [design, especially §13](../specs/2026-09-26-m6b-coastal-highway-design.md)
and [B1 handover](../../notes/handover-codex-2026-09-27-coastal-b1.md).
Work on existing branch **`m6b-coastal-highway`**, currently `0a119c5`, based on
merged master `b075946`. No merge or push. No new branch stack is needed.

Milestone 6 is accepted/merged. Its hitch is **closed as platform behaviour**;
the [phone report](../../notes/m6-hitch-phone-reproduction-2026-09-27.md)
preserves the inference and historical limitations. Do not repeat that
investigation without evidence of a different shape. Accepted Test Ground
synthetic CPU/GPU misses remain recorded optimisation targets, not spare Coastal
headroom or permission to waive its own gates.

| B1 builds | B1 deliberately does not build |
| --- | --- |
| Approximately 3 km route, dry asphalt/sand, shoulders and checkpoints | Flooded dip, wet crossing, puddles or local surface-patch system |
| True mandatory gap, tunnel and short stone bridge | Sea mesh/bodies, wave binding, coastal water queries or new water feedback |
| Land/cliff geometry, selective barriers, scrub, lighting and rainbow | Active rain, dynamic weather, waves on timed levels |
| New approved surface resources and additive grip/feel entries | Retuning any car or existing surface/grip entry |
| Reserved space for future water and shortcut corridors | Driveable shortcuts, deep-mud cuts, loose stones, car locks |

B1's future inlet, outlet channel and bay are visibly **dry preview terrain**.
There is no decorative blue plane pretending to be physical sea, and no wet
grip applied to a dry road merely to preview B2. Reserve water stations and
space; don't implement the flooded/crossing beds or patch tessellation early.
The cliff, jump void and bridge channel need physical land shaping in B1,
but water-specific bed/shore work belongs to B2.

**Sequence:** plan approval → route greybox + gap → all-car feasibility →
**owner drive and explicit feel approval** → structures/surfaces → presentation
and full-route feedback → B1 phone acceptance/review. Then stop. B2 needs its
own plan and starts only after B1 is reviewed and actually merged with the
owner's authorization.

The jump gate blocks all later feature work, not just the final art pass. Do not
use time awaiting owner feedback to build scenery, bridge, tunnel or B2.

## Task 0 — safe baseline and reproducible checks

Before implementation, not as part of writing this plan:

- [ ] Confirm branch, named working-tree changes and merged ancestry. Preserve
  the existing untracked import files, `tools/__pycache__/`, `tmux-session.sh`
  and any owner modifications; never touch `project.godot` or discard changes.
- [ ] Confirm no owner game/test is running with `ps -eo pid,etime,args` and
  `rg '[gG]odot'`. Coordinate play windows; never kill the owner's process.
- [ ] Record source revision and hashes of protected geometry/build-details
  and car-balance tests plus existing car/surface resources. Run an isolated
  baseline `./run_tests.sh all`; retain log/exit status. The handed-over 799
  pass/one pending result is historical, not a newly executed baseline.
- [ ] Record the owner's usual TC percentage. It has been requested; do not
  equate the default/saved value or a guessed 50% with their answer. If still
  unknown, 0%/50%/100% can be exploratory coverage, but the owner-setting gate
  remains incomplete until confirmed. Avoid persistent settings changes in
  automated fixtures; use explicit car overrides and runtime-only TC inputs.
- [ ] Set up a dated `runs/` evidence directory for source/configuration hashes,
  attempts and logs. Keep failed iterations, not just the winning ramp.

All new code is typed GDScript with tabs. New classes require import before
tests; the suite wrapper already imports. Accelerated headless runs establish
correctness, **not** performance. Use normal-speed rendered runs for feel and
wall-clock measurements.

## Task 1 — dry, undecorated route greybox

**Files:** new `tools/generate_coastal_highway_curve.gd`,
`levels/coastal_highway/coastal_highway.tscn`, generated
`coastal_highway_curve.tres`, `coastal_highway_trail.tres`,
`coastal_highway_terrain.tres`, `coastal_highway_scatter.tres`;
new `tests/unit/test_coastal_route.gd`.

- [ ] Use `CurveGenerator.build_curve`/its separation checks; encode every
  anchor through generator data, not edits to the saved curve. Start with these
  station bands and keep explicit cumulative-length/grade diagnostics:

  | Station | Dry greybox layout |
  | --- | --- |
  | 0–600 | Asphalt sweepers/crests; reserve the 350 m dip, without water shaping. |
  | 600–1000 | Reserve 610–710 tunnel; straight 730–835 approach; gap/landing/recovery to 990. |
  | 1000–1350 | Descent, linked tighter turns and two separated hairpins; no demanding bend before 1020. |
  | 1350–1950 | Firm-sand cove alignment; reserve crossing at about 1700. |
  | 1950–2250 | Asphalt shoreline bends; reserve 2055–2073 bridge. |
  | 2250–2550 | Firm-sand uphill S-bends. |
  | 2550–3000 | Asphalt headland finish. |

- [ ] Fit the 3D baked length near 3,000 m (target within 5 m) by adjusting
  noncritical connecting straights. Do not globally rescale a validated ramp,
  gap, turning radius or structure station to force the total. Keep nominal
  sand bands 1350–1950 and 2250–2550; report actual surface lengths.
- [ ] Start with the spec's widths, grade envelope and radius ranges. Keep the
  road far enough from itself for the unchanged separation check and a natural
  hill between hairpins; do not lower that check to force a layout through.
- [ ] Express the proposed elevation datum in generator coordinates: current
  `CurveGenerator` starts at Y=0. Apply a Coastal-only translation to the built
  curve (initial upper-road height about 24 m), preserving handles, then save.
  Keep the Path3D transform identity as required by `TrailLevel`; don't change
  the shared generator's default or another level's coordinates.
- [ ] Use existing asphalt and temporary dirt placeholders for the future sand
  in this first mechanical greybox. No wet patches, extra surface system or
  new tuning before the jump gate. Label the dry/placeholder status clearly.
- [ ] Compose the standard `RunLevel`/`DrivingRig`/checkpoint/reset nodes.
  Checkpoints start at 730, 980, 1330, 1600, 1970, 2240, 2570 m, with start/end
  margins of 10 m. Put the 730 m reset on the straight, at rest and correctly
  aligned, before the whole run-up. Checkpoint banners cannot obscure landing.
- [ ] Build only neutral-lit road, essential terrain/collision and functional
  checkpoint markers. Disable scatter/posts and omit decorative sky, rainbow,
  tunnel shell and stone structure. Do not install a temporary collider across
  the jump and present it as playable: Task 2 must replace that span first.

**Check:** deterministic generated curve, length/surface-band arithmetic,
separation, grade/sightline constraints, reset transforms, no water body/wave
runtime, no accidental shortcut corridor or intersecting road legs. The full
route is inspectable, but it is not yet the final driveable level.

**Commit:** `Add Coastal Highway dry route greybox`.

## Task 2 — true gap and matching ground/collision

**New files:** `levels/trail/road_gap_def.gd`, `gap_builder.gd`,
`tests/unit/test_road_gap.gd`.

**Scoped integration:** `trail_def.gd`, `road_profile.gd`, `road_builder.gd`,
`road_blend_builder.gd`, `terrain_field.gd`, `trail_earthworks.gd`,
`trail_level.gd`; touch `road_chunk_data.gd`, `road_height_data.gd`,
`road_blend_data.gd` or `terrain_builder.gd` only where new immutable data/cut
support actually requires it. All paths here are under `levels/trail/`.

- [ ] Add `TrailDef.road_gaps: Array[RoadGapDef] = []`. Proposed initial data:
  `takeoff_start=835`, `takeoff_end=853`, `landing_start=869`,
  `landing_end=929`, `recovery_end=990`, `rise=2.0`, `landing_drop=1.5` m,
  `lip_angle_deg=14.0`. The 730 m reset remains checkpoint data. Add explicit
  cut width/depth and side-face settings; require an empty/valid ordered span,
  finite values, no overlap with another structure or surface transition.
- [ ] Define one canonical longitudinal profile for the new ramp and landing,
  shared by road sampling, collision, terrain clearances and debug probes.
  Start the ramp tangent to the approach and finish with an **upward lip
  slope**, not the zero-slope top of `smoothstep`. A Hermite profile can specify
  both endpoint slopes. Keep landing's initial height 1.5 m below the lip,
  gently downhill, blending into the ordinary profile before recovery ends.
  All these geometry values remain adjustable from measurements, not car data.
- [ ] Correct the proposed landing-width timing: with 12 m blending, starting
  widening at 865 m does not reach 9 m by 869. Start it at **857 m** instead
  (`Vector4(857, 113, 9, 1.25)` as the initial replacement), so the landing
  already has full width. Verify the sampled width, don't trust the numbers
  without testing the actual easing function.
- [ ] Add exact rows at ramp/lip/gap/landing/recovery boundaries. Extend row
  omission for the new gap in serial and threaded road paths, including paint
  and shoulders. Existing log bridges retain their old path and surface IDs.
  Keep `surface_at` usable as an authored route hint, but never confuse it with
  proof of ground contact in the missing span.
- [ ] Earth joins must also omit whole gap cells, including endpoint cells.
  Zeroing only a row's blend width can leave a sliver across the opening; use
  an explicit segment exclusion in both paths and test it.
- [ ] Cut the supporting terrain and prevent coarse triangles from bridging
  the void. Prefer existing height-field earthworks where a sufficiently deep
  cut is adequate; use an opt-in cut mask/cap only where required. The existing
  portal-hole path is a reference, not permission to alter old tunnel masks.
  Recompute lowest height after new cuts. Close exposed bank/shoulder faces
  with visible static collision and a distinct dry ravine floor well below
  flight clearance; there is no near-deck invisible floor or ramp.
- [ ] Validate both sides/underside: a car must not crawl around or through
  supporting terrain and reach the landing gate. Give failed jumps existing
  manual Reset/kill-height behaviour, not a new automatic failure mechanic.

**Tests:** finite/profile endpoints and slopes; exact boundary rows; sample
left/centre/right support on approach/landing and absence through the opening;
no high terrain triangle crossing the void; consistent caps/collision; banked,
rotated and chunk-boundary fixtures; no blend slivers; invalid overlap rejection;
byte/geometry-equivalent serial/threaded outputs. Existing humps/log bridges and
all protected fingerprints/build-details remain unchanged with empty arrays.

**Commit:** `Add opt-in road gaps with aligned terrain and collision`.

## Task 3 — jump feasibility, then mandatory owner stop

**New files:** `tests/scenarios/test_coastal_gap.gd`,
`tests/scenarios/coastal_driver.gd` (test-only if needed),
`debug/coastal_playcheck.gd`/`.tscn`,
`docs/notes/m6b1-jump-feasibility.md` and retained evidence.
Add a debug-only, consumed one-shot `coastal_playcheck` flag in
`ui/main_menu.gd` for phone entry, with focused flag/option tests. Existing
one-shot flags and normal startup keep their semantics.

- [ ] Fixtures explicitly select Rally, Tuned Rally and Off-road 4x4 from their
  `CarDef`s; never inherit the selected save car. Start each at rest using the
  **actual 730 m reset transform and reset path**, not a magic launch velocity.
  Use only ordinary virtual steer/throttle/brake inputs after placement.
- [ ] Test each at TC **0%, owner-usual, 100%**, three fresh attempts per unique
  combination. That is 27 attempts if all settings differ; if usual duplicates
  an endpoint, record the overlap rather than pretending it adds coverage.
- [ ] Use a common, documented driving strategy. Check throttle-release at the
  lip and held-throttle behaviour: the older kicker has a known held-throttle
  pitch pending test. Do not quietly inherit a pending/relaxed assertion for
  this mandatory jump, disguise a crash with selective inputs, or add hidden
  gameplay assistance. Resolve geometry first; bring any unavoidable control
  caveat to the owner before declaring feasibility.
- [ ] Record starting pose/TC/car, approach and lip speed, contact count,
  airborne duration/distance, min pitch/up-vector, first landing point, yaw,
  chassis hits, reset events and ability to continue to 990 m upright. Require
  a genuine unsupported flight across the span, landing on visible roadway,
  no teleport/reset, no roll or chassis wedge, and controllable recovery.
- [ ] Run failed approach, stopped-on-approach, Reset-after-fall, off-centre
  launch, edge-approach and attempted bypass cases. A poor attempt may fail;
  failures must be readable and restart with the entire run-up. Ordered gates
  alone do not prove the car jumped: test the underside/side approach too.
- [ ] Prove the automated driver itself is not imposing an arbitrary speed
  limit near the gap. Keep any gap-aware pursuit/input policy test-only,
  leaving shared `TrailDriver` defaults and all existing scenarios untouched.
- [ ] If the weakest successful approach lacks margin, change the gap, ramp,
  landing or run-up within the approved concept and rerun **every** combination.
  Never alter `car/`, tyres, TC implementation or old surface coefficients.
- [ ] Verify normal-speed rendered PC behaviour; when a phone test window is
  available, repeat jump smoke and capture greybox build/render costs early.
  Phone unavailability is not a desktop performance pass or B1 acceptance.

Preview the uncatalogued scene: `RunLevel` already supports no stars/saving for
such scenes. The debug runner should keep a clear **B1 dry preview** label and
support explicit car/TC options without changing progress. Reuse current pause/
reset/car-selection controls where possible; no temporary catalog entry or
invented star times. Test restart, car change and exit without a leaked timer,
callback or audio player. Any automated runner must suppress saving in isolation.

**Gate:** all-car mechanical evidence passes, then the owner drives and explicitly
approves the jump feel. Commit the feature/evidence and **stop here**. No Task 4
or later work while waiting. After approval, preserve this geometry baseline;
later structure/terrain changes require rerunning the gap gate's tests and
renewed feel feedback if its driving behaviour changes.

**Commit(s):** `Verify Coastal gap across cars and traction settings`, then
`Record Coastal jump playtest checkpoint`.

## Task 4 — tunnel and independent stone bridge

Only after the Task 3 owner approval.

### 4a. Reuse the tunnel

**Files:** Coastal trail/terrain data; extend `tests/unit/test_tunnel.gd` only
with new Coastal cases and add Coastal integration checks.

- [ ] Author existing `TunnelDef` at 610–710 m, inner width 10.5 m, height 6 m,
  lamps every 12 m, cover 8 m, portal length 12 m. Keep existing shell builder
  and original tunnel behaviour; add no duplicate tunnel subsystem.
- [ ] Check dry floor, overhead cover and closed portals, correct collision,
  chase camera clearance and clean exposure leaving the tunnel. No lamp lights
  per fixture, no wet exit, and no obstruction of the complete open approach.
- [ ] Rerun the jump from Reset **and from normal tunnel traversal**: an all-car
  reset pass does not prove the course's approach is equally readable.

**Commit:** `Author Coastal headland tunnel`.

### 4b. New stone bridge, not modified logs

**New files:** `levels/trail/stone_bridge_def.gd`, `stone_bridge_builder.gd`,
`tests/unit/test_stone_bridge.gd`. Integrate opt-in
`TrailDef.stone_bridges = []`, profile/row omissions, terrain cuts and build
phase in the same shared files as Task 2; add Coastal data.

- [ ] Initial start 2055 m, length 18 m, clear deck width 7 m, parapet height
  0.7 m outside clear width, gentle 0.15 m deck crest. Use asphalt contact on
  the stone structure. Expose channel/arch clearance and abutment dimensions
  as bounded resource data; select them against the dry channel in the greybox.
- [ ] Build a closed stone arch, deck, parapets and abutments with batched
  materials and static matching collision. One driveable deck, no duplicate
  road faces/shoulders, no ground slab plugging the arch or visible edge with
  no physical support. Keep inward-facing parapet ends out of the road.
- [ ] Do **not** expand `RoadProfile.on_bridge()` in a way that assigns the log
  surface to stone. Distinguish road omission from surface choice and preserve
  `BridgeDef`/`BridgeBuilder` and all Frozen Pass fixtures unchanged.
- [ ] Terrain cuts run before terrain mesh/collision; bridge build runs once
  afterward and reports its own phase. Rebuild/exit removes old generated data.
  Keep geometry available for future B2 bed registration, but don't change
  `WaterBedSource`, add water below it or pre-build a B2 registry now.

**Tests:** arch open, dry underside accessible only where visible; deck profile
matches tyre rays; joints flush; all-car low/normal-speed crossing without
snags; correct surface ID; parapet collision; no duplicate/hidden support;
empty opt-in features preserve every existing level. Measure structural phone
cost now if available, with no inference from desktop scaling.

**Commit:** `Add opt-in stone bridge and Coastal channel crossing`.

## Task 5 — approved dry surfaces and seamless shoulders

**Files:** new `surfaces/coastal_sand.tres`, `soft_sand.tres`,
`wet_asphalt.tres`; additive entries only in `surfaces/grip_table.tres` and
`effects/surface_feel_table.tres`, with new feel resources as needed;
Coastal trail data; new `tests/unit/test_coastal_surfaces.gd`.

- [ ] Add the spec §5 values authorized by the B1 handover:

  | Surface | Grip / roll / sink / drag | Rally / off-road multiplier | B1 use |
  | --- | --- | --- | --- |
  | `coastal_sand` | 0.80 / 0.045 / 0.010 / 0 | 1.05 / 1.10 | Two main sand stretches and their shoulders. |
  | `soft_sand` | 0.70 / 0.070 / 0.025 / 0 | 1.05 / 1.10 | Data only; local soft patches wait for B2. |
  | `wet_asphalt` | 0.90 / 0.015 / 0.000 / 0 | 1.10 / 0.95 | Data only; no misleading wet driving in B1. |

- [ ] Keep every old surface and grip-table value identical. Never retune the
  new values silently in response to the jump. The jump remains on dry asphalt.
- [ ] Apply full-width `SurfaceStretch`s at 1350/600 m and 2250/300 m with
  `affects_shoulders=true`; asphalt shoulders use existing dirt/gravel physics.
  Preserve the 70/30 nominal allocation and make the shoulder slightly darker
  than the main sand without inventing a different traction boundary.
- [ ] Use existing colour/roughness blends and small local damage/ruts, staying
  within spec ranges. Keep approach/landing and structure joints smooth. If
  asphalt edge lines remain on sand, add an **opt-in painted-line exclusion/
  fade profile** (not a general surface-patch system), mirrored in serial and
  snapshot paths. Likewise, any shoulder-only colour tint is opt-in and purely
  visual; no altered old defaults or collision surfaces.
- [ ] Keep visual and colliding triangles aligned through potholes, transitions
  and shoulders. Terrain must stay below actual road depressions, not prop up
  the wheels through a lower visible mesh. Road/earth joins have no lip or
  floating ribbon. Avoid the old raised asphalt patch effect where it makes
  this mostly-even road look like stacked sheets.
- [ ] New surface feedback uses existing dry road/gravel sounds and light sand
  dust; no puddle splash, water sound or doubled drag. Test surface identity
  before/inside/after blends and at both shoulders, plus all-car dry traction.

**Check:** old coefficient/fixture hashes, additive mappings, serial/threaded
colour/collision parity and full existing car-balance tests. Local two-dimensional
patches remain unimplemented, even though their surface resources exist.

**Commit:** `Add Coastal sand surfaces and smooth dry transitions`.

## Task 6 — land, selective barriers and restrained presentation

**Files:** Coastal terrain/scatter/scene data; proposed opt-in
`levels/trail/coastal_terrain_def.gd`, `coastal_earthworks.gd`,
`road_barrier_def.gd`, `road_barrier_builder.gd` if needed;
`levels/coastal_highway/coastal_rainbow.gd`; focused terrain/barrier/rainbow tests.

- [ ] Establish the land silhouette before decorative scatter: independently
  authored headlands, cove and dry channel, not terrain stretched from the
  nearest road stamp. If existing terrain settings cannot express it, use a
  nullable `TerrainDef.coast` with world-XZ shore outline, land/low-ground shape
  and blend data. A null resource must run the exact old path; new shaping uses
  immutable worker snapshots, then road/structure cuts. No sea mesh or water
  registration is part of this resource. Do not build a generalized new terrain
  engine when an opt-in field shaping pass is sufficient.
- [ ] Keep filled/closed land sides and collision at raised roads. Test both
  legs of hairpins, tunnel cover, the gap and arch after shaping; no random
  boulder support or shortcut bypass may appear near a tested jump.
- [ ] Author selective seaward guardrails/stone walls near 80–250, 440–570 and
  2700–2860 m, adjusting to the actual bend orientation. Opt-in barrier data
  includes start/length/side/lateral inset/type/height and end treatment. Batch
  static visuals and collision; don't make individual stones dynamic. Leave
  some visibly exposed slow corners open and bridge parapets continuous.
- [ ] Add sparse scrub/grass, wind-shaped trees and static rocks outside driving
  clearance. Extend scatter exclusions only as needed for the gap, new bridge,
  sightlines and future corridors; preserve old seeds/order with empty additions.
  No shelf/talus work and no functioning future-shortcut paths.
- [ ] Apply the spec's clearing-weather palette and existing mood component.
  Add a soft depth-tested rainbow arc opposite the sun, positioned for selected
  cliff/finish views. No collision, shadow, dynamic light or active weather.
  Fog must not conceal the landing or the true edge. Bound transparent overdraw.
- [ ] Use quiet existing wind ambience; any new loop must have the 32-frame
  `SoundSynth.LOOP_PAD` tail and stop on exit/pause as appropriate. No sea/wave
  feedback system ahead of B2. Recheck rebuild/reload cleanup.

**Owner checks:** opening/tunnel/jump in context first; then descent/cove/stone
bridge; then uphill S-bends and finish. Pause after a section if the owner wants
changes. Keep its dry B1 status obvious; do not claim final water appearance.

**Commits:** separate terrain/barrier and scenery/lighting/rainbow commits, each
with its focused tests and a captured playtest note. Don't bury shared-builder
changes in an art-data commit.

## Task 7 — phone budgets and conditional deferral

Use the existing benchmark/one-shot patterns; add Coastal-specific options to
`debug/coastal_playcheck` or a small `debug/coastal_acceptance` scene instead
of silently changing the historical five-scene benchmark's comparison order.
Add deterministic result-schema/flag tests alongside the harness.

Measure at the greybox, structure and presentation stages when the phone is
available. Before installing, build a fresh APK, record source and APK hashes,
confirm the owner's game is closed, preserve progress and consume only the
specific debug flag. Never use an old `install` artifact as a fresh build.

- [ ] **Build <5 s on the Xiaomi 13**, with native resource loading, instantiate/
  ready, `TrailLevel.build_seconds`, each phase, loading-cover duration and
  first interactive frame reported separately. Retain a cold launch and at
  least three repeated loads; do not report only the fastest result or subtract
  expensive phases from the total. No change to old levels' acceptance records.
- [ ] **<300k submitted primitives, <150 draw calls**, counting shadow passes,
  at opening, tunnel exit/jump, landing, descent hairpins, cove/bridge and finish.
  Report every worst view; visibility changes cannot hide required road support.
- [ ] **60 FPS target**, average >=59, whole-frame p95 <=18.5 ms and p99 <=25 ms;
  retain maxima and all >33.3 ms intervals with start/warmed classification.
  Use normal-speed, thermally warmed runs, repeated/balanced views, live all-car
  driving and a five-minute warmed scene/drive soak. New repeatable Coastal
  work spikes are investigated; don't reopen M6's closed case merely because
  another measurement-start platform tail exists.
- [ ] B1's Coastal `WaterWorld` stays empty and no wave runtime is instantiated.
  Record any inherited empty-world callback overhead separately. Do not use
  the future water allowance to justify B1 costs, and do not claim B2 will fit
  before it is built/measured. B2's agreed **6/7 ms CPU** and **+0.50 ms GPU**
  limits stay intact; exceeding the water ceiling later cuts features.

**If build exceeds 5 s:** keep the failed measurement; profile actual phases,
then use the owner-approved deferral lever, not a larger budget. This is a
conditional task, not a speculative streaming rewrite before measurement:

1. Keep the whole route's cheap immutable definition and stable IDs available;
   prepare what the player can reach soon before countdown, defer distant
   expensive mesh/node/collision work. Pick the split from measured phase cost
   and fastest observed approach, not an arbitrary distance.
2. Establish a preload safety margin covering maximum observed drive speed,
   measured preparation time, camera look-ahead and worst scheduling delay.
   Work from the player's furthest reachable/visible region, including reverse
   and every legitimate Reset destination. No missing collision, visible
   pop-in or one large synchronous mid-race build is acceptable.
3. Snapshot/compute arrays on workers, create nodes/shapes in bounded main-thread
   batches. Never call one shared GDScript object from workers or switch the
   global physics thread mode. Existing levels keep eager construction.
4. Cancel and clean pending work on restart/exit; maintain deterministic final
   geometry. Test a fast car, reversing, Reset/retry, rapid scene change and a
   deliberately late preparation case. If readiness cannot be guaranteed,
   keep the feature explicitly failing and propose a smaller design; do not
   teleport/stop the car or conceal the load as an unmeasured gate.
5. Report initial-ready time, total deferred work and the worst post-countdown
   frame/load burst. Rerun all functional/full-scene and phone checks. Give a
   concrete deferral plan update before adding this larger shared change.

**Commit(s):** scoped acceptance tooling/evidence; measured deferral separately
only if required. No measured pass is inferred from the earlier 3.3 s estimate.

## Task 8 — whole-track playtest, scoring and final review package

- [ ] Complete all three cars through the entire B1 course using normal inputs;
  verify every checkpoint, manual/automatic Reset, restart, car change, finish,
  pause and return-to-menu. Test failed jump bypasses after final scenery.
- [ ] Let the owner judge technicality/flow and collect actual run times. Leave
  the scene uncatalogued/no-score during preview. Add the final
  `coastal_highway_level.tres` and append to `levels/catalog.tres` only with
  owner-chosen B1 star thresholds; no invented or zero shipping thresholds.
  If stars are intentionally deferred to B2, retain the documented no-score
  preview instead of pretending catalog/scoring acceptance is complete.
- [ ] Stable ID `coastal_highway`, sixth level/fifth timed track; no changes to
  old IDs, stars, unlock rules or owner progress. Add/update catalog-count tests
  explicitly for the new entry, without changing geometry or balance fixtures.
  Note that B2 may require another measured star-time decision.
- [ ] Run `./run_tests.sh unit`, affected scenarios during development and final
  `./run_tests.sh all` on the delivered source, no `SCRIPT ERROR`, exit 0.
  Retain any existing pending test with its actual reason; don't add a pending
  mandatory jump test or rerecord protected fixture files. New Coastal fixtures
  can be pinned only after its owner-approved shape is stable.
- [ ] Verify the tested Android artifact matches source; final B1 phone check
  and owner playtest, saves preserved, no leftover one-shot flags. Stop all
  automation while they drive. Device-unavailable checks stay plainly pending.
- [ ] Finish `docs/notes/codex-report-m6b1-coastal.md`: per-feature commits,
  owner checkpoints, jump matrix, before/after layout/tuning, all load phases,
  rendered view/frame distributions, failed attempts, reproducible commands,
  evidence hashes, suite outcome and explicit B2 omissions.
- [ ] Update AGENTS with delivered status and remaining decisions. Stop for
  Claude/owner review. No B2 work, merge or push, even if all B1 checks pass.

## Review checklist for this plan

- [x] Owner approves the B1 plan before code work.
- [x] Owner's usual traction-control percentage confirmed before closing Task 3.
- [ ] Initial jump values and landing-width correction accepted as geometry
  prototype values, subject to all-car results, not guarantees.
- [ ] Dry-preview boundary understood: water, sea and all local wet/soft patches
  are B2; optional surface resources alone do not enable them.
- [ ] Jump owner-feel stop, staged PC checks and separate B1 phone acceptance
  remain mandatory. No new budget or tuning exception is being requested.

**Historical planning verification (2026-09-27):** source/read-only inspection
only, with no game or phone run. Actual implementation checks from 2026-10-06
are recorded separately in the first-delivery report linked above.
