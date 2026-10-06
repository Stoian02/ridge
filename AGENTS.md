# Ridge — notes for coding agents

**State:** Milestones 1–6 are merged into `master`. Four timed levels (Rally
Road, Muddy Valley, Frozen Pass, Rock Canyon) plus the Test Ground as Free
Drive, three cars, water physics everywhere water appears, and wave prototyping
on the Test Ground. The merged suite was verified at 799 passing, one inherited
pending, no `SCRIPT ERROR`; this is not a fresh Coastal test result.

**In flight: Coastal Highway Part B1** on `m6b-coastal-highway`, handed to
Codex in `docs/notes/handover-codex-2026-09-27-coastal-b1.md`. The design is
`docs/superpowers/specs/2026-09-26-m6b-coastal-highway-design.md`; **read its
§13 first**, the owner's decisions, which constrain the proposals in the rest of
it. In short: **B1 is the driving** (route, tunnel, mandatory gap jump, stone
bridge, surfaces, presentation) and **B2 is the water**, each with its own plan,
review and phone acceptance; levels over 2 km get a **5 s build budget**, with
deferral rather than another raise if it is exceeded; and water keeps the
**6 ms p95 / 7 ms p99** ceiling, where exceeding it cuts features. The jump
feasibility gate for all three cars comes before any scenery.

**B1 implementation plan (2026-09-27):**
`docs/superpowers/plans/2026-09-27-m6b1-coastal-highway.md` was approved by the
owner; implementation started 2026-10-06. The owner confirmed usual TC of
**15–20%**, so coverage includes **0%, 15%, 20% and 100%** for each car.
The first delivery is the dry route greybox and true gap, with an explicit
**owner-feel stop before structures or scenery**. See
`docs/notes/m6b1-jump-feasibility.md` for current evidence and limitations.
Launch `debug/coastal_playcheck.tscn` for the uncatalogued jump preview; it starts
at the 730 m approach checkpoint, not the beginning of the full route.
B2's local surface patches, water bodies, sea and timed-level waves stay out.
Do not advance to Task 4 until the owner explicitly approves the jump's feel.
First-delivery checks: **813 passing, one inherited pending, no script errors**;
48 all-car jump cases and three normal-speed rendered PC smokes passed. The
14 m gap has a longer 10° ramp; held-throttle Tuned Rally landing harshness is
explicitly awaiting owner judgment. PC peak is 130 draws / about 212k primitives.
The phone was unavailable; no phone budget acceptance is claimed. Implementation
commits end at `203d2b7`; the report/evidence follow separately. No merge/push.

## Milestone 6, as merged

- **Water physics** (`water/`): depth-dependent drag, temporary flotation and
  sinking, steady currents, translucent water, and engine stalls after 3.00 s of
  continuous intake submersion. Live in Rock Canyon's ford and rut puddles,
  Muddy Valley's creek, and three Test Ground water areas. Cars gained a
  `water_profile`; their dry tuning is unchanged and guarded by
  `tests/scenarios/test_car_balance.gd`.
- **Waves** (`water/waves/`): ambient waves, vehicle entry, bow crest and a
  trailing wake, with physics sampling the same displaced surface that is drawn
  (CPU/GPU parity measured at sub-micron error against a 1 mm gate). **Test
  Ground only, default Off**, chosen from Pause → Water waves. Rolling waves out
  to timed levels is a separate, unapproved piece of work.
- **The long-frame "hitch" is closed as platform behaviour.** See
  `docs/notes/m6-hitch-phone-reproduction-2026-09-27.md`: across 291 s and
  17,480 traced phone frames, twelve of thirteen frames over 33.3 ms occurred
  within 0.10 s of a measurement case starting, and the single warmed-state one
  showed identical work (same queries, triangles and state) taking twenty times
  longer — a descheduled or down-clocked thread, not game work. Warmed running
  shows about one long frame per five minutes and the owner sees none in play.
  Do not reopen it without new evidence of a *different* shape.

**Performance gates that remain unmet, knowingly:** the Test Ground total-water
CPU limits (6 ms/frame p95, 7 ms/frame p99) fail in synthetic replay and
saturation cases while live driving and five-minute soaks pass; the matched GPU
increment is +0.64–0.92 ms against a +0.50 ms target. The owner accepted these
after playtesting at a sustained 60 fps. They are optimisation targets, not
blockers, and they are not licence to spend the same headroom again on a new
level.

## Background, in the order it is usually needed

- `docs/notes/handover-2026-09-17-rock-canyon.md` — repo rules, tooling and the
  hard-won engine lessons. Still the best single orientation document.
- `docs/notes/performance-m5.md` and `docs/notes/codex-report-build-speed.md` —
  the loose-stone performance cliff and its activation window, and the
  build-speed refactor. Rock Canyon builds in **3.9 s** on the phone against a
  3 s budget; the sampling path is already inlined, so what remains is
  engine-side node and collision creation. **The untried lever is deferral** —
  Rock Canyon builds its 1500 m shelf, stones and boulders (about 1.45 s) before
  the countdown, though the player needs about 90 s to reach them.
- `docs/notes/feel-log.md` — how the cars came to feel as they do. Session 9 is
  the most recent: the rally cars are all-wheel-drive and must behave like it.
- `docs/notes/codex-report-m6a-water.md`, `codex-report-m6w-waves.md` and the
  dated `m6a-*`/`m6w-*` notes — what was built, measured and left open in
  Milestone 6, including the retained failures.
- `docs/notes/m5-rock-canyon-notes.md` and the dated `rock-canyon-*` notes —
  how that level was built and what the owner accepted. The CP4–CP5 shelf is
  deliberately unforgiving: **do not soften the bank (peaks of 12°, 14°, 13°),
  the gradient or the line.** Its stones are loose on purpose; keep
  `TalusDef.active_distance` set, or the phone drops to 8–10 fps.
- The specs under `docs/superpowers/specs/` for each milestone's agreed design
  and, just as usefully, what each one ruled out of scope.

## Key rules

- **Tests:** `./run_tests.sh unit|scenarios|all` must pass with no
  `SCRIPT ERROR`. The full suite takes about eight minutes now.
- **GDScript:** typed, tabs, `##` doc comments.
- **Git:** work on a branch; merge only when the owner says so; never push.
  Stage files by name, never `git add -A` or `git add .`. Never touch the
  untracked `tmux-session.sh` or the owner's modified `project.godot`, and never
  discard working-tree state — use a separate `git worktree` if you need another
  branch's files.
- **Car physics:** ask the owner before changing anything under `car/` or the
  values in `surfaces/*.tres`. `tests/scenarios/test_car_balance.gd` and
  `tests/unit/test_geometry_fingerprints.gd` exist so tuning and level geometry
  cannot drift unnoticed — **never re-record or relax them** to make something
  else pass.
- **Measure on the phone, not the desktop.** This project has been caught out
  repeatedly: 485 awake stones cost 6 ms on the desktop and 58 ms on the phone;
  ambient waves looked free on the desktop and cost 2.7 ms a frame on the
  device. A desktop result is a hypothesis.
- **Tests vs playing:** never start a test run, benchmark or capture while the
  owner is playing — the second Godot instance freezes. Check with
  `ps -eo pid,args | grep "godot --path ."` first, and never kill their process.
- **Big changes:** show the owner the plan before starting.
