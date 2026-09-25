# M6W — water waves implementation plan (isolated start approved)

## Current CPU budget amendment (2026-09-25)

Owner approved provisional **Test Ground total-water CPU 6 ms/frame p95 /
7 ms/frame p99**, replacing 4/5 in this scope. Incremental CPU 0.50/1.0 ms
figures are now reported optimization targets, not a second blocking gate.
Whole-frame/GPU/hitch/setup/memory/drawing checks are unchanged. Defer native/C++
work. See `../../notes/m6w-budget-amendment-2026-09-25.md` for evidence and
`../../notes/m6w-completion-plan-2026-09-25.md` for the current remaining work.
Historical checklists below are not final acceptance and do not supersede these
later owner decisions. No rollout/merge/Coastal Highway authority is added.

## Completion authorized (2026-09-25; current scope)

Owner approved the measurement correction and finishing M6W for a whole review,
with focused commits and documentation. Claude's intervening wake/splash work
(`135c33f`) and phone launcher (`de50ab5`) are delivered; earlier step-only stops
below are historical. See `../../notes/m6w-completion-plan-2026-09-25.md` for the
current sequence. Preserve wave feel and apply the amended CPU policy. Test Ground
only; no merge, push, timed-level rollout or Coastal Highway. Implementation
completion is not a claim of owner/reviewer or phone acceptance.

## Bow-only follow-up (2026-09-24; latest scope)

Owner accepted improved entry visibility and chose **step 1 only** from the
proposed bow / trailing-wake / splash follow-up. Refine the attached leading
crest and its response to water-relative orientation, including reverse, then
stop for PC feel feedback. No phone work, wake/splash redesign or further polish
is implied. Existing hitch deferral and all acceptance/rollout gates remain.

- [x] Capture the original bow in forward/reverse/oblique/slow real-car cases.
- [x] Curved shoulder crest, projected cross-flow width, small leading clearance;
  same strength, ambient, entry/wake rules, fixed field and safety caps.
- [x] Focused unit/source and all-car/60–120 Hz driving/steering checks: 25 pass.
- [x] Real-GPU bow/triangle parity, normal-speed PC smoke and full regression:
  780 passing, one inherited pending, no SCRIPT ERROR; code frozen for run.
- [x] Record evidence and stop for owner feedback before step 2 or phone testing.
- [ ] Owner drives the refined bow and provides feedback; no further work implied.

Feature `2ba1096`; report/evidence:
`../../notes/m6w-bow-refinement-2026-09-24.md`. No Android export/install this pass.

## Approved entry-readability correction (2026-09-24; latest work)

Owner approved proceeding after feedback: preserve satisfactory ambient waves,
improve barely visible entry response, and prepare for connected-phone testing.
The intermittent hitch remains recorded and unresolved but is explicitly
non-blocking for this iteration. Keep diagnostics and revisit on phone before
final acceptance; budgets, timed-level restrictions and no-merge rule remain.

- [x] Record the decision and capture the original natural entry from chase/side.
- [x] Diagnose early hull occlusion and weak crest contrast; retain original
  coefficients, depth/shore caps, car tuning and ambient response.
- [x] Add a hull-sized entry origin radius and displacement-linked crest contrast
  on the existing surface, with CPU/GPU equations kept parallel.
- [x] Focused all-car/60–120 Hz source, early visibility and flotation tests.
- [x] Slow-entry visual check, real-GPU parity and complete regression: 775
  passing, one inherited pending, no SCRIPT ERROR. Runtime/tests frozen for run.
- [x] Fresh Android export (feature `78bb1b8`) ready for the owner's phone.
- [ ] Install for owner phone playtesting when connected; no device detected at
  handoff. No phone result/full-gate acceptance inferred from PC or export.
- [ ] Stop for renewed owner feel feedback; no automatic expansion into polish.

Report/evidence: `../../notes/m6w-entry-readability-2026-09-24.md`.

## Owner-approved PC feel exception (2026-09-24; latest scope)

