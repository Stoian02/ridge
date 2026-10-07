# Coastal B1 jump and structure evidence

See [the checkpoint report](../m6b1-jump-feasibility.md) for scope, criteria,
failures and pending owner/phone acceptance. This directory is ignored by the
Godot importer; none of its evidence becomes a game asset.

## October 7 — dry sand and transitions (Task 5)

Final implementation **`441ff5d`**: `ac2ea81` resources/feedback, `923a5cf`
authoring and opt-in visuals, then previews and integration checks. Both main
stretches are firm sand with matching darker shoulders, shallow ruts and smooth
paint/colour transitions. Mild local undulation and sparse small potholes leave
the accepted structure profiles unchanged. Soft sand/wet asphalt are unplaced
B2 data. No water, scenery, car retune or existing level-data change.

`surfaces-2026-10-07.tar.gz` preserves `runs/m6b1-surfaces-2026-10-07.Hq7iaF/`:
focused unit/driving checks, the failed first checkpoint measurement and its
correction, seven normal-speed PC smokes and trajectories, nine fixed views,
and the final full suite. `surfaces-source.sha256` is the **current** source
manifest; historical manifests below intentionally differ. Fresh full regression:
**832 passing, one inherited pending, 629,413 assertions across 135 scripts,
648.259 s, exit 0**, no `SCRIPT ERROR` or `ERROR:`. The existing held-gas kicker
case remains pending. See the plan's Task 5 execution record for limitations.

The original protected hash check excludes only `surfaces/grip_table.tres`,
whose entire-file hash necessarily changed with six approved additions. The
new surface test independently pins all twenty old entries. Existing surface
definitions, cars, protected tests and old-level data remain unchanged.

```sh
sha256sum -c docs/notes/m6b1-jump-data/surfaces-source.sha256
sha256sum -c docs/notes/m6b1-jump-data/SHA256SUMS
```

Manual preview: `start=sand` (1330 m) or `start=climb` (2240 m), with the existing
course, jump and bridge modes unchanged. For a normal-speed drive, keep other
Godot sessions closed and omit `--fixed-fps`:

```sh
XDG_DATA_HOME=/tmp/ridge-coastal-review-data \
XDG_CONFIG_HOME=/tmp/ridge-coastal-review-config \
godot --path . --resolution 1280x720 res://debug/coastal_playcheck.tscn -- \
  mode=smoke start=sand car=rally tc=0.20 capture=/tmp/coastal-sand.png
```

Physics boundaries are exact despite visual colour blending. The checkpoint
assertion correction records instantaneous reset separately from subsequent
settling drift; no driving gate or car tuning was relaxed. Normal-speed PC
peaks were 133 draws / 235,332 primitives, **not phone acceptance**. Geometry
cost grew with detail; it is not free headroom for the remaining scenery.

## October 7 — owner bridge refinement

Implementation **`b845a20`**, based on `c152ab5`: a slightly longer 20 m bridge,
0.30 m deck crest and taller masonry arch, authored only in Coastal's resource.
The centre, smooth joins, shared defaults, car tuning and jump are unchanged.
See the plan's **Task 4 owner refinement** record for dimensions and limitations.

`bridge-refinement-2026-10-07.tar.gz` preserves
`runs/m6b1-bridge-refinement-2026-10-07.E9BMuW/`: focused checks, three normal-speed
all-car bridge drives, six fixed views and the full regression log/exit status.
`bridge-refinement-source.sha256` pins this revision's source; the older
`structures-source.sha256` still describes `81f368f`, not this revision.
Verify historical source manifests only in separate worktrees at their recorded
commits; their intentional differences from today's bridge are not corruption.

Focused: **14 passing / 18,941 assertions**, exit 0, no script errors. All eight
low/normal/off-centre crossings passed, as did three rendered PC smokes. The
stock rally briefly unloaded one wheel at road speed; no full-car hop or chassis
strike was recorded. Fresh full regression: **825 passing, one inherited pending,
624,587 assertions, 620.386 s, exit 0**, no script errors. Protected source hashes
also pass. No phone acceptance claim.

Verify from the project root. Manual preview is unchanged:

```sh
sha256sum -c docs/notes/m6b1-jump-data/bridge-refinement-source.sha256
sha256sum -c docs/notes/m6b1-jump-data/SHA256SUMS
godot --path . res://debug/coastal_playcheck.tscn -- start=bridge
```

## October 7 — approved jump, tunnel and stone bridge

Implementation source: **`81f368f`**, after `bd3f57d` (tunnel), `f1e3a45`
(independent stone bridge and opt-in tunnel join/floor correction), `08ae44b`
(preview/capture tooling), and the final typed parity-fixture correction.
The dated Task 4 execution section of the
[B1 plan](../../superpowers/plans/2026-09-27-m6b1-coastal-highway.md) is this
stage's report; the whole-milestone final report remains future work.

`structures-2026-10-07.tar.gz` preserves
`runs/m6b1-structures-2026-10-07.OO7lQK/`: failed and successful tunnel/bridge
tests, the stopped failing regression, a stalled combined run and its isolated
Rally Road repeat, the final regression, normal-speed
all-car drives, sampled trajectories and before/after fixed-view screenshots.
`structures-source.sha256` pins tested implementation and protected source.
Neither of the older source manifests describes this later structure revision.

