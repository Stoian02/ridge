# Query-fix evidence (2026-09-24)

Interpretation: `../m6a-query-fixes-2026-09-24.md`.

- `headless-before/after.log` and corresponding `.tar.gz`: three rounds × ruts
  and ford, normal-paced headless, **not** FPS/phone acceptance. Archives contain
  `water_acceptance_results/summary.json`, raw tick CSVs and raw frame CSVs.
- `ford-layout.log`: untimed 13-probe diagnostic before optimization.
- `creek-baseline.log`: detached pre-water `a3dbee4`; `creek-before.log`: current
  water build before rendering fix. Exact same camera/viewport/hidden HUD.
- `creek-shadow-experiment.log`: same fixture with road shadow casting disabled.
- `creek-final-authored.log`: final saved setting, no diagnostic override; all
  three counts match the experiment, including after covering the finish run-out.
- `window-coarse.log` / `.tar.gz`: normal rendered Canyon, original query path.
- `window-final.log` / `.tar.gz`: final code, three rounds of all five live
  creek/rut/ford views, 18,000 measured ticks. Actual viewport 1600×720.
- `window-aborted-authoring.log`: incomplete live run stopped because the saved
  resource's misplaced shadow property had not loaded. It is not a passed run.
- `regression-first.log.gz`: first suite, with the overbroad new sparse-creek
  performance assertion failing (exact water-query parity itself passed).
- `regression-runout-coverage.log.gz`: stopped intermediate suite; new render
  test caught the last road chunk outside the initial 1500 m shadow-free range.
- `regression-final.log.gz`: completed-code full suite, 735 passing, one existing
  pending, no SCRIPT ERROR, exit 0.
- `phone-coarse.log` / `.tar.gz`: original query lookup on the fixed APK, three
  Canyon rounds / 7,200 ticks. The fine index is still constructed, so this is
  not a pre/post setup-time comparison.
- `phone-ford.log` / `.tar.gz`: refined queries, matching three Canyon rounds /
  7,200 ticks. Same APK, car, forces and geometry as `phone-coarse`.
- `phone-creek.log` / `.tar.gz`: three rounds of three live creek views /
  10,800 ticks; final authored road-shadow fix, no diagnostic render override.
- `phone-course.log` / `.tar.gz`: three rounds × three cars × four course
  placements / 45,360 ticks. Includes the first-round current-pool stall in
  frame timing; no outlier or failing case was removed.
- `phone-*-before.txt` / `phone-*-after.txt`: battery temperature (tenths of °C),
  Android thermal status and save hash immediately around each batch.

All logs retain timing values and warnings; trailing whitespace only is removed.
PNGs are local artifacts, not raw timing data. The owner reconnected the phone
after desktop testing. All four phone batches use APK SHA-256
`7e4cf5d572046c99b95d5f6684a4ea20faa5bc97833cf585d948bff31c9aa865`.
Phone archives contain only that batch's `summary.json` and its referenced tick
and frame CSVs at the archive root, not stale files from previous batches.
Full streamed Godot/AndroidRuntime logcat is retained, including setup/cleanup.

Reproduction (isolated `XDG_DATA_HOME` and `XDG_CONFIG_HOME` recommended):

```bash
godot --headless --path . res://debug/water_acceptance.tscn -- mode=views level=rock_canyon rounds=3
# Reproduce original query path on the fixed build; forces/geometry unchanged:
godot --headless --path . res://debug/water_acceptance.tscn -- mode=views level=rock_canyon rounds=3 index=coarse
# Optional spot=1290 and layout=1 for untimed local candidate diagnostics.
python3 tools/check_water_measurements.py <extracted-water_acceptance_results>
DISPLAY=:1 WAYLAND_DISPLAY=wayland-1 godot --path . --resolution 2400x1080 res://tools/creek_render_audit.tscn -- tag=current
```

For baseline capture, copy only the creek audit `.gd`/`.tscn` to a detached
`a3dbee4` worktree, import that copy and run the identical capture command there.
No water classes are referenced by that fixture. Record **actual** viewport size
printed in metadata; the desktop may constrain the requested window dimensions.

For phone reproduction, build/install the branch using `tools/android.sh build`
then `tools/android.sh install`. With the owner not playing and the game closed,
place the selected JSON below in `files/water_acceptance` via
`adb shell run-as com.ridge.game tee files/water_acceptance < <options-file>`;
start continuous logcat **before** launching the game. The debug launcher
consumes the flag, runs the selected batch at normal speed and exits. Pull
`files/water_acceptance_results` using `run-as` before the next batch overwrites
its summary. Validate each extracted batch separately, since tick IDs restart
between app launches.

```json
{"mode":"views","level":"rock_canyon","rounds":3,"index":"coarse"}
{"mode":"views","level":"rock_canyon","rounds":3}
{"mode":"views","level":"muddy_valley","rounds":3}
{"mode":"course","rounds":3}
```

These are four separate option files/runs, not a single JSON document. Do not
run benchmarks while the owner plays. `--limit-ms 0.50` on the validator still
applies the original gate: the course batch exits 2 with 34/36 cases over it.
Successful raw-data validation without this option does **not** mean that the
performance gate passed. See the report for all open acceptance limitations.
