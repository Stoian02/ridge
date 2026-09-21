# Ridge — notes for coding agents

**State:** Milestones 1–5 are merged into `master` (Rally Road, Muddy Valley,
cars and car select, surface feedback and sound, Frozen Pass, Rock Canyon).
The full suite is green. Nothing is in flight.

**Start with** `docs/notes/handover-2026-09-17-rock-canyon.md` for the repo
rules, tooling and the hard-won lessons, then:

- `docs/notes/performance-m5.md` — the loose-stone performance cliff and the
  activation window that fixes it, plus **the deferred load-time work**: Rock
  Canyon builds in ~5.7 s on the phone against a 3 s budget, and 77% of the
  cost is sampling through shared objects, so wrapping the build phases in
  `WorkerThreadPool` will not help. It needs the M3B-style inlining.
- `docs/notes/m5-rock-canyon-notes.md` and the dated `rock-canyon-*` notes for
  how the level was built and what the owner accepted along the way. The
  CP4–CP5 shelf is deliberately unforgiving: **do not soften the bank
  (peaks of 12°, 14°, 13°), the gradient or the line.** Its stones are loose on
  purpose; keep `TalusDef.active_distance` set, or the phone drops to 8–10 fps.
- `docs/superpowers/specs/2026-09-17-m5-rock-canyon-design.md` for the design
  the level was built from, including what stayed out of scope (water physics,
  a rock-crawler car, car locking).

Key rules (details in the handover):
- **Tests:** `./run_tests.sh unit|scenarios|all` must pass, with no `SCRIPT ERROR`.
- **GDScript:** typed, tabs.
- **Git:**
  - Work on a branch and merge only when the owner says so.
  - Stage files by name, never `git add -A` or `git add .`.
  - Never touch the untracked `tmux-session.sh`.
- **Car physics:** ask the owner before changing anything under `car/` or the values in `surfaces/*.tres`. Milestone 5 added new surface files and grip-table entries, and one approved change in `car/wheel.gd`: wheels apply equal and opposite forces to movable supports, so loose stones react. It changed no existing car or surface value.
- **Tests vs playing:** never start a test run, benchmark or capture while the owner is playing the game — the second Godot instance freezes.
- **Big changes:** show the owner the plan before starting.
