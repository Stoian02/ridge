# Ridge — notes for coding agents

**Current handoff:** read `docs/notes/handover-codex-2026-09-23.md` first — the
open task is the build-speed refactor (Rock Canyon builds in ~5.7 s on the phone
against a 3 s budget), on branch `build-speed`, not merged and not pushed.
It also summarises what shipped recently and the rules.

**State:** Milestones 1–5 are merged into `master` (Rally Road, Muddy Valley,
cars and car select, surface feedback and sound, Frozen Pass, Rock Canyon, plus
the 2026-09-23 AWD balance tuning). The full suite is green.

Background, in the order it is usually needed:

- `docs/notes/handover-2026-09-17-rock-canyon.md` — repo rules, tooling and the
  hard-won lessons. Still current.
- `docs/notes/performance-m5.md` — the loose-stone performance cliff and the
  activation window that fixes it, plus the measurements behind the build-speed
  task: 77% of the cost is sampling through shared objects, so wrapping the
  build phases in `WorkerThreadPool` will not help.
- `docs/notes/feel-log.md` — how the cars got to where they are, Session 9 most
  recently.
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
