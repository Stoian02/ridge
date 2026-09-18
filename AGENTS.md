# Ridge — notes for coding agents

Start with the latest handover: `docs/notes/handover-2026-09-18-codex-m5.md` (Milestone 5 in progress on branch `m5-rock-canyon`: Tasks 1–5 done, Task 6 WIP, 7–11 to do), then `docs/notes/handover-2026-09-17-rock-canyon.md` for the repo rules. They cover:
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
