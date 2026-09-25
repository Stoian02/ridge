# Ridge — notes for coding agents

**Latest owner budget amendment (2026-09-25):** provisional **Test Ground**
total-water CPU limits are now **6 ms/frame p95 / 7 ms/frame p99**, replacing
4/5 only in this scope. The old incremental CPU 0.50/1.0 ms targets remain
reported optimization targets, not another blocking gate. Whole-frame, GPU,
setup, memory, drawing and hitch checks are unchanged. See
`docs/notes/m6w-budget-amendment-2026-09-25.md` for the approval, phone evidence,
remaining checks and rationale: recent replay/stress cases held about 60 FPS,
so the owner accepts less headroom instead of a native rewrite solely for 4 ms.
The 30-second 4x4 subchecks do not constitute final phone acceptance; retain the
original failed results. C++ work is deferred, not approved or necessary on this
evidence. No wave feel/physics change, M6A acceptance, timed-level rollout,
Coastal Highway, merge or push is authorized by this amendment.

**Latest owner approval (2026-09-25): finish M6W implementation.** Correct the
measurement protocol/coverage first, then measured performance hardening and
remaining behaviour/lifecycle verification. Preserve the approved ambient and
vehicle-wave feel, exact drawn-height queries, car tuning and geometry. Keep
focused commits and retained evidence for Claude's whole-milestone review.
See `docs/notes/m6w-completion-plan-2026-09-25.md`. This supersedes the earlier
diagnostic-only/step-by-step implementation stops, not owner/reviewer acceptance.
Use the amended Test Ground CPU policy above. Test Ground only; no Coastal Highway,
timed-level rollout, merge or push. The historical M6A hitch remains separate.

**Preceding diagnosis (2026-09-25):** Owner supplied Claude's
phone report and asked to measure the suspected ambient-wave cost before any
optimization. See `docs/notes/m6w-ambient-cost-diagnosis-2026-09-25.md` and retained
raw evidence. The slow late Full case reproduces, but reversing mode order makes
Full fast and Off slow. Full evaluates fewer vertices; ambient maths is a small
component. Read-only CPU samples show a frequency drop before the late case.
The playcheck measures **controller-only**, not total water. Full's late-state
ceiling misses remain real; no budget is waived and no all-water pass is claimed.
Only opt-in debug instrumentation/tests/reporting were added; production wave
maths, behaviour and tuning are untouched. Suite: **785 passing, one inherited
pending, no SCRIPT ERROR**. Diagnostic APK installed, flags consumed, save
unchanged. No optimization, merge or push. Next: agree a steady-state, balanced
measurement protocol and complete total-water coverage before choosing a fix.
The historical flooded/stalled M6A hitch stays open and separate.

**Claude's intervening work:** `135c33f` completed the owner-approved trailing
wake and directional entry/spray work; `de50ab5` added the phone playcheck flag.
Read `docs/notes/m6w-wake-and-splash-2026-09-24.md` and
`docs/notes/m6w-phone-waves-2026-09-25.md`. Earlier step-1-only notes below describe
the preceding checkpoint, not the latest delivered feature scope.

**Latest scope (2026-09-24):** owner likes the now-visible entry and approved
**step 1 only: refine the bow wave**, on the Test Ground, before phone testing.
Make the leading crest wrap around the sides and follow water-relative motion,
including reverse. Do not change trailing-wake generation, splash particles,
ambient waves, accepted entry sources, car tuning or depth/shore limits. Stop
for feedback again after PC verification. Hitch remains open/non-blocking for
this iteration; phone acceptance, timed-level rollout and merge/push stay pending.

**Bow refinement delivered:** feature `2ba1096`, report and playtest guide at
`docs/notes/m6w-bow-refinement-2026-09-24.md`. Curved leading/shoulder crest uses
the hull's projected span and follows reverse/oblique motion. Strength settings,
ambient/entry/wake sources, splash particles and car tuning are unchanged.
Final suite: **780 passing, one inherited pending, no SCRIPT ERROR**; dedicated
GPU bow/triangle checks and normal-speed PC smoke pass. **Stop for owner feedback**
before steps 2/3 or phone work. No Android build/install this pass; the previous
APK predates this bow change and must be rebuilt before future installation.