Owner approved: "let's keep it to the Test grounds and let me test" after an
explicit proposal to bring PC live integration before the unresolved hitch/full
phone gate. This supersedes that prerequisite **only for the experimental PC
Test Ground prototype**; no phone acceptance, rollout, merge or polish is implied.

- [x] Optional drawn-triangle query binding and rest-height source diagnostics.
- [x] Natural entry/bow/wake with bounded history and no extra bed queries.
- [x] Test Ground-only comparison controls and covered reset/pause/rebuild lifecycle.
- [x] Focused unit/lifecycle/live-car checks at 60/120 Hz and real-renderer PC
  smoke/parity checks; raw evidence retained. Full-part phone gates are not claimed.
- [x] Final complete regression: 774 passing, one inherited pending, no SCRIPT
  ERROR; one interrupted attempt retained alongside the unchanged successful rerun.
- [ ] **Task 5a: owner drives and explicitly approves the feel. STOP HERE.**

Current report/playtest guide: `../../notes/m6w-pc-prototype-2026-09-24.md`.
The original full-part checklist below is not blanket acceptance: sustained
phone measurements, the broader driving matrix and polish remain outstanding.

Current execution: exact optional query binding and Off parity → bounded natural
source generation → Test Ground-only mode/reset/pause lifecycle and plain controls
→ focused/live PC checks and full regression → **stop at Task 5a for the owner**.
Keep car/surface tuning and protected fixtures unchanged. Phone cost validation
and historic hitch classification stay open and must be revisited later.

## Follow-up to Claude's e37620d review (2026-09-24)

Owner asked to continue in review order: hitch diagnostics, preparation
profiling/fix, early phone work. See
`../../notes/m6w-review-followup-2026-09-24.md` for raw evidence and limitations.

- [x] Trace waves-Off state/effects/audio and scheduling on the phone; retain all
  cases and failed diagnostic attempt. Two reproduced long frames are dominated
  by off-CPU scheduling delays, not new stall transitions. No gameplay fix claimed.
- [x] Separate static preparation phases; identify deep outline/depth/topology
  work as the main cost, not native mesh commit or four small bays.
- [x] Package exact offline-generated topology, validate source/profile/revision,
  fail closed on stale assets, preserve distinct masks and shared deep geometry.
- [x] Cover real shader first use; phone CPU preparation 27–38 ms across three
  launches, first-use waits 154–753 ms separately; phone numerical parity passes.
- [x] Final desktop regression: 765 passing, one inherited pending, no SCRIPT ERROR.
- [ ] M6A hitch/acceptance prerequisite explicitly resolved after trace review.
- [ ] Complete Task 0/4 all-water timing coverage and synthetic phone gate.
  Setup/parity above are subchecks only, not full CPU/GPU/frame/memory acceptance.

No natural source generation or live-car wave sampling was connected. The
original groundwork checkpoint below is historical; its "phone untested" and
"no instrumentation" descriptions refer to that earlier stage only.

## Approved limited start (2026-09-24; supersedes original sequencing below)

Owner approved **4 ms/frame p95 / 5 ms/frame p99 total water CPU** and Tasks 1–3
as isolated groundwork on `m6-water-waves` from unmerged M6A `4d5bd21`. Do not
bind queries to live cars or enable waves in gameplay. Standalone field/mesh/
shader fixtures may proceed while M6A acceptance remains open. Preserve the
waves-Off reproduction; stop before live integration until the hitch is fixed
and retested. No merge/push. Task 5a owner feel approval remains mandatory.

- [x] Owner approval of limited scope and total-water limits recorded.
- [x] New branch created from unmerged M6A; master untouched.
- [x] Unchanged desktop baseline recorded: 736 passing, one pending.
- [x] Isolated pure model complete and tested.
- [x] Isolated refined mesh/sampling complete and tested (no WaterWorld binding).
- [x] Synthetic shader/CPU parity verified on desktop; phone parity untested.
- [x] Final complete regression: 760 passing, one pre-existing pending, no
  SCRIPT ERROR; report/evidence retained, feature commits made, stopped.

The original full-part checklist below remains for later integration; blocked
M6A merge/phone items are not prerequisites for this explicit limited exception.

