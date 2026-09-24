# M6W isolated groundwork evidence — 2026-09-24

Desktop only: Godot 4.7.2, GUT 9.7.1. No phone acceptance is implied.
See `../codex-report-m6w-waves.md` for results and limitations.

- `baseline.log.gz`: complete unchanged M6A baseline, exit 0.
- `regression-interrupted.log.gz`: first new-suite attempt, stopped with SIGTERM
  (exit 143) after prolonged lack of output following the Rock Canyon ledge
  test. Not a completed run or a pass; cause unknown. A final isolated mesh
  guard/test edit also postdated the start of this attempt.
- `selector-error.log.gz`: mistaken `-gtest=test_water_wave_` invocation; this
  option expects script paths, not a substring. GUT logged an error but ran
  the whole unit directory and exited 0. Not counted as a clean acceptance run.
- `focused.log.gz`: corrected `-gselect=test_water_wave_` run on final code,
  exit 0, 24 passing tests, 13,647 assertions, no SCRIPT ERROR or GUT error.
- `gpu.log`: final real-renderer parity check, exit 0, Forward Mobile/Vulkan,
  AMD Radeon 880M, 960x540. The X11 input-method warning is retained.
- `preview.png`: inspected synthetic calm-pool capture from that check;
  unpolished lighting, no car or driving-feel claim.
- `regression.log.gz`: final complete regression, exit 0; 760 passing, one
  pre-existing pending, 370,525 assertions, no SCRIPT ERROR or GUT error,
  480.818 s. Exact runtime/tests match feature commit `d9eb9ee`.

Each run used a separate `/tmp/ridge-m6w-…` XDG data/config path and ran
sequentially. Runtime and tests were frozen for the final complete regression.

Reproduce focused tests from the project root after import:

```sh
godot --headless --path . --fixed-fps 120 --max-fps 0 \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit \
  -gselect=test_water_wave_ -gexit
```

Full suite: `./run_tests.sh all`. It uses accelerated simulation for functional
regressions, not performance acceptance. Check the actual exit status and log
for SCRIPT ERROR and GUT errors, not only the green summary.

Rendered parity (requires an idle real display, not `--headless`):

```sh
godot --path . --resolution 960x540 res://debug/water_wave_lab.tscn -- --verify
```

The diagnostic canvas shares the spatial shader's exact height function. It
calibrates encoded readback, checks 576 packed-input samples, then compares GPU
vertex heights using actual mesh attributes against 21 barycentric sampler
queries. It does not claim a phone test, normal-parity test, render-performance
benchmark or complete rasterized spatial-depth readback.
