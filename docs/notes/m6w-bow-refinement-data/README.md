# Bow-only refinement evidence

See [the report](../m6w-bow-refinement-2026-09-24.md). All PC runs use isolated
save/config directories, with no simultaneous Godot instances. This checkpoint
does not include an Android export, installation or phone acceptance.

- `captures.tar.gz`: selected original/refined forward, reverse, oblique and
  slow front-side captures. Identical starting inputs, not guaranteed identical
  subsequent physics trajectories. Whole-mesh diagnostics and screenshot
  readbacks contaminate on-screen timings: these are **visual checks, not
  performance measurements**.
- `checks.tar.gz`: complete before/after capture logs, focused tests, GPU parity,
  normally paced smoke and independent CSV verification logs. The focused run
  reports 18 ObjectDB instances on exit; graphical runs retain XIM warnings.
- `pc-smoke.tar.gz`: tick/frame CSVs, JSON summary mechanically extracted from
  the printed results and screenshots. Controller-only timing, not all-water
  acceptance; 600 ticks per mode, 1,800 in total.
- `full-regression.tar.gz`: complete accelerated correctness regression log;
  780 passing, one inherited pending, 449,525 assertions, exit 0, no SCRIPT ERROR
  or warnings. Not a gameplay performance measurement.
- `SHA256SUMS`: archive identities relative to repository root.

Rerun only when the owner is **not playing**. Use fresh task-specific XDG data
and config directories, not the owner's save. Graphical runners need a local
display and exit when complete.

```sh
# Real 4x4, coasting forward/reverse/oblique/slow; visual check only.
godot --path . --resolution 1280x720 res://debug/water_wave_bow_check.tscn
# Real-renderer numerical parity; headless must not emit a hollow pass.
godot --path . res://debug/water_wave_lab.tscn -- --verify
# Normally paced smoke; capture windows outside timing.
godot --path . --resolution 1280x720 res://debug/water_wave_pc_playcheck.tscn
# Full correctness regression (accelerated, not performance evidence).
./run_tests.sh all
```

Validate the smoke data read-only after extraction:

```sh
wave_bow_audit=$(mktemp -d /tmp/ridge-wave-bow-audit.XXXXXX)
tar -xzf docs/notes/m6w-bow-refinement-data/pc-smoke.tar.gz -C "$wave_bow_audit"
PYTHONDONTWRITEBYTECODE=1 python3 tools/check_water_measurements.py "$wave_bow_audit"
```

Expected: three cases / 1,800 ticks validated, no performance gate requested.