**Status:** isolated groundwork complete and desktop-verified; stopped before
live-car integration. Phone/setup performance and the M6A hitch remain open.
Design: `../specs/2026-09-24-m6w-water-waves-design.md`. The remaining full-part
tasks are not automatically authorized by finishing this groundwork. Task 5a
is a mandatory live owner-feel stop before polish.

Completed isolated subset: fixed global packet store, packed body snapshots,
analytic field, conservative refined mesh and standalone sampler, translucent
shader, pause-aware lab runtime, car-free preview and calibrated GPU evaluator
checks. No WaterWorld/car binding, natural emitter, phone instrumentation or
Test Ground controls were added. The detailed full-part boxes below deliberately
remain open where they include integration/phone requirements beyond this
exception. See `../../notes/codex-report-m6w-waves.md` and its retained logs.

## Guardrails

- M6A hitch fix/retest precedes live-car integration; acceptance/setup/load
  decisions remain open. Isolated work alone is allowed before those decisions.
- Approved provisional Test Ground total-water CPU limits are 6 ms/frame p95
  and 7 ms/frame p99 in the recorded all-water scope. Incremental CPU is a
  reported optimization target; it cannot replace the absolute total gate.
- `m6-water-waves` starts from unmerged M6A `4d5bd21` by owner exception. Do not
  merge or push; future baseline/branch reconciliation requires an explicit step.
- Wave runtime enabled only through Test Ground opt-in modes. Timed levels,
  Coastal Highway and wall/rock reflections are outside this part.
- Preserve `car/`, existing surface values and all protected fixtures. Ask if
  integration requires a car-side edit not planned by the spec.
- Preserve the owner's `project.godot` re-save; never touch `tmux-session.sh`.
- Typed/tabbed GDScript; named-file staging; commits by completed feature.
- One Godot run at a time. Never run tests/imports/benchmarks/captures while the
  owner plays; do not kill their process. Use isolated desktop save paths and
  preserve phone progress. No automatic phone runs merely because it reconnects.
- Tests use accelerated mode when appropriate; acceptance measurements do not.
- No parameter/budget change to hide a failure. Record it and seek review.
- Stop after Task 5 for Task 5a owner driving-feel approval. No Task 6 polish
  while waiting; delegated starting strength does not replace this checkpoint.

Dependency order:

Agreed total-water ceiling/approval/baseline → pure field and exact sampling →
shader/parity → **phone feasibility gate** → natural car sources and basic
playable controls → **Task 5a: owner drives; stop for feel approval** → Test Ground
polish/lifecycle completion → full regression, phone acceptance and final review.

## 0. Approval and comparable baseline

- [x] Record owner feedback and explicit **limited** start approval.
- [x] Record original C95=4 and C99=5 ms/frame approval, scope and rationale;
  superseded for the Test Ground by the 2026-09-25 C95=6 / C99=7 amendment.
  Neither approval is a retroactive full-protocol pass for old measurements.
- [ ] Verify M6A acceptance decision and merged starting commit. Ensure its
  three-second intake amendment is included; the old audit APK is not baseline.
- [ ] Create the approved new branch, inspect dirty files and preserve them.
- [ ] Run the unchanged complete desktop suite and retain its log/exit status.
- [ ] Verify baseline instrumentation covers the approved total-water scope.
  If not, add and validate measurement-only coverage before the baseline capture;
  historical controller-only totals are not a substitute. Task 4 later extends
  this instrumentation for new wave regions without double-counting them.
- [ ] With the owner's idle phone, fresh build/install and record hash/save hash.
  Capture Test Ground Off costs, normal frame tails, drawing, setup, shader state
  and thermal status. Sum all measured water CPU per frame in the approved scope;
  check absolute ceilings before waves, not just old controller-only timings.
- [ ] Write baseline results and device availability into the future M6W report.

Exit: comparable accepted baseline and numeric total-water ceilings recorded,
not just a clean-looking desktop run or an unapproved budget proposal.

## 1. Pure, bounded field

Files: new `water/waves/water_wave_profile.gd`, prototype `.tres`,
`water_wave_math.gd`, `water_wave_field.gd`; new unit tests.

