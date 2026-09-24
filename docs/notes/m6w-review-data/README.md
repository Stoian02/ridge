# M6W review follow-up evidence

See [the report](../m6w-review-followup-2026-09-24.md) for scope and conclusions.
These are follow-up captures, not replacements for the earlier groundwork or
failed M6A acceptance evidence. Archives contain raw samples, not just plots.

## Contents

- `all-cars-csv.tar.gz`: summary and all four CSVs per case for the **24 cases
  named in this batch's summary**, including slow frames. Two rounds, three cars,
  shallow05/shallow30/calm/current. Old phone-result files not named by that
  summary are deliberately excluded, not mixed into this batch.
- `rally-calm-detail-csv.tar.gz`: three detailed calm-pool cases, including
  placement/warm-up in diagnostic CSVs and separate warmed standard CSVs.
- `rally-calm-baseline-only-csv.tar.gz`: initial three ordinary calm measurements.
  Detailed trace was accidentally disabled by JSON flag parsing; do not treat
  them as successful diagnostic captures.
- `hitch-metadata.tar.gz`: each batch's exact options, complete game-tag logcat,
  battery/thermal/save hashes, trace command result; validated analysis JSON for
  detailed captures and all-car SQL output/loader log.
- `phone-lab.tar.gz`: three complete numerical lab logs and before/after checks.
- `desktop-build-logs.tar.gz`: phase profiler, bake generation, focused tests,
  full regression, desktop GPU verification and Android exports. Export/tooling
  warnings are retained. Desktop GPU log predates only the cosmetic replacement
  of its old "desktop only" print with an actual device label; phone logs use
  the final code. No equations/topology changed between those checks.
- `capture-scripts.tar.gz`: the temporary host scripts/configs/options used.
  The included streaming Perfetto config is the **final all-car config**, not
  the earlier incomplete ring-buffer setup. Scripts contain this session's
  device/path choices, not a general automatic testing service.
- `desktop-preview.png`: inspected car-free cached-mesh preview, not a feel pass.
- `SHA256SUMS`: archive hashes plus local trace/APK identities, paths relative to
  repository root.

Full system trace is intentionally **local-only**, about 40 MiB compressed:
`runs/m6w-review-data/all-cars.pftrace.gz`. It remains available in the shared
workspace but will not travel with a git checkout. Do not assert independently
verified scheduling from CSVs alone if that trace is unavailable; request it.
Other transient captures remain under `/tmp/ridge-m6w-hitch/`. Owner progress
JSON is not committed; only its hashes are included. Raw trace contains system
process names; do not publish/upload it automatically.

## Replay without running the game

From the repository root:

```sh
audit_dir=$(mktemp -d /tmp/ridge-m6w-audit.XXXXXX)
tar -xzf docs/notes/m6w-review-data/all-cars-csv.tar.gz -C "$audit_dir"
PYTHONDONTWRITEBYTECODE=1 python3 tools/test_analyze_water_hitch.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/analyze_water_hitch.py "$audit_dir"
```

The analyzer validates case membership/tick-to-frame sums, reports transitions
and retains warm-up tails; it does not determine scheduling or gate acceptance.
Do not confuse its placement-inclusive maximum with the standard harness's
warmed `summary.json` maximum.

With the trace and official Perfetto v58.2 trace processor available:

```sh
gzip -dc runs/m6w-review-data/all-cars.pftrace.gz > "$audit_dir/all-cars.pftrace"
/tmp/ridge-trace-processor-bin query -f tools/water_hitch_trace.sql \
  "$audit_dir/all-cars.pftrace"
```

The session's binary SHA256 is
`58042408e6cc861fb1a731c26bb082dc222285561eaa4e12a48a8b2b90dca7b9`.
It is not bundled with the project. Obtain it from the official
[Perfetto release](https://github.com/google/perfetto/releases/tag/v58.2) if
needed. SQL uses thread IDs/windows specific to this trace, not future runs.
Clock anchors are in logcat. See
[Perfetto SQL documentation](https://perfetto.dev/docs/analysis/perfetto-sql-getting-started).

## Rebuild / rerun, only while owner is not playing

```sh
# Offline derivation profiler, no gameplay or acceptance timing:
godot --headless --path . -s debug/water_wave_preparation.gd
# Regenerate NEW wave assets only when source/profile/algorithm changes:
godot --headless --path . -s tools/bake_water_waves.gd
# Real-renderer desktop parity (not the dummy headless backend):
godot --path . --resolution 960x540 res://debug/water_wave_lab.tscn -- --verify
# Normal paced, waves-Off diagnostic:
godot --path . res://debug/water_acceptance.tscn -- mode=course rounds=2 trace=1
```

Use isolated XDG desktop data/config paths, never concurrent Godot instances.
The five assets must be regenerated together and fresh/cache unit comparisons
rerun; never regenerate protected geometry/balance fixtures.

Phone entry uses the existing one-shot `files/water_acceptance` flag containing
JSON. `{"mode":"course","rounds":2,"trace":1}` runs the detailed all-car
diagnostic; `{"mode":"wave_lab"}` runs cached preparation and calibrated
GPU parity. Build before installing, compare installed APK SHA256, retain full
logcat and preserve the save. The archived scripts show the exact sequence.
Do not start these automatically just because the phone is connected.

Final APK: `a670f2f4307b59fb6c14aa27c0669385ef1be02a7f3d09d0d30280e64e9f8abf`.
The earlier detailed-hitch APK identity is in the report; its local hash was
recorded and it was fully installed, but unlike the final lab APK it did not
receive a separate installed-file hash check. Do not retroactively claim one.
