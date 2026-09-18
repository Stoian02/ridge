# Rock Canyon — checkpoint to waterfall (2026-09-18)

Owner approved the next section-by-section pass: continue to the 700 m
checkpoint, narrow into a rock crawl, open into dirt with a diagonal fallen
tree, climb more steeply, then a washed-out S-bend before the waterfall.
**Stop here for owner PC playtest. Do not redesign the later shelf or finish.**
Work remains on `m5-rock-canyon`, not merged or pushed.
Implementation commits: `931cd27` (obstacle support) and `b76f502` (level and tests).

This supersedes the old fixed-talus layout at 1150–1250 m, but not the decision
to keep dynamic talus disabled. The [opening pass](rock-canyon-opening-2026-09-18.md)
and [M5 completion notes](m5-rock-canyon-notes.md) remain useful background.

## Built sequence and tuning

- The opening curve segments, asphalt/mud damage, wheel paths and first clearing
  are retained through 700 m. The checkpoint remains full width.
- From 704 m the road eases down to **5.75 m**, with 1 m shoulders. The crawl
  has exposed rock from 720–890 m, two fields of fixed boulders/tilted slabs,
  and shelves at **758, 814 and 868 m**. Shelf rises are 35, 50 and 30 cm;
  only the first spans the whole narrowed road. The second is on the right,
  the third on the left, with ramped alternatives. Their permanent cumulative
  rise remains 1.15 m. Crawl grades increase from 5.5% to 6.5%.
- At 900–990 m the road opens to **10 m**, with 3 m shoulders, and the authored
  canyon walls recede. The dirt clearing continues uphill at 6.5%.
- A **12 m tapered fallen tree at 940 m**, angled 25 degrees across the road,
  has a thick left root and thinner right end. The lower trunk is partly buried.
  Measured visible heights above this road are about 25 cm on the left,
  18 cm at the centre and 14 cm on the right. Broken roots stay off the
  carriageway. It is fixed, with the existing `logs` surface and no physics change.
- At 990 m the road narrows again. Dirt climbs at **9–9.5%**, with additional
  independently seeded holes through 1142 m: density 28→42/100 m, radius
  0.55–1.25 m, depth 7–24 cm. Existing small wash potholes remain.
- The old straight fixed-talus field becomes an **S-bend around 1150–1250 m**:
  radius 47.746 m, turns +30/-60/+30 degrees, unchanged exit heading.
  Four diagonal erosion channels at **1161, 1185, 1210 and 1231 m** alternate
  direction and the easier side. Depths are 20/27/25/18 cm, widths 2.4–2.8 m
  along the road, with rounded sides and tapered ends. Fourteen offset fixed
  slabs replace the 40 scattered stones. The exposed rock bed is lighter than dirt.
- The technical features finish before 1240 m; the road widens back for the
  **1250 m checkpoint**. A short flat approach leads into the existing
  **1290 m waterfall/ford**. Ford definition, banks and wet-rock transitions are unchanged.
- Later curve segments and obstacle definitions are retained. As with the opening
  pass, regenerating from a higher exit carries the later route upward and shifts
  it slightly in world space; this is not an absolute-coordinate freeze. The
  trail is now about **2175 m** overall, with **112 m** total curve rise.
  No car code or existing surface-resource values changed.

Data lives in `levels/rock_canyon/rock_canyon_trail.tres` (`CrawlRock`, `Step1–3`,
`Wash1–2`, `FallenTree`, `BrokenClimb`, `CrossRut1–4`, `WashoutSlabs`, width stretches).
Tree defaults are in `levels/trail/fallen_tree_def.gd`; overrides can be authored
on the `FallenTree` subresource. Wall openings are in `rock_canyon_terrain.tres`.
Regenerate the curve using `tools/generate_rock_canyon_curve.gd`, never by editing
the generated curve resource by hand.

## Safeguards and tests

- Optional `CrossRutDef` channels enter both road-mesh and collision geometry.
  Workers receive value-only snapshots and inline the same maths as the serial
  reference. Darker channel shading follows the depression. Fine rows cover
  each channel's entire diagonal footprint.
- Terrain cuts include the complete grid-triangle footprint beneath a channel,
  preventing the heightmap from invisibly bridging the groove.
- Each fallen tree is one 120-triangle mesh and one matching concave collider,
  tagged `logs`, culled visually at 200 m. Collision is never culled. No hidden
  box, oversized hull, dynamic trunk or branch spike across the driving line.
- Empty feature arrays preserve other tracks. Regression checks cover threaded/
  serial equivalence across a chunk boundary and narrowed rows, collision rays,
  tree taper/normals, terrain clearance, section widths/grades/turns, driver caution
  zones, the existing level fingerprints and driving scenarios.
- The first shelf was trimmed to the narrowed road-plus-shoulder width after
  visual review; its old full-width ends otherwise overhung the new road edges.
- Tests and captures use isolated saves/configs under `/tmp/ridge-m5-data` and
  `/tmp/ridge-m5-config`. Never run them alongside the owner's Godot session.
  `project.godot` and untracked `tmux-session.sh` remain untouched.

## Desktop validation

Final full suite:

```sh
XDG_DATA_HOME=/tmp/ridge-m5-data XDG_CONFIG_HOME=/tmp/ridge-m5-config ./run_tests.sh all
```

**609 passed, 1 existing pending** (gas-held rally kicker), 88 scripts, 39,746
assertions, 214.651 s, exit 0, no `SCRIPT ERROR`. Log:
`/tmp/ridge-waterfall-all.log`. The three existing tracks' geometry fingerprints
remain unchanged.

All eight Rock Canyon driving scenarios passed. The 4×4 completed the whole track
in **5:32.4** without resets (minimum upright 0.947). From rest, the new crawl reached
the tree clearing in **56.98 s** and the washed-out S reached the waterfall approach
in 32.77 s, staying within the road. Both centre and right-hand tree crossings
touched actual log collision and passed at about 2–3 m/s, without a run-up.
The ford crossing had zero airborne physics ticks. Star times remain placeholders.

Visual capture used `tools/level_shots.tscn`, 1280×720, Forward Mobile, Off-road 4×4.
Rendered build: **1.08–1.16 s**. Logs: `/tmp/ridge-waterfall-shots.log` and
`/tmp/ridge-waterfall-final-shelf.log`.
Images: ignored `build/level_shots/rock_canyon_offroad_4x4_*.png`.

| Distance (m) | Primitives | Draw calls |
| --- | ---: | ---: |
| 705 | 226,480 | 96 |
| 748 | 222,304 | 88 |
| 810 | 194,660 | 86 |
| 855 | 226,380 | 87 |
| 925 | 215,496 | 86 |
| 938 | 212,942 | 89 |
| 990 | 218,874 | 91 |
| 1070 | 221,682 | 92 |
| 1150 | 166,606 | 88 |
| 1180 | 178,574 | 98 |
| 1205 | 143,382 | 94 |
| 1230 | 145,474 | 95 |
| 1260 | 127,306 | 80 |
| 1290 | 97,056 | 75 |

The 748 m view was recaptured after the first shelf's small width trim and
visually verified. Other views precede that reduction in shelf geometry.
All views are below 300k primitives / 150 draw calls.
Screenshot frame-time spikes are capture overhead, not sustained-FPS measurements.
No phone install or phone-performance claim this pass.

## Owner handoff

Drive Rock Canyon with the 4×4 from the 700 m checkpoint through the waterfall,
paying attention to rock line choices, the tree crossing, dirt incline and
washout severity. Stop further track changes until that feedback arrives.
