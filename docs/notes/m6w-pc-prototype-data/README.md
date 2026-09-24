# PC Test Ground prototype evidence (2026-09-24)

See [the report/playtest guide](../m6w-pc-prototype-2026-09-24.md). This checkpoint
is the owner's explicitly approved **early PC feel exception**, not phone or
whole-part acceptance. No phone was built, installed or tested during this pass.

- `pc-playcheck.tar.gz`: final normally paced PC run, all three modes, raw
  tick/frame CSVs, summary derived from the printed per-case JSON, and all views.
  Includes actual pause UI, drive/settle, entry/chase/side and underwater views.
  Timed windows are 600 ticks each; image readbacks happen outside them.
- `focused-and-rendered-logs.tar.gz`: all focused tests, imports and three
  rendered development checks, the final GPU parity check and independent CSV
  validator output. No unsuccessful/limited run is substituted for the final.
  `vehicle-tests.log` has the local/world flotation measurement error;
  `vehicle-tests2.log` corrects it without changing physics or limits.
  `render-final.log` predates only the covered-mode Escape guard;
  `render-verified.log` tests that guard through the real UI and is the final
  rendered case used by the report. `focused-final.log` uses the final tests.
- `full-regression-logs.tar.gz`: interrupted attempt (SIGTERM, exit 143, not a
  pass) and its thread-state/failed native-debugger inspection, plus the unchanged
  full rerun: **774 passing, one existing pending, 380,851 assertions, exit 0,
  no SCRIPT ERROR or GUT error**, 447.574 s. Native debugger was not installed;
  no native-stack explanation is claimed for the interrupted attempt.
- `SHA256SUMS`: retained archive identities, paths relative to repository root.

The raw timing columns are **controller-only**, not complete water cost. The
usual 13 base queries/tick are retained; source generation is not measured in
those columns. Do not subtract component percentiles, infer phone performance,
or call this the proposed three-by-30-second synthetic feasibility protocol.
Some early/focused logs contain ObjectDB exit warnings; the final rendered log
does not. Initial sandbox import socket errors are retained; the unrestricted
import retry completed. The graphical checks have an XIM warning, not a script
failure. No leak-free/long-session claim is made from these short tests.

## Recompute existing samples without running Godot

From the repository root:

```sh
wave_audit_dir=$(mktemp -d /tmp/ridge-m6w-pc-audit.XXXXXX)
tar -xzf docs/notes/m6w-pc-prototype-data/pc-playcheck.tar.gz -C "$wave_audit_dir"
PYTHONDONTWRITEBYTECODE=1 python3 tools/check_water_measurements.py "$wave_audit_dir"
```

Expected: three cases / 1,800 ticks, no gate requested. This validates counts,
sequence and printed timing totals/percentiles, not GPU/all-water acceptance.

## Rerun only while the owner is not playing

```sh
# Use a real renderer; runs the actual pause controls and unfrozen 4×4, then exits.
XDG_DATA_HOME=/tmp/ridge-wave-pc-data XDG_CONFIG_HOME=/tmp/ridge-wave-pc-config \
  godot --path . --resolution 1280x720 res://debug/water_wave_pc_playcheck.tscn

# Full correctness regression, not a performance benchmark:
XDG_DATA_HOME=/tmp/ridge-wave-tests-data XDG_CONFIG_HOME=/tmp/ridge-wave-tests-config \
  ./run_tests.sh all
```

Never overlap Godot instances or run tests while the owner drives. The desktop
data/config overrides keep real progress untouched. Runtime timing is normal
120 Hz / 60 FPS; only correctness tests use accelerated fixed-fps mode. Desktop
GPU parity uses the existing `debug/water_wave_lab.tscn -- --verify` command.
