# Coastal B1 staged implementation evidence

See [the final B1 report](../codex-report-m6b1-coastal.md) and
[the original jump checkpoint report](../m6b1-jump-feasibility.md) for scope,
criteria, failures and owner acceptance. This directory is ignored by the
Godot importer; none of its evidence becomes a game asset.

## October 7 — whole-route and phone acceptance (Tasks 7–8)

Final runtime source **`b8b182e`**, after `fe8848c` ordinary-input whole-route
checks and `caa3d8f` recorder. The owner approved presentation and explicitly
deferred scoring/catalog admission to B2. Geometry/car/surface tuning is
unchanged; B2 water, sea and waves remain absent. No merge/push.

`acceptance-2026-10-07.tar.gz` contains `package/`:

- `phone-r2/`: final artifact/source/installed-APK/save hashes and per-mode
  `results.tar`, process-filtered logs, thermal/battery snapshots. Modes are
  loads, balanced views, full all-car driving, five-minute soak. Each tar keeps
  only its own cases/metadata/completion, not duplicate earlier-case files.
- `phone/`: the initial **failed** Android artifact. The driver was excluded
  under tests/, causing compile errors and preventing the drive. Numeric load/
  view diagnostics and logs are retained; redundant initial PNGs are omitted
  from the package, but remain in the original ignored runs directory.
- `phone-install-failed*`: transient ADB disconnect before any case in the first
  corrected-install attempt. It is not a gameplay/performance failure.
- `pc-drive/`, `pc-loads/`, focused/full logs: desktop verification, including
  the normal-speed final 4x4 complete route. `full-suite.log` is the initial
  842-pass result; **`final-full-suite.log`** is the delivered-source result.
- `analyze.py`, `independent-csv-audit.txt`, `repeat-phone.sh`: independent raw
  CSV recomputation and the exact phone runner. The runner's local output path
  should be changed to a fresh directory for a new review run.

Final suite: **843 passing, one inherited pending, 630,382 assertions,
141 scripts, 707.095 s, exit 0, no SCRIPT ERROR/ERROR**. Unit: 726 passing.
Final phone: all three cars finish through every gate without resets; 59,417
frames across views/drives/soak with zero >33.3 ms intervals. Peak **145 draws /
238,954 primitives**. Live p95 <=17.698 ms; p99 <=18.310 ms. Worst **post-drive**
load is **4.253 s through ready / 4.378 s cover**, not only the quicker 2.6–2.8 s
repeat sequence. All measured B1 gates pass; owner final playtest/review remain.

`acceptance-source.sha256` is now the current manifest. Verify historical ones
only at their recorded commits; the driver relocation changes its old path.
The final APK's SHA-256 is
`d413f44239382bb241c6fee3f1de36edfd942121b2e888bbe0e7b51602e5cda5`, matching the
installed file. Save checksum before/after is identical, flags consumed.

```sh
sha256sum -c docs/notes/m6b1-jump-data/acceptance-source.sha256
sha256sum -c docs/notes/m6b1-jump-data/SHA256SUMS
# Extract into a fresh directory, then from its parent:
python3 package/analyze.py
```

The report includes exact phone/desktop repeat commands and every load phase.
No failed run was converted to a pass by dropping a tail or raising a limit.

## October 7 — coastal land and presentation (Task 6)

Implementation **`69f45c7`**, after terrain/barrier commit **`1ea9e06`**, based
on owner-approved Task 5 (`4109f29`). New opt-in independent shore/headlands,
selective static protection, sparse mixed scenery batches, clearing-weather
mood, existing wind ambience and a fixed depth-tested rainbow. No accepted
driving-profile, car or surface value change. Sea/channel/cove remain dry B1;
no water bodies, waves, scoring, catalog entry, merge or push.

`presentation-2026-10-07.tar.gz` retains the complete
`runs/m6b1-presentation-2026-10-07.NuzqNT/` directory: initial terrain checks,
failed typed-code iterations, before/after views, six normal-speed PC drives,
post-split focused tests and full regression. The first view pass exposed
unmatched join colour and a camera-clipped arc; the corrections are included
in final source, not hidden by deleting the original evidence. The first
test-file parse failure returned exit 0 from GUT and is **not a pass**.

`presentation-source.sha256` pins the **Task 6** source. Earlier
manifests below describe their own revisions; verify those only in separate
worktrees at the stated commits. All car/surface resources and protected tests
are unchanged from Task 5, including its six already-approved grip additions.

Focused final: **16 passing / 5,717 assertions, 21.278 s**, no script errors.
Full regression on **`69f45c7`: 839 passing, one inherited pending, 630,255
assertions across 139 scripts, 655.866 s, exit 0**, no `SCRIPT ERROR` or `ERROR:`.
The inherited held-gas kicker case is still pending. Six PC drives passed; maximum
**141 draws / 236,996 primitives**, build **1.081–1.163 s**. Thirteen corrected
fixed views were captured, with the same scene-only 4000 m camera far plane
as manual play. See the plan's Task 6 execution record for every case and
limitations: these are not whole-route, frame-time percentile or phone gates.
The phone was absent over USB; no Android artifact/install is claimed.

```sh
sha256sum -c docs/notes/m6b1-jump-data/presentation-source.sha256
sha256sum -c docs/notes/m6b1-jump-data/SHA256SUMS
XDG_DATA_HOME=/tmp/ridge-coastal-review-data \
XDG_CONFIG_HOME=/tmp/ridge-coastal-review-config ./run_tests.sh all
```

Manual preview from the start (no concurrent tests):

```sh
godot --path . res://debug/coastal_playcheck.tscn -- start=course
```

`start=sand`, `start=bridge`, `start=climb` and the default jump reset remain.
For normal-speed automation use the same isolated XDG paths, resolution
1280×720 and `mode=smoke start=course car=rally tc=0.20 balance=true`, optionally
`samples=/tmp/coastal.json capture=/tmp/coastal.png`. Balance is only ordinary
test-driver pedal input, not an in-game landing assist. `mode=views` captures
13 fixed views and refuses the headless dummy backend.

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
and the final full suite. `surfaces-source.sha256` pins Task 5's source,
not the later presentation revision above. Fresh Task 5 full regression:
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