**Latest owner approval (2026-09-24):** keep the intermittent hitch recorded as
unresolved but **non-blocking for the next Test Ground wave iteration**. Improve
the barely visible vehicle-entry response; preserve the ambient waves the owner
likes, car tuning and depth/shore safety limits. The owner will connect the phone
for testing. Retain Off-mode diagnostics and revisit hitches in phone checks
before final acceptance, sooner if reproducible in ordinary driving. This is
not a hitch fix, waived performance gate, timed-level rollout or merge approval.
Stop again for owner feel feedback after the entry adjustment.

**Entry correction delivered:** see `docs/notes/m6w-entry-readability-2026-09-24.md`.
Feature `78bb1b8` makes the entry crest emerge beside the hull and highlights
actual vehicle-wave displacement on the existing surface. Ambient values,
coefficients, depth/shore caps, geometry and car tuning stay unchanged. Final
suite: **775 passing, one inherited pending, no SCRIPT ERROR**; GPU height parity
and PC smoke checks pass. Fresh Android APK exported, but no phone detected and
**no installation/phone acceptance** this pass. Stop for owner feel feedback;
do not start another Godot run while they play.

**Latest owner exception (2026-09-24):** the owner explicitly approved bringing
the PC driving-feel prototype forward, on the **Test Ground only**, before the
M6A hitch review/full phone gate closes. Implement natural entry/bow/wake,
drawn-height coupling and Off / Car waves / Full controls (Off on scene entry),
verify on PC, then **stop for owner driving feedback before polish**. This
supersedes the earlier no-live-binding prerequisite below only for this
experimental Test Ground checkpoint. Phone acceptance, historic hitch review,
timed-level rollout and merge/push remain pending; no budgets or car tuning change.

**PC prototype delivered:** `docs/notes/m6w-pc-prototype-2026-09-24.md` is the
current playtest/report. Free Drive → Pause → Water waves — PC prototype:
Off / Car waves / Full. Natural sources and drawn-height physics are connected
only here. Final desktop regression: **774 passing, one inherited pending,
no SCRIPT ERROR**; the first stalled regression attempt and unchanged successful
rerun are both retained. PC rendered smoke/parity checks pass, not the full
phone gate. **First owner feedback received:** ambient waves are visible and
sufficient; entry disturbance is barely visible or not visible. GTA IV is the
owner's reference for eventual physical interaction, with stylized visuals
acceptable. See the playtest report's feedback section. Initially this was a
record/discussion request only; the latest approval above now permits the entry
correction, not full feel acceptance or unrelated polish. Do not start automated
Godot runs while they play. The original PC delivery made no phone installation.

**Current handoff:** `docs/notes/handover-codex-2026-09-23-m6.md` — Milestone 6
in two parts, Codex designing as well as building, stopping for review between
them. **Part A: water physics** (branch `m6a-water-physics`), validated on the
Test Ground and Rock Canyon's ford, which the owner has decided gets real water.
**Part B: Coastal Highway**, the sixth level, designed around what water does.
Neither is merged or pushed; Claude reviews each branch.

