# Phone ambient-cost diagnosis evidence

See [the report](../m6w-ambient-cost-diagnosis-2026-09-25.md). No gameplay changes
or acceptance pass are implied. No private progress JSON is included.

- `phone-csv.tar.gz`: original retained Claude run (`existing`) plus fresh
  unchanged baseline, split-cost, reverse-order, counts-only, uninstrumented
  repeat (`observed`) and uninstrumented CPU-observed repeat (`final`). Exactly
  three standard tick/frame cases per run. Old cost CSVs left by earlier runs
  are deliberately excluded from this archive.
- `diagnostic-csv.tar.gz`: exactly three cost CSVs for each of `split`, `reverse`
  and `counts`; 5,400 ticks in total. Wall timings include recorder overhead and
  preemption, not thread CPU time. `raw_usec` encloses ambient/packet/bow costs;
  never add both the enclosing total and its parts.
- `logs.tar.gz`: complete cumulative Godot logcats, build/import/focused/full
  suite logs, analysis summaries and CPU observations. Older launch entries
  recur in later logcat snapshots; use the report's run times/process IDs.
  The first baseline Vulkan-startup error is retained. Empty/unsuccessful CPU
  captures remain identified, not silently discarded.
- `capture-support.tar.gz`: local phone mode config files and final read-only
  CPU-monitor script. The uptime column was denied; epoch seconds are usable.
- `SHA256SUMS`: hashes relative to the repository root.

## Replay analysis without the phone

```sh
wave_cost_audit=$(mktemp -d /tmp/ridge-wave-cost-audit.XXXXXX)
tar -xzf docs/notes/m6w-ambient-diagnosis-data/diagnostic-csv.tar.gz -C "$wave_cost_audit"
PYTHONDONTWRITEBYTECODE=1 python3 tools/summarize_wave_cost.py "$wave_cost_audit"
```

The analyzer validates 600 unique contiguous ticks per case, finite/nonnegative
metrics, request/cache/evaluation accounting and nested timing consistency.
It reports the frame/tick histogram and component statistics on complete
two-tick frames, excluding partial capture boundaries, not slow valid samples.
Standard playcheck p95 values use its original frame CSVs including their normal
boundary handling, so they can differ slightly from the diagnostic's p95.

## Repeat on the phone only when the owner is not playing

Build and install fresh first. Existing `files/wave_playcheck` is still the
launcher flag; `files/wave_cost_diagnosis` is an additional, consumed opt-in.

```sh
tools/android.sh build
tools/android.sh install
# Empty diagnosis file = split-cost normal order. Plain text "reverse" reverses
# mode order; "counts" uses unchanged production raw maths, without split clocks.
adb shell run-as com.ridge.game touch files/wave_cost_diagnosis
adb shell run-as com.ridge.game touch files/wave_playcheck
adb shell monkey -p com.ridge.game -c android.intent.category.LAUNCHER 1
```

Desktop equivalent with isolated save/config directories:

```sh
godot --path . res://debug/water_wave_pc_playcheck.tscn -- --diagnose
godot --path . res://debug/water_wave_pc_playcheck.tscn -- --diagnose --reverse
godot --path . res://debug/water_wave_pc_playcheck.tscn -- --diagnose --counts
```

Each mode's trace is `user://wave_pc_playcheck/cost_mode_N.csv`. Counters-only
mode still times whole raw evaluation, bounding and lookup; it is not a zero
overhead baseline. Without the diagnosis flag/argument there is no diagnostic
sampler replacement. Replay occurs only after timing, on private snapshots,
and must not be treated as acceptance or sustained thermal evidence.
