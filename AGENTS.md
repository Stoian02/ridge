# Ridge — notes for coding agents

Start with the latest handover: `docs/notes/handover-codex-2026-09-14.md`. It covers:
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
- **Car physics:** ask the owner before changing anything under `car/` or the values in `surfaces/*.tres`.
- **Big changes:** show the owner the plan before starting.
