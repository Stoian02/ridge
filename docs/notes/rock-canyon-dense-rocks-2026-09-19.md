# Rock Canyon — dense rock bed and rougher S-bends (2026-09-19)

Owner's next playtest feedback: the section after the 700 m checkpoint needs
many large boulders and smaller stones, like the supplied photo of a densely
packed boulder bed. End the rocks where the track starts widening. Keep the
tree as it is; add deeper holes and scattered rocks to the S-bends.

Implemented on `m5-rock-canyon`, not merged or pushed. This supplements the
[checkpoint-to-waterfall pass](rock-canyon-waterfall-approach-2026-09-18.md).
Implementation commits: `10585f9` (burial support) and `243cb09` (level and tests).
**Stop at the waterfall for the next owner PC playtest.** The curve, width
profile, tree, ford, earlier opening and later shelf/finish were not redesigned.
No car code or existing surface-resource values changed.

## What changed

- The rock bed runs from **710–888 m**, leaving the checkpoint launch clear and
  ending before the widening begins at **890 m**. Geometry tests check the
  actual transformed rock vertices, not just their centre positions.
- **700 fixed rocks** replace the previous 38 in the crawl: **400 medium bed
  stones, 80 large boulders and 220 small stones**. The large rocks frame and
  intrude into the available lines; medium and small stones cover the centre
  too. Every ten-metre interval has substantial coverage, with no old empty
  gap between the two bed fields. Grey/tan/sandstone colours distinguish sizes
  and make the bed readable against the canyon.
- Medium rock radii are 0.58–0.88 m, embedded 25–27 cm into the road. Their
  broad crowns make real wheel obstacles without turning each rock into a
  chassis-height wall. Large radii are 1.0–1.75 m, small radii 0.16–0.34 m.
  The three existing rock shelves remain unchanged.
- `BoulderFieldDef.burial_depth` lowers the visible mesh and complete convex
  hull together. Default zero leaves other fields untouched; the fixed-rock
  builder retains one MultiMesh per field. No dynamic stones were re-enabled.
- In the **1150–1240 m S-bends**, diagonal channel depths are now **30/38/35/27 cm**
  (previously 20/27/25/18). The third channel is broadened from 2.4 to 3.2 m
  so the deeper floor is accurately represented by the road triangles; the
  existing 6 cm collision/profile agreement test remains unchanged in tolerance.
- Three independently seeded pothole pockets occupy the spaces between the
  channels: 1166–1178, 1191–1204 and 1215.5–1226.5 m. Their depth ranges reach
  **34–38 cm**, with radii 0.5–1.2 m. Their footprints cannot overlap the diagonal
  channels, preventing accidental summed-depth pits.
- **40 scattered rocks** join the existing 14 tilted slabs in the S-bends.
  All finish before the 1250 m checkpoint and flatter waterfall approach.
- The accepted tree at **940 m** and its crossing lines are unchanged.

## Tuning locations

`levels/rock_canyon/rock_canyon_trail.tres`:

- `Wash1`, `Wash2`: dense embedded bed.
- `CrawlBoulders`, `CrawlOuterBoulders`, `CrawlSmallStones`: size layers.
- `CrossRut1–4`: diagonal channel shapes.
- `S_ChartedHoles1–3`: pothole pockets between those channels.
- `S_ScatteredRocks`: extra S-bend rubble; `WashoutSlabs` remains the older slab field.

The stock image was viewed as a layout/size reference only; it was not added
to the game. Existing procedural low-poly geometry is used throughout.

## Validation

Final full suite:

```sh
XDG_DATA_HOME=/tmp/ridge-m5-data XDG_CONFIG_HOME=/tmp/ridge-m5-config ./run_tests.sh all
```

**612 passed, 1 existing pending** (gas-held rally kicker), 88 scripts,
40,838 assertions, 215.676 s, exit 0, no `SCRIPT ERROR`.
Log: `/tmp/ridge-dense-rocks-all.log`. The existing three tracks' geometry
fingerprints remain unchanged. Master remains at `cb20c09`.

All eight Rock Canyon scenarios passed in the full-suite run. The 4×4
completed the full trail in **5:55.2**, no resets, minimum upright 0.940.
Checkpoint-to-clearing crawl: **71.01 s**, versus 56.98 s before this pass;
maximum lateral deviation 0.52 m. The denser centre is therefore traversed,
not avoided on the shoulder. S-bend: **33.14 s**, minimum upright 0.978. Both tree
lines still cross slowly and the ford has zero airborne ticks. The initial
focused run also passed all eight scenarios (`/tmp/ridge-dense-rocks-first-driving.log`).

Focused geometry tests verify burial/render/collider parity, mixed sizes and
central coverage, the widening boundary, depth/footprint separation, and road
clearance beneath the deeper grooves and holes. Integrated road-floor ray
checks explicitly exclude visible boulders: a rock over a crater is intended,
whereas terrain filling the crater is not. Separate boulder and driving tests
continue to check the actual rock collisions.

First visual pass, 1280×720 Forward Mobile, Off-road 4×4: **1.23 s** rendered build.
Log: `/tmp/ridge-dense-rocks-shots.log`; images in ignored `build/level_shots/`.

| Distance (m) | Primitives | Draw calls |
| --- | ---: | ---: |
| 710 | 223,716 | 94 |
| 735 | 237,216 | 89 |
| 780 | 250,456 | 91 |
| 810 | 206,948 | 89 |
| 865 | 234,940 | 91 |
| 895 | 273,084 | 85 |
| 925 | 220,488 | 86 |
| 1163 | 182,354 | 91 |
| 1180 | 192,166 | 99 |
| 1205 | 150,734 | 95 |
| 1230 | 152,826 | 96 |

All sampled views are below 300k primitives / 150 draw calls. These are rendered
counts, not a sustained phone-FPS claim. Final S-bend capture after broadening
the third channel: **1.12 s** build; 150,726 primitives / 95 calls at 1205 m,
145,258 / 93 at 1210 m. Both were visually checked. Final capture log:
`/tmp/ridge-dense-rocks-final-s.log`. No phone install this pass.

Tests/captures use isolated saves and configs under `/tmp/ridge-m5-data` and
`/tmp/ridge-m5-config`, with one Godot instance at a time. Owner changes in
`project.godot` and untracked `tmux-session.sh` remain untouched.

## Handoff

Ready for the owner to judge the denser crawl's line choices and the rougher
S-bends in the 4×4. Keep the tree and the waterfall stopping point; wait for
feedback before continuing the track.
