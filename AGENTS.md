# Ridge — notes for coding agents

**Current handoff:** read `docs/notes/loose-rock-prototype-2026-09-19.md` first.
The owner approved wheel-to-moving-rock physics and a Test Ground prototype,
but wants to playtest it before shelf integration. Stop for that feedback.
The later approved design boundary is checkpoint 4 to checkpoint 5; preserve
the easier finish after checkpoint 5. The earlier dense-rock pass is accepted.

Start with the latest rock-density pass: `docs/notes/rock-canyon-dense-rocks-2026-09-19.md` (700 mixed-size fixed rocks before the widening, deeper S-bend holes and more rubble; accepted tree unchanged). Then read the underlying checkpoint-to-waterfall pass: `docs/notes/rock-canyon-waterfall-approach-2026-09-18.md`. Stop at the waterfall for owner PC playtest. The preceding opening is documented in `docs/notes/rock-canyon-opening-2026-09-18.md`. Read `docs/notes/m5-rock-canyon-notes.md` for the full Milestone 5 completion state on `m5-rock-canyon` (not merged), and `docs/notes/handover-2026-09-17-rock-canyon.md` for the repo rules. The completion notes supersede the older Task 6 WIP handover; the later passes replace their fixed-talus layout, while keeping dynamic talus disabled. They cover:
- the current branch and state
- the open request
- how to run tests
- repo conventions
- what comes next

Key rules (details in the handover):
- **Tests:** `./run_tests.sh unit|scenarios|all` must pass, with no `SCRIPT ERROR`.
- **GDScript:** typed, tabs.
- **Git:**
  - Work on a branch and merge only when the owner says so.
  - Stage files by name, never `git add -A` or `git add .`.
  - Never touch the untracked `tmux-session.sh`.
- **Car physics:** ask the owner before changing anything under `car/` or the values in `surfaces/*.tres`. Milestone 5 adds new surface files and grip-table entries, which is approved; it changes no existing value.
- **Tests vs playing:** never start a test run, benchmark or capture while the owner is playing the game — the second Godot instance freezes.
- **Big changes:** show the owner the plan before starting.
