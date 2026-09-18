# Handover to Codex — Milestone 5, Rock Canyon (2026-09-18)

Written by Claude on the owner's "stop here" after the Claude subagent budget ran out mid-task. Read this, then the plan, then the spec.

## 1. Where things stand

- **Branch:** `m5-rock-canyon` (from master `cb20c09`). Do not merge, do not push. The owner decides after the phone test.
- **Plan:** `docs/superpowers/plans/2026-09-17-m5-rock-canyon.md` — 11 tasks with full code and tests. **Spec:** `docs/superpowers/specs/2026-09-17-m5-rock-canyon-design.md` (binding).
- **Tasks 1–5 are done, reviewed and committed:** road width profile (with geometry fingerprints proving the three shipped levels bit-identical), the four surfaces + grip + feel + rock/waterfall sounds, canyon walls, rock steps, boulder fields. Unit suite was 460/460 at `ce69736`.
- **Task 6 (talus) is a WIP commit `deb4ace` on top — unverified.** The subagent writing it was killed by an API limit while reproducing a freeze that happens when `test_pause_menu` runs before `test_talus` in one GUT run (its last words: "re-run the reproduction scenario (test_pause_menu then test_talus) to check the freeze-based fix"; no fix was applied — `grep freeze levels/trail/talus_builder.gd` finds nothing). The draft has the two controller corrections already (`Array(gates).any(...)`, road-length clamp) and a test seam `TalusBuilder.instance_transforms` because headless Godot drops MultiMesh instance data.
- **Tasks 7–11 not started:** ford + waterfall, throttle lever, recommended car, the level itself, scenarios + notes. Briefs for every task are already extracted in `.superpowers/sdd/2026-09-17-m5-rock-canyon/task-N-brief.md` (git-ignored; if missing, they are just the plan's task sections).
- `project.godot` is modified in the working tree (the owner's editor re-save) — leave it alone, never stage it. `tmux-session.sh` is the owner's untracked file — never touch it.

## 2. What to do next

1. **Finish Task 6.** Run `./run_tests.sh unit` (check no Godot is running first: `ps -eo pid,args | grep "godot --path ." | grep -v grep` must print nothing; never kill the owner's Godot). If `test_talus` alone passes but hangs after `test_pause_menu`, the likely cause is the paused SceneTree / physics state left by the pause-menu test (its `after_each` unpauses, but sleeping RigidBody3Ds created while the tree was paused may never register); a `RigidBody3D.freeze`-based approach (freeze stones until first contact, or set `sleeping` deferred after a physics frame) is what the subagent was about to try. Get it green with no `SCRIPT ERROR`, then amend the WIP into a proper commit ("Add the loose talus field of sleeping rigid stones") with the plan's commit trailer.
2. Continue with Tasks 7–11 in order, exactly per the plan (each task: failing test first, implement, focused tests, `./run_tests.sh unit` once, commit by named files). Task 11 ends with `./run_tests.sh all` green, `docs/notes/m5-rock-canyon-notes.md`, and AGENTS.md pointing at those notes.
3. Do not stop between tasks to ask; do not merge.

## 3. Rulings already made (carry them forward; they override the plan's literal text where they conflict)

- No git worktree: work on the branch in this checkout.
- Checkpoint gates follow the taper but never exceed today's 12 m (`CheckpointPlacer.gate_width_at`).
- Rock step faces are vertical for `RockStepDef.LEDGE_SHARE = 0.6` of their height with a sloping lip (a sphere-cast wheel cannot mount a face taller than the chassis clearance); face jitter is non-positive (`randf_range(-JITTER, 0.0)`) so the rock plane stays in front of the road's 2 cm step quad.
- `BoulderBuilder.BURY = 0.0`: a 0.45 m boulder stands 0.21–0.32 m (the plan's "−0.1 / 0.74 r" was wrong). Boulder and talus fields are clamped to `sampler.length - 1.0`.
- The second Rock Canyon rock step spans +1.0..+3.5 m (spec says +0.5); partial-face lateral edges must be multiples of 0.5 m (the road's station grid).
- `PackedFloat32Array` has no `.any()` in 4.7.2: use `Array(x).any(...)`.
- `RoadSampler` keeps a default `TrailDef` when built with two arguments; builders must get their sampler from `TrailLevel` (which passes the trail) and tests must pass the trail (`RoadSampler.new(curve, banking, trail)`).
- `half_total_width()` now means the widest half-width; `hedge_builder.gd` and `shortcut_builder.gd` still read it as the local edge — harmless for Rock Canyon (no hedges, no shortcut); mention in the M5 notes.
- Headless Godot drops MultiMesh instance data: test through builder-side arrays (`BoulderBuilder.placed`, `ScatterBuilder.post_transforms`, `TalusBuilder.instance_transforms`).
- Deferred minors for the final review are listed in the SDD ledger `.superpowers/sdd/2026-09-17-m5-rock-canyon/progress.md` (git-ignored; read it if present).

## 4. Standing rules (unchanged, from `docs/notes/handover-2026-09-17-rock-canyon.md`)

Ask before changing anything under `car/` or values in existing `surfaces/*.tres`; stage by name; commit trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` (Codex may use its own attribution line instead); never run Godot while the owner is playing; typed GDScript with tabs; no worker-thread calls on shared objects; every loop needs the `LOOP_PAD` tail and players stop in `_exit_tree()`.
