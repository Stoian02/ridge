# Coastal B1 jump evidence

See [the checkpoint report](../m6b1-jump-feasibility.md) for scope, criteria,
failures and pending owner/phone acceptance. This directory is ignored by the
Godot importer; none of its evidence becomes a game asset.

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
