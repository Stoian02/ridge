# Coastal B1 jump evidence — 2026-10-06

See [the checkpoint report](../m6b1-jump-feasibility.md) for scope, criteria,
failures and pending owner/phone acceptance. This directory is ignored by the
Godot importer; none of its evidence becomes a game asset.

`evidence.tar.gz` preserves the dated run directory, including the fresh
baseline, interrupted/failed attempts, raw sampled trajectories, normal-speed
PC screenshots and final regression log/exit status. `SHA256SUMS` verifies the
archive; `source.sha256` identifies the delivered source and protected files.
Commands should be run from the project root, with no owner game or other
Godot process running.

```sh
sha256sum -c docs/notes/m6b1-jump-data/SHA256SUMS
sha256sum -c docs/notes/m6b1-jump-data/source.sha256
XDG_DATA_HOME=/tmp/ridge-coastal-review-data \
XDG_CONFIG_HOME=/tmp/ridge-coastal-review-config ./run_tests.sh all
```

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
