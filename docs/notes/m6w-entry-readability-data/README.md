# Entry-readability correction evidence

See [the report](../m6w-entry-readability-2026-09-24.md). All PC runs use isolated
save/config directories; no simultaneous Godot instances. Phone acceptance is
not implied.

- `captures.tar.gz`: selected original/final event-aligned chase/side captures,
  plus the slower paced entry. Original and final launch cases use the same
  inputs; live physical response can change the subsequent trajectory. The
  full-mesh diagnostic/readbacks contaminate on-screen performance numbers:
  **do not treat screenshot FPS/timings as gameplay measurements**.
- `checks.tar.gz`: diagnostic development logs (including failed slow-runner
  typed-array initialization and corrected rerun), focused tests, GPU parity,
  normally paced smoke log, independent CSV verification and Android export log.
- `pc-smoke.tar.gz`: three normal-speed cases, actual tick/frame CSVs and summary
  mechanically extracted from their printed JSON, with smoke-test screenshots.
  Controller-only timings, not the complete total-water gate.
- `full-regression.tar.gz`: complete regression log: 775 passing, one inherited
  pending, 431,425 assertions, exit 0, no SCRIPT ERROR or warnings.
- `SHA256SUMS`: identities of the retained archives, relative to repository root.

Rerun only when the owner is **not playing**. Use fresh task-specific XDG data /
config directories rather than the owner's save. Graphical commands need the
local display; all runners exit when complete.

```sh
# Natural entry, three launch speeds under acceleration; geometry/visual check only.
godot --path . --resolution 1280x720 res://debug/water_wave_entry_check.tscn
# Maintains about 3m/s using throttle/brake inputs; same geometry/visual check.
godot --path . --resolution 1280x720 res://debug/water_wave_entry_check.tscn -- --slow
# Numerical check on the real renderer (headless is not a pass).
godot --path . res://debug/water_wave_lab.tscn -- --verify
# Normally paced PC smoke with screenshot windows outside timing.
godot --path . --resolution 1280x720 res://debug/water_wave_pc_playcheck.tscn
# Full correctness regression (accelerated, not performance measurements).
./run_tests.sh all
```

Raw smoke data can be checked read-only after extraction:

```sh
wave_entry_audit=$(mktemp -d /tmp/ridge-wave-entry-audit.XXXXXX)
tar -xzf docs/notes/m6w-entry-readability-data/pc-smoke.tar.gz -C "$wave_entry_audit"
PYTHONDONTWRITEBYTECODE=1 python3 tools/check_water_measurements.py "$wave_entry_audit"
```

Expected: three cases / 1,800 ticks validated, no performance gate requested.

Fresh Android APK exported successfully; its identity is in the report. No
connected device was detected, so no phone install/test is included here.