**Part A design:** `docs/superpowers/specs/2026-09-23-m6a-water-physics-design.md`
was **approved by the owner on 2026-09-23 and is implemented** on
`m6a-water-physics`. **Ready for PC playtesting and Claude review; phone
acceptance is still pending.** Read `docs/notes/codex-report-m6a-water.md` for
results, limitations and the playtest guide, and
`docs/superpowers/plans/2026-09-23-m6a-water-physics.md` for completed work.
**Performance review reopened:** see
`docs/notes/m6a-performance-retest-2026-09-23.md`. The earlier accelerated
desktop timings are not representative of normal gameplay; direct phone
retests have exceeded the water-cost gate. Do not mark A accepted on the basis
of the old performance table. This audit changes measurement tools, not physics.
**Follow-up fixes (2026-09-24):** see
`docs/notes/m6a-query-fixes-2026-09-24.md`. Crowded water-bed cells now have a
finer index with unchanged sampling/forces; Muddy Valley's ground-supported road
no longer casts redundant shadows. Matched pre-water/current creek captures
establish inherited primitive debt. Post-fix phone measurements show the ford's
controller p95 falling from about 4.2 to 1.6 ms/tick; all three creek views now
meet the drawing budgets. **Phone acceptance is still pending:** the original
strict timing failures are retained, setup gates remain missed, and one
current-pool case contains unexplained long frame intervals (up to 79.459 ms).
The later approved total-water policy below has not yet been verified in its
full measurement scope; it does not retroactively pass these runs.
**Independent review supplied by the owner (2026-09-24):** see
`docs/notes/m6a-independent-review-2026-09-24.md`. Claude confirms the query and
creek fixes. Matched no-water Rock Canyon views already have about 20 ms frame
p95: that baseline is inherited debt, not wholly an M6A regression. The hitch
remains open. Claude's newer rally-only/flooded-stalled pattern differs from the
earlier 4x4 hitch on the old intake-delay build; retain both, do not assert a
cause yet. The owner subsequently approved isolated wave groundwork before
M6A merge and **4/5 ms p95/p99 total-water CPU ceilings per rendered frame**.
This does not accept the hitch or authorize a merge.
The conversation approved progressive drag, temporary flotation and
sinking, recoverable intake-based stalls, steady currents, translucent water,
feedback and three Test Ground water areas. Scope also includes Muddy Valley's
creek and Rock Canyon's rut puddles. The written spec's numeric starting values
and water-only car integration are now approved; existing dry tuning stays
protected. Aquaplaning, deep-water skimming and visible snorkel art are deferred.
**Owner tuning amendment (2026-09-24):** the intake must stay submerged for
**3.00 s continuously** before stalling (was 0.60 s), for all three cars.
Clearing the intake resets the timer; restart and flooding timings are unchanged.
This change is separate from wave implementation and performance acceptance.
The owner wants waves/vehicle-displaced water in a **separate future part**;
the conversation is recorded in `docs/notes/water-waves-followup.md`.
**M6W isolated groundwork is approved (2026-09-24):**
`docs/superpowers/specs/2026-09-24-m6w-water-waves-design.md` and
`docs/superpowers/plans/2026-09-24-m6w-water-waves.md`. Agreed behaviours include
entry/bow/wake waves, gentle flotation effects and wave-driven intake submersion;
wall/rock reflections are deferred. Work on `m6-water-waves`, branched from
unmerged M6A at `4d5bd21`, is limited to pure wave maths, meshes and synthetic
shader/query fixtures. **Do not connect waves to live cars until the M6A hitch
is fixed and retested.** Master and M6A acceptance remain untouched. The total
water CPU limits are **4 ms/frame p95, 5 ms/frame p99**, including baseline and
waves; incremental limits must fit inside them. **Task 5a is a mandatory
owner driving-feel stop after entry/bow/wake work, before Task 6 polish**; provide
minimal playable controls early and wait for explicit feel approval to resume.
The approved limited start supersedes the original merge-first prerequisite
only for isolated groundwork. Full integration/phone acceptance and Coastal
Highway retain their recorded gates. No merge or push is authorized.
**Groundwork completed:** `docs/notes/codex-report-m6w-waves.md` records the
isolated field, refined mesh/sampler and car-free shader lab. Final desktop suite:
**760 passing, one pre-existing pending, no SCRIPT ERROR**; calibrated desktop
GPU-height checks pass. Normal gameplay remains unchanged. Mesh preparation is
already about 0.32 s on desktop versus the proposed 0.25 s phone allowance;
profile it before the early phone gate. One interrupted regression attempt is
retained in the report; the final complete rerun passed. No phone tests or
installation were performed for this groundwork. Do not treat this as the
owner-playable driving feature, hitch resolution or phone acceptance.

