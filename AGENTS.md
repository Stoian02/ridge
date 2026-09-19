# Ridge — notes for coding agents

**Current handoff:** read `docs/notes/shelf-surface-fix-2026-09-19.md` first,
then `docs/notes/loose-rock-shelf-2026-09-19.md` for the underlying implementation.
The owner approved dense loose stones and the close left hillside on CP4–CP5.
They explicitly rejected easing the difficult bank: keep peaks of 12°, 14°, 13°.
Their careful PC pass is now **accepted**; do not soften the shelf. The latest
follow-up aligns the visible gravel with road collision, clears underlying
terrain, closes roadbed sides, and replaces the stretched cliff with rock strata.
Focused scripted driving still fails on the steep shelf; do not claim a green
full suite or soften the level to make that driver pass. Preserve the easier
finish after CP5 and the accepted earlier sections. Owner playtest acceptance
does not mean automated release acceptance. Stop for feedback on the visual fix.
This supersedes the older notes' disabled-talus fallback and prototype-only gate.

Earlier accepted work: `docs/notes/rock-canyon-dense-rocks-2026-09-19.md` (700 mixed-size fixed rocks before the widening, deeper S-bend holes and more rubble; accepted tree unchanged), and the underlying checkpoint-to-waterfall pass: `docs/notes/rock-canyon-waterfall-approach-2026-09-18.md`. Their old stop-at-waterfall gate has been passed. The preceding opening is documented in `docs/notes/rock-canyon-opening-2026-09-18.md`. Read `docs/notes/m5-rock-canyon-notes.md` for the original Milestone 5 completion state on `m5-rock-canyon` (not merged), and `docs/notes/handover-2026-09-17-rock-canyon.md` for the repo rules. The completion notes supersede the older Task 6 WIP handover; later passes replace their fixed-talus layout, and the current shelf handoff supersedes their disabled-dynamic-talus state. They cover:
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