- [ ] Tests first for two ambient terms, compact travelling pulse, bow profile,
  direction, onset/expiry, amplitude/depth/shore limiting and finite derivatives.
- [ ] Implement fixed-capacity 4-entry/12-wake slots, deterministic IDs and age,
  explicit skipped-event counter and scene-local ownership. No growable history.
- [ ] Test whole versus split timesteps, 60/120 Hz schedules, zero/current-relative
  motion, source-centre singularities, pause and long-run phase precision.
- [ ] Represent snapshots with reusable float32 parameter buffers to be consumed
  identically by CPU/shader; commit sources only between physics ticks.
- [ ] Keep components free of live car/scene queries so math is independently
  testable. Do not add direct impulses or alter the vehicle force model.

Exit/commit: pure bounded model and tests; no gameplay opt-in yet.

## 2. Refined drawing topology and exact query integration

Files: new `water_wave_mesh.gd`; limited edits to `WaterSample`, `WaterWorld`,
`WaterBody` only if needed for rest-height diagnostics; new geometry/query tests.

- [ ] Build a 0.75 m clipped XZ top from existing Test Ground footprints and source
  colours, with per-triangle lookup and shared-vertex metadata. Keep original
  top/bed source arrays and base query bins unmodified.
  Follow-up implementation uses offline generation into exact packaged assets;
  runtime validates source/profile fingerprints and adopts arrays under a cover,
  with no silent fallback build or reduced detail. Fresh/cache equality is tested.
- [ ] Precompute conservative bed-wide height limits and shoreline taper using
  nearby static faces, including bed breaks between render vertices.
- [ ] Reuse compatible static mesh data for calm/current while keeping runtime
  parameters per body. Check actual counts before proceeding: all instances,
  clipped shore triangles, CPU/GPU buffers and the 40k/16 MiB allocations.
- [ ] Add optional wave-field binding. At each valid query, use the render
  triangle's three current-snapshot vertex heights with a tick-local cache.
  Wave-invalid/unbound bodies retain original results and force behaviour.
- [ ] Test clipped cells, seams, negative coordinates, thin/shallow margins,
  separate bays, max packet overlap, saturation and base-invalid queries.
- [ ] Test all existing level geometry and Off water results unchanged. Do not
  put dense drawing triangles into the ford's optimized static query index.

Exit/commit: synthetic height queries match the new mesh's planes; all old
fixtures remain exact. No shader parity claim until the next step.

## 3. Shader, clock and diagnostic parity

Files: `water_surface.gdshader`, `water_wave_runtime.gd`, minimal non-default
debug scene and render/parity tests. No natural vehicle source generation yet.

- [ ] Implement one shader program with bounded packet loop, ambient/bow terms,
  same masks/saturation and analytic normals. Retain translucency/material values.
- [ ] Use explicit physics snapshot uniforms, not shader TIME. Pre-car runtime
  priority -50; render the last completed immutable snapshot. Pause freezes both.
- [ ] Add displaced bounds; turn water shadow casting off; retain depth testing
  and correct underside normals. No stacked original/animated tops.
- [ ] Create a tiny diagnostic shader/readback path using the same GPU evaluator
  as the water shader. Calibrate linear/encoded output against known heights,
  then compare CPU vertices and barycentric query heights (<=1 mm). Exercise
  boundaries, cold/long time, maximum packet count and clamping. Keep this path
  out of normal gameplay/timing.
- [ ] Cold/first-use shader warm-up under a loading cover, with measured time to
  first present. Check transparency and normal stability on desktop and phone.
- [ ] Implement synthetic zero/max-packet source inputs and fixed-pose fixtures.

Exit/commit: verified synthetic field and rendering contract; not a natural
vehicle-wake feature or a finished playtest build.

## 4. Early phone feasibility gate — before more feature work

Files: new `debug/water_wave_acceptance.gd` / `.tscn`, measurement extensions,
independent validator tests and raw-data report.