**Review follow-up (2026-09-24):** read
`docs/notes/m6w-review-followup-2026-09-24.md` next. Opt-in waves-Off diagnostics
and a phone system trace attribute two reproduced long frames mainly to the
game thread being runnable but off CPU, not a new stall/flood/audio transition.
This is **not a gameplay fix or a universal explanation of historical tails**;
review the evidence before closing the M6A hitch/integration prerequisite.
Wave preparation was profiled and replaced by exact offline-generated,
source/profile-validated packaged assets (no reduced detail or runtime fallback).
Three phone launches: **27–38 ms wave CPU preparation**, separately **154–753 ms
covered first-use wait**; GPU evaluator/triangle parity passed. Full suite now
**765 passing, one pre-existing pending, no SCRIPT ERROR**. These are setup and
parity subchecks, **not the complete Task 4 total-water/frame-time phone gate**.
No live-wave binding is enabled. Finish measurement coverage and that gate after
the M6A prerequisite is resolved; Task 5a owner-feel stop remains mandatory.
Raw CSVs/logs/SQL are committed; the large scheduling trace is local-only under
`runs/m6w-review-data/` (see evidence README). Final diagnostic APK is installed,
one-shot flag consumed, progress unchanged. No merge or push.

**State:** Milestones 1–5 are merged into `master`, plus the 2026-09-23 AWD
balance tuning and the build-speed refactor. Five levels (Rally Road, Muddy
Valley, Frozen Pass, Rock Canyon, and the Test Ground as Free Drive), three
cars. M6A's retested full desktop suite is **736 passing, 1 pre-existing pending, no
SCRIPT ERROR**, with protected geometry and balance fixtures unchanged. Phone
retests missed the original water/setup budgets; the broader approved total-water
gate is not yet verified, and the creek primitive overage is fixed.
Rock Canyon's inherited >3 s phone load miss remains open.
Part B must not begin before A's review, phone acceptance
and owner-authorized merge.

Background, in the order it is usually needed:

- `docs/notes/handover-2026-09-17-rock-canyon.md` — repo rules, tooling and the
  hard-won lessons. Still current.
- `docs/notes/performance-m5.md` and `docs/notes/codex-report-build-speed.md` —
  the loose-stone performance cliff and its activation window, and the
  build-speed refactor. Rock Canyon now builds in **3.9 s** on the phone (was
  6.5–8.0 and climbing across repeats), against a 3 s budget. What remains is
  engine-side node and collision-shape creation, which cannot be threaded
  without separate-thread physics: the sampling path is already inlined.
  **The untried lever is deferral** — the shelf, its stones and its boulders
  (about 1.45 s) sit at 1500 m and are built before the countdown, though the
  player needs about 90 s to reach them.
- `docs/notes/feel-log.md` — how the cars got to where they are, Session 9 most
  recently (the rally cars are AWD and must behave like it).
- `docs/notes/m5-rock-canyon-notes.md` and the dated `rock-canyon-*` notes for
  how that level was built and what the owner accepted. The CP4–CP5 shelf is
  deliberately unforgiving: **do not soften the bank (peaks of 12°, 14°, 13°),
  the gradient or the line.** Its stones are loose on purpose; keep
  `TalusDef.active_distance` set, or the phone drops to 8–10 fps.
- `docs/superpowers/specs/2026-09-17-m5-rock-canyon-design.md` for the design
  Rock Canyon was built from, including what stayed out of scope (water physics,
  a rock-crawler car, car locking).

Key rules (details in the handover):
- **Tests:** `./run_tests.sh unit|scenarios|all` must pass, with no `SCRIPT ERROR`.
- **GDScript:** typed, tabs.
- **Git:**
  - Work on a branch and merge only when the owner says so.
  - Stage files by name, never `git add -A` or `git add .`.
  - Never touch the untracked `tmux-session.sh`.
- **Car physics:** ask the owner before changing anything under `car/` or the values in `surfaces/*.tres`. `tests/scenarios/test_car_balance.gd` and `tests/unit/test_geometry_fingerprints.gd` exist so tuning and level geometry cannot drift unnoticed — never re-record or relax them to make something else pass.
- **Tests vs playing:** never start a test run, benchmark or capture while the owner is playing the game — the second Godot instance freezes.
- **Big changes:** show the owner the plan before starting.