Final combined regression: **823 passing, one inherited pending, 624,470
assertions, 623.793 s, exit 0**, no script errors. The earlier stalled combined
run is not accepted evidence; its cause remains unconfirmed and it did not recur
in the isolated Rally Road repeat or the final full run. Six normal-speed PC
smokes passed. Phone acceptance and Tasks 5–8 remain outstanding.

```sh
sha256sum -c docs/notes/m6b1-jump-data/SHA256SUMS
sha256sum -c docs/notes/m6b1-jump-data/structures-source.sha256
XDG_DATA_HOME=/tmp/ridge-coastal-review-data \
XDG_CONFIG_HOME=/tmp/ridge-coastal-review-config ./run_tests.sh all
```

Manual launch: add `start=course` to include the tunnel from the beginning,
or `start=bridge` for the real 1970 m checkpoint. Default remains the accepted
730 m jump reset. No Coastal scoring or progress entry exists yet.
`mode=smoke start=course balance=true` runs the course-to-jump driver;
`mode=smoke start=bridge` runs the bridge driver. Explicit car/TC overrides
are runtime-only. `mode=views capture=/tmp/coastal` saves six fixed views;
this mode deliberately refuses the headless dummy backend. Use the isolated
XDG paths and close other Godot/game sessions before checks.

The two course-start-only controller changes are documented, not game assists:
conservative opening bends until 580 m, then uncapped acceleration, and a 2°
nose-up landing target bias for the faster arrival. The accepted reset driver
and gap geometry are unchanged. No phone result or completed B1 is claimed.

## October 7 — larger-jump revision

Implementation source: **`0efa994`**, based on the October 6 delivery `b8655b4`.
`larger-jump-2026-10-07.tar.gz` preserves
`runs/m6b1-larger-jump-2026-10-07.qUnef4/`: before/after measurements, rejected
geometry matrices, final controlled and stress cases, normal-speed rendered
screenshots/trajectories and full regression log/exit status.
`larger-jump-source.sha256` identifies this revision's source, including the
unchanged protected files. `SHA256SUMS` covers both immutable archives.

The main driving gate now uses the owner's stated lift-and-balance strategy.
The pitch feedback controller uses normal gas/brake inputs, **only in tests**.
It is not a player assist or proof of human feel. Held-throttle and uncorrected
coast runs remain logged stress observations, not clean-landing acceptance.
See the report for the exact scope change and retained failures.

For this revision, run from the project root:

```sh
sha256sum -c docs/notes/m6b1-jump-data/SHA256SUMS
sha256sum -c docs/notes/m6b1-jump-data/larger-jump-source.sha256
XDG_DATA_HOME=/tmp/ridge-coastal-review-data \
XDG_CONFIG_HOME=/tmp/ridge-coastal-review-config ./run_tests.sh all
```

Normal-speed corrected smoke (omit `balance=true` for uncorrected coast;
use `held=true` for held throttle):

```sh
XDG_DATA_HOME=/tmp/ridge-coastal-review-data \
XDG_CONFIG_HOME=/tmp/ridge-coastal-review-config \
godot --path . --resolution 1280x720 res://debug/coastal_playcheck.tscn -- \
  mode=smoke car=offroad_4x4 tc=0.20 balance=true capture=/tmp/coastal-oct7.png
```

Smoke exit status checks recovery/upright/no-reset only. The stricter matrix
assertions live in `test_coastal_gap.gd`; do not equate smoke exit 0 with those
limits. No October 7 phone performance is claimed.

## October 6 — original 14 m gap

`evidence.tar.gz` preserves the original dated run directory, including the fresh
baseline, interrupted/failed attempts, raw sampled trajectories, normal-speed
PC screenshots and final regression log/exit status. `SHA256SUMS` verifies the
archive; `source.sha256` identifies **`203d2b7`**, not today's source. Some of
its hashes deliberately differ after the October 7 revision; verify that
historical manifest only in a separate worktree at its recorded revision.
Commands should be run from the project root, with no owner game or other
Godot process running.

The isolated paths are important: test fixtures use `SaveSandbox`, and the
independent data/config roots also keep preview smoke runs away from the
owner's progress and settings.

For a focused matrix, import newly added classes first, then run:

```sh
godot --headless --path . --import
godot --headless --path . --fixed-fps 120 --max-fps 0 \
  -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/scenarios/test_coastal_gap.gd -gexit
```

Check the log for `SCRIPT ERROR`, not only GUT's exit code; an empty/failed
script load is never a pass. Use the same isolated XDG variables for both
commands. Accelerated headless tests do not establish real-time performance.

Phone entry is prepared, **not exercised in this delivery**. After building
and installing a fresh debug APK, the one-shot flag is
`adb shell run-as com.ridge.game touch files/coastal_playcheck`. Empty means
manual jump preview; optional JSON accepts `car`, `tc`, `start` and `mode`.
It is consumed by the preview, so next launch is normal. Do not launch a test
over an owner play session or describe an old installed APK as this build.
