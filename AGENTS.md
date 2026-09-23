# Ridge — notes for coding agents

**State:** Milestones 1–5 are merged into `master`, plus the 2026-09-23 AWD
balance tuning and the build-speed refactor. Five levels (Rally Road, Muddy
Valley, Frozen Pass, Rock Canyon, and the Test Ground as Free Drive), three
cars. The full suite is green at 654 passing, 1 pending. Nothing is in flight.

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