- [ ] Add non-overlapping timing categories: controller-inclusive, nested wave
  query subtotal, external field/emitter, existing water feedback, water uploads,
  other water callbacks, frame intervals and GPU timing. Sum all water CPU per
  frame; preserve controller-only columns without confusing them with the total.
  Include snapshot/packet/query/vertex counters and p95/p99/max/long-frame counts.
- [ ] Validate normal 120 Hz/60 FPS pacing and all completed tick-to-frame sums;
  reject missing/duplicate ticks, incomplete cases and unsupported GPU counters.
- [ ] Fresh build, verify installed APK hash, stream complete logcat. Record
  3 x 30 s synthetic max-packet cases, matching Off and refined-flat controls,
  actual viewport, temps and save/cleanup hashes. Never infer phone cost from PC.
- [ ] Check approved **absolute total-water C95/C99 first**, plus GPU, drawing,
  memory, setup and whole-frame limits from spec §9; report incremental CPU
  target misses without using them as blocking gates. Compute
  percentiles from raw frame sums, not sums of percentiles. Inspect the water
  from driving/underwater angles. Both Off and On must pass the total ceiling.
- [ ] If unavailable or failed: record the checkpoint and stop for owner input.
  Do not continue adding natural sources/polish on assumed headroom. Neither a
  silent quality reduction nor a gate increase is an approved fix.

Exit/commit: evidence-backed go/no-go report. A pass only authorizes continuing
within the already-approved spec, not merging or accepting the complete part.

## 5. Natural vehicle entry, bow and wake sources

Files: new `water_wave_emitter.gd`, source tests and real-car scenarios; minimal
Test Ground binding/top handles and plain comparison controls brought forward
from Task 6 only as needed for the immediate owner playtest.

- [ ] Read the completed existing body/wheel/intake sample data at priority 50;
  use rest heights for emission triggers, dynamic height for actual car physics.
- [ ] Queue next-tick entry events after dry re-arm; seed pose history on spawn
  and reset. Implement size/velocity/depth intensity and deep-source fade.
- [ ] Attached bow follows water-relative direction, including reverse/sideways
  motion. Wake uses both distance and time cadence, finite support and current
  advection. Wheel spin never becomes physical wave propulsion.
- [ ] Body change leaves old packets in their original water; no cross-body or
  dry-gap propagation. Keep all caps/counters active at high speed and after reset.
- [ ] Verify at 60/120 Hz: fewer than 3 s intake coverage does not stall; exact
  3 s does; clearance resets; wave-trough restart and flooding stay independent.
- [ ] Test no current + no input stability, no self-exciting entry/wake, decay to
  rest and bounded early flotation relative to Off. Do not freeze flooding or
  give production cars extra buoyancy to make the demo last longer.
- [ ] Make the existing Test Ground actually drivable with Off / Car waves /
  Full selection, ordinary camera/input, Reset/pause and safe teardown. Keep Off
  as scene-entry default; clear history on switches. Use plain controls with the
  reset warning, not a scripted/frozen-car fixture or a polished settings page.

Exit/commit: natural car effects work in fixtures with existing car/force files
unchanged. Re-run the phone max-load case if emitted histories differ materially
from the synthetic feasibility fixture. Next is the owner feel stop, not polish.

## 5a. Early owner driving-feel checkpoint — mandatory stop

- [ ] Run focused safety/correctness tests and check the rough live prototype
  against agreed total/GPU/frame budgets; report incremental CPU. No menu,
  material or optional-effects polish is required to reach this checkpoint.
- [ ] Stop automated Godot runs; provide a short playtest guide and the exact
  build/values. Install on the idle phone only when available and authorized.
- [ ] Owner drives Off / Car waves / Full: slow/faster entry, turning/reversing,
  stopping/settling, early flotation, current drift and shallow water. Start
  with the 4x4, then compare rally cars; use the regular driving camera.
- [ ] Ask for feedback on entry/wake visibility, strength, bobbing and control,
  plus intake/stall readability. Record the owner's response, not an inferred
  pass from automated tests, a video capture or delegated numeric choices.
