# Muddy Valley — Mud-Skip Fix Implementation Plan

**Goal:** Make the intended mud racing line unavoidable from the road verges,
while adding one deliberate hidden shortcut on the final climb.

**Spec:** `docs/superpowers/specs/2026-09-14-muddy-valley-mud-skip-design.md`

## Constraints

- Typed GDScript with tabs.
- No car or surface-tuning changes.
- Stage files by name and never touch `tmux-session.sh`.
- Run `./run_tests.sh unit|scenarios|all`; no `SCRIPT ERROR` is acceptable.

## Task 1: Mud shoulders

- Extend `RoadBuilder` face selection so road and shoulder quads are grouped by
  the surface applying to that row.
- Keep dirt shoulders outside stretches and on trails without stretches.
- Blend shoulder vertex colour into the stretch colour.
- Update road-builder unit coverage and run the Rally Road regression test.

## Task 2: Hedge builder

- Add hedge run, opening and return settings to `TrailDef`.
- Add a small public hedge-bush mesh to `LowPolyMeshes`.
- Add `HedgeBuilder`: deterministic bush transforms, terrain-chunk
  `MultiMesh` buckets, longitudinal collision segments, screened openings and
  outward end returns.
- Build hedges in `TrailLevel` after terrain generation.
- Add focused unit tests for placement, collision extents and openings.

## Task 3: Muddy Valley layout and driving scenarios

- Configure hedges beside all three mud stretches.
- Add the final-climb entry and exit openings.
- Add a direct-bypass scenario and a shortcut traversal scenario.
- Keep the existing whole-level scripted-driver scenario green.
- Tune only hedge placement, opening width and generated hedge geometry.

## Task 4: Verification

- Run the unit suite, scenario suite and complete suite.
- Re-run the level-shot tool at 15, 320, 560, 760, 1000, 1250 and 1450 m.
- Record peak primitives and draw calls in the Muddy Valley performance note.
- Commit the implementation by explicitly named files, then ask the owner about
  merging the branch.
