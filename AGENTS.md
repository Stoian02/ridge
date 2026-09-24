# Ridge — notes for coding agents

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
meet the drawing budgets. **Phone acceptance is still pending:** the strict
water/setup gates still fail, total frame p95 did not improve in the ford A/B,
and one current-pool case contains unexplained long frame intervals (up to
79.459 ms). The frame-based gate proposal is not an approved replacement for
the spec.
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
recorded in `docs/notes/water-waves-followup.md` for later brainstorming.
Its order relative to Coastal Highway is not yet approved; implement neither
as part of this performance retest.

**State:** Milestones 1–5 are merged into `master`, plus the 2026-09-23 AWD
balance tuning and the build-speed refactor. Five levels (Rally Road, Muddy
Valley, Frozen Pass, Rock Canyon, and the Test Ground as Free Drive), three
cars. M6A's retested full desktop suite is **736 passing, 1 pre-existing pending, no
SCRIPT ERROR**, with protected geometry and balance fixtures unchanged. Phone
retests still fail the water/setup budgets; the creek primitive overage is fixed.
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
