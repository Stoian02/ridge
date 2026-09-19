# Shelf acceptance and visible-surface correction

Branch: `m5-rock-canyon`; not merged or pushed. The owner reports they can pass
CP4–CP5 by being careful and explicitly asks to mark it passed. **Owner PC
playtest: passed; difficulty accepted.** Keep the 12°/14°/13° banks, route, width,
4,747 movable stones, car physics and surface values. Earlier accepted sections
and the easier finish after checkpoint 5 are not being redesigned.

Implementation commit: `9dc352a` (surface/collision alignment and natural cliff).

The owner then reported misleading grey road/terrain contact and a stretched
left mountain. This follow-up addresses those, not the accepted difficulty.

## Diagnosis and changes

- The fine-gravel bed was a separate non-colliding ribbon, with different rows
  and triangulation from RoadBuilder. Initial probes found up to **8.09 cm**
  mismatch and five contacts on underlying dirt. The gravel shader now runs
  directly on the **colliding RoadBuilder mesh**. Material boundaries receive
  exact rows, including the talus endpoints. No separate `GravelBed` exists.
- Near 1888–1900 m the smoothed, coarse terrain collision also protruded through
  the changing bank/shoulders by up to **7.98 cm**. Local earthworks conservatively
  lower every heightmap corner supporting a gravel road cell, below its lowest
  road vertex by the existing terrain clearance. This covers either heightmap
  diagonal. It does not raise or flatten the road. Only gravel-bed footprints
  and their supporting grid corners are affected.
- The solid subgrade now follows the road's actual rows, lateral stations and
  triangle diagonal; convex triangular prisms replace convex full-width quads
  that could bridge a twisting bank. Tops sit 2 mm below the road, with a 2 mm
  hull margin. Existing buried terrain support remains. Both exposed road edges
  have visible, matching colliding faces extending down into the ground.
- The left cliff has seeded irregular sandstone beds, ledges, recesses and
  several steps back into the existing mountain. It remains closed and uses
  matching visual/collision triangles. The toe respects the **total** drivable
  width, including widening shoulders at the ends, not just the narrow road.
  No curve relocation, extra obstacles, grip changes or difficulty reduction.

## Verification

The focused five-test shelf suite passes. The new regression probes real
rendered gravel triangles (centres and near edges), excluding real boulders and
loose stones: **2,030 probes, worst gap 0.0001 m, zero terrain contacts**.
Degenerate zero-area triangles where a shoulder collapses are intentionally
skipped because they have no rendered area. Additional assertions check cliff
relief stays outside both narrow road and widening shoulders.

Desktop visual check: 1280×720, Forward Mobile, AMD Radeon 880M; build **2.42 s**.
Views at 1515/1575/1670/1850/1888/1898 m stay below the existing budgets:
maximum **255,188 primitives**, maximum **127 draw calls**. The 1670 m view is
160,166 primitives / 110 calls. Captures are in ignored `build/level_shots/`;
log `/tmp/ridge-shelf-natural-shots.log`. These are screenshot measurements,
not sustained-FPS or phone results. The more exact solid support costs extra
build time (shelf phase ~0.82 s versus the previous coarse support's ~0.08 s).

`./run_tests.sh all`: **633 passed, 3 failed, 1 pending**, 92 scripts, 637 tests,
321.548 s, exit 1, **no `SCRIPT ERROR`**. All **559 unit tests** pass, including
the unchanged earlier-level geometry checks. Log:
`/tmp/ridge-shelf-surface-all.log`. The existing jump-landing pending test remains.

The three failures are driving acceptance checks, not waived by the owner's
manual pass; their assertions have not been weakened:

- Whole-shelf driver slides off at **1671.14 m**, moves **932 stones**, peaks at
  **208 awake** (provisional bound 150) and **24.82 m/s** fragment speed. No stone
  penetration below the terrain detected. This reproduces the preceding shelf
  driver's failure near 1670 m; it does not indicate that the owner's pass failed.
- Relaunch/repeat-pass driver still slides off the 14° bank near 1678 m.
- The full Rock Canyon driver also goes off that bank, stopping at **1677.62 m**
  with +13.96 m lateral displacement, after 342.5 simulated seconds. The previous
  handoff warned this full-run check had not been rerun. Its failure is now
  explicitly measured; a green full-suite release is **not** claimed.

## Resume

Stop for the owner to inspect the corrected road edge and mountain. Keep the
accepted difficulty. No phone installation or merge requested in this pass.
Use isolated test saves; check host Godot processes before any test/capture and
never run a second instance while the owner is playing. Leave the owner's
`project.godot` edits and untracked `tmux-session.sh` alone.