- [ ] If changes are requested, tune the wave profile within approved scope,
  recheck safety/total/GPU/frame costs, report incremental CPU, and repeat the
  short owner test.
  No dry-car retuning or budget increase to obtain a pass.
- [ ] **Wait for explicit owner feel approval before Task 6.** If unavailable,
  leave a resumable checkpoint and stop. PC feedback can unblock polish only
  with owner agreement; final phone feel/performance acceptance is still needed.

Exit: recorded owner approval of the rough feature's feel and selected values.
Commit the approved adjustments and resume polish only after that decision.

## 6. Test Ground polish and lifecycle completion — after feel approval

Files: `levels/test_ground/test_ground.gd`, minimal `water_course.gd` handles,
optional `ui/pause_menu.gd` extension hook, `ui/water_wave_test_controls.gd`, tests.

- [ ] Confirm Task 5a owner feel approval is recorded before starting this task.
- [ ] Retain Task 5's Test Ground-only binding. Off is default on entry; old
  `WaterCourse` meshes/data and assertions still exercise the original baseline.
- [ ] Finish the plain Off / Car waves / Full controls in the Test Ground pause
  menu; preserve the tested semantics. Label mode-change reset; release touches.
- [ ] Prepare mesh/material once on first enable behind a loading cover, retain
  for toggles, then detach/free on exit. No hidden transparent layer remains.
- [ ] Use all existing shallow/calm/current areas; no new wall, pool, bed or
  gameplay setting. Reuse spray/audio limits and avoid double entry feedback.
- [ ] Verify Reset, pause/resume, car change, world rebuild, scene exit and mode
  changes clear fields/queues without ghost waves or audio. Scope shared-menu
  changes so timed levels keep their old controls and behaviour.
- [ ] Add optional telemetry for active mode/packets/height and CPU categories,
  without altering old recorder columns or exposing a misleading timer display.

Exit/commit: polished Test Ground prototype preserving the owner's approved feel,
with full lifecycle coverage and no rollout. Material feel changes return to 5a.

## 7. Final verification and owner review

- [ ] Run the complete unchanged baseline fixtures plus new wave tests with
  `./run_tests.sh all`; no SCRIPT ERROR. Record exact totals/exit status and
  inherited pending tests. Do not re-record protected fixtures.
- [ ] Rendered desktop captures and shader parity: shallow bank, entry, bow/wake,
  stopped fading wake, partial immersion, underside/sinking and all modes.
- [ ] Phone protocol from spec §9: three alternating Off/Full rounds × all cars,
  60 s matched-pose cost replay, separate live 3/8/15 m/s behaviours, Car waves
  comparison, synthetic stress and at least five minutes warmed Full gameplay.
- [ ] Capture cold/first use and repeated mode/load behaviour with complete logs,
  every raw sample, temperatures, GPU validity, setup phases and cleanup counts.
- [ ] Recheck approved total-water C95/C99 in every case alongside GPU and
  whole-frame limits; report incremental CPU target misses. No incremental-only
  acceptance or pooled slow cases.
- [ ] Investigate all >33.3 ms tails. Use a system/CPU trace if necessary; do not
  attribute them from query counts or averages alone. Keep failed cases visible.
- [ ] Confirm all timed levels remain waves-Off with baseline geometry and
  balance unchanged; record any unrelated inherited misses separately.
- [ ] Freshly install the measured final build when the phone is available, with
  save preserved; announce when automated tests finish and the owner can play.
- [ ] Write `docs/notes/codex-report-m6w-waves.md`: change list, approved numbers,
  total/incremental performance evidence, Task 5a owner feedback and final feel
  confirmation, limitations and a short Off/Car waves/Full playtest guide.
- [ ] Finish feature commits with named files, update AGENTS, stop for owner/Claude
  review. No merge/push, reflected-wave work, timed-level enablement or Coastal
  Highway implementation without the next explicit decision.

## Review checkpoint

The latest explicit PC exception supersedes the old isolated-only start for
this Test Ground prototype. It is now implemented and PC-verified: **stop for
Task 5a owner driving feedback**, not polish. Phone acceptance, historic hitch
review, timed-level rollout, merge and Coastal Highway remain open.
