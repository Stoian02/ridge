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
**Owner approved the revised jump's feel on October 7 and authorized continuing.**
Task 4 (tunnel and independent stone bridge) is implemented and PC-verified.
Preserve the accepted jump geometry and rerun its gate after
structure/terrain changes. Task 5 (dry sand and transitions) is PC-verified; scenery,
whole-route acceptance, scoring and phone gates remain outstanding.
October 6 first delivery: 813 passing, one inherited pending, no script errors.
**October 7 revision (`0efa994`):** owner requested more airtime and clarified
they lift and balance in flight. Gap is now **18 m, landing 2 m below the lip,
7% downslope**, with the same 10° ramp and reset. The main gate uses ordinary
pedal pitch corrections **in the test driver only**; manual play is unassisted.
36 controlled cases and two off-centre cases passed focused checks. Held-throttle
and uncorrected coasts are separate stress observations, not clean-landing passes;
their harsher results and rejected shapes are retained in the report. Three
normal-speed PC smokes passed (131 draws / about 210k primitives maximum).
Jump-delivery full regression: **814 passing, one inherited pending, no script errors**.
Jump feel is approved; no phone budget acceptance is claimed. No merge/push.

**Structure implementation:** `bd3f57d` tunnel, `f1e3a45` independent stone bridge
and opt-in tunnel floor/join correction, `08ae44b` preview/capture tools. Tunnel
610–710 m; initial bridge 2055–2073 m with asphalt contact, not logs. Manual preview:
`start=course` includes the opening/tunnel; `start=bridge` resets at 1970 m;
default stays at the jump. Six normal-speed PC smokes passed at TC 20%, peaks
133 draws / 209,522 primitives. This is not whole-route or phone acceptance.
The phone was checked and absent. See the implementation plan's dated Task 4
execution record for failed iterations, control strategy and verification.
`81f368f` fixes a typed-array assignment in the new parity fixture; the first
full structure-suite run was stopped after that error and retained, not counted
as a pass. A later runner stall after Rally Road did not reproduce in an isolated
repeat or the final combined run; its cause is unconfirmed and its log retained.
Initial structure source **`81f368f`: 823 passing, one inherited pending, no script errors,
exit 0** (623.793 s). Evidence and reproducible commands are in
`docs/notes/m6b1-jump-data/README.md`.

**Owner bridge refinement (`b845a20`):** happy with the structures; requested
a slightly longer, more arched bridge only. Coastal now spans **2054–2074 m**,
with a **0.30 m deck crest**, **4.5 m masonry arch rise** and 6 m dry channel.
Same centre/width, smooth joins; shared defaults, jump and car tuning unchanged.
14 focused tests and three rendered all-car bridge crossings passed. Fresh full
regression: **825 passing, one inherited pending, no script errors, exit 0**
(620.386 s). The earlier 823-pass claim belongs to the initial shape.
The owner approved this bridge refinement and authorized continuing on October 7.
No phone acceptance, merge or push.

**Task 5 implemented and PC-verified:** firm coastal sand at 1350–1950 and 2250–2550 m,
including darker shoulders with the same traction. Opt-in painted-line fading,
shallow dry ruts, sparse small potholes and mild local undulations; no raised
asphalt patches. Approved new grip entries are additive; no old value changed.
`soft_sand` and `wet_asphalt` are data only for B2, not applied to the road.
Preview `start=sand` at 1330 m or `start=climb` at 2240 m; original starts remain.
Focused sand, jump/structure and old-fingerprint checks passed. Seven rendered
PC smokes passed (maximum 133 draws / 235,332 primitives); this is not phone or
whole-route acceptance. Fresh full regression on `441ff5d`: **832 passing,
one inherited pending, no script errors, exit 0** (648.259 s). Task 6 (coastal
land and scenery) has not started. See the plan's Task 5 execution record for
current evidence. No phone acceptance, merge or push.

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
